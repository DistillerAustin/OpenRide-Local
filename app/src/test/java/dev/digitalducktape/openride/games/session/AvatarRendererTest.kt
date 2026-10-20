package dev.digitalducktape.openride.games.session

import android.graphics.BitmapFactory
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import dev.digitalducktape.openride.core.data.Profile
import java.io.File
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AvatarRendererTest {
    private val cacheDir: File = ApplicationProvider.getApplicationContext<android.content.Context>().cacheDir
    private val renderer = BitmapAvatarRenderer(cacheDir)

    @Test
    fun `an emoji avatar renders to a 256 px PNG named for the rider`() = runTest {
        val path = renderer.render(Profile(id = 3, name = "Ed", avatarEmoji = "🚴", avatarColor = 0xFF4F7CFF.toInt(), weightKg = null, ftp = null))

        assertEquals(File(cacheDir, "games/avatar_3.png").path, path)
        val file = File(path!!)
        assertTrue(file.length() > 0)
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        assertEquals(256, bounds.outWidth)
        assertEquals(256, bounds.outHeight)
    }

    @Test
    fun `a missing photo falls back to the emoji`() = runTest {
        val path = renderer.render(
            Profile(id = 4, name = "Kid", avatarEmoji = "🤖", avatarColor = 0, weightKg = null, ftp = null, avatarPhotoPath = "/nowhere.jpg"),
        )

        assertTrue(File(path!!).length() > 0)
    }
}
