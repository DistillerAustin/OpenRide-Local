class_name KartRaceBoard
extends CanvasLayer
## The flow screens between and after races (#43), shown with no touch needed and timed by the
## game (a pill counts down to what comes next):
##
## - `show_board`: the results board. A violet sunburst over the still-running race, a big
##   gradient title that pops in, then the finishing order sliding in row by row: place,
##   portrait, name, time gap, the race's points chip and the Grand Prix total. The rider's row
##   is gold. Confetti when the rider made the podium.
## - `show_podium`: the Grand Prix podium. The top three on gold, silver and bronze blocks that
##   rise in turn (third, second, then the champion with a burst), big portraits, names and
##   points, and the full standings beside it, under a shower of confetti.
##
## The title sits left of the framework HUD's clock and Pause | End (top right), so nothing that
## stays touchable is ever covered.
##
## The tablet's draw-call budget: the title, the subtitle, the pill, every row and every podium
## block are baked (KartBaked: rendered into a texture when they change, one draw call each on
## screen); the slide, pop and rise tweens move the baked rects. `tests/measure_kart_board.gd`
## measures it.

const LAYER := 9  ## under the HUD (10), over the 3D view
const W := 1920.0
const H := 1080.0
const TITLE_CENTRE := 650.0  ## clear of the framework's clock cluster at the top right
const ROW_W := 980.0
const ROW_H := 62.0
const ROWS_TOP := 360.0
const MINI_W := 640.0
const MINI_H := 58.0
const CONFETTI := 110
const PODIUM_COLORS := [Color(1.0, 0.78, 0.2), Color(0.8, 0.84, 0.92), Color(0.86, 0.52, 0.26)]
const SHADOW_ROOM := Vector2(16, 16)  ## a baked panel's drop shadow, right and below
const PILL_BOX := Vector2(760, 90)  ## the pill's fixed bake, the pill centred in it
const PODIUM_TOP := 40.0  ## room above a podium block's node for the champion's crown
const PODIUM_SIDE := 30.0  ## the name runs this far past the block either side

## racer id -> portrait texture (KartHud renders them); rows may carry `racer_id`.
var portraits := {}
var portrait_maker: Callable  ## (racer_id, size, you) -> Control, when set
## What's showing: "", "results" or "podium".
var mode := ""

var _root: Control
var _burst: ColorRect
var _title: Label
## The board's bakes take turns rendering (KartBakeQueue).
var bakes := KartBakeQueue.new()
var _title_view: KartBaked
var _subtitle: Label
var _content: Control
var _pill: PanelContainer
var _pill_box: Control
var _pill_view: KartBaked
var _pill_label: Label
var _confetti: Control
var _bits := []  # [pos, vel, rot, spin, color, size]
var _rng := RandomNumberGenerator.new()
var _left := 0.0
var _next_text := ""
var _rain := false


func _init() -> void:
	layer = LAYER
	visible = false
	_rng.seed = 3
	_root = Control.new()
	_root.size = Vector2(W, H)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_burst = ColorRect.new()
	_burst.size = _root.size
	_burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load(KartTheme.SHADERS + "sunburst.gdshader")
	mat.set_shader_parameter("centre", Vector2(TITLE_CENTRE / W, 0.16))
	mat.set_shader_parameter("alpha", 0.86)
	_burst.material = mat
	_root.add_child(_burst)
	_title = KartTheme.label("", 130, KartTheme.INK)
	_title.name = "Title"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.size = Vector2(1160, 200)
	_title.position = Vector2(TITLE_CENTRE - 580, 50)
	_title.pivot_offset = _title.size * 0.5
	_title.add_theme_constant_override("outline_size", 30)
	KartTheme.gradient(_title, KartTheme.GOLD_TOP, KartTheme.GOLD_BOTTOM)
	_root.add_child(_title)
	_title_view = _bake(_title, _root)
	_subtitle = KartTheme.label("", 36, KartTheme.CHIP)
	_subtitle.name = "Subtitle"
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.size = Vector2(1160, 56)
	_subtitle.position = Vector2(TITLE_CENTRE - 580, 248)
	_root.add_child(_subtitle)
	_bake(_subtitle, _root)
	_content = Control.new()
	_content.name = "Content"
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.size = _root.size
	_root.add_child(_content)
	_pill = PanelContainer.new()
	_pill.name = "Pill"
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ps := KartTheme.badge(Color(1.0, 0.78, 0.18), 0.0, 44, Color(0.6, 0.3, 0.0))
	ps.content_margin_left = 54
	ps.content_margin_right = 54
	ps.content_margin_top = 8
	ps.content_margin_bottom = 12
	_pill.add_theme_stylebox_override("panel", ps)
	_pill_box = Control.new()
	_pill_box.name = "PillBox"
	_pill_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill_box.size = PILL_BOX
	_pill_box.add_child(_pill)
	_root.add_child(_pill_box)
	_pill_label = KartTheme.label("", 44, KartTheme.OUTLINE, true)
	_pill_label.add_theme_constant_override("outline_size", 0)
	_pill_label.add_theme_constant_override("shadow_offset_y", 0)
	_pill_label.add_theme_constant_override("shadow_offset_x", 0)
	_pill.add_child(_pill_label)
	_pill.resized.connect(_centre_pill)
	_pill_view = _bake(_pill_box, _root)
	_confetti = Control.new()
	_confetti.size = _root.size
	_confetti.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confetti.draw.connect(_draw_confetti)
	_root.add_child(_confetti)


## The results board. rows: [{name, detail}] in finishing order, optionally with racer_id, time,
## points (or detail: the race's points), total (the GP total) and you. `subtitle` and `next_sec`
## (a countdown to what follows, with `next_text`) are optional.
func show_board(title: String, rows: Array, subtitle := "", next_sec := 0.0, next_text := "Next race") -> void:
	mode = "results"
	_open(title, subtitle, next_sec, next_text)
	for i in rows.size():
		var row := _row(i, rows[i])
		row.position = Vector2((W - ROW_W) * 0.5, ROWS_TOP + i * (ROW_H + 7))
		_content.add_child(row)
		_slide_in(_bake(row, _content, row.size + SHADOW_ROOM), 0.25 + i * 0.07, 220.0)
	_place_pill(Vector2(W * 0.5, ROWS_TOP + rows.size() * (ROW_H + 7) + 16))
	var rider_place := -1
	for i in rows.size():
		if bool(rows[i].get("you", false)):
			rider_place = i
	_start_confetti(rider_place >= 0 and rider_place < 3)


## The Grand Prix podium and the final standings. rows: standings order, as `show_board`'s
## (`time` may carry the wins), with `points` the GP total.
func show_podium(title: String, rows: Array, subtitle := "", next_sec := 0.0, next_text := "Ride summary") -> void:
	mode = "podium"
	_open(title, subtitle, next_sec, next_text)
	# The blocks: second on the left, the champion in the middle, third on the right.
	var slots := [[1, 300.0, 215.0], [0, 640.0, 285.0], [2, 980.0, 165.0]]  # [place index, centre x, block height]
	var order := [2, 1, 0]  # third rises first, the champion last
	for o in order.size():
		var slot: Array = slots[[2, 0, 1][o]]
		var place: int = slot[0]
		if place >= rows.size():
			continue
		var block := _podium_block(place, rows[place], slot[1], slot[2])
		_content.add_child(block)
		var node := _bake(block, _content, block.size + SHADOW_ROOM)
		var delay := 0.35 + o * 0.45
		var final_y := node.position.y
		node.position.y = H + 40.0
		var tw := node.create_tween()
		tw.tween_interval(delay)
		tw.tween_property(node, "position:y", final_y, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if place == 0:
			tw.tween_callback(func(): _burst_confetti(Vector2(slot[1], final_y + KartBaked.PAD + PODIUM_TOP + 40.0)))
	# The full standings beside the podium.
	for i in rows.size():
		var row := _mini_row(i, rows[i])
		row.position = Vector2(W - 40.0 - MINI_W, ROWS_TOP + i * (MINI_H + 6))
		_content.add_child(row)
		_slide_in(_bake(row, _content, row.size + SHADOW_ROOM), 0.2 + i * 0.06, 180.0)
	_place_pill(Vector2(640.0, 938.0))
	_start_confetti(true)


func hide_board() -> void:
	visible = false
	mode = ""
	_bits.clear()


## Seconds until what comes next (the pill's countdown).
func seconds_left() -> float:
	return _left


func _open(title: String, subtitle: String, next_sec: float, next_text: String) -> void:
	_title.text = title
	# Long titles shrink to stay clear of the framework's clock.
	var font_size := 130
	while font_size > 70 and KartTheme.display().get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > _title.size.x - 60.0:
		font_size -= 8
	_title.add_theme_font_size_override("font_size", font_size)
	(_title.material as ShaderMaterial).set_shader_parameter("span", Vector2(100.0 - font_size * 0.38, 100.0 + font_size * 0.42))
	_subtitle.text = subtitle.to_upper()
	for c in _content.get_children():
		c.queue_free()
	_left = next_sec
	_next_text = next_text
	_pill_box.visible = next_sec > 0.0
	_update_pill()
	visible = true
	_title_view.scale = Vector2(0.2, 0.2)
	var tt := _title_view.create_tween()
	tt.tween_property(_title_view, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Bakes `w` in turn with the board's others: one render a frame, so a board's first frame
## never draws all its widgets at once (the 205-call spike on the tablet).
func _bake(w: Control, parent: Control, bake_size := Vector2.ZERO) -> KartBaked:
	var b := KartBaked.new(w, parent, bake_size)
	b.queue = bakes
	return b


func _place_pill(centre: Vector2) -> void:
	_centre_pill()
	_pill_view.position = centre - Vector2(PILL_BOX.x * 0.5 + KartBaked.PAD, KartBaked.PAD)


## The pill sits centred in its fixed bake whatever its text's width.
func _centre_pill() -> void:
	_pill.reset_size()
	_pill.position = Vector2((PILL_BOX.x - _pill.size.x) * 0.5, 0.0)


func _slide_in(row: Control, delay: float, from_dx: float) -> void:
	row.modulate.a = 0.0
	var x := row.position.x
	var tw := row.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(row, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(row, "position:x", x, 0.35).from(x + from_dx).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if not visible:
		return
	if _left > 0.0:
		_left -= delta
		_update_pill()
	for b in _bits:
		b[1].y += 260.0 * delta
		b[1].x += sin(b[2] * 2.0) * 30.0 * delta
		b[1] *= 1.0 - 0.6 * delta
		b[0] += b[1] * delta
		b[2] += b[3] * delta
		if b[0].y > H + 30.0 and _rain:
			b[0] = Vector2(_rng.randf_range(0, W), -20.0)
			b[1] = Vector2(_rng.randf_range(-60, 60), _rng.randf_range(80, 200))
	if not _bits.is_empty():
		_confetti.queue_redraw()


func _update_pill() -> void:
	var text := "%s  »  %d" % [_next_text, ceili(maxf(_left, 0.0))]
	if text != _pill_label.text:
		_pill_label.text = text


# --- Confetti ---

func _start_confetti(rain: bool) -> void:
	_bits.clear()
	_rain = rain
	if not rain:
		_confetti.queue_redraw()
		return
	for i in CONFETTI:
		_spawn_bit(Vector2(_rng.randf_range(0, W), _rng.randf_range(-H * 0.8, 0)), Vector2(_rng.randf_range(-60, 60), _rng.randf_range(80, 220)))


## A burst from a point (the champion's block landing).
func _burst_confetti(at: Vector2) -> void:
	for i in 70:
		var a := _rng.randf_range(-PI * 0.95, -PI * 0.05)
		_spawn_bit(at, Vector2(cos(a), sin(a)) * _rng.randf_range(300, 900))


func _spawn_bit(pos: Vector2, vel: Vector2) -> void:
	var colors := [Color(1, 0.84, 0.2), Color(0.3, 0.85, 1.0), Color(1, 0.4, 0.6), Color(0.5, 1, 0.5), Color(0.8, 0.55, 1.0), Color(1, 0.55, 0.2)]
	_bits.append([pos, vel, _rng.randf() * TAU, _rng.randf_range(-6, 6), colors[_rng.randi() % colors.size()],
		Vector2(_rng.randf_range(12, 20), _rng.randf_range(7, 11))])


func _draw_confetti() -> void:
	for b in _bits:
		var s: Vector2 = b[5]
		var squash := absf(cos(b[2]))
		_confetti.draw_set_transform(b[0], b[2] * 0.5, Vector2(1.0, maxf(0.2, squash)))
		_confetti.draw_rect(Rect2(-s * 0.5, s), b[4])
	_confetti.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- Rows ---

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
	suffix.position = Vector2(86, 6)
	row.add_child(suffix)
	var rid := str(r.get("racer_id", ""))
	if rid != "" and portrait_maker.is_valid():
		var pic: Control = portrait_maker.call(rid, 54.0, you)
		pic.position = Vector2(130, (ROW_H - 54) * 0.5)
		row.add_child(pic)
	row.add_child(_text(str(r.get("name", "")), 38, ink, you, Rect2(206, 0, 330, ROW_H), HORIZONTAL_ALIGNMENT_LEFT))
	row.add_child(_text(str(r.get("time", "")), 32, ink, you, Rect2(520, 0, 190, ROW_H), HORIZONTAL_ALIGNMENT_RIGHT))
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
	if r.has("total"):
		row.add_child(_text(str(r.total), 36, ink, you, Rect2(830, 0, 130, ROW_H), HORIZONTAL_ALIGNMENT_RIGHT))
	return row


func _text(text: String, font_size: int, ink: Color, you: bool, rect: Rect2, align: HorizontalAlignment) -> Label:
	var l := KartTheme.label(text, font_size, ink, true)
	if you:
		l.add_theme_constant_override("outline_size", 0)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	l.position = rect.position
	l.size = rect.size
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.horizontal_alignment = align
	l.clip_text = true
	return l


func _mini_row(i: int, r: Dictionary) -> Control:
	var you := bool(r.get("you", false))
	var row := Panel.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size = Vector2(MINI_W, MINI_H)
	var bg := Color(1.0, 0.78, 0.2, 0.95) if you else Color(0.16, 0.1, 0.36, 0.86)
	row.add_theme_stylebox_override("panel", KartTheme.badge(bg, 0.12, 14, Color(1, 1, 1, 0.5) if you else Color(0.55, 0.42, 1.0, 0.5)))
	var ink := KartTheme.OUTLINE if you else KartTheme.INK
	var place := KartTheme.label(str(i + 1), 42, PODIUM_COLORS[i] if i < 3 and not you else (KartTheme.INK if you else KartTheme.CHIP))
	place.position = Vector2(8, 0)
	place.size = Vector2(54, MINI_H)
	place.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	place.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(place)
	var rid := str(r.get("racer_id", ""))
	if rid != "" and portrait_maker.is_valid():
		var pic: Control = portrait_maker.call(rid, 48.0, you)
		pic.position = Vector2(76, (MINI_H - 48) * 0.5)
		row.add_child(pic)
	row.add_child(_text(str(r.get("name", "")), 34, ink, you, Rect2(136, 0, 300, MINI_H), HORIZONTAL_ALIGNMENT_LEFT))
	row.add_child(_text(str(r.get("points", r.get("detail", ""))), 34, ink, you, Rect2(430, 0, 190, MINI_H), HORIZONTAL_ALIGNMENT_RIGHT))
	return row


## One podium step: the portrait on top, the name, the block with its number and the points (in
## a holder with room for the crown and the name, so the bake doesn't clip them).
func _podium_block(place: int, r: Dictionary, centre_x: float, height: float) -> Control:
	var you := bool(r.get("you", false))
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var node := Control.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var block_w := 300.0
	var top := 900.0 - height
	holder.position = Vector2(centre_x - block_w * 0.5 - PODIUM_SIDE, top - 250.0 - PODIUM_TOP)
	holder.size = Vector2(block_w + PODIUM_SIDE * 2.0, height + 250.0 + PODIUM_TOP)
	node.position = Vector2(PODIUM_SIDE, PODIUM_TOP)
	node.size = Vector2(block_w, height + 250.0)
	holder.add_child(node)
	var color: Color = PODIUM_COLORS[place]
	var block := Panel.new()
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bs := StyleBoxFlat.new()
	bs.bg_color = color
	bs.set_corner_radius_all(18)
	bs.corner_radius_bottom_left = 0
	bs.corner_radius_bottom_right = 0
	bs.border_color = color.lightened(0.45)
	bs.border_width_top = 10
	bs.shadow_color = Color(0.05, 0.0, 0.15, 0.5)
	bs.shadow_size = 14
	bs.anti_aliasing = true
	block.add_theme_stylebox_override("panel", bs)
	block.position = Vector2(0, 250)
	block.size = Vector2(block_w, height)
	node.add_child(block)
	var num := KartTheme.label(str(place + 1), mini(150, int(height * 0.56)), KartTheme.INK)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.size = Vector2(block_w, height - 58)
	num.position = Vector2(0, 254)
	num.add_theme_constant_override("outline_size", 26)
	KartTheme.gradient(num, Color(1, 1, 1), color.lightened(0.3))
	node.add_child(num)
	var pts := KartTheme.label(str(r.get("points", "")), 36, KartTheme.OUTLINE, true)
	pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pts.size = Vector2(block_w, 50)
	pts.position = Vector2(0, 250 + height - 62)
	pts.add_theme_constant_override("outline_size", 0)
	pts.add_theme_constant_override("shadow_offset_y", 0)
	node.add_child(pts)
	var d := 156.0 if place == 0 else 136.0
	var rid := str(r.get("racer_id", ""))
	if rid != "" and portrait_maker.is_valid():
		var pic: Control = portrait_maker.call(rid, d, you)
		pic.position = Vector2((block_w - d) * 0.5, 186 - d)
		node.add_child(pic)
	var name_label := KartTheme.label(str(r.get("name", "")), 40 if place == 0 else 36, KartTheme.CHIP if you else KartTheme.INK, true)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.size = Vector2(block_w + 60, 56)
	name_label.position = Vector2(-30, 190)
	name_label.clip_text = true
	node.add_child(name_label)
	if place == 0:
		# A little crown over the champion.
		var crown := Control.new()
		crown.mouse_filter = Control.MOUSE_FILTER_IGNORE
		crown.size = Vector2(120, 70)
		crown.position = Vector2((block_w - 120) * 0.5, 186 - d - 62)
		crown.draw.connect(func():
			var pts2 := PackedVector2Array([Vector2(8, 66), Vector2(4, 14), Vector2(34, 40), Vector2(60, 4), Vector2(86, 40), Vector2(116, 14), Vector2(112, 66)])
			var outline := pts2.duplicate()
			outline.append(pts2[0])
			crown.draw_colored_polygon(pts2, Color(1.0, 0.82, 0.2))
			crown.draw_polyline(outline, KartTheme.OUTLINE, 6.0, true)
			for p in [Vector2(4, 14), Vector2(60, 4), Vector2(116, 14)]:
				crown.draw_circle(p, 8.0, KartTheme.OUTLINE)
				crown.draw_circle(p, 5.0, Color(1.0, 0.4, 0.5)))
		node.add_child(crown)
	return holder
