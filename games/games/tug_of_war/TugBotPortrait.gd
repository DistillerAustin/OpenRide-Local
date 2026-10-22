class_name TugBotPortrait
extends HBoxContainer
## The intro card's picture: the first bot's head in its body colour (ears or horns, glowing
## eyes, as in TugWorld), with "VS" and its name beside it. Drawn with shapes and redrawn only
## when made, so it costs nothing per frame. Like Dodge Ball's mode badge, but still: the rider
## reads the card, the bot just stares back.

const HEAD := Vector2(120, 120)
const EYES := Color(0.3, 0.9, 1.0)

var body: Color
var horns := false
var _head: Control


func _init(theme: GameTheme, bot_name: String, body_color: Color, has_horns: bool) -> void:
	body = body_color
	horns = has_horns
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 24)
	_head = Control.new()
	_head.custom_minimum_size = HEAD
	_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_head.draw.connect(_draw_head.bind(theme.ink))
	add_child(_head)
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", -6)
	add_child(words)
	words.add_child(theme.label(tr("VS"), HudTheme.SMALL, GameTheme.MUTED, true))
	words.add_child(theme.label(bot_name, HudTheme.MEDIUM, TugStatus.ui_color(body_color), true))


func _draw_head(ink: Color) -> void:
	var c := HEAD * 0.5 + Vector2(0, 8)
	var dark := body.darkened(0.35)
	if horns:
		_head.draw_colored_polygon(PackedVector2Array([c + Vector2(-40, -26), c + Vector2(-52, -58), c + Vector2(-22, -36)]), Color(0.9, 0.86, 0.74))
		_head.draw_colored_polygon(PackedVector2Array([c + Vector2(40, -26), c + Vector2(52, -58), c + Vector2(22, -36)]), Color(0.9, 0.86, 0.74))
	else:
		_head.draw_circle(c + Vector2(-34, -34), 14.0, dark)
		_head.draw_circle(c + Vector2(34, -34), 14.0, dark)
	var box := StyleBoxFlat.new()
	box.bg_color = body
	box.border_color = ink
	box.set_border_width_all(5)
	box.set_corner_radius_all(20)
	box.anti_aliasing = true
	_head.draw_style_box(box, Rect2(c - Vector2(42, 38), Vector2(84, 76)))
	for side in [-1.0, 1.0]:
		_head.draw_circle(c + Vector2(18.0 * side, -6.0), 9.0, ink)
		_head.draw_circle(c + Vector2(18.0 * side, -6.0), 6.0, EYES)
	_head.draw_rect(Rect2(c + Vector2(-20, 16), Vector2(40, 6)), ink)
