package com.iraqitube.app

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.rotate
import kotlin.math.cos
import kotlin.math.sin
import kotlin.random.Random

private val ConfettiColors = listOf(
    Color(0xFFFF4D8D),
    Color(0xFFFF8FB8),
    Color(0xFFF7F1F4),
    Color(0xFF3DDC97),
    Color(0xFFFFC857),
    Color(0xFF7AD7FF),
    Color(0xFFFF6B6B),
)

private class Piece(
    val originX: Float,
    val originY: Float,
    val vx: Float,
    val vy: Float,
    val gravity: Float,
    val spin: Float,
    val width: Float,
    val height: Float,
    val color: Color,
    val delay: Float,
    val circle: Boolean,
)

@Composable
fun ConfettiBurst(active: Boolean) {
    if (!active) return
    val pieces = remember(active) {
        List(72) {
            val angle = Math.toRadians((-110.0 + Random.nextFloat() * 40.0))
            val power = 0.55f + Random.nextFloat() * 0.85f
            Piece(
                originX = 0.18f + Random.nextFloat() * 0.64f,
                originY = 0.08f + Random.nextFloat() * 0.12f,
                vx = (cos(angle).toFloat() * power),
                vy = (sin(angle).toFloat() * power * 0.35f) - (0.35f + Random.nextFloat() * 0.45f),
                gravity = 1.35f + Random.nextFloat() * 0.7f,
                spin = 220f + Random.nextFloat() * 640f,
                width = 7f + Random.nextFloat() * 9f,
                height = 4f + Random.nextFloat() * 6f,
                color = ConfettiColors[it % ConfettiColors.size],
                delay = Random.nextFloat() * 0.16f,
                circle = it % 5 == 0,
            )
        }
    }
    val clock = remember { Animatable(0f) }
    LaunchedEffect(active) {
        clock.snapTo(0f)
        clock.animateTo(1f, tween(2600, easing = LinearEasing))
    }
    val t = clock.value
    Canvas(Modifier.fillMaxSize()) {
        pieces.forEach { piece ->
            val local = ((t - piece.delay) / (1f - piece.delay)).coerceIn(0f, 1f)
            if (local <= 0f) return@forEach
            val x = piece.originX * size.width + piece.vx * local * size.width
            val y = piece.originY * size.height +
                piece.vy * local * size.height +
                piece.gravity * local * local * size.height
            val alpha = (1f - local * 0.92f).coerceIn(0f, 1f)
            rotate(piece.spin * local, Offset(x, y)) {
                if (piece.circle) {
                    drawCircle(
                        color = piece.color.copy(alpha = alpha),
                        radius = piece.width * 0.45f,
                        center = Offset(x, y),
                    )
                } else {
                    drawRect(
                        color = piece.color.copy(alpha = alpha),
                        topLeft = Offset(x, y),
                        size = Size(piece.width, piece.height),
                    )
                }
            }
        }
    }
}
