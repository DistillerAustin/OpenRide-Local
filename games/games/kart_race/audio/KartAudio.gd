class_name KartAudio
extends Node
## Kart Race's sound (#43): the music and every effect, all through the framework's
## AudioDirector. It only listens and reads: the race's events, the rider's KartState and the
## HUD's place pops.
##
## - **Music**: produced tracks rendered offline (games/tools/kart_music, KartMusicIndex), one
##   theme per track, played as pre-rendered stems (AudioDirector `stem_files`): an intro over
##   the grid, then a verse-chorus-verse-bridge-chorus loop. The final lap crossfades to its own
##   version (a key change up, double-time hats, an extra lead), loaded ahead when the race
##   starts. The results board loops a laid-back groove; the podium plays a fanfare sting (a
##   cue, so the music ducks under it).
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

const DEFAULT_THEME := "meadow_ring"  ## for a track without a theme of its own
const FANFARE_ROOT := 11  ## kart_fanfare is in B; it's pitched to the final lap's key
const SILENT_DB := -60.0

## The engine. Pitch (playback rate of the 100 Hz layers) from idle to ENGINE_TOP_SPEED, on an
## exponential curve, ×ENGINE_BOOST_PITCH in a boost.
const ENGINE_PITCH := Vector2(0.85, 2.2)
const ENGINE_TOP_SPEED := 22.0  ## m/s: a kart's cruise is ~20
const ENGINE_BOOST_PITCH := 1.12
const ENGINE_DB := -8.5  ## the layers' level at cruise on the pedals
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
	"kart_whoosh": -3.0, "kart_pickup": -1.0, "kart_roulette": -3.0, "kart_fire": 0.0,
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

## The game, for its pause state.
var game: Game

var theme := DEFAULT_THEME  ## the race's music theme (KartMusicIndex.THEMES)
var final_lap := false

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
var _crowd_at := Vector3.ZERO
var _race: KartRaceLogic
var _flow := ""
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
	var podium := KartMusicIndex.DIR + "/" + KartMusicIndex.PODIUM
	if ResourceLoader.exists(podium):
		AudioDirector.register_sound("kart_podium", load(podium))


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


## A new race: its theme from the intro, the final lap's version loading in the background,
## and its events hooked.
func listen(race: KartRaceLogic) -> void:
	_race = race
	_count_shown = -1
	_crowd_at = race.track.position_at(0.0, 0.0)
	for i in _rival_ids.size():
		_rival_ids[i] = -1
	theme = theme_for(race.track.def.id if race.track.def else "")
	final_lap = false
	_request()
	var final_path := music_path(theme, true)
	if ResourceLoader.exists(final_path):
		ResourceLoader.load_threaded_request(final_path)  # cached for the final lap's swap
	# The lambdas below read `_race`, never `race`: capturing the race would keep every race alive
	# (race → events → lambda → race).
	var e := race.events
	var rider := KartRaceLogic.RIDER
	e.race_started.connect(func():
		_sfx("kart_go")
		AudioDirector.duck_music(DUCK_DB, DUCK_SEC.go))
	e.lap_completed.connect(func(id: int, lap: int, _t: float):
		if id == rider and lap + 1 < _race.laps:
			_sfx("kart_lap")  # with the "LAP n/m" banner
			AudioDirector.duck_music(DUCK_DB, DUCK_SEC.lap))
	e.final_lap.connect(func(id: int):
		if id == rider:
			if _race.laps > 1:  # with the "FINAL LAP!" banner, in the new key
				AudioDirector.play_sfx("kart_fanfare", SFX_DB.kart_fanfare, fanfare_pitch(theme))
				_engine_duck = ENGINE_DUCK_SEC
				AudioDirector.duck_music(DUCK_DB, DUCK_SEC.final)
			final_lap = true
			_request())
	e.kart_finished.connect(func(id: int, _place: int, _t: float):
		if id == rider:
			_sfx("kart_cheer")
			_sfx("kart_lap", 1.5)
			AudioDirector.play_sfx(KartSfx.horn(_race.karts[rider].racer_id), -3.0))
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


## Every frame, from the game: the loops, the countdown, the roulette, the results music.
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
	# The results groove and the podium sting.
	if flow != _flow:
		_flow = flow
		if flow == "RESULTS":
			AudioDirector.play_music(results_request(), 150.0)
		elif flow == "PODIUM":
			AudioDirector.play_cue("kart_podium")


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


## Silences the loops (the segment is over).
func stop() -> void:
	for p: AudioStreamPlayer in _loops:
		p.stop()


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


## The theme for a track id: its own, else DEFAULT_THEME.
static func theme_for(track_id: String) -> String:
	return track_id if KartMusicIndex.THEMES.has(track_id) else DEFAULT_THEME


static func music_path(theme_id: String, final: bool) -> String:
	var e: Dictionary = KartMusicIndex.THEMES[theme_for(theme_id)]
	return KartMusicIndex.DIR + "/" + str(e.final if final else e.main)


## The AudioDirector music request for a theme (`final`: the final lap's version).
static func music_style(theme_id: String, final: bool) -> Dictionary:
	var e: Dictionary = KartMusicIndex.THEMES[theme_for(theme_id)]
	return {"name": "kart_%s%s" % [theme_for(theme_id), "_final" if final else ""],
		"stem_files": {"mix": music_path(theme_id, final)},
		"loop_from": float(e.final_loop if final else e.main_loop)}


static func results_request() -> Dictionary:
	return {"name": "kart_results", "stem_files": {"mix": KartMusicIndex.DIR + "/" + KartMusicIndex.RESULTS}, "loop_from": 0.0}


## The final-lap fanfare's pitch: its B moved to the final lap's key (the nearest way).
static func fanfare_pitch(theme_id: String) -> float:
	var key := int(KartMusicIndex.THEMES[theme_for(theme_id)].final_key)
	var d := posmod(key - FANFARE_ROOT + 6, 12) - 6
	return pow(2.0, d / 12.0)


func music_request() -> Dictionary:
	return music_style(theme, final_lap)


func _request() -> void:
	var e: Dictionary = KartMusicIndex.THEMES[theme]
	AudioDirector.play_music(music_request(), float(e.bpm))


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
