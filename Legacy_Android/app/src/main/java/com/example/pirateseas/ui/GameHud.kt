package com.example.pirateseas.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Anchor
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Navigation
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.pirateseas.data.PlayerSaveData
import com.example.pirateseas.game.GameEngine
import com.example.pirateseas.viewmodel.InteractionPrompt

@Composable
fun GameHud(
    engine: GameEngine,
    saveData: PlayerSaveData,
    interaction: InteractionPrompt,
    isFishing: Boolean,
    fishingProgress: Float,
    onJoystickMove: (Float, Float) -> Unit,
    onPortFire: () -> Unit,
    onStarboardFire: () -> Unit,
    onInteract: () -> Unit,
    onOpenDocs: () -> Unit
) {
    Box(modifier = Modifier.fillMaxSize()) {
        // TOP HUD BAR
        TopHudBar(
            saveData = saveData,
            playerHp = engine.player.hp,
            playerMaxHp = engine.player.maxHp,
            onOpenDocs = onOpenDocs
        )

        // FISHING PROGRESS MODAL / OVERLAY
        if (isFishing) {
            Box(
                modifier = Modifier
                    .align(Alignment.Center)
                    .background(Color(0xEE0B1A30), RoundedCornerShape(16.dp))
                    .border(2.dp, Color(0xFFFFD54F), RoundedCornerShape(16.dp))
                    .padding(24.dp),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = "🎣 Casting Fishing Line...",
                        color = Color(0xFFFFD54F),
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    LinearProgressIndicator(
                        progress = { fishingProgress },
                        modifier = Modifier
                            .width(200.dp)
                            .height(10.dp)
                            .clip(RoundedCornerShape(5.dp)),
                        color = Color(0xFF4CAF50),
                        trackColor = Color(0xFF1E3A5F)
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = "Waiting for a bite...",
                        color = Color.White.copy(alpha = 0.8f),
                        fontSize = 13.sp
                    )
                }
            }
        }

        // DYNAMIC INTERACTION BUTTON (CENTER-RIGHT)
        AnimatedVisibility(
            visible = interaction !is InteractionPrompt.None && !isFishing,
            enter = fadeIn(),
            exit = fadeOut(),
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 120.dp)
        ) {
            val (buttonText, buttonColor) = when (interaction) {
                is InteractionPrompt.Dock -> "⚓ DOCK AT PORT" to Color(0xFF2E7D32)
                is InteractionPrompt.Fish -> "🎣 CAST FISHING LINE" to Color(0xFF0288D1)
                is InteractionPrompt.CollectLoot -> "📦 COLLECT LOOT" to Color(0xFFFF8F00)
                InteractionPrompt.None -> "" to Color.Transparent
            }

            Surface(
                onClick = onInteract,
                shape = RoundedCornerShape(28.dp),
                color = buttonColor,
                shadowElevation = 8.dp,
                modifier = Modifier.border(2.dp, Color.White, RoundedCornerShape(28.dp))
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 24.dp, vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = buttonText,
                        color = Color.White,
                        fontWeight = FontWeight.ExtraBold,
                        fontSize = 16.sp
                    )
                }
            }
        }

        // BOTTOM CONTROLS ROW
        Row(
            modifier = Modifier
                .align(Alignment.BottomStart)
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 24.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.Bottom
        ) {
            // Virtual Joystick (Left)
            VirtualJoystick(
                size = 140.dp,
                onMove = onJoystickMove
            )

            // Cannon Fire Controls (Right)
            Column(
                horizontalAlignment = Alignment.End,
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                // Port Cannons (Left flank)
                CannonFireButton(
                    label = "PORT (L)",
                    cooldown = engine.player.portCooldown,
                    totalCooldown = 2.5f,
                    onClick = onPortFire
                )

                // Starboard Cannons (Right flank)
                CannonFireButton(
                    label = "STARBOARD (R)",
                    cooldown = engine.player.starboardCooldown,
                    totalCooldown = 2.5f,
                    onClick = onStarboardFire
                )
            }
        }
    }
}

@Composable
private fun TopHudBar(
    saveData: PlayerSaveData,
    playerHp: Float,
    playerMaxHp: Float,
    onOpenDocs: () -> Unit
) {
    Surface(
        color = Color(0xDD081528),
        shape = RoundedCornerShape(bottomStart = 20.dp, bottomEnd = 20.dp),
        shadowElevation = 6.dp,
        modifier = Modifier
            .fillMaxWidth()
            .border(
                width = 1.dp,
                color = Color(0x33FFD54F),
                shape = RoundedCornerShape(bottomStart = 20.dp, bottomEnd = 20.dp)
            )
    ) {
        Column(modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Player Level & Ship badge
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier = Modifier
                            .size(34.dp)
                            .background(Color(0xFFFFB300), CircleShape),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "${saveData.level}",
                            fontWeight = FontWeight.Bold,
                            color = Color(0xFF263238),
                            fontSize = 15.sp
                        )
                    }
                    Spacer(modifier = Modifier.width(8.dp))
                    Column {
                        Text(
                            text = saveData.currentShip.displayName,
                            color = Color.White,
                            fontWeight = FontWeight.Bold,
                            fontSize = 13.sp
                        )
                        val xpNeeded = saveData.level * 100
                        Text(
                            text = "XP: ${saveData.xp} / $xpNeeded",
                            color = Color(0xFFFFD54F),
                            fontSize = 10.sp
                        )
                    }
                }

                // Economy Badges: Gold, Wood, Iron
                Row(
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    ResourceBadge("🪙", "${saveData.gold}", Color(0xFFFFD700))
                    ResourceBadge("🪵", "${saveData.wood}", Color(0xFFBCAAA4))
                    ResourceBadge("⛓️", "${saveData.iron}", Color(0xFF90A4AE))

                    // Unity Architecture & Script Viewer button
                    Surface(
                        onClick = onOpenDocs,
                        shape = RoundedCornerShape(12.dp),
                        color = Color(0xFF1E3A5F),
                        modifier = Modifier.border(1.dp, Color(0xFF64B5F6), RoundedCornerShape(12.dp))
                    ) {
                        Row(
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(text = "📐 Architecture", color = Color(0xFF90CAF9), fontSize = 11.sp, fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(6.dp))

            // Ship Hull Health Bar
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text(
                    text = "HULL",
                    color = Color.White.copy(alpha = 0.7f),
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Bold
                )
                val hpFrac = (playerHp / playerMaxHp).coerceIn(0f, 1f)
                LinearProgressIndicator(
                    progress = { hpFrac },
                    modifier = Modifier
                        .weight(1f)
                        .height(8.dp)
                        .clip(RoundedCornerShape(4.dp)),
                    color = if (hpFrac > 0.4f) Color(0xFF4CAF50) else Color(0xFFE53935),
                    trackColor = Color(0xFF263238)
                )
                Text(
                    text = "${playerHp.toInt()} / ${playerMaxHp.toInt()}",
                    color = Color.White,
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Bold
                )
            }
        }
    }
}

@Composable
private fun ResourceBadge(icon: String, value: String, color: Color) {
    Row(
        modifier = Modifier
            .background(Color(0x55000000), RoundedCornerShape(8.dp))
            .padding(horizontal = 6.dp, vertical = 3.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(text = icon, fontSize = 12.sp)
        Spacer(modifier = Modifier.width(4.dp))
        Text(text = value, color = color, fontSize = 12.sp, fontWeight = FontWeight.Bold)
    }
}

@Composable
private fun CannonFireButton(
    label: String,
    cooldown: Float,
    totalCooldown: Float,
    onClick: () -> Unit
) {
    val isReady = cooldown <= 0.05f
    val fraction = (cooldown / totalCooldown).coerceIn(0f, 1f)

    Box(
        modifier = Modifier
            .size(72.dp)
            .background(
                color = if (isReady) Color(0xDD8D2B0B) else Color(0xAA37474F),
                shape = CircleShape
            )
            .border(
                width = 2.5.dp,
                color = if (isReady) Color(0xFFFFD54F) else Color(0xFF78909C),
                shape = CircleShape
            )
            .clickable(enabled = isReady, onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        if (!isReady) {
            CircularProgressIndicator(
                progress = { fraction },
                modifier = Modifier.size(68.dp),
                color = Color(0xFFFFAB00),
                strokeWidth = 3.dp,
                trackColor = Color.Transparent
            )
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = "💣",
                fontSize = 18.sp
            )
            Text(
                text = if (isReady) label else "${(cooldown * 10).toInt() / 10f}s",
                color = Color.White,
                fontSize = 9.sp,
                fontWeight = FontWeight.Bold
            )
        }
    }
}
