class_name KartItemButton
extends Button
## The item button (#43): a big round touch target in the bottom-right corner (a 260 px disc,
## the bike's touch rule is 240) that uses the held item, with the drift meter wrapped round its
## upper-left edge. It fires on the press, not the release: on the bike a tap should act at once.
##
## Safety: it sits at the far end of the screen from the framework's End button (top right), and
## its hit area is a circle 1.25× the drawn disc, so a rushed tap on a moving bike lands on the
## item, never on End (`kart_presentation_test` keeps them at least 120 px apart).
##
## The face (a child, so its pulse is a transform tween, never a redraw) shows the held item's
## icon on a deep violet disc inside a rainbow rim, with a "TAP" chip. While an item is being
## drawn (`roulette_time` > 0) the icons spin past, slowing down, then the new item lands with a
## pop and a flash. Empty, it dims to a faint slot. An item held unused for IDLE_SEC starts a slow
## pulse with a gold rim glow: the call to action the review asked for (items sat unused 10 s+).
##
## The drift meter (drawn by this node, behind the face) is a three-segment arc in the spark
## tiers' blue, orange and violet, each sized by the charge its tier needs, on a dark backing
## band so it reads over any scenery; it fills with the rider's drift charge. At its end, the knob
## glyph: a little resistance dial that lights up while turning the resistance up is speeding the
## charge (KartState.knob_boosting). Dim at rest, bright while drifting, each new tier flashes
## its segment. It redraws only on a charge step (24 a full charge), a tier, the knob or the fade.
## No text: the arc explains itself once it lights, and nothing is drawn under 34 px.

signal used

const SIZE := 260.0  ## the drawn disc's diameter
const HIT_SCALE := 1.25  ## the hit circle's radius, as a share of the disc's
const HIT_SIZE := SIZE * HIT_SCALE  ## the control's square: the hit circle fits it exactly
const DEBOUNCE_MS := 150
const SPIN_STEP := 0.075  ## seconds per icon at full roulette speed
const IDLE_SEC := 2.0  ## an item held this long unused starts the pulse
const PULSE_SCALE := 1.06
## The drift arc: from lower left, over the top, round the disc (radians, 0 = +x, y down).
const ARC_FROM := PI * 0.83
const ARC_TO := PI * 1.6
const ARC_IN := 147.0  ## radii of the coloured band ...
const ARC_OUT := 175.0
const ARC_BACK := 6.0  ## ... and how far the dark backing band reaches past it
const KNOB_AT := PI * 1.7  ## the knob glyph, just past the arc's end
const KNOB_R := 161.0
const CHARGE_STEPS := 24  ## redraw steps over a full charge
## Seconds of charge for tiers 1-3: the physics' own (KartPhysics.TIER_SEC).
var tiers: Array = KartPhysics.TIER_SEC

var item := ""
var roulette := 0.0  ## seconds of roulette left
var face: Control  ## the disc, icon and chip (the pulse scales it)
var glow: Control  ## the gold rim glow behind the face (the pulse fades it)

var _last_press_ms := -100000
var _shown_item := ""
var _shown_icon := ""
var _flash := 0.0
var _spin_t := 0.0
var _spin_i := 0
var _held_for := 0.0
var _pulsing := false
var _tween: Tween
var _pulse: Tween
var _ring: Gradient
var _ring_dim: Gradient
var _draw_kit := KartDraw.new()
var _arc_kit := KartDraw.new()
# The drift meter's shown state.
var _charge_step := 0
var _tier := 0
var _knob := false
var _active := false
var _arc_flash := 0.0
var _level := 0.0  ## 0 dim .. 1 bright, eased


func _init() -> void:
	name = "ItemButton"
	focus_mode = Control.FOCUS_NONE
	action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	custom_minimum_size = Vector2(HIT_SIZE, HIT_SIZE)
	size = Vector2(HIT_SIZE, HIT_SIZE)
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
	face = Control.new()
	face.name = "Face"
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.size = size
	face.pivot_offset = size * 0.5
	face.draw.connect(_draw_face)
	add_child(face)
	glow = Control.new()
	glow.name = "Glow"
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.size = size
	glow.show_behind_parent = true
	glow.visible = false
	glow.modulate.a = 0.0
	glow.draw.connect(func():
		var d := KartDraw.new()
		var c := size * 0.5
		var r := SIZE * 0.5
		d.ring(c, r - 2.0, r + 4.0, Color(1.0, 0.9, 0.4, 0.95), Color(-1, 0, 0), 0.0, TAU, 72)
		d.ring(c, r + 4.0, r + 8.0, Color(1.0, 0.8, 0.3, 0.45), Color(-1, 0, 0), 0.0, TAU, 72)
		d.flush(glow))
	face.add_child(glow)


## The hit area: a circle 1.25× the drawn disc's radius (it fills the control's square), so a
## hurried tap near the rim still uses the item. The square's corners don't count.
func _has_point(point: Vector2) -> bool:
	return point.distance_to(size * 0.5) <= hit_radius()


func hit_radius() -> float:
	return SIZE * 0.5 * HIT_SCALE


## The hit circle on the canvas (centre, radius), for layout checks.
func hit_circle() -> Array:
	return [get_global_rect().get_center(), hit_radius()]


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
		_set_pulse(false)
		_held_for = 0.0
		return
	if held != _shown_item or was_spinning:
		var landed := held != "" and (was_spinning or _shown_item == "")
		_shown_item = held
		_held_for = 0.0
		_set_icon(held)
		if landed:
			_land()
	if held != "":
		_held_for += delta
	_set_pulse(held != "" and _held_for >= IDLE_SEC)
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 2.5)
		face.queue_redraw()


## The drift meter, from the rider's KartState each frame.
func set_drift(drift_dir: int, charge: float, tier: int, knob: bool, delta: float) -> void:
	var active := drift_dir != 0
	var full: float = tiers[2]
	var step := clampi(ceili(charge / full * CHARGE_STEPS - 0.001), 0, CHARGE_STEPS) if active else 0
	var changed := active != _active or tier != _tier or knob != _knob or step != _charge_step
	if tier > _tier and active:
		_arc_flash = 1.0
	_active = active
	_tier = tier
	_knob = knob
	_charge_step = step
	var goal := 1.0 if active else 0.0
	if absf(_level - goal) > 0.001:
		_level = move_toward(_level, goal, delta * 5.0)
		changed = true
	if _arc_flash > 0.0:
		_arc_flash = maxf(0.0, _arc_flash - delta * 3.0)
		changed = true
	if changed:
		queue_redraw()


## The charge the arc shows, in seconds (quantised to its redraw steps).
func shown_charge() -> float:
	return float(_charge_step) / CHARGE_STEPS * float(tiers[2])


func is_pulsing() -> bool:
	return _pulsing


func _set_icon(icon: String) -> void:
	if icon != _shown_icon:
		_shown_icon = icon
		face.queue_redraw()


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
	_held_for = 0.0
	_set_pulse(false)
	_flash = 1.0  # the burst on use
	face.queue_redraw()
	_bounce(0.86, 0.3)


## The press squash and the landing pop (the face's transform; the drift arc stays put).
func _bounce(from: float, seconds: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	face.scale = Vector2(from, from)
	_tween = create_tween()
	_tween.tween_property(face, "scale", Vector2.ONE, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The idle call to action: a slow 1.0 → 1.06 breathe of the face and the gold glow, as tweens
## (a transform and a modulate: nothing re-draws).
func _set_pulse(on: bool) -> void:
	if on == _pulsing:
		return
	_pulsing = on
	if _pulse and _pulse.is_valid():
		_pulse.kill()
	if not on:
		glow.visible = false
		glow.modulate.a = 0.0
		if not (_tween and _tween.is_valid()):
			face.scale = Vector2.ONE
		return
	glow.visible = true
	_pulse = create_tween().set_loops()
	_pulse.tween_property(face, "scale", Vector2(PULSE_SCALE, PULSE_SCALE), 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse.parallel().tween_property(glow, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(face, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse.parallel().tween_property(glow, "modulate:a", 0.25, 0.55).set_trans(Tween.TRANS_SINE)


# --- Drawing ---

## The drift arc and the knob glyph (this node; the face draws over it).
func _draw() -> void:
	var c := size * 0.5
	var d := _arc_kit
	var alpha := lerpf(0.6, 1.0, _level)
	var full: float = tiers[2]
	var span := ARC_TO - ARC_FROM
	# The backing: a dark band with round ends, so the meter reads over sky, grass or barriers.
	var back := Color(KartTheme.OUTLINE, 0.88)
	d.ring(c, ARC_IN - ARC_BACK, ARC_OUT + ARC_BACK, back, Color(-1, 0, 0), ARC_FROM, ARC_TO, 48)
	for a in [ARC_FROM, ARC_TO]:
		d.disc(c + Vector2(cos(a), sin(a)) * (ARC_IN + ARC_OUT) * 0.5, (ARC_OUT - ARC_IN) * 0.5 + ARC_BACK, back, 16)
	var charge := shown_charge()
	var prev := 0.0
	for i in 3:
		var t: float = tiers[i]
		var gap := 0.012  # a dark notch between segments
		var a0 := ARC_FROM + span * prev / full + (gap if i > 0 else 0.0)
		var a1 := ARC_FROM + span * t / full - (gap if i < 2 else 0.0)
		var col: Color = KartTheme.TIER_COLORS[i]
		# The unfilled part of each segment shows its colour faintly.
		d.ring(c, ARC_IN, ARC_OUT, Color(col, 0.3 * alpha), Color(-1, 0, 0), a0, a1, 16)
		var fill_to := clampf(ARC_FROM + span * charge / full, a0, a1)
		if fill_to > a0 + 0.005:
			var bright := col.lightened(0.4 * _arc_flash) if _tier == i + 1 else col
			d.ring(c, ARC_IN, ARC_OUT, bright, Color(-1, 0, 0), a0, fill_to, 16)
			# A gloss line along the band's outer edge.
			d.ring(c, ARC_OUT - 6.0, ARC_OUT - 3.0, Color(1, 1, 1, 0.45), Color(-1, 0, 0), a0, fill_to, 16)
		prev = t
	if _arc_flash > 0.0 and _tier > 0:
		d.ring(c, ARC_IN - 8.0 * _arc_flash, ARC_OUT + 8.0 * _arc_flash, Color(KartTheme.TIER_COLORS[_tier - 1], 0.35 * _arc_flash),
			Color(-1, 0, 0), ARC_FROM, ARC_TO, 48)
	_draw_knob(d, c + Vector2(cos(KNOB_AT), sin(KNOB_AT)) * KNOB_R, alpha)
	d.flush(self)


## The knob glyph: a resistance dial with a pointer and grip ticks; gold and glowing when lit.
func _draw_knob(d: KartDraw, c: Vector2, alpha: float) -> void:
	var lit := _knob and _active
	if lit:
		d.disc(c, 33.0, Color(1.0, 0.75, 0.2, 0.4))
	d.disc(c, 26.0, Color(KartTheme.OUTLINE, 0.92))
	var dial := Color(1.0, 0.8, 0.2) if lit else Color(0.5, 0.45, 0.72, alpha)
	d.disc(c, 21.0, dial)
	for i in 8:
		var a := TAU * i / 8.0
		d.line(c + Vector2(cos(a), sin(a)) * 13.0, c + Vector2(cos(a), sin(a)) * 19.0, 3.0, Color(KartTheme.OUTLINE, 0.6))
	var pointer := -PI * 0.25 if lit else -PI * 0.75
	d.line(c, c + Vector2(cos(pointer), sin(pointer)) * 15.0, 5.0, KartTheme.OUTLINE)
	d.disc(c, 5.0, KartTheme.OUTLINE)


## The disc, icon, chip and text (the face's own draw: one triangle array and the labels).
func _draw_face() -> void:
	var c := size * 0.5
	var r := SIZE * 0.5
	var empty := _shown_icon == "" and roulette <= 0.0
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
	d.flush(face)
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
		face.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 8, Color(KartTheme.OUTLINE, color.a))
	face.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
