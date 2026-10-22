class_name OptionRow
extends HBoxContainer
## One game option on the hub's game screen (spec §7.1): its label, then its control at the
## row's full width. `kind: segmented` shows every choice side by side (Segmented); `cycle` (and
## anything else outside a card grid) is one button that steps to the next choice
## (OptionCycle, value only). A pick is saved by the screen (GameOptions, per rider).
##
##   OptionRow (HBox, `width` wide, TARGET tall)
##   ├ Label (LABEL_W, the option's label)
##   └ Segmented | OptionCycle

signal changed(key: String, value: String)

const LABEL_W := 330.0

var spec: Dictionary
var key := ""
var value := ""
var segmented: Segmented
var cycle: OptionCycle


func _init(option: Dictionary, current: String, width: float, look: GameTheme = null) -> void:
	spec = option
	key = str(option.key)
	value = current
	name = "Option_" + key
	add_theme_constant_override("separation", int(HubTheme.GAP))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(width, HubTheme.TARGET)
	var text := str(option.get("label", key))
	var label := HubTheme.label(text, HomeScreen.fit_size(text, HudTheme.BODY, LABEL_W), GameTheme.INK)
	label.name = "Label"
	label.custom_minimum_size = Vector2(LABEL_W, HubTheme.TARGET)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)
	var room := width - LABEL_W - HubTheme.GAP
	var choices: Array = option.get("choices", [])
	if GameInfo.option_kind(option) == "segmented":
		var labels: Array = option.get("labels", choices)
		var each := floorf((room - HubTheme.GAP * (choices.size() - 1)) / choices.size())
		segmented = Segmented.new(choices, labels, current, look, each)
		segmented.name = "Choices"
		for b in segmented.buttons:
			b.add_theme_font_size_override("font_size", HomeScreen.fit_size(b.text, HudTheme.BUTTON_FONT, each - 72))  # the pill pads 28 a side, plus the outline
		segmented.changed.connect(func(v: String):
			value = v
			changed.emit(key, v))
		add_child(segmented)
	else:
		cycle = OptionCycle.new(option, current, look, false)
		cycle.name = "Cycle"
		cycle.set_width(room)
		cycle.changed.connect(func(_k: String, v: String):
			value = v
			changed.emit(key, v))
		add_child(cycle)
