package com.example.pirateseas.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Fill
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.nativeCanvas
import com.example.pirateseas.game.EnemyShip
import com.example.pirateseas.game.GameEngine
import com.example.pirateseas.game.Island
import com.example.pirateseas.model.Cannonball
import com.example.pirateseas.model.FloatingLoot
import com.example.pirateseas.model.FloatingText
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

@Composable
fun GameCanvas(
    engine: GameEngine,
    modifier: Modifier = Modifier
) {
    Canvas(modifier = modifier.fillMaxSize()) {
        val screenCenterX = size.width / 2f
        val screenCenterY = size.height / 2f

        // Camera smoothly follows player
        val camX = engine.player.x
        val camY = engine.player.y

        // Function to transform world coord to screen coord
        fun worldToScreen(wx: Float, wy: Float): Offset {
            return Offset(screenCenterX + (wx - camX), screenCenterY + (wy - camY))
        }

        // 1. Draw Ocean Background
        drawRect(Color(0xFF0F2D54))

        // Draw Ocean waves / grid lines
        val waveTime = engine.waveTime
        drawOceanWaves(camX, camY, size, waveTime)

        // 2. Draw Fishing Zones
        for (zone in engine.world.fishingZones) {
            val screenPos = worldToScreen(zone.x, zone.y)
            drawCircle(
                color = Color(0x334CAF50),
                radius = zone.radius,
                center = screenPos
            )
            drawCircle(
                color = Color(0x8881C784),
                radius = zone.radius,
                center = screenPos,
                style = Stroke(width = 3f)
            )
            // Draw Zone Center buoy
            drawCircle(Color(0xFFFF9800), radius = 8f, center = screenPos)
        }

        // 3. Draw Islands & Ports
        for (island in engine.world.islands) {
            val sPos = worldToScreen(island.x, island.y)

            // Safe Zone aura if capital port
            if (island.isSafeZone) {
                drawCircle(
                    color = Color(0x1A29B6F6),
                    radius = island.radius + 100f,
                    center = sPos
                )
                drawCircle(
                    color = Color(0x4429B6F6),
                    radius = island.radius + 100f,
                    center = sPos,
                    style = Stroke(width = 2f)
                )
            }

            // Beach Sand
            drawCircle(
                color = Color(0xFFE0C068),
                radius = island.radius,
                center = sPos
            )
            // Island Foliage / Grass Core
            drawCircle(
                color = Color(0xFF2E7D32),
                radius = island.radius * 0.72f,
                center = sPos
            )

            // Port Pier / Dock if applicable
            if (island.isPort) {
                drawRoundRect(
                    color = Color(0xFF8D5524),
                    topLeft = Offset(sPos.x - 16f, sPos.y - island.radius - 20f),
                    size = Size(32f, 40f),
                    cornerRadius = CornerRadius(4f, 4f)
                )
                // Anchor icon marker
                drawCircle(Color(0xFFFFD700), radius = 6f, center = Offset(sPos.x, sPos.y - island.radius - 10f))
            }
        }

        // 4. Draw Floating Loot Crates & Barrels
        for (loot in engine.world.floatingLoots) {
            val lPos = worldToScreen(loot.x, loot.y)
            val bob = sin(waveTime * 3f + loot.x) * 3f

            if (loot.isChest) {
                // Treasure Chest
                drawRoundRect(
                    color = Color(0xFFFFB300),
                    topLeft = Offset(lPos.x - 14f, lPos.y - 10f + bob),
                    size = Size(28f, 20f),
                    cornerRadius = CornerRadius(4f, 4f)
                )
                drawRoundRect(
                    color = Color(0xFF5D4037),
                    topLeft = Offset(lPos.x - 12f, lPos.y - 8f + bob),
                    size = Size(24f, 16f),
                    cornerRadius = CornerRadius(2f, 2f)
                )
            } else {
                // Floating Crate
                drawRoundRect(
                    color = Color(0xFF8D6E63),
                    topLeft = Offset(lPos.x - 12f, lPos.y - 12f + bob),
                    size = Size(24f, 24f),
                    cornerRadius = CornerRadius(3f, 3f)
                )
                drawCircle(Color(0xFFD7CCC8), radius = 3f, center = Offset(lPos.x, lPos.y + bob))
            }
        }

        // 5. Draw Cannonballs
        for (ball in engine.world.cannonballs) {
            val bPos = worldToScreen(ball.x, ball.y)
            val ballColor = if (ball.fromPlayer) Color(0xFFFFD54F) else Color(0xFFFF5252)
            // Smoke / Trail puff
            drawCircle(
                color = ballColor.copy(alpha = 0.4f),
                radius = 8f,
                center = bPos
            )
            // Cannonball core
            drawCircle(
                color = if (ball.fromPlayer) Color(0xFF263238) else Color(0xFFB71C1C),
                radius = 5f,
                center = bPos
            )
        }

        // 6. Draw Enemy Ships
        for (enemy in engine.world.enemies) {
            drawShip(
                drawScope = this,
                screenPos = worldToScreen(enemy.x, enemy.y),
                rotationRad = enemy.rotation,
                isPlayer = false,
                hp = enemy.hp,
                maxHp = enemy.maxHp,
                name = "Pirate ${enemy.shipType.displayName}"
            )
        }

        // 7. Draw Player Ship
        drawShip(
            drawScope = this,
            screenPos = worldToScreen(engine.player.x, engine.player.y),
            rotationRad = engine.player.rotation,
            isPlayer = true,
            hp = engine.player.hp,
            maxHp = engine.player.maxHp,
            name = "Flagship"
        )

        // 8. Draw Floating Damage Numbers / Loot Notifications
        for (fText in engine.world.floatingTexts) {
            val tPos = worldToScreen(fText.x, fText.y)
            drawContext.canvas.nativeCanvas.apply {
                val paint = android.graphics.Paint().apply {
                    color = fText.colorHex.toInt()
                    textSize = 34f
                    isFakeBoldText = true
                    alpha = (fText.alpha * 255).toInt()
                    textAlign = android.graphics.Paint.Align.CENTER
                    setShadowLayer(6f, 0f, 0f, android.graphics.Color.BLACK)
                }
                drawText(fText.text, tPos.x, tPos.y, paint)
            }
        }
    }
}

private fun DrawScope.drawOceanWaves(camX: Float, camY: Float, screenSize: Size, waveTime: Float) {
    val spacing = 120f
    val offsetX = -(camX % spacing)
    val offsetY = -(camY % spacing)

    var x = offsetX - spacing
    while (x < screenSize.width + spacing) {
        var y = offsetY - spacing
        while (y < screenSize.height + spacing) {
            val waveWave = sin(waveTime * 2f + x * 0.02f + y * 0.02f)
            val waveLength = 26f + waveWave * 8f

            drawLine(
                color = Color(0x22FFFFFF),
                start = Offset(x, y),
                end = Offset(x + waveLength, y + waveWave * 4f),
                strokeWidth = 2.5f
            )
            y += spacing
        }
        x += spacing
    }
}

private fun drawShip(
    drawScope: DrawScope,
    screenPos: Offset,
    rotationRad: Float,
    isPlayer: Boolean,
    hp: Float,
    maxHp: Float,
    name: String
) {
    // Rotation in degrees (convert from radians)
    val degrees = (rotationRad * 180f / PI).toFloat()

    drawScope.rotate(degrees, pivot = screenPos) {
        // Ship Wake / foam at stern
        val wakePath = Path().apply {
            moveTo(screenPos.x - 32f, screenPos.y - 12f)
            lineTo(screenPos.x - 48f, screenPos.y - 20f)
            lineTo(screenPos.x - 44f, screenPos.y)
            lineTo(screenPos.x - 48f, screenPos.y + 20f)
            lineTo(screenPos.x - 32f, screenPos.y + 12f)
            close()
        }
        drawPath(wakePath, color = Color(0x33E0F7FA))

        // Ship Wooden Hull (pointed bow to the right, flat stern to the left)
        val hullPath = Path().apply {
            moveTo(screenPos.x + 36f, screenPos.y) // Bow
            lineTo(screenPos.x + 16f, screenPos.y + 16f)
            lineTo(screenPos.x - 26f, screenPos.y + 15f)
            lineTo(screenPos.x - 30f, screenPos.y) // Stern
            lineTo(screenPos.x - 26f, screenPos.y - 15f)
            lineTo(screenPos.x + 16f, screenPos.y - 16f)
            close()
        }

        val hullColor = if (isPlayer) Color(0xFF6D4C41) else Color(0xFF37474F)
        drawPath(hullPath, color = hullColor)
        drawPath(hullPath, color = if (isPlayer) Color(0xFFFFD54F) else Color(0xFF90A4AE), style = Stroke(width = 2.5f))

        // Deck cabin
        drawRoundRect(
            color = if (isPlayer) Color(0xFF4E342E) else Color(0xFF263238),
            topLeft = Offset(screenPos.x - 24f, screenPos.y - 9f),
            size = Size(18f, 18f),
            cornerRadius = CornerRadius(3f, 3f)
        )

        // Main Mast & White/Black Sails
        drawLine(
            color = Color(0xFF3E2723),
            start = Offset(screenPos.x + 2f, screenPos.y - 22f),
            end = Offset(screenPos.x + 2f, screenPos.y + 22f),
            strokeWidth = 3f
        )
        // Main Sail Canvas
        val sailPath = Path().apply {
            moveTo(screenPos.x + 2f, screenPos.y - 20f)
            quadraticTo(screenPos.x + 10f, screenPos.y, screenPos.x + 2f, screenPos.y + 20f)
            close()
        }
        drawPath(sailPath, color = if (isPlayer) Color(0xFFECEFF1) else Color(0xFF212121))

        // Fore Sail
        val foreSail = Path().apply {
            moveTo(screenPos.x + 22f, screenPos.y - 12f)
            quadraticTo(screenPos.x + 27f, screenPos.y, screenPos.x + 22f, screenPos.y + 12f)
            close()
        }
        drawPath(foreSail, color = if (isPlayer) Color(0xFFECEFF1) else Color(0xFFB71C1C))

        // Port & Starboard Cannons
        val cannonColor = Color(0xFF212121)
        // Left (Port) cannons (top relative to heading)
        drawCircle(cannonColor, radius = 2.5f, center = Offset(screenPos.x - 5f, screenPos.y - 16f))
        drawCircle(cannonColor, radius = 2.5f, center = Offset(screenPos.x + 8f, screenPos.y - 16f))
        // Right (Starboard) cannons (bottom relative to heading)
        drawCircle(cannonColor, radius = 2.5f, center = Offset(screenPos.x - 5f, screenPos.y + 16f))
        drawCircle(cannonColor, radius = 2.5f, center = Offset(screenPos.x + 8f, screenPos.y + 16f))
    }

    // Health Bar (stays horizontal above ship, doesn't rotate)
    val barWidth = 64f
    val barHeight = 7f
    val barTopLeft = Offset(screenPos.x - barWidth / 2f, screenPos.y - 42f)

    // Bar background
    drawScope.drawRoundRect(
        color = Color(0xCC000000),
        topLeft = barTopLeft,
        size = Size(barWidth, barHeight),
        cornerRadius = CornerRadius(3f, 3f)
    )

    // Bar fill
    val hpFraction = (hp / maxHp).coerceIn(0f, 1f)
    val hpColor = when {
        hpFraction > 0.5f -> Color(0xFF4CAF50)
        hpFraction > 0.25f -> Color(0xFFFFC107)
        else -> Color(0xFFF44336)
    }

    drawScope.drawRoundRect(
        color = hpColor,
        topLeft = barTopLeft,
        size = Size(barWidth * hpFraction, barHeight),
        cornerRadius = CornerRadius(3f, 3f)
    )

    // Ship Name
    drawScope.drawContext.canvas.nativeCanvas.apply {
        val paint = android.graphics.Paint().apply {
            color = if (isPlayer) android.graphics.Color.WHITE else android.graphics.Color.LTGRAY
            textSize = 22f
            textAlign = android.graphics.Paint.Align.CENTER
            setShadowLayer(4f, 0f, 0f, android.graphics.Color.BLACK)
        }
        drawText(name, screenPos.x, screenPos.y - 48f, paint)
    }
}
