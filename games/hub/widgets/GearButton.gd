class_name GearButton
extends Button
## Settings as a 120 px secondary pill with a gear drawn as one polygon (the display face has
## no gear glyph). It draws only when its state changes.

const TEETH := 8


func _init() -> void:
	name = "Settings"
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(HubTheme.TARGET, HubTheme.TARGET)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tooltip_text = "Settings"
	HubTheme.look().style_button(self, GameTheme.SECONDARY)


func _draw() -> void:
	var c := size / 2.0 + Vector2(0, -2)
	var outer := 34.0
	var inner := 25.0
	var points := PackedVector2Array()
	var steps := TEETH * 4
	for i in steps:
		var a := TAU * (i + 0.5) / steps
		var tooth := (i % 4) < 2
		points.append(c + Vector2(cos(a), sin(a)) * (outer if tooth else inner))
	var ink := Color(1, 1, 1, 0.45 if disabled else 1.0)
	# One triangle array (one draw call): the teeth, then the hole in the ink.
	ShapeBatch.new().fan(c, points, ink).circle(c, 11.0, HubTheme.look().ink).draw(self)
