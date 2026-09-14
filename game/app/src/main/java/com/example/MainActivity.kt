package com.example

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import com.example.game.ui.GameScreen
import com.example.game.ui.LobbyScreen
import com.example.game.viewmodel.GameScreenState
import com.example.game.viewmodel.GameViewModel
import com.example.ui.theme.MyApplicationTheme

class MainActivity : ComponentActivity() {

    private val viewModel: GameViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        // Immersive sticky full screen for tactical shooter
        WindowCompat.setDecorFitsSystemWindows(window, false)
        val insetsController = WindowCompat.getInsetsController(window, window.decorView)
        insetsController.systemBarsBehavior =
            WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        insetsController.hide(WindowInsetsCompat.Type.systemBars())

        setContent {
            MyApplicationTheme(darkTheme = true) {
                val uiState by viewModel.uiState.collectAsState()

                BackHandler(enabled = uiState.screenState != GameScreenState.LOBBY) {
                    if (uiState.isPaused) {
                        viewModel.returnToLobby()
                    } else {
                        viewModel.togglePause()
                    }
                }

                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(Color(0xFF040812))
                ) {
                    when (uiState.screenState) {
                        GameScreenState.LOBBY, GameScreenState.CONNECTING -> {
                            LobbyScreen(
                                uiState = uiState,
                                onUsernameChange = { viewModel.setUsername(it) },
                                onServerHostChange = { viewModel.setServerHost(it) },
                                onServerPortChange = { viewModel.setServerPort(it) },
                                onStartOnline = { viewModel.startOnlineGame() },
                                onStartPractice = { viewModel.startPracticeMatch() }
                            )
                        }

                        GameScreenState.PLAYING, GameScreenState.DEATH_SCREEN -> {
                            GameScreen(
                                viewModel = viewModel,
                                uiState = uiState
                            )
                        }
                    }
                }
            }
        }
    }
}

/**
 * Kept for screenshot test compatibility.
 */
@Composable
fun Greeting(name: String, modifier: Modifier = Modifier) {
    Text(text = "Hello $name!", modifier = modifier)
}
