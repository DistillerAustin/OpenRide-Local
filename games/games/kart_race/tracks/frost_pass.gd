extends RefCounted
## Frost Pass (#43): snowy pines and an ice-blue lake. About 1.3 km, clockwise: the start
## straight on the high shelf, a right-hander, then the downhill run through three banked turns
## to the lake shore, a fast sweep along the ice, and the long climb back up to the line. An
## original layout (KartTrackShape). Banked turns lean in by up to 0.18 rad (about 10°).

const WIDE := 7.5
const ROAD := 6.5
const HIGH := 10.0
const LAKE := -10.0


static func shape(a: float, b: float) -> KartTrackShape:
	var t := KartTrackShape.new(Vector2.ZERO, 0.0, HIGH, WIDE)
	t.straight(100.0)
	t.arc(60.0, -90.0, HIGH, ROAD)
	t.mark("items1")
	t.straight(40.0, HIGH + 1.0)
	t.mark("downhill")
	# About 5% down. Banked right: the left edge (the outside) higher.
	t.straight(25.0, 9.8, NAN, -0.16)
	t.arc(55.0, -60.0, 7.0)
	t.straight(90.0, 2.5, NAN, 0.0)
	# Banked left.
	t.straight(25.0, 1.3, NAN, 0.18)
	t.arc(55.0, 60.0, -1.5)
	t.straight(a, -3.8, NAN, 0.0)
	t.mark("boost")
	# Banked right, down onto the lake shore.
	t.straight(25.0, -5.0, NAN, -0.14)
	t.arc(60.0, -90.0, LAKE + 0.5)
	t.mark("lake")
	t.straight(b, LAKE, NAN, 0.0)
	t.mark("items2")
	t.arc(55.0, -90.0, LAKE + 3.0)
	t.mark("climb0")
	# The climb back up to the shelf, about 5%, with a gentle S on the way.
	t.straight(90.0, -2.5)
	t.arc(110.0, 22.0, -0.4)
	t.arc(110.0, -22.0, 1.7)
	t.straight(120.0, 7.7)
	t.mark("climb1")
	t.arc(60.0, -90.0, HIGH)
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
		{"type": "items", "s0": m.items2 - 30.0, "s1": m.items2 - 28.0},
		{"type": "climb", "s0": m.climb0, "s1": m.climb1, "dir": "forward"},
		# Driven the other way round, the banked run is the climb.
		{"type": "climb", "s0": m.downhill, "s1": m.lake, "dir": "reversed"},
		{"type": "boost", "s0": m.boost + 2.0, "s1": m.boost + 8.0, "d": -2.6, "w": 1.4},
		{"type": "boost", "s0": m.boost + 2.0, "s1": m.boost + 8.0, "d": 2.6, "w": 1.4},
	]
	return def
