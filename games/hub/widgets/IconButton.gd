class_name IconButton
extends Button
## A 120 px secondary pill with a drawn icon (the display face has no ▲ ▼ ✕ glyphs), like
## GearButton: "up", "down" or "remove". One triangle array; it draws only when its state
## changes. A disabled one fades its icon (the shape and the fade, never colour alone).

var icon_name := ""


func _init(which: String, action: Callable) -> void:
	icon_name = which
	name = which.capitalize()
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(HubTheme.TARGET, HubTheme.TARGET)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tooltip_text = {"up": "Move up", "down": "Move down", "remove": "Remove"}.get(which, which)
	HubTheme.look().style_button(self, GameTheme.SECONDARY)
	pressed.connect(action)


func _draw() -> void:
	var c := size / 2.0 + Vector2(0, -2)
	var ink := Color(1, 1, 1, 0.35 if disabled else 1.0)
	var b := ShapeBatch.new()
	match icon_name:
		"up":
			b.convex(PackedVector2Array([c + Vector2(0, -26), c + Vector2(30, 20), c + Vector2(-30, 20)]), ink)
		"down":
			b.convex(PackedVector2Array([c + Vector2(0, 26), c + Vector2(-30, -20), c + Vector2(30, -20)]), ink)
		"remove":
			b.line(c + Vector2(-24, -24), c + Vector2(24, 24), 13.0, ink).line(c + Vector2(-24, 24), c + Vector2(24, -24), 13.0, ink)
	b.draw(self)


func set_enabled(on: bool) -> void:
	if disabled == on:
		disabled = not on
		queue_redraw()
