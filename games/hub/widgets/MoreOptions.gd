class_name MoreOptions
extends PanelContainer
## The game screen's "More options" panel (spec §8.3): a game's grouped options (any `group`
## other than ""), the ones a rider sets once and forgets, shown over the screen's left column
## with Done. Each is an OptionRow; a pick is saved by the screen at once. Groups keep their
## declared order; a group's name heads its rows when the game declares more than one group.
##
##   MoreOptions (PanelContainer, the left column's rect)
##   └ VBox: Heading, (Group heading,) OptionRow …, spacer, Done

signal changed(key: String, value: String)
signal done

var rows: Dictionary = {}  ## option key → OptionRow
var done_button: Button


## `options` are the grouped ones; `value_of(key) -> String` reads each one's current value.
func _init(options: Array, value_of: Callable, panel_size: Vector2, look: GameTheme = null) -> void:
	name = "MoreOptions"
	var t := look if look else HubTheme.look()
	custom_minimum_size = panel_size
	size = panel_size
	mouse_filter = Control.MOUSE_FILTER_STOP  # the cards under it take no taps
	var style := HomeScreen.card_style(t)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 20
	style.content_margin_bottom = 30
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(HubTheme.GAP))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	box.add_child(HubTheme.heading("More options"))
	var groups: Array = []
	for o in options:
		if str(o.get("group", "")) not in groups:
			groups.append(str(o.get("group", "")))
	var width := panel_size.x - 60
	for g in groups:
		if groups.size() > 1:
			box.add_child(HubTheme.label(g, HudTheme.SMALL, GameTheme.MUTED))
		for o in options.filter(func(x): return str(x.get("group", "")) == g):
			var row := OptionRow.new(o, str(value_of.call(str(o.key))), width, t)
			row.changed.connect(func(k: String, v: String): changed.emit(k, v))
			box.add_child(row)
			rows[str(o.key)] = row
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spacer)
	done_button = t.button("Done", func(): done.emit(), GameTheme.PRIMARY)
	done_button.name = "Done"
	done_button.custom_minimum_size = Vector2(300, HubTheme.TARGET)
	done_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN  # far from Start (bottom right)
	box.add_child(done_button)
