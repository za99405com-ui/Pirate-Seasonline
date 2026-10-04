package com.example.pirateseas.model

enum class ShipType(
    val displayName: String,
    val baseHp: Float,
    val maxSpeed: Float,
    val turnSpeed: Float,
    val cannonCount: Int,
    val cannonDamage: Float,
    val cargoCapacity: Int,
    val cost: Int,
    val levelRequired: Int
) {
    ROWBOAT("Small Sloop", 100f, 3.8f, 2.5f, 2, 20f, 20, 0, 1),
    SLOOP("Fast Sloop", 180f, 4.8f, 3.2f, 4, 25f, 40, 250, 3),
    BRIGANTINE("Brigantine", 320f, 4.2f, 2.2f, 6, 35f, 80, 800, 6),
    FRIGATE("War Frigate", 550f, 3.6f, 1.8f, 10, 45f, 150, 2000, 10),
    GALLEON("Imperial Galleon", 950f, 3.0f, 1.4f, 16, 60f, 300, 5000, 15)
}

enum class FishRarity(val label: String, val colorHex: Long, val baseValue: Int) {
    COMMON("Common", 0xFF9E9E9E, 15),
    UNCOMMON("Uncommon", 0xFF4CAF50, 35),
    RARE("Rare", 0xFF2196F3, 85),
    EPIC("Epic", 0xFF9C27B0, 220),
    LEGENDARY("Legendary", 0xFFFF9800, 600)
}

data class CaughtFish(
    val id: String,
    val name: String,
    val rarity: FishRarity,
    val weightKg: Float,
    val value: Int
)

enum class CrewRole(val title: String, val perkDescription: String, val hireCost: Int) {
    GUNNER("Master Gunner", "-25% Cannon Reload Time", 120),
    NAVIGATOR("Sea Navigator", "+20% Ship Max Speed", 150),
    FISHERMAN("Expert Fisherman", "+35% Chance for Rare/Epic Fish", 100),
    ENGINEER("Shipwright Engineer", "+50% Health Auto-Repair Rate", 180)
}

data class CrewMember(
    val role: CrewRole,
    val level: Int = 1
)

data class ShipUpgrades(
    val hullLevel: Int = 1,
    val sailsLevel: Int = 1,
    val cannonsLevel: Int = 1,
    val cargoLevel: Int = 1
) {
    fun hullBonusHp() = (hullLevel - 1) * 30f
    fun sailsSpeedMultiplier() = 1f + (sailsLevel - 1) * 0.12f
    fun cannonDamageBonus() = (cannonsLevel - 1) * 6f
    fun cargoBonus() = (cargoLevel - 1) * 25
}

data class FloatingLoot(
    val id: String,
    var x: Float,
    var y: Float,
    val gold: Int,
    val wood: Int,
    val iron: Int,
    val isChest: Boolean = false
)

data class Cannonball(
    var x: Float,
    var y: Float,
    val vx: Float,
    val vy: Float,
    val damage: Float,
    val fromPlayer: Boolean,
    var lifeTime: Float = 1.6f
)

data class FloatingText(
    val id: String,
    val text: String,
    var x: Float,
    var y: Float,
    val colorHex: Long,
    var alpha: Float = 1f,
    var age: Float = 0f
)
