extends RefCounted
## Canyon Dash (#43): red layered rock, mesas and a dry riverbed. About 1.3 km, clockwise: the
## start straight runs along the riverbed under a rock arch; turn 1 (38 m, 90°: a tier-2 drift)
## climbs out of it; a fast left-right esses through the narrows (a second arch); the long climb
## up the canyon wall to the summit hairpin (24 m, 180°: the tier-3 drift) by a lone rock spire;
## a run along the mesa, a sweeping right-hander that drops back down, and the last corner (36
## m, 90°: tier 2) onto the start straight. An original layout, laid out as a route card
## (KartTrackShape).

const WIDE := 7.5
const ROAD := 6.5
const TOP := 18.0  ## the mesa road's height, metres


## The route; `a` and `b` are the two straights KartTrackShape.solve() sizes to close the loop.
static func shape(a: float, b: float) -> KartTrackShape:
	var t := KartTrackShape.new(Vector2.ZERO, 0.0, 0.0, WIDE)
	t.straight(125.0)
	# Turn 1 out of the riverbed: tight enough to drift (tier 2), the run to the narrows after.
	t.arc(38.0, -90.0, 0.0, ROAD)
	t.mark("items1")
	t.straight(60.0)
	t.mark("climb0")
	# The esses through the narrows, already climbing.
	t.arc(70.0, 40.0, 3.0)
	t.arc(70.0, -40.0, 6.0)
	# The long climb up the canyon wall.
	t.straight(a, TOP - 4.0)
	t.mark("hairpin")
	# The summit hairpin: a long drift (tier 3) onto the mesa straight.
	t.arc(24.0, -180.0, TOP, WIDE)
	t.mark("climb1")
	# Along the mesa, then the drop back to the riverbed.
	t.straight(100.0, TOP - 1.0, ROAD)
	t.mark("items2")
	t.arc(60.0, 90.0, TOP - 3.0)
	t.straight(b, 3.0)
	t.mark("boost")
	t.arc(60.0, -90.0, 0.0)
	t.straight(75.0)
	# The last corner, under the arch's shadow: a tier-2 drift onto the start straight.
	t.arc(36.0, -90.0)
	t.straight(115.0, 0.0, WIDE)
	return t


static func build() -> KartTrackDef:
	var ab := KartTrackShape.solve(shape)
	var t := shape(ab.x, ab.y)
	var def := t.def("canyon_dash", "Canyon Dash", "canyon")
	def.verge = 4.0
	def.start_s = 0.0
	var m := t.marks
	var lap := t.length()
	def.zones = [
		{"type": "start", "s0": lap - 50.0, "s1": 50.0},
		{"type": "items", "s0": m.items1 + 30.0, "s1": m.items1 + 32.0},
		{"type": "climb", "s0": m.climb0, "s1": m.climb1, "dir": "forward"},
		{"type": "climb", "s0": m.items2, "s1": m.boost, "dir": "reversed"},
		{"type": "items", "s0": m.items2 - 45.0, "s1": m.items2 - 43.0},
		{"type": "boost", "s0": m.boost + 4.0, "s1": m.boost + 10.0, "d": -2.6, "w": 1.4},
		{"type": "boost", "s0": m.boost + 4.0, "s1": m.boost + 10.0, "d": 2.6, "w": 1.4},
	]
	# The dry riverbed winds through the infield; rock arches span the start straight (the
	# title shot frames it over the grid) and the esses (a gateway into the climb); a lone rock
	# spire stands on the summit hairpin's outside, the view as the karts come round.
	def.landmarks = [
		{"type": "river", "s": 40.0, "d": 70.0},
		{"type": "arch", "s": 75.0, "d": 0.0, "hero": true},
		{"type": "arch", "s": m.climb0 + 60.0, "d": 0.0},
		{"type": "spire", "s": m.hairpin + 38.0, "d": -30.0},
	]
	return def
