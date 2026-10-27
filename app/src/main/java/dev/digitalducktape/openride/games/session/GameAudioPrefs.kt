package dev.digitalducktape.openride.games.session

import dev.digitalducktape.openride.games.bridge.AudioSettings

/**
 * The rider's game audio volumes (the hub, #38, stores and edits them), 0..1. There is no game
 * music switch: game music plays unless the rider's own music app has a track, which the
 * games read live from the input frame (`rider_music`, see `docs/GAMES.md`), not from here.
 */
data class GameAudioPrefs(
    val musicVolume: Double = 0.8,
    val sfxVolume: Double = 1.0,
) {
    /** `segment.audio` and `hub_state.audio`. Effects always play. */
    fun resolve() = AudioSettings(
        musicVolume = musicVolume.coerceIn(0.0, 1.0),
        sfxVolume = sfxVolume.coerceIn(0.0, 1.0),
    )
}
