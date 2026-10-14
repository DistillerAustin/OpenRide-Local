class_name KartRideStrip
extends Control
## Kart Race's ride metrics (#43): a slim strip of four tiles at the bottom centre, in place of
## the framework's ride panel (hidden through `Hud.set_skin({"ride_panel": false})`):
##
##   [ 82 RPM ] [ 202 WATTS ] [ 38% RESIST ] [ ×1.6 EFFORT ]
##
## It reads the same sources as the framework panel (InputBus, Effort). The effort tile glows
## warmer as the multiplier climbs and hides in segments without effort scoring. Tiles are
## free-standing (no container) and labels change only with their values, so a new number never
## re-lays out the HUD.

const TILE := Vector2(164, 112)
const GAP := 12.0
const VALUE_SIZE := 64
const CAPTION_SIZE := 34
const CAPTIONS := ["RPM", "WATTS", "RESIST", "EFFORT"]

var values: Array[Label] = []
var captions: Array[Label] = []
var tiles: Array[Panel] = []

var _shown := ["", "", "", ""]
var _effort_on := true
var _effort_style: StyleBoxFlat
var _shown_glow := -1.0
## Tests set these instead of reading InputBus and Effort.
var source := {}


func _init() -> void:
	name = "RideStrip"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(TILE.x * 4 + GAP * 3, TILE.y)
	for i in 4:
		var tile := Panel.new()
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.size = TILE
		tile.position = Vector2(i * (TILE.x + GAP), 0)
		var style := _style(i == 3)
		if i == 3:
			_effort_style = style
		tile.add_theme_stylebox_override("panel", style)
		add_child(tile)
		var value := KartTheme.label("--", VALUE_SIZE, KartTheme.INK, true)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.size = Vector2(TILE.x, 70)
		value.position = Vector2(0, 2)
		value.add_theme_constant_override("outline_size", 12)
		tile.add_child(value)
		var caption := KartTheme.label(CAPTIONS[i], CAPTION_SIZE, Color(0.78, 0.8, 1.0) if i < 3 else Color(1, 0.95, 0.85), true)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.size = Vector2(TILE.x, 40)
		caption.position = Vector2(0, 66)
		caption.add_theme_constant_override("outline_size", 0)
		caption.add_theme_constant_override("shadow_offset_y", 0)
		tile.add_child(caption)
		values.append(value)
		captions.append(caption)
		tiles.append(tile)


func _style(effort: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(1.0, 0.5, 0.2, 0.95) if effort else KartTheme.NIGHT
	s.set_corner_radius_all(18)
	s.border_color = Color(1.0, 0.8, 0.5) if effort else KartTheme.TILE_EDGE
	s.set_border_width_all(3)
	s.border_width_bottom = 7
	s.shadow_color = Color(0.05, 0.0, 0.15, 0.4)
	s.shadow_size = 6
	s.shadow_offset = Vector2(3, 5)
	s.anti_aliasing = true
	return s


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	var cadence: float = source.get("cadence", InputBus.cadence)
	var power: float = source.get("power", InputBus.power)
	var resistance: float = source.get("resistance", InputBus.resistance)
	var on: bool = source.get("effort_enabled", Effort.enabled)
	var multiplier: float = source.get("multiplier", Effort.multiplier)
	refresh(cadence, power, resistance, on, multiplier)


func refresh(cadence: float, power: float, resistance: float, effort_on: bool, multiplier: float) -> void:
	_put(0, str(roundi(cadence)))
	_put(1, str(roundi(power)))
	_put(2, "%d%%" % roundi(resistance))
	if effort_on != _effort_on:
		_effort_on = effort_on
		tiles[3].visible = effort_on
		# Three tiles stay centred where four were.
		var n := 4 if effort_on else 3
		var x0 := (size.x - (n * TILE.x + (n - 1) * GAP)) * 0.5
		for i in 3:
			tiles[i].position.x = x0 + i * (TILE.x + GAP)
	if effort_on:
		var m := snappedf(multiplier, 0.1)
		_put(3, "×%.1f" % m)
		var glow := clampf((m - 1.0) / 0.5, 0.0, 1.0)
		if absf(glow - _shown_glow) > 0.01:
			_shown_glow = glow
			_effort_style.bg_color = Color(0.95, 0.42, 0.2, 0.95).lerp(Color(1.0, 0.62, 0.12, 1.0), glow)
			_effort_style.border_color = Color(1.0, 0.8, 0.5).lerp(Color(1.0, 0.97, 0.7), glow)
			_effort_style.shadow_color = Color(0.05, 0.0, 0.15, 0.4).lerp(Color(1.0, 0.6, 0.1, 0.55), glow)
			_effort_style.shadow_size = int(lerpf(6.0, 16.0, glow))


func _put(i: int, text: String) -> void:
	if _shown[i] != text:
		_shown[i] = text
		values[i].text = text
