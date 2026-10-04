package com.example

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import com.example.pirateseas.ui.CaughtFishDialog
import com.example.pirateseas.ui.GameCanvas
import com.example.pirateseas.ui.GameHud
import com.example.pirateseas.ui.PortModal
import com.example.pirateseas.ui.UnityArchitectureScreen
import com.example.pirateseas.viewmodel.GameViewModel
import com.example.ui.theme.MyApplicationTheme

class MainActivity : ComponentActivity() {
    private val gameViewModel: GameViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        setContent {
            MyApplicationTheme(darkTheme = true) {
                Scaffold(modifier = Modifier.fillMaxSize()) { innerPadding ->
                    PirateSeasApp(
                        viewModel = gameViewModel,
                        modifier = Modifier.padding(innerPadding)
                    )
                }
            }
        }
    }
}

@Composable
fun PirateSeasApp(
    viewModel: GameViewModel,
    modifier: Modifier = Modifier
) {
    val activeTab by viewModel.activeTab.collectAsState()
    val saveData by viewModel.saveData.collectAsState()
    val interaction by viewModel.interaction.collectAsState()
    val isDocked by viewModel.isDocked.collectAsState()
    val dockedIsland by viewModel.dockedIsland.collectAsState()
    val isFishing by viewModel.isFishing.collectAsState()
    val fishingProgress by viewModel.fishingProgress.collectAsState()
    val lastCaughtFish by viewModel.lastCaughtFish.collectAsState()

    BackHandler(enabled = activeTab != 0 || isDocked) {
        if (isDocked) {
            viewModel.closeDock()
        } else if (activeTab != 0) {
            viewModel.setActiveTab(0)
        }
    }

    Box(modifier = modifier.fillMaxSize()) {
        if (activeTab == 0) {
            // Live Playable Nautical Game Canvas
            GameCanvas(
                engine = viewModel.engine,
                modifier = Modifier.fillMaxSize()
            )

            // Game HUD & Controls
            GameHud(
                engine = viewModel.engine,
                saveData = saveData,
                interaction = interaction,
                isFishing = isFishing,
                fishingProgress = fishingProgress,
                onJoystickMove = { x, y ->
                    viewModel.joystickInputX = x
                    viewModel.joystickInputY = y
                },
                onPortFire = { viewModel.firePortCannons() },
                onStarboardFire = { viewModel.fireStarboardCannons() },
                onInteract = { viewModel.triggerInteraction() },
                onOpenDocs = { viewModel.setActiveTab(1) }
            )

            // Docking Port Modal
            if (isDocked && dockedIsland != null) {
                PortModal(
                    island = dockedIsland!!,
                    saveData = saveData,
                    viewModel = viewModel,
                    onClose = { viewModel.closeDock() }
                )
            }

            // Caught Fish Reward Dialog
            lastCaughtFish?.let { fish ->
                CaughtFishDialog(
                    fish = fish,
                    onDismiss = { viewModel.dismissCaughtFishDialog() }
                )
            }
        } else {
            // Unity 6 + URP Architecture & C# Scripts Documentation
            UnityArchitectureScreen(
                onBackToGame = { viewModel.setActiveTab(0) }
            )
        }
    }
}
