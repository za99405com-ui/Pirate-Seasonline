package com.example.pirateseas.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.example.pirateseas.data.PlayerSaveData
import com.example.pirateseas.game.Island
import com.example.pirateseas.model.CaughtFish
import com.example.pirateseas.model.CrewRole
import com.example.pirateseas.model.ShipType
import com.example.pirateseas.viewmodel.GameViewModel

@Composable
fun PortModal(
    island: Island,
    saveData: PlayerSaveData,
    viewModel: GameViewModel,
    onClose: () -> Unit
) {
    var selectedTab by remember { mutableStateOf(0) }
    val tabs = listOf("🛠️ Upgrades", "⛵ Shipyard", "🍺 Tavern", "🐟 Fish Market")

    Dialog(onDismissRequest = onClose) {
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .height(580.dp)
                .border(2.dp, Color(0xFFFFD54F), RoundedCornerShape(16.dp)),
            colors = CardDefaults.cardColors(containerColor = Color(0xFF0F1E36)),
            shape = RoundedCornerShape(16.dp)
        ) {
            Column(modifier = Modifier.fillMaxSize()) {
                // Header
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(Color(0xFF0A1526))
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text(
                            text = "⚓ ${island.name}",
                            color = Color(0xFFFFD54F),
                            fontSize = 18.sp,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            text = island.description,
                            color = Color.White.copy(alpha = 0.7f),
                            fontSize = 11.sp
                        )
                    }
                    IconButton(onClick = onClose) {
                        Icon(
                            imageVector = Icons.Default.Close,
                            contentDescription = "Close Port",
                            tint = Color.White
                        )
                    }
                }

                // Port Tabs
                TabRow(
                    selectedTabIndex = selectedTab,
                    containerColor = Color(0xFF142642),
                    contentColor = Color(0xFFFFD54F)
                ) {
                    tabs.forEachIndexed { index, title ->
                        Tab(
                            selected = selectedTab == index,
                            onClick = { selectedTab = index },
                            text = { Text(text = title, fontSize = 11.sp, fontWeight = FontWeight.Bold) }
                        )
                    }
                }

                // Tab Content
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(12.dp)
                ) {
                    when (selectedTab) {
                        0 -> UpgradesTab(saveData = saveData, viewModel = viewModel)
                        1 -> ShipyardTab(saveData = saveData, viewModel = viewModel)
                        2 -> TavernTab(saveData = saveData, viewModel = viewModel)
                        3 -> FishMarketTab(saveData = saveData, viewModel = viewModel)
                    }
                }
            }
        }
    }
}

@Composable
private fun UpgradesTab(saveData: PlayerSaveData, viewModel: GameViewModel) {
    val upg = saveData.upgrades
    LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        item {
            UpgradeCard(
                title = "Ship Hull Reinforcement",
                currentLevel = upg.hullLevel,
                statBenefit = "+${upg.hullBonusHp().toInt()} Max Health",
                costText = "Cost: ${upg.hullLevel * 150} Gold, ${upg.hullLevel * 20} Wood",
                canAfford = saveData.gold >= upg.hullLevel * 150 && saveData.wood >= upg.hullLevel * 20,
                onUpgrade = { viewModel.upgradeHull() }
            )
        }
        item {
            UpgradeCard(
                title = "Silk Sails & Rigging",
                currentLevel = upg.sailsLevel,
                statBenefit = "+${((upg.sailsSpeedMultiplier() - 1f) * 100).toInt()}% Top Speed",
                costText = "Cost: ${upg.sailsLevel * 120} Gold, ${upg.sailsLevel * 15} Wood",
                canAfford = saveData.gold >= upg.sailsLevel * 120 && saveData.wood >= upg.sailsLevel * 15,
                onUpgrade = { viewModel.upgradeSails() }
            )
        }
        item {
            UpgradeCard(
                title = "Cast-Iron Broadside Cannons",
                currentLevel = upg.cannonsLevel,
                statBenefit = "+${upg.cannonDamageBonus().toInt()} Cannon Fire Damage",
                costText = "Cost: ${upg.cannonsLevel * 180} Gold, ${upg.cannonsLevel * 10} Iron",
                canAfford = saveData.gold >= upg.cannonsLevel * 180 && saveData.iron >= upg.cannonsLevel * 10,
                onUpgrade = { viewModel.upgradeCannons() }
            )
        }
    }
}

@Composable
private fun UpgradeCard(
    title: String,
    currentLevel: Int,
    statBenefit: String,
    costText: String,
    canAfford: Boolean,
    onUpgrade: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = Color(0xFF162D50)),
        shape = RoundedCornerShape(10.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(text = "$title (Lv. $currentLevel)", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                Text(text = statBenefit, color = Color(0xFF81C784), fontSize = 12.sp)
                Text(text = costText, color = Color(0xFFFFD54F), fontSize = 11.sp)
            }
            Button(
                onClick = onUpgrade,
                enabled = canAfford,
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color(0xFF2E7D32),
                    disabledContainerColor = Color(0xFF37474F)
                ),
                shape = RoundedCornerShape(8.dp)
            ) {
                Text(text = "UPGRADE", fontSize = 11.sp, fontWeight = FontWeight.Bold)
            }
        }
    }
}

@Composable
private fun ShipyardTab(saveData: PlayerSaveData, viewModel: GameViewModel) {
    LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        items(ShipType.values()) { ship ->
            val isCurrent = saveData.currentShip == ship
            val isUnlocked = saveData.level >= ship.levelRequired
            val canAfford = saveData.gold >= ship.cost

            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(
                    containerColor = if (isCurrent) Color(0xFF1E4620) else Color(0xFF162D50)
                ),
                shape = RoundedCornerShape(10.dp)
            ) {
                Column(modifier = Modifier.padding(12.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = ship.displayName + if (isCurrent) " [ACTIVE]" else "",
                            color = if (isCurrent) Color(0xFFA5D6A7) else Color.White,
                            fontWeight = FontWeight.Bold,
                            fontSize = 15.sp
                        )
                        Text(
                            text = if (ship.cost == 0) "Free" else "${ship.cost} Gold",
                            color = Color(0xFFFFD54F),
                            fontWeight = FontWeight.Bold,
                            fontSize = 13.sp
                        )
                    }

                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = "HP: ${ship.baseHp.toInt()} | Speed: ${ship.maxSpeed} | Cannons: ${ship.cannonCount} | Cargo: ${ship.cargoCapacity}",
                        color = Color.White.copy(alpha = 0.7f),
                        fontSize = 11.sp
                    )

                    Spacer(modifier = Modifier.height(8.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "Requires Level ${ship.levelRequired}",
                            color = if (isUnlocked) Color(0xFF81C784) else Color(0xFFE57373),
                            fontSize = 11.sp
                        )

                        if (!isCurrent) {
                            Button(
                                onClick = { viewModel.purchaseShip(ship) },
                                enabled = isUnlocked && canAfford,
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = Color(0xFF0288D1),
                                    disabledContainerColor = Color(0xFF37474F)
                                ),
                                shape = RoundedCornerShape(8.dp)
                            ) {
                                Text(text = "BUY & EQUIP", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun TavernTab(saveData: PlayerSaveData, viewModel: GameViewModel) {
    LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        items(CrewRole.values()) { role ->
            val isHired = saveData.crew.any { it.role == role }
            val canAfford = saveData.gold >= role.hireCost

            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(containerColor = Color(0xFF162D50)),
                shape = RoundedCornerShape(10.dp)
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(12.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(text = role.title, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                        Text(text = role.perkDescription, color = Color(0xFF81C784), fontSize = 12.sp)
                        Text(text = "Hire Fee: ${role.hireCost} Gold", color = Color(0xFFFFD54F), fontSize = 11.sp)
                    }
                    if (isHired) {
                        Text(text = "HIRED ✅", color = Color(0xFF81C784), fontWeight = FontWeight.Bold, fontSize = 12.sp)
                    } else {
                        Button(
                            onClick = { viewModel.hireCrew(role) },
                            enabled = canAfford,
                            colors = ButtonDefaults.buttonColors(
                                containerColor = Color(0xFFFF8F00),
                                disabledContainerColor = Color(0xFF37474F)
                            ),
                            shape = RoundedCornerShape(8.dp)
                        ) {
                            Text(text = "RECRUIT", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun FishMarketTab(saveData: PlayerSaveData, viewModel: GameViewModel) {
    val fishList = saveData.cargoFish
    val totalValue = fishList.sumOf { it.value }

    Column(modifier = Modifier.fillMaxSize()) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "Cargo: ${fishList.size} Fish (Total: $totalValue Gold)",
                color = Color.White,
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold
            )
            Button(
                onClick = { viewModel.sellAllFish() },
                enabled = fishList.isNotEmpty(),
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color(0xFF2E7D32),
                    disabledContainerColor = Color(0xFF37474F)
                ),
                shape = RoundedCornerShape(8.dp)
            ) {
                Text(text = "SELL ALL", fontSize = 11.sp, fontWeight = FontWeight.Bold)
            }
        }

        Spacer(modifier = Modifier.height(10.dp))

        if (fishList.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(32.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "No fish in cargo hold!\nSail to fishing zones (green circles) and cast your line.",
                    color = Color.White.copy(alpha = 0.6f),
                    textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                    fontSize = 13.sp
                )
            }
        } else {
            LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                items(fishList) { fish ->
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(containerColor = Color(0xFF162D50)),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(10.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column {
                                Text(
                                    text = "🐟 ${fish.name}",
                                    color = Color.White,
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 13.sp
                                )
                                Text(
                                    text = "${fish.rarity.label} | ${fish.weightKg} kg",
                                    color = Color(fish.rarity.colorHex),
                                    fontSize = 11.sp
                                )
                            }
                            Text(
                                text = "+${fish.value} Gold",
                                color = Color(0xFFFFD54F),
                                fontWeight = FontWeight.Bold,
                                fontSize = 13.sp
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun CaughtFishDialog(fish: CaughtFish, onDismiss: () -> Unit) {
    Dialog(onDismissRequest = onDismiss) {
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
                .border(2.dp, Color(fish.rarity.colorHex), RoundedCornerShape(16.dp)),
            colors = CardDefaults.cardColors(containerColor = Color(0xFF0F1E36)),
            shape = RoundedCornerShape(16.dp)
        ) {
            Column(
                modifier = Modifier.padding(20.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = "🎉 FISH CAUGHT!",
                    color = Color(0xFFFFD54F),
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold
                )
                Spacer(modifier = Modifier.height(10.dp))
                Text(
                    text = fish.name,
                    color = Color.White,
                    fontSize = 20.sp,
                    fontWeight = FontWeight.ExtraBold
                )
                Spacer(modifier = Modifier.height(6.dp))
                Text(
                    text = "[ ${fish.rarity.label.uppercase()} ]",
                    color = Color(fish.rarity.colorHex),
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold
                )
                Spacer(modifier = Modifier.height(6.dp))
                Text(
                    text = "Weight: ${fish.weightKg} kg  •  Value: ${fish.value} Gold",
                    color = Color.White.copy(alpha = 0.85f),
                    fontSize = 13.sp
                )
                Spacer(modifier = Modifier.height(16.dp))
                Button(
                    onClick = onDismiss,
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2E7D32)),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Text(text = "STOW IN CARGO", fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}
