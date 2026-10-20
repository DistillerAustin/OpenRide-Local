class_name Stepper
extends HBoxContainer
## − value + (spec §8.3): steps through a fixed list of values, with the value big between two
## 120 px buttons. No keyboard anywhere, and no slider (a poor target while pedalling). The
## ends don't wrap: − disables at the first value, + at the last.

signal changed(value: Variant)

var values: Array = []
var index := 0
var minus: Button
var plus: Button
var shown: Label
var _format: Callable


## `format(value) -> String` draws the value ("10 min"); `value_width` fits the widest.
func _init(step_values: Array, current: Variant, format: Callable, value_width := 260.0, look: GameTheme = null) -> void:
	values = step_values
	_format = format
	var t := look if look else HubTheme.look()
	add_theme_constant_override("separation", int(HubTheme.GAP))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	minus = t.button("−", func(): step(-1), GameTheme.SECONDARY)
	minus.custom_minimum_size = Vector2(HubTheme.TARGET, HubTheme.TARGET)
	minus.name = "Minus"
	plus = t.button("+", func(): step(1), GameTheme.SECONDARY)
	plus.custom_minimum_size = Vector2(HubTheme.TARGET, HubTheme.TARGET)
	plus.name = "Plus"
	for b in [minus, plus]:
		b.add_theme_font_size_override("font_size", HudTheme.BIG)  # a big − and +, read at a glance
	shown = HubTheme.label("", HudTheme.MEDIUM)
	shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	shown.custom_minimum_size = Vector2(value_width, HubTheme.TARGET)
	add_child(minus)
	add_child(shown)
	add_child(plus)
	index = maxi(0, values.find(current))
	_show()


func value() -> Variant:
	return values[index] if not values.is_empty() else null


func step(delta: int) -> void:
	var next := clampi(index + delta, 0, values.size() - 1)
	if next == index:
		return
	index = next
	_show()
	GameTheme.pop(shown, 1.15, 0.25)
	changed.emit(values[index])


## Replaces the list (a new mode), keeping the nearest value.
func set_values(step_values: Array, current: Variant) -> void:
	values = step_values
	index = maxi(0, values.find(current))
	_show()


func _show() -> void:
	shown.text = _format.call(values[index]) if not values.is_empty() else ""
	minus.disabled = index <= 0
	plus.disabled = index >= values.size() - 1
	minus.modulate.a = 0.45 if minus.disabled else 1.0
	plus.modulate.a = 0.45 if plus.disabled else 1.0
