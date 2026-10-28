class_name ConfirmDialog
extends CanvasLayer
## A confirmation over the hub (spec §8.3: Exit games; leaving to set the FTP; later, deleting a
## saved circuit). A shade takes every touch; the card has a title, a line and two buttons far
## apart: the safe one on the left, the one that acts on the right. Nothing irreversible is one
## tap away, and a tap on the shade does nothing (only a button closes it).

signal confirmed
signal cancelled

const LAYER := 35
const CARD_WIDTH := 1160.0
const BUTTON_SIZE := Vector2(460, 130)

var title: Label
var line: Label
var keep_button: Button
var act_button: Button
var _card: PanelContainer


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(HubTheme.look().ink.darkened(0.5), 0.78)
	Stage.bleed(shade)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", HubTheme.look().card_style())
	_card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 30)
	_card.add_child(box)
	title = HubTheme.label("", HudTheme.BIG)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	HubTheme.look().set_gradient(title)
	box.add_child(title)
	line = HubTheme.label("", HudTheme.BODY, GameTheme.MUTED, true)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(CARD_WIDTH - 80, 0)
	box.add_child(line)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	box.add_child(row)
	keep_button = HubTheme.button("", _cancel, GameTheme.GO, BUTTON_SIZE)
	keep_button.name = "Keep"
	act_button = HubTheme.button("", _confirm, GameTheme.DANGER, BUTTON_SIZE)
	act_button.name = "Act"
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(keep_button)
	row.add_child(gap)
	row.add_child(act_button)


## Shows the question. `act_kind` is DANGER for what ends something, PRIMARY otherwise.
func ask(heading: String, text: String, keep_text: String, act_text: String, act_kind := GameTheme.DANGER) -> void:
	title.text = heading
	line.text = text
	keep_button.text = keep_text
	act_button.text = act_text
	act_button.visible = not act_text.is_empty()  # an explanation: one button closes it
	HubTheme.look().style_button(act_button, act_kind)
	visible = true
	_card.reset_size()
	_card.position = (Vector2(HubTheme.W, HubTheme.H) - _card.get_combined_minimum_size()) / 2.0
	GameTheme.slam(_card, 1.12, 0.3)


func close() -> void:
	visible = false


func _cancel() -> void:
	close()
	cancelled.emit()


func _confirm() -> void:
	close()
	confirmed.emit()
