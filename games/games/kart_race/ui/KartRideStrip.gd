class_name KartRideStrip
extends Control
## Kart Race's ride metrics (#43): a slim strip of tiles at the bottom centre, in place of the
## framework's ride panel (hidden through `Hud.set_skin({"ride_panel": false})`):
##
##   [ 82 RPM ] [ 202 WATTS ] [ 38% RESIST ] [ 142 BPM ] [ ×1.6 EFFORT ]
##
## It reads the same sources as the framework panel (InputBus, Effort). The heart-rate tile shows
## only while a strap is sending (rider's ask, 2026-10-27); the effort tile glows warmer as the
## multiplier climbs and hides in segments without effort scoring.
##
## The whole strip is drawn by this one control (tiles in one KartDraw triangle array, then every
## text's outline, then every fill), so it costs a handful of draw calls instead of a pair per
## label, and it redraws only when a shown value changes.

const TILE := Vector2(164, 112)
const GAP := 12.0
const VALUE_SIZE := 64
const CAPTION_SIZE := 34
const CAPTIONS := ["RPM", "WATTS", "RESIST", "BPM", "EFFORT"]
const HEART := 3
const EFFORT := 4
const RADIUS := 18.0

## The texts shown, per tile (for tests): rpm, watts, resistance, bpm, effort.
var shown := ["--", "--", "--", "--", "--"]
## Tests set these instead of reading InputBus and Effort.
var source := {}

var _effort_on := true
var _heart_on := false
var _glow := 0.0
var _d := KartDraw.new()


func _init() -> void:
	name = "RideStrip"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(TILE.x * CAPTIONS.size() + GAP * (CAPTIONS.size() - 1), TILE.y)


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	var cadence: float = source.get("cadence", InputBus.cadence)
	var power: float = source.get("power", InputBus.power)
	var resistance: float = source.get("resistance", InputBus.resistance)
	var on: bool = source.get("effort_enabled", Effort.enabled)
	var multiplier: float = source.get("multiplier", Effort.multiplier)
	var heart_rate: float = source.get("heart_rate", InputBus.heart_rate)
	refresh(cadence, power, resistance, on, multiplier, heart_rate)


## `heart_rate` < 0: no strap sending, and its tile hides.
func refresh(cadence: float, power: float, resistance: float, effort_on: bool, multiplier: float, heart_rate := -1.0) -> void:
	var heart_on := heart_rate >= 0.0
	var changed := effort_on != _effort_on or heart_on != _heart_on
	_effort_on = effort_on
	_heart_on = heart_on
	changed = _put(0, str(roundi(cadence))) or changed
	changed = _put(1, str(roundi(power))) or changed
	changed = _put(2, "%d%%" % roundi(resistance)) or changed
	if heart_on:
		changed = _put(HEART, str(roundi(heart_rate))) or changed
	if effort_on:
		var m := snappedf(multiplier, 0.1)
		changed = _put(EFFORT, "×%.1f" % m) or changed
		var glow := clampf((m - 1.0) / 0.5, 0.0, 1.0)
		if absf(glow - _glow) > 0.01:
			_glow = glow
			changed = true
	if changed:
		queue_redraw()


## The tiles shown, left to right: indexes into CAPTIONS and `shown`.
func tiles() -> Array[int]:
	var out: Array[int] = [0, 1, 2]
	if _heart_on:
		out.append(HEART)
	if _effort_on:
		out.append(EFFORT)
	return out


## The shown tiles' rects, left to right, centred.
func tile_rects() -> Array[Rect2]:
	var n := tiles().size()
	var x0 := (size.x - (n * TILE.x + (n - 1) * GAP)) * 0.5
	var out: Array[Rect2] = []
	for i in n:
		out.append(Rect2(Vector2(x0 + i * (TILE.x + GAP), 0), TILE))
	return out


func _put(i: int, text: String) -> bool:
	if shown[i] == text:
		return false
	shown[i] = text
	return true


func _draw() -> void:
	var rects := tile_rects()
	var which := tiles()
	for i in rects.size():
		var r := rects[i]
		var effort := which[i] == EFFORT
		var fill := Color(0.12, 0.08, 0.28, 0.95)
		var edge := KartTheme.TILE_EDGE
		if effort:
			fill = Color(0.95, 0.42, 0.2, 0.95).lerp(Color(1.0, 0.62, 0.12, 1.0), _glow)
			edge = Color(1.0, 0.8, 0.5).lerp(Color(1.0, 0.97, 0.7), _glow)
			if _glow > 0.0:
				_d.rect(r.grow(4.0 + 8.0 * _glow), Color(1.0, 0.6, 0.1, 0.3 * _glow), RADIUS + 10.0)
		_d.rect(Rect2(r.position + Vector2(3, 5), r.size), Color(0.05, 0.0, 0.15, 0.4), RADIUS)
		_d.rect(r, edge, RADIUS)
		_d.rect(r.grow_individual(-3, -3, -3, -7), fill, RADIUS - 3.0)
	_d.flush(self)
	var font := KartTheme.display(true)
	# Outlines first, then fills: two passes instead of two draws per text.
	for pass_i in 2:
		for i in rects.size():
			var r := rects[i]
			var t := which[i]
			_text(font, shown[t], VALUE_SIZE, Vector2(r.get_center().x, r.position.y + 64), KartTheme.INK, 12, pass_i == 0)
			var cap := Color(1, 0.95, 0.85) if t == EFFORT else Color(0.78, 0.8, 1.0)
			if pass_i == 1:
				_text(font, CAPTIONS[t], CAPTION_SIZE, Vector2(r.get_center().x, r.position.y + 100), cap, 0, false)


func _text(font: Font, text: String, font_size: int, base_centre: Vector2, color: Color, outline: int, outline_pass: bool) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at := base_centre - Vector2(w * 0.5, 0)
	if outline_pass:
		if outline > 0:
			draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, KartTheme.OUTLINE)
	else:
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
