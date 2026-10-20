class_name SlotRow
extends HBoxContainer
## One slot of the circuit builder (spec §8.3): a bar in the slot's role colour, the game and
## "2 · Work" (its place and role, in words: never colour alone), the length on a Stepper
## (−/+, no keyboard), then move up, move down and remove. 120 px tall; every button 120 px.
## The game's name area passes touches on, so a drag there scrolls the list.
##
##   SlotRow (HBox)
##   ├ Bar (Panel, the role's colour)
##   ├ Names (VBox): Title, Role
##   ├ Stepper (− 3:00 +)
##   └ Up, Down, Remove (IconButton)

signal length_changed(index: int, sec: int)
signal moved(index: int, delta: int)
signal removed(index: int)

const BAR_W := 14.0
const VALUE_W := 150.0

var index := 0
var stepper: Stepper
var up: IconButton
var down: IconButton
var remove: IconButton
var title: Label
var role_label: Label


func _init(slot_index: int, game_id: String, role: String, lengths: Array, sec: int, count: int, width: float) -> void:
	index = slot_index
	name = "Slot_%d" % slot_index
	add_theme_constant_override("separation", int(HubTheme.GAP))
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(width, HubTheme.TARGET)
	var bar := Panel.new()
	bar.name = "Bar"
	var st := StyleBoxFlat.new()
	st.bg_color = HudTheme.role_color(role)
	st.set_corner_radius_all(7)
	bar.add_theme_stylebox_override("panel", st)
	bar.custom_minimum_size = Vector2(BAR_W, HubTheme.TARGET - 16)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(bar)
	var fixed := BAR_W + (HubTheme.TARGET * 2 + VALUE_W + HubTheme.GAP * 2) + HubTheme.TARGET * 3 + HubTheme.GAP * 5
	var names_w := width - fixed
	var names := VBoxContainer.new()
	names.name = "Names"
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation", -4)
	names.custom_minimum_size = Vector2(names_w, HubTheme.TARGET)
	names.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(names)
	var text := HubTheme.fit_title(game_id, names_w)
	title = HubTheme.label(text, HomeScreen.fit_size(text, HubTheme.CARD_TITLE, names_w), GameTheme.INK)
	title.name = "Title"
	title.clip_text = true
	title.custom_minimum_size = Vector2(names_w, 0)
	names.add_child(title)
	role_label = HubTheme.label("%d · %s" % [slot_index + 1, HudTheme.role_name(role)], HudTheme.SMALL, GameTheme.MUTED)
	role_label.name = "Role"
	names.add_child(role_label)
	stepper = Stepper.new(lengths, sec, func(v): return HudTheme.clock(float(v)), VALUE_W)
	stepper.name = "Stepper"
	stepper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stepper.changed.connect(func(v): length_changed.emit(index, int(v)))
	add_child(stepper)
	up = IconButton.new("up", func(): moved.emit(index, -1))
	down = IconButton.new("down", func(): moved.emit(index, 1))
	remove = IconButton.new("remove", func(): removed.emit(index))
	for b in [up, down, remove]:
		add_child(b)
	up.set_enabled(slot_index > 0)
	down.set_enabled(slot_index < count - 1)


func buttons() -> Array[Control]:
	return [stepper.minus, stepper.plus, up, down, remove]
