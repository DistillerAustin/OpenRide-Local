class_name CadenceStatus
extends PanelContainer
## Cadence Karaoke's HUD widget, in the HUD's top-centre slot. The hero is the target rpm: the
## one number the rider matches (framework/ui/UI_STYLE.md §5). Beside it, two caption rows:
##
##   120   rpm target   [▶ 125 in 12 s]
##         In band 78%  ×1.5  [▼ SLOW DOWN]
##
## Within 850 x 120 px with the longest texts (hud_layout_test). Labels only change with their
## values, so the HUD isn't re-laid out every frame; motion is scale and modulate only.

const ARROW_UP := 0
const ARROW_DOWN := 1
const ARROW_RIGHT := 2

## The alert kinds `set_alert` takes.
const ALERT_NONE := ""
const ALERT_SLOW := "slow"  ## over the target: SLOW DOWN ▼
const ALERT_FAST := "fast"  ## under it: SPEED UP ▲
const ALERT_PEDAL := "pedal"  ## stopped: PEDAL ▲
const ALERT_EASE := "ease"  ## over the power cap: EASE OFF, red, breathing
const ALERT_TEXTS := {"slow": "SLOW DOWN", "fast": "SPEED UP", "pedal": "PEDAL", "ease": "EASE OFF"}

var target: Label  ## the hero
var caption: Label
var next_chip: PanelContainer
var next_label: Label
var info: Label
var streak: Label
var alert: PanelContainer
var alert_label: Label

var _look: GameTheme
var _next_arrow: _Arrow
var _alert_arrow: _Arrow
var _texts := {}
var _alert := ALERT_NONE
var _target_rpm := -1
var _pct := 0


func _init(look: GameTheme = null) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := _box(HBoxContainer.new(), self, 18)
	# The hero, with the face's empty descent (digits have none) taken off so it fits the budget.
	var hero_box := MarginContainer.new()
	hero_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_box.add_theme_constant_override("margin_top", -4)
	hero_box.add_theme_constant_override("margin_bottom", -18)
	row.add_child(hero_box)
	target = Label.new()
	target.name = "Target"
	target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	target.custom_minimum_size = Vector2(168, 0)  # "120" never shifts its neighbours
	hero_box.add_child(target)
	var rows := _box(VBoxContainer.new(), row, 4)
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	var top := _box(HBoxContainer.new(), rows, 12)
	caption = _label("rpm target", top)
	next_chip = _chip(top)
	_next_arrow = _Arrow.new(ARROW_RIGHT)
	next_chip.get_child(0).add_child(_next_arrow)
	next_label = _label("", next_chip.get_child(0))
	next_chip.visible = false
	var bottom := _box(HBoxContainer.new(), rows, 12)
	info = _label("", bottom)
	info.custom_minimum_size = Vector2(196, 0)  # "In band 100%"
	streak = _label("", bottom)
	streak.custom_minimum_size = Vector2(84, 0)  # "×1.75"
	streak.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert = _chip(bottom)
	_alert_arrow = _Arrow.new(ARROW_DOWN)
	alert.get_child(0).add_child(_alert_arrow)
	alert_label = _label("", alert.get_child(0))
	alert.visible = false
	apply_theme(look if look else GameTheme.new(Color(1.0, 0.45, 0.8), Color("12052a"), 0.25, true))


## Restyles the widget in `look` (the segment's neon). Keeps the texts and the state.
func apply_theme(look: GameTheme) -> void:
	_look = look
	var style := look.panel_style()
	style.content_margin_top = 8
	style.content_margin_bottom = 10
	add_theme_stylebox_override("panel", style)
	look.style_label(target, HudTheme.BIG, GameTheme.INK, true)
	look.set_gradient(target)
	look.style_label(caption, HudTheme.SMALL, GameTheme.MUTED, true)
	look.style_label(info, HudTheme.SMALL, GameTheme.MUTED, true)
	look.style_label(streak, HudTheme.SMALL, GameTheme.TARGET, true)
	look.style_label(next_label, HudTheme.SMALL, GameTheme.INK, true)
	look.style_label(alert_label, HudTheme.SMALL, GameTheme.INK)
	next_chip.add_theme_stylebox_override("panel", _chip_style(look.accent.darkened(0.2)))
	_next_arrow.color = GameTheme.INK
	_style_alert()


## The hero: pops when the target changes (a pace step, the circuit's profile), not on the first.
func set_target(rpm: int) -> void:
	if rpm == _target_rpm:
		return
	var first := _target_rpm < 0
	_target_rpm = rpm
	target.text = str(rpm)
	if not first:
		GameTheme.pop(target, 1.3)


## The pending change ("125 in 12 s"), or "" for none.
func set_next(text: String) -> void:
	if _changed("next", text):
		next_label.text = text
		if next_chip.visible != (text != ""):
			if text != "":
				GameTheme.fade(next_chip, true)
				GameTheme.pop(next_chip, 1.15)
			else:
				next_chip.visible = false


func set_info(pct_in_band: int, multiplier: float) -> void:
	_pct = pct_in_band
	if _changed("info", str(pct_in_band)):
		info.text = "In band %d%%" % pct_in_band
	if _changed("streak", str(multiplier)):
		if multiplier >= CadenceLogic.STREAK_MULT_MAX:
			streak.text = "×%d!" % roundi(multiplier)
		else:
			streak.text = "×%s" % String.num(multiplier, 2)


## The streak stepped up: pop the multiplier, or slam it when it maxes out.
func streak_up(multiplier: float) -> void:
	set_info(_pct, multiplier)
	if multiplier >= CadenceLogic.STREAK_MULT_MAX:
		GameTheme.slam(streak, 2.0)
	else:
		GameTheme.pop(streak, 1.35)


## The directional alert (ALERT_*): a WARN badge with its arrow, or EASE OFF in red, breathing.
func set_alert(kind: String) -> void:
	if kind == _alert:
		return
	var was_ease := _alert == ALERT_EASE
	_alert = kind
	if kind == ALERT_NONE:
		GameTheme.pulse(alert, false)
		alert.visible = false
		return
	alert_label.text = ALERT_TEXTS[kind]
	_style_alert()
	if not alert.visible:
		alert.visible = true
		alert.modulate = Color.WHITE
		GameTheme.pop(alert, 1.15)
	if kind == ALERT_EASE:
		GameTheme.pulse(alert, true)
	elif was_ease:
		GameTheme.pulse(alert, false)


func alert_kind() -> String:
	return _alert


## On each beat: the alert's badge brightens for a moment (modulate only).
func beat() -> void:
	if alert.visible:
		GameTheme.flash(alert, 1.35, 0.22)


func _style_alert() -> void:
	var ease_off := _alert == ALERT_EASE
	alert.add_theme_stylebox_override("panel", _chip_style(GameTheme.BAD if ease_off else GameTheme.WARN.darkened(0.15)))
	_alert_arrow.visible = not ease_off
	_alert_arrow.set_direction(ARROW_UP if _alert in [ALERT_FAST, ALERT_PEDAL] else ARROW_DOWN)
	_alert_arrow.color = GameTheme.INK


## A slim badge: the theme's lean, a white edge, little vertical padding (two rows fit 120 px).
func _chip_style(fill: Color) -> StyleBoxFlat:
	var s := _look.badge_style(fill)
	s.content_margin_top = 1
	s.content_margin_bottom = 3
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.border_width_bottom = 4
	return s


func _chip(parent: Control) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(chip)
	var box := _box(HBoxContainer.new(), chip, 8)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	return chip


func _label(text: String, parent: Control) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


func _box(box: BoxContainer, parent: Control, separation: int) -> BoxContainer:
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", separation)
	parent.add_child(box)
	return box


func _changed(key: String, value: String) -> bool:
	if _texts.get(key) == value:
		return false
	_texts[key] = value
	return true


## A triangle drawn as a shape (the display face has no arrow glyphs, and a fallback face would
## split the HUD's batch). Redraws only when its direction or colour changes.
class _Arrow:
	extends Control

	var direction := ARROW_DOWN
	var color := Color.WHITE:
		set(value):
			if value != color:
				color = value
				queue_redraw()

	func _init(dir: int) -> void:
		direction = dir
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(26, 26)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func set_direction(dir: int) -> void:
		if dir != direction:
			direction = dir
			queue_redraw()

	func _draw() -> void:
		var s := size
		var points: PackedVector2Array
		match direction:
			ARROW_UP:
				points = [Vector2(s.x * 0.5, 0), Vector2(s.x, s.y), Vector2(0, s.y)]
			ARROW_RIGHT:
				points = [Vector2(0, 0), Vector2(s.x, s.y * 0.5), Vector2(0, s.y)]
			_:
				points = [Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x * 0.5, s.y)]
		draw_colored_polygon(points, color)
