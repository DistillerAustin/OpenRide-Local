class_name KartMinimap
extends Control
## The minimap (#43), bottom left: a rounded night-violet card with the track's outline (a dark
## casing, a white road with a dashed centre line, a checkered start line) and a dot per kart in
## its racer's colour; the rider's dot is bigger, ringed in gold, and drawn on top.
##
## The track is drawn once per track (`set_track`); only the dots redraw each frame, on their own
## child control, so the outline's polylines aren't rebuilt.

const SIZE := Vector2(320, 250)
const INSET := 30.0

var _pts := PackedVector2Array()
var _xf := Transform2D.IDENTITY
var _dots := PackedVector2Array()
var _colors := PackedColorArray()
var _dot_layer: Control
var _rider := 0


func _init() -> void:
	name = "Minimap"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE
	_dot_layer = Control.new()
	_dot_layer.name = "Dots"
	_dot_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dot_layer.size = SIZE
	_dot_layer.draw.connect(_draw_dots)
	add_child(_dot_layer)


## The track (and the racers' colours, kart id order).
func set_track(track: KartTrackModel, racers: Array) -> void:
	var raw := PackedVector2Array()
	var s := 0.0
	while s < track.length:
		var p := track.sample(s).position
		raw.append(Vector2(p.x, p.z))
		s += 5.0
	var bounds := Rect2(raw[0], Vector2.ZERO)
	for p in raw:
		bounds = bounds.expand(p)
	var inner := Rect2(Vector2(INSET, INSET), SIZE - Vector2(INSET, INSET) * 2.0)
	var k := minf(inner.size.x / maxf(bounds.size.x, 1.0), inner.size.y / maxf(bounds.size.y, 1.0))
	var off := inner.position + (inner.size - bounds.size * k) * 0.5 - bounds.position * k
	_xf = Transform2D(0.0, Vector2(k, k), 0.0, off)
	_pts = PackedVector2Array()
	for p in raw:
		_pts.append(_xf * p)
	_pts.append(_pts[0])
	_colors.resize(racers.size())
	for i in racers.size():
		_colors[i] = racers[i].color
	queue_redraw()


## Every kart's world position, each frame.
func set_karts(karts: Array) -> void:
	_dots.resize(karts.size())
	for i in karts.size():
		var k: KartState = karts[i]
		_dots[i] = _xf * Vector2(k.pos.x, k.pos.z)
	_dot_layer.queue_redraw()


func _draw() -> void:
	var card := StyleBoxFlat.new()
	card.bg_color = Color(0.1, 0.06, 0.24, 0.62)
	card.set_corner_radius_all(26)
	card.border_color = Color(0.55, 0.42, 1.0, 0.55)
	card.set_border_width_all(3)
	card.anti_aliasing = true
	draw_style_box(card, Rect2(Vector2.ZERO, SIZE))
	if _pts.size() < 3:
		return
	draw_polyline(_pts, Color(0.06, 0.03, 0.16, 0.9), 26.0, true)
	draw_polyline(_pts, Color(0.95, 0.94, 1.0), 14.0, true)
	# A dashed centre line.
	var dash := 0
	for i in range(0, _pts.size() - 1):
		dash += 1
		if dash % 3 == 0:
			draw_line(_pts[i], _pts[i + 1], Color(0.55, 0.5, 0.75), 3.0, true)
	# The checkered start line, across the road.
	var a := _pts[0]
	var dir := (_pts[1] - _pts[0]).normalized()
	var n := dir.orthogonal()
	for j in 4:
		var t := -1.5 + j
		var col := Color.WHITE if j % 2 == 0 else Color(0.08, 0.05, 0.15)
		draw_rect(Rect2(a + n * t * 4.0 - Vector2(2.5, 2.5), Vector2(5, 5)), col)


func _draw_dots() -> void:
	for i in range(_dots.size() - 1, -1, -1):
		if i == _rider:
			continue
		_dot_layer.draw_circle(_dots[i], 12.0, KartTheme.OUTLINE)
		_dot_layer.draw_circle(_dots[i], 9.0, _colors[i] if i < _colors.size() else Color.WHITE)
	if _rider < _dots.size():
		var p := _dots[_rider]
		_dot_layer.draw_circle(p, 17.0, KartTheme.OUTLINE)
		_dot_layer.draw_circle(p, 14.0, Color(1.0, 0.82, 0.2))
		_dot_layer.draw_circle(p, 10.0, _colors[_rider] if _rider < _colors.size() else Color.WHITE)
		_dot_layer.draw_circle(p + Vector2(-3, -3), 3.0, Color(1, 1, 1, 0.8))
