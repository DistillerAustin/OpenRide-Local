package dev.digitalducktape.openride.games.session

import dev.digitalducktape.openride.games.bridge.AudioSettings

/**
 * The rider's game audio settings (the hub, #38, stores and edits them). Volumes are 0..1.
 * [gameMusic] is the hub's Game music switch; even on, game music stays off while the rider's
 * own music app has a track, which the games read live from the input frame (`rider_music`,
 * see `docs/GAMES.md`), not from here. Effects always play.
 */
data class GameAudioPrefs(
    val gameMusic: Boolean = true,
    val musicVolume: Double = 0.8,
    val sfxVolume: Double = 1.0,
) {
    /** `segment.audio` and `hub_state.audio`. */
    fun resolve() = AudioSettings(
        music = gameMusic,
        musicVolume = musicVolume.coerceIn(0.0, 1.0),
        sfxVolume = sfxVolume.coerceIn(0.0, 1.0),
    )
}
