class_name KartRoster
extends RefCounted
## The eight racers (#43), all original: an animal driver each, with a kart colour, a suit, a
## weight class (which picks the kart's design, KartModels) and a horn. The kart colours are
## eight well-spaced hues, so the HUD's racer list and the minimap read at a glance.
##
## Fields: id, name, species, color (the kart and helmet), accent (trim, wing, stripes), suit
## (the racing suit), eyes (iris colour), helmet (optional: a contrast to the fur), weight (0.85 light .. 1.15 heavy: kart-kart contacts),
## kart ("light" | "medium" | "heavy"), number, horn ({hz, ratio, beeps, wave}: see
## horn_preset), tagline (one line for menus and boards).

const RACERS := [
	{"id": "fox", "name": "Juniper", "species": "fox", "color": Color(1.0, 0.48, 0.1), "accent": Color(1.0, 0.93, 0.78),
		"suit": Color(0.2, 0.24, 0.42), "eyes": Color(0.45, 0.26, 0.1), "helmet": Color(0.97, 0.96, 0.92), "weight": 1.0, "kart": "medium", "number": 7,
		"horn": {"hz": 620.0, "ratio": 1.26, "beeps": 2, "wave": "square"}, "tagline": "Quick wits, quicker corners"},
	{"id": "panda", "name": "Tofu", "species": "panda", "color": Color(0.2, 0.78, 0.7), "accent": Color(0.97, 0.97, 0.95),
		"suit": Color(0.14, 0.15, 0.2), "eyes": Color(0.25, 0.18, 0.14), "weight": 1.15, "kart": "heavy", "number": 22,
		"horn": {"hz": 330.0, "ratio": 1.0, "beeps": 1, "wave": "saw"}, "tagline": "Slow to start, impossible to shove"},
	{"id": "frog", "name": "Pip", "species": "frog", "color": Color(0.55, 0.86, 0.18), "accent": Color(1.0, 0.86, 0.25),
		"suit": Color(0.98, 0.62, 0.16), "eyes": Color(0.2, 0.14, 0.08), "helmet": Color(1.0, 0.84, 0.2), "weight": 0.85, "kart": "light", "number": 5,
		"horn": {"hz": 880.0, "ratio": 1.5, "beeps": 3, "wave": "square"}, "tagline": "Hops every kerb on purpose"},
	{"id": "rabbit", "name": "Clover", "species": "rabbit", "color": Color(1.0, 0.45, 0.68), "accent": Color(1.0, 1.0, 1.0),
		"suit": Color(0.42, 0.26, 0.58), "eyes": Color(0.62, 0.22, 0.32), "weight": 0.85, "kart": "light", "number": 12,
		"horn": {"hz": 990.0, "ratio": 1.19, "beeps": 2, "wave": "triangle"}, "tagline": "Gone before you see the ears"},
	{"id": "bear", "name": "Bramble", "species": "bear", "color": Color(0.92, 0.2, 0.2), "accent": Color(1.0, 0.82, 0.3),
		"suit": Color(0.16, 0.16, 0.2), "eyes": Color(0.22, 0.13, 0.08), "weight": 1.15, "kart": "heavy", "number": 33,
		"horn": {"hz": 260.0, "ratio": 0.8, "beeps": 2, "wave": "saw"}, "tagline": "Takes the inside line, and the outside"},
	{"id": "otter", "name": "Ripple", "species": "otter", "color": Color(0.16, 0.5, 1.0), "accent": Color(0.85, 0.96, 1.0),
		"suit": Color(1.0, 0.8, 0.22), "eyes": Color(0.18, 0.12, 0.08), "weight": 1.0, "kart": "medium", "number": 9,
		"horn": {"hz": 520.0, "ratio": 1.33, "beeps": 2, "wave": "triangle"}, "tagline": "Slides through every corner"},
	{"id": "penguin", "name": "Pebble", "species": "penguin", "color": Color(1.0, 0.8, 0.12), "accent": Color(0.2, 0.3, 0.6),
		"suit": Color(0.22, 0.42, 0.85), "eyes": Color(0.12, 0.16, 0.3), "weight": 0.9, "kart": "light", "number": 44,
		"horn": {"hz": 740.0, "ratio": 0.75, "beeps": 2, "wave": "square"}, "tagline": "Cool head, warm tyres"},
	{"id": "raccoon", "name": "Scout", "species": "raccoon", "color": Color(0.6, 0.3, 0.95), "accent": Color(0.4, 0.95, 0.85),
		"suit": Color(0.18, 0.18, 0.22), "eyes": Color(0.3, 0.2, 0.1), "weight": 1.05, "kart": "medium", "number": 18,
		"horn": {"hz": 440.0, "ratio": 1.12, "beeps": 3, "wave": "saw"}, "tagline": "Always has a shortcut in mind"},
]

const KART_CLASSES := ["light", "medium", "heavy"]


static func ids() -> Array:
	return RACERS.map(func(r): return r.id)


static func names() -> Array:
	return RACERS.map(func(r): return r.name)


## Labels for the Driver option: "Juniper the fox".
static func option_labels() -> Array:
	return RACERS.map(func(r): return "%s the %s" % [r.name, r.species])


## The racer with this id (the first one for an unknown id).
static func racer(racer_id: String) -> Dictionary:
	for r in RACERS:
		if r.id == racer_id:
			return r
	return RACERS[0]


## The grid's racers, kart id order: the rider's pick first, then the others in roster order.
static func lineup(rider_racer_id: String, count := 8) -> Array:
	var first := racer(rider_racer_id)
	var out := [first]
	for r in RACERS:
		if out.size() >= count:
			break
		if r.id != first.id:
			out.append(r)
	return out


## The kart class for a racer: its `kart` field, else from its weight.
static func kart_class(r: Dictionary) -> String:
	var k := str(r.get("kart", ""))
	if k in KART_CLASSES:
		return k
	var w := float(r.get("weight", 1.0))
	return "light" if w < 0.95 else ("heavy" if w > 1.1 else "medium")


## The racer's horn as an SfxPreset (a short two-tone toot), for SfxSynth:
## `SfxSynth.add_preset("horn_" + id, KartRoster.horn_preset(id))`.
static func horn_preset(racer_id: String) -> SfxPreset:
	var h: Dictionary = racer(racer_id).get("horn", {})
	var p := SfxPreset.new()
	match str(h.get("wave", "square")):
		"saw":
			p.wave = SfxPreset.Wave.SAW
		"triangle":
			p.wave = SfxPreset.Wave.TRIANGLE
		_:
			p.wave = SfxPreset.Wave.SQUARE
	var hz := float(h.get("hz", 600.0))
	p.freq_start = hz
	p.freq_end = hz
	p.jump_ratio = float(h.get("ratio", 1.0))
	p.jump_time = 0.07
	p.attack = 0.008
	p.sustain = 0.1
	p.decay = 0.06
	p.vibrato_depth = 0.15
	p.vibrato_rate = 14.0
	p.lowpass_start = 3200.0
	p.lowpass_end = 2600.0
	p.repeats = int(h.get("beeps", 2))
	p.repeat_gap = 0.06
	p.volume = 0.42
	return p
