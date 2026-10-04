package com.example.pirateseas.game

import com.example.pirateseas.model.Cannonball
import com.example.pirateseas.model.CaughtFish
import com.example.pirateseas.model.FishRarity
import com.example.pirateseas.model.FloatingLoot
import com.example.pirateseas.model.FloatingText
import com.example.pirateseas.model.ShipType
import com.example.pirateseas.model.ShipUpgrades
import kotlin.math.PI
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt
import kotlin.random.Random

data class Island(
    val name: String,
    val x: Float,
    val y: Float,
    val radius: Float,
    val isPort: Boolean,
    val isSafeZone: Boolean,
    val description: String
)

data class FishingZone(
    val name: String,
    val x: Float,
    val y: Float,
    val radius: Float,
    val rareBonus: Float
)

data class EnemyShip(
    val id: String,
    var x: Float,
    var y: Float,
    var rotation: Float, // radians
    var currentSpeed: Float = 0f,
    val shipType: ShipType,
    var hp: Float,
    val maxHp: Float,
    var reloadTimer: Float = 0f,
    var targetWaypointX: Float = 0f,
    var targetWaypointY: Float = 0f
)

class GameWorld {
    val islands = listOf(
        Island("Port Royal", 0f, 0f, 130f, isPort = true, isSafeZone = true, "Safe haven capital port"),
        Island("Tortuga Outpost", 900f, 600f, 110f, isPort = true, isSafeZone = true, "Smugglers haven and black market"),
        Island("Dead Man's Rock", -800f, 850f, 90f, isPort = false, isSafeZone = false, "Dangerous skull rocks with sunken shipwrecks")
    )

    val fishingZones = listOf(
        FishingZone("Emerald Shoals", 350f, -400f, 160f, rareBonus = 0f),
        FishingZone("Kraken's Abyss", -600f, -600f, 180f, rareBonus = 0.35f)
    )

    val enemies = mutableListOf<EnemyShip>()
    val cannonballs = mutableListOf<Cannonball>()
    val floatingLoots = mutableListOf<FloatingLoot>()
    val floatingTexts = mutableListOf<FloatingText>()

    init {
        spawnInitialEnemies()
        spawnFloatingLoot()
    }

    private fun spawnInitialEnemies() {
        enemies.clear()
        enemies.add(EnemyShip("npc_1", 500f, 400f, 0f, 0f, ShipType.SLOOP, 120f, 120f))
        enemies.add(EnemyShip("npc_2", -500f, 500f, 1f, 0f, ShipType.BRIGANTINE, 250f, 250f))
        enemies.add(EnemyShip("npc_3", 700f, -700f, 2.5f, 0f, ShipType.SLOOP, 140f, 140f))
        enemies.add(EnemyShip("npc_4", -900f, -300f, 3.14f, 0f, ShipType.FRIGATE, 450f, 450f))
    }

    private fun spawnFloatingLoot() {
        floatingLoots.clear()
        val r = Random(42)
        for (i in 1..8) {
            val dist = r.nextFloat() * 800f + 250f
            val angle = r.nextFloat() * 2f * PI.toFloat()
            floatingLoots.add(
                FloatingLoot(
                    id = "loot_$i",
                    x = cos(angle) * dist,
                    y = sin(angle) * dist,
                    gold = r.nextInt(20, 60),
                    wood = r.nextInt(5, 15),
                    iron = r.nextInt(1, 5),
                    isChest = i % 3 == 0
                )
            )
        }
    }

    fun isInsideSafeZone(x: Float, y: Float): Boolean {
        return islands.any { it.isSafeZone && distance(x, y, it.x, it.y) <= it.radius + 120f }
    }

    fun getNearbyPort(x: Float, y: Float): Island? {
        return islands.firstOrNull { it.isPort && distance(x, y, it.x, it.y) <= it.radius + 60f }
    }

    fun getNearbyFishingZone(x: Float, y: Float): FishingZone? {
        return fishingZones.firstOrNull { distance(x, y, it.x, it.y) <= it.radius }
    }

    fun getNearbyLoot(x: Float, y: Float): FloatingLoot? {
        return floatingLoots.firstOrNull { distance(x, y, it.x, it.y) <= 65f }
    }

    fun respawnEnemyIfNeeded() {
        if (enemies.size < 4) {
            val id = "npc_${System.currentTimeMillis()}"
            val angle = Random.nextFloat() * 2f * PI.toFloat()
            val dist = Random.nextFloat() * 700f + 600f
            val types = listOf(ShipType.SLOOP, ShipType.BRIGANTINE)
            val type = types.random()
            enemies.add(
                EnemyShip(
                    id = id,
                    x = cos(angle) * dist,
                    y = sin(angle) * dist,
                    rotation = Random.nextFloat() * 6.28f,
                    shipType = type,
                    hp = type.baseHp,
                    maxHp = type.baseHp
                )
            )
        }
    }

    companion object {
        fun distance(x1: Float, y1: Float, x2: Float, y2: Float): Float {
            val dx = x1 - x2
            val dy = y1 - y2
            return sqrt(dx * dx + dy * dy)
        }
    }
}
