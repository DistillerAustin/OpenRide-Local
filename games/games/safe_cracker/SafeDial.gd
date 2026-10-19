class_name SafeDial
extends Node2D
## Safe Cracker's door and dial (#41), centred on the door. Redrawn only when something shown
## changes (the needle, the hold ring, the lights, the alarm or the door swinging). The dial
## runs 0-100 over 270 degrees, from the lower left round to the lower right; the needle is the
## live resistance reading.
##
## Type follows framework/ui/UI_STYLE.md: the display face (`GameTheme.display_font`), nothing
## under 34 px, an ink outline under every number. The hero is the reading (96 px, green when on
## the target), in the gap at the bottom of the dial that the needle never sweeps. The target
## number sits on a brass plate above the bezel, out of the needle's reach. Shapes are drawn
## first and text last (every outline, then every fill), so the text batches together.

const R := 262.0
const DOOR := Rect2(-440, -320, 880, 640)
const SWEEP_START := 135.0
const SWEEP := 270.0

const INK := Color("14110d")  ## soot: outlines (Safe Cracker's ink)
const NUMERAL_SIZE := 36
const NUMERAL_OUTLINE := 8
const READING_SIZE := 96  ## HudTheme.BIG: the hero
const READING_BASELINE := 182.0
const TARGET_SIZE := 56  ## HudTheme.MEDIUM
## The target's brass plate, above the bezel (radius R + 40) and outside the needle's sweep.
const TARGET_PLATE := Rect2(-92, -R - 118, 184, 80)
## The tumbler lights: a column on the door, right of the bezel, filling from the bottom up.
const LIGHT_X := 371.0
const LIGHT_R := 22.0
const LIGHT_GAP := 58.0
const LIGHT_POP := 0.35  ## the newest light grows by this much at `light_pop` 1
## "KEEP PEDALLING": an amber badge across the dial's lower half, above the reading.
const TEXT_BOX := 600.0  ## the width centred text is laid out in
const PEDAL_BADGE := Rect2(-250, 30, 500, 82)

var reading := 0.0
var target := 0
var tolerance := 2.0
var target_hidden := false
var hold_frac := 0.0  ## 0-1, how far through the hold
var closeness := 0.0
var powered := true
var tumblers_done := 0
var tumblers_total := 3
var door_open := 0.0  ## 0 closed, 1 fully open
var alarm := 0.0  ## 0-1, the alarm light
var light_pop := 0.0  ## 0-1, the newest lit tumbler light's pop (tweened by SafeCracker)
var colour := Color(0.5, 0.52, 0.55)
var accent := Color(0.95, 0.75, 0.35)

var _drawn := {}
var _t := 0.0
var _font: Font
var _queued: Array = []  ## text waiting for `_flush_text`


static func angle_for(value: float) -> float:
	return deg_to_rad(SWEEP_START + clampf(value, 0.0, 100.0) * SWEEP / 100.0)


## Where tumbler light `i` of `total` sits (door coordinates).
static func light_at(i: int, total: int) -> Vector2:
	return Vector2(LIGHT_X, (total - 1) * LIGHT_GAP / 2.0 - i * LIGHT_GAP)


## Whether the reading is within the tolerance of a shown target (the reading turns green).
func on_target() -> bool:
	return not target_hidden and absf(reading - float(target)) <= tolerance


## Redraws only when a shown value changed.
func refresh() -> void:
	var state := {"r": roundi(reading * 2.0), "t": target, "tol": tolerance, "h": target_hidden, "f": roundi(hold_frac * 60.0),
		"c": roundi(closeness * 20.0), "p": powered, "d": tumblers_done, "n": tumblers_total,
		"o": roundi(door_open * 120.0), "a": roundi(alarm * 10.0), "col": colour, "lp": roundi(light_pop * 24.0)}
	if tumblers_done < tumblers_total:
		state["pulse"] = int(_t * 6.0)  # the next light's outline breathes
	if state != _drawn:
		_drawn = state
		queue_redraw()


func _process(delta: float) -> void:
	_t += delta


func _draw() -> void:
	if _font == null:
		_font = GameTheme.display_font(true)
	if alarm > 0.0:
		# Steady: the door's red modulate pulse (SafeCracker) does the breathing.
		draw_rect(Rect2(-500, -380, 1000, 760), Color(0.95, 0.15, 0.1, 0.35 + 0.5 * alarm), false, 20)
	var s := maxf(1.0 - door_open, 0.0)
	if s <= 0.02:
		return
	draw_set_transform_matrix(Transform2D(Vector2(s, 0), Vector2(0, 1), Vector2(DOOR.position.x * (1.0 - s), 0)))
	_draw_door()
	_draw_lights()
	_draw_needle()
	_draw_text()
	_draw_reading()
	_flush_text()
	if not powered:
		draw_circle(Vector2.ZERO, R + 40.0, Color(0.02, 0.02, 0.04, 0.6))
		var badge := StyleBoxFlat.new()
		badge.bg_color = Color(GameTheme.WARN, 0.96)
		badge.set_corner_radius_all(14)
		badge.border_color = Color(Color.WHITE, 0.55)
		badge.set_border_width_all(3)
		badge.border_width_bottom = 6
		draw_style_box(badge, PEDAL_BADGE)
		_text("KEEP PEDALLING", Vector2(0, PEDAL_BADGE.get_center().y + 20), 52, Color.WHITE)
		_flush_text()
	draw_set_transform_matrix(Transform2D.IDENTITY)


## The door, the bezel, the ticks, the target band and the hold ring: shapes only.
func _draw_door() -> void:
	var face := StyleBoxFlat.new()
	face.bg_color = colour
	face.set_corner_radius_all(22)
	face.border_color = colour.lightened(0.25)
	face.set_border_width_all(6)
	draw_style_box(face, DOOR)
	for corner in [DOOR.position + Vector2(36, 36), Vector2(DOOR.end.x - 36, DOOR.position.y + 36),
			Vector2(DOOR.position.x + 36, DOOR.end.y - 36), DOOR.end - Vector2(36, 36)]:
		draw_circle(corner, 11, colour.darkened(0.3))
		draw_circle(corner, 5, colour.lightened(0.3))
	draw_circle(Vector2.ZERO, R + 40.0, colour.darkened(0.35))
	draw_circle(Vector2.ZERO, R + 24.0, colour.lightened(0.1))
	draw_circle(Vector2.ZERO, R + 8.0, Color(0.07, 0.07, 0.09))
	for i in range(0, 101, 5):
		var a := angle_for(float(i))
		var major := i % 10 == 0
		var from := Vector2(cos(a), sin(a)) * (R - (34.0 if major else 20.0))
		draw_line(from, Vector2(cos(a), sin(a)) * (R - 4.0), Color(0.85, 0.85, 0.8) if major else Color(0.5, 0.5, 0.5), 5.0 if major else 3.0)
	# The target: a brass band the width of the tolerance, or a glow that warms as you close in.
	if not target_hidden:
		draw_arc(Vector2.ZERO, R - 22.0, angle_for(float(target) - tolerance), angle_for(float(target) + tolerance), 24, Color(accent, 0.85), 26.0)
		var ta := angle_for(float(target))
		var tip := Vector2(cos(ta), sin(ta)) * (R + 6.0)
		var side := Vector2(-sin(ta), cos(ta)) * 14.0
		var out := Vector2(cos(ta), sin(ta)) * 30.0
		draw_colored_polygon(PackedVector2Array([tip, tip + out + side, tip + out - side]), accent)
	else:
		draw_arc(Vector2.ZERO, R + 33.0, 0.0, TAU, 72, Color(accent, closeness * closeness * 0.9), 10.0)
	# The hold ring, filling as the needle stays on the target.
	if hold_frac > 0.0:
		draw_arc(Vector2.ZERO, R + 33.0, -PI / 2.0, -PI / 2.0 + hold_frac * TAU, 72, GameTheme.GOOD, 12.0)
	# The target's plate: soot with a brass edge, riveted over the top of the door.
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(INK, 0.94)
	plate.set_corner_radius_all(16)
	plate.border_color = accent if not target_hidden else Color(0.75, 0.78, 0.85)
	plate.set_border_width_all(4)
	plate.border_width_bottom = 7
	draw_style_box(plate, TARGET_PLATE)


## One light per tumbler: brass when clicked, a breathing outline for the next. The newest lit
## light pops (`light_pop`).
func _draw_lights() -> void:
	for i in tumblers_total:
		var at := light_at(i, tumblers_total)
		if i < tumblers_done:
			var grow := 1.0 + LIGHT_POP * light_pop if i == tumblers_done - 1 else 1.0
			draw_circle(at, LIGHT_R * grow + 4.0, INK)
			draw_circle(at, LIGHT_R * grow, accent)
			draw_circle(at, LIGHT_R * 0.5 * grow, accent.lightened(0.5))
		else:
			var pulse := 0.5 + 0.5 * sin(_t * 6.0) if i == tumblers_done else 0.0
			draw_circle(at, LIGHT_R + 4.0, Color(INK, 0.7))
			draw_arc(at, LIGHT_R - 2.0, 0.0, TAU, 24, Color(accent, 0.35 + 0.5 * pulse), 4.0)


## The numerals round the dial and the target on its plate.
func _draw_text() -> void:
	for i in range(0, 101, 10):
		var a := angle_for(float(i))
		var at := Vector2(cos(a), sin(a)) * (R - 70.0)
		_text(str(i), at + Vector2(0, NUMERAL_SIZE * 0.36), NUMERAL_SIZE, Color(0.93, 0.92, 0.86), NUMERAL_OUTLINE)
	var plate_base := Vector2(0, TARGET_PLATE.get_center().y + TARGET_SIZE * 0.36)
	if target_hidden:
		_text("?", plate_base, TARGET_SIZE, Color(0.75, 0.78, 0.85))
	else:
		_text(str(target), plate_base, TARGET_SIZE, accent)


func _draw_needle() -> void:
	var na := angle_for(reading)
	var dir := Vector2(cos(na), sin(na))
	draw_line(-dir * 40.0, dir * (R - 12.0), Color(0.95, 0.3, 0.25), 9.0)
	draw_circle(Vector2.ZERO, 30.0, Color(0.85, 0.85, 0.8))
	draw_circle(Vector2.ZERO, 14.0, Color(0.2, 0.2, 0.22))


## The hero: the reading in big numbers, green while it's on a shown target.
func _draw_reading() -> void:
	_text(str(roundi(reading)), Vector2(0, READING_BASELINE), READING_SIZE,
		GameTheme.GOOD if on_target() else Color(0.97, 0.96, 0.92))


## Queues centred text with the ink outline under it (`baseline` is the centre of its baseline).
## `_flush_text` draws every queued outline, then every fill: two batches, not two a string.
func _text(text: String, baseline: Vector2, size: int, color: Color, outline := 0) -> void:
	_queued.append([text, baseline - Vector2(TEXT_BOX / 2.0, 0), size, color,
		outline if outline > 0 else GameTheme.outline_for(size)])


func _flush_text() -> void:
	for q in _queued:
		draw_string_outline(_font, q[1], q[0], HORIZONTAL_ALIGNMENT_CENTER, TEXT_BOX, q[2], q[4], INK)
	for q in _queued:
		draw_string(_font, q[1], q[0], HORIZONTAL_ALIGNMENT_CENTER, TEXT_BOX, q[2], q[3])
	_queued.clear()
