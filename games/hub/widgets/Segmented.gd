class_name Segmented
extends HBoxContainer
## All choices side by side (2-4 short ones, spec §7.1): the chosen one is a primary pill, the
## rest secondary. A tap picks at once; no keyboard focus.

signal changed(value: String)

const MIN_WIDTH := 200.0

var choices: Array = []
var value := ""
var buttons: Array[Button] = []
var _theme: GameTheme


func _init(choice_values: Array, labels: Array, current: String, look: GameTheme = null, min_width := MIN_WIDTH) -> void:
	choices = choice_values
	value = current if current in choices else str(choices[0]) if not choices.is_empty() else ""
	_theme = look if look else HubTheme.look()
	add_theme_constant_override("separation", int(HubTheme.GAP))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in choices.size():
		var v := str(choices[i])
		var b := _theme.button(str(labels[i]) if i < labels.size() else v, func(): pick(v), GameTheme.SECONDARY)
		b.custom_minimum_size = Vector2(min_width, HubTheme.TARGET)
		b.name = "Choice_" + v
		buttons.append(b)
		add_child(b)
	_restyle()


## Picks `v` (a tap, or the hub restoring a pick); emits `changed` when it differs.
func pick(v: String) -> void:
	if v == value or v not in choices:
		return
	value = v
	_restyle()
	GameTheme.pop(buttons[choices.find(v)], 1.08, 0.25)
	changed.emit(v)


## Shows `v` as picked without emitting (the state confirming a pick).
func show_value(v: String) -> void:
	if v != value and v in choices:
		value = v
		_restyle()


func _restyle() -> void:
	for i in buttons.size():
		_theme.style_button(buttons[i], GameTheme.PRIMARY if str(choices[i]) == value else GameTheme.SECONDARY)
