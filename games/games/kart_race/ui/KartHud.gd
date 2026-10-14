class_name KartHud
extends CanvasLayer
## Kart Race's game HUD (#43, the hero slice), over the 3D view and under the framework's HUD
## (which keeps the ride metrics, the clock and the buttons, restyled through `Hud.set_skin`):
##
##   - the race clock under the lap badge (KartStatus, in the HUD's top-centre slot);
##   - the racer list down the left: round rendered portraits in race order, sliding on overtakes;
##   - the minimap, bottom left;
##   - the item slot on the right, a big round tap target (tap = use the item), ringed by the
##     drift/boost meter;
##   - the big italic gradient position badge, bottom right, which pops on every change;
##   - the title card, the countdown and banners.
##
## Everything except the clock changes only with its value; the clock and the minimap's dots are
## free-standing (no container), so their per-frame changes never re-lay out the HUD.

signal item_pressed

const LAYER := 8
const ROW_H := 54.0
const PORTRAIT := 50.0
const LIST_TOP := 392.0
const ITEM_SIZE := 250.0
const MAP_RECT := Rect2(40, 818, 330, 222)

## racer id -> its portrait (a rendered head), also used by the boards.
var portraits := {}
var lineup: Array = []

var _root: Control
var _gameplay: Control
var _clock: Label
var _rows: Array[Control] = []
var _row_place: Array[Label] = []
var _row_target := PackedFloat32Array()
var _shown_order := []
var _badge: Control
var _place: Label
var _suffix: Label
var _shown_place := 0
var _item: Button
var _item_icon: Control
var _map: Control
var _map_dots: Control
var _map_pts := PackedVector2Array()
var _map_xf := Transform2D.IDENTITY
var _dots := PackedVector2Array()
var _dot_colors := PackedColorArray()
var _rider_dot := 0
var _drift := 0.0
var _drift_tier := 0
var _title: Control
var _title_chip: Label
var _title_name: Label
var _count: Label
var _banner: Label
var _tweens := {}
var _shown_clock := ""
var _portrait_shader: Shader


func _init() -> void:
	layer = LAYER
	_root = Control.new()
	_root.name = "KartHud"
	_root.size = Vector2(HudTheme.W, HudTheme.H)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_gameplay = Control.new()
	_gameplay.name = "Gameplay"
	_gameplay.size = _root.size
	_gameplay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_gameplay)
	_portrait_shader = load(KartTheme.SHADERS + "portrait.gdshader")
	_build_clock()
	_build_badge()
	_build_item()
	_build_map()
	_build_title()
	_count = KartTheme.label("", 260, KartTheme.INK)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count.size = Vector2(900, 360)
	_count.position = Vector2((HudTheme.W - 900) * 0.5, 300)
	_count.pivot_offset = _count.size * 0.5
	_count.visible = false
	_root.add_child(_count)
	_banner = KartTheme.label("", 110, KartTheme.INK)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.size = Vector2(1200, 160)
	_banner.position = Vector2((HudTheme.W - 1200) * 0.5, 260)
	_banner.pivot_offset = _banner.size * 0.5
	_banner.visible = false
	KartTheme.gradient(_banner, KartTheme.GOLD_TOP, KartTheme.GOLD_BOTTOM)
	_root.add_child(_banner)


## A new grid: the racers (KartRoster entries, kart id order) and the track for the minimap.
func setup(racers: Array, track: KartTrackModel) -> void:
	lineup = racers
	_make_portraits()
	_build_list()
	_map_track(track)


# --- Per frame ---

func update(race: KartRaceLogic, drift_charge: float, drift_tier: int) -> void:
	var k: KartState = race.karts[KartRaceLogic.RIDER]
	var t := race.time if race.phase != KartRaceLogic.Phase.FINISHED else k.finish_time
	if race.phase == KartRaceLogic.Phase.RACING or race.phase == KartRaceLogic.Phase.FINISHED:
		var text := KartTheme.race_time(t)
		if text != _shown_clock:
			_shown_clock = text
			_clock.text = text
	_set_place(k.place)
	var order := race.order()
	if order != _shown_order:
		_shown_order = order.duplicate()
		for p in order.size():
			var id: int = order[p]
			if id < _rows.size():
				_row_target[id] = LIST_TOP + p * ROW_H
				_row_place[id].text = str(p + 1)
		for id in _rows.size():
			_slide_row(id)
	# Minimap dots.
	_dots.resize(race.karts.size())
	for i in race.karts.size():
		var kk: KartState = race.karts[i]
		_dots[i] = _map_xf * Vector2(kk.pos.x, kk.pos.z)
	_map_dots.queue_redraw()
	if absf(drift_charge - _drift) > 0.01 or drift_tier != _drift_tier:
		_drift = drift_charge
		_drift_tier = drift_tier
		_item_icon.queue_redraw()


func set_gameplay_visible(on: bool, animate := true) -> void:
	if _gameplay.visible == on and _gameplay.modulate.a > 0.99:
		return
	_kill("gameplay")
	_gameplay.visible = true
	if not animate:
		_gameplay.modulate.a = 1.0 if on else 0.0
		_gameplay.visible = on
		return
	var tw := create_tween()
	_tweens["gameplay"] = tw
	tw.tween_property(_gameplay, "modulate:a", 1.0 if on else 0.0, 0.35)
	if not on:
		tw.tween_callback(func(): _gameplay.visible = false)


# --- Title card, countdown, banners ---

func show_title(chip: String, title: String, seconds := 3.2) -> void:
	_title_chip.text = chip.to_upper()
	_title_name.text = title
	_kill("title")
	_title.visible = true
	_title.modulate.a = 0.0
	_title.position.x = -120.0
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tweens["title"] = tw
	tw.tween_property(_title, "position:x", 0.0, 0.5)
	tw.parallel().tween_property(_title, "modulate:a", 1.0, 0.3)
	tw.tween_interval(seconds)
	tw.tween_property(_title, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): _title.visible = false)


func countdown(n: int) -> void:
	_count.text = str(n)
	KartTheme.gradient(_count, KartTheme.GOLD_TOP, KartTheme.GOLD_BOTTOM)
	_pop(_count, 0.9)


func go() -> void:
	_count.text = "GO!"
	KartTheme.gradient(_count, KartTheme.GREEN_TOP, KartTheme.GREEN_BOTTOM)
	_pop(_count, 0.9)


func banner(text: String, seconds := 1.6) -> void:
	_banner.text = text
	_kill("banner")
	_banner.visible = true
	_banner.modulate.a = 1.0
	_banner.scale = Vector2(0.3, 0.3)
	var tw := create_tween()
	_tweens["banner"] = tw
	tw.tween_property(_banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(seconds)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func(): _banner.visible = false)


func _pop(l: Label, hold: float) -> void:
	_kill(str(l.get_instance_id()))
	l.visible = true
	l.modulate.a = 1.0
	l.scale = Vector2(2.0, 2.0)
	var tw := create_tween()
	_tweens[str(l.get_instance_id())] = tw
	tw.tween_property(l, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.0, hold - 0.55))
	tw.tween_property(l, "modulate:a", 0.0, 0.22)
	tw.parallel().tween_property(l, "scale", Vector2(0.8, 0.8), 0.22)
	tw.tween_callback(func(): l.visible = false)


func _kill(key: String) -> void:
	var tw: Tween = _tweens.get(key)
	if tw and tw.is_valid():
		tw.kill()


# --- Builders ---

func _build_clock() -> void:
	var plate := Panel.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := KartTheme.badge(Color(0.08, 0.05, 0.2, 0.72), 0.2, 10, Color(0, 0, 0, 0))
	plate.add_theme_stylebox_override("panel", style)
	plate.size = Vector2(290, 62)
	plate.position = Vector2(HudTheme.W * 0.5 - 145, 150)
	_gameplay.add_child(plate)
	_clock = KartTheme.label("0:00.000", 48, KartTheme.INK, true)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock.size = Vector2(290, 62)
	_clock.position = plate.position + Vector2(0, -3)
	_gameplay.add_child(_clock)


func _build_badge() -> void:
	_badge = Control.new()
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.size = Vector2(400, 250)
	_badge.position = Vector2(HudTheme.W - 40 - 400, 655)
	_badge.pivot_offset = Vector2(300, 170)
	_gameplay.add_child(_badge)
	_place = KartTheme.label("8", 236, KartTheme.INK)
	_place.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place.size = Vector2(250, 270)
	_place.position = Vector2(30, -26)
	_place.add_theme_constant_override("outline_size", 34)
	KartTheme.gradient(_place, KartTheme.VIOLET_TOP, KartTheme.VIOLET_BOTTOM)
	_badge.add_child(_place)
	_suffix = KartTheme.label("th", 92, KartTheme.INK)
	_suffix.position = Vector2(286, 26)
	_suffix.add_theme_constant_override("outline_size", 20)
	KartTheme.gradient(_suffix, KartTheme.VIOLET_TOP, KartTheme.VIOLET_BOTTOM)
	_badge.add_child(_suffix)


func _set_place(place: int) -> void:
	if place == _shown_place or place <= 0:
		return
	var better := _shown_place == 0 or place < _shown_place
	_shown_place = place
	_place.text = str(place)
	_suffix.text = KartTheme.ordinal_suffix(place)
	var top: Color = KartTheme.GOLD_TOP if place <= 3 else KartTheme.VIOLET_TOP
	var bottom: Color = KartTheme.GOLD_BOTTOM if place <= 3 else KartTheme.VIOLET_BOTTOM
	(_place.material as ShaderMaterial).set_shader_parameter("top", top)
	(_place.material as ShaderMaterial).set_shader_parameter("bottom", bottom)
	(_suffix.material as ShaderMaterial).set_shader_parameter("top", top)
	(_suffix.material as ShaderMaterial).set_shader_parameter("bottom", bottom)
	_kill("badge")
	var tw := create_tween()
	_tweens["badge"] = tw
	_badge.scale = Vector2(1.35, 1.35) if better else Vector2(0.8, 0.8)
	_badge.rotation = -0.08 if better else 0.05
	tw.tween_property(_badge, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_badge, "rotation", 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_item() -> void:
	_item = Button.new()
	_item.name = "ItemSlot"
	_item.focus_mode = Control.FOCUS_NONE
	_item.size = Vector2(ITEM_SIZE, ITEM_SIZE)
	_item.position = Vector2(HudTheme.W - 40 - ITEM_SIZE, 392)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.2, 0.12, 0.42, 0.82) if state != "pressed" else Color(0.45, 0.3, 0.9, 0.9)
		s.set_corner_radius_all(int(ITEM_SIZE * 0.5))
		s.border_color = Color(0.85, 0.78, 1.0)
		s.set_border_width_all(7)
		s.shadow_color = Color(0.05, 0.0, 0.15, 0.5)
		s.shadow_size = 10
		s.shadow_offset = Vector2(4, 8)
		s.anti_aliasing = true
		_item.add_theme_stylebox_override(state, s)
	_item.pressed.connect(func():
		item_pressed.emit()
		var tw := create_tween()
		_item.pivot_offset = _item.size * 0.5
		_item.scale = Vector2(0.88, 0.88)
		tw.tween_property(_item, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	_gameplay.add_child(_item)
	_item_icon = Control.new()
	_item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_item_icon.size = _item.size
	_item_icon.draw.connect(_draw_item)
	_item.add_child(_item_icon)


## The held item (a Turbo Pepper for the slice) and the drift/boost ring around the slot.
func _draw_item() -> void:
	var c := _item_icon.size * 0.5
	var r := ITEM_SIZE * 0.5 + 16.0
	_item_icon.draw_arc(c, r, 0, TAU, 64, Color(0.08, 0.04, 0.18, 0.7), 18.0, true)
	if _drift > 0.0:
		var colors: Array = KartFx.TIER_COLORS
		var col: Color = colors[clampi(_drift_tier - 1, 0, 2)]
		_item_icon.draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * _drift, 64, col, 13.0, true)
	# Turbo Pepper: a glossy red chilli with a green stem and speed streaks.
	var body := PackedVector2Array()
	for i in 21:
		var t := float(i) / 20.0
		var x := lerpf(-62.0, 64.0, t)
		var y := -18.0 + 36.0 * t * t - 10.0 * sin(t * PI)
		var w := 34.0 * sin(clampf(t * 1.15, 0.0, 1.0) * PI * 0.5) * (1.0 - t * 0.85)
		body.append(c + Vector2(x, y - w))
	for i in range(20, -1, -1):
		var t := float(i) / 20.0
		var x := lerpf(-62.0, 64.0, t)
		var y := -18.0 + 36.0 * t * t - 10.0 * sin(t * PI)
		var w := 34.0 * sin(clampf(t * 1.15, 0.0, 1.0) * PI * 0.5) * (1.0 - t * 0.85)
		body.append(c + Vector2(x, y + w * 0.9))
	var outline := body.duplicate()
	outline.append(body[0])
	_item_icon.draw_polyline(outline, KartTheme.OUTLINE, 14.0, true)
	_item_icon.draw_colored_polygon(body, Color(0.93, 0.16, 0.12))
	_item_icon.draw_line(c + Vector2(-40, -30), c + Vector2(10, -20), Color(1, 0.75, 0.7, 0.8), 7.0, true)
	_item_icon.draw_line(c + Vector2(-66, -14), c + Vector2(-82, -38), KartTheme.OUTLINE, 18.0, true)
	_item_icon.draw_line(c + Vector2(-66, -14), c + Vector2(-82, -38), Color(0.3, 0.75, 0.25), 10.0, true)
	_item_icon.draw_circle(c + Vector2(-64, -16), 15.0, KartTheme.OUTLINE)
	_item_icon.draw_circle(c + Vector2(-64, -16), 10.0, Color(0.3, 0.75, 0.25))
	for i in 3:
		var y := -10.0 + i * 22.0
		_item_icon.draw_line(c + Vector2(70, y), c + Vector2(96 - i * 6, y), Color(1, 1, 1, 0.85), 6.0, true)


func _build_map() -> void:
	_map = Control.new()
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map.position = MAP_RECT.position
	_map.size = MAP_RECT.size
	_map.draw.connect(_draw_map)
	_gameplay.add_child(_map)
	_map_dots = Control.new()
	_map_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_dots.size = MAP_RECT.size
	_map_dots.draw.connect(_draw_dots)
	_map.add_child(_map_dots)


func _map_track(track: KartTrackModel) -> void:
	var pts := PackedVector2Array()
	var s := 0.0
	while s < track.length:
		var p := track.sample(s).position
		pts.append(Vector2(p.x, p.z))
		s += 6.0
	var bounds := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		bounds = bounds.expand(p)
	var inner := Rect2(Vector2(22, 22), MAP_RECT.size - Vector2(44, 44))
	var k := minf(inner.size.x / bounds.size.x, inner.size.y / bounds.size.y)
	var off := inner.position + (inner.size - bounds.size * k) * 0.5 - bounds.position * k
	_map_xf = Transform2D(0.0, Vector2(k, k), 0.0, off)
	_map_pts = PackedVector2Array()
	for p in pts:
		_map_pts.append(_map_xf * p)
	_map_pts.append(_map_pts[0])
	_dot_colors.resize(lineup.size())
	for i in lineup.size():
		_dot_colors[i] = lineup[i].color
	_map.queue_redraw()


func _draw_map() -> void:
	if _map_pts.size() < 2:
		return
	_map.draw_polyline(_map_pts, Color(0.08, 0.04, 0.2, 0.75), 26.0, true)
	_map.draw_polyline(_map_pts, Color(0.95, 0.93, 1.0, 0.95), 11.0, true)
	var a := _map_pts[0]
	var b := _map_pts[1]
	var n := (b - a).normalized().orthogonal() * 12.0
	_map.draw_line(a - n, a + n, Color(1, 0.8, 0.15), 6.0, true)


func _draw_dots() -> void:
	for i in range(_dots.size() - 1, -1, -1):
		var r := 13.0 if i == 0 else 9.0
		_map_dots.draw_circle(_dots[i], r + 3.5, KartTheme.OUTLINE)
		_map_dots.draw_circle(_dots[i], r, _dot_colors[i] if i < _dot_colors.size() else Color.WHITE)
		if i == 0:
			_map_dots.draw_circle(_dots[i], r * 0.45, Color.WHITE)


func _build_title() -> void:
	_title = Control.new()
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.size = _root.size
	_title.visible = false
	_root.add_child(_title)
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := KartTheme.badge(KartTheme.CHIP, 0.2, 10, Color(1, 1, 1, 0.0))
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 2
	style.content_margin_bottom = 4
	chip.add_theme_stylebox_override("panel", style)
	chip.position = Vector2(76, 812)
	_title.add_child(chip)
	_title_chip = KartTheme.label("", 38, KartTheme.OUTLINE)
	_title_chip.add_theme_constant_override("outline_size", 0)
	_title_chip.add_theme_constant_override("shadow_offset_y", 0)
	_title_chip.add_theme_constant_override("shadow_offset_x", 0)
	chip.add_child(_title_chip)
	_title_name = KartTheme.label("", 150, KartTheme.INK)
	_title_name.position = Vector2(60, 860)
	_title_name.add_theme_constant_override("outline_size", 30)
	KartTheme.gradient(_title_name, Color(1, 1, 1), Color(0.86, 0.84, 1.0))
	_title.add_child(_title_name)


# --- Racer list and portraits ---

func _build_list() -> void:
	for r in _rows:
		r.queue_free()
	_rows.clear()
	_row_place.clear()
	_row_target.resize(lineup.size())
	_shown_order = []
	for i in lineup.size():
		var racer: Dictionary = lineup[i]
		var row := Control.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.size = Vector2(170, ROW_H)
		row.position = Vector2(40, LIST_TOP + i * ROW_H)
		_gameplay.add_child(row)
		var you := i == KartRaceLogic.RIDER
		var size := PORTRAIT + (10.0 if you else 0.0)
		var pic := portrait_rect(str(racer.id), size, you)
		pic.position = Vector2(44, (ROW_H - size) * 0.5)
		row.add_child(pic)
		var place := KartTheme.label(str(i + 1), 34, KartTheme.CHIP if you else KartTheme.INK, true)
		place.size = Vector2(40, ROW_H)
		place.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		place.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(place)
		_rows.append(row)
		_row_place.append(place)
		_row_target[i] = row.position.y


func _slide_row(id: int) -> void:
	var row := _rows[id]
	if absf(row.position.y - _row_target[id]) < 0.5:
		return
	_kill("row%d" % id)
	var tw := create_tween()
	_tweens["row%d" % id] = tw
	tw.tween_property(row, "position:y", _row_target[id], 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## A round portrait of a racer at `size` px (gold ring for the rider).
func portrait_rect(racer_id: String, size: float, you := false) -> TextureRect:
	var pic := TextureRect.new()
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.texture = portraits.get(racer_id)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.size = Vector2(size, size)
	pic.custom_minimum_size = Vector2(size, size)
	var mat := ShaderMaterial.new()
	mat.shader = _portrait_shader
	var racer := KartRoster.racer(racer_id)
	mat.set_shader_parameter("backdrop", racer.color)
	mat.set_shader_parameter("ring", Color(1.0, 0.82, 0.2) if you else Color(1, 1, 1))
	pic.material = mat
	return pic


## Renders each racer's head once into a small SubViewport (own world, transparent).
func _make_portraits() -> void:
	for racer in lineup:
		var id := str(racer.id)
		if portraits.has(id):
			continue
		var vp := SubViewport.new()
		vp.name = "Portrait_%s" % id
		vp.size = Vector2i(160, 160)
		vp.own_world_3d = true
		vp.transparent_bg = true
		vp.msaa_3d = Viewport.MSAA_4X
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(vp)
		var head := MeshInstance3D.new()
		head.mesh = KartView.head_mesh(racer)
		head.material_override = KartLook.kart_material(true)
		head.rotation = Vector3(0.05, 0.42, 0.0)
		vp.add_child(head)
		var cam := Camera3D.new()
		cam.fov = 34.0
		var tall := 1.0 if id == "rabbit" else 0.0
		cam.position = Vector3(0.0, 0.06 + tall * 0.12, -1.38 - tall * 0.3)
		cam.look_at_from_position(cam.position, Vector3(0.0, 0.05 + tall * 0.14, 0.0), Vector3.UP)
		vp.add_child(cam)
		cam.current = true
		portraits[id] = vp.get_texture()
