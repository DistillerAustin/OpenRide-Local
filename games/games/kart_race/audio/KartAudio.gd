class_name KartAudio
extends Node
## Kart Race's sound (#43): the music, its stems and tempo, and every effect, all through the
## framework's AudioDirector (SFX bus, MusicGen, SfxSynth). It only listens and reads: the race's
## events and the rider's KartState.
##
## - **Music**: the `kart_circuit` style (racing electronica), one and a half beats per pedal
##   stroke. Its tempo follows the rider's cadence on phrase boundaries (a request a few seconds
##   ahead, once a new cadence has held). Stems come in with `set_intensity`: drums and bass on
##   the grid, the arpeggio in the race, the lead near the front, in a boost and on the final
##   lap, which also swaps to a lifted variation (up a tone, busier), pre-rendered off the main
##   thread when the race starts so it's ready.
## - **Loops** on this node's own players (SFX bus, so the rider's effects volume applies): the
##   engine hum pitched by speed and opened up by power, a second hum for the nearest rival,
##   the tyre screech while drifting, the crowd near the grandstand.
## - **One-shots** (AudioDirector.play_sfx): countdown and go, tier pings, boost whoosh, item
##   pickup and roulette ticks, fire, hit, shield, bumps, the lap chime, the final-lap fanfare
##   and the finish cheer.

const STYLE := {"name": "kart_circuit", "stem_gates": {"harmony": 0.45, "lead": 0.7}}
## The final lap's variation (MusicStyle overrides).
const FINAL_LAP := {"transpose": 2, "energy": 1.0, "lead_density": 0.75}
const CADENCE_RANGE := Vector2(70.0, 100.0)  ## the tempo follows cadence within this
const TEMPO_STEP := 5.0
const TEMPO_HOLD_SEC := 6.0  ## a new cadence must hold this long before the tempo follows
const DEFAULT_CADENCE := 85.0
const ENGINE_DB := Vector2(-16.0, -7.0)  ## idle .. full power
const SILENT_DB := -60.0

var music_seed := 0
## The game, for its pause state.
var game: Game

var tempo_cadence := DEFAULT_CADENCE  ## the cadence the music plays at (× the style's 1.5)
var final_lap := false
var intensity := 0.0

var _engine: AudioStreamPlayer
var _rival: AudioStreamPlayer
var _screech: AudioStreamPlayer
var _crowd: AudioStreamPlayer
var _count_shown := -1
var _roulette_tick := 0.0
var _want_cadence := DEFAULT_CADENCE
var _want_for := 0.0
var _crowd_at := Vector3.ZERO
var _race: KartRaceLogic
var _prewarmed := ""


func _ready() -> void:
	name = "Audio"
	process_mode = Node.PROCESS_MODE_ALWAYS
	KartSfx.register()
	_engine = _loop("kart_engine")
	_rival = _loop("kart_engine")
	_screech = _loop("kart_screech")
	_crowd = _loop("kart_crowd")


func _loop(sound: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = AudioDirector.SFX_BUS
	p.stream = SfxSynth.stream(sound)
	p.volume_db = SILENT_DB
	add_child(p)
	return p


## The first music of the segment.
func start_music(cadence := DEFAULT_CADENCE) -> void:
	tempo_cadence = tempo_cadence_for(cadence)
	_want_cadence = tempo_cadence
	final_lap = false
	_request()
	set_intensity(0.3)


## A new race: hook its events, back to the normal music, and pre-render the final lap's.
func listen(race: KartRaceLogic) -> void:
	_race = race
	_count_shown = -1
	_crowd_at = race.track.position_at(0.0, 0.0)
	if final_lap:
		final_lap = false
		_request()
	_prewarm_final()
	var e := race.events
	var rider := KartRaceLogic.RIDER
	e.race_started.connect(func(): AudioDirector.play_sfx("kart_go"))
	e.lap_completed.connect(func(id: int, lap: int, _t: float):
		if id == rider and lap + 1 < race.laps:
			AudioDirector.play_sfx("kart_lap"))
	e.final_lap.connect(func(id: int):
		if id == rider:
			if race.laps > 1:
				AudioDirector.play_sfx("kart_fanfare")
			final_lap = true
			_request())
	e.kart_finished.connect(func(id: int, _place: int, _t: float):
		if id == rider:
			AudioDirector.play_sfx("kart_cheer")
			AudioDirector.play_sfx("kart_lap", 0.0, 1.5))
	e.drift_tier.connect(func(id: int, tier: int):
		if id == rider and tier >= 1:
			AudioDirector.play_sfx("kart_tier%d" % clampi(tier, 1, 3)))
	e.boost_started.connect(func(id: int, _kind: String, _tier: int):
		if id == rider:
			AudioDirector.play_sfx("kart_whoosh"))
	e.item_picked.connect(func(id: int, _item: String):
		if id == rider:
			AudioDirector.play_sfx("kart_pickup"))
	e.item_used.connect(func(id: int, _item: String):
		if id == rider:
			AudioDirector.play_sfx("kart_fire"))
	e.kart_hit.connect(func(id: int, by: int, _item: String):
		if id == rider or by == rider:
			AudioDirector.play_sfx("kart_hit", 0.0 if id == rider else -5.0))
	e.shield_blocked.connect(func(id: int):
		if id == rider:
			AudioDirector.play_sfx("kart_shield"))
	e.wall_bump.connect(func(id: int, strength: float):
		if id == rider:
			AudioDirector.play_sfx("kart_bump", linear_to_db(clampf(0.3 + strength, 0.3, 1.0))))
	e.kart_bump.connect(func(a: int, b: int, strength: float):
		if a == rider or b == rider:
			AudioDirector.play_sfx("kart_bump", linear_to_db(clampf(0.3 + strength, 0.3, 1.0)), 1.2))


## Every frame, from the game: the loops, the countdown, the roulette, intensity and tempo.
## `flow` is the game's Flow name ("COUNTDOWN", "RACING", "RESULTS", "PODIUM", …).
func step(race: KartRaceLogic, flow: String, delta: float) -> void:
	if race == null:
		return
	var k: KartState = race.karts[KartRaceLogic.RIDER]
	var racing := flow == "RACING"
	# Countdown beeps on 3, 2, 1 (GO comes with race_started).
	if race.phase == KartRaceLogic.Phase.COUNTDOWN:
		var n := ceili(race.countdown)
		if n != _count_shown and n >= 1 and n <= 3:
			_count_shown = n
			AudioDirector.play_sfx("kart_count")
	# Roulette ticks, slowing as it settles.
	if k.roulette_time > 0.0:
		_roulette_tick -= delta
		if _roulette_tick <= 0.0:
			_roulette_tick = 0.07 + 0.12 * clampf(1.0 - k.roulette_time / 0.6, 0.0, 1.0)
			AudioDirector.play_sfx("kart_roulette", -4.0, 0.9 + 0.2 * randf())
	# The rider's engine: pitch by speed, louder with power and in a boost.
	var on_track := flow in ["COUNTDOWN", "RACING", "RESULTS"]
	var power := clampf(InputBus.power / 300.0, 0.0, 1.0)
	_set_loop(_engine, on_track, engine_pitch(k.speed, k.boost_time > 0.0),
		lerpf(ENGINE_DB.x, ENGINE_DB.y, maxf(power, 0.25 if k.speed > 1.0 else 0.0)))
	# The nearest rival's hum, by distance.
	var near := INF
	var near_speed := 0.0
	for i in range(1, race.karts.size()):
		var o: KartState = race.karts[i]
		var dist := o.pos.distance_to(k.pos)
		if dist < near:
			near = dist
			near_speed = o.speed
	var rival_db := lerpf(ENGINE_DB.x - 2.0, SILENT_DB, clampf((near - 3.0) / 25.0, 0.0, 1.0))
	_set_loop(_rival, on_track and near < 28.0, engine_pitch(near_speed, false) * 1.07, rival_db)
	# Tyres in a drift.
	var drifting := racing and k.drift_dir != 0 and k.speed > 5.0
	_set_loop(_screech, drifting, 0.9 + 0.1 * k.drift_tier, -10.0)
	# The crowd near the start line (and cheering through the boards).
	var crowd_d := k.pos.distance_to(_crowd_at)
	var crowd_db := lerpf(-12.0, SILENT_DB, clampf((crowd_d - 15.0) / 70.0, 0.0, 1.0))
	if flow in ["RESULTS", "PODIUM"]:
		crowd_db = -10.0
	_set_loop(_crowd, crowd_db > -50.0, 1.0, crowd_db)
	# Stems and tempo.
	set_intensity(intensity_for(flow, k.place, k.boost_time > 0.0, final_lap))
	if racing:
		_follow_cadence(InputBus.cadence, delta)


func _process(_delta: float) -> void:
	var paused := game != null and game.paused
	for p: AudioStreamPlayer in [_engine, _rival, _screech, _crowd]:
		if p and p.stream_paused != paused:
			p.stream_paused = paused


func set_intensity(value: float) -> void:
	if absf(value - intensity) > 0.001:
		intensity = value
		AudioDirector.set_intensity(value)


## Silences the loops (the segment is over).
func stop() -> void:
	for p: AudioStreamPlayer in [_engine, _rival, _screech, _crowd]:
		p.stop()


## 0-1 for the stems: drums and bass on the grid (0.3), the arpeggio while racing (0.5), the lead
## in the top three or a boost (0.8), everything on the final lap and the podium (1.0).
static func intensity_for(flow: String, place: int, boosting: bool, final: bool) -> float:
	match flow:
		"RACING":
			if final:
				return 1.0
			return 0.8 if (place >= 1 and place <= 3) or boosting else 0.55
		"RESULTS":
			return 0.55
		"PODIUM":
			return 1.0
	return 0.3


## The engine's playback rate for a kart speed (m/s): a low idle that climbs through the range.
static func engine_pitch(speed: float, boosting: bool) -> float:
	return clampf(0.62 + speed / 24.0, 0.62, 2.1) * (1.08 if boosting else 1.0)


## The cadence the music follows: the rider's, clamped and stepped (so small wobbles don't
## re-render the music).
static func tempo_cadence_for(cadence: float) -> float:
	return snappedf(clampf(cadence, CADENCE_RANGE.x, CADENCE_RANGE.y), TEMPO_STEP)


## Asks for a tempo change once a new cadence has held for TEMPO_HOLD_SEC (AudioDirector swaps it
## in on the next phrase boundary).
func _follow_cadence(cadence: float, delta: float) -> void:
	if cadence < 30.0:
		return  # coasting: keep the tempo
	var want := tempo_cadence_for(cadence)
	if want != _want_cadence:
		_want_cadence = want
		_want_for = 0.0
	if want == tempo_cadence:
		return
	_want_for += delta
	if _want_for >= TEMPO_HOLD_SEC:
		tempo_cadence = want
		_request()


func music_request() -> Dictionary:
	var style := STYLE.duplicate(true)
	if final_lap:
		style.merge(FINAL_LAP, true)
	return style


func _request() -> void:
	AudioDirector.play_music(music_request(), tempo_cadence, music_seed)


## Renders the final lap's variation into MusicGen's disk cache on a worker thread, so the swap
## on the final lap only loads it.
func _prewarm_final() -> void:
	if not AudioDirector.music_enabled or not AudioDirector.has_music_generator() or DisplayServer.get_name() == "headless":
		return
	var style := STYLE.duplicate(true)
	style.merge(FINAL_LAP, true)
	var request := {"style": style, "tempo_bpm": tempo_cadence, "seed": music_seed}
	var key := JSON.stringify(request)
	if key == _prewarmed:
		return
	_prewarmed = key
	WorkerThreadPool.add_task(func(): MusicGen.generate(request), false, "kart final-lap music")


func _set_loop(p: AudioStreamPlayer, on: bool, pitch: float, db: float) -> void:
	if not on:
		if p.playing:
			p.volume_db = move_toward(p.volume_db, SILENT_DB, 3.0)
			if p.volume_db <= SILENT_DB + 1.0:
				p.stop()
		return
	if not p.playing and p.stream:
		p.volume_db = SILENT_DB
		p.play()
	p.pitch_scale = lerpf(p.pitch_scale, pitch, 0.15)
	p.volume_db = lerpf(p.volume_db, db, 0.12)
