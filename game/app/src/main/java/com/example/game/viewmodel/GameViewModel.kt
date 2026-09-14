package com.example.game.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.example.game.arena.ArenaMap
import com.example.game.audio.GameAudio
import com.example.game.engine.GameRenderer
import com.example.game.model.Bullet
import com.example.game.model.GamePalette
import com.example.game.model.KillFeedEntry
import com.example.game.model.RemotePlayer
import com.example.game.model.Vec3
import com.example.game.network.ConnectionState
import com.example.game.network.GameNetworkClient
import com.example.game.network.LocalGameServer
import com.example.game.network.NetworkMessage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlin.math.cos
import kotlin.math.sin
import kotlin.random.Random

enum class GameScreenState {
    LOBBY, CONNECTING, PLAYING, DEATH_SCREEN
}

data class ScoreEntry(
    val id: String,
    val name: String,
    val colorArgb: Long,
    val kills: Int,
    val deaths: Int,
    val health: Int,
    val isLocalPlayer: Boolean = false
)

data class GameUiState(
    val screenState: GameScreenState = GameScreenState.LOBBY,
    val username: String = "Blue",
    val playerColorArgb: Long = 0xFF3498DBL,
    val serverHost: String = "127.0.0.1",
    val serverPort: Int = 8888,
    val isPracticeMode: Boolean = false,
    val health: Float = 250f,
    val maxHealth: Float = 250f,
    val kills: Int = 0,
    val deaths: Int = 0,
    val ammo: Int = 30,
    val maxAmmo: Int = 30,
    val isReloading: Boolean = false,
    val respawnTimerSeconds: Int = 5,
    val hitMarkerAlpha: Float = 0f,
    val hitMarkerIsKill: Boolean = false,
    val damageFlashAlpha: Float = 0f,
    val killFeed: List<KillFeedEntry> = emptyList(),
    val scoreboard: List<ScoreEntry> = emptyList(),
    val pingMs: Int = 18,
    val connectionStatusText: String = "",
    val autoFireEnabled: Boolean = false,
    val lookSensitivity: Float = 1.0f,
    val soundEnabled: Boolean = true,
    val hapticEnabled: Boolean = true,
    val isPaused: Boolean = false
)

class GameViewModel(application: Application) : AndroidViewModel(application) {

    val audio = GameAudio(application.applicationContext)
    val renderer = GameRenderer()
    val networkClient = GameNetworkClient(viewModelScope)
    val localServer = LocalGameServer(viewModelScope)

    private val _uiState = MutableStateFlow(GameUiState())
    val uiState: StateFlow<GameUiState> = _uiState.asStateFlow()

    // Physics state
    var playerPos = Vec3(0f, 1f, 0f)
    var velocityY = 0f
    var isGrounded = true
    var cameraYaw = 0f
    var cameraPitch = 0f

    // Input state
    var joystickX = 0f
    var joystickY = 0f
    var isFireButtonHeld = false

    private var gameLoopJob: Job? = null
    private var nextShootTime = 0L
    private var lastNetworkSendTime = 0L

    init {
        // Observe incoming network messages
        viewModelScope.launch {
            networkClient.incomingMessages.collect { msg ->
                handleNetworkMessage(msg)
            }
        }

        // Observe network state
        viewModelScope.launch {
            networkClient.connectionState.collect { state ->
                when (state) {
                    is ConnectionState.Connected -> {
                        _uiState.update {
                            it.copy(
                                screenState = GameScreenState.PLAYING,
                                connectionStatusText = "Connected to ${state.serverHost}:${state.serverPort}"
                            )
                        }
                        startGameLoop()
                    }
                    is ConnectionState.Connecting -> {
                        _uiState.update {
                            it.copy(
                                screenState = GameScreenState.CONNECTING,
                                connectionStatusText = "Connecting..."
                            )
                        }
                    }
                    is ConnectionState.Error -> {
                        _uiState.update {
                            it.copy(
                                screenState = GameScreenState.LOBBY,
                                connectionStatusText = "Error: ${state.message}"
                            )
                        }
                    }
                    is ConnectionState.Disconnected -> {
                        if (_uiState.value.screenState != GameScreenState.LOBBY && !_uiState.value.isPracticeMode) {
                            _uiState.update {
                                it.copy(
                                    screenState = GameScreenState.LOBBY,
                                    connectionStatusText = "Disconnected from server"
                                )
                            }
                        }
                    }
                }
            }
        }

        // Local bot server event listeners
        localServer.onBotSpawnBullet = { bullet ->
            renderer.activeBullets.add(bullet)
        }

        localServer.onPlayerKilled = { killer, killerColor, victim, victimColor ->
            addDeathFeed(killer, killerColor, victim, victimColor)
        }
    }

    fun setUsername(name: String) {
        val color = GamePalette.getPlayerColor(networkClient.myId.ifBlank { "1" }, name)
        _uiState.update { it.copy(username = name, playerColorArgb = color) }
        renderer.playerColorArgb = color
    }

    fun setServerHost(host: String) {
        _uiState.update { it.copy(serverHost = host) }
    }

    fun setServerPort(port: Int) {
        _uiState.update { it.copy(serverPort = port) }
    }

    fun setLookSensitivity(sens: Float) {
        _uiState.update { it.copy(lookSensitivity = sens) }
    }

    fun toggleAutoFire() {
        _uiState.update { it.copy(autoFireEnabled = !it.autoFireEnabled) }
    }

    fun toggleSound() {
        val newVal = !_uiState.value.soundEnabled
        audio.soundEnabled = newVal
        _uiState.update { it.copy(soundEnabled = newVal) }
    }

    fun toggleHaptic() {
        val newVal = !_uiState.value.hapticEnabled
        audio.hapticEnabled = newVal
        _uiState.update { it.copy(hapticEnabled = newVal) }
    }

    fun togglePause() {
        _uiState.update { it.copy(isPaused = !it.isPaused) }
    }

    fun startOnlineGame() {
        _uiState.update { it.copy(isPracticeMode = false) }
        val host = _uiState.value.serverHost.trim()
        val port = _uiState.value.serverPort
        val name = _uiState.value.username.trim().ifBlank { "Blue" }
        networkClient.connect(host, port, name)
    }

    fun startPracticeMatch() {
        _uiState.update {
            it.copy(
                isPracticeMode = true,
                screenState = GameScreenState.PLAYING,
                connectionStatusText = "Practice Mode (Offline Bots)"
            )
        }
        val name = _uiState.value.username.trim().ifBlank { "Blue" }
        localServer.startPracticeMatch(name)
        renderer.enemyPlayers.clear()
        renderer.enemyPlayers.addAll(localServer.bots.values)
        startGameLoop()
    }

    private fun startGameLoop() {
        gameLoopJob?.cancel()
        // Reset player to spawn point
        val spawn = ArenaMap.SPAWN_POINTS.random()
        playerPos = spawn
        velocityY = 0f
        isGrounded = true
        cameraYaw = 0f
        cameraPitch = 0f
        renderer.playerPosition = playerPos
        renderer.cameraYaw = cameraYaw
        renderer.cameraPitch = cameraPitch

        _uiState.update {
            it.copy(
                health = 250f,
                maxHealth = 250f,
                ammo = 30,
                isReloading = false,
                screenState = GameScreenState.PLAYING
            )
        }

        gameLoopJob = viewModelScope.launch(Dispatchers.Default) {
            var lastTime = System.currentTimeMillis()

            while (isActive) {
                val now = System.currentTimeMillis()
                val dt = ((now - lastTime) / 1000f).coerceIn(0.001f, 0.1f)
                lastTime = now

                if (!_uiState.value.isPaused) {
                    updatePhysics(dt)
                    updateBullets(dt)
                    updateRecoilAndFlash(dt)

                    // Auto-fire or fire button held
                    if (isFireButtonHeld && now >= nextShootTime && _uiState.value.health > 0f) {
                        fireBullet()
                    }

                    // Update scoreboard & enemy sync in practice mode
                    if (_uiState.value.isPracticeMode) {
                        renderer.enemyPlayers.clear()
                        renderer.enemyPlayers.addAll(localServer.bots.values)
                    }

                    // Network player position broadcast (at ~30 Hz)
                    if (!_uiState.value.isPracticeMode && (now - lastNetworkSendTime) > 33) {
                        lastNetworkSendTime = now
                        networkClient.sendPlayer(playerPos, cameraYaw, _uiState.value.health)
                    }

                    updateScoreboard()
                }

                delay(16) // ~60 FPS update
            }
        }
    }

    private fun updatePhysics(dt: Float) {
        if (_uiState.value.health <= 0f) return

        // 1. Horizontal movement from virtual joystick
        val yawRad = Math.toRadians(cameraYaw.toDouble()).toFloat()
        val forwardX = sin(yawRad)
        val forwardZ = cos(yawRad)
        val rightX = cos(yawRad)
        val rightZ = -sin(yawRad)

        val speed = 7.0f // speed = 7 from Ursina player.py
        val moveDirX = (rightX * joystickX + forwardX * joystickY)
        val moveDirZ = (rightZ * joystickX + forwardZ * joystickY)

        val deltaX = moveDirX * speed * dt
        val deltaZ = moveDirZ * speed * dt

        // Sliding collision check: test X and Z separately
        var nextX = playerPos.x + deltaX
        var nextZ = playerPos.z + deltaZ

        val groundElevNext = ArenaMap.getStandingElevation(nextX, nextZ)
        val testPosBoth = Vec3(nextX, groundElevNext, nextZ)

        if (ArenaMap.checkCollision(testPosBoth, radius = 0.45f)) {
            // Try X only
            val testPosX = Vec3(nextX, ArenaMap.getStandingElevation(nextX, playerPos.z), playerPos.z)
            if (!ArenaMap.checkCollision(testPosX, radius = 0.45f)) {
                nextZ = playerPos.z
            } else {
                // Try Z only
                val testPosZ = Vec3(playerPos.x, ArenaMap.getStandingElevation(playerPos.x, nextZ), nextZ)
                if (!ArenaMap.checkCollision(testPosZ, radius = 0.45f)) {
                    nextX = playerPos.x
                } else {
                    nextX = playerPos.x
                    nextZ = playerPos.z
                }
            }
        }

        // 2. Vertical movement & Gravity
        val standingY = ArenaMap.getStandingElevation(nextX, nextZ)
        var currentY = playerPos.y

        if (!isGrounded) {
            val gravity = 24.0f
            velocityY -= gravity * dt
            currentY += velocityY * dt
            if (currentY <= standingY) {
                currentY = standingY
                velocityY = 0f
                isGrounded = true
            }
        } else {
            // Smoothly snap to slope / ramp elevation
            currentY = standingY
        }

        // Void fall check
        if (currentY < -20f) {
            onPlayerDeath()
            return
        }

        playerPos = Vec3(nextX, currentY, nextZ)
        renderer.playerPosition = playerPos
    }

    fun jump() {
        if (isGrounded && _uiState.value.health > 0f) {
            isGrounded = false
            velocityY = 9.5f // jump height matching 2.5 units
        }
    }

    fun onLookDelta(dx: Float, dy: Float) {
        val sens = _uiState.value.lookSensitivity * 0.18f
        cameraYaw = (cameraYaw + dx * sens) % 360f
        cameraPitch = (cameraPitch - dy * sens).coerceIn(-80f, 80f)

        renderer.cameraYaw = cameraYaw
        renderer.cameraPitch = cameraPitch
    }

    fun fireBullet() {
        val state = _uiState.value
        if (state.health <= 0f || state.isReloading) return

        if (state.ammo <= 0) {
            reload()
            return
        }

        nextShootTime = System.currentTimeMillis() + 140 // rapid fire ~7 rounds/sec
        _uiState.update { it.copy(ammo = it.ammo - 1) }

        val yawRad = Math.toRadians(cameraYaw.toDouble()).toFloat()
        val pitchRad = Math.toRadians(cameraPitch.toDouble()).toFloat()

        val speed = 40.0f
        val velocity = Vec3(
            sin(yawRad) * cos(pitchRad) * speed,
            sin(pitchRad) * speed,
            cos(yawRad) * cos(pitchRad) * speed
        )

        val spawnPos = playerPos + Vec3(0f, 1.6f, 0f) + velocity.normalized() * 0.8f
        val damage = Random.nextInt(8, 22)
        val bullet = Bullet(
            id = "bullet_${System.currentTimeMillis()}_${Random.nextInt(1000)}",
            position = spawnPos,
            velocity = velocity,
            directionY = cameraYaw,
            directionX = cameraPitch,
            damage = damage,
            shooterId = networkClient.myId.ifBlank { "local_player" }
        )

        renderer.activeBullets.add(bullet)
        renderer.recoilProgress = 1.0f
        renderer.muzzleFlashAlpha = 1.0f

        audio.playGunshot()

        if (!state.isPracticeMode) {
            networkClient.sendBullet(bullet)
        }
    }

    fun reload() {
        if (_uiState.value.isReloading || _uiState.value.ammo == _uiState.value.maxAmmo) return
        _uiState.update { it.copy(isReloading = true) }
        viewModelScope.launch {
            delay(1200)
            _uiState.update { it.copy(ammo = it.maxAmmo, isReloading = false) }
        }
    }

    private fun updateBullets(dt: Float) {
        val iterator = renderer.activeBullets.iterator()
        while (iterator.hasNext()) {
            val bullet = iterator.next()
            if (bullet.isDestroyed) {
                renderer.activeBullets.remove(bullet)
                continue
            }

            bullet.lifetime -= dt
            if (bullet.lifetime <= 0f) {
                bullet.isDestroyed = true
                renderer.activeBullets.remove(bullet)
                continue
            }

            val nextPos = bullet.position + bullet.velocity * dt

            // 1. Raycast collision with obstacles
            val hitObstacle = ArenaMap.raycastObstacle(bullet.position, nextPos)
            if (hitObstacle != null) {
                bullet.isDestroyed = true
                renderer.activeBullets.remove(bullet)
                continue
            }

            // 2. Collision with enemies (if fired by local player)
            if (bullet.shooterId == (networkClient.myId.ifBlank { "local_player" })) {
                var hitEnemy: RemotePlayer? = null
                for (enemy in renderer.enemyPlayers) {
                    if (enemy.isDead) continue
                    val enemyCenter = enemy.position + Vec3(0f, 1.0f, 0f)
                    if (nextPos.distanceTo(enemyCenter) < 1.0f) {
                        hitEnemy = enemy
                        break
                    }
                }

                if (hitEnemy != null) {
                    bullet.isDestroyed = true
                    renderer.activeBullets.remove(bullet)

                    val isKill = if (_uiState.value.isPracticeMode) {
                        localServer.applyDamageToBot(
                            hitEnemy.id,
                            bullet.damage,
                            _uiState.value.username,
                            _uiState.value.playerColorArgb
                        )
                    } else {
                        val newHp = (hitEnemy.health - bullet.damage).coerceAtLeast(0f)
                        hitEnemy.health = newHp
                        networkClient.sendHealthUpdate(hitEnemy.id, newHp)
                        newHp <= 0f
                    }

                    showHitMarker(isKill)
                    if (isKill) {
                        _uiState.update { it.copy(kills = it.kills + 1) }
                        audio.playKill()
                    } else {
                        audio.playHitMarker()
                    }
                    continue
                }
            }

            // 3. Collision with local player (if fired by enemy or bot)
            if (bullet.shooterId != (networkClient.myId.ifBlank { "local_player" })) {
                val playerCenter = playerPos + Vec3(0f, 1.0f, 0f)
                if (nextPos.distanceTo(playerCenter) < 0.9f && _uiState.value.health > 0f) {
                    bullet.isDestroyed = true
                    renderer.activeBullets.remove(bullet)
                    applyDamageToPlayer(bullet.damage)
                    continue
                }
            }

            bullet.position = nextPos
        }
    }

    private fun applyDamageToPlayer(damage: Int) {
        if (_uiState.value.health <= 0f) return
        val newHealth = (_uiState.value.health - damage).coerceAtLeast(0f)
        _uiState.update { it.copy(health = newHealth, damageFlashAlpha = 0.7f) }
        audio.playDamageTaken()

        if (!_uiState.value.isPracticeMode) {
            networkClient.sendPlayer(playerPos, cameraYaw, newHealth)
        }

        if (newHealth <= 0f) {
            onPlayerDeath()
        }
    }

    private fun onPlayerDeath() {
        _uiState.update {
            it.copy(
                health = 0f,
                deaths = it.deaths + 1,
                screenState = GameScreenState.DEATH_SCREEN,
                respawnTimerSeconds = 5
            )
        }

        // Auto respawn countdown timer
        viewModelScope.launch {
            for (sec in 5 downTo 1) {
                _uiState.update { it.copy(respawnTimerSeconds = sec) }
                delay(1000)
                if (_uiState.value.screenState != GameScreenState.DEATH_SCREEN) return@launch
            }
            respawn()
        }
    }

    fun respawn() {
        if (_uiState.value.screenState != GameScreenState.DEATH_SCREEN && _uiState.value.health > 0f) return

        val newSpawn = ArenaMap.SPAWN_POINTS.random()
        playerPos = newSpawn
        velocityY = 0f
        isGrounded = true
        cameraPitch = 0f

        renderer.playerPosition = playerPos
        renderer.cameraPitch = 0f

        _uiState.update {
            it.copy(
                health = 250f,
                screenState = GameScreenState.PLAYING,
                ammo = 30,
                isReloading = false
            )
        }

        audio.playRespawn()

        if (!_uiState.value.isPracticeMode) {
            networkClient.sendRespawn(newSpawn, 250f)
            networkClient.sendPlayer(playerPos, cameraYaw, 250f)
        }
    }

    private fun showHitMarker(isKill: Boolean) {
        _uiState.update { it.copy(hitMarkerAlpha = 1.0f, hitMarkerIsKill = isKill) }
    }

    private fun updateRecoilAndFlash(dt: Float) {
        if (renderer.recoilProgress > 0f) {
            renderer.recoilProgress = (renderer.recoilProgress - dt * 8f).coerceAtLeast(0f)
        }
        if (renderer.muzzleFlashAlpha > 0f) {
            renderer.muzzleFlashAlpha = (renderer.muzzleFlashAlpha - dt * 14f).coerceAtLeast(0f)
        }
        if (_uiState.value.hitMarkerAlpha > 0f) {
            _uiState.update { it.copy(hitMarkerAlpha = (it.hitMarkerAlpha - dt * 4f).coerceAtLeast(0f)) }
        }
        if (_uiState.value.damageFlashAlpha > 0f) {
            _uiState.update { it.copy(damageFlashAlpha = (it.damageFlashAlpha - dt * 2.5f).coerceAtLeast(0f)) }
        }
    }

    private fun handleNetworkMessage(msg: NetworkMessage) {
        when (msg) {
            is NetworkMessage.PlayerUpdate -> {
                if (msg.id == networkClient.myId) return
                var player = renderer.enemyPlayers.firstOrNull { it.id == msg.id }
                if (msg.left) {
                    if (player != null) renderer.enemyPlayers.remove(player)
                    return
                }

                if (player == null) {
                    val uname = msg.username ?: "Player ${msg.id}"
                    player = RemotePlayer(
                        id = msg.id,
                        username = uname,
                        position = msg.position,
                        targetPosition = msg.position,
                        rotationY = msg.rotationY,
                        health = msg.health
                    )
                    renderer.enemyPlayers.add(player)
                } else {
                    player.position = msg.position
                    player.rotationY = msg.rotationY
                    player.health = msg.health
                    player.isDead = msg.health <= 0f
                }
            }

            is NetworkMessage.PlayerRespawn -> {
                if (msg.id == networkClient.myId) return
                val player = renderer.enemyPlayers.firstOrNull { it.id == msg.id }
                if (player != null) {
                    player.position = msg.position
                    player.health = msg.health
                    player.isDead = false
                }
            }

            is NetworkMessage.BulletSpawn -> {
                val yawRad = Math.toRadians(msg.directionY.toDouble()).toFloat()
                val pitchRad = Math.toRadians(msg.directionX.toDouble()).toFloat()
                val speed = 40f
                val vel = Vec3(
                    sin(yawRad) * cos(pitchRad) * speed,
                    sin(pitchRad) * speed,
                    cos(yawRad) * cos(pitchRad) * speed
                )
                val bullet = Bullet(
                    id = "net_bullet_${System.currentTimeMillis()}_${Random.nextInt(1000)}",
                    position = msg.position,
                    velocity = vel,
                    directionY = msg.directionY,
                    directionX = msg.directionX,
                    damage = msg.damage,
                    shooterId = "remote"
                )
                renderer.activeBullets.add(bullet)
            }

            is NetworkMessage.HealthUpdate -> {
                if (msg.id == networkClient.myId) {
                    val prevHealth = _uiState.value.health
                    if (msg.health < prevHealth) {
                        applyDamageToPlayer((prevHealth - msg.health).toInt())
                    }
                } else {
                    val player = renderer.enemyPlayers.firstOrNull { it.id == msg.id }
                    if (player != null) {
                        player.health = msg.health
                        player.isDead = msg.health <= 0f
                    }
                }
            }
        }
    }

    private fun addDeathFeed(killer: String, killerColor: Long, victim: String, victimColor: Long) {
        val entry = KillFeedEntry(
            killerName = killer,
            killerColor = killerColor,
            victimName = victim,
            victimColor = victimColor
        )
        val currentFeed = _uiState.value.killFeed.takeLast(4).toMutableList()
        currentFeed.add(entry)
        _uiState.update { it.copy(killFeed = currentFeed) }

        // Remove after 4.5 seconds
        viewModelScope.launch {
            delay(4500)
            _uiState.update { state ->
                state.copy(killFeed = state.killFeed.filter { it.id != entry.id })
            }
        }
    }

    private fun updateScoreboard() {
        val list = mutableListOf<ScoreEntry>()
        list.add(
            ScoreEntry(
                id = networkClient.myId.ifBlank { "local" },
                name = _uiState.value.username,
                colorArgb = _uiState.value.playerColorArgb,
                kills = _uiState.value.kills,
                deaths = _uiState.value.deaths,
                health = _uiState.value.health.toInt(),
                isLocalPlayer = true
            )
        )

        for (p in renderer.enemyPlayers) {
            list.add(
                ScoreEntry(
                    id = p.id,
                    name = p.username,
                    colorArgb = p.colorArgb,
                    kills = p.kills,
                    deaths = p.deaths,
                    health = p.health.toInt(),
                    isLocalPlayer = false
                )
            )
        }

        // Sort by kills descending
        list.sortByDescending { it.kills }
        _uiState.update { it.copy(scoreboard = list) }
    }

    fun returnToLobby() {
        gameLoopJob?.cancel()
        networkClient.disconnect()
        localServer.stop()
        renderer.enemyPlayers.clear()
        renderer.activeBullets.clear()
        _uiState.update { it.copy(screenState = GameScreenState.LOBBY, isPaused = false) }
    }

    override fun onCleared() {
        super.onCleared()
        returnToLobby()
    }
}
