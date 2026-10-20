package dev.digitalducktape.openride.games.session

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Rect
import android.graphics.RectF
import dev.digitalducktape.openride.core.data.Profile
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * The rider's avatar for the Games hub (spec §4.3): Godot's default font has no emoji, so
 * Kotlin draws the avatar as Compose's `ProfileAvatar` does (the photo clipped round, or the
 * emoji on its colour disc, with Android's emoji font) into a 256×256 PNG once per visit, and
 * `hub_state.rider.avatar_png` names the file.
 */
fun interface AvatarRenderer {
    /** The PNG's path, or null if it couldn't be drawn. */
    suspend fun render(profile: Profile): String?
}

/** Draws into `<cacheDir>/games/avatar_<id>.png`. */
class BitmapAvatarRenderer(private val cacheDir: File) : AvatarRenderer {
    override suspend fun render(profile: Profile): String? = withContext(Dispatchers.IO) {
        runCatching {
            val bitmap = Bitmap.createBitmap(SIZE, SIZE, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            val photo = profile.avatarPhotoPath?.let { path -> File(path).takeIf { it.isFile }?.let { BitmapFactory.decodeFile(it.path) } }
            if (photo != null) drawPhoto(canvas, photo) else drawEmoji(canvas, profile)
            val file = File(cacheDir, "games/avatar_${profile.id}.png")
            file.parentFile?.mkdirs()
            file.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
            bitmap.recycle()
            file.path
        }.getOrNull()
    }

    private fun drawPhoto(canvas: Canvas, photo: Bitmap) {
        // AvatarPhotoStore already crops square; centre-crop anyway, then clip to the circle.
        val side = minOf(photo.width, photo.height)
        val src = Rect((photo.width - side) / 2, (photo.height - side) / 2, (photo.width + side) / 2, (photo.height + side) / 2)
        canvas.save()
        canvas.clipPath(Path().apply { addOval(RectF(0f, 0f, SIZE.toFloat(), SIZE.toFloat()), Path.Direction.CW) })
        canvas.drawBitmap(photo, src, Rect(0, 0, SIZE, SIZE), Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG))
        canvas.restore()
        photo.recycle()
    }

    private fun drawEmoji(canvas: Canvas, profile: Profile) {
        val half = SIZE / 2f
        canvas.drawCircle(half, half, half, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = profile.avatarColor or OPAQUE })
        val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textSize = SIZE * 0.55f
            textAlign = Paint.Align.CENTER
        }
        // Centre the glyph vertically on its font metrics.
        val baseline = half - (text.descent() + text.ascent()) / 2
        canvas.drawText(profile.avatarEmoji, half, baseline, text)
    }

    private companion object {
        const val SIZE = 256
        const val OPAQUE = 0xFF000000.toInt()
    }
}
