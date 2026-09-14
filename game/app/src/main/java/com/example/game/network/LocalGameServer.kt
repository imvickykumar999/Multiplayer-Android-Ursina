package com.example.game.network

import com.example.game.arena.ArenaMap
import com.example.game.model.Bullet
import com.example.game.model.GamePalette
import com.example.game.model.RemotePlayer
import com.example.game.model.Vec3
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.net.ServerSocket
import java.net.Socket
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.random.Random

/**
 * Built-in local deathmatch host & AI Bot simulator.
 * Allows instant offline practice against 4 dynamic bots or hosting for local peers.
 */
class LocalGameServer(
    private val scope: CoroutineScope
) {
    private var serverJob: Job? = null
    private var botJob: Job? = null
    private var serverSocket: ServerSocket? = null

    val bots = ConcurrentHashMap<String, RemotePlayer>()
    private val botNextShootTimes = ConcurrentHashMap<String, Long>()
    private val botTargetWaypoints = ConcurrentHashMap<String, Vec3>()
    private val botRespawnTimers = ConcurrentHashMap<String, Float>()

    // Callback when bot fires a bullet or changes health
    var onBotSpawnBullet: ((Bullet) -> Unit)? = null
    var onPlayerKilled: ((killer: String, killerColor: Long, victim: String, victimColor: Long) -> Unit)? = null

    var isRunning: Boolean = false
        private set

    // Waypoints for bot patrol across Ground Floor, Stairs, and Mezzanine
    private val waypoints = listOf(
        Vec3(0f, 1f, 0f),
        Vec3(10f, 1f, 10f),
        Vec3(-10f, 1f, 10f),
        Vec3(10f, 1f, -10f),
        Vec3(-10f, 1f, -10f),
        // Stair entries
        Vec3(8.5f, 1.25f, -3.5f),
        Vec3(-8.5f, 1.25f, 3.5f),
        // Upper Deck Mezzanine
        Vec3(0f, 6f, 13f),
        Vec3(0f, 6f, -13f),
        Vec3(16f, 6f, 0f),
        Vec3(-16f, 6f, 0f)
    )

    fun startPracticeMatch(humanPlayerName: String) {
        stop()
        isRunning = true
        bots.clear()
        botNextShootTimes.clear()
        botTargetWaypoints.clear()
        botRespawnTimers.clear()

        // Spawn 4 distinct AI bots with colors from palette
        val botConfigs = listOf(
            Pair("Turquoise", "Turquoise"),
            Pair("Orange", "Orange"),
            Pair("Pink", "Pink"),
            Pair("Lime", "Lime")
        )

        for ((index, config) in botConfigs.withIndex()) {
            val botId = "bot_${index + 1}"
            val name = config.first
            val color = GamePalette.getPlayerColor(botId, config.second)
            val spawnPos = ArenaMap.SPAWN_POINTS[index % ArenaMap.SPAWN_POINTS.size]
            val bot = RemotePlayer(
                id = botId,
                username = "$name (Bot)",
                position = spawnPos,
                targetPosition = spawnPos,
                rotationY = Random.nextFloat() * 360f,
                health = 250f,
                colorArgb = color,
                isBot = true
            )
            bots[botId] = bot
            botTargetWaypoints[botId] = waypoints.random()
            botNextShootTimes[botId] = System.currentTimeMillis() + Random.nextLong(1000, 3000)
        }

        startBotLoop()
    }

    private fun startBotLoop() {
        botJob = scope.launch(Dispatchers.Default) {
            var lastTime = System.currentTimeMillis()

            while (isActive && isRunning) {
                val currentTime = System.currentTimeMillis()
                val dt = (currentTime - lastTime) / 1000f
                lastTime = currentTime

                for (bot in bots.values) {
                    if (bot.isDead) {
                        val remaining = (botRespawnTimers[bot.id] ?: 0f) - dt
                        if (remaining <= 0f) {
                            // Respawn bot
                            bot.isDead = false
                            bot.health = 250f
                            val newSpawn = ArenaMap.SPAWN_POINTS.random()
                            bot.position = newSpawn
                            bot.targetPosition = newSpawn
                            botTargetWaypoints[bot.id] = waypoints.random()
                            botRespawnTimers.remove(bot.id)
                        } else {
                            botRespawnTimers[bot.id] = remaining
                        }
                        continue
                    }

                    // Bot Movement AI
                    var targetWp = botTargetWaypoints[bot.id]
                    if (targetWp == null || bot.position.distanceTo(targetWp) < 2.0f) {
                        targetWp = waypoints.random()
                        botTargetWaypoints[bot.id] = targetWp
                    }

                    val toTarget = targetWp - bot.position
                    val angleRad = atan2(toTarget.x.toDouble(), toTarget.z.toDouble()).toFloat()
                    val targetRotDeg = Math.toDegrees(angleRad.toDouble()).toFloat()
                    bot.rotationY = targetRotDeg

                    val speed = 5.0f
                    val moveX = sin(angleRad) * speed * dt
                    val moveZ = cos(angleRad) * speed * dt

                    val newX = (bot.position.x + moveX).coerceIn(-19f, 19f)
                    val newZ = (bot.position.z + moveZ).coerceIn(-19f, 19f)
                    val groundY = ArenaMap.getStandingElevation(newX, newZ)

                    val newPos = Vec3(newX, groundY, newZ)
                    if (!ArenaMap.checkCollision(newPos, radius = 0.5f)) {
                        bot.position = newPos
                        bot.targetPosition = newPos
                    } else {
                        // Pick a different waypoint if stuck
                        botTargetWaypoints[bot.id] = waypoints.random()
                    }

                    // Bot Shooting logic
                    val nextShoot = botNextShootTimes[bot.id] ?: 0L
                    if (currentTime >= nextShoot) {
                        botNextShootTimes[bot.id] = currentTime + Random.nextLong(1200, 2600)

                        // Shoot in facing direction with slight pitch
                        val pitch = Random.nextFloat() * 6f - 3f
                        val radYaw = Math.toRadians(bot.rotationY.toDouble()).toFloat()
                        val radPitch = Math.toRadians(pitch.toDouble()).toFloat()

                        val bulletSpeed = 38f
                        val velocity = Vec3(
                            sin(radYaw) * cos(radPitch) * bulletSpeed,
                            sin(radPitch) * bulletSpeed,
                            cos(radYaw) * cos(radPitch) * bulletSpeed
                        )
                        val spawnPos = bot.position + Vec3(0f, 1.5f, 0f) + velocity.normalized() * 0.8f
                        val bullet = Bullet(
                            id = "bot_bullet_${System.currentTimeMillis()}_${Random.nextInt(1000)}",
                            position = spawnPos,
                            velocity = velocity,
                            directionY = bot.rotationY,
                            directionX = pitch,
                            damage = Random.nextInt(8, 20),
                            shooterId = bot.id
                        )
                        onBotSpawnBullet?.invoke(bullet)
                    }
                }

                delay(33) // ~30 Hz bot tick
            }
        }
    }

    fun applyDamageToBot(botId: String, damage: Int, attackerName: String, attackerColor: Long): Boolean {
        val bot = bots[botId] ?: return false
        if (bot.isDead) return false

        bot.health = (bot.health - damage).coerceAtLeast(0f)
        if (bot.health <= 0f) {
            bot.isDead = true
            bot.deaths++
            botRespawnTimers[bot.id] = 5.0f // 5-second respawn matching Ursina spec
            onPlayerKilled?.invoke(attackerName, attackerColor, bot.username, bot.colorArgb)
            return true // killed
        }
        return false // hit
    }

    fun stop() {
        isRunning = false
        botJob?.cancel()
        serverJob?.cancel()
        try {
            serverSocket?.close()
        } catch (_: Exception) {
        }
        serverSocket = null
        bots.clear()
    }
}
