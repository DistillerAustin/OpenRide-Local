class_name KartMusicIndex
extends RefCounted
## Kart Race's rendered music (#43): written by games/tools/kart_music/render_kart_music.py; don't
## edit by hand. Per track: the race theme and the final lap's version (paths, the second the loop
## restarts at, the tempo, the key's pitch class), plus the results loop and the podium sting.

const DIR := "res://games/kart_race/music"

const THEMES := {
	"meadow_ring": {"title": "Sunny Side Lap", "bpm": 150.0, "key": 2, "final_key": 4, "main": "meadow_ring.ogg", "main_loop": 6.4000, "final": "meadow_ring_final.ogg", "final_loop": 3.2000},
	"canyon_dash": {"title": "Dust Devil Run", "bpm": 156.0, "key": 4, "final_key": 6, "main": "canyon_dash.ogg", "main_loop": 6.1538, "final": "canyon_dash_final.ogg", "final_loop": 3.0769},
	"harbor_lights": {"title": "Lights on the Water", "bpm": 140.0, "key": 5, "final_key": 7, "main": "harbor_lights.ogg", "main_loop": 6.8572, "final": "harbor_lights_final.ogg", "final_loop": 3.4286},
	"frost_pass": {"title": "Snowline Sprint", "bpm": 152.0, "key": 9, "final_key": 11, "main": "frost_pass.ogg", "main_loop": 6.3158, "final": "frost_pass_final.ogg", "final_loop": 3.1579},
}
const RESULTS := "results.ogg"
const PODIUM := "podium.ogg"
