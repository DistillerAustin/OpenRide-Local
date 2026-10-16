extends RefCounted
## Incoming!: the game's rendered music and effects (#55). Written by
## games/tools/music/render_music.py from songs/dodge_ball.py; don't edit by hand.

const TITLE := "Incoming!"
const BPM := 150.0
const KEY := 4  ## the key's pitch class (0 = C)
const LOOP_FROM := 6.4000  ## seconds: the intro plays once, the rest loops
## The stems: the bed always plays; harmony and lead are gated by the game.
const STEM_FILES := {
	"bed": "res://games/dodge_ball/music/incoming_bed.ogg",
	"harmony": "res://games/dodge_ball/music/incoming_harmony.ogg",
	"lead": "res://games/dodge_ball/music/incoming_lead.ogg",
}
const SOUNDS := {
	"launch_whoosh": "res://games/dodge_ball/music/sfx/launch_whoosh.ogg",
	"dodge_tick": "res://games/dodge_ball/music/sfx/dodge_tick.ogg",
	"catch_chime": "res://games/dodge_ball/music/sfx/catch_chime.ogg",
	"miss_whiff": "res://games/dodge_ball/music/sfx/miss_whiff.ogg",
	"fumble_thud": "res://games/dodge_ball/music/sfx/fumble_thud.ogg",
	"streak_chime": "res://games/dodge_ball/music/sfx/streak_chime.ogg",
	"hit_body": "res://games/dodge_ball/music/sfx/hit_body.ogg",
	"shield_zap": "res://games/dodge_ball/music/sfx/shield_zap.ogg",
	"shield_ready": "res://games/dodge_ball/music/sfx/shield_ready.ogg",
	"game_over": "res://games/dodge_ball/music/sfx/game_over.ogg",
}
