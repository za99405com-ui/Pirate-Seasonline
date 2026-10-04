package com.example.pirateseas.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

@Composable
fun VirtualJoystick(
    modifier: Modifier = Modifier,
    size: Dp = 140.dp,
    onMove: (x: Float, y: Float) -> Unit
) {
    var thumbOffset by remember { mutableStateOf(Offset.Zero) }

    Box(
        modifier = modifier
            .size(size)
            .pointerInput(Unit) {
                val radius = (size.toPx()) / 2f
                val maxDragRadius = radius * 0.75f

                detectDragGestures(
                    onDragStart = { offset ->
                        val center = Offset(radius, radius)
                        val dragVec = offset - center
                        val dist = sqrt(dragVec.x * dragVec.x + dragVec.y * dragVec.y)
                        val clampedDist = dist.coerceAtMost(maxDragRadius)
                        val angle = atan2(dragVec.y, dragVec.x)
                        val clampedX = cos(angle) * clampedDist
                        val clampedY = sin(angle) * clampedDist

                        thumbOffset = Offset(clampedX, clampedY)
                        onMove(clampedX / maxDragRadius, clampedY / maxDragRadius)
                    },
                    onDrag = { change, dragAmount ->
                        change.consume()
                        val newOffset = thumbOffset + dragAmount
                        val dist = sqrt(newOffset.x * newOffset.x + newOffset.y * newOffset.y)
                        val angle = atan2(newOffset.y, newOffset.x)
                        val clampedDist = dist.coerceAtMost(maxDragRadius)
                        val clampedX = cos(angle) * clampedDist
                        val clampedY = sin(angle) * clampedDist

                        thumbOffset = Offset(clampedX, clampedY)
                        onMove(clampedX / maxDragRadius, clampedY / maxDragRadius)
                    },
                    onDragEnd = {
                        thumbOffset = Offset.Zero
                        onMove(0f, 0f)
                    },
                    onDragCancel = {
                        thumbOffset = Offset.Zero
                        onMove(0f, 0f)
                    }
                )
            }
    ) {
        Canvas(modifier = Modifier.matchParentSize()) {
            val center = Offset(this.size.width / 2f, this.size.height / 2f)
            val outerRadius = this.size.width / 2f - 8f

            // Outer Base Ring
            drawCircle(
                color = Color(0x660B1A30),
                radius = outerRadius,
                center = center
            )
            drawCircle(
                color = Color(0x99FFD54F),
                radius = outerRadius,
                center = center,
                style = Stroke(width = 3.dp.toPx())
            )

            // Directional cross markers
            drawLine(
                color = Color(0x44FFD54F),
                start = Offset(center.x - outerRadius * 0.6f, center.y),
                end = Offset(center.x + outerRadius * 0.6f, center.y),
                strokeWidth = 2f
            )
            drawLine(
                color = Color(0x44FFD54F),
                start = Offset(center.x, center.y - outerRadius * 0.6f),
                end = Offset(center.x, center.y + outerRadius * 0.6f),
                strokeWidth = 2f
            )

            // Inner Thumb Stick
            val thumbCenter = center + thumbOffset
            drawCircle(
                color = Color(0xDDA07830),
                radius = outerRadius * 0.38f,
                center = thumbCenter
            )
            drawCircle(
                color = Color(0xFFFFD54F),
                radius = outerRadius * 0.38f,
                center = thumbCenter,
                style = Stroke(width = 2.5.dp.toPx())
            )
            drawCircle(
                color = Color(0xAAFFFFFF),
                radius = outerRadius * 0.12f,
                center = thumbCenter
            )
        }
    }
}
