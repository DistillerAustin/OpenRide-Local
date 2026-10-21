extends Control
## The Games hub (spec §8): the idle scene and the project's main scene. One entry point inside
## Godot: the rider picks a game or circuit, sets it up, plays, comes back here and plays
## again; the whole visit records as one ride (Kotlin's GameVisitManager).
##
##   Hub (Control, full rect)
##   ├ Backdrop (TextureRect: one baked gradient)
##   ├ Screens (Control): the top screen of HubNav, built when shown, freed when left
##   ├ Waiting (Label): before the visit's first hub_state
##   ├ Calibration (CalibrationOverlay in hub mode, CanvasLayer 25): built on the first
##   │   calibration, full screen with Cancel while the hub calibrates
##   ├ Dialog (ConfirmDialog, CanvasLayer 35), Toast (CanvasLayer 36)
##   └ Saved (CanvasLayer 37): "We saved your ride" after the idle guard, and the exit shade
##
## Talks to Kotlin only through `Session` (signals in, the v1.1 methods out). Screens emit what
## the rider asked for and this script acts on it. The SessionDirector swaps games in as the
## current scene and brings this scene back on the result card's "Back to games"
## (`hub_entered`). Cheap by design (spec §8.4): baked cards, no _process, 30 fps.

## Every hub button clicks as it goes down (the rider's bike-test ask): one hook here rather
## than in each button factory, so cards, icon buttons and option cards all get it.
const TAP_SOUND := "click"
const TAP_DB := -6.0
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
	HubNav.MY_CIRCUITS: preload("res://hub/screens/MyCircuitsScreen.gd"),
	HubNav.BUILDER: preload("res://hub/screens/BuilderScreen.gd"),
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
## Calibrating from the hub (plan phase E): the chip's tap, the permission, the overlay.
var calibration := HubCalibration.new()
var calibration_overlay: CalibrationOverlay
var _screens: Control
var _waiting: Label
var _saved_layer: CanvasLayer
var _saved_title: Label
var _saved_line: Label
var _exiting := false
var _idle_saved := false
var taps := 0  ## button-down clicks played (for tests)


func _ready() -> void:
	LoadClock.mark("boot", "hub_ready_begin")
	name = "Hub"
	get_tree().node_added.connect(_on_node_added)
	SfxSynth.stream.call_deferred(TAP_SOUND)  # render the click now, not on the first tap
	# Every game's title and options, on a loader thread: the cards don't wait for them.
	GameRegistry.warm_infos.call_deferred()
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
	dialog.visibility_changed.connect(_update_duck)

	if not Session.visit_id.is_empty() and Session.visit_id == _saved_visit:
		nav.restore(_saved_stack)
	if not Session.hub.is_empty():
		_apply_state(Session.hub)
	if Session.director.phase == SessionDirector.Phase.HUB:
		_on_hub_entered()
	LoadClock.mark("boot", "hub_ready_end")
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
	elif calibration.running():
		cancel_calibration()
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
	_calibration_state()
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
	if calibration.running():
		calibration.cancel()
		_close_calibration()
	calibration = HubCalibration.new()
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
	_prefetch(id, top.args)
	screen = SCREENS[id].new()
	screen.name = id.to_pascal_case() + "Screen"
	screen.setup(state, top.args, queue)
	screen.open.connect(func(sid: String, sargs: Dictionary): nav.push(sid, sargs))
	screen.back.connect(func(): nav.pop())
	screen.start.connect(_start)
	screen.exit_requested.connect(ask_exit)
	screen.set_ftp_requested.connect(_ask_set_ftp)
	screen.setting.connect(func(key: String, value: Variant): Session.update_setting(key, value))
	screen.notice.connect(func(text: String): toast.show_text(text))
	screen.confirm_requested.connect(_confirm)
	if screen is HomeScreen:
		(screen as HomeScreen).camera_explain.connect(_explain_camera)
		(screen as HomeScreen).calibrate_requested.connect(calibrate)
	if screen is SettingsScreen:
		(screen as SettingsScreen).volume_preview.connect(music.preview_volume)
	# No fade: the bakes draw premultiplied (a faded parent would brighten them), and each
	# card appears as its bake renders (two a frame) anyway.
	_screens.add_child(screen)


## Loads the game the rider is looking at on a loader thread, so Start doesn't wait for it: the
## game's scene on its screen, a circuit's first game on the circuit's. Anywhere else, nothing is
## held (the tablet has 2 GB).
func _prefetch(id: String, args: Dictionary) -> void:
	if id == HubNav.GAME:
		GameRegistry.prefetch([str(args.get("game_id", ""))])
	elif id == HubNav.CIRCUIT:
		var slots: Array = HubState.circuit(state, str(args.get("circuit_id", ""))).get("slots", [])
		GameRegistry.prefetch([str(slots[0].get("game_id", ""))] if not slots.is_empty() and slots[0] is Dictionary else [])
	else:
		GameRegistry.release()


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


## A screen's confirmation (replace or delete a saved circuit, leave the builder unsaved).
func _confirm(heading: String, text: String, keep_text: String, act_text: String, act_kind: String, on_confirm: Callable) -> void:
	_disconnect_dialog()
	dialog.ask(heading, text, keep_text, act_text, act_kind)
	dialog.confirmed.connect(on_confirm, CONNECT_ONE_SHOT)


# --- Calibration (spec §6) ---

## The camera chip: calibrate (centre only with today's extremes), recalibrate once the visit
## is calibrated, or first ask for the permission, or explain what's in the way.
func calibrate() -> void:
	match calibration.tap(state, Time.get_ticks_msec()):
		"calibrate":
			_begin_calibration()
		"ask":
			toast.show_text("Allow the camera when Android asks", 3.0)
			Session.request_camera_permission()
		"camera_off":
			_disconnect_dialog()
			dialog.ask("Camera games are off", "Turn them on to steer by leaning, then calibrate.", "Not now",
				"Turn them on", GameTheme.PRIMARY)
			dialog.confirmed.connect(func(): Session.update_setting("camera_games", true), CONNECT_ONE_SHOT)
		"denied":
			_disconnect_dialog()
			dialog.ask("Camera not allowed", "Allow the camera for OpenRide in Android's settings, then come back.", "OK", "")


func cancel_calibration() -> void:
	if not calibration.running():
		return
	calibration.cancel()
	Session.cancel_calibration()
	_close_calibration()
	toast.show_text("Calibration cancelled", 2.0)


## Whether the hub's calibration overlay is up (for tests).
func calibrating() -> bool:
	return calibration.running()


func _begin_calibration() -> void:
	if calibration_overlay == null:
		calibration_overlay = CalibrationOverlay.new()
		calibration_overlay.name = "Calibration"
		calibration_overlay.use_hub_mode()
		calibration_overlay.cancel_pressed.connect(cancel_calibration)
		add_child(calibration_overlay)
	calibration_overlay.begin_hub()
	_update_duck()
	Session.hub_calibrate(HubCalibration.MODE, calibration.full)


func _close_calibration() -> void:
	if calibration_overlay:
		calibration_overlay.end_hub()
	_update_duck()


## A hub_state: did the permission come, or the hub's calibration end? One that can't tell yet
## (too soon after the start, or the tracker's state not polled since) is looked at once more
## shortly: Kotlin may send no other.
func _calibration_state(again := false) -> void:
	if calibration.running() and not again and (Time.get_ticks_msec() - calibration.started_msec < HubCalibration.MIN_RUN_MSEC
			or InputBus.tracker_state == InputBus.TRACKER_CALIBRATING):
		get_tree().create_timer(0.4).timeout.connect(_calibration_state.bind(true), CONNECT_ONE_SHOT)
		return
	match calibration.on_state(state, InputBus.tracker_state, Time.get_ticks_msec()):
		"calibrate":
			_begin_calibration()
		"refused":
			toast.show_text("The camera isn't allowed: camera games stay off", 3.0, GameTheme.WARN.darkened(0.35))
		"done":
			_close_calibration()
			toast.show_text("Camera ready: every camera game uses it", 3.0, GameTheme.GOOD.darkened(0.45))
			music.duck_moment(1.0)
		"failed":
			_close_calibration()
			toast.show_text("Couldn't see you: face the screen in good light, then try again", 4.0, GameTheme.WARN.darkened(0.35))


## The hub's music ducks under a dialog and under the calibration (spec §8.5).
func _update_duck() -> void:
	music.set_dialog(dialog.visible or calibration.running())


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


func _on_node_added(node: Node) -> void:
	if node is BaseButton and is_ancestor_of(node) and not node.button_down.is_connected(_tap):
		(node as BaseButton).button_down.connect(_tap)


func _tap() -> void:
	taps += 1
	AudioDirector.play_sfx(TAP_SOUND, TAP_DB)
