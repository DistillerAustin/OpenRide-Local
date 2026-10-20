extends Control
## The Games hub (spec §8): the idle scene and the project's main scene. One entry point inside
## Godot: the rider picks a game or circuit, sets it up, plays, comes back here and plays
## again; the whole visit records as one ride (Kotlin's GameVisitManager).
##
##   Hub (Control, full rect)
##   ├ Backdrop (TextureRect: one baked gradient)
##   ├ Screens (Control): the top screen of HubNav, built when shown, freed when left
##   ├ Waiting (Label): before the visit's first hub_state
##   ├ Dialog (ConfirmDialog, CanvasLayer 35), Toast (CanvasLayer 36)
##   └ Saved (CanvasLayer 37): "We saved your ride" after the idle guard, and the exit shade
##
## Talks to Kotlin only through `Session` (signals in, the v1.1 methods out). Screens emit what
## the rider asked for and this script acts on it. The SessionDirector swaps games in as the
## current scene and brings this scene back on the result card's "Back to games"
## (`hub_entered`). Cheap by design (spec §8.4): baked cards, no _process, 30 fps.

const ACTIVITY_MSEC := 60000  ## hub_activity at most once a minute (spec §3.3)
const REJECT_TEXT := {
	"unknown_game": "That game isn't available",
	"unsupported_mode": "That length isn't available for this game",
	"camera_unavailable": "That game needs the camera",
	"busy": "A game is still running",
	"empty_circuit": "That circuit has no games",
	"too_long": "That circuit is too long: 90 minutes at most",
}
const SCREENS := {
	HubNav.HOME: preload("res://hub/screens/HomeScreen.gd"),
	HubNav.GAME: preload("res://hub/screens/GameScreen.gd"),
	HubNav.CIRCUIT: preload("res://hub/screens/CircuitScreen.gd"),
	HubNav.SETTINGS: preload("res://hub/screens/SettingsScreen.gd"),
}

## The stack the rider left for a plan, restored when they come back (same visit only).
static var _saved_stack: Array = []
static var _saved_visit := ""
static var _last_activity_msec := -ACTIVITY_MSEC

var nav := HubNav.new()
var state: Dictionary = {}
var screen: HubScreen
var dialog: ConfirmDialog
var toast: Toast
var music: HubMusic
var queue := BakeQueue.new()
var _screens: Control
var _waiting: Label
var _saved_layer: CanvasLayer
var _saved_title: Label
var _saved_line: Label
var _exiting := false
var _idle_saved := false


func _ready() -> void:
	name = "Hub"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue.per_frame = 2
	add_child(HubTheme.backdrop())
	_screens = Control.new()
	_screens.name = "Screens"
	_screens.size = Vector2(HubTheme.W, HubTheme.H)
	_screens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_screens)
	_waiting = HubTheme.label("Getting your games ready…", HudTheme.MEDIUM, GameTheme.MUTED)
	_waiting.name = "Waiting"
	_waiting.size = Vector2(HubTheme.W, HubTheme.H)
	_waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_waiting.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_waiting)
	dialog = ConfirmDialog.new()
	add_child(dialog)
	toast = Toast.new()
	add_child(toast)
	_build_saved_layer()
	music = HubMusic.new()
	add_child(music)

	nav.changed.connect(func(_id, _args): _show_top())
	Session.hub_state_changed.connect(_on_hub_state)
	Session.plan_rejected.connect(_on_plan_rejected)
	Session.visit_ended.connect(_on_visit_ended)
	Session.visit_changed.connect(_on_visit_changed)
	Session.session_started.connect(_on_session_started)
	Session.director.hub_entered.connect(_on_hub_entered)
	dialog.visibility_changed.connect(func(): music.set_dialog(dialog.visible))

	if not Session.visit_id.is_empty() and Session.visit_id == _saved_visit:
		nav.restore(_saved_stack)
	if not Session.hub.is_empty():
		_apply_state(Session.hub)
	if Session.director.phase == SessionDirector.Phase.HUB:
		_on_hub_entered()
	print("OPENRIDE_GAMES hub ready renderer=%s adapter=%s" % [
		RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name()])


func _exit_tree() -> void:
	_saved_stack = nav.snapshot()
	_saved_visit = Session.visit_id


## Android back (Session.back): close the dialog, then a screen's own panel, then pop a screen;
## on the home screen, ask to exit. It never exits by itself.
func back() -> void:
	if dialog.visible:
		dialog.close()
	elif _saved_layer.visible:
		pass
	elif screen and screen.handle_back():
		pass
	elif not nav.pop():
		ask_exit()


## The hub is on screen (a visit started, or "Back to games"): its music plays.
func _on_hub_entered() -> void:
	music.play(state.get("audio", {}))


# --- State ---

func _on_hub_state(raw: Dictionary) -> void:
	_apply_state(raw)


func _apply_state(raw: Dictionary) -> void:
	var first := state.is_empty()
	state = HubState.normalized(raw)
	_waiting.visible = false
	music.apply_audio(state.audio)
	if _idle_saved or _exiting:
		return
	if first or screen == null:
		_show_top()
	else:
		screen.refresh(state)


func _on_visit_changed(_id: String) -> void:
	# A new visit: back home, nothing remembered from the last one.
	_saved_stack = []
	_exiting = false
	_idle_saved = false
	_saved_layer.visible = false
	nav.restore([])
	if not state.is_empty():
		_show_top()


# --- Screens ---

func _show_top() -> void:
	if state.is_empty():
		return
	if screen:
		# Hidden and freed at the frame's end, in the tree meanwhile (never an orphan; a tap's
		# own signal may still be running in it).
		screen.visible = false
		screen.queue_free()
	var top := nav.top()
	var id := str(top.id)
	if id == HubNav.GAME and not HubState.playable(state, HubState.entry(state, str(top.args.get("game_id", "")))):
		nav.restore([])  # the game left the catalog or lost the camera
		top = nav.top()
		id = HubNav.HOME
	screen = SCREENS[id].new()
	screen.name = id.capitalize() + "Screen"
	screen.setup(state, top.args, queue)
	screen.open.connect(func(sid: String, sargs: Dictionary): nav.push(sid, sargs))
	screen.back.connect(func(): nav.pop())
	screen.start.connect(_start)
	screen.exit_requested.connect(ask_exit)
	screen.set_ftp_requested.connect(_ask_set_ftp)
	screen.setting.connect(func(key: String, value: Variant): Session.update_setting(key, value))
	screen.notice.connect(func(text: String): toast.show_text(text))
	if screen is HomeScreen:
		(screen as HomeScreen).camera_explain.connect(_explain_camera)
	if screen is SettingsScreen:
		(screen as SettingsScreen).volume_preview.connect(music.preview_volume)
	# No fade: the bakes draw premultiplied (a faded parent would brighten them), and each
	# card appears as its bake renders (two a frame) anyway.
	_screens.add_child(screen)
	AudioDirector.play_sfx("click", -12.0)


func _start(request: Dictionary) -> void:
	Session.start_plan(request)


func _on_session_started(_plan: Dictionary) -> void:
	if screen:
		screen.start_answered()
	music.leave()


func _on_plan_rejected(reason: Dictionary) -> void:
	if screen:
		screen.start_answered()
	toast.show_text(REJECT_TEXT.get(str(reason.get("reason", "")), "That couldn't start"), 3.0, GameTheme.WARN.darkened(0.35))
	music.duck_moment(3.0)


# --- Dialogs ---

## Exit games (spec §8.3): confirmed, with what will happen to the ride.
func ask_exit() -> void:
	_disconnect_dialog()
	var visit: Dictionary = state.get("visit", {})
	var games := 0
	for p in visit.get("plans", []):
		games += (p.get("game_ids", []) as Array).size()
	if not bool(visit.get("recording", true)):
		dialog.ask("Exit games?", "This visit isn't being recorded.", "Keep playing", "Exit")
	elif float(visit.get("gameplay_sec", 0)) >= 60.0:
		dialog.ask("Exit games?", "Your ride (%s, %d %s) will be saved." % [HubTheme.clock(float(visit.get("ride_sec", 0))), games,
			"game" if games == 1 else "games"], "Keep playing", "Exit and save")
	else:
		dialog.ask("Exit games?", "Nothing's been recorded yet.", "Keep playing", "Exit")
	dialog.confirmed.connect(_exit.bind("app"), CONNECT_ONE_SHOT)


func _ask_set_ftp() -> void:
	_disconnect_dialog()
	dialog.ask("Set your FTP?", "Games close and your ride so far is saved. Come back any time.",
		"Keep playing", "Set FTP", GameTheme.PRIMARY)
	dialog.confirmed.connect(_exit.bind("edit_profile"), CONNECT_ONE_SHOT)


## A dimmed game: why, and the one fix the rider can make here.
func _explain_camera(game_id: String) -> void:
	_disconnect_dialog()
	var info := GameRegistry.info(game_id)
	var title := "%s needs the camera" % (info.title if info else game_id)
	if not bool(state.settings.camera_games):
		dialog.ask(title, "Camera games are off in Settings.", "Not now", "Turn them on", GameTheme.PRIMARY)
		dialog.confirmed.connect(func(): Session.update_setting("camera_games", true), CONNECT_ONE_SHOT)
	elif str(state.camera.permission) == "ask":
		dialog.ask(title, "OpenRide needs your permission to use the camera.", "Not now", "Allow camera", GameTheme.PRIMARY)
		dialog.confirmed.connect(Session.request_camera_permission, CONNECT_ONE_SHOT)
	elif str(state.camera.permission) == "denied":
		dialog.ask(title, "Allow the camera for OpenRide in Android's settings, then come back.", "OK", "")
	else:
		dialog.ask(title, "The camera isn't working right now. Try the other games.", "OK", "")


func _disconnect_dialog() -> void:
	for c in dialog.confirmed.get_connections():
		dialog.confirmed.disconnect(c.callable)


func _exit(next: String) -> void:
	_exiting = true
	_show_saved("Saving your ride…", "", false)
	Session.exit_hub(next)


# --- The end of a visit ---

func _on_visit_ended(result: Dictionary) -> void:
	var saved := bool(result.get("saved", false))
	music.duck_moment(2.0)
	if str(result.get("next", "app")) == "hub":
		# The idle guard saved the ride while the hub showed: a tap starts a new visit.
		_idle_saved = true
		_show_saved("We saved your ride" if saved else "We're still here", "Tap to keep playing", true)
		return
	_show_saved("Ride saved" if saved else "Nothing to save", "See you soon", false)
	toast.show_text("Ride saved" if saved else "Nothing was recorded", 1.0, GameTheme.GOOD.darkened(0.45) if saved else null)


func _build_saved_layer() -> void:
	_saved_layer = CanvasLayer.new()
	_saved_layer.name = "Saved"
	_saved_layer.layer = 37
	_saved_layer.visible = false
	add_child(_saved_layer)
	var shade := Button.new()  # the whole screen is the tap target after the idle save
	shade.focus_mode = Control.FOCUS_NONE
	shade.size = Vector2(HubTheme.W, HubTheme.H)
	var shade_style := StyleBoxFlat.new()
	shade_style.bg_color = Color(HubTheme.look().ink.darkened(0.5), 0.9)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		shade.add_theme_stylebox_override(st, shade_style)
	shade.pressed.connect(_on_saved_tapped)
	_saved_layer.add_child(shade)
	var center := CenterContainer.new()
	center.size = Vector2(HubTheme.W, HubTheme.H)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_saved_layer.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", HubTheme.look().card_style())
	card.custom_minimum_size = Vector2(1000, 0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	_saved_title = HubTheme.look().hero("", HudTheme.BIG, GameTheme.GOOD_GRADIENT, true)
	_saved_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_saved_title)
	_saved_line = HubTheme.label("", HudTheme.MEDIUM, GameTheme.MUTED)
	_saved_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_saved_line)


func _show_saved(title: String, line: String, tappable: bool) -> void:
	_saved_title.text = title
	_saved_line.text = line
	_saved_line.visible = not line.is_empty()
	_saved_layer.visible = true
	(_saved_layer.get_child(0) as Button).disabled = not tappable
	GameTheme.slam(_saved_title, 1.3)


func _on_saved_tapped() -> void:
	if _idle_saved:
		_saved_title.text = "Starting a new ride…"
		_saved_line.visible = false
		Session.hub_activity()  # Kotlin starts a new visit


# --- Activity ---

func _input(event: InputEvent) -> void:
	var touched: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed)
	if touched and Session.director.phase == SessionDirector.Phase.HUB and not _idle_saved:
		note_activity()


## The rider touched the hub: tells Kotlin's idle guard, at most once a minute.
func note_activity() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_activity_msec >= ACTIVITY_MSEC:
		_last_activity_msec = now
		Session.hub_activity()
