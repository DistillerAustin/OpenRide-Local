class_name HubMusicIndex
extends RefCounted
## Lobby Loop: the game's rendered music and effects (#55). Written by
## games/tools/music/render_music.py from songs/hub.py; don't edit by hand.

const TITLE := "Lobby Loop"
const BPM := 108.0
const KEY := 7  ## the key's pitch class (0 = C)
const LOOP_FROM := 8.8889  ## seconds: the intro plays once, the rest loops
## The stems: the bed always plays; harmony and lead are gated by the game.
const STEM_FILES := {
	"bed": "res://hub/music/lobby_loop_bed.ogg",
	"harmony": "res://hub/music/lobby_loop_harmony.ogg",
	"lead": "res://hub/music/lobby_loop_lead.ogg",
}
const SOUNDS := {
}
