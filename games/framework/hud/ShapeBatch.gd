class_name ShapeBatch
extends RefCounted
## Flat shapes (stars, circles, thick lines, arcs, polygons) gathered into one triangle array,
## so a drawn widget costs one draw call however many shapes it has. Each `draw_circle`,
## `draw_line` or `draw_arc` would be its own call on the GL Compatibility renderer (the
## tablet's draw-call budget: framework/ui/UI_STYLE.md, "Tablet budget"). Shapes are drawn in
## the order added, so a fill added after its outline sits on it. No antialiasing: give small
## shapes an ink outline instead.
##
##   func _draw():
##       var b := ShapeBatch.new()
##       b.circle(c, 40.0, ink); b.circle(c, 34.0, GameTheme.GOOD); b.line(a, z, 8.0, Color.WHITE)
##       b.draw(self)

var points := PackedVector2Array()
var colors := PackedColorArray()
var indices := PackedInt32Array()
## Applied to every point added from now on (a figure leaning about its hip).
var xform := Transform2D.IDENTITY


## A five-pointed star, point up.
func star(centre: Vector2, radius: float, color: Color) -> ShapeBatch:
	return fan(centre, StarRow._star(centre, radius), color)


## A filled circle.
func circle(centre: Vector2, radius: float, color: Color, segments := 24) -> ShapeBatch:
	var ring := PackedVector2Array()
	for i in segments:
		ring.append(centre + Vector2.from_angle(TAU * i / segments) * radius)
	return fan(centre, ring, color)


## A thick straight line with round ends.
## A music note (the display faces have no ♪) centred on `c`; `scale` 1 suits a 120 px button.
func note(c: Vector2, scale: float, color: Color) -> ShapeBatch:
	circle(c + Vector2(-12, 20) * scale, 14.0 * scale, color)
	line(c + Vector2(0, 20) * scale, c + Vector2(0, -28) * scale, 7.0 * scale, color)
	return line(c + Vector2(0, -28) * scale, c + Vector2(22, -18) * scale, 7.0 * scale, color)


func line(a: Vector2, b: Vector2, width: float, color: Color, round_ends := true) -> ShapeBatch:
	var side := (b - a).normalized().orthogonal() * width * 0.5
	quad(a + side, b + side, b - side, a - side, color)
	if round_ends:
		circle(a, width * 0.5, color, 12)
		circle(b, width * 0.5, color, 12)
	return self


## A thick arc from angle `from` to `to` (radians, clockwise on screen).
func arc(centre: Vector2, radius: float, from: float, to: float, width: float, color: Color, segments := 48) -> ShapeBatch:
	var n := maxi(2, ceili(segments * absf(to - from) / TAU))
	for i in n:
		var a0 := lerpf(from, to, float(i) / n)
		var a1 := lerpf(from, to, float(i + 1) / n)
		var d0 := Vector2.from_angle(a0)
		var d1 := Vector2.from_angle(a1)
		quad(centre + d0 * (radius + width * 0.5), centre + d1 * (radius + width * 0.5),
			centre + d1 * (radius - width * 0.5), centre + d0 * (radius - width * 0.5), color)
	return self


## A polyline of thick segments (a tick), with round joints.
func polyline(path: PackedVector2Array, width: float, color: Color) -> ShapeBatch:
	for i in path.size() - 1:
		line(path[i], path[i + 1], width, color, true)
	return self


## A convex polygon (fanned from its first point).
func convex(polygon: PackedVector2Array, color: Color) -> ShapeBatch:
	var base := points.size()
	for p in polygon:
		points.append(xform * p)
		colors.append(color)
	for i in range(1, polygon.size() - 1):
		indices.append_array([base, base + i, base + i + 1])
	return self


func quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, color: Color) -> ShapeBatch:
	return convex(PackedVector2Array([a, b, c, d]), color)


## A shape fanned from `centre` through `ring` (a star, a circle).
func fan(centre: Vector2, ring: PackedVector2Array, color: Color) -> ShapeBatch:
	var base := points.size()
	points.append(xform * centre)
	colors.append(color)
	for p in ring:
		points.append(xform * p)
		colors.append(color)
	var n := ring.size()
	for i in n:
		indices.append_array([base, base + 1 + i, base + 1 + (i + 1) % n])
	return self


## Draws everything gathered on `item` (call from its `_draw`). Points are in the item's space
## (through `xform`); `draw_set_transform` doesn't apply to them.
func draw(item: CanvasItem) -> void:
	if not indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(item.get_canvas_item(), indices, points, colors)
