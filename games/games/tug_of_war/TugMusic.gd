extends RefCounted
## Heave Together: the game's rendered music and effects (#55). Written by
## games/tools/music/render_music.py from songs/tug_of_war.py; don't edit by hand.

const TITLE := "Heave Together"
const BPM := 132.0
const KEY := 2  ## the key's pitch class (0 = C)
const LOOP_FROM := 7.2727  ## seconds: the intro plays once, the rest loops
## The stems: the bed always plays; harmony and lead are gated by the game.
const STEM_FILES := {
	"bed": "res://games/tug_of_war/music/heave_together_bed.ogg",
	"harmony": "res://games/tug_of_war/music/heave_together_harmony.ogg",
	"lead": "res://games/tug_of_war/music/heave_together_lead.ogg",
}
const SOUNDS := {
	"rope_creak": "res://games/tug_of_war/music/sfx/rope_creak.ogg",
	"surge_drumroll": "res://games/tug_of_war/music/sfx/surge_drumroll.ogg",
	"crowd_swell": "res://games/tug_of_war/music/sfx/crowd_swell.ogg",
	"win_sting": "res://games/tug_of_war/music/sfx/win_sting.ogg",
	"lose_sting": "res://games/tug_of_war/music/sfx/lose_sting.ogg",
	"splash": "res://games/tug_of_war/music/sfx/splash.ogg",
}
