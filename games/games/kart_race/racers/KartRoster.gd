class_name KartRoster
extends RefCounted
## The eight racers (#43), all original: an animal driver each, with a kart colour and a weight
## class. Placeholder looks for the walking skeleton; the racers agent owns the final cast
## (names, species, colours, models, horns).

## weight: 0.85 light .. 1.15 heavy (kart-kart contacts).
const RACERS := [
	{"id": "fox", "name": "Juniper", "species": "fox", "color": Color(0.95, 0.45, 0.12), "accent": Color(1.0, 0.92, 0.8), "weight": 1.0},
	{"id": "panda", "name": "Tofu", "species": "panda", "color": Color(0.92, 0.92, 0.95), "accent": Color(0.12, 0.12, 0.14), "weight": 1.15},
	{"id": "frog", "name": "Pip", "species": "frog", "color": Color(0.35, 0.8, 0.25), "accent": Color(0.95, 0.85, 0.3), "weight": 0.85},
	{"id": "rabbit", "name": "Clover", "species": "rabbit", "color": Color(0.95, 0.55, 0.75), "accent": Color(1.0, 1.0, 1.0), "weight": 0.85},
	{"id": "bear", "name": "Bramble", "species": "bear", "color": Color(0.55, 0.32, 0.18), "accent": Color(0.95, 0.75, 0.35), "weight": 1.15},
	{"id": "otter", "name": "Ripple", "species": "otter", "color": Color(0.2, 0.55, 0.95), "accent": Color(0.85, 0.95, 1.0), "weight": 1.0},
	{"id": "penguin", "name": "Pebble", "species": "penguin", "color": Color(0.15, 0.2, 0.35), "accent": Color(1.0, 0.65, 0.15), "weight": 0.9},
	{"id": "raccoon", "name": "Scout", "species": "raccoon", "color": Color(0.6, 0.25, 0.85), "accent": Color(0.7, 0.7, 0.72), "weight": 1.05},
]


static func ids() -> Array:
	return RACERS.map(func(r): return r.id)


static func names() -> Array:
	return RACERS.map(func(r): return r.name)


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
