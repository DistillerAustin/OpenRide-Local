extends RefCounted
## Night Shift: the game's rendered music and effects (#55). Written by
## games/tools/music/render_music.py from songs/safe_cracker.py; don't edit by hand.

const TITLE := "Night Shift"
const BPM := 120.0
const KEY := 0  ## the key's pitch class (0 = C)
const LOOP_FROM := 8.0000  ## seconds: the intro plays once, the rest loops
## The stems: the bed always plays; harmony and lead are gated by the game.
const STEM_FILES := {
	"bed": "res://games/safe_cracker/music/night_shift_bed.ogg",
	"harmony": "res://games/safe_cracker/music/night_shift_harmony.ogg",
	"lead": "res://games/safe_cracker/music/night_shift_lead.ogg",
}
const SOUNDS := {
	"tumbler_click": "res://games/safe_cracker/music/sfx/tumbler_click.ogg",
	"proximity_tick": "res://games/safe_cracker/music/sfx/proximity_tick.ogg",
	"soft_alarm": "res://games/safe_cracker/music/sfx/soft_alarm.ogg",
	"vault_open": "res://games/safe_cracker/music/sfx/vault_open.ogg",
	"door_creak": "res://games/safe_cracker/music/sfx/door_creak.ogg",
}
