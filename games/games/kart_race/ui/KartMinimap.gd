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
var _dot_kit := KartDraw.new()  ## every dot in one draw call


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
	# The card and the track in one triangle array (one draw call).
	var d := _dot_kit
	d.rect(Rect2(Vector2.ZERO, SIZE), Color(0.55, 0.42, 1.0, 0.55), 26.0)
	d.rect(Rect2(Vector2(3, 3), SIZE - Vector2(6, 6)), Color(0.1, 0.06, 0.24, 0.7), 23.0)
	if _pts.size() >= 3:
		var outline := _pts.slice(0, _pts.size() - 1)
		_band(d, outline, 13.0, Color(0.06, 0.03, 0.16, 0.95))
		_band(d, outline, 7.0, Color(0.95, 0.94, 1.0))
		for i in range(0, _pts.size() - 1, 3):
			d.line(_pts[i], _pts[i + 1], 3.0, Color(0.55, 0.5, 0.75))
		# The checkered start line, across the road.
		var a := _pts[0]
		var n := (_pts[1] - _pts[0]).normalized().orthogonal()
		for j in 4:
			var col := Color.WHITE if j % 2 == 0 else Color(0.08, 0.05, 0.15)
			d.rect(Rect2(a + n * (-1.5 + j) * 4.0 - Vector2(2.5, 2.5), Vector2(5, 5)), col)
	d.flush(self)


## A closed band `half` px either side of the loop, mitred at each point, with soft edges.
static func _band(d: KartDraw, loop: PackedVector2Array, half: float, color: Color) -> void:
	var n := loop.size()
	var base := d.points.size()
	var clear := Color(color, 0.0)
	for i in n:
		var prev := loop[(i - 1 + n) % n]
		var next := loop[(i + 1) % n]
		var nrm := (next - prev).normalized().orthogonal()
		for k in [-half - KartDraw.AA, -half, half, half + KartDraw.AA]:
			d.points.append(loop[i] + nrm * k)
			d.colors.append(clear if absf(k) > half else color)
	for i in n:
		var a := base + i * 4
		var b := base + ((i + 1) % n) * 4
		for j in 3:
			d.indices.append_array([a + j, b + j, b + j + 1, a + j, b + j + 1, a + j + 1])


func _draw_dots() -> void:
	var d := _dot_kit
	for i in range(_dots.size() - 1, -1, -1):
		if i == _rider:
			continue
		d.disc(_dots[i], 12.0, KartTheme.OUTLINE, 14)
		d.disc(_dots[i], 9.0, _colors[i] if i < _colors.size() else Color.WHITE, 14)
	if _rider < _dots.size():
		var p := _dots[_rider]
		d.disc(p, 17.0, KartTheme.OUTLINE)
		d.disc(p, 14.0, Color(1.0, 0.82, 0.2))
		d.disc(p, 10.0, _colors[_rider] if _rider < _colors.size() else Color.WHITE)
		d.disc(p + Vector2(-3, -3), 3.0, Color(1, 1, 1, 0.8), 8)
	d.flush(_dot_layer)
