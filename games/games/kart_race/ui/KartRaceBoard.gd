class_name KartRaceBoard
extends CanvasLayer
## The results board between races, and the final standings (#43): a violet sunburst over the
## still-running race, a big gradient title that pops in, finishing rows that slide in one by
## one (place, portrait, name, time, points chip; the rider's row in gold), confetti, and a
## chunky pill counting down to the next race. Shown without any touch needed.

const LAYER := 9  ## under the HUD (10), over the 3D view
const ROW_W := 860.0
const ROW_H := 62.0
const CONFETTI := 90

## racer id -> portrait texture (KartHud renders them); rows may carry `racer_id`.
var portraits := {}
var portrait_maker: Callable  ## (racer_id, size, you) -> Control, when set

var _root: Control
var _burst: ColorRect
var _title: Label
var _subtitle: Label
var _rows_box: Control
var _pill: PanelContainer
var _pill_label: Label
var _confetti: Control
var _bits := []  # [pos, vel, rot, spin, color, size]
var _rng := RandomNumberGenerator.new()
var _left := 0.0
var _next_text := ""


func _init() -> void:
	layer = LAYER
	visible = false
	_rng.seed = 3
	_root = Control.new()
	_root.size = Vector2(HudTheme.W, HudTheme.H)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_burst = ColorRect.new()
	_burst.size = _root.size
	_burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load(KartTheme.SHADERS + "sunburst.gdshader")
	mat.set_shader_parameter("centre", Vector2(0.5, 0.18))
	mat.set_shader_parameter("alpha", 0.86)
	_burst.material = mat
	_root.add_child(_burst)
	_title = KartTheme.label("", 140, KartTheme.INK)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.size = Vector2(1400, 190)
	_title.position = Vector2((HudTheme.W - 1400) * 0.5, 120)
	_title.pivot_offset = _title.size * 0.5
	_title.add_theme_constant_override("outline_size", 30)
	KartTheme.gradient(_title, KartTheme.GOLD_TOP, KartTheme.GOLD_BOTTOM)
	_root.add_child(_title)
	_subtitle = KartTheme.label("", 40, KartTheme.CHIP)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.size = Vector2(1400, 60)
	_subtitle.position = Vector2((HudTheme.W - 1400) * 0.5, 300)
	_root.add_child(_subtitle)
	_rows_box = Control.new()
	_rows_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows_box.position = Vector2((HudTheme.W - ROW_W) * 0.5, 398)
	_root.add_child(_rows_box)
	_pill = PanelContainer.new()
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ps := KartTheme.badge(Color(1.0, 0.78, 0.18), 0.0, 44, Color(0.6, 0.3, 0.0))
	ps.content_margin_left = 54
	ps.content_margin_right = 54
	ps.content_margin_top = 10
	ps.content_margin_bottom = 14
	_pill.add_theme_stylebox_override("panel", ps)
	_root.add_child(_pill)
	_pill_label = KartTheme.label("", 46, KartTheme.OUTLINE, true)
	_pill_label.add_theme_constant_override("outline_size", 0)
	_pill_label.add_theme_constant_override("shadow_offset_y", 0)
	_pill_label.add_theme_constant_override("shadow_offset_x", 0)
	_pill.add_child(_pill_label)
	_confetti = Control.new()
	_confetti.size = _root.size
	_confetti.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confetti.draw.connect(_draw_confetti)
	_root.add_child(_confetti)


## rows: [{name, detail}] in order, optionally with racer_id, time, points, you. `subtitle` and
## `next_sec` (a countdown to what follows, with `next_text`) are optional.
func show_board(title: String, rows: Array, subtitle := "", next_sec := 0.0, next_text := "Next race") -> void:
	_title.text = title
	_subtitle.text = subtitle.to_upper()
	for c in _rows_box.get_children():
		c.queue_free()
	for i in rows.size():
		var row := _row(i, rows[i])
		row.position = Vector2(0, i * (ROW_H + 7))
		_rows_box.add_child(row)
		row.modulate.a = 0.0
		var tw := row.create_tween()
		tw.tween_interval(0.25 + i * 0.07)
		tw.tween_property(row, "modulate:a", 1.0, 0.2)
		tw.parallel().tween_property(row, "position:x", 0.0, 0.35).from(220.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_left = next_sec
	_next_text = next_text
	_pill.visible = next_sec > 0.0
	_update_pill()
	_pill.reset_size()
	_pill.position = Vector2((HudTheme.W - _pill.size.x) * 0.5, 398 + rows.size() * (ROW_H + 7) + 14)
	visible = true
	_title.scale = Vector2(0.2, 0.2)
	var tt := _title.create_tween()
	tt.tween_property(_title, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_bits.clear()
	for i in CONFETTI:
		_spawn_bit(true)


func hide_board() -> void:
	visible = false
	_bits.clear()


func _process(delta: float) -> void:
	if not visible:
		return
	if _left > 0.0:
		_left -= delta
		_update_pill()
	for b in _bits:
		b[1].y += 260.0 * delta
		b[1].x += sin(b[2] * 2.0) * 30.0 * delta
		b[0] += b[1] * delta
		b[2] += b[3] * delta
		if b[0].y > HudTheme.H + 30.0:
			b[0] = Vector2(_rng.randf_range(0, HudTheme.W), -20.0)
			b[1] = Vector2(_rng.randf_range(-60, 60), _rng.randf_range(80, 200))
	_confetti.queue_redraw()


func _update_pill() -> void:
	var text := "%s  »  %d" % [_next_text, ceili(maxf(_left, 0.0))]
	if text != _pill_label.text:
		_pill_label.text = text


func _spawn_bit(initial: bool) -> void:
	var colors := [Color(1, 0.84, 0.2), Color(0.3, 0.85, 1.0), Color(1, 0.4, 0.6), Color(0.5, 1, 0.5), Color(0.8, 0.55, 1.0), Color(1, 0.55, 0.2)]
	var pos := Vector2(_rng.randf_range(0, HudTheme.W), _rng.randf_range(-HudTheme.H * 0.8, 0) if initial else -20.0)
	_bits.append([pos, Vector2(_rng.randf_range(-60, 60), _rng.randf_range(80, 220)), _rng.randf() * TAU,
		_rng.randf_range(-6, 6), colors[_rng.randi() % colors.size()], Vector2(_rng.randf_range(10, 18), _rng.randf_range(6, 10))])


func _draw_confetti() -> void:
	for b in _bits:
		var s: Vector2 = b[5]
		var squash := absf(cos(b[2]))
		_confetti.draw_set_transform(b[0], b[2] * 0.5, Vector2(1.0, maxf(0.2, squash)))
		_confetti.draw_rect(Rect2(-s * 0.5, s), b[4])
	_confetti.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _row(i: int, r: Dictionary) -> Control:
	var you := bool(r.get("you", false))
	var row := Panel.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size = Vector2(ROW_W, ROW_H)
	var bg := Color(1.0, 0.78, 0.2, 0.95) if you else Color(0.16, 0.1, 0.36, 0.88)
	var style := KartTheme.badge(bg, 0.12, 16, Color(1, 1, 1, 0.5) if you else Color(0.55, 0.42, 1.0, 0.6))
	row.add_theme_stylebox_override("panel", style)
	var ink := KartTheme.OUTLINE if you else KartTheme.INK
	var place := KartTheme.label(str(i + 1), 50, KartTheme.CHIP if not you else KartTheme.INK)
	place.position = Vector2(14, 0)
	place.size = Vector2(70, ROW_H)
	place.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	place.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(place)
	var suffix := KartTheme.label(KartTheme.ordinal_suffix(i + 1), 26, place.get_theme_color("font_color"))
	suffix.position = Vector2(86, 8)
	row.add_child(suffix)
	var rid := str(r.get("racer_id", ""))
	if rid != "" and portrait_maker.is_valid():
		var pic: Control = portrait_maker.call(rid, 54.0, you)
		pic.position = Vector2(130, (ROW_H - 54) * 0.5)
		row.add_child(pic)
	var name_label := KartTheme.label(str(r.get("name", "")), 38, ink, true)
	if you:
		name_label.add_theme_constant_override("outline_size", 0)
		name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	name_label.position = Vector2(206, 0)
	name_label.size = Vector2(330, ROW_H)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)
	var time_label := KartTheme.label(str(r.get("time", "")), 32, ink, true)
	if you:
		time_label.add_theme_constant_override("outline_size", 0)
		time_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	time_label.position = Vector2(520, 0)
	time_label.size = Vector2(190, ROW_H)
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(time_label)
	var pts := str(r.get("points", r.get("detail", "")))
	if pts != "":
		var chip := PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cs := KartTheme.badge(Color(0.3, 0.85, 0.45) if not you else Color(0.36, 0.22, 0.86), 0.15, 10, Color(1, 1, 1, 0.0))
		cs.content_margin_left = 16
		cs.content_margin_right = 16
		cs.content_margin_top = 0
		cs.content_margin_bottom = 2
		chip.add_theme_stylebox_override("panel", cs)
		chip.position = Vector2(732, 9)
		var cl := KartTheme.label(pts, 32, KartTheme.INK, true)
		cl.add_theme_constant_override("outline_size", 8)
		chip.add_child(cl)
		row.add_child(chip)
	return row
