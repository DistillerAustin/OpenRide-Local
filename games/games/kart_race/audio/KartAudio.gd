class_name KartAudio
extends Node
## Kart Race's sound (#43): the music, its stems and tempo, and every effect, all through the
## framework's AudioDirector (SFX bus, MusicGen, SfxSynth). It only listens and reads: the race's
## events, the rider's KartState and the HUD's place pops.
##
## - **Music**: the `kart_circuit` style (racing electronica), one and a half beats per pedal
##   stroke. Its tempo follows the rider's cadence on phrase boundaries (a request a few seconds
##   ahead, once a new cadence has held). Stems come in with `set_intensity`: drums and bass on
##   the grid, the arpeggio in the race, the lead near the front, in a boost and on the final
##   lap, which also swaps to a lifted variation (up a tone, an off-beat bass, a busier lead,
##   louder), pre-rendered off the main thread when the race starts so it's ready.
## - **Loops** on this node's own players (SFX bus, so the rider's effects volume applies):
##   - the rider's engine, two synth layers (KartSfx.ENGINES) crossfaded and pitched by speed,
##     louder on the pedals, brighter in a boost (`engine_mix`);
##   - the nearest bots' engines, at most RIVAL_VOICES of them, by distance, with a pass-by
##     pitch bend (`nearest_rivals`, `rival_db`);
##   - the tyres in a drift and the sparks' sizzle, which steps up with each tier;
##   - the crowd near the grandstand.
## - **One-shots** (AudioDirector.play_sfx), each on the same frame as what it marks on screen:
##   countdown and GO, tier pings, the boost whoosh (pitched by tier), item pickup and roulette
##   ticks, fire, hit, shield, bumps, place up and down (the HUD's place pop), the lap chime,
##   the final-lap fanfare and the finish cheer.
## - **The mix**: a limiter on Master (AudioDirector.set_bus_effects); the music ducks 3 dB
##   under the countdown and the lap and final-lap banners (AudioDirector.duck_music). Levels
##   are this file's constants, checked by tests/render_kart_audio.gd.

const STYLE := {"name": "kart_circuit", "stem_gates": {"harmony": 0.45, "lead": 0.7}}
## The final lap's variation (MusicStyle overrides).
const FINAL_LAP := {"transpose": 2, "energy": 1.0, "lead_density": 0.8, "bass": "offbeat", "loudness": 1.25}
const CADENCE_RANGE := Vector2(70.0, 100.0)  ## the tempo follows cadence within this
const TEMPO_STEP := 5.0
const TEMPO_HOLD_SEC := 6.0  ## a new cadence must hold this long before the tempo follows
const DEFAULT_CADENCE := 85.0
const SILENT_DB := -60.0

## The engine. Pitch (playback rate of the 100 Hz layers) from idle to ENGINE_TOP_SPEED, on an
## exponential curve, ×ENGINE_BOOST_PITCH in a boost.
const ENGINE_PITCH := Vector2(0.85, 2.2)
const ENGINE_TOP_SPEED := 22.0  ## m/s: a kart's cruise is ~20
const ENGINE_BOOST_PITCH := 1.12
const ENGINE_DB := -7.0  ## the layers' level at cruise on the pedals
const ENGINE_COAST_DB := -6.0  ## off the pedals
## Bot engines: the nearest few within RIVAL_RANGE m, RIVAL_DB at RIVAL_NEAR m, -6 dB per
## doubling beyond, faded out toward the edge of the range.
const RIVAL_VOICES := 2
const RIVAL_RANGE := 30.0
const RIVAL_NEAR := 3.0
const RIVAL_DB := -11.0
const DOPPLER := 0.004  ## pitch per m/s of closing speed (exaggerated, for the pass-by)
## Drift: tyres, and the sparks per tier (0-3).
const SCREECH_DB := -15.0
const SIZZLE_DB := [-60.0, -18.0, -12.5, -7.5]
const SIZZLE_PITCH := [1.0, 1.0, 1.2, 1.45]
## One-shot levels (player volume_db), so the cues read over the engine and music.
const SFX_DB := {
	"kart_count": -2.0, "kart_go": 0.0, "kart_tier1": -1.0, "kart_tier2": 0.0, "kart_tier3": 0.0,
	"kart_whoosh": -3.0, "kart_pickup": -1.0, "kart_roulette": -3.0, "kart_fire": -1.0,
	"kart_hit": -1.5, "kart_shield": -2.0, "kart_lap": -1.0, "kart_fanfare": 0.0, "kart_bump": -2.0,
	"kart_place_up": -2.0, "kart_place_down": -5.0, "kart_cheer": -3.0,
}
## The music's duck under the countdown and banners (dB, and seconds per moment).
const DUCK_DB := -3.0
const DUCK_SEC := {"count": 0.7, "go": 1.2, "lap": 1.9, "final": 2.4}
const PLACE_GAP_SEC := 0.12  ## place cues closer than this are dropped (the pop still shows)
## The cues the engine makes room for: it dips ENGINE_DUCK_DB for ENGINE_DUCK_SEC under them
## (their pings sit in the engine's harmonics, 1-4 kHz).
const PRIORITY := ["kart_count", "kart_go", "kart_tier1", "kart_tier2", "kart_tier3", "kart_pickup",
	"kart_lap", "kart_fanfare", "kart_place_up", "kart_place_down"]
const ENGINE_DUCK_DB := -5.0
const ENGINE_DUCK_SEC := 0.35

var music_seed := 0
## The game, for its pause state.
var game: Game

var tempo_cadence := DEFAULT_CADENCE  ## the cadence the music plays at (× the style's 1.5)
var final_lap := false
var intensity := 0.0

var _engine_lo: AudioStreamPlayer
var _engine_hi: AudioStreamPlayer
var _rivals: Array[AudioStreamPlayer] = []
var _rival_ids: Array[int] = []  # the bot each rival voice follows (-1: none)
var _screech: AudioStreamPlayer
var _sizzle: AudioStreamPlayer
var _crowd: AudioStreamPlayer
var _loops: Array[AudioStreamPlayer] = []
var _count_shown := -1
var _roulette_tick := 0.0
var _want_cadence := DEFAULT_CADENCE
var _want_for := 0.0
var _crowd_at := Vector3.ZERO
var _race: KartRaceLogic
var _prewarmed := ""
var _racing := false
var _clock := 0.0  # seconds of step()s, for the place cue's gap
var _place_at := -100.0  # _clock at the last place cue
var _engine_duck := 0.0  # seconds left of the engine's dip under a priority cue
var _near_scratch: Array[int] = []
var _paused := false
var _half := false  # which half-rate part steps this frame


func _ready() -> void:
	name = "Audio"
	process_mode = Node.PROCESS_MODE_ALWAYS
	KartSfx.register()
	_engine_lo = _loop("kart_engine_lo", "EngineLo")
	_engine_hi = _loop("kart_engine_hi", "EngineHi")
	for i in RIVAL_VOICES:
		_rivals.append(_loop("kart_engine_hi", "Rival%d" % i))
		_rival_ids.append(-1)
	_screech = _loop("kart_screech", "Screech")
	_sizzle = _loop(KartSfx.SIZZLE, "Sizzle")
	_crowd = _loop("kart_crowd", "Crowd")
	AudioDirector.set_bus_effects(AudioDirector.MASTER_BUS, master_effects())


## The whole mix's limiter: nothing the game plays can clip.
static func master_effects() -> Array[AudioEffect]:
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -1.0
	limiter.pre_gain_db = 0.0
	limiter.release = 0.12
	return [limiter]


func _loop(sound: String, player_name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = player_name
	p.bus = AudioDirector.SFX_BUS
	p.volume_db = SILENT_DB
	add_child(p)
	p.set_meta("sound", sound)
	_loops.append(p)
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
	for i in _rival_ids.size():
		_rival_ids[i] = -1
	if final_lap:
		final_lap = false
		_request()
	_prewarm_final()
	var e := race.events
	var rider := KartRaceLogic.RIDER
	e.race_started.connect(func():
		_sfx("kart_go")
		AudioDirector.duck_music(DUCK_DB, DUCK_SEC.go))
	e.lap_completed.connect(func(id: int, lap: int, _t: float):
		if id == rider and lap + 1 < race.laps:
			_sfx("kart_lap")  # with the "LAP n/m" banner
			AudioDirector.duck_music(DUCK_DB, DUCK_SEC.lap))
	e.final_lap.connect(func(id: int):
		if id == rider:
			if race.laps > 1:
				_sfx("kart_fanfare")  # with the "FINAL LAP!" banner
				AudioDirector.duck_music(DUCK_DB, DUCK_SEC.final)
			final_lap = true
			_request())
	e.kart_finished.connect(func(id: int, _place: int, _t: float):
		if id == rider:
			_sfx("kart_cheer")
			_sfx("kart_lap", 1.5)
			AudioDirector.play_sfx(KartSfx.horn(race.karts[rider].racer_id), -3.0))
	e.drift_tier.connect(func(id: int, tier: int):
		if id == rider and tier >= 1:
			_sfx("kart_tier%d" % clampi(tier, 1, 3)))
	e.boost_started.connect(func(id: int, kind: String, tier: int):
		if id == rider:
			_sfx("kart_whoosh", 1.0 + 0.06 * tier if kind == "drift" else 1.0))
	e.item_picked.connect(func(id: int, _item: String):
		if id == rider:
			_sfx("kart_pickup"))
	e.item_used.connect(func(id: int, _item: String):
		if id == rider:
			_sfx("kart_fire"))
	e.kart_hit.connect(func(id: int, by: int, _item: String):
		if id == rider or by == rider:
			AudioDirector.play_sfx("kart_hit", SFX_DB.kart_hit + (0.0 if id == rider else -5.0)))
	e.shield_blocked.connect(func(id: int):
		if id == rider:
			_sfx("kart_shield"))
	e.wall_bump.connect(func(id: int, strength: float):
		if id == rider:
			AudioDirector.play_sfx("kart_bump", SFX_DB.kart_bump + linear_to_db(clampf(0.3 + strength, 0.3, 1.0))))
	e.kart_bump.connect(func(a: int, b: int, strength: float):
		if a == rider or b == rider:
			AudioDirector.play_sfx("kart_bump", SFX_DB.kart_bump + linear_to_db(clampf(0.3 + strength, 0.3, 1.0)), 1.2))


## The HUD's place badge popped (KartHud.place_popped): its cue, on the same frame.
func on_place_popped(_place: int, better: bool) -> void:
	if not _racing:
		return
	if _clock - _place_at < PLACE_GAP_SEC:
		return
	_place_at = _clock
	_sfx("kart_place_up" if better else "kart_place_down")


func _sfx(sound: String, pitch := 1.0) -> void:
	AudioDirector.play_sfx(sound, SFX_DB.get(sound, 0.0), pitch)
	if sound in PRIORITY:
		_engine_duck = ENGINE_DUCK_SEC


## Every frame, from the game: the loops, the countdown, the roulette, intensity and tempo.
## `flow` is the game's Flow name ("COUNTDOWN", "RACING", "RESULTS", "PODIUM", …).
func step(race: KartRaceLogic, flow: String, delta: float) -> void:
	if race == null:
		return
	var k: KartState = race.karts[KartRaceLogic.RIDER]
	var racing := flow == "RACING"
	_racing = racing
	_clock += delta
	# Countdown beeps on 3, 2, 1 (GO comes with race_started), with the HUD's numbers.
	if race.phase == KartRaceLogic.Phase.COUNTDOWN:
		var n := ceili(race.countdown)
		if n != _count_shown and n >= 1 and n <= 3:
			_count_shown = n
			_sfx("kart_count")
			AudioDirector.duck_music(DUCK_DB, DUCK_SEC.count)
	# Roulette ticks, slowing as it settles.
	if k.roulette_time > 0.0:
		_roulette_tick -= delta
		if _roulette_tick <= 0.0:
			_roulette_tick = 0.07 + 0.12 * clampf(1.0 - k.roulette_time / 0.6, 0.0, 1.0)
			AudioDirector.play_sfx("kart_roulette", SFX_DB.kart_roulette, 0.9 + 0.2 * randf())
	_engine_duck = maxf(0.0, _engine_duck - delta)
	# The loops at half rate, alternating: the engines one frame, the drift and crowd the next
	# (the AudioServer glides each player's pitch and volume between).
	_half = not _half
	if _half:
		var on_track := flow == "RACING" or flow == "COUNTDOWN" or flow == "RESULTS"
		var m := engine_mix(k.speed, clampf(InputBus.power / 200.0, 0.0, 1.0), k.boost_time > 0.0)
		var dip := ENGINE_DUCK_DB if _engine_duck > 0.0 else 0.0
		_set_loop(_engine_lo, on_track, m.x, m.y + dip)
		_set_loop(_engine_hi, on_track, m.x, m.z + dip)
		_step_rivals(race, k, on_track)
	else:
		_step_drift_and_crowd(k, flow, racing)
	# Stems and tempo.
	set_intensity(intensity_for(flow, k.place, k.boost_time > 0.0, final_lap))
	if racing:
		_follow_cadence(InputBus.cadence, delta)


## The nearest bots' engines: each voice keeps its bot while that bot stays among the nearest.
func _step_rivals(race: KartRaceLogic, k: KartState, on_track: bool) -> void:
	nearest_rivals(race.karts, k, RIVAL_VOICES, RIVAL_RANGE, _near_scratch)
	for i in _rivals.size():
		if _rival_ids[i] not in _near_scratch:
			_rival_ids[i] = -1
	for id in _near_scratch:
		if id not in _rival_ids:
			_rival_ids[_rival_ids.find(-1)] = id
	for i in _rivals.size():
		var id := _rival_ids[i]
		if id < 0 or not on_track:
			_set_loop(_rivals[i], false, 1.0, SILENT_DB)
			continue
		var o: KartState = race.karts[id]
		var dist := o.pos.distance_to(k.pos)
		var pitch := engine_pitch(o.speed, o.boost_time > 0.0) * (1.06 if o.weight < 0.95 else (0.94 if o.weight > 1.05 else 1.0))
		pitch *= 1.0 + clampf(DOPPLER * closing_speed(k, o), -0.1, 0.1)
		_set_loop(_rivals[i], true, pitch, rival_db(dist))


## Tyres and sparks in a drift; the crowd near the start line (and cheering through the boards).
func _step_drift_and_crowd(k: KartState, flow: String, racing: bool) -> void:
	var drifting := racing and k.drift_dir != 0 and k.speed > 5.0
	var tier := clampi(k.drift_tier, 0, 3) if drifting else 0
	_set_loop(_screech, drifting, 0.9 + 0.08 * tier, SCREECH_DB)
	_set_loop(_sizzle, tier >= 1, SIZZLE_PITCH[tier], SIZZLE_DB[tier])
	var crowd_d := k.pos.distance_to(_crowd_at)
	var crowd_db := lerpf(-12.0, SILENT_DB, clampf((crowd_d - 15.0) / 70.0, 0.0, 1.0))
	if flow in ["RESULTS", "PODIUM"]:
		crowd_db = -10.0
	_set_loop(_crowd, crowd_db > -50.0, 1.0, crowd_db)


func _process(_delta: float) -> void:
	var paused := game != null and game.paused
	if paused == _paused:
		return
	_paused = paused
	for p: AudioStreamPlayer in _loops:
		p.stream_paused = paused


func set_intensity(value: float) -> void:
	if absf(value - intensity) > 0.001:
		intensity = value
		AudioDirector.set_intensity(value)


## Silences the loops (the segment is over).
func stop() -> void:
	for p: AudioStreamPlayer in _loops:
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


## The engine layers' playback rate for a kart speed (m/s): a low idle climbing exponentially
## (even steps in pitch for even steps in speed) to the cruise, higher in a boost.
static func engine_pitch(speed: float, boosting: bool) -> float:
	var x := clampf(speed / ENGINE_TOP_SPEED, 0.0, 1.15)
	return ENGINE_PITCH.x * pow(ENGINE_PITCH.y / ENGINE_PITCH.x, x) * (ENGINE_BOOST_PITCH if boosting else 1.0)


## The rider's engine for a speed, pedal effort (0-1) and boost: (pitch, lo_db, hi_db). The
## lumpy low layer carries the idle and fades as the revs rise; the buzzy high layer takes over,
## louder on the pedals, louder still in a boost.
static func engine_mix(speed: float, effort: float, boosting: bool) -> Vector3:
	var x := clampf(speed / ENGINE_TOP_SPEED, 0.0, 1.0)
	var on := clampf(maxf(effort, 0.3 if speed > 1.0 else 0.0), 0.0, 1.0)
	var level := ENGINE_DB + lerpf(ENGINE_COAST_DB, 0.0, on) + (2.0 if boosting else 0.0)
	return Vector3(engine_pitch(speed, boosting),
		level + linear_to_db(maxf(cos(x * PI * 0.5), 0.2)) - 1.0,
		level + linear_to_db(maxf(sin(x * PI * 0.5), 0.08)) + (1.0 if boosting else 0.0))


## The ids of up to `count` bots within `range_m` of the rider `k`, nearest first, into `out`.
static func nearest_rivals(karts: Array, k: KartState, count: int, range_m: float, out: Array[int]) -> void:
	out.clear()
	var dists: Array[float] = []
	for i in range(1, karts.size()):
		var o: KartState = karts[i]
		var d := o.pos.distance_to(k.pos)
		if d > range_m or o.finished:
			continue
		var at := dists.size()
		while at > 0 and dists[at - 1] > d:
			at -= 1
		if at >= count:
			continue
		dists.insert(at, d)
		out.insert(at, i)
		if out.size() > count:
			out.resize(count)
			dists.resize(count)


## A bot engine's level at `dist` m: RIVAL_DB close, -6 dB per doubling, fading out over the
## last third of the range.
static func rival_db(dist: float) -> float:
	var db := RIVAL_DB - 20.0 * log(maxf(dist, RIVAL_NEAR) / RIVAL_NEAR) / log(10.0)
	var edge := clampf((dist - RIVAL_RANGE * 0.66) / (RIVAL_RANGE * 0.34), 0.0, 1.0)
	return lerpf(db, SILENT_DB, edge)


## How fast `o` closes on `k` (m/s, + = getting nearer): for the pass-by pitch bend.
static func closing_speed(k: KartState, o: KartState) -> float:
	var to := o.pos - k.pos
	var d := to.length()
	if d < 0.01:
		return 0.0
	var vk := Vector3(-sin(k.heading), 0.0, -cos(k.heading)) * k.speed
	var vo := Vector3(-sin(o.heading), 0.0, -cos(o.heading)) * o.speed
	return (vk - vo).dot(to / d)


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
		_prewarm_final()


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
	if not p.playing:
		if p.stream == null:
			if not KartSfx.warmed():
				return  # still rendering off the main thread; starts next frame it's ready
			p.stream = KartSfx.stream(p.get_meta("sound"))
		p.volume_db = SILENT_DB
		p.pitch_scale = pitch
		p.play()
	p.pitch_scale = lerpf(p.pitch_scale, pitch, 0.28)  # per call, at 30 Hz
	p.volume_db = lerpf(p.volume_db, db, 0.22)
