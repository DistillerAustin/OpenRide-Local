class_name KartDraw
extends RefCounted
## Batched vector drawing for the HUD (#43): discs, rings, arcs and quads collected into one
## triangle array (with a soft 1.5 px alpha fringe for anti-aliasing) and drawn in a single call.
##
## Why: the GL Compatibility renderer draws each `draw_circle` / `draw_arc` / polygon as its own
## draw call, so a rainbow rim of 48 arcs cost 48 calls on a GPU budgeted at ~120 for the whole
## frame. Shapes keep their painter's order inside the array.
##
##   var d := KartDraw.new()
##   d.disc(c, 40.0, Color.WHITE)
##   d.ring(c, 40.0, 50.0, Color.BLACK)
##   d.flush(self)   # in _draw()

const AA := 1.5

var points := PackedVector2Array()
var colors := PackedColorArray()
var indices := PackedInt32Array()


## A filled circle.
func disc(c: Vector2, r: float, color: Color, segments := 0) -> void:
	ring(c, 0.0, r, color, color, 0.0, TAU, segments)


## A band between radii r0 and r1, from angle a0 to a1 (radians, 0 = +x, clockwise on screen).
## `color1` (optional) blends along the arc; `gradient`, when set, colours it by angle instead.
func ring(c: Vector2, r0: float, r1: float, color: Color, color1 := Color(-1, 0, 0), a0 := 0.0, a1 := TAU,
		segments := 0, gradient: Gradient = null) -> void:
	if segments <= 0:
		segments = clampi(int(r1 * absf(a1 - a0) / 6.0), 12, 96)
	var full := absf(a1 - a0) >= TAU - 0.001
	var radii: Array[float] = []
	var alpha: Array[float] = []
	if r0 > 0.0:
		radii.append_array([maxf(r0 - AA, 0.0), r0])
		alpha.append_array([0.0, 1.0])
	else:
		radii.append(0.0)
		alpha.append(1.0)
	radii.append_array([r1, r1 + AA])
	alpha.append_array([1.0, 0.0])
	var rows := radii.size()
	var base := points.size()
	var cols := segments + (0 if full else 1)
	for i in cols:
		var t := float(i) / segments
		var a := lerpf(a0, a1, t)
		var dir := Vector2(cos(a), sin(a))
		var col := color
		if gradient:
			col = gradient.sample(t)
		elif color1.r >= 0.0:
			col = color.lerp(color1, t)
		for j in rows:
			points.append(c + dir * radii[j])
			colors.append(Color(col, col.a * alpha[j]))
	for i in segments:
		var i1 := (i + 1) % cols if full else i + 1
		for j in rows - 1:
			var p00 := base + i * rows + j
			var p01 := base + i * rows + j + 1
			var p10 := base + i1 * rows + j
			var p11 := base + i1 * rows + j + 1
			indices.append_array([p00, p10, p11, p00, p11, p01])


## A filled convex quad (corners in order), with no fringe (for slanted bars).
func quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, color: Color) -> void:
	var base := points.size()
	points.append_array([a, b, c, d])
	colors.append_array([color, color, color, color])
	indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])


## A filled convex polygon (fan from the first point).
func convex(pts: PackedVector2Array, color: Color) -> void:
	var base := points.size()
	for p in pts:
		points.append(p)
		colors.append(color)
	for i in range(1, pts.size() - 1):
		indices.append_array([base, base + i, base + i + 1])


## A filled simple polygon (any shape; triangulated).
func polygon(pts: PackedVector2Array, color: Color) -> void:
	var tris := Geometry2D.triangulate_polygon(pts)
	if tris.is_empty():
		return
	var base := points.size()
	for p in pts:
		points.append(p)
		colors.append(color)
	for t in tris:
		indices.append(base + t)


## A thick polyline with round joints.
func polyline(pts: PackedVector2Array, width: float, color: Color) -> void:
	for i in pts.size() - 1:
		line(pts[i], pts[i + 1], width, color)
	for p in pts:
		disc(p, width * 0.5, color, 10)


## An axis-aligned rectangle, optionally with rounded corners (one convex shape, so translucent
## colours have no seams), with an anti-aliased edge.
func rect(r: Rect2, color: Color, radius := 0.0) -> void:
	radius = minf(radius, minf(r.size.x, r.size.y) * 0.5)
	if radius <= 0.0:
		convex_aa(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), color)
		return
	var pts := PackedVector2Array()
	var steps := clampi(int(radius / 3.0), 3, 10)
	var corners := [[r.end - Vector2(radius, radius), 0.0], [Vector2(r.position.x + radius, r.end.y - radius), PI * 0.5],
		[r.position + Vector2(radius, radius), PI], [Vector2(r.end.x - radius, r.position.y + radius), PI * 1.5]]
	for corner in corners:
		for i in steps + 1:
			var a: float = corner[1] + PI * 0.5 * i / steps
			pts.append(corner[0] + Vector2(cos(a), sin(a)) * radius)
	convex_aa(pts, color)


## A filled convex polygon with a soft anti-aliased rim (points in either winding).
func convex_aa(pts: PackedVector2Array, color: Color) -> void:
	var n := pts.size()
	if n < 3:
		return
	var centre := Vector2.ZERO
	for p in pts:
		centre += p
	centre /= n
	var base := points.size()
	var clear := Color(color, 0.0)
	for i in n:
		var p := pts[i]
		points.append(p)
		colors.append(color)
		var prev := pts[(i - 1 + n) % n]
		var next := pts[(i + 1) % n]
		var nrm := ((p - prev).orthogonal().normalized() + (next - p).orthogonal().normalized()).normalized()
		if nrm.dot(p - centre) < 0.0:
			nrm = -nrm
		points.append(p + nrm * AA)
		colors.append(clear)
	for i in range(1, n - 1):
		indices.append_array([base, base + i * 2, base + (i + 1) * 2])
	for i in n:
		var a := base + i * 2
		var b := base + ((i + 1) % n) * 2
		indices.append_array([a, b, b + 1, a, b + 1, a + 1])


## An ellipse.
func ellipse(c: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	convex(pts, color)


## A thick straight line with square ends.
func line(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	var n := (b - a).normalized().orthogonal() * width * 0.5
	quad(a + n, b + n, b - n, a - n, color)


func is_empty() -> bool:
	return indices.is_empty()


## Draws everything collected on `ci` in one call, then empties the builder.
func flush(ci: CanvasItem) -> void:
	if not indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), indices, points, colors)
	points = PackedVector2Array()
	colors = PackedColorArray()
	indices = PackedInt32Array()
