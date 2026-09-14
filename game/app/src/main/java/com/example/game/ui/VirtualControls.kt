package com.example.game.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Responsive Virtual Analog Joystick for movement.
 */
@Composable
fun VirtualJoystick(
    modifier: Modifier = Modifier,
    sizeDp: Int = 140,
    onMove: (x: Float, y: Float) -> Unit
) {
    var thumbOffset by remember { mutableStateOf(Offset.Zero) }
    val maxRadius = (sizeDp / 2f) * 0.7f

    Box(
        modifier = modifier
            .size(sizeDp.dp)
            .testTag("virtual_joystick")
            .clip(CircleShape)
            .background(
                Brush.radialGradient(
                    colors = listOf(Color(0x551E293B), Color(0x990F172A))
                )
            )
            .border(2.dp, Color(0x6638BDF8), CircleShape)
            .pointerInput(Unit) {
                detectDragGestures(
                    onDragStart = { offset ->
                        val center = Offset(size.width / 2f, size.height / 2f)
                        val delta = offset - center
                        val dist = delta.getDistance()
                        val clampedDist = dist.coerceAtMost(maxRadius)
                        val angle = atan2(delta.y.toDouble(), delta.x.toDouble())
                        thumbOffset = Offset(
                            (cos(angle) * clampedDist).toFloat(),
                            (sin(angle) * clampedDist).toFloat()
                        )
                        val normX = (thumbOffset.x / maxRadius).coerceIn(-1f, 1f)
                        val normY = -(thumbOffset.y / maxRadius).coerceIn(-1f, 1f)
                        onMove(normX, normY)
                    },
                    onDrag = { change, dragAmount ->
                        change.consume()
                        val newOffset = thumbOffset + dragAmount
                        val dist = newOffset.getDistance()
                        val clampedDist = dist.coerceAtMost(maxRadius)
                        val angle = atan2(newOffset.y.toDouble(), newOffset.x.toDouble())
                        thumbOffset = Offset(
                            (cos(angle) * clampedDist).toFloat(),
                            (sin(angle) * clampedDist).toFloat()
                        )
                        val normX = (thumbOffset.x / maxRadius).coerceIn(-1f, 1f)
                        val normY = -(thumbOffset.y / maxRadius).coerceIn(-1f, 1f)
                        onMove(normX, normY)
                    },
                    onDragEnd = {
                        thumbOffset = Offset.Zero
                        onMove(0f, 0f)
                    },
                    onDragCancel = {
                        thumbOffset = Offset.Zero
                        onMove(0f, 0f)
                    }
                )
            },
        contentAlignment = Alignment.Center
    ) {
        // Center deadzone ring
        Box(
            modifier = Modifier
                .size((sizeDp * 0.35f).dp)
                .border(1.dp, Color(0x3338BDF8), CircleShape)
        )

        // Thumb knob
        Box(
            modifier = Modifier
                .offset { IntOffset(thumbOffset.x.toInt(), thumbOffset.y.toInt()) }
                .size((sizeDp * 0.42f).dp)
                .shadow(6.dp, CircleShape)
                .clip(CircleShape)
                .background(
                    Brush.radialGradient(
                        colors = listOf(Color(0xFF38BDF8), Color(0xFF0284C7))
                    )
                )
                .border(2.dp, Color(0xCCBAE6FD), CircleShape)
        )
    }
}

/**
 * Transparent look-touch drag zone for camera aiming.
 */
@Composable
fun TouchLookArea(
    modifier: Modifier = Modifier,
    onLookDelta: (dx: Float, dy: Float) -> Unit
) {
    Box(
        modifier = modifier
            .testTag("touch_look_area")
            .pointerInput(Unit) {
                detectDragGestures { change, dragAmount ->
                    change.consume()
                    onLookDelta(dragAmount.x, dragAmount.y)
                }
            }
    )
}

/**
 * Primary Fire Button with glowing activation.
 */
@Composable
fun FireButton(
    modifier: Modifier = Modifier,
    onFirePress: (isPressed: Boolean) -> Unit
) {
    var isPressed by remember { mutableStateOf(false) }

    Box(
        modifier = modifier
            .size(76.dp)
            .testTag("fire_button")
            .shadow(if (isPressed) 12.dp else 6.dp, CircleShape)
            .clip(CircleShape)
            .background(
                Brush.radialGradient(
                    colors = if (isPressed) {
                        listOf(Color(0xFFFF5252), Color(0xFFB71C1C))
                    } else {
                        listOf(Color(0xFFEF4444), Color(0xFF991B1B))
                    }
                )
            )
            .border(
                3.dp,
                if (isPressed) Color(0xFFFFF176) else Color(0xFFFF8A80),
                CircleShape
            )
            .pointerInput(Unit) {
                detectTapGestures(
                    onPress = {
                        isPressed = true
                        onFirePress(true)
                        tryAwaitRelease()
                        isPressed = false
                        onFirePress(false)
                    }
                )
            },
        contentAlignment = Alignment.Center
    ) {
        // Crosshair icon inside fire button
        Box(
            modifier = Modifier
                .size(36.dp)
                .border(2.dp, Color.White, CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .background(Color.White, CircleShape)
            )
        }
    }
}

/**
 * Jump Button.
 */
@Composable
fun JumpButton(
    modifier: Modifier = Modifier,
    onJump: () -> Unit
) {
    Box(
        modifier = modifier
            .size(56.dp)
            .testTag("jump_button")
            .shadow(4.dp, CircleShape)
            .clip(CircleShape)
            .background(
                Brush.radialGradient(
                    colors = listOf(Color(0xFF3B82F6), Color(0xFF1D4ED8))
                )
            )
            .border(2.dp, Color(0xFF93C5FD), CircleShape)
            .pointerInput(Unit) {
                detectTapGestures(onTap = { onJump() })
            },
        contentAlignment = Alignment.Center
    ) {
        Icon(
            imageVector = Icons.Default.ArrowUpward,
            contentDescription = "Jump",
            tint = Color.White,
            modifier = Modifier.size(28.dp)
        )
    }
}

/**
 * Reload Button.
 */
@Composable
fun ReloadButton(
    modifier: Modifier = Modifier,
    isReloading: Boolean,
    onReload: () -> Unit
) {
    Box(
        modifier = modifier
            .size(48.dp)
            .testTag("reload_button")
            .clip(CircleShape)
            .background(Color(0x881E293B))
            .border(1.5.dp, if (isReloading) Color(0xFFFBBF24) else Color(0x6694A3B8), CircleShape)
            .pointerInput(Unit) {
                detectTapGestures(onTap = { onReload() })
            },
        contentAlignment = Alignment.Center
    ) {
        Icon(
            imageVector = Icons.Default.Refresh,
            contentDescription = "Reload",
            tint = if (isReloading) Color(0xFFFBBF24) else Color.White,
            modifier = Modifier.size(24.dp)
        )
    }
}
