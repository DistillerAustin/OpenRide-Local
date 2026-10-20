class_name GameScreen
extends HubScreen
## One game's screen (spec §8.3): Back and the game's name, its picture, how to play and the
## rider's best on the left, with the game's own options under them (GameInfo.options, each a
## cycle button for now: plan phase C adds `segmented` and `cards` kinds and a "More options"
## panel in this column); Length, Difficulty and Start on the right, Start at the bottom right.
## Every tap is saved at once (HubPrefs for the hub's picks, GameOptions for the game's).
## There's no auto-start: Start sends `start_plan`, and it waits for the answer.
##
##   GameScreen
##   ├ TopBar: Back, title (the game's gradient)
##   ├ Left (VBox): Poster (HubCard, baked), How-to, Best, OPTIONS heading, Options (GridContainer)
##   └ Right (VBox): LENGTH, LengthPicker, DIFFICULTY, Segmented, spacer, Start

const LEFT_WIDTH := 1040.0
const RIGHT_X := 1180.0
const BODY_TOP := 175.0
const POSTER := Vector2(1040, 300)

var game_id := ""
var entry: Dictionary = {}
var info: GameInfo
var look: GameTheme
var pick: Dictionary = {}
var length_picker: LengthPicker
var difficulty: Segmented
var start_button: Button
var options_grid: GridContainer
var _best_label: Label
var _stars: StarRow
var _waiting := false


func build() -> void:
	game_id = str(args.get("game_id", ""))
	entry = HubState.entry(state, game_id)
	info = GameRegistry.info(game_id)
	look = HubTheme.game_look(game_id)
	pick = HubPrefs.game_pick(rider_id, entry)
	top_bar(info.title if info else str(entry.get("title", game_id)), look)

	var left := VBoxContainer.new()
	left.name = "Left"
	left.position = Vector2(HubTheme.MARGIN, BODY_TOP)
	left.size = Vector2(LEFT_WIDTH, HubTheme.H - BODY_TOP - 40)
	left.add_theme_constant_override("separation", 18)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(left)
	left.add_child(HubCard.new(_poster(), POSTER, queue, false))
	var options: Array = info.options if info else []
	if not options.is_empty():
		left.add_child(HubTheme.heading("Your game"))
		options_grid = GridContainer.new()
		options_grid.name = "Options"
		options_grid.columns = 2
		options_grid.add_theme_constant_override("h_separation", int(HubTheme.GAP))
		options_grid.add_theme_constant_override("v_separation", int(HubTheme.GAP))
		left.add_child(options_grid)
		for spec in options:
			var current := GameOptions.get_value(info, str(spec.key), rider_id)
			var cycle := OptionCycle.new(spec, current)
			cycle.set_width((LEFT_WIDTH - HubTheme.GAP) / 2.0)
			cycle.changed.connect(func(key: String, value: String): GameOptions.set_value(info, key, value, rider_id))
			options_grid.add_child(cycle)

	var right := VBoxContainer.new()
	right.name = "Right"
	right.position = Vector2(RIGHT_X, BODY_TOP)
	right.size = Vector2(HubTheme.W - HubTheme.MARGIN - RIGHT_X, HubTheme.H - BODY_TOP - 40)
	right.add_theme_constant_override("separation", 18)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(right)
	right.add_child(HubTheme.heading("Length"))
	length_picker = LengthPicker.new(entry, pick)
	length_picker.changed.connect(func(mode: String, length: int):
		pick.mode = mode
		pick.length = length
		HubPrefs.set_game_pick(rider_id, game_id, pick)
		_show_best())
	right.add_child(length_picker)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(gap)
	right.add_child(HubTheme.heading("Difficulty"))
	difficulty = difficulty_picker(str(pick.difficulty))
	difficulty.changed.connect(func(d: String):
		pick.difficulty = d
		HubPrefs.set_game_pick(rider_id, game_id, pick)
		_show_best())
	right.add_child(difficulty)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(spacer)
	start_button = look.button("Start", _start, GameTheme.GO)
	start_button.name = "Start"
	start_button.custom_minimum_size = HubTheme.START_SIZE
	start_button.add_theme_font_size_override("font_size", HudTheme.MEDIUM)
	start_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	right.add_child(start_button)
	_show_best()


## The poster: the picture, how to play and the best at the picked length and difficulty.
func _poster() -> Control:
	var panel := PanelContainer.new()
	var style := HomeScreen.card_style(look)
	style.content_margin_right = 30
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	panel.add_child(row)
	var pic_h := POSTER.y - HubTheme.PICTURE_INSET - 10 - 4
	row.add_child(HubArt.picture(game_id, Vector2(pic_h * 16.0 / 9.0, pic_h), HubTheme.CARD_RADIUS - HubTheme.PICTURE_INSET))
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 14)
	row.add_child(col)
	var how := HubTheme.label(info.how_to if info else "", HudTheme.BODY, GameTheme.INK, true)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.custom_minimum_size = Vector2(POSTER.x - pic_h * 16.0 / 9.0 - 70, 0)
	col.add_child(how)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 14)
	col.add_child(chips)
	if bool(entry.get("uses_camera", false)):
		chips.add_child(_chip("Lean to steer"))
	var best_row := HBoxContainer.new()
	best_row.add_theme_constant_override("separation", 14)
	col.add_child(best_row)
	_best_label = HubTheme.label("", HudTheme.SMALL, GameTheme.TARGET, true)
	best_row.add_child(_best_label)
	_stars = StarRow.new(0, 34.0)
	_stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	best_row.add_child(_stars)
	return panel


func _chip(text: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", look.badge_style(null, true))
	chip.add_child(HubTheme.label(text, HudTheme.SMALL, GameTheme.INK, true))
	return chip


## The plan id Kotlin will give this pick (SessionPlans.justRide), for its best.
static func plan_id(game: String, mode: String, length: int) -> String:
	match mode:
		"minutes":
			return "just-ride:%s:minutes:%d" % [game, length]
		"rounds":
			return "just-ride:%s:rounds:%d" % [game, length]
	return "just-ride:%s:open" % game


func _show_best() -> void:
	if _best_label == null:
		return
	var best := HubState.just_ride_best(state, game_id, plan_id(game_id, str(pick.mode), int(pick.length)), str(pick.difficulty))
	if best.is_empty():
		_best_label.text = "No best yet at this length"
		_best_label.add_theme_color_override("font_color", GameTheme.MUTED)
		_stars.visible = false
	else:
		_best_label.text = "Your best here: %d" % best.score
		_best_label.add_theme_color_override("font_color", GameTheme.TARGET)
		_stars.stars = mini(3, best.stars)
		_stars.visible = true


func refresh(hub_state: Dictionary) -> void:
	state = hub_state
	_show_best()


## The start_plan request for the current pick.
func request() -> Dictionary:
	var r := {"kind": "just_ride", "game_id": game_id, "mode": str(pick.mode), "difficulty": str(pick.difficulty)}
	if str(pick.mode) != "open":
		r["length"] = int(pick.length)
	return r


func _start() -> void:
	if _waiting:
		return
	_waiting = true
	start_button.disabled = true
	start_button.text = "Starting…"
	start.emit(request())


func start_answered() -> void:
	_waiting = false
	start_button.disabled = false
	start_button.text = "Start"
