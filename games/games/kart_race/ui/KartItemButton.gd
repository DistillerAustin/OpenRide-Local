class_name KartItemButton
extends Button
## The item button (#43): a big round touch target in the top-right corner (at least 240 px,
## the bike's touch rule) that uses the held item. Only the circle counts as the button, so a
## touch in its square's corners doesn't fire it. It fires on the press, not the release: on the
## bike a tap should act at once.
##
## It shows the held item's icon on a deep violet disc inside a rainbow rim, with a "TAP" chip.
## While an item is being drawn (`roulette_time` > 0) the icons spin past, slowing down, then the
## new item lands with a pop and a flash. Empty, it dims to a faint slot.

signal used

const SIZE := 260.0
const SPIN_STEP := 0.075  ## seconds per icon at full roulette speed

var item := ""
var roulette := 0.0  ## seconds of roulette left

var _shown_item := ""
var _shown_icon := ""
var _flash := 0.0
var _spin_t := 0.0
var _spin_i := 0
var _tween: Tween
var _ring: Gradient


func _init() -> void:
	name = "ItemButton"
	focus_mode = Control.FOCUS_NONE
	action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	pivot_offset = size * 0.5
	for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	pressed.connect(_on_pressed)
	_ring = Gradient.new()
	_ring.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
	_ring.colors = PackedColorArray([Color(1.0, 0.35, 0.45), Color(1.0, 0.7, 0.2), Color(0.95, 0.95, 0.3),
		Color(0.3, 0.85, 0.55), Color(0.3, 0.6, 1.0), Color(1.0, 0.35, 0.45)])


## Only the disc is the button.
func _has_point(point: Vector2) -> bool:
	return point.distance_to(size * 0.5) <= SIZE * 0.5


## Called every frame with the rider's KartState fields; redraws only when something shows.
func set_item(held: String, roulette_left: float, delta: float) -> void:
	var was_spinning := roulette > 0.0
	item = held
	roulette = roulette_left
	if roulette > 0.0:
		# Slow down over the roulette's last half second.
		_spin_t += delta
		var step := SPIN_STEP * (1.0 + 3.0 * clampf(1.0 - roulette / 0.5, 0.0, 1.0))
		if _spin_t >= step:
			_spin_t = 0.0
			_spin_i = (_spin_i + 1) % KartItemIcons.KINDS.size()
			_set_icon(KartItemIcons.KINDS[_spin_i])
		return
	if held != _shown_item or was_spinning:
		var landed := held != "" and (was_spinning or _shown_item == "")
		_shown_item = held
		_set_icon(held)
		if landed:
			_land()
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 2.5)
		queue_redraw()


func _set_icon(icon: String) -> void:
	if icon != _shown_icon:
		_shown_icon = icon
		queue_redraw()


func _land() -> void:
	_flash = 1.0
	_bounce(1.18, 0.45)


func _on_pressed() -> void:
	used.emit()
	_bounce(0.86, 0.3)


func _bounce(from: float, seconds: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	pivot_offset = size * 0.5
	scale = Vector2(from, from)
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var c := size * 0.5
	var r := SIZE * 0.5
	var empty := _shown_icon == "" and roulette <= 0.0
	# Soft drop shadow, the rainbow rim, then the disc.
	draw_circle(c + Vector2(4, 9), r - 2.0, Color(0.05, 0.0, 0.15, 0.4))
	draw_circle(c, r - 1.0, KartTheme.OUTLINE)
	var segments := 48
	for i in segments:
		var a0 := TAU * i / segments - PI * 0.5
		var a1 := TAU * (i + 1) / segments - PI * 0.5
		var col := _ring.sample(float(i) / segments)
		if empty:
			col = col.lerp(Color(0.4, 0.36, 0.6), 0.75)
		draw_arc(c, r - 12.0, a0, a1 + 0.01, 3, col, 16.0, true)
	draw_circle(c, r - 22.0, KartTheme.OUTLINE)
	draw_circle(c, r - 26.0, Color(0.2, 0.13, 0.5) if not empty else Color(0.15, 0.1, 0.32, 0.9))
	draw_circle(c + Vector2(0, -12), r - 44.0, Color(0.28, 0.2, 0.66) if not empty else Color(0.18, 0.12, 0.38))
	# Gloss across the top of the disc.
	draw_arc(c, r - 40.0, PI * 1.12, PI * 1.6, 18, Color(1, 1, 1, 0.16), 14.0, true)
	if _flash > 0.0:
		draw_circle(c, (r - 26.0) * (1.0 + 0.1 * (1.0 - _flash)), Color(1.0, 0.95, 0.7, 0.45 * _flash))
	if empty:
		_label("ITEM", c + Vector2(0, 14), 40, Color(1, 1, 1, 0.35))
		return
	KartItemIcons.draw(self, _shown_icon, c + Vector2(0, -8), r * 0.5)
	if roulette <= 0.0:
		# The "TAP" chip on the bottom of the rim.
		var chip := Rect2(c + Vector2(-58, r - 62), Vector2(116, 52))
		KartItemIcons.round_rect(self, chip.grow(5), 31.0, KartTheme.OUTLINE)
		KartItemIcons.round_rect(self, chip, 26.0, KartTheme.CHIP)
		_label("TAP", chip.get_center() + Vector2(0, 15), 40, KartTheme.OUTLINE, false)


func _label(text: String, centre: Vector2, font_size: int, color: Color, outline := true) -> void:
	var font := KartTheme.display(true)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at := centre - Vector2(w * 0.5, 0)
	if outline:
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 8, Color(KartTheme.OUTLINE, color.a))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
