package com.example.pirateseas.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.example.pirateseas.data.PlayerSaveData
import com.example.pirateseas.data.SaveRepository
import com.example.pirateseas.game.FishingZone
import com.example.pirateseas.game.GameEngine
import com.example.pirateseas.game.Island
import com.example.pirateseas.model.CaughtFish
import com.example.pirateseas.model.CrewMember
import com.example.pirateseas.model.CrewRole
import com.example.pirateseas.model.FloatingLoot
import com.example.pirateseas.model.ShipType
import com.example.pirateseas.model.ShipUpgrades
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

sealed class InteractionPrompt {
    object None : InteractionPrompt()
    data class Dock(val port: Island) : InteractionPrompt()
    data class Fish(val zone: FishingZone) : InteractionPrompt()
    data class CollectLoot(val loot: FloatingLoot) : InteractionPrompt()
}

class GameViewModel(application: Application) : AndroidViewModel(application) {
    private val repository = SaveRepository(application.applicationContext)
    val engine = GameEngine()

    private val _saveData = MutableStateFlow(repository.load())
    val saveData: StateFlow<PlayerSaveData> = _saveData.asStateFlow()

    private val _interaction = MutableStateFlow<InteractionPrompt>(InteractionPrompt.None)
    val interaction: StateFlow<InteractionPrompt> = _interaction.asStateFlow()

    private val _isDocked = MutableStateFlow(false)
    val isDocked: StateFlow<Boolean> = _isDocked.asStateFlow()

    private val _dockedIsland = MutableStateFlow<Island?>(null)
    val dockedIsland: StateFlow<Island?> = _dockedIsland.asStateFlow()

    private val _isFishing = MutableStateFlow(false)
    val isFishing: StateFlow<Boolean> = _isFishing.asStateFlow()

    private val _fishingProgress = MutableStateFlow(0f)
    val fishingProgress: StateFlow<Float> = _fishingProgress.asStateFlow()

    private val _lastCaughtFish = MutableStateFlow<CaughtFish?>(null)
    val lastCaughtFish: StateFlow<CaughtFish?> = _lastCaughtFish.asStateFlow()

    private val _activeTab = MutableStateFlow(0) // 0 = Play, 1 = Unity Architecture & Code
    val activeTab: StateFlow<Int> = _activeTab.asStateFlow()

    var joystickInputX = 0f
    var joystickInputY = 0f

    init {
        // Load initial player HP
        val initialShip = _saveData.value.currentShip
        val upgrades = _saveData.value.upgrades
        engine.player.hp = initialShip.baseHp + upgrades.hullBonusHp()
        engine.player.maxHp = engine.player.hp

        // Start 60fps Game Loop
        startGameLoop()
    }

    private fun startGameLoop() {
        viewModelScope.launch {
            var lastTime = System.nanoTime()
            while (isActive) {
                val now = System.nanoTime()
                val dt = ((now - lastTime) / 1_000_000_000f).coerceIn(0.001f, 0.05f)
                lastTime = now

                if (!_isDocked.value && !_isFishing.value) {
                    val currentShip = _saveData.value.currentShip
                    val upgrades = _saveData.value.upgrades
                    val hasNavigator = _saveData.value.crew.any { it.role == CrewRole.NAVIGATOR }
                    val hasGunner = _saveData.value.crew.any { it.role == CrewRole.GUNNER }
                    val hasEngineer = _saveData.value.crew.any { it.role == CrewRole.ENGINEER }

                    engine.update(
                        dt = dt,
                        joystickX = joystickInputX,
                        joystickY = joystickInputY,
                        currentShip = currentShip,
                        upgrades = upgrades,
                        hasNavigator = hasNavigator,
                        hasGunner = hasGunner,
                        hasEngineer = hasEngineer
                    )

                    // Check respawn if player died
                    if (engine.player.hp <= 0f) {
                        engine.player.x = 0f
                        engine.player.y = -180f
                        engine.player.hp = engine.player.maxHp
                        engine.player.currentSpeed = 0f
                    }

                    // Check interaction triggers
                    checkInteractions()
                }

                delay(16) // ~60 FPS
            }
        }
    }

    private fun checkInteractions() {
        val px = engine.player.x
        val py = engine.player.y

        // Check port proximity
        val port = engine.world.getNearbyPort(px, py)
        if (port != null) {
            _interaction.value = InteractionPrompt.Dock(port)
            return
        }

        // Check floating loot
        val loot = engine.world.getNearbyLoot(px, py)
        if (loot != null) {
            _interaction.value = InteractionPrompt.CollectLoot(loot)
            return
        }

        // Check fishing zone
        val zone = engine.world.getNearbyFishingZone(px, py)
        if (zone != null) {
            _interaction.value = InteractionPrompt.Fish(zone)
            return
        }

        _interaction.value = InteractionPrompt.None
    }

    fun firePortCannons() {
        val currentShip = _saveData.value.currentShip
        val upgrades = _saveData.value.upgrades
        engine.firePortCannons(currentShip, upgrades)
    }

    fun fireStarboardCannons() {
        val currentShip = _saveData.value.currentShip
        val upgrades = _saveData.value.upgrades
        engine.fireStarboardCannons(currentShip, upgrades)
    }

    fun triggerInteraction() {
        when (val prompt = _interaction.value) {
            is InteractionPrompt.Dock -> {
                _isDocked.value = true
                _dockedIsland.value = prompt.port
            }
            is InteractionPrompt.Fish -> {
                startFishing(prompt.zone)
            }
            is InteractionPrompt.CollectLoot -> {
                collectLoot(prompt.loot)
            }
            InteractionPrompt.None -> {}
        }
    }

    fun closeDock() {
        _isDocked.value = false
        _dockedIsland.value = null
    }

    fun dismissCaughtFishDialog() {
        _lastCaughtFish.value = null
    }

    private fun startFishing(zone: FishingZone) {
        if (_isFishing.value) return
        _isFishing.value = true
        _fishingProgress.value = 0f
        engine.player.currentSpeed = 0f

        viewModelScope.launch {
            val totalTime = 3.0f // 3 seconds
            val steps = 30
            val interval = (totalTime * 1000 / steps).toLong()

            for (i in 1..steps) {
                delay(interval)
                _fishingProgress.value = i.toFloat() / steps
            }

            val hasFisherman = _saveData.value.crew.any { it.role == CrewRole.FISHERMAN }
            val fish = engine.catchFish(zone, hasFisherman)

            // Add to cargo
            val currentCargo = _saveData.value.cargoFish.toMutableList()
            currentCargo.add(0, fish)

            // Gain XP
            addXp(25)

            _saveData.value = _saveData.value.copy(cargoFish = currentCargo)
            repository.save(_saveData.value)

            _isFishing.value = false
            _lastCaughtFish.value = fish
        }
    }

    private fun collectLoot(loot: FloatingLoot) {
        engine.world.floatingLoots.remove(loot)
        addGold(loot.gold)
        addResources(loot.wood, loot.iron)
        addXp(15)
        _interaction.value = InteractionPrompt.None
    }

    fun addGold(amount: Int) {
        val newGold = _saveData.value.gold + amount
        _saveData.value = _saveData.value.copy(gold = newGold)
        repository.save(_saveData.value)
    }

    fun addResources(wood: Int, iron: Int) {
        _saveData.value = _saveData.value.copy(
            wood = _saveData.value.wood + wood,
            iron = _saveData.value.iron + iron
        )
        repository.save(_saveData.value)
    }

    fun addXp(amount: Int) {
        var currentXp = _saveData.value.xp + amount
        var currentLevel = _saveData.value.level
        val xpNeeded = currentLevel * 100

        if (currentXp >= xpNeeded) {
            currentXp -= xpNeeded
            currentLevel += 1
        }

        _saveData.value = _saveData.value.copy(level = currentLevel, xp = currentXp)
        repository.save(_saveData.value)
    }

    fun upgradeHull(): Boolean {
        val costGold = _saveData.value.upgrades.hullLevel * 150
        val costWood = _saveData.value.upgrades.hullLevel * 20
        if (_saveData.value.gold >= costGold && _saveData.value.wood >= costWood) {
            val newUpgrades = _saveData.value.upgrades.copy(hullLevel = _saveData.value.upgrades.hullLevel + 1)
            _saveData.value = _saveData.value.copy(
                gold = _saveData.value.gold - costGold,
                wood = _saveData.value.wood - costWood,
                upgrades = newUpgrades
            )
            repository.save(_saveData.value)
            engine.player.maxHp = _saveData.value.currentShip.baseHp + newUpgrades.hullBonusHp()
            engine.player.hp = engine.player.maxHp
            return true
        }
        return false
    }

    fun upgradeSails(): Boolean {
        val costGold = _saveData.value.upgrades.sailsLevel * 120
        val costWood = _saveData.value.upgrades.sailsLevel * 15
        if (_saveData.value.gold >= costGold && _saveData.value.wood >= costWood) {
            val newUpgrades = _saveData.value.upgrades.copy(sailsLevel = _saveData.value.upgrades.sailsLevel + 1)
            _saveData.value = _saveData.value.copy(
                gold = _saveData.value.gold - costGold,
                wood = _saveData.value.wood - costWood,
                upgrades = newUpgrades
            )
            repository.save(_saveData.value)
            return true
        }
        return false
    }

    fun upgradeCannons(): Boolean {
        val costGold = _saveData.value.upgrades.cannonsLevel * 180
        val costIron = _saveData.value.upgrades.cannonsLevel * 10
        if (_saveData.value.gold >= costGold && _saveData.value.iron >= costIron) {
            val newUpgrades = _saveData.value.upgrades.copy(cannonsLevel = _saveData.value.upgrades.cannonsLevel + 1)
            _saveData.value = _saveData.value.copy(
                gold = _saveData.value.gold - costGold,
                iron = _saveData.value.iron - costIron,
                upgrades = newUpgrades
            )
            repository.save(_saveData.value)
            return true
        }
        return false
    }

    fun hireCrew(role: CrewRole): Boolean {
        if (_saveData.value.crew.any { it.role == role }) return false
        if (_saveData.value.gold >= role.hireCost) {
            val newCrew = _saveData.value.crew.toMutableList()
            newCrew.add(CrewMember(role))
            _saveData.value = _saveData.value.copy(
                gold = _saveData.value.gold - role.hireCost,
                crew = newCrew
            )
            repository.save(_saveData.value)
            return true
        }
        return false
    }

    fun purchaseShip(ship: ShipType): Boolean {
        if (_saveData.value.level < ship.levelRequired) return false
        if (_saveData.value.gold >= ship.cost) {
            _saveData.value = _saveData.value.copy(
                gold = _saveData.value.gold - ship.cost,
                currentShip = ship
            )
            repository.save(_saveData.value)
            engine.player.maxHp = ship.baseHp + _saveData.value.upgrades.hullBonusHp()
            engine.player.hp = engine.player.maxHp
            return true
        }
        return false
    }

    fun sellAllFish(): Int {
        val totalEarned = _saveData.value.cargoFish.sumOf { it.value }
        if (totalEarned > 0) {
            _saveData.value = _saveData.value.copy(
                gold = _saveData.value.gold + totalEarned,
                cargoFish = emptyList()
            )
            repository.save(_saveData.value)
        }
        return totalEarned
    }

    fun setActiveTab(index: Int) {
        _activeTab.value = index
    }
}
