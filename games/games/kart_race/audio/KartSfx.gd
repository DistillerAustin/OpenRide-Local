class_name KartSfx
extends RefCounted
## Kart Race's sound effects (#43): SfxSynth presets written in code (synth settings only, no
## recordings), registered once under `kart_*` names, played through AudioDirector. All original.
##
## Loops (played on KartAudio's own players, pitched and faded live): kart_engine (the rider's
## hum, pitched by speed), kart_screech (tyres in a drift), kart_crowd (the grandstand).
## One-shots: kart_tier1-3 (spark-tier pings), kart_whoosh (a boost), kart_pickup, kart_roulette
## (a tick per icon), kart_fire (an item thrown), kart_hit, kart_shield, kart_lap (the lap
## chime), kart_fanfare (the final lap), kart_count and kart_go (the countdown), kart_bump,
## kart_cheer (the finish).

const W := SfxPreset.Wave

## name -> property overrides on a fresh SfxPreset.
const PRESETS := {
	"kart_engine": {"wave": W.SAW, "noise_mix": 0.06, "freq_start": 62.0, "freq_end": 62.0, "sustain": 0.8,
		"vibrato_depth": 0.6, "vibrato_rate": 24.0, "lowpass_start": 700.0, "lowpass_end": 700.0,
		"highpass": 40.0, "volume": 0.6, "loop": true},
	"kart_screech": {"wave": W.SQUARE, "noise_mix": 0.55, "freq_start": 1180.0, "freq_end": 1180.0,
		"sustain": 0.6, "vibrato_depth": 1.2, "vibrato_rate": 17.0, "lowpass_start": 4200.0,
		"lowpass_end": 4200.0, "highpass": 700.0, "volume": 0.3, "loop": true},
	"kart_crowd": {"wave": W.NOISE, "sustain": 1.6, "lowpass_start": 1300.0, "lowpass_end": 1300.0,
		"highpass": 260.0, "volume": 0.5, "loop": true},
	"kart_tier1": {"wave": W.SINE, "freq_start": 1318.0, "freq_end": 1318.0, "attack": 0.002,
		"sustain": 0.03, "decay": 0.22, "punch": 0.4, "volume": 0.4},
	"kart_tier2": {"wave": W.SINE, "freq_start": 1568.0, "freq_end": 1568.0, "attack": 0.002,
		"sustain": 0.03, "decay": 0.25, "punch": 0.4, "volume": 0.3, "repeats": 2, "repeat_gap": 0.06},
	"kart_tier3": {"wave": W.TRIANGLE, "freq_start": 1976.0, "freq_end": 1976.0, "attack": 0.002,
		"sustain": 0.04, "decay": 0.3, "punch": 0.3, "volume": 0.22, "repeats": 3, "repeat_gap": 0.055,
		"vibrato_depth": 0.3, "vibrato_rate": 12.0},
	"kart_whoosh": {"wave": W.NOISE, "attack": 0.04, "sustain": 0.12, "decay": 0.4,
		"lowpass_start": 500.0, "lowpass_end": 6500.0, "highpass": 200.0, "volume": 0.7},
	"kart_pickup": {"wave": W.SQUARE, "freq_start": 784.0, "freq_end": 784.0, "attack": 0.003,
		"sustain": 0.06, "decay": 0.16, "jump_ratio": 1.5, "jump_time": 0.06, "lowpass_start": 4000.0,
		"volume": 0.32},
	"kart_roulette": {"wave": W.PULSE, "freq_start": 1700.0, "freq_end": 1500.0, "attack": 0.001,
		"sustain": 0.01, "decay": 0.035, "lowpass_start": 5000.0, "volume": 0.28},
	"kart_fire": {"wave": W.SAW, "noise_mix": 0.4, "freq_start": 360.0, "freq_end": 90.0, "attack": 0.003,
		"sustain": 0.05, "decay": 0.22, "punch": 0.5, "lowpass_start": 3000.0, "lowpass_end": 600.0,
		"volume": 0.55},
	"kart_hit": {"wave": W.SQUARE, "noise_mix": 0.5, "freq_start": 220.0, "freq_end": 55.0,
		"attack": 0.002, "sustain": 0.06, "decay": 0.45, "punch": 0.7, "lowpass_start": 1800.0,
		"lowpass_end": 250.0, "volume": 0.7},
	"kart_shield": {"wave": W.SINE, "freq_start": 520.0, "freq_end": 1040.0, "attack": 0.005,
		"sustain": 0.08, "decay": 0.45, "vibrato_depth": 0.7, "vibrato_rate": 18.0, "volume": 0.45},
	"kart_lap": {"wave": W.TRIANGLE, "freq_start": 880.0, "freq_end": 880.0, "attack": 0.003,
		"sustain": 0.06, "decay": 0.35, "jump_ratio": 1.5, "jump_time": 0.12, "volume": 0.45},
	"kart_fanfare": {"wave": W.SQUARE, "freq_start": 523.0, "freq_end": 523.0, "attack": 0.01,
		"sustain": 0.12, "decay": 0.3, "jump_ratio": 1.335, "jump_time": 0.1, "lowpass_start": 3200.0,
		"vibrato_depth": 0.2, "vibrato_rate": 6.0, "repeats": 3, "repeat_gap": 0.17, "volume": 0.27},
	"kart_count": {"wave": W.SQUARE, "freq_start": 659.0, "freq_end": 659.0, "attack": 0.003,
		"sustain": 0.12, "decay": 0.08, "lowpass_start": 3500.0, "volume": 0.38},
	"kart_go": {"wave": W.SQUARE, "freq_start": 1318.0, "freq_end": 1318.0, "attack": 0.003,
		"sustain": 0.35, "decay": 0.25, "punch": 0.3, "lowpass_start": 4000.0, "volume": 0.4},
	"kart_bump": {"wave": W.SINE, "noise_mix": 0.45, "freq_start": 120.0, "freq_end": 45.0,
		"attack": 0.002, "sustain": 0.03, "decay": 0.18, "punch": 0.6, "lowpass_start": 900.0,
		"volume": 0.7},
	"kart_cheer": {"wave": W.NOISE, "attack": 0.25, "sustain": 0.7, "decay": 1.3,
		"lowpass_start": 2600.0, "lowpass_end": 1600.0, "highpass": 300.0, "volume": 0.6},
}

static func names() -> Array:
	return PRESETS.keys()


static func preset(sound: String) -> SfxPreset:
	var p := SfxPreset.new()
	var props: Dictionary = PRESETS[sound]
	for key in props:
		p.set(key, props[key])
	return p


## Adds every preset to SfxSynth (rendered lazily on first play), and each racer's horn as
## `horn_<racer id>` (KartRoster.horn_preset). Cheap to call again: presets already there (and
## their cached renders) are kept.
static func register() -> void:
	for sound in PRESETS:
		if SfxSynth._presets.has(sound):
			continue
		SfxSynth.add_preset(sound, preset(sound))
	for id in KartRoster.ids():
		if not SfxSynth._presets.has(horn(id)):
			SfxSynth.add_preset(horn(id), KartRoster.horn_preset(id))


## The SfxSynth name of a racer's horn.
static func horn(racer_id: String) -> String:
	return "horn_" + racer_id
