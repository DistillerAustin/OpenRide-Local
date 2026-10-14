class_name KartStatus
extends PanelContainer
## Kart Race's HUD widget (#43), placeholder: one slim row in the HUD's top-centre slot.
##
##   3rd / 8   Lap 2/3   Race 2
##
## Labels change only with their values (a re-layout every frame cost frame time on the
## tablet). The presentation agent owns this file (styling, pops on position changes).

var _place: Label
var _lap: Label
var _race: Label
var _shown := ["", "", ""]


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := HudTheme.panel_style()
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.content_margin_left = 24
	style.content_margin_right = 24
	add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 28)
	add_child(row)
	_place = HudTheme.label("", HudTheme.MEDIUM)
	row.add_child(_place)
	_lap = HudTheme.label("", HudTheme.SMALL)
	_lap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_lap)
	_race = HudTheme.label("", HudTheme.SMALL, HudTheme.MUTED)
	_race.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_race)


## place: 1-based (0 = none yet); lap: the lap being driven (0 on the grid); race_text e.g.
## "Race 2" or "Final race".
func set_state(place: int, racers: int, lap: int, laps: int, race_text: String) -> void:
	_put(0, _place, "%s / %d" % [ordinal(place), racers] if place > 0 else "")
	_put(1, _lap, "Lap %d/%d" % [clampi(lap, 1, laps), laps])
	_put(2, _race, race_text)


static func ordinal(n: int) -> String:
	var suffix := "th"
	if n % 100 < 11 or n % 100 > 13:
		match n % 10:
			1: suffix = "st"
			2: suffix = "nd"
			3: suffix = "rd"
	return "%d%s" % [n, suffix]


func _put(i: int, label: Label, text: String) -> void:
	if _shown[i] != text:
		_shown[i] = text
		label.text = text
