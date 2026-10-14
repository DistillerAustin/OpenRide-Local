class_name KartRaceBoard
extends CanvasLayer
## The results board between races, and the final standings (#43), placeholder: a centred panel
## of plain text, shown without any touch needed. The presentation agent owns this file
## (RaceBoard: results, GP standings, the podium with confetti).

const LAYER := 9  ## under the HUD (10), over the 3D view

var _panel: PanelContainer
var _title: Label
var _body: Label


func _init() -> void:
	layer = LAYER
	visible = false
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", HudTheme.panel_style(HudTheme.CARD, 32))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.custom_minimum_size = Vector2(980, 0)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 12)
	_panel.add_child(box)
	_title = HudTheme.label("", HudTheme.MEDIUM)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_body = HudTheme.label("", HudTheme.SMALL)
	box.add_child(_body)


## rows: [{name, detail}] in order; shown as "1st  Name  detail".
func show_board(title: String, rows: Array) -> void:
	_title.text = title
	var lines := PackedStringArray()
	for i in rows.size():
		lines.append("%-5s %-10s %s" % [KartStatus.ordinal(i + 1), rows[i].name, rows[i].detail])
	_body.text = "\n".join(lines)
	visible = true
	_panel.reset_size()
	_panel.position = Vector2((HudTheme.W - _panel.size.x) * 0.5, 230.0)


func hide_board() -> void:
	visible = false
