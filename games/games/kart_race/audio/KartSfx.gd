class_name KartSfx
extends RefCounted
## Kart Race's sound effects (#43): all synthesised in code, no recordings, all original.
## Played through AudioDirector by name (`kart_*`), or on KartAudio's own loop players.
##
## Three kinds:
## - **Presets**: single-voice SfxSynth presets (PRESETS), registered with SfxSynth.
## - **Layered one-shots** (LAYERED): several SfxSynth voices mixed at offsets into one sound,
##   for cues that need a body and a sparkle (GO, the tier pings, the boost, the fanfare, ...).
## - **Synth loops** rendered here: the engine's two layers (ENGINES: a toy two-stroke, a pulse
##   per firing through two exhaust resonances, a lumpy idle layer and a buzzy high layer that
##   KartAudio crossfades and pitches by speed) and the drift sparks' sizzle (a crackle of short
##   high-passed noise bursts).
##
## Everything renders once, on a WorkerThreadPool thread when a race loads (`warm`), and is
## cached for the app's life; nothing synthesises per frame. A sound asked for before the worker
## got to it renders on the spot.
##
## Pitches sit in the music's key (kart_circuit: A Dorian; the final lap's B Dorian): the
## countdown on E, GO on E, the lap chime A-E, the tier pings rising to E, G and B, the fanfare
## B-E-F#-B.

const W := SfxPreset.Wave
const Dsp := preload("res://audio/Dsp.gd")

## Single-voice presets: name -> property overrides on a fresh SfxPreset.
const PRESETS := {
	"kart_screech": {"wave": W.TRIANGLE, "noise_mix": 0.45, "freq_start": 1180.0, "freq_end": 1180.0,
		"sustain": 0.6, "vibrato_depth": 0.9, "vibrato_rate": 13.0, "lowpass_start": 3800.0,
		"lowpass_end": 3800.0, "highpass": 600.0, "volume": 0.5, "loop": true},
	"kart_crowd": {"wave": W.NOISE, "sustain": 1.6, "lowpass_start": 1300.0, "lowpass_end": 1300.0,
		"highpass": 260.0, "volume": 0.5, "loop": true},
	"kart_roulette": {"wave": W.SQUARE, "noise_mix": 0.2, "freq_start": 2100.0, "freq_end": 1700.0, "attack": 0.001,
		"sustain": 0.008, "decay": 0.03, "punch": 0.6, "lowpass_start": 7000.0, "highpass": 600.0, "volume": 0.55},
	"kart_hit": {"wave": W.SQUARE, "noise_mix": 0.5, "freq_start": 220.0, "freq_end": 55.0,
		"attack": 0.002, "sustain": 0.06, "decay": 0.45, "punch": 0.7, "lowpass_start": 1800.0,
		"lowpass_end": 250.0, "volume": 0.7},
	"kart_shield": {"wave": W.SINE, "freq_start": 520.0, "freq_end": 1040.0, "attack": 0.005,
		"sustain": 0.08, "decay": 0.45, "vibrato_depth": 0.7, "vibrato_rate": 18.0, "volume": 0.45},
	"kart_count": {"wave": W.SQUARE, "freq_start": 659.0, "freq_end": 659.0, "attack": 0.002,
		"sustain": 0.1, "decay": 0.12, "punch": 0.35, "lowpass_start": 4000.0, "volume": 0.42},
	"kart_cheer": {"wave": W.NOISE, "attack": 0.25, "sustain": 0.7, "decay": 1.3,
		"lowpass_start": 2600.0, "lowpass_end": 1600.0, "highpass": 300.0, "volume": 0.6},
}

## Layered one-shots: name -> {layers: [[preset overrides, offset sec, gain]], peak}. Each is
## mixed, then scaled to `peak`.
const LAYERED := {
	# GO: the countdown's E an octave up, over its octave below and a fifth, with a burst.
	"kart_go": {"peak": 0.6, "layers": [
		[{"wave": W.SQUARE, "freq_start": 1318.0, "freq_end": 1318.0, "attack": 0.002, "sustain": 0.3,
			"decay": 0.3, "punch": 0.4, "lowpass_start": 4500.0, "volume": 0.5}, 0.0, 1.0],
		[{"wave": W.SAW, "freq_start": 659.0, "freq_end": 659.0, "attack": 0.002, "sustain": 0.3,
			"decay": 0.3, "lowpass_start": 3000.0, "volume": 0.5}, 0.0, 0.55],
		[{"wave": W.TRIANGLE, "freq_start": 1976.0, "freq_end": 1976.0, "attack": 0.002, "sustain": 0.25,
			"decay": 0.3, "volume": 0.5}, 0.0, 0.4],
		[{"wave": W.NOISE, "attack": 0.001, "sustain": 0.02, "decay": 0.12, "highpass": 2000.0, "volume": 0.5}, 0.0, 0.5],
	]},
	# Drift tiers: one rising blip, then two, then three with a sparkle: more and higher per tier,
	# up where the engine's harmonics thin out (2-4 kHz).
	"kart_tier1": {"peak": 0.55, "layers": [
		[{"wave": W.TRIANGLE, "freq_start": 1976.0, "freq_end": 2637.0, "sweep_time": 0.025, "attack": 0.001,
			"sustain": 0.03, "decay": 0.16, "punch": 0.5, "volume": 0.5}, 0.0, 1.0],
		[{"wave": W.SQUARE, "freq_start": 1318.0, "freq_end": 1318.0, "attack": 0.001, "sustain": 0.02,
			"decay": 0.1, "lowpass_start": 5000.0, "volume": 0.5}, 0.0, 0.35],
	]},
	"kart_tier2": {"peak": 0.6, "layers": [
		[{"wave": W.TRIANGLE, "freq_start": 1976.0, "freq_end": 2637.0, "sweep_time": 0.025, "attack": 0.001,
			"sustain": 0.03, "decay": 0.12, "punch": 0.5, "volume": 0.5}, 0.0, 0.8],
		[{"wave": W.TRIANGLE, "freq_start": 2349.0, "freq_end": 3136.0, "sweep_time": 0.025, "attack": 0.001,
			"sustain": 0.04, "decay": 0.2, "punch": 0.5, "volume": 0.5}, 0.07, 1.0],
		[{"wave": W.SQUARE, "freq_start": 1568.0, "freq_end": 1568.0, "attack": 0.001, "sustain": 0.02,
			"decay": 0.12, "lowpass_start": 5000.0, "volume": 0.5}, 0.07, 0.35],
	]},
	"kart_tier3": {"peak": 0.65, "layers": [
		[{"wave": W.TRIANGLE, "freq_start": 1976.0, "freq_end": 2637.0, "sweep_time": 0.025, "attack": 0.001,
			"sustain": 0.03, "decay": 0.1, "punch": 0.5, "volume": 0.5}, 0.0, 0.7],
		[{"wave": W.TRIANGLE, "freq_start": 2349.0, "freq_end": 3136.0, "sweep_time": 0.025, "attack": 0.001,
			"sustain": 0.03, "decay": 0.1, "punch": 0.5, "volume": 0.5}, 0.06, 0.85],
		[{"wave": W.SQUARE, "freq_start": 2960.0, "freq_end": 3951.0, "sweep_time": 0.025, "attack": 0.001,
			"sustain": 0.05, "decay": 0.28, "punch": 0.5, "lowpass_start": 8000.0, "vibrato_depth": 0.25,
			"vibrato_rate": 14.0, "volume": 0.5}, 0.12, 1.0],
		[{"wave": W.SQUARE, "freq_start": 1976.0, "freq_end": 1976.0, "attack": 0.001, "sustain": 0.04,
			"decay": 0.2, "lowpass_start": 5000.0, "volume": 0.5}, 0.12, 0.4],
		[{"wave": W.NOISE, "attack": 0.01, "sustain": 0.05, "decay": 0.3, "highpass": 5000.0, "volume": 0.5}, 0.12, 0.35],
	]},
	# The boost: an air rush opening up, a rising engine-ish swell and a low kick of thrust.
	"kart_whoosh": {"peak": 0.7, "layers": [
		[{"wave": W.NOISE, "attack": 0.03, "sustain": 0.12, "decay": 0.45, "lowpass_start": 600.0,
			"lowpass_end": 7500.0, "highpass": 250.0, "volume": 0.6}, 0.0, 1.0],
		[{"wave": W.SAW, "freq_start": 220.0, "freq_end": 660.0, "sweep_time": 0.35, "attack": 0.02,
			"sustain": 0.15, "decay": 0.35, "lowpass_start": 900.0, "lowpass_end": 3500.0, "highpass": 180.0,
			"volume": 0.5}, 0.0, 0.45],
		[{"wave": W.SINE, "freq_start": 110.0, "freq_end": 55.0, "attack": 0.002, "sustain": 0.03,
			"decay": 0.12, "punch": 0.6, "volume": 0.5}, 0.0, 0.5],
	]},
	# An item lands in the button: a hop up a fifth with a glint.
	"kart_pickup": {"peak": 0.55, "layers": [
		[{"wave": W.SQUARE, "freq_start": 784.0, "freq_end": 784.0, "attack": 0.002, "sustain": 0.06,
			"decay": 0.16, "jump_ratio": 1.5, "jump_time": 0.06, "lowpass_start": 4500.0, "volume": 0.5}, 0.0, 1.0],
		[{"wave": W.SINE, "freq_start": 2352.0, "freq_end": 2352.0, "attack": 0.002, "sustain": 0.03,
			"decay": 0.18, "volume": 0.5}, 0.06, 0.4],
	]},
	"kart_lap": {"peak": 0.55, "layers": [
		[{"wave": W.TRIANGLE, "freq_start": 880.0, "freq_end": 880.0, "attack": 0.003, "sustain": 0.06,
			"decay": 0.35, "jump_ratio": 1.5, "jump_time": 0.12, "volume": 0.5}, 0.0, 1.0],
		[{"wave": W.SQUARE, "freq_start": 1760.0, "freq_end": 1760.0, "attack": 0.003, "sustain": 0.05,
			"decay": 0.3, "jump_ratio": 1.5, "jump_time": 0.12, "lowpass_start": 5000.0, "volume": 0.5}, 0.0, 0.25],
	]},
	# The final lap: root, fourth, fifth, octave in B, the last note held.
	"kart_fanfare": {"peak": 0.6, "layers": [
		[{"wave": W.SQUARE, "freq_start": 494.0, "freq_end": 494.0, "attack": 0.004, "sustain": 0.08,
			"decay": 0.08, "lowpass_start": 3600.0, "volume": 0.5}, 0.0, 0.8],
		[{"wave": W.SQUARE, "freq_start": 659.0, "freq_end": 659.0, "attack": 0.004, "sustain": 0.08,
			"decay": 0.08, "lowpass_start": 3600.0, "volume": 0.5}, 0.13, 0.8],
		[{"wave": W.SQUARE, "freq_start": 740.0, "freq_end": 740.0, "attack": 0.004, "sustain": 0.08,
			"decay": 0.08, "lowpass_start": 3600.0, "volume": 0.5}, 0.26, 0.85],
		[{"wave": W.SQUARE, "freq_start": 988.0, "freq_end": 988.0, "attack": 0.004, "sustain": 0.35,
			"decay": 0.4, "lowpass_start": 4200.0, "vibrato_depth": 0.2, "vibrato_rate": 6.0, "volume": 0.5}, 0.39, 1.0],
		[{"wave": W.SAW, "freq_start": 494.0, "freq_end": 494.0, "attack": 0.01, "sustain": 0.35,
			"decay": 0.4, "lowpass_start": 2400.0, "volume": 0.5}, 0.39, 0.45],
	]},
	# An item thrown: a downward zap with a snap of air on top.
	"kart_fire": {"peak": 0.6, "layers": [
		[{"wave": W.SAW, "noise_mix": 0.4, "freq_start": 360.0, "freq_end": 90.0, "attack": 0.003,
			"sustain": 0.05, "decay": 0.22, "punch": 0.5, "lowpass_start": 3000.0, "lowpass_end": 600.0,
			"volume": 0.5}, 0.0, 1.0],
		[{"wave": W.SQUARE, "noise_mix": 0.3, "freq_start": 1800.0, "freq_end": 700.0, "attack": 0.001,
			"sustain": 0.02, "decay": 0.08, "lowpass_start": 7000.0, "highpass": 900.0, "volume": 0.5}, 0.0, 0.5],
	]},
	# A barrier or a kart: a low thud with a hard plastic knock on top.
	"kart_bump": {"peak": 0.7, "layers": [
		[{"wave": W.SINE, "noise_mix": 0.45, "freq_start": 120.0, "freq_end": 45.0, "attack": 0.002,
			"sustain": 0.03, "decay": 0.18, "punch": 0.6, "lowpass_start": 900.0, "volume": 0.5}, 0.0, 1.0],
		[{"wave": W.TRIANGLE, "noise_mix": 0.3, "freq_start": 640.0, "freq_end": 380.0, "attack": 0.001,
			"sustain": 0.01, "decay": 0.06, "punch": 0.8, "lowpass_start": 4000.0, "volume": 0.5}, 0.0, 0.6],
	]},
	# Places: up a fifth, bright; down a fifth, darker.
	"kart_place_up": {"peak": 0.55, "layers": [
		[{"wave": W.TRIANGLE, "freq_start": 880.0, "freq_end": 880.0, "attack": 0.002, "sustain": 0.04,
			"decay": 0.2, "jump_ratio": 1.5, "jump_time": 0.07, "punch": 0.4, "volume": 0.5}, 0.0, 1.0],
		[{"wave": W.SQUARE, "freq_start": 1760.0, "freq_end": 1760.0, "attack": 0.002, "sustain": 0.03,
			"decay": 0.16, "jump_ratio": 1.5, "jump_time": 0.07, "lowpass_start": 5000.0, "volume": 0.5}, 0.0, 0.3],
	]},
	"kart_place_down": {"peak": 0.45, "layers": [
		[{"wave": W.SQUARE, "freq_start": 659.0, "freq_end": 659.0, "attack": 0.002, "sustain": 0.04,
			"decay": 0.18, "jump_ratio": 0.667, "jump_time": 0.07, "lowpass_start": 2200.0, "volume": 0.5}, 0.0, 1.0],
	]},
}

## The engine's layers: synthesised loops (see _engine). f0 is the firing rate at pitch_scale 1.
const ENGINES := {
	# Lumpy and round: the idle and low revs. Uneven firings (a two-stroke's lope).
	"kart_engine_lo": {"f0": 100.0, "cycles": 80, "pulse": 0.3, "noise": 0.25, "lumps": [1.0, 0.62, 0.86, 0.55],
		"amp_jitter": 0.12, "time_jitter": 0.02, "f1": 520.0, "q1": 3.0, "f2": 1250.0, "q2": 5.0, "f2_mix": 0.35,
		"direct": 0.45, "lowpass": 2600.0, "highpass": 140.0, "seed": 11},
	# Buzzy and bright: the high revs. Even firings, a rasp of noise, a higher pipe resonance.
	"kart_engine_hi": {"f0": 100.0, "cycles": 80, "pulse": 0.18, "noise": 0.4, "lumps": [1.0, 0.93, 0.97, 0.9],
		"amp_jitter": 0.08, "time_jitter": 0.01, "f1": 880.0, "q1": 4.0, "f2": 2300.0, "q2": 6.0, "f2_mix": 0.5,
		"direct": 0.35, "lowpass": 5200.0, "highpass": 180.0, "seed": 23},
}
## The drift sparks: a crackle that KartAudio pitches and raises per tier.
const SIZZLE := "kart_sizzle"
const SIZZLE_SEC := 0.8
const LOOP_PEAK := 0.8  ## synth loops are scaled to this peak

static var _streams := {}  # name -> AudioStreamWAV (the layered and synth sounds)
static var _mutex := Mutex.new()
static var _factory := Callable()  # AudioDirector's factory for the layered and synth sounds
static var _warm_task := -1


## Every kart sound's name (not the horns).
static func names() -> Array:
	return PRESETS.keys() + LAYERED.keys() + ENGINES.keys() + [SIZZLE]


static func is_loop(sound: String) -> bool:
	return sound in ENGINES or sound == SIZZLE or bool(PRESETS.get(sound, {}).get("loop", false))


## A single-voice preset (PRESETS) as an SfxPreset.
static func preset(sound: String) -> SfxPreset:
	return _preset_from(PRESETS[sound])


static func _preset_from(props: Dictionary) -> SfxPreset:
	var p := SfxPreset.new()
	for key in props:
		p.set(key, props[key])
	return p


## A kart sound's samples, rendered now (deterministic).
static func samples(sound: String) -> PackedFloat32Array:
	if sound in PRESETS:
		return SfxSynth.render_samples(preset(sound))
	if sound in LAYERED:
		return _layered(LAYERED[sound])
	if sound in ENGINES:
		return _engine(ENGINES[sound])
	if sound == SIZZLE:
		return _sizzle()
	return PackedFloat32Array()


## A kart sound's stream: SfxSynth's cache for presets, this class's for the rest. Renders on
## the spot if `warm` hasn't got to it yet. Thread-safe.
static func stream(sound: String) -> AudioStreamWAV:
	if sound in PRESETS or sound.begins_with("horn_"):
		return SfxSynth.stream(sound)
	if not (sound in LAYERED or sound in ENGINES or sound == SIZZLE):
		return null
	_mutex.lock()
	var cached: AudioStreamWAV = _streams.get(sound)
	_mutex.unlock()
	if cached:
		return cached
	var wav := Dsp.to_wav(samples(sound), is_loop(sound))
	_mutex.lock()
	_streams[sound] = wav
	_mutex.unlock()
	return wav


## Adds the presets and each racer's horn (`horn_<racer id>`, KartRoster.horn_preset) to
## SfxSynth, lets AudioDirector find the layered and synth sounds by name, and starts `warm`.
## Cheap to call again: what's there (and its cached renders) is kept.
static func register() -> void:
	for sound in PRESETS:
		if not SfxSynth._presets.has(sound):
			SfxSynth.add_preset(sound, preset(sound))
	for id in KartRoster.ids():
		if not SfxSynth._presets.has(horn(id)):
			SfxSynth.add_preset(horn(id), KartRoster.horn_preset(id))
	var director: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("AudioDirector") if Engine.get_main_loop() is SceneTree else null
	if not _factory.is_valid():
		_factory = func(sound: String) -> AudioStream:
			return stream(sound) if sound in LAYERED or sound in ENGINES or sound == SIZZLE else null
	if director and not director._sound_factories.has(_factory):  # once (tests clear the list)
		director.register_sound_factory(_factory)
	warm()


## Renders every kart sound and horn on a WorkerThreadPool thread, once per app run, so no
## sound renders on the main thread mid-race.
static func warm() -> void:
	if _warm_task != -1:
		return
	var all: Array = names()
	for id in KartRoster.ids():
		all.append(horn(id))
	_warm_task = WorkerThreadPool.add_task(func():
		for sound in all:
			stream(sound), false, "kart sfx")


## True once `warm` has rendered everything (or was never started).
static func warmed() -> bool:
	return _warm_task == -1 or WorkerThreadPool.is_task_completed(_warm_task)


## The SfxSynth name of a racer's horn.
static func horn(racer_id: String) -> String:
	return "horn_" + racer_id


# --- Rendering ---

static func _layered(def: Dictionary) -> PackedFloat32Array:
	var parts := []
	var n := 0
	for layer: Array in def.layers:
		var s := SfxSynth.render_samples(_preset_from(layer[0]))
		var at := int(float(layer[1]) * Dsp.SR)
		parts.append([s, at, float(layer[2])])
		n = maxi(n, at + s.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for part: Array in parts:
		Dsp.mix_into(out, part[0], part[1], part[2])
	_scale_to(out, float(def.peak))
	Dsp.fade_edges(out, 8, 32)
	return out


## A toy two-stroke: per firing, a half-sine pulse and a burst of noise (each firing's level
## varies: `lumps` repeats a lope, plus jitter), through two exhaust resonances, low-passed and
## high-passed clear of the music's bass. Rendered twice over and the second pass kept, so the
## resonators' ring carries over the loop point: it loops without a seam.
static func _engine(e: Dictionary) -> PackedFloat32Array:
	var sr := float(Dsp.SR)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(e.seed)
	var cycles := int(e.cycles)
	var lumps: Array = e.lumps
	var starts := PackedInt32Array()
	var amps := PackedFloat32Array()
	var lens := PackedInt32Array()
	var pos := 0.0
	var period := sr / float(e.f0)
	for c in cycles:
		var len_c := period * (1.0 + float(e.time_jitter) * rng.randf_range(-1.0, 1.0))
		starts.append(int(pos))
		lens.append(int(len_c))
		amps.append(float(lumps[c % lumps.size()]) * (1.0 + float(e.amp_jitter) * rng.randf_range(-1.0, 1.0)))
		pos += len_c
	var n := int(pos)
	var exc := PackedFloat32Array()
	exc.resize(n)
	var noise := Dsp.noise()
	var ni := rng.randi() & (Dsp.NOISE_SIZE - 1)
	for c in cycles:
		var w := maxi(2, int(lens[c] * float(e.pulse)))
		var tau := lens[c] * 0.3
		for k in lens[c]:
			var i := starts[c] + k
			if i >= n:
				break
			var v := sin(PI * k / w) if k < w else 0.0
			v += float(e.noise) * noise[ni] * exp(-k / tau)
			ni = (ni + 1) & (Dsp.NOISE_SIZE - 1)
			exc[i] = v * amps[c]
	var r1 := _bandpass(float(e.f1), float(e.q1))
	var r2 := _bandpass(float(e.f2), float(e.q2))
	var lp := Dsp.lp_coef(float(e.lowpass))
	var hp := Dsp.lp_coef(float(e.highpass))
	var out := PackedFloat32Array()
	out.resize(n)
	var s1 := [0.0, 0.0, 0.0, 0.0]  # x1 x2 y1 y2
	var s2 := [0.0, 0.0, 0.0, 0.0]
	var lp_y := 0.0
	var hp_low := 0.0
	var f2_mix := float(e.f2_mix)
	var direct := float(e.direct)
	for rep in 2:
		for i in n:
			var x := exc[i]
			var y1 := _biquad(r1, s1, x)
			var y2 := _biquad(r2, s2, x)
			var y := y1 + y2 * f2_mix + x * direct
			lp_y += lp * (y - lp_y)
			hp_low += hp * (lp_y - hp_low)
			if rep == 1:
				out[i] = lp_y - hp_low
	_scale_to(out, LOOP_PEAK)
	return out


## The drift sparks: a dense crackle of tiny noise bursts, high-passed twice (the second pass
## kept, so the loop has no seam).
static func _sizzle() -> PackedFloat32Array:
	var sr := float(Dsp.SR)
	var n := int(SIZZLE_SEC * sr)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var raw := PackedFloat32Array()
	raw.resize(n)
	var noise := Dsp.noise()
	var ni := 0
	for i in n:  # a faint bed of hiss
		raw[i] = noise[ni] * 0.12
		ni = (ni + 1) & (Dsp.NOISE_SIZE - 1)
	var crackles := int(SIZZLE_SEC * 520.0)
	for c in crackles:
		var at := rng.randi_range(0, n - 1)
		var amp := rng.randf_range(0.25, 1.0)
		var tau := rng.randf_range(0.0006, 0.0025) * sr
		for k in int(tau * 5.0):
			raw[(at + k) % n] += noise[ni] * amp * exp(-k / tau)
			ni = (ni + 1) & (Dsp.NOISE_SIZE - 1)
	var hp := Dsp.lp_coef(3200.0)
	var a := 0.0
	var b := 0.0
	var out := PackedFloat32Array()
	out.resize(n)
	for rep in 2:
		for i in n:
			a += hp * (raw[i] - a)
			var y := raw[i] - a
			b += hp * (y - b)
			if rep == 1:
				out[i] = y - b
	_scale_to(out, LOOP_PEAK)
	return out


## RBJ band-pass (0 dB peak) coefficients: [b0, b2, a1, a2] (b1 = 0).
static func _bandpass(f: float, q: float) -> PackedFloat32Array:
	var w := TAU * f / Dsp.SR
	var alpha := sin(w) / (2.0 * q)
	var a0 := 1.0 + alpha
	return PackedFloat32Array([alpha / a0, -alpha / a0, -2.0 * cos(w) / a0, (1.0 - alpha) / a0])


static func _biquad(c: PackedFloat32Array, s: Array, x: float) -> float:
	var y: float = c[0] * x + c[1] * s[1] - c[2] * s[2] - c[3] * s[3]
	s[1] = s[0]
	s[0] = x
	s[3] = s[2]
	s[2] = y
	return y


static func _scale_to(buf: PackedFloat32Array, peak: float) -> void:
	var m := 0.0
	for v in buf:
		m = maxf(m, absf(v))
	if m <= 0.0:
		return
	var g := peak / m
	for i in buf.size():
		buf[i] *= g
