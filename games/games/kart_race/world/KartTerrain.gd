class_name KartTerrain
extends RefCounted
## The ground under and around a Kart Race track (#43): one heightfield that runs from under
## the road out to the far hills, so every theme's land (meadow hills, canyon walls, the
## harbour's seabed, the frozen lake's basin) is a single mesh and a single draw call.
##
## The grid is 8 m square over the track and its surroundings, its spacing growing outside that
## to the horizon. The road shapes the land near it: every road sample stamps its height onto
## the vertices around it, so the ground meets an embankment or a cutting at the road's level
## (just under it), and blends into the theme's own height (`base`) further out. KartWorld's
## short skirt from the barrier's foot hides the seam.

const STEP := 8.0  ## metres between grid lines over the track
const STAMP := 90.0  ## the road shapes the land this far beyond its wall
const SHOULDER := 6.0  ## flat at the road's level this far beyond the wall
const BLEND := 45.0  ## then blends to the theme's height over this far
const UNDER := 0.6  ## the shoulder sits this far below the road's lowest edge
const OUTER := 950.0  ## the grid reaches this far from the centre
const FAR := 1.0e6  ## r_road for vertices the road doesn't reach

var centre := Vector3.ZERO
var xs := PackedFloat32Array()  ## grid line x (absolute)
var zs := PackedFloat32Array()  ## grid line z (absolute)
var heights := PackedFloat32Array()  ## xs.size() × zs.size(), row-major by z
var r_road := PackedFloat32Array()  ## metres beyond the nearest wall (FAR when far)
var road_y := PackedFloat32Array()  ## the nearest road sample's shoulder height

var _nx := 0
var _nz := 0


## Builds the grid for `track` around `track_centre`. `base` is the theme's land:
## base(x: float, z: float, r_road: float) -> float, r_road being metres beyond the nearest
## wall (FAR beyond STAMP).
func _init(track: KartTrackModel, track_centre: Vector3, base: Callable) -> void:
	centre = track_centre
	var reach := 0.0
	var s := 0.0
	while s < track.length:
		var p := track.sample(s).position
		reach = maxf(reach, maxf(absf(p.x - centre.x), absf(p.z - centre.z)))
		s += 10.0
	var inner := ceilf((reach + STAMP + 30.0) / STEP) * STEP
	xs = _axis(centre.x, inner)
	zs = _axis(centre.z, inner)
	_nx = xs.size()
	_nz = zs.size()
	var n := _nx * _nz
	heights.resize(n)
	r_road.resize(n)
	road_y.resize(n)
	r_road.fill(FAR)
	road_y.fill(0.0)
	_stamp(track)
	for j in _nz:
		for i in _nx:
			var k := j * _nx + i
			var r := r_road[k]
			var land: float = base.call(xs[i], zs[j], r)
			if r < SHOULDER:
				heights[k] = road_y[k]
			elif r < SHOULDER + BLEND:
				var w := smoothstep(SHOULDER + BLEND, SHOULDER, r)
				heights[k] = lerpf(land, road_y[k] + 0.1, w)
			else:
				heights[k] = land


## The ground's height at (x, z), interpolated like the mesh's triangles (near enough).
func height_at(x: float, z: float) -> float:
	var i := clampi(xs.bsearch(x) - 1, 0, _nx - 2)
	var j := clampi(zs.bsearch(z) - 1, 0, _nz - 2)
	var fx := clampf((x - xs[i]) / (xs[i + 1] - xs[i]), 0.0, 1.0)
	var fz := clampf((z - zs[j]) / (zs[j + 1] - zs[j]), 0.0, 1.0)
	var k := j * _nx + i
	var a := lerpf(heights[k], heights[k + 1], fx)
	var b := lerpf(heights[k + _nx], heights[k + _nx + 1], fx)
	return lerpf(a, b, fz)


## Roughly how far (x, z) is beyond the nearest wall, metres (to within a grid cell): FAR when
## the road is far away.
func road_clearance(x: float, z: float) -> float:
	var i := clampi(xs.bsearch(x) - 1, 0, _nx - 2)
	var j := clampi(zs.bsearch(z) - 1, 0, _nz - 2)
	var k := j * _nx + i
	return minf(minf(r_road[k], r_road[k + 1]), minf(r_road[k + _nx], r_road[k + _nx + 1]))


## The mesh: an indexed grid with smooth normals; vertex colours tint the far hills bluer
## (from `tint_r0` to `tint_r1` metres from the centre), times `tint(x, z, height) -> Color`
## when given (a theme's riverbed, beaches).
func mesh(tint_r0: float, tint_r1: float, far_tint := Color(0.86, 0.92, 1.0), tint := Callable()) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	verts.resize(_nx * _nz)
	normals.resize(_nx * _nz)
	colors.resize(_nx * _nz)
	for j in _nz:
		for i in _nx:
			var k := j * _nx + i
			verts[k] = Vector3(xs[i], heights[k], zs[j])
			var i0 := maxi(i - 1, 0)
			var i1 := mini(i + 1, _nx - 1)
			var j0 := maxi(j - 1, 0)
			var j1 := mini(j + 1, _nz - 1)
			var dx := (heights[j * _nx + i1] - heights[j * _nx + i0]) / maxf(xs[i1] - xs[i0], 0.01)
			var dz := (heights[j1 * _nx + i] - heights[j0 * _nx + i]) / maxf(zs[j1] - zs[j0], 0.01)
			normals[k] = Vector3(-dx, 1.0, -dz).normalized()
			var rc := Vector2(xs[i] - centre.x, zs[j] - centre.z).length()
			var c := Color.WHITE.lerp(far_tint, smoothstep(tint_r0, tint_r1, rc))
			if tint.is_valid():
				c *= tint.call(xs[i], zs[j], heights[k])
			colors[k] = c
	var idx := PackedInt32Array()
	idx.resize((_nx - 1) * (_nz - 1) * 6)
	var w := 0
	for j in _nz - 1:
		for i in _nx - 1:
			var a := j * _nx + i
			var b := a + 1
			var c := a + _nx
			var d := c + 1
			# Split each quad along the diagonal that follows the land better.
			if absf(heights[a] - heights[d]) < absf(heights[b] - heights[c]):
				for v in [a, b, d, a, d, c]:
					idx[w] = v
					w += 1
			else:
				for v in [a, b, c, b, d, c]:
					idx[w] = v
					w += 1
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


func triangle_count() -> int:
	return (_nx - 1) * (_nz - 1) * 2


# --- Internals ---

## Grid lines: every STEP within `inner` of `c`, then spacing growing ×1.5 out to OUTER.
static func _axis(c: float, inner: float) -> PackedFloat32Array:
	var outer := PackedFloat32Array()
	var d := inner
	var gap := STEP * 1.5
	while d < OUTER:
		d += gap
		gap *= 1.5
		outer.append(d)
	var out := PackedFloat32Array()
	for k in range(outer.size() - 1, -1, -1):
		out.append(c - outer[k])
	var x := -inner
	while x <= inner + 0.01:
		out.append(c + x)
		x += STEP
	for k in outer.size():
		out.append(c + outer[k])
	return out


## Every 3 m of road stamps the vertices within its wall + STAMP: the nearest wins.
func _stamp(track: KartTrackModel) -> void:
	var s := 0.0
	while s < track.length:
		var p := track.sample(s).position
		var edge := track.half_width(s) + track.verge
		var low := p.y - edge * absf(tan(track.banking(s))) - UNDER
		var reach := edge + STAMP
		var i0 := maxi(xs.bsearch(p.x - reach), 0)
		var i1 := mini(xs.bsearch(p.x + reach), _nx - 1)
		var j0 := maxi(zs.bsearch(p.z - reach), 0)
		var j1 := mini(zs.bsearch(p.z + reach), _nz - 1)
		for j in range(j0, j1 + 1):
			var dz := zs[j] - p.z
			for i in range(i0, i1 + 1):
				var dx := xs[i] - p.x
				var r := sqrt(dx * dx + dz * dz) - edge
				var k := j * _nx + i
				if r < r_road[k]:
					r_road[k] = r
					road_y[k] = low
		s += 3.0
	# Beyond STAMP the road no longer counts.
	for k in r_road.size():
		if r_road[k] > STAMP:
			r_road[k] = FAR
