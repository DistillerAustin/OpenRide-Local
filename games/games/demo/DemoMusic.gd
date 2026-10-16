extends RefCounted
## Warm Up: the game's rendered music and effects (#55). Written by
## games/tools/music/render_music.py from songs/demo.py; don't edit by hand.

const TITLE := "Warm Up"
const BPM := 122.0
const KEY := 5  ## the key's pitch class (0 = C)
const LOOP_FROM := 7.8688  ## seconds: the intro plays once, the rest loops
## The stems: the bed always plays; harmony and lead are gated by the game.
const STEM_FILES := {
	"bed": "res://games/demo/music/warm_up_bed.ogg",
	"harmony": "res://games/demo/music/warm_up_harmony.ogg",
	"lead": "res://games/demo/music/warm_up_lead.ogg",
}
const SOUNDS := {
	"dodge": "res://games/demo/music/sfx/dodge.ogg",
	"hit": "res://games/demo/music/sfx/hit.ogg",
}
