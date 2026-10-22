package dev.digitalducktape.openride.ui.profile

/** The profile editor's derived text, kept out of the composable so it can be unit-tested. */
object ProfileEditorLabels {
    /** The photo button: "Take photo", or "Retake photo" once the rider has one. */
    fun photoAction(hasPhoto: Boolean): String = if (hasPhoto) "Retake photo" else "Take photo"

    /** A colour swatch's spoken name: the colours have no names, so their place in the row. */
    fun colorDescription(index: Int, count: Int): String = "Avatar colour ${index + 1} of $count"

    /** An icon swatch's spoken name. */
    fun emojiDescription(emoji: String): String = "Avatar icon $emoji"
}
