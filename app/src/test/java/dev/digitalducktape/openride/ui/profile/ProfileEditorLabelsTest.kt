package dev.digitalducktape.openride.ui.profile

import org.junit.Assert.assertEquals
import org.junit.Test

class ProfileEditorLabelsTest {

    @Test
    fun `the photo button offers a retake once there is a photo`() {
        assertEquals("Take photo", ProfileEditorLabels.photoAction(hasPhoto = false))
        assertEquals("Retake photo", ProfileEditorLabels.photoAction(hasPhoto = true))
    }

    @Test
    fun `colour swatches are named by their place in the row`() {
        assertEquals("Avatar colour 1 of 8", ProfileEditorLabels.colorDescription(0, 8))
        assertEquals("Avatar colour 8 of 8", ProfileEditorLabels.colorDescription(7, 8))
    }

    @Test
    fun `icon swatches are named by their emoji`() {
        assertEquals("Avatar icon 🚴", ProfileEditorLabels.emojiDescription("🚴"))
    }
}
