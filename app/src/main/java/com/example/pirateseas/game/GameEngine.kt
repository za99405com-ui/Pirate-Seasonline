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

data class PlayerShipState(
    var x: Float = 0f,
    var y: Float = -180f,
    var rotation: Float = 0f, // in radians (0 = pointing right/east, PI/2 = down/south)
    var currentSpeed: Float = 0f,
    var maxSpeed: Float = 4.0f,
    var turnSpeed: Float = 2.4f,
    var hp: Float = 100f,
    var maxHp: Float = 100f,
    var portCooldown: Float = 0f,
    var starboardCooldown: Float = 0f,
    val reloadTimeTotal: Float = 2.5f
)

class GameEngine(
    val world: GameWorld = GameWorld()
) {
    val player = PlayerShipState()
    var waveTime: Float = 0f
    var scoreGoldEarned: Int = 0

    fun update(
        dt: Float,
        joystickX: Float,
        joystickY: Float,
        currentShip: ShipType,
        upgrades: ShipUpgrades,
        hasNavigator: Boolean,
        hasGunner: Boolean,
        hasEngineer: Boolean
    ) {
        waveTime += dt

        // 1. Calculate Player Ship Stats with Upgrades & Crew
        val baseSpeed = currentShip.maxSpeed * upgrades.sailsSpeedMultiplier() * (if (hasNavigator) 1.20f else 1.0f)
        player.maxSpeed = baseSpeed
        player.turnSpeed = currentShip.turnSpeed
        player.maxHp = currentShip.baseHp + upgrades.hullBonusHp()

        // Engineer auto repair
        if (hasEngineer && player.hp < player.maxHp) {
            player.hp = (player.hp + dt * 2.5f).coerceAtMost(player.maxHp)
        }

        // 2. Rudder & Propulsion Physics
        val inputMag = sqrt(joystickX * joystickX + joystickY * joystickY)
        if (inputMag > 0.15f) {
            val targetAngle = atan2(joystickY, joystickX)
            var angleDiff = targetAngle - player.rotation
            while (angleDiff > PI) angleDiff -= (2 * PI).toFloat()
            while (angleDiff < -PI) angleDiff += (2 * PI).toFloat()

            // Smooth rotational inertia
            player.rotation += angleDiff * player.turnSpeed * dt

            // Smooth forward acceleration
            val targetSpeed = player.maxSpeed * (inputMag.coerceAtMost(1f))
            player.currentSpeed += (targetSpeed - player.currentSpeed) * 2.5f * dt
        } else {
            // Nautical drag / deceleration
            player.currentSpeed -= player.currentSpeed * 1.2f * dt
            if (player.currentSpeed < 0.05f) player.currentSpeed = 0f
        }

        // Apply movement vector along ship's bow heading
        player.x += cos(player.rotation) * player.currentSpeed * 60f * dt
        player.y += sin(player.rotation) * player.currentSpeed * 60f * dt

        // World boundary clamp
        player.x = player.x.coerceIn(-1800f, 1800f)
        player.y = player.y.coerceIn(-1800f, 1800f)

        // 3. Cannon reload timers
        val reloadMultiplier = if (hasGunner) 0.75f else 1.0f
        if (player.portCooldown > 0f) player.portCooldown = (player.portCooldown - dt / reloadMultiplier).coerceAtLeast(0f)
        if (player.starboardCooldown > 0f) player.starboardCooldown = (player.starboardCooldown - dt / reloadMultiplier).coerceAtLeast(0f)

        // 4. Update Cannonballs
        val cIt = world.cannonballs.iterator()
        while (cIt.hasNext()) {
            val ball = cIt.next()
            ball.x += ball.vx * dt
            ball.y += ball.vy * dt
            ball.lifeTime -= dt

            if (ball.lifeTime <= 0f) {
                cIt.remove()
                continue
            }

            // Check collision
            if (ball.fromPlayer) {
                // Check enemy hits
                for (enemy in world.enemies) {
                    if (GameWorld.distance(ball.x, ball.y, enemy.x, enemy.y) < 35f) {
                        val isCrit = Random.nextFloat() < 0.15f
                        val finalDamage = if (isCrit) ball.damage * 1.75f else ball.damage
                        enemy.hp -= finalDamage
                        world.floatingTexts.add(
                            FloatingText(
                                id = "dmg_${System.currentTimeMillis()}_${Random.nextInt(100)}",
                                text = if (isCrit) "CRIT -${finalDamage.toInt()}" else "-${finalDamage.toInt()}",
                                x = enemy.x,
                                y = enemy.y - 20f,
                                colorHex = if (isCrit) 0xFFFF5722 else 0xFFFFEB3B
                            )
                        )
                        ball.lifeTime = 0f
                        break
                    }
                }
            } else {
                // Check player hit
                if (GameWorld.distance(ball.x, ball.y, player.x, player.y) < 32f) {
                    player.hp = (player.hp - ball.damage).coerceAtLeast(0f)
                    world.floatingTexts.add(
                        FloatingText(
                            id = "dmg_player_${System.currentTimeMillis()}",
                            text = "-${ball.damage.toInt()}",
                            x = player.x,
                            y = player.y - 20f,
                            colorHex = 0xFFFF1744
                        )
                    )
                    ball.lifeTime = 0f
                }
            }
        }

        // 5. Update Enemy AI
        val playerInSafeZone = world.isInsideSafeZone(player.x, player.y)
        val eIt = world.enemies.iterator()
        while (eIt.hasNext()) {
            val enemy = eIt.next()

            // If sunk
            if (enemy.hp <= 0f) {
                // Drop loot
                val lootGold = Random.nextInt(40, 100)
                world.floatingLoots.add(
                    FloatingLoot(
                        id = "loot_drop_${System.currentTimeMillis()}",
                        x = enemy.x,
                        y = enemy.y,
                        gold = lootGold,
                        wood = Random.nextInt(10, 25),
                        iron = Random.nextInt(3, 10),
                        isChest = Random.nextBoolean()
                    )
                )
                world.floatingTexts.add(
                    FloatingText(
                        id = "sunk_${System.currentTimeMillis()}",
                        text = "SHIP SUNK! +XP",
                        x = enemy.x,
                        y = enemy.y,
                        colorHex = 0xFF4CAF50
                    )
                )
                eIt.remove()
                world.respawnEnemyIfNeeded()
                continue
            }

            enemy.reloadTimer -= dt

            val distToPlayer = GameWorld.distance(enemy.x, enemy.y, player.x, player.y)
            if (!playerInSafeZone && distToPlayer < 450f) {
                // Combat engagement: try to align broadside
                val toPlayerAngle = atan2(player.y - enemy.y, player.x - enemy.x)
                // Broadside heading = angle to player - 90 deg
                val desiredHeading = toPlayerAngle - (PI / 2).toFloat()
                var angleDiff = desiredHeading - enemy.rotation
                while (angleDiff > PI) angleDiff -= (2 * PI).toFloat()
                while (angleDiff < -PI) angleDiff += (2 * PI).toFloat()

                enemy.rotation += angleDiff * 1.5f * dt
                enemy.currentSpeed = 2.0f

                // Fire broadside at player if ready and within 320f
                if (distToPlayer < 320f && enemy.reloadTimer <= 0f) {
                    enemy.reloadTimer = 3.8f
                    fireEnemyBroadside(enemy, toPlayerAngle)
                }
            } else {
                // Peaceful patrol
                if (Random.nextFloat() < 0.01f) {
                    enemy.rotation += (Random.nextFloat() - 0.5f) * 1.2f
                }
                enemy.currentSpeed = 1.2f
            }

            enemy.x += cos(enemy.rotation) * enemy.currentSpeed * 60f * dt
            enemy.y += sin(enemy.rotation) * enemy.currentSpeed * 60f * dt
        }

        // 6. Floating texts aging
        val tIt = world.floatingTexts.iterator()
        while (tIt.hasNext()) {
            val t = tIt.next()
            t.age += dt
            t.y -= 25f * dt
            t.alpha = (1f - (t.age / 1.5f)).coerceAtLeast(0f)
            if (t.age >= 1.5f) {
                tIt.remove()
            }
        }
    }

    fun firePortCannons(currentShip: ShipType, upgrades: ShipUpgrades) {
        if (player.portCooldown > 0f) return
        player.portCooldown = 2.5f

        val portAngle = player.rotation - (PI / 2).toFloat()
        spawnBroadsideVolley(portAngle, currentShip, upgrades, fromPlayer = true)
    }

    fun fireStarboardCannons(currentShip: ShipType, upgrades: ShipUpgrades) {
        if (player.starboardCooldown > 0f) return
        player.starboardCooldown = 2.5f

        val starboardAngle = player.rotation + (PI / 2).toFloat()
        spawnBroadsideVolley(starboardAngle, currentShip, upgrades, fromPlayer = true)
    }

    private fun spawnBroadsideVolley(
        baseAngle: Float,
        currentShip: ShipType,
        upgrades: ShipUpgrades,
        fromPlayer: Boolean
    ) {
        val shots = currentShip.cannonCount / 2
        val spread = 0.15f
        val dmg = (currentShip.cannonDamage + upgrades.cannonDamageBonus()) / shots.coerceAtLeast(1)

        for (i in 0 until shots) {
            val offsetAngle = baseAngle + (i - (shots - 1) / 2f) * spread
            val speed = 340f + Random.nextFloat() * 40f
            world.cannonballs.add(
                Cannonball(
                    x = player.x + cos(baseAngle) * 20f,
                    y = player.y + sin(baseAngle) * 20f,
                    vx = cos(offsetAngle) * speed,
                    vy = sin(offsetAngle) * speed,
                    damage = dmg,
                    fromPlayer = fromPlayer,
                    lifeTime = 1.3f
                )
            )
        }
    }

    private fun fireEnemyBroadside(enemy: EnemyShip, angleToPlayer: Float) {
        val shots = 2
        for (i in 0 until shots) {
            val spread = (Random.nextFloat() - 0.5f) * 0.2f
            val angle = angleToPlayer + spread
            val speed = 280f
            world.cannonballs.add(
                Cannonball(
                    x = enemy.x,
                    y = enemy.y,
                    vx = cos(angle) * speed,
                    vy = sin(angle) * speed,
                    damage = 18f,
                    fromPlayer = false,
                    lifeTime = 1.5f
                )
            )
        }
    }

    fun catchFish(zone: FishingZone, hasFisherman: Boolean): CaughtFish {
        val rareChanceBonus = zone.rareBonus + (if (hasFisherman) 0.35f else 0.0f)
        val roll = Random.nextFloat()

        val rarity = when {
            roll < (0.05f + rareChanceBonus * 0.1f) -> FishRarity.LEGENDARY
            roll < (0.15f + rareChanceBonus * 0.2f) -> FishRarity.EPIC
            roll < (0.35f + rareChanceBonus * 0.3f) -> FishRarity.RARE
            roll < (0.65f + rareChanceBonus * 0.2f) -> FishRarity.UNCOMMON
            else -> FishRarity.COMMON
        }

        val fishNames = when (rarity) {
            FishRarity.COMMON -> listOf("Atlantic Cod", "Sea Bass", "Silver Sardine", "Mackerel")
            FishRarity.UNCOMMON -> listOf("Golden Snapper", "Barracuda", "Spotted Marlin", "Tiger Trout")
            FishRarity.RARE -> listOf("Bluefin Tuna", "Swordfish", "Ghost Shark", "Sunken Grouper")
            FishRarity.EPIC -> listOf("Abyssal Angler", "Armored Leviathan Pup", "Moonlit Ray")
            FishRarity.LEGENDARY -> listOf("Kraken Tenderling", "Golden Dorado of the Deep", "Poseidon's Serpent")
        }

        val name = fishNames.random()
        val weight = when (rarity) {
            FishRarity.COMMON -> Random.nextFloat() * 4f + 1f
            FishRarity.UNCOMMON -> Random.nextFloat() * 10f + 5f
            FishRarity.RARE -> Random.nextFloat() * 30f + 15f
            FishRarity.EPIC -> Random.nextFloat() * 60f + 40f
            FishRarity.LEGENDARY -> Random.nextFloat() * 180f + 90f
        }
        val value = (rarity.baseValue * (weight / 5f).coerceAtLeast(0.8f)).toInt()

        return CaughtFish(
            id = "fish_${System.currentTimeMillis()}",
            name = name,
            rarity = rarity,
            weightKg = (weight * 10).toInt() / 10f,
            value = value
        )
    }
}
