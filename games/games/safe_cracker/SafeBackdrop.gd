class_name SafeBackdrop
extends Node2D
## The room behind the safe (#41): one `SafeMesh` batch redrawn only when the place changes, and
## the place's slow ambient life as children that never redraw: rain on the office window and
## the sea in the cabin's porthole (shaders on one rect each), the cabin's lantern swaying (a
## rotation tween), the lab's flasks shimmering (a shader), and dust drifting in the key light
## (one CPUParticles2D, 16 motes). Each lives in its place and is hidden in the others.

const RAIN_RECT := Rect2(64, 314, 312, 392)
const PORTHOLE := Vector2(230, 520)
const PORTHOLE_R := 124.0
const LANTERN_PIVOT := Vector2(1700, 120)
const LANTERN_SWAY := 2.5  ## degrees each way
const LANTERN_SEC := 3.6  ## one way
const DUST := 16

var place_index := 0
var rain: ColorRect
var sea: ColorRect
var lantern: Node2D
var flasks: Node2D
var dust: CPUParticles2D
var _lantern_tween: Tween


func _init() -> void:
	rain = _shader_rect("Rain", RAIN_RECT, preload("res://games/safe_cracker/safe_rain.gdshader"))
	sea = _shader_rect("Sea", Rect2(PORTHOLE - Vector2.ONE * PORTHOLE_R, Vector2.ONE * PORTHOLE_R * 2.0),
		preload("res://games/safe_cracker/safe_sea.gdshader"))
	flasks = SafeDial.Layer.new()
	flasks.name = "Flasks"
	flasks.paint = _paint_flasks
	var shimmer := ShaderMaterial.new()
	shimmer.shader = preload("res://games/safe_cracker/safe_shimmer.gdshader")
	flasks.material = shimmer
	add_child(flasks)
	lantern = SafeDial.Layer.new()
	lantern.name = "Lantern"
	lantern.paint = _paint_lantern
	lantern.position = LANTERN_PIVOT
	add_child(lantern)
	dust = _make_dust()
	add_child(dust)


func _shader_rect(rect_name: String, r: Rect2, shader: Shader) -> ColorRect:
	var c := ColorRect.new()
	c.name = rect_name
	c.position = r.position
	c.size = r.size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = shader
	c.material = mat
	add_child(c)
	return c


func set_place(index: int) -> void:
	place_index = index
	var id: String = SafePlaces.place(index).id
	rain.visible = id == "office"
	sea.visible = id == "cabin"
	flasks.visible = id == "lab"
	lantern.visible = id == "cabin"
	if _lantern_tween:
		_lantern_tween.kill()
		_lantern_tween = null
	lantern.rotation = 0.0
	if lantern.visible and is_inside_tree():
		_lantern_tween = create_tween().set_loops()
		_lantern_tween.tween_property(lantern, "rotation", deg_to_rad(LANTERN_SWAY), LANTERN_SEC).set_trans(Tween.TRANS_SINE)
		_lantern_tween.tween_property(lantern, "rotation", deg_to_rad(-LANTERN_SWAY), LANTERN_SEC).set_trans(Tween.TRANS_SINE)
	var l := SafePlaces.light(index)
	var at: Vector2 = l.at
	var overhead := at.y < 100.0
	dust.position = at + (Vector2(0, 200) if overhead else Vector2.ZERO)
	dust.emission_rect_extents = Vector2(700, 150) if overhead else (l.radius as Vector2) * 0.4
	var lc: Color = l.color
	var ramp := Gradient.new()
	ramp.set_color(0, Color(lc, 0.0))
	ramp.set_color(1, Color(lc, 0.0))
	ramp.add_point(0.25, Color(lc, 0.28))
	ramp.add_point(0.75, Color(lc, 0.22))
	dust.color_ramp = ramp
	dust.restart()
	queue_redraw()
	flasks.queue_redraw()


func _draw() -> void:
	var m := SafeMesh.new()
	SafePlaces.build_room(m, place_index)
	m.flush(self)


## The flasks' liquids on the lab's shelves (the glass is in the room).
func _paint_flasks(ci: CanvasItem) -> void:
	var m := SafeMesh.new()
	var tints := [Color(0.4, 0.85, 0.6), Color(0.9, 0.6, 0.3), Color(0.5, 0.7, 0.95), Color(0.9, 0.5, 0.6)]
	for shelf in 3:
		var y := 420.0 + shelf * 150.0
		for k in 4:
			var c: Color = tints[(k + shelf) % 4]
			var at := Vector2(110.0 + k * 80.0, y + 72.0)
			var cut := 10.0 - 4.0 * ((k + shelf) % 3)
			var arc := SafeMesh.arc_points(at, 26.0, asin(-cut / 26.0), PI - asin(-cut / 26.0), 18)
			m.fill(arc, c)
			m.rect(Rect2(at.x - 18, at.y - cut - 2.0, 36, 3), c.lightened(0.4))
			m.circle(at + Vector2(-9, 8), 5.0, Color(1, 1, 1, 0.25))
	m.flush(ci)


## The lantern on its chain, from the pivot: a cage with a glowing glass.
func _paint_lantern(ci: CanvasItem) -> void:
	var m := SafeMesh.new()
	var iron := Color(0.14, 0.11, 0.08)
	var acc: Color = SafePlaces.place(place_index).accent
	for k in 8:
		m.line(Vector2(0, k * 26.0), Vector2(0, k * 26.0 + 20.0), 4.0, iron.lightened(0.15))
	var top := 220.0
	m.glow(Vector2(0, top + 80), Vector2(110, 110), Color(1.0, 0.75, 0.35, 0.35), 10)
	m.quad(Vector2(-22, top), Vector2(22, top), Vector2(38, top + 26), Vector2(-38, top + 26), iron.lightened(0.1))
	m.rect_v(Rect2(-32, top + 26, 64, 104), Color(1.0, 0.85, 0.5, 0.9), Color(1.0, 0.65, 0.3, 0.9))
	m.glow(Vector2(0, top + 78), Vector2(18, 30), Color(1, 0.97, 0.85, 1.0), 6, 0.3)
	for x in [-32.0, 0.0, 32.0]:
		m.line(Vector2(x, top + 26), Vector2(x, top + 130), 5.0, iron)
	m.rect_v(Rect2(-40, top + 128, 80, 16), acc, acc.darkened(0.4))
	m.circle(Vector2(0, top - 6), 9.0, iron)
	m.flush(ci)


func _make_dust() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "Dust"
	p.amount = DUST
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.texture = SafePlaces.soft_dot()
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(200, 200)
	p.direction = Vector2(0.3, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, 2)
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 10.0
	p.scale_amount_min = 0.1
	p.scale_amount_max = 0.2
	return p
