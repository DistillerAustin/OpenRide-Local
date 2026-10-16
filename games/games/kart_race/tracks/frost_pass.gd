extends RefCounted
## Frost Pass (#43): snowy pines and an ice-blue lake. About 1.3 km, clockwise: the start
## straight on the high shelf past a frozen tarn, a right-hander, then the downhill run through
## two banked drift corners (the Cornice, 32 m 100° right, and the pine bend, 30 m 100° left:
## tier 2 each, a straight after each) to the lake shore, a fast run along the ice to the lake
## hairpin (30 m, 150°: the tier-3 drift) and the long climb back up to the line. An original
## layout (KartTrackShape). Banked turns lean in by up to 0.18 rad (about 10°).

const WIDE := 7.5
const ROAD := 6.5
const HIGH := 10.0
const LAKE := -10.0


static func shape(a: float, b: float) -> KartTrackShape:
	var t := KartTrackShape.new(Vector2.ZERO, 0.0, HIGH, WIDE)
	t.straight(100.0)
	t.arc(50.0, -90.0, HIGH, ROAD)
	t.mark("items1")
	t.straight(40.0, HIGH + 1.0)
	t.mark("downhill")
	# About 5% down all the way to the lake. The Cornice, banked right (the left edge, the
	# outside, higher): a tier-2 drift onto the long straight.
	t.straight(25.0, 9.6, NAN, -0.16)
	t.arc(32.0, -100.0, 6.6)
	t.straight(120.0, 0.2, NAN, 0.0)
	# The pine bend, banked left: tier 2, onto the run to the lake.
	t.straight(25.0, -1.2, NAN, 0.18)
	t.arc(30.0, 100.0, -4.0)
	t.straight(a, -6.4, NAN, 0.0)
	t.mark("boost")
	t.straight(25.0, -7.8, NAN, -0.1)
	t.arc(55.0, -40.0, LAKE, NAN, 0.0)
	t.mark("lake")
	# Along the frozen lake to the hairpin at its far end: the long drift (tier 3).
	t.straight(b, LAKE)
	t.mark("hairpin")
	t.arc(30.0, -150.0, LAKE + 1.0, WIDE)
	t.mark("climb0")
	# The climb back up to the shelf, about 5%, with a gentle S on the way.
	t.straight(90.0, LAKE + 5.5, ROAD)
	t.arc(110.0, 22.0, LAKE + 7.6)
	t.arc(110.0, -22.0, LAKE + 9.7)
	t.straight(120.0, HIGH - 4.0)
	t.mark("climb1")
	t.arc(60.0, -80.0, HIGH)
	t.straight(100.0, HIGH, WIDE)
	return t


static func build() -> KartTrackDef:
	var ab := KartTrackShape.solve(shape)
	var t := shape(ab.x, ab.y)
	var def := t.def("frost_pass", "Frost Pass", "frost")
	def.verge = 4.0
	def.start_s = 0.0
	var m := t.marks
	var lap := t.length()
	def.zones = [
		{"type": "start", "s0": lap - 50.0, "s1": 50.0},
		{"type": "items", "s0": m.items1 + 20.0, "s1": m.items1 + 22.0},
		{"type": "items", "s0": m.hairpin - 50.0, "s1": m.hairpin - 48.0},
		{"type": "climb", "s0": m.climb0, "s1": m.climb1, "dir": "forward"},
		# Driven the other way round, the banked run is the climb.
		{"type": "climb", "s0": m.downhill, "s1": m.lake, "dir": "reversed"},
		{"type": "boost", "s0": m.boost + 2.0, "s1": m.boost + 8.0, "d": -2.6, "w": 1.4},
		{"type": "boost", "s0": m.boost + 2.0, "s1": m.boost + 8.0, "d": 2.6, "w": 1.4},
	]
	# The frozen lake lies below the shore straight, on its outside: the hairpin swings round
	# its far end, and the start shelf looks down on it.
	# A small frozen tarn lies off the start shelf, on its outside: the title shot looks across
	# the grid to it.
	def.landmarks = [
		{"type": "lake", "s": lap - 20.0, "d": -46.0, "r": 28.0, "hero": true},
		{"type": "lake", "s": m.lake + 50.0, "d": -88.0, "r": 70.0},
		# Ice-fishing huts out on the big lake, seen all along the shore straight.
		{"type": "huts", "s": m.lake + 50.0, "d": -88.0},
	]
	return def
