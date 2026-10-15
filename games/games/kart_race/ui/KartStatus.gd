class_name KartStatus
extends PanelContainer
## Kart Race's lap badge (#43), top left in KartHud (above the race clock and the racer list):
## a slanted violet badge with the lap in a gold gradient, and the race beside it.
##
##   [ LAP 2/3 ]  RACE 2
##
## Labels change only with their values (a re-layout every frame cost frame time on the
## tablet), so the race clock, which ticks every frame, lives outside the container in KartHud
## (just under this badge). The place shows in KartHud's big position badge.

var _lap_word: Label
var _lap: Label
var _laps: Label
var _race: Label
var _shown := ["", "", "", "", ""]


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 22)
	add_child(row)
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := KartTheme.badge(Color(0.36, 0.22, 0.86, 0.96), 0.22, 12, Color(0.75, 0.66, 1.0))
	style.content_margin_top = 0
	style.content_margin_bottom = 2
	badge.add_theme_stylebox_override("panel", style)
	row.add_child(badge)
	var lap_row := HBoxContainer.new()
	lap_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lap_row.add_theme_constant_override("separation", 6)
	badge.add_child(lap_row)
	_lap_word = KartTheme.label("LAP", 34)
	_lap_word.size_flags_vertical = Control.SIZE_SHRINK_END
	lap_row.add_child(_lap_word)
	_lap = KartTheme.label("1", 76)
	KartTheme.gradient(_lap, KartTheme.GOLD_TOP, KartTheme.GOLD_BOTTOM)
	lap_row.add_child(_lap)
	_laps = KartTheme.label("/3", 40)
	_laps.size_flags_vertical = Control.SIZE_SHRINK_END
	lap_row.add_child(_laps)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", -6)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(col)
	_race = KartTheme.label("", 34, KartTheme.CHIP)
	col.add_child(_race)


## place: 1-based (0 = none yet); lap: the lap being driven (0 on the grid); race_text e.g.
## "Race 2" or "Final race".
func set_state(_place: int, _racers: int, lap: int, laps: int, race_text: String) -> void:
	_put(0, _lap, str(clampi(lap, 1, laps)))
	_put(1, _laps, "/%d" % laps)
	_put(2, _race, race_text.to_upper())


static func ordinal(n: int) -> String:
	return "%d%s" % [n, KartTheme.ordinal_suffix(n)]


func _put(i: int, label: Label, text: String) -> void:
	if _shown[i] != text:
		_shown[i] = text
		label.text = text
