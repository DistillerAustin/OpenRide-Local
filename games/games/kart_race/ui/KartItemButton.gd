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
const DEBOUNCE_MS := 150
const SPIN_STEP := 0.075  ## seconds per icon at full roulette speed

var item := ""
var roulette := 0.0  ## seconds of roulette left

var _last_press_ms := -100000
var _shown_item := ""
var _shown_icon := ""
var _flash := 0.0
var _spin_t := 0.0
var _spin_i := 0
var _tween: Tween
var _ring: Gradient
var _ring_dim: Gradient
var _draw_kit := KartDraw.new()


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
	_ring_dim = _ring.duplicate()
	for i in _ring_dim.colors.size():
		_ring_dim.set_color(i, _ring.colors[i].lerp(Color(0.4, 0.36, 0.6), 0.75))


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
	# A finger arrives as a touch and as the mouse click Android emulates from it: one use.
	var now := Time.get_ticks_msec()
	if now - _last_press_ms < DEBOUNCE_MS:
		return
	_last_press_ms = now
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
	# Everything but the text is one triangle array (KartDraw): a drop shadow, the rainbow rim,
	# the disc, its gloss, the flash and the icon.
	var d := _draw_kit
	d.disc(c + Vector2(4, 9), r - 2.0, Color(0.05, 0.0, 0.15, 0.4))
	d.disc(c, r - 1.0, KartTheme.OUTLINE)
	d.ring(c, r - 20.0, r - 4.0, Color.WHITE, Color(-1, 0, 0), -PI * 0.5, PI * 1.5, 72, _ring if not empty else _ring_dim)
	d.disc(c, r - 22.0, KartTheme.OUTLINE)
	d.disc(c, r - 26.0, Color(0.2, 0.13, 0.5) if not empty else Color(0.15, 0.1, 0.32, 0.9))
	d.disc(c + Vector2(0, -12), r - 44.0, Color(0.28, 0.2, 0.66) if not empty else Color(0.18, 0.12, 0.38))
	d.ring(c, r - 47.0, r - 33.0, Color(1, 1, 1, 0.16), Color(-1, 0, 0), PI * 1.12, PI * 1.6)
	if _flash > 0.0:
		d.disc(c, (r - 26.0) * (1.0 + 0.1 * (1.0 - _flash)), Color(1.0, 0.95, 0.7, 0.45 * _flash))
	var known := true
	if not empty:
		known = KartItemIcons.draw(d, _shown_icon, c + Vector2(0, -8), r * 0.5)
	var chip := Rect2(c + Vector2(-58, r - 62), Vector2(116, 52))
	if not empty and roulette <= 0.0:
		d.rect(chip.grow(5), KartTheme.OUTLINE, 31.0)
		d.rect(chip, KartTheme.CHIP, 26.0)
	d.flush(self)
	if empty:
		_label("ITEM", c + Vector2(0, 14), 40, Color(1, 1, 1, 0.35))
		return
	if not known:
		_label("?", c + Vector2(0, 22), 90, Color.WHITE)
	if roulette <= 0.0:
		_label("TAP", chip.get_center() + Vector2(0, 15), 40, KartTheme.OUTLINE, false)


func _label(text: String, centre: Vector2, font_size: int, color: Color, outline := true) -> void:
	var font := KartTheme.display(true)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at := centre - Vector2(w * 0.5, 0)
	if outline:
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 8, Color(KartTheme.OUTLINE, color.a))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
