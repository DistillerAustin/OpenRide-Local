class_name KartTrackShape
extends RefCounted
## A turtle for laying out Kart Race tracks (#43): straights and constant-radius arcs, each
## taking the height (linearly), the road's half-width and the banking (eased) to new values
## over its length. Keep climbs under about 6%: the bike model stalls weak riders on steeper
## ones.
## `def()` samples the path every SAMPLE metres into a `KartTrackDef`'s control points, so a
## track script reads like a route card ("300 m straight, a 25 m hairpin right, climb 18 m")
## and its corners have the radii it says.
##
## The path should close by itself (turns summing to ±360°, the legs balancing out). A small
## leftover gap is spread along the whole lap, proportionally to distance, so it never shows;
## `closure_error` reports it before the correction (tests keep it under a few metres).
##
## Turns: + degrees = a left-hander for the driver (the track model's + curvature). Banking:
## + = the right edge higher (the outside of a left-hander).

const SAMPLE := 4.0  ## metres between control points along the path (denser keeps the spline on the arcs)

var closure_error := 0.0
var marks := {}  ## name -> metres from the start of the path

var _pos := Vector2.ZERO  ## x, z
var _angle := 0.0  ## heading: direction (cos, sin) in the (x, z) plane
var _y := 0.0
var _hw := 6.5
var _bank := 0.0
var _dist := 0.0
var _pts := PackedVector3Array()
var _hws := PackedFloat32Array()
var _banks := PackedFloat32Array()
var _cum := PackedFloat32Array()


## Starts at `pos` heading along `heading_deg` (0 = +x, 90 = +z), `y` high, `half_width` wide.
func _init(pos := Vector2.ZERO, heading_deg := 0.0, y := 0.0, half_width := 6.5) -> void:
	_pos = pos
	_angle = deg_to_rad(heading_deg)
	_y = y
	_hw = half_width
	_emit()


## A straight `length` metres long, easing to height `y`, half-width `hw`, banking `bank` (NAN
## keeps the current value).
func straight(length: float, y := NAN, hw := NAN, bank := NAN) -> KartTrackShape:
	return _leg(length, 0.0, y, hw, bank)


## An arc of `radius` metres turning `degrees` (+ = left), easing like `straight`.
func arc(radius: float, degrees: float, y := NAN, hw := NAN, bank := NAN) -> KartTrackShape:
	return _leg(radius * deg_to_rad(absf(degrees)), deg_to_rad(degrees) / maxf(radius * deg_to_rad(absf(degrees)), 0.001), y, hw, bank)


## Names the current distance (zones use it).
func mark(name: String) -> KartTrackShape:
	marks[name] = _dist
	return self


func length() -> float:
	return _dist


## Where the path ends relative to where it started, (x, z) metres, before any correction.
func gap() -> Vector2:
	return _pos - Vector2(_pts[0].x, _pts[0].z)


## The heading's mismatch at the end, degrees (0 when the turns sum to a whole lap).
func heading_error() -> float:
	return rad_to_deg(angle_difference(_angle, atan2(_pts[1].z - _pts[0].z, _pts[1].x - _pts[0].x)))


## The two straight lengths (a, b) that close a path exactly: `build(a, b)` returns the shape
## with two non-parallel straights of those lengths. The end point is linear in them, so three
## trial builds solve it.
static func solve(build: Callable) -> Vector2:
	var g0: Vector2 = build.call(0.0, 0.0).gap()
	var ga: Vector2 = build.call(1.0, 0.0).gap() - g0
	var gb: Vector2 = build.call(0.0, 1.0).gap() - g0
	var det := ga.x * gb.y - ga.y * gb.x
	if absf(det) < 1e-6:
		return Vector2.ZERO
	return Vector2((-g0.x * gb.y + g0.y * gb.x) / det, (-ga.x * g0.y + ga.y * g0.x) / det)


## The control points, closed (the last sample, back at the start, is dropped) and corrected.
func def(id: String, title: String, theme: String) -> KartTrackDef:
	var pts := _pts.duplicate()
	var hws := _hws.duplicate()
	var banks := _banks.duplicate()
	var cum := _cum.duplicate()
	var gap := pts[0] - pts[pts.size() - 1]
	gap.y = 0.0
	closure_error = gap.length()
	var total := cum[cum.size() - 1]
	for i in pts.size():
		pts[i] += gap * (cum[i] / total)
	# The last point now sits on the first: drop it.
	pts.resize(pts.size() - 1)
	hws.resize(hws.size() - 1)
	banks.resize(banks.size() - 1)
	var d := KartTrackDef.new()
	d.id = id
	d.title = title
	d.theme = theme
	d.points = pts
	d.half_widths = hws
	d.banking = banks
	return d


# --- Internals ---

func _leg(length: float, curvature: float, y: float, hw: float, bank: float) -> KartTrackShape:
	var y0 := _y
	var hw0 := _hw
	var bank0 := _bank
	var y1 := y0 if is_nan(y) else y
	var hw1 := hw0 if is_nan(hw) else hw
	var bank1 := bank0 if is_nan(bank) else bank
	var steps := maxi(1, ceili(length / SAMPLE))
	var ds := length / steps
	for k in steps:
		# Advance exactly along the arc (or the straight).
		if absf(curvature) < 1e-6:
			_pos += Vector2(cos(_angle), sin(_angle)) * ds
		else:
			# + curvature turns left, which is toward decreasing angle in (x, z) seen from above.
			var r := 1.0 / curvature
			var turn := ds * curvature
			var left := Vector2(sin(_angle), -cos(_angle))
			var centre := _pos + left * r
			var from := _pos - centre
			_pos = centre + from.rotated(-turn)
			_angle -= turn
		_dist += ds
		var f := float(k + 1) / steps
		var e := f * f * (3.0 - 2.0 * f)
		# Heights change linearly, so chained legs make an even climb (the spline smooths the
		# joins); widths and banking ease in and out.
		_y = lerpf(y0, y1, f)
		_hw = lerpf(hw0, hw1, e)
		_bank = lerpf(bank0, bank1, e)
		_emit()
	return self


func _emit() -> void:
	_pts.append(Vector3(_pos.x, _y, _pos.y))
	_hws.append(_hw)
	_banks.append(_bank)
	_cum.append(_dist)
