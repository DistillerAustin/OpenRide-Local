class_name OptionCycle
extends Button
## One game option as a single button that steps to the next choice on each tap (spec §7.1,
## `kind: cycle`, the pause card's control): "Assist  ·  Low ›". The pick is saved at once
## (GameOptions, per rider). Rich `segmented`/`cards` kinds come with plan phase C.

signal changed(key: String, value: String)

var spec: Dictionary
var value := ""


func _init(option: Dictionary, current: String, look: GameTheme = null) -> void:
	spec = option
	value = current
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(380, HubTheme.TARGET)
	name = "Option_" + str(option.get("key", ""))
	(look if look else HubTheme.look()).style_button(self, GameTheme.SECONDARY)
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	pressed.connect(_next)
	_show()


## Sets the button's width and fits its text to it.
func set_width(width: float) -> void:
	custom_minimum_size = Vector2(width, HubTheme.TARGET)
	_show()


func _next() -> void:
	value = GameOptions.next_choice(spec, value)
	_show()
	GameTheme.pop(self, 1.05, 0.25)
	changed.emit(str(spec.key), value)


func _show() -> void:
	text = "%s:  %s" % [spec.get("label", spec.get("key", "")), GameOptions.label_for(spec, value)]
	# The longest choices shrink to fit (never under HudTheme.SMALL) rather than lose their end.
	add_theme_font_size_override("font_size", HomeScreen.fit_size(text, HudTheme.BUTTON_FONT, custom_minimum_size.x - 64))
