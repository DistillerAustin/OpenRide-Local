class_name HubHeader
extends Control
## The home screen's header (spec §8.3), 150 px: the rider (avatar, name, the ride so far),
## live "88 rpm · 142 W", the camera's state, ♪ (the rider's own music, while their app has a
## track: opens the music panel), Settings and, at the far right, Exit games.
##
## Cheap by design (spec §8.4): the rider, the metrics and the camera chip are three bakes (one
## draw call each); the live metrics update on a 0.5 s Timer and touch their label only when
## the value changes, so the metrics bake re-renders at most twice a second and never while
## the rider is still. No _process.

signal settings_pressed
signal music_pressed
signal exit_pressed
## The camera chip was tapped: the hub calibrates, recalibrates, asks for the permission or
## explains (plan phase E).
signal camera_pressed

# Sized so the row fits 1808 px with ♪ showing: the right-hand items share one gap each, and
# each is a little narrower than before ♪ (rider 560, metrics 380, camera 330, Exit 300).
const RIDER_SIZE := Vector2(546, 120)
const METRICS_SIZE := Vector2(350, 104)
const CAMERA_SIZE := Vector2(300, HubTheme.TARGET)
const EXIT_SIZE := Vector2(250, HubTheme.TARGET)
const METRICS_SEC := 0.5

var avatar: AvatarView
var name_label: Label
var ride_label: Label
var metrics_label: Label
var camera_label: Label
var camera_card: HubCard
var camera_dot: Panel
var camera_caption: Label
var music_button: IconButton
var settings_button: Button
var exit_button: Button
var bakes: Array[HubCard] = []
var _timer: Timer
var _metrics_text := ""


func _init(queue: BakeQueue = null) -> void:
	name = "HubHeader"
	size = Vector2(HubTheme.W, HubTheme.HEADER_H)
	custom_minimum_size = size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.position = Vector2(HubTheme.MARGIN, 0)
	row.size = Vector2(HubTheme.W - 2 * HubTheme.MARGIN, HubTheme.HEADER_H)
	row.add_theme_constant_override("separation", int(HubTheme.GAP))
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	# The rider.
	var rider := HBoxContainer.new()
	rider.add_theme_constant_override("separation", 24)
	avatar = AvatarView.new(108)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rider.add_child(avatar)
	var names := VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation", -4)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rider.add_child(names)
	name_label = HubTheme.label("", HudTheme.MEDIUM)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	names.add_child(name_label)
	ride_label = HubTheme.label("", HudTheme.SMALL, GameTheme.MUTED)
	ride_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ride_label.clip_text = true
	names.add_child(ride_label)
	_add_bake(row, rider, RIDER_SIZE)

	# Everything else sits right, in its own row: one gap from the rider instead of a spacer's two.
	var right := HBoxContainer.new()
	right.name = "Right"
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_theme_constant_override("separation", int(HubTheme.GAP))
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(right)
	row = right

	# Live metrics: a slim panel, the number upright.
	var metrics := PanelContainer.new()
	var mstyle := HubTheme.look().panel_style(Color(HubTheme.look().ink, 0.7), 0.0, 22)
	mstyle.border_color = Color(1, 1, 1, 0.18)
	metrics.add_theme_stylebox_override("panel", mstyle)
	metrics_label = HubTheme.label("0 rpm · 0 W", HudTheme.BODY, GameTheme.INK, true)
	metrics_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	metrics_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	metrics.add_child(metrics_label)
	_add_bake(row, metrics, METRICS_SIZE)

	# The camera: its state on top, what a tap does under it ("Calibrate", "Recalibrate").
	var camera := PanelContainer.new()
	var cstyle := HubTheme.look().panel_style(Color(HubTheme.look().ink, 0.85), 0.0, 22)
	cstyle.border_color = HubTheme.look().accent  # a pill's edge: it's a button
	cstyle.set_border_width_all(4)
	camera.add_theme_stylebox_override("panel", cstyle)
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 14)
	crow.alignment = BoxContainer.ALIGNMENT_CENTER
	camera.add_child(crow)
	camera_dot = Panel.new()  # a round dot beside the word
	var dot := StyleBoxFlat.new()
	dot.set_corner_radius_all(14)
	dot.anti_aliasing = true
	camera_dot.add_theme_stylebox_override("panel", dot)
	camera_dot.custom_minimum_size = Vector2(26, 26)
	camera_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	crow.add_child(camera_dot)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", -6)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	crow.add_child(words)
	camera_caption = HubTheme.label("CAMERA", HudTheme.SMALL, GameTheme.MUTED, true)
	words.add_child(camera_caption)
	camera_label = HubTheme.label("", HudTheme.SMALL, GameTheme.INK, true)
	words.add_child(camera_label)
	camera_card = _add_bake(row, camera, CAMERA_SIZE, true)
	camera_card.name = "Camera"
	camera_card.hit.name = "Camera"
	camera_card.pressed.connect(func(): camera_pressed.emit())

	music_button = IconButton.new("music", func(): music_pressed.emit())
	music_button.visible = not Session.now_playing.is_empty()
	Session.now_playing_changed.connect(func(track: Dictionary): music_button.visible = not track.is_empty())
	row.add_child(music_button)

	settings_button = GearButton.new()
	settings_button.pressed.connect(func(): settings_pressed.emit())
	settings_button.name = "Settings"
	settings_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(settings_button)
	exit_button = HubTheme.button("Exit games", func(): exit_pressed.emit(), GameTheme.DANGER, EXIT_SIZE)
	exit_button.name = "Exit"
	exit_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(exit_button)

	_timer = Timer.new()
	_timer.wait_time = METRICS_SEC
	_timer.timeout.connect(update_metrics)
	add_child(_timer)


func _ready() -> void:
	_timer.start()
	update_metrics()


## Fills the header from a normalized hub_state.
func set_state(state: Dictionary) -> void:
	avatar.set_rider(state.rider)
	var rider_name := str(state.rider.get("name", "")).strip_edges()
	name_label.text = rider_name if not rider_name.is_empty() else "Guest"
	ride_label.text = HubState.ride_line(state)
	var chip := camera_chip(state)
	camera_label.text = chip.text
	camera_caption.text = chip.caption
	(camera_dot.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = chip.color
	camera_dot.queue_redraw()


## The camera chip: its state (the caption), what a tap does (the text) and the dot's colour
## (never colour alone: the words say it).
static func camera_chip(state: Dictionary) -> Dictionary:
	var cam: Dictionary = state.camera
	if not bool(state.settings.get("camera_games", true)):
		return {"caption": "CAMERA OFF", "text": "Turn on", "color": GameTheme.MUTED}
	match str(cam.get("permission", "granted")):
		"denied":
			return {"caption": "NOT ALLOWED", "text": "How to allow", "color": GameTheme.WARN}
		"ask":
			return {"caption": "CAMERA", "text": "Allow", "color": GameTheme.WARN}
	if not bool(cam.get("available", true)):
		return {"caption": "CAN'T SEE YOU", "text": "Try again", "color": GameTheme.WARN}
	if not str(cam.get("calibrated", "")).is_empty():
		return {"caption": "CAMERA READY", "text": "Recalibrate", "color": GameTheme.GOOD}
	return {"caption": "CAMERA", "text": "Calibrate", "color": GameTheme.TARGET}


## "88 rpm · 142 W" from the input frame, changed only when the numbers change.
func update_metrics() -> void:
	var text := metrics_text(InputBus.cadence, InputBus.power)
	if text != _metrics_text:
		_metrics_text = text
		metrics_label.text = text


static func metrics_text(cadence: float, power: float) -> String:
	return "%d rpm · %d W" % [roundi(cadence), roundi(power)]


## Every touch target in the header (for the layout test).
func targets() -> Array[Control]:
	var out: Array[Control] = [camera_card.hit, settings_button, exit_button]
	if music_button.visible:
		out.append(music_button)
	return out


func _add_bake(parent: Control, content: Control, bake_size: Vector2, interactive := false) -> HubCard:
	var card := HubCard.new(content, bake_size, null, interactive)
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(card)
	bakes.append(card)
	return card
