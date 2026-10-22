class_name HubMusic
extends Node
## The hub's music (spec §8.5): its own original theme (HubMusicIndex, rendered by
## games/tools/music from songs/hub.py), played through AudioDirector as three stems. The bed
## always plays; harmony comes in from 0.3 intensity and the lead from 0.7, and intensity
## follows pedalling (0 still, 0.5 at 60 rpm, 1.0 at 90 rpm or more), so the music wakes up as
## the rider spins. One `set_intensity` per 0.5 s tick: no _process.
##
## It honours `hub_state.audio` (music off: silence; the volumes apply at once), puts the mix
## limiter on Master as the games do, and ducks under the hub's dialogs (held while one shows)
## and its messages. Starting a game crossfades to the game's theme (AudioDirector's 2 s
## crossfade covers the intro card); back in the hub, the theme crossfades in.

const ENABLED := true
const TICK_SEC := 0.5
const GATES := {"harmony": 0.3, "lead": 0.7}
const HOLD_DUCK_SEC := 0.7  ## re-asked every tick while a dialog shows, so the duck holds

var playing := false  ## the hub asked for its music (and the rider's settings allow it)
var audio := {"music": true, "music_volume": 0.8, "sfx_volume": 1.0}
var _dialog := false
var _timer: Timer


func _init() -> void:
	name = "HubMusic"
	_timer = Timer.new()
	_timer.wait_time = TICK_SEC
	_timer.timeout.connect(tick)
	add_child(_timer)


## The request the hub plays (for AudioDirector.play_music).
static func style() -> Dictionary:
	return {"name": "hub", "stem_files": HubMusicIndex.STEM_FILES, "loop_from": HubMusicIndex.LOOP_FROM,
		"stem_gates": GATES}


## Intensity for a cadence: 0 still, 0.5 at 60 rpm, 1.0 at 90 rpm or more.
static func intensity_for(cadence: float) -> float:
	if cadence <= 0.0:
		return 0.0
	if cadence <= 60.0:
		return 0.5 * cadence / 60.0
	return clampf(0.5 + 0.5 * (cadence - 60.0) / 30.0, 0.5, 1.0)


## The hub shows: its theme plays (or crossfades in) with the rider's settings.
func play(new_audio: Dictionary = {}) -> void:
	if not new_audio.is_empty():
		audio = new_audio
	_apply_volumes()
	AudioDirector.set_bus_effects(AudioDirector.MASTER_BUS, GameMix.master_effects())
	playing = ENABLED and not HubMusicIndex.STEM_FILES.is_empty() and bool(audio.get("music", true))
	if playing:
		AudioDirector.play_music(style(), HubMusicIndex.BPM)
		AudioDirector.set_intensity(intensity_for(InputBus.cadence))
		if is_inside_tree():
			_timer.start()


## A plan starts: the game's music takes over (it crossfades in when the game asks for it).
func leave() -> void:
	playing = false
	_timer.stop()


## hub_state.audio changed (Settings, or the rider's own music started).
func apply_audio(new_audio: Dictionary) -> void:
	var was_on := bool(audio.get("music", true))
	audio = new_audio
	_apply_volumes()
	var on := bool(audio.get("music", true))
	if on and not was_on and Session.director.phase == SessionDirector.Phase.HUB:
		play()
	elif not on:
		playing = false


## A volume moved in Settings: heard at once, before hub_state confirms it.
func preview_volume(key: String, value: float) -> void:
	audio[key] = value
	_apply_volumes()


## A dialog shows (the exit confirmation, an explanation): the music ducks while it does.
func set_dialog(on: bool) -> void:
	_dialog = on
	if on:
		GameMix.duck_for_moment(HOLD_DUCK_SEC)


## A message (a toast, "Ride saved"): a short duck.
func duck_moment(seconds: float) -> void:
	GameMix.duck_for_moment(seconds)


func tick() -> void:
	if not playing:
		return
	AudioDirector.set_intensity(intensity_for(InputBus.cadence))
	if _dialog:
		GameMix.duck_for_moment(HOLD_DUCK_SEC)


func _apply_volumes() -> void:
	AudioDirector.set_volumes(bool(audio.get("music", true)), float(audio.get("music_volume", 0.8)),
		float(audio.get("sfx_volume", 1.0)))
