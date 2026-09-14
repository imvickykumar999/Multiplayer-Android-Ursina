package com.example.game.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.VolumeOff
import androidx.compose.material.icons.filled.VolumeUp
import androidx.compose.material.icons.filled.Vibration
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.game.model.Vec3
import com.example.game.viewmodel.GameScreenState
import com.example.game.viewmodel.GameUiState
import kotlin.math.cos
import kotlin.math.sin

/**
 * In-game Heads-Up Display:
 * Health gauge, ammo counter, crosshair with hit markers, radar, kill feed, and death screen.
 */
@Composable
fun GameHUD(
    uiState: GameUiState,
    playerPos: Vec3,
    cameraYaw: Float,
    enemies: List<com.example.game.model.RemotePlayer>,
    onJump: () -> Unit,
    onFirePress: (Boolean) -> Unit,
    onReload: () -> Unit,
    onRespawn: () -> Unit,
    onTogglePause: () -> Unit,
    onSensitivityChange: (Float) -> Unit,
    onToggleSound: () -> Unit,
    onToggleHaptic: () -> Unit,
    onToggleAutoFire: () -> Unit,
    onLeaveGame: () -> Unit
) {
    Box(modifier = Modifier.fillMaxSize()) {

        // 1. Damage Flash Vignette
        if (uiState.damageFlashAlpha > 0.02f) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color(0xFFDC2626).copy(alpha = uiState.damageFlashAlpha * 0.45f))
            )
        }

        // 2. Crosshair & Hit Marker
        CrosshairView(
            modifier = Modifier.align(Alignment.Center),
            hitMarkerAlpha = uiState.hitMarkerAlpha,
            isKill = uiState.hitMarkerIsKill
        )

        // 3. Top Status Bar: Health, Username, Stats, Radar
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.Top
        ) {
            // Left: Player info & Health Bar
            Column {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier = Modifier
                            .size(14.dp)
                            .clip(CircleShape)
                            .background(Color(uiState.playerColorArgb))
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = uiState.username,
                        color = Color.White,
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
                Spacer(modifier = Modifier.height(4.dp))
                // Health Bar
                val healthRatio = (uiState.health / uiState.maxHealth).coerceIn(0f, 1f)
                val healthColor = when {
                    healthRatio > 0.5f -> Color(0xFF22C55E)
                    healthRatio > 0.25f -> Color(0xFFEAB308)
                    else -> Color(0xFFEF4444)
                }
                Box(
                    modifier = Modifier
                        .width(180.dp)
                        .height(18.dp)
                        .clip(RoundedCornerShape(4.dp))
                        .background(Color(0x770F172A))
                        .border(1.dp, Color(0x6694A3B8), RoundedCornerShape(4.dp))
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth(healthRatio)
                            .height(18.dp)
                            .background(
                                Brush.horizontalGradient(
                                    listOf(healthColor.copy(alpha = 0.8f), healthColor)
                                )
                            )
                    )
                    Text(
                        text = "${uiState.health.toInt()} / ${uiState.maxHealth.toInt()} HP",
                        color = Color.White,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier
                            .align(Alignment.Center)
                            .padding(horizontal = 4.dp)
                    )
                }

                // Kill Feed
                Spacer(modifier = Modifier.height(8.dp))
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    for (entry in uiState.killFeed) {
                        Row(
                            modifier = Modifier
                                .background(Color(0x880F172A), RoundedCornerShape(4.dp))
                                .padding(horizontal = 6.dp, vertical = 2.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = entry.killerName,
                                color = Color(entry.killerColor),
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold
                            )
                            Text(
                                text = " ➔ ",
                                color = Color.LightGray,
                                fontSize = 11.sp
                            )
                            Text(
                                text = entry.victimName,
                                color = Color(entry.victimColor),
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }
                }
            }

            // Center: Match Stats
            Card(
                colors = CardDefaults.cardColors(containerColor = Color(0x880F172A)),
                shape = RoundedCornerShape(8.dp),
                border = CardDefaults.outlinedCardBorder().copy(brush = Brush.linearGradient(listOf(Color(0x4438BDF8), Color(0x4438BDF8))))
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 14.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("KILLS", color = Color(0xFF94A3B8), fontSize = 10.sp, fontWeight = FontWeight.SemiBold)
                        Text("${uiState.kills}", color = Color(0xFF38BDF8), fontSize = 16.sp, fontWeight = FontWeight.Bold)
                    }
                    Box(modifier = Modifier.width(1.dp).height(24.dp).background(Color(0x4494A3B8)))
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("DEATHS", color = Color(0xFF94A3B8), fontSize = 10.sp, fontWeight = FontWeight.SemiBold)
                        Text("${uiState.deaths}", color = Color(0xFFEF4444), fontSize = 16.sp, fontWeight = FontWeight.Bold)
                    }
                }
            }

            // Right: Radar & Pause
            Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                // Mini Radar
                MiniRadar(
                    playerPos = playerPos,
                    cameraYaw = cameraYaw,
                    enemies = enemies,
                    modifier = Modifier.size(76.dp)
                )

                // Pause / Settings Button
                IconButton(
                    onClick = onTogglePause,
                    modifier = Modifier
                        .testTag("pause_button")
                        .size(38.dp)
                        .clip(CircleShape)
                        .background(Color(0x880F172A))
                        .border(1.dp, Color(0x4494A3B8), CircleShape)
                ) {
                    Icon(
                        imageVector = Icons.Default.Pause,
                        contentDescription = "Menu",
                        tint = Color.White,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }
        }

        // 4. Bottom HUD: Ammo Counter
        Box(
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(end = 120.dp, bottom = 24.dp)
        ) {
            Card(
                colors = CardDefaults.cardColors(containerColor = Color(0x880F172A)),
                shape = RoundedCornerShape(8.dp),
                border = CardDefaults.outlinedCardBorder().copy(brush = Brush.linearGradient(listOf(Color(0x44F97316), Color(0x44F97316))))
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 14.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = if (uiState.isReloading) "RELOADING..." else "${uiState.ammo}",
                        color = if (uiState.isReloading) Color(0xFFFBBF24) else if (uiState.ammo <= 5) Color(0xFFEF4444) else Color.White,
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Black
                    )
                    if (!uiState.isReloading) {
                        Text(
                            text = " / ${uiState.maxAmmo}",
                            color = Color(0xFF94A3B8),
                            fontSize = 14.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }
            }
        }

        // 5. Death Screen Overlay
        if (uiState.screenState == GameScreenState.DEATH_SCREEN) {
            DeathScreenOverlay(
                secondsLeft = uiState.respawnTimerSeconds,
                onRespawn = onRespawn
            )
        }

        // 6. Pause / Scoreboard Dialog
        if (uiState.isPaused) {
            PauseMenuDialog(
                uiState = uiState,
                onResume = onTogglePause,
                onSensitivityChange = onSensitivityChange,
                onToggleSound = onToggleSound,
                onToggleHaptic = onToggleHaptic,
                onToggleAutoFire = onToggleAutoFire,
                onLeaveGame = onLeaveGame
            )
        }
    }
}

/**
 * Crosshairs and dynamic Hit Marker.
 */
@Composable
fun CrosshairView(
    modifier: Modifier = Modifier,
    hitMarkerAlpha: Float,
    isKill: Boolean
) {
    Canvas(modifier = modifier.size(44.dp).testTag("crosshair_view")) {
        val cx = size.width / 2f
        val cy = size.height / 2f
        val gap = 6.dp.toPx()
        val len = 8.dp.toPx()
        val color = Color.White.copy(alpha = 0.85f)
        val strokeWidth = 2.dp.toPx()

        // Crosshair lines
        drawLine(color, Offset(cx - gap - len, cy), Offset(cx - gap, cy), strokeWidth)
        drawLine(color, Offset(cx + gap, cy), Offset(cx + gap + len, cy), strokeWidth)
        drawLine(color, Offset(cx, cy - gap - len), Offset(cx, cy - gap), strokeWidth)
        drawLine(color, Offset(cx, cy + gap), Offset(cx, cy + gap + len), strokeWidth)

        // Center dot
        drawCircle(color, 1.5.dp.toPx(), Offset(cx, cy))

        // Hit Marker 'X'
        if (hitMarkerAlpha > 0.05f) {
            val hmColor = if (isKill) Color(0xFFFF2222) else Color(0xFFFFFFFF)
            val hmLen = 9.dp.toPx()
            val hmGap = 4.dp.toPx()
            val hmAlpha = hitMarkerAlpha.coerceIn(0f, 1f)

            // 4 diagonal tick marks
            drawLine(hmColor.copy(alpha = hmAlpha), Offset(cx - hmGap, cy - hmGap), Offset(cx - hmGap - hmLen, cy - hmGap - hmLen), 3.dp.toPx())
            drawLine(hmColor.copy(alpha = hmAlpha), Offset(cx + hmGap, cy - hmGap), Offset(cx + hmGap + hmLen, cy - hmGap - hmLen), 3.dp.toPx())
            drawLine(hmColor.copy(alpha = hmAlpha), Offset(cx - hmGap, cy + hmGap), Offset(cx - hmGap - hmLen, cy + hmGap + hmLen), 3.dp.toPx())
            drawLine(hmColor.copy(alpha = hmAlpha), Offset(cx + hmGap, cy + hmGap), Offset(cx + hmGap + hmLen, cy + hmGap + hmLen), 3.dp.toPx())
        }
    }
}

/**
 * 2D Mini Radar showing arena layout, player heading, and enemy blips.
 */
@Composable
fun MiniRadar(
    playerPos: Vec3,
    cameraYaw: Float,
    enemies: List<com.example.game.model.RemotePlayer>,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .clip(CircleShape)
            .background(Color(0x990F172A))
            .border(1.5.dp, Color(0x6638BDF8), CircleShape)
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val cx = size.width / 2f
            val cy = size.height / 2f
            val radius = size.width / 2f

            // Arena boundary circle
            drawCircle(Color(0x3338BDF8), radius = radius - 2f, style = Stroke(1.dp.toPx()))

            // Draw enemies relative to player
            val arenaHalfSize = 20f
            val scale = (radius - 8.dp.toPx()) / arenaHalfSize

            for (enemy in enemies) {
                if (enemy.isDead) continue
                val dx = (enemy.position.x - playerPos.x) * scale
                val dz = (enemy.position.z - playerPos.z) * scale

                // Rotate by camera yaw so radar matches player's forward view
                val yawRad = Math.toRadians(-cameraYaw.toDouble())
                val rx = (dx * cos(yawRad) - dz * sin(yawRad)).toFloat()
                val ry = (dx * sin(yawRad) + dz * cos(yawRad)).toFloat()

                val enemyX = cx + rx
                val enemyY = cy - ry

                if (rx * rx + ry * ry < (radius - 4.dp.toPx()) * (radius - 4.dp.toPx())) {
                    drawCircle(Color(enemy.colorArgb), radius = 3.dp.toPx(), center = Offset(enemyX, enemyY))
                }
            }

            // Player dot and heading pointer in center
            drawCircle(Color(0xFF38BDF8), radius = 3.5.dp.toPx(), center = Offset(cx, cy))
            // Heading triangle forward (pointing UP on radar)
            val path = Path().apply {
                moveTo(cx, cy - 8.dp.toPx())
                lineTo(cx - 4.dp.toPx(), cy - 2.dp.toPx())
                lineTo(cx + 4.dp.toPx(), cy - 2.dp.toPx())
                close()
            }
            drawPath(path, Color(0xFF38BDF8))
        }
    }
}

/**
 * "YOU DIED" death screen overlay matching Python Ursina player.death().
 */
@Composable
fun DeathScreenOverlay(
    secondsLeft: Int,
    onRespawn: () -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xDD090D16))
            .testTag("death_screen_overlay"),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Text(
                text = "YOU DIED",
                color = Color(0xFFEF4444),
                fontSize = 42.sp,
                fontWeight = FontWeight.Black,
                letterSpacing = 4.sp
            )

            Text(
                text = "Auto-respawn in ${secondsLeft}s...",
                color = Color(0xFF94A3B8),
                fontSize = 16.sp
            )

            Button(
                onClick = onRespawn,
                modifier = Modifier
                    .testTag("respawn_button")
                    .height(48.dp)
                    .width(180.dp),
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF0284C7)),
                shape = RoundedCornerShape(8.dp)
            ) {
                Text("RESPAWN NOW", color = Color.White, fontWeight = FontWeight.Bold)
            }
        }
    }
}

/**
 * Pause Menu and Match Scoreboard dialog.
 */
@Composable
fun PauseMenuDialog(
    uiState: GameUiState,
    onResume: () -> Unit,
    onSensitivityChange: (Float) -> Unit,
    onToggleSound: () -> Unit,
    onToggleHaptic: () -> Unit,
    onToggleAutoFire: () -> Unit,
    onLeaveGame: () -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xCC090D16))
            .testTag("pause_menu_dialog"),
        contentAlignment = Alignment.Center
    ) {
        Card(
            modifier = Modifier
                .fillMaxWidth(0.85f)
                .padding(16.dp),
            colors = CardDefaults.cardColors(containerColor = Color(0xFF0F172A)),
            shape = RoundedCornerShape(16.dp),
            border = CardDefaults.outlinedCardBorder().copy(brush = Brush.linearGradient(listOf(Color(0xFF38BDF8), Color(0xFF0284C7))))
        ) {
            Column(
                modifier = Modifier.padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                // Header
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "MATCH STATS & SETTINGS",
                        color = Color.White,
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold
                    )
                    IconButton(onClick = onResume, modifier = Modifier.size(32.dp)) {
                        Icon(Icons.Default.Close, contentDescription = "Close", tint = Color.LightGray)
                    }
                }

                // Scoreboard Table
                Text("LEADERBOARD", color = Color(0xFF38BDF8), fontSize = 12.sp, fontWeight = FontWeight.Bold)
                LazyColumn(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(110.dp)
                ) {
                    items(uiState.scoreboard) { entry ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 3.dp)
                                .background(if (entry.isLocalPlayer) Color(0x3338BDF8) else Color(0x11FFFFFF), RoundedCornerShape(4.dp))
                                .padding(horizontal = 8.dp, vertical = 4.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Box(modifier = Modifier.size(10.dp).clip(CircleShape).background(Color(entry.colorArgb)))
                                Spacer(modifier = Modifier.width(6.dp))
                                Text(
                                    text = entry.name + if (entry.isLocalPlayer) " (You)" else "",
                                    color = Color.White,
                                    fontSize = 12.sp,
                                    fontWeight = if (entry.isLocalPlayer) FontWeight.Bold else FontWeight.Normal
                                )
                            }
                            Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                                Text("K: ${entry.kills}", color = Color(0xFF38BDF8), fontSize = 12.sp, fontWeight = FontWeight.Bold)
                                Text("D: ${entry.deaths}", color = Color(0xFFEF4444), fontSize = 12.sp)
                                Text("HP: ${entry.health}", color = Color(0xFF22C55E), fontSize = 12.sp)
                            }
                        }
                    }
                }

                // Controls and Settings
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("Look Sensitivity", color = Color.White, fontSize = 13.sp)
                    Slider(
                        value = uiState.lookSensitivity,
                        onValueChange = onSensitivityChange,
                        valueRange = 0.4f..2.5f,
                        modifier = Modifier.width(180.dp),
                        colors = SliderDefaults.colors(thumbColor = Color(0xFF38BDF8), activeTrackColor = Color(0xFF38BDF8))
                    )
                }

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text("Sound", color = Color.White, fontSize = 13.sp)
                            Spacer(modifier = Modifier.width(6.dp))
                            Switch(
                                checked = uiState.soundEnabled,
                                onCheckedChange = { onToggleSound() },
                                colors = SwitchDefaults.colors(checkedThumbColor = Color(0xFF38BDF8))
                            )
                        }
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text("Haptics", color = Color.White, fontSize = 13.sp)
                            Spacer(modifier = Modifier.width(6.dp))
                            Switch(
                                checked = uiState.hapticEnabled,
                                onCheckedChange = { onToggleHaptic() },
                                colors = SwitchDefaults.colors(checkedThumbColor = Color(0xFF38BDF8))
                            )
                        }
                    }

                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        Button(
                            onClick = onLeaveGame,
                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFEF4444)),
                            shape = RoundedCornerShape(8.dp)
                        ) {
                            Text("Leave Match", color = Color.White, fontSize = 12.sp)
                        }
                        Button(
                            onClick = onResume,
                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF0284C7)),
                            shape = RoundedCornerShape(8.dp)
                        ) {
                            Text("Resume", color = Color.White, fontSize = 12.sp)
                        }
                    }
                }
            }
        }
    }
}
