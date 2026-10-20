class_name HubScreen
extends Control
## A hub screen (spec §8.1): one responsibility each, built from the hub's state and the
## rider's picks, freed when the rider leaves it. Screens never call Session or HubNav: they
## emit what the rider asked for, and `Hub.gd` acts on it (signals up, calls down).

signal open(id: String, args: Dictionary)  ## show another screen on top
signal back  ## leave this screen
signal start(request: Dictionary)  ## a start_plan request
signal exit_requested  ## Exit games (the hub confirms first)
signal set_ftp_requested  ## the FTP nudge (the hub confirms first)
signal setting(key: String, value: Variant)  ## an app setting (update_setting)
signal notice(text: String)  ## a one-line message (a toast)
## A confirmation (the hub's ConfirmDialog): `on_confirm` runs when the rider confirms.
signal confirm_requested(heading: String, text: String, keep_text: String, act_text: String, act_kind: String, on_confirm: Callable)

## The normalized hub_state (HubState.normalized).
var state: Dictionary = {}
var args: Dictionary = {}
var rider_id := "guest"
## The hub's bakes take turns rendering (a screen's first frame would otherwise render all).
var queue: BakeQueue


func _init() -> void:
	size = Vector2(HubTheme.W, HubTheme.H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Called once, before the screen enters the tree.
func setup(hub_state: Dictionary, screen_args: Dictionary, bake_queue: BakeQueue) -> void:
	state = hub_state
	args = screen_args
	queue = bake_queue
	rider_id = HubPrefs.rider(state)
	build()


## Builds the screen's controls.
func build() -> void:
	pass


## A new hub_state arrived while the screen shows. By default nothing changes.
func refresh(hub_state: Dictionary) -> void:
	state = hub_state


## Android back on this screen: true when the screen handled it (a panel closed).
func handle_back() -> bool:
	return false


## The top bar's Back: leaves the screen (a screen with unsaved work asks first).
func back_pressed() -> void:
	back.emit()


## A Start was answered (session_started, or plan_rejected): Start may be pressed again.
func start_answered() -> void:
	pass


## Every touch target on the screen, for hub_layout_test.
func targets() -> Array[Control]:
	var out: Array[Control] = []
	_collect(self, out)
	return out


func _collect(n: Node, out: Array[Control]) -> void:
	for c in n.get_children():
		if c is BaseButton and (c as Control).is_visible_in_tree():
			out.append(c)
		elif c is Control and not (c is SubViewport):
			_collect(c, out)


## The back pill and the screen's title, for every screen but home.
func top_bar(title: String, look: GameTheme = null) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "TopBar"
	row.position = Vector2(HubTheme.MARGIN, 15)
	row.size = Vector2(HubTheme.W - 2 * HubTheme.MARGIN, HubTheme.TARGET)
	row.add_theme_constant_override("separation", 40)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back_button := HubTheme.button("‹  Back", back_pressed, GameTheme.SECONDARY, HubTheme.BACK_SIZE)
	back_button.name = "Back"
	row.add_child(back_button)
	var t := look if look else HubTheme.look()
	var heading := t.hero(title.to_upper(), HudTheme.BIG, [], false)
	heading.name = "Title"
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(heading)
	add_child(row)
	return row


static func difficulty_picker(current: String) -> Segmented:
	var s := Segmented.new(HubPrefs.DIFFICULTIES, ["Easy", "Standard", "Hard"], current, null, 200)
	s.name = "Difficulty"
	return s
