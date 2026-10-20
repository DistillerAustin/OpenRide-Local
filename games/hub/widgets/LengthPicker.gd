class_name LengthPicker
extends VBoxContainer
## A game's standard Length option (spec §7.1): its modes (Timed, Rounds, Open: those in its
## catalog `supports`) side by side, then the minutes (`catalog.minute_steps`) or the rounds
## (`min_rounds..max_rounds`) on a Stepper. Open has no length; its stepper row keeps its place
## (faded out), so nothing below it moves.

signal changed(mode: String, length: int)

const MODE_LABELS := {"minutes": "Timed", "rounds": "Rounds", "open": "Open"}
const MODE_ORDER := ["minutes", "rounds", "open"]

var entry: Dictionary
var mode := "minutes"
var length := 0
var modes: Segmented
var stepper: Stepper
var _open_note: Label


func _init(catalog_entry: Dictionary, pick: Dictionary) -> void:
	entry = catalog_entry
	mode = str(pick.mode)
	length = int(pick.length)
	add_theme_constant_override("separation", int(HubTheme.GAP))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var supported: Array = MODE_ORDER.filter(func(m): return m in entry.get("supports", []))
	modes = Segmented.new(supported, supported.map(func(m): return MODE_LABELS[m]), mode)
	modes.name = "Modes"
	modes.changed.connect(_on_mode)
	add_child(modes)
	var row := Control.new()  # the stepper or the open note, in one fixed slot
	row.custom_minimum_size = Vector2(0, HubTheme.TARGET)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	stepper = Stepper.new(_values(mode), length if length > 0 else 0, _format)
	stepper.name = "Length"
	stepper.changed.connect(func(v): length = int(v); changed.emit(mode, length))
	row.add_child(stepper)
	_open_note = HubTheme.label("Play as long as you like", HudTheme.BODY, GameTheme.MUTED)
	_open_note.custom_minimum_size = Vector2(0, HubTheme.TARGET)
	_open_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_open_note)
	_sync()


func _on_mode(m: String) -> void:
	mode = m
	if mode != "open":
		length = HubPrefs.valid_length(entry, mode, 0)
		stepper.set_values(_values(mode), length)
	else:
		length = 0
	_sync()
	changed.emit(mode, length)


## The steps for a mode: minutes from the catalog, rounds from its limits.
func _values(m: String) -> Array:
	match m:
		"minutes":
			return (entry.get("minute_steps", [10]) as Array).map(func(v): return int(v))
		"rounds":
			return range(int(entry.get("min_rounds", 1)), int(entry.get("max_rounds", 10)) + 1)
	return [0]


func _format(v: Variant) -> String:
	match mode:
		"minutes":
			return "%d min" % int(v)
		"rounds":
			return "%d %s" % [int(v), "round" if int(v) == 1 else "rounds"]
	return ""


func _sync() -> void:
	stepper.visible = mode != "open"
	_open_note.visible = mode == "open"
	if mode != "open":
		stepper.set_values(_values(mode), length)
