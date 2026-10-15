extends RefCounted
## Harbor Lights (#43): a seaside town at sunset. About 1.15 km, clockwise: the start straight
## runs along the quay with the sea on the left, a right-hander turns into town, a tight
## left-right-left chicane between the warehouses, a short rise past the old town, a kink, and
## a long sweeping right-hander back down to the waterfront. An original layout
## (KartTrackShape).

const WIDE := 7.5
const ROAD := 6.0


static func shape(a: float, b: float) -> KartTrackShape:
	# Heading 212°: along the shore, into the low sun (KartLook's sun is west-south-west).
	var t := KartTrackShape.new(Vector2.ZERO, 212.0, 0.0, WIDE)
	t.straight(130.0)
	t.mark("items1")
	t.arc(40.0, -90.0, 0.0, ROAD)
	t.straight(20.0)
	t.mark("chicane")
	t.arc(21.0, 65.0, NAN, 6.5)
	t.arc(21.0, -130.0)
	t.arc(21.0, 65.0)
	t.straight(a, NAN, ROAD)
	t.arc(35.0, -90.0)
	t.mark("climb0")
	t.straight(b, 4.5)
	t.arc(90.0, 25.0, 6.0)
	t.arc(90.0, -25.0, 6.5)
	t.mark("climb1")
	t.arc(45.0, -60.0, 6.0)
	t.mark("items2")
	t.arc(30.0, 40.0, 4.5)
	t.straight(40.0, 2.5)
	t.mark("boost")
	t.arc(55.0, -70.0, 0.0)
	t.straight(60.0)
	t.arc(65.0, -90.0)
	t.straight(110.0, 0.0, WIDE)
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
	def.landmarks = [{"type": "shore", "s": 20.0, "d": -(WIDE + def.verge + 7.0)}]
	return def
