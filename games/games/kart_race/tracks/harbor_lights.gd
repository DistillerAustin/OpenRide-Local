extends RefCounted
## Harbor Lights (#43): a seaside town at sunset. About 1.0 km, clockwise: the start straight
## runs along the quay with the sea on the left; the harbour master's corner (34 m, 90°: a
## tier-2 drift) turns into town; a tight left-right-left chicane between the warehouses; the
## old-town turn (30 m, 125°: tier 2) onto the rise; a kink, the boost run down toward the
## point, and the lighthouse hairpin (30 m, 145°: the tier-3 drift) round the point and back onto
## the quay. An original layout (KartTrackShape).

const WIDE := 7.5
const ROAD := 6.0


static func shape(a: float, b: float) -> KartTrackShape:
	# Heading 212°: along the shore, into the low sun (KartLook's sun is west-south-west).
	var t := KartTrackShape.new(Vector2.ZERO, 212.0, 0.0, WIDE)
	t.straight(160.0)
	t.mark("items1")
	# The harbour master's corner, off the quay into town: a tier-2 drift.
	t.arc(34.0, -90.0, 0.0, ROAD)
	t.straight(30.0)
	t.mark("chicane")
	t.arc(21.0, 65.0, NAN, 6.5)
	t.arc(21.0, -130.0)
	t.arc(21.0, 65.0)
	t.straight(a, NAN, ROAD)
	# The old-town turn at the end of the warehouses (tier 2), onto the rise.
	t.mark("oldtown")
	t.arc(30.0, -125.0, NAN, 6.5)
	t.mark("climb0")
	t.straight(b, 5.0, ROAD)
	t.arc(90.0, 25.0, 6.0)
	t.arc(90.0, -25.0, 6.0)
	t.mark("climb1")
	t.straight(60.0, 5.0)
	t.mark("items2")
	t.straight(90.0, 2.5)
	t.mark("boost")
	t.straight(60.0, 0.5)
	# The lighthouse hairpin, round the point and back onto the quay: the long drift (tier 3).
	t.mark("point")
	t.arc(30.0, -145.0, 0.0, 6.5)
	t.straight(120.0, 0.0, WIDE)
	return t


static func build() -> KartTrackDef:
	var ab := KartTrackShape.solve(shape)
	var t := shape(ab.x, ab.y)
	var def := t.def("harbor_lights", "Harbor Lights", "harbor")
	def.verge = 3.5
	def.start_s = 0.0
	var m := t.marks
	var lap := t.length()
	def.zones = [
		{"type": "start", "s0": lap - 50.0, "s1": 50.0},
		{"type": "items", "s0": m.items1 - 40.0, "s1": m.items1 - 38.0},
		{"type": "climb", "s0": m.climb0 + 10.0, "s1": m.climb1, "dir": "forward"},
		{"type": "climb", "s0": m.climb1 + 20.0, "s1": m.boost + 60.0, "dir": "reversed"},
		{"type": "items", "s0": m.climb1 - 40.0, "s1": m.climb1 - 38.0},
		{"type": "boost", "s0": m.boost + 8.0, "s1": m.boost + 14.0, "d": -2.4, "w": 1.4},
		{"type": "boost", "s0": m.boost + 8.0, "s1": m.boost + 14.0, "d": 2.4, "w": 1.4},
	]
	# The quay runs along the start straight, the sea on the left (driving forward).
	# The lighthouse stands on the point, off the lighthouse hairpin's apex: the karts swing round
	# it, and the title shot frames it, the festoons and the quay over the grid.
	def.landmarks = [
		{"type": "shore", "s": 20.0, "d": -(WIDE + def.verge + 7.0)},
		{"type": "lighthouse", "s": m.point + 38.0, "d": -24.0},
		# The old town's clock tower, on the old-town turn's outside: the karts drift round it.
		{"type": "clocktower", "s": m.oldtown + 34.0, "d": -24.0},
	]
	return def
