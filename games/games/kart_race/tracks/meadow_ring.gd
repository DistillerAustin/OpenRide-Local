extends RefCounted
## Meadow Ring (#43): the hero track. Green hills, wide sweepers and three corners that pay a
## long drift, about 1.15 km, anticlockwise. An original layout, laid out as a route card
## (KartTrackShape):
##
## - the start straight past the grandstand into **the Carousel**, a long banked left-hander
##   (34 m, 150°: a tier-3 drift) that opens onto the item row;
## - a kink, then the climb along the back to **the crest hairpin** by the windmill (25 m, 115°:
##   tier 2), the view opening over the valley as the karts come round;
## - the winding descent (wide esses), the run past the hay fields to **the barn bend** (30 m,
##   95°: tier 2), the boost pads on its exit, and a last sweeper onto the line.

const WIDE := 7.5
const ROAD := 6.5
const HAIRPIN := 7.0  ## the crest hairpin is a little wider: room to drift round it
const CREST := 9.5  ## metres above the start
const BANK := 0.1  ## the Carousel leans in (the outside, the right edge, higher)


## The route; `a` and `b` are the two straights KartTrackShape.solve() sizes to close the loop.
static func shape(a: float, b: float) -> KartTrackShape:
	var t := KartTrackShape.new(Vector2(58.0, 88.0), -22.0, 0.0, WIDE)
	t.straight(65.0)
	t.straight(90.0, NAN, ROAD)
	t.mark("carousel")
	t.arc(34.0, 150.0, NAN, NAN, BANK)
	t.straight(18.0, NAN, NAN, 0.0)
	t.mark("items1")
	t.straight(70.0)
	# A pair of wide sweepers through the hay fields, flat out.
	t.arc(90.0, -50.0)
	t.arc(90.0, 50.0)
	t.mark("climb0")
	# The climb along the back, about 4.5%.
	t.straight(a, CREST - 0.5)
	t.mark("crest")
	t.arc(25.0, 115.0, CREST, HAIRPIN)
	t.mark("climb1")
	t.straight(90.0, CREST - 3.0, ROAD)
	# The winding descent.
	t.arc(65.0, -50.0, CREST - 5.5)
	t.arc(65.0, 50.0, CREST - 7.5)
	t.mark("items2")
	t.straight(b, 0.6)
	t.mark("barn")
	t.arc(30.0, 95.0, 0.0)
	t.mark("boost")
	t.straight(50.0)
	t.straight(70.0, 0.0, WIDE)
	t.straight(55.0)
	return t


static func build() -> KartTrackDef:
	var ab := KartTrackShape.solve(shape)
	var t := shape(ab.x, ab.y)
	var def := t.def("meadow_ring", "Meadow Ring", "meadow")
	def.verge = 4.0
	def.start_s = 0.0
	var m := t.marks
	var lap := t.length()
	def.zones = [
		{"type": "start", "s0": lap - 50.0, "s1": 50.0},
		{"type": "items", "s0": m.items1 + 25.0, "s1": m.items1 + 27.0},
		{"type": "climb", "s0": m.climb0, "s1": m.crest, "dir": "forward"},
		# Driven the other way round, the winding descent is the climb.
		{"type": "climb", "s0": m.climb1, "s1": m.items2 + 40.0, "dir": "reversed"},
		{"type": "items", "s0": m.items2 + 30.0, "s1": m.items2 + 32.0},
		{"type": "boost", "s0": m.boost + 30.0, "s1": m.boost + 36.0, "d": -2.8, "w": 1.4},
		{"type": "boost", "s0": m.boost + 30.0, "s1": m.boost + 36.0, "d": 2.8, "w": 1.4},
	]
	# The windmill turns on a rise in the infield by the start (the title shot frames it over
	# the grid); the barn stands on the barn bend's outside, facing the karts as they exit.
	def.landmarks = [
		{"type": "windmill", "s": 85.0, "d": -36.0},
		{"type": "barn", "s": m.barn + 50.0, "d": 30.0},
	]
	return def
