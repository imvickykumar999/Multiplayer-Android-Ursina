package com.example.game.ui

import android.opengl.GLSurfaceView
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.example.game.viewmodel.GameViewModel

/**
 * 3D FPS Game Screen combining hardware-accelerated OpenGL GLSurfaceView
 * with touch controls and overlay HUD.
 */
@Composable
fun GameScreen(
    viewModel: GameViewModel,
    uiState: com.example.game.viewmodel.GameUiState
) {
    val context = LocalContext.current
    val glView = remember {
        GLSurfaceView(context).apply {
            setEGLContextClientVersion(2)
            setRenderer(viewModel.renderer)
            renderMode = GLSurfaceView.RENDERMODE_CONTINUOUSLY
        }
    }

    DisposableEffect(glView) {
        glView.onResume()
        onDispose {
            glView.onPause()
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        // 1. OpenGL 3D Render Surface
        AndroidView(
            factory = { glView },
            modifier = Modifier.fillMaxSize()
        )

        // 2. Touch Look Area (Right 65% of screen for camera aiming)
        TouchLookArea(
            modifier = Modifier
                .fillMaxHeight()
                .fillMaxSize(0.65f)
                .align(Alignment.CenterEnd),
            onLookDelta = { dx, dy ->
                viewModel.onLookDelta(dx, dy)
            }
        )

        // 3. Virtual Analog Joystick (Bottom-Left)
        VirtualJoystick(
            modifier = Modifier
                .align(Alignment.BottomStart)
                .padding(start = 28.dp, bottom = 28.dp),
            sizeDp = 140,
            onMove = { normX, normY ->
                viewModel.joystickX = normX
                viewModel.joystickY = normY
            }
        )

        // 4. Action Controls (Bottom-Right)
        // Jump Button
        JumpButton(
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(end = 124.dp, bottom = 28.dp),
            onJump = { viewModel.jump() }
        )

        // Reload Button
        ReloadButton(
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(end = 114.dp, bottom = 96.dp),
            isReloading = uiState.isReloading,
            onReload = { viewModel.reload() }
        )

        // Primary Fire Button
        FireButton(
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(end = 28.dp, bottom = 28.dp),
            onFirePress = { isPressed ->
                viewModel.isFireButtonHeld = isPressed
                if (isPressed) {
                    viewModel.fireBullet()
                }
            }
        )

        // 5. HUD: Health, Crosshair, Radar, Death Screen, Pause Menu
        GameHUD(
            uiState = uiState,
            playerPos = viewModel.playerPos,
            cameraYaw = viewModel.cameraYaw,
            enemies = viewModel.renderer.enemyPlayers,
            onJump = { viewModel.jump() },
            onFirePress = { isPressed ->
                viewModel.isFireButtonHeld = isPressed
                if (isPressed) viewModel.fireBullet()
            },
            onReload = { viewModel.reload() },
            onRespawn = { viewModel.respawn() },
            onTogglePause = { viewModel.togglePause() },
            onSensitivityChange = { viewModel.setLookSensitivity(it) },
            onToggleSound = { viewModel.toggleSound() },
            onToggleHaptic = { viewModel.toggleHaptic() },
            onToggleAutoFire = { viewModel.toggleAutoFire() },
            onLeaveGame = { viewModel.returnToLobby() }
        )
    }
}
