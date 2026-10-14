class_name KartDriftMeter
extends Control
## The drift meter (#43): "DRIFT", a slanted bar in three segments (the spark tiers' blue,
## orange and violet, sized by the charge each tier needs) that fills with the rider's drift
## charge, and the knob glyph: a little resistance dial that lights up while turning the
## resistance up is speeding the charge (KartState.knob_boosting, the spec's "knob" bonus).
##
## Dim at rest; bright while drifting; each new tier flashes its segment. It redraws only while
## the charge, tier or knob changes.

const SIZE := Vector2(470, 76)
const BAR := Rect2(118, 18, 266, 40)
const KNOB_C := Vector2(432, 38)
const SKEW := 14.0
## Seconds of charge for tiers 1-3 (the spec's 0.9 / 2.0 / 3.4 s). KartPhysics' own constant
## wins when the handling agent defines one (`DRIFT_TIERS` or `TIER_CHARGE`).
const DEFAULT_TIERS := [0.9, 2.0, 3.4]

var tiers: Array = DEFAULT_TIERS

var _charge := 0.0
var _tier := 0
var _knob := false
var _active := false
var _flash := 0.0
var _level := 0.0  ## 0 dim .. 1 bright, eased


func _init() -> void:
	name = "DriftMeter"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE
	var consts: Dictionary = (KartPhysics as Script).get_script_constant_map()
	for key in ["DRIFT_TIERS", "TIER_CHARGE"]:
		var v = consts.get(key)
		if v is Array and v.size() == 3:
			tiers = v
			break


## From the rider's KartState each frame.
func set_drift(drift_dir: int, charge: float, tier: int, knob: bool, delta: float) -> void:
	var active := drift_dir != 0
	var changed := false
	if tier > _tier and active:
		_flash = 1.0
	if active != _active or tier != _tier or knob != _knob or absf(charge - _charge) > 0.005:
		changed = true
	_active = active
	_tier = tier
	_knob = knob
	_charge = charge if active else 0.0
	var goal := 1.0 if active else 0.0
	if absf(_level - goal) > 0.001:
		_level = move_toward(_level, goal, delta * 5.0)
		changed = true
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 3.0)
		changed = true
	if changed:
		queue_redraw()


func _draw() -> void:
	var alpha := lerpf(0.55, 1.0, _level)
	var font := KartTheme.display()
	# "DRIFT"
	var word := "DRIFT"
	var at := Vector2(4, 52)
	draw_string_outline(font, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, 10, Color(KartTheme.OUTLINE, alpha))
	draw_string(font, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1, 1, 1, alpha))
	# The bar's slanted shell.
	var shell := _slant(BAR.grow(6))
	draw_colored_polygon(shell, Color(KartTheme.OUTLINE, 0.9 * alpha))
	draw_colored_polygon(_slant(BAR), Color(0.16, 0.1, 0.34, 0.85 * alpha))
	var full: float = tiers[2]
	var x0 := BAR.position.x
	var prev := 0.0
	for i in 3:
		var t: float = tiers[i]
		var a := x0 + BAR.size.x * prev / full
		var b := x0 + BAR.size.x * t / full
		var col: Color = KartTheme.TIER_COLORS[i]
		# The unfilled part of each segment shows its colour faintly.
		draw_colored_polygon(_slant(Rect2(a + 2, BAR.position.y + 4, b - a - 4, BAR.size.y - 8)), Color(col, 0.22 * alpha))
		var fill_to := clampf(x0 + BAR.size.x * _charge / full, a, b)
		if fill_to > a + 2:
			var bright := col.lightened(0.35 * _flash) if _tier == i + 1 else col
			draw_colored_polygon(_slant(Rect2(a + 2, BAR.position.y + 4, fill_to - a - 4 + (2.0 if fill_to >= b else 0.0), BAR.size.y - 8)), bright)
			draw_line(Vector2(a + 6 + SKEW * 0.5, BAR.position.y + 10), Vector2(fill_to - 4 + SKEW * 0.5, BAR.position.y + 10), Color(1, 1, 1, 0.45), 4.0, true)
		if i < 2:
			draw_line(Vector2(b + SKEW * 0.5, BAR.position.y + 2), Vector2(b - SKEW * 0.5, BAR.end.y - 2), Color(KartTheme.OUTLINE, alpha), 4.0, true)
		prev = t
	if _flash > 0.0 and _tier > 0:
		draw_colored_polygon(_slant(BAR.grow(10 * _flash)), Color(KartTheme.TIER_COLORS[_tier - 1], 0.35 * _flash))
	_draw_knob(alpha)


## The knob glyph: a resistance dial with a pointer and grip ticks; gold and glowing when lit.
func _draw_knob(alpha: float) -> void:
	var lit := _knob and _active
	var c := KNOB_C
	if lit:
		draw_circle(c, 33.0, Color(1.0, 0.75, 0.2, 0.35))
	draw_circle(c, 27.0, Color(KartTheme.OUTLINE, alpha))
	var face := Color(1.0, 0.8, 0.2) if lit else Color(0.42, 0.38, 0.6, alpha)
	draw_circle(c, 22.0, face)
	for i in 8:
		var a := TAU * i / 8.0
		draw_line(c + Vector2(cos(a), sin(a)) * 14.0, c + Vector2(cos(a), sin(a)) * 20.0, Color(KartTheme.OUTLINE, 0.6 * alpha), 3.0, true)
	var pointer := -PI * 0.25 if lit else -PI * 0.75
	draw_line(c, c + Vector2(cos(pointer), sin(pointer)) * 15.0, Color(KartTheme.OUTLINE, alpha), 5.0, true)
	draw_circle(c, 5.0, Color(KartTheme.OUTLINE, alpha))


func _slant(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(r.position.x + SKEW * 0.5, r.position.y), Vector2(r.end.x + SKEW * 0.5, r.position.y),
		Vector2(r.end.x - SKEW * 0.5, r.end.y), Vector2(r.position.x - SKEW * 0.5, r.end.y)])
