package dev.digitalducktape.openride.ui.designsystem

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.compositeOver
import kotlin.math.pow

/**
 * WCAG 2.x relative luminance of an sRGB colour (alpha ignored: composite it first). Written out
 * rather than using Compose's `Color.luminance()` so the formula the tests rely on is the
 * published one, and readable here.
 */
fun relativeLuminance(color: Color): Double {
    fun channel(c: Float): Double {
        val v = c.toDouble()
        return if (v <= 0.04045) v / 12.92 else ((v + 0.055) / 1.055).pow(2.4)
    }
    return 0.2126 * channel(color.red) + 0.7152 * channel(color.green) + 0.0722 * channel(color.blue)
}

/**
 * WCAG contrast ratio of [foreground] drawn on [background], from 1.0 (none) to 21.0 (black on
 * white). A translucent foreground is composited over the background first.
 */
fun contrastRatio(foreground: Color, background: Color): Double {
    val fg = if (foreground.alpha < 1f) foreground.compositeOver(background) else foreground
    val a = relativeLuminance(fg)
    val b = relativeLuminance(background)
    val lighter = maxOf(a, b)
    val darker = minOf(a, b)
    return (lighter + 0.05) / (darker + 0.05)
}
