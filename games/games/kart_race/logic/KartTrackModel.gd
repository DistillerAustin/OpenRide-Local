class_name KartTrackModel
extends RefCounted
## Track space for Kart Race (#43, games/kart_race/DESIGN.md "Track space"). A `KartTrackDef`'s
## closed centre line becomes a `Curve3D`, baked to a lookup table every ~1 m. Everything in the
## race asks it where things are as (s, d):
##
##   s  metres along the centre line from the start/finish line, in the driving direction,
##      0..length (it wraps)
##   d  metres across the road from the centre line, horizontal, + = the driver's right
##
## The road surface at (s, d) is the centre line's point plus d along the horizontal right, raised
## by the banking (+ banking = the right edge higher). Reversed mode drives the same loop the other
## way round: the start line stays where it is, s runs backwards, d and curvature flip sign.
##
## Plain data and maths, no nodes: it is tested headless and shared by the physics, the bots, the
## race logic and the world builders.

enum Surface { ROAD, KERB, OFFROAD, WALL }

## The lookup table's spacing, metres (the actual spacing divides the length evenly).
const STEP := 1.0
## Kerbs: a band just outside the road's edge. Driving on them is as fast as the road.
const KERB_WIDTH := 0.8
## `project` with a hint searches this far either side of it, metres.
const PROJECT_WINDOW := 25.0
## The racing line keeps at least this far inside the road's edge, metres.
const RACING_MARGIN := 1.5
## Corners this tight or tighter (1 / radius) put the racing line right on the inside.
const RACING_FULL_CURVATURE := 1.0 / 40.0
## The racing line is smoothed over this many metres either side.
const RACING_SMOOTH := 20.0
const RACING_SMOOTH_PASSES := 3

var length: float
var def: KartTrackDef
var reversed := false
var verge: float
## The def's zones in this model's s (re-based on the start line, mirrored when reversed).
var zones: Array[Dictionary] = []
## The centre line as a closed Curve3D in the driving direction (its first point is the def's
## points[0], so its offsets are not this model's s: use `sample`/`position_at` for that).
var curve: Curve3D

var _n := 0
var _ds := 1.0
var _origin := 0.0  ## the curve offset of s = 0 (the start line)
var _pos := PackedVector3Array()  ## centre line, every _ds from the start line
var _tan := PackedVector3Array()  ## horizontal unit tangents
var _hw := PackedFloat32Array()
var _bank := PackedFloat32Array()
var _curv := PackedFloat32Array()
var _grade := PackedFloat32Array()
var _line := PackedFloat32Array()
var _at := 0  ## scratch: the row `_locate` found
var _frac := 0.0  ## scratch: the fraction to the next row


func _init(track_def: KartTrackDef, is_reversed := false) -> void:
	def = track_def
	reversed = is_reversed
	verge = def.verge
	var pts := PackedVector3Array()
	var widths := PackedFloat32Array()
	var bank := PackedFloat32Array()
	var n := def.points.size()
	for k in n:
		# Reversed: p0, p(n-1), ..., p1, so the curve still starts at points[0].
		var i := (n - k) % n if reversed else k
		pts.append(def.points[i])
		widths.append(def.half_widths[i] if i < def.half_widths.size() else 6.0)
		var b := def.banking[i] if i < def.banking.size() else 0.0
		bank.append(-b if reversed else b)
	_bake(pts, widths, bank)
	_build_zones()


# --- Queries ---

## The centre line at s (d = 0).
func sample(s: float) -> KartTrackPoint:
	return _point(_wrap(s), 0.0)


## The road surface's point at (s, d).
func position_at(s: float, d: float) -> Vector3:
	_locate(s)
	var i := _at
	var f := _frac
	var j := (i + 1) % _n
	var c := _pos[i].lerp(_pos[j], f)
	var t := _tan[i].lerp(_tan[j], f).normalized()
	var right := Vector3(-t.z, 0.0, t.x)
	var b := lerpf(_bank[i], _bank[j], f)
	return c + right * d + Vector3.UP * (d * tan(b))


## The nearest place on the track to `pos`. With `hint_s` (≥ 0, e.g. the kart's s last tick) it
## searches only near it, so it never jumps to another part of the track that passes close by.
func project(pos: Vector3, hint_s := -1.0) -> KartTrackPoint:
	var best := 0
	var best_d2 := INF
	if hint_s >= 0.0:
		var h := roundi(_wrap(hint_s) / _ds)
		var w := ceili(PROJECT_WINDOW / _ds)
		for k in range(h - w, h + w + 1):
			var i := posmod(k, _n)
			var d2 := pos.distance_squared_to(_pos[i])
			if d2 < best_d2:
				best_d2 = d2
				best = i
	else:
		for i in _n:
			var d2 := pos.distance_squared_to(_pos[i])
			if d2 < best_d2:
				best_d2 = d2
				best = i
	# Newton's method on the foot of the perpendicular: (pos - c(s)) · t(s) = 0.
	var s := best * _ds
	for _iteration in 6:
		_locate(s)
		var i := _at
		var f := _frac
		var j := (i + 1) % _n
		var c := _pos[i].lerp(_pos[j], f)
		var t := _tan[i].lerp(_tan[j], f).normalized()
		var off := pos - c
		off.y = 0.0
		var along := off.dot(t)
		var across := off.dot(Vector3(-t.z, 0.0, t.x))
		var k := lerpf(_curv[i], _curv[j], f)
		var step := along / maxf(0.2, 1.0 + k * across)
		s = _wrap(s + clampf(step, -3.0 * _ds, 3.0 * _ds))
		if absf(step) < 0.0005:
			break
	_locate(s)
	var i0 := _at
	var f0 := _frac
	var j0 := (i0 + 1) % _n
	var centre := _pos[i0].lerp(_pos[j0], f0)
	var tan0 := _tan[i0].lerp(_tan[j0], f0).normalized()
	var offset := pos - centre
	offset.y = 0.0
	return _point(s, offset.dot(Vector3(-tan0.z, 0.0, tan0.x)))


## The road's half-width at s (the edge of the tarmac; kerbs and the verge lie beyond it).
func half_width(s: float) -> float:
	return _lerp_table(_hw, s)


## What is under (s, d): ROAD, KERB (the first KERB_WIDTH past the edge), OFFROAD (the rest of
## the verge) or WALL (beyond the verge: the barrier).
func surface(s: float, d: float) -> int:
	var a := absf(d)
	var edge := half_width(s)
	if a <= edge:
		return Surface.ROAD
	if a <= edge + KERB_WIDTH:
		return Surface.KERB
	if a <= edge + verge:
		return Surface.OFFROAD
	return Surface.WALL


## Signed curvature of the centre line, 1/m: + turns left, - right.
func curvature(s: float) -> float:
	return _lerp_table(_curv, s)


## The centre line's slope, dy/ds: + uphill in the driving direction.
func grade(s: float) -> float:
	return _lerp_table(_grade, s)


## The racing line's d at s: the inside of corners, smoothed, always at least RACING_MARGIN
## inside the road's edge.
func racing_line(s: float) -> float:
	return _lerp_table(_line, s)


## The driving direction at s as a yaw (Node3D.rotation.y: 0 faces -Z, + turns left).
func yaw_at(s: float) -> float:
	_locate(s)
	var t := _tan[_at].lerp(_tan[(_at + 1) % _n], _frac)
	return atan2(-t.x, -t.z)


## The road's banking at s, radians (+ = the right edge higher).
func banking(s: float) -> float:
	return _lerp_table(_bank, s)


## The zones covering s (re-based zones, see `zones`).
func zones_at(s: float) -> Array[Dictionary]:
	var x := _wrap(s)
	var found: Array[Dictionary] = []
	for z in zones:
		if in_span(x, float(z.s0), float(z.s1)):
			found.append(z)
	return found


## Whether s lies in the span s0 → s1 (driving forward, wrapping past the line when s1 < s0).
static func in_span(s: float, s0: float, s1: float) -> bool:
	if s0 <= s1:
		return s >= s0 and s <= s1
	return s >= s0 or s <= s1


func wrap(s: float) -> float:
	return _wrap(s)


## (The global `wrap()` shadows the method inside this class, hence the private name.)
func _wrap(s: float) -> float:
	return fposmod(s, length)


## The signed shortest distance along the loop from `from_s` to `to_s` (+ = ahead).
func delta(from_s: float, to_s: float) -> float:
	var d := fposmod(to_s - from_s, length)
	return d - length if d > length * 0.5 else d


# --- Baking ---

func _bake(pts: PackedVector3Array, widths: PackedFloat32Array, bank: PackedFloat32Array) -> void:
	var n := pts.size()
	curve = Curve3D.new()
	# Smooth handles: along the neighbours' chord, a third of each adjoining segment long, so the
	# spline passes through every point without overshooting on uneven spacing.
	var handles_in: Array[Vector3] = []
	var handles_out: Array[Vector3] = []
	for i in n:
		var prev := pts[(i - 1 + n) % n]
		var next := pts[(i + 1) % n]
		var dir := (next - prev).normalized()
		handles_in.append(-dir * pts[i].distance_to(prev) / 3.0)
		handles_out.append(dir * pts[i].distance_to(next) / 3.0)
	for i in n + 1:
		var k := i % n
		curve.add_point(pts[k], handles_in[k], handles_out[k])

	# Dense samples along each segment, for arc length.
	var dense := PackedVector3Array()
	var cum := PackedFloat64Array()
	var point_s := PackedFloat64Array()  # curve offset of each control point
	var total := 0.0
	for i in n:
		point_s.append(total)
		var steps := clampi(ceili(pts[i].distance_to(pts[(i + 1) % n]) / 0.25), 8, 2000)
		for k in steps:
			var p := curve.sample(i, float(k) / steps)
			if not dense.is_empty():
				total += p.distance_to(dense[dense.size() - 1])
			dense.append(p)
			cum.append(total)
	total += dense[0].distance_to(dense[dense.size() - 1])
	dense.append(dense[0])
	cum.append(total)
	length = total

	# s = 0 is the start line: forward, start_s along the curve; reversed, the same place.
	_origin = fposmod(def.start_s if not reversed else total - def.start_s, total)
	_n = maxi(16, roundi(total / STEP))
	_ds = total / _n
	_pos.resize(_n)
	_hw.resize(_n)
	_bank.resize(_n)
	var seg := 0
	for j in _n:
		var cs := fposmod(_origin + j * _ds, total)
		# Binary search the dense table for cs.
		var lo := 0
		var hi := cum.size() - 1
		while hi - lo > 1:
			var mid := (lo + hi) >> 1
			if cum[mid] <= cs:
				lo = mid
			else:
				hi = mid
		var span := cum[hi] - cum[lo]
		var f := (cs - cum[lo]) / span if span > 0.0 else 0.0
		_pos[j] = dense[lo].lerp(dense[hi], f)
		# Per-point values, interpolated between control points by curve offset.
		seg = 0
		while seg < n - 1 and point_s[seg + 1] <= cs:
			seg += 1
		var s_a := point_s[seg]
		var s_b := point_s[seg + 1] if seg < n - 1 else total
		var g := (cs - s_a) / (s_b - s_a) if s_b > s_a else 0.0
		var nxt := (seg + 1) % n
		_hw[j] = lerpf(widths[seg], widths[nxt], g)
		_bank[j] = lerpf(bank[seg], bank[nxt], g)

	_tan.resize(_n)
	_grade.resize(_n)
	for j in _n:
		var a := _pos[(j - 1 + _n) % _n]
		var b := _pos[(j + 1) % _n]
		var flat := Vector3(b.x - a.x, 0.0, b.z - a.z)
		_tan[j] = flat.normalized()
		_grade[j] = (b.y - a.y) / maxf(flat.length(), 0.001)

	var raw := PackedFloat32Array()
	raw.resize(_n)
	for j in _n:
		var t0 := _tan[(j - 1 + _n) % _n]
		var t1 := _tan[(j + 1) % _n]
		# + = turning left: the tangent swings away from the right (right = (-t.z, 0, t.x)).
		var turn := atan2(t0.x * t1.z - t0.z * t1.x, t0.dot(t1))
		raw[j] = -turn / (2.0 * _ds)
	_curv = _smooth(raw, 1, 1)

	_line.resize(_n)
	for j in _n:
		var k := _curv[j]
		var inside := -signf(k) * clampf(absf(k) / RACING_FULL_CURVATURE, 0.0, 1.0)
		_line[j] = inside * maxf(0.0, _hw[j] - RACING_MARGIN)
	_line = _smooth(_line, roundi(RACING_SMOOTH / _ds), RACING_SMOOTH_PASSES)
	for j in _n:
		var limit := maxf(0.0, _hw[j] - RACING_MARGIN)
		_line[j] = clampf(_line[j], -limit, limit)


## A circular moving average, `half` samples either side, `passes` times.
func _smooth(values: PackedFloat32Array, half: int, passes: int) -> PackedFloat32Array:
	var out := values
	for p in passes:
		var next := PackedFloat32Array()
		next.resize(_n)
		var sum := 0.0
		for k in range(-half, half + 1):
			sum += out[posmod(k, _n)]
		for j in _n:
			next[j] = sum / (2 * half + 1)
			sum += out[posmod(j + half + 1, _n)] - out[posmod(j - half, _n)]
		out = next
	return out


func _build_zones() -> void:
	zones = []
	for z in def.zones:
		# A zone may hold for one direction only ("dir": "forward" | "reversed"): a climb driven
		# the other way is a descent.
		if z.has("dir") and str(z.dir) != ("reversed" if reversed else "forward"):
			continue
		var copy := z.duplicate()
		var s0 := float(z.get("s0", 0.0))
		var s1 := float(z.get("s1", s0))
		if reversed:
			copy.s0 = fposmod(def.start_s - s1, length)
			copy.s1 = fposmod(def.start_s - s0, length)
			if copy.has("d"):
				copy.d = -float(copy.d)
		else:
			copy.s0 = fposmod(s0 - def.start_s, length)
			copy.s1 = fposmod(s1 - def.start_s, length)
		zones.append(copy)


# --- Table lookups ---

## Locates s in the table: sets _at (the row) and _frac (0..1 to the next row). Scratch fields
## rather than a returned pair, so queries in the fixed step allocate nothing.
func _locate(s: float) -> void:
	var u := _wrap(s) / _ds
	_at = mini(floori(u), _n - 1)
	_frac = u - _at


func _lerp_table(table: PackedFloat32Array, s: float) -> float:
	_locate(s)
	return lerpf(table[_at], table[(_at + 1) % _n], _frac)


func _point(s: float, d: float) -> KartTrackPoint:
	_locate(s)
	var i := _at
	var f := _frac
	var j := (i + 1) % _n
	var p := KartTrackPoint.new()
	p.s = s
	p.d = d
	var t := _tan[i].lerp(_tan[j], f).normalized()
	p.right = Vector3(-t.z, 0.0, t.x)
	var b := lerpf(_bank[i], _bank[j], f)
	var g := lerpf(_grade[i], _grade[j], f)
	p.position = _pos[i].lerp(_pos[j], f) + p.right * d + Vector3.UP * (d * tan(b))
	p.height = p.position.y
	p.tangent = (t + Vector3.UP * g).normalized()
	var right_banked := p.right * cos(b) + Vector3.UP * sin(b)
	p.normal = right_banked.cross(p.tangent).normalized()
	return p
