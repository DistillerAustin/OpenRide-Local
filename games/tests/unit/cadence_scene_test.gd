extends GdUnitTestSuite
## Cadence Karaoke's scene with the framework: real touches on the −/+ buttons change the
## pending pace, a touch on the intro card over them does nothing, the buttons grey out at the
## pace limits and keep their touch size far from End, the target is the HUD's hero and the look
## follows the tunnel's neon (UI_POLISH.md P0.1, P1.1, P1.2).

const LocalSession := preload("res://autoload/LocalSession.gd")
const SEGMENT := {"game_id": "cadence_karaoke", "role": "warmup", "difficulty": "standard",
	"duration_sec": -1, "end_mode": "game", "seed": 3, "params": {}}

var director: SessionDirector
var local: Node
var _rider := ""
var _saved_plan := {}


func before_test() -> void:
	director = Session.director
	local = Session._local
	director.process_mode = Node.PROCESS_MODE_DISABLED
	local.process_mode = Node.PROCESS_MODE_DISABLED
	director._last_recalibrate_msec = -1
	_rider = "test%d" % Time.get_ticks_usec()
	_saved_plan = Session.plan


func after_test() -> void:
	if Session.active:
		Session.request_end()
		_step(LocalSession.GRACE_SEC + 0.1)
	director.process_mode = Node.PROCESS_MODE_ALWAYS
	local.process_mode = Node.PROCESS_MODE_ALWAYS
	director.summary_screen.visible = false
	GameOptions.forget_rider(_rider)
	Session.plan = _saved_plan


func _step(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var dt := minf(left, 0.25)
		local._process(dt)
		director._process(dt)
		left -= dt


## A finger at `at` (canvas coordinates), through the viewport like the bike: the touch and the
## mouse click Android emulates from it.
func _touch(at: Vector2) -> void:
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.position = at
		touch.pressed = pressed
		get_tree().root.push_input(touch, true)
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = at
		click.global_position = at
		click.pressed = pressed
		get_tree().root.push_input(click, true)


## A scene on its own (no session), prepared and started.
func _game() -> Game:
	Session.plan = {"rider_id": _rider}
	var game: Game = auto_free(load("res://games/cadence_karaoke/CadenceKaraoke.tscn").instantiate())
	game.hud = auto_free(Hud.new())
	add_child(game.hud)
	add_child(game)
	game.prepare(SEGMENT)
	game.start()
	return game


func _settle() -> void:
	for i in 4:
		await get_tree().process_frame


func _start_session() -> Game:
	local.start({"kind": "just_ride", "plan_id": "test", "difficulty": "standard", "total_sec": 0,
		"segments": [{"game_id": "cadence_karaoke", "role": "free", "duration_sec": 1200}]})
	_step(local.calibration_left_sec() + LocalSession.INTRO_SEC - 1.0)
	assert_int(director.phase).is_equal(SessionDirector.Phase.INTRO)
	return director.game


func test_touches_on_the_buttons_change_the_pace_but_not_through_the_intro_card() -> void:
	var game := _start_session()
	await _settle()
	var minus: Button = game.get("_minus")
	var plus: Button = game.get("_plus")
	# On the intro card, the buttons are hidden and the card's shade takes the touch.
	assert_bool(minus.is_visible_in_tree()).is_false()
	for at in [Vector2(960 - 180, 1080 - 85), Vector2(960 + 180, 1080 - 85)]:
		_touch(at)
	assert_int(game.logic.pending_adjust).is_equal(0)
	_step(1.5)
	assert_int(director.phase).is_equal(SessionDirector.Phase.PLAYING)
	await _settle()
	assert_bool(plus.is_visible_in_tree()).is_true()
	_touch(plus.get_global_rect().get_center())
	assert_int(game.logic.pending_adjust).is_equal(CadenceLogic.PACE_STEP)
	_touch(minus.get_global_rect().get_center())
	_touch(minus.get_global_rect().get_center())
	assert_int(game.logic.pending_adjust).is_equal(-CadenceLogic.PACE_STEP)


func test_the_buttons_are_big_bottom_centre_and_far_from_end() -> void:
	var game := _game()
	await _settle()
	var end_rect: Rect2 = game.hud.end_button.get_global_rect()
	for b: Button in [game.get("_minus"), game.get("_plus")]:
		var r := b.get_global_rect()
		assert_float(r.size.x).is_greater_equal(220.0)
		assert_float(r.size.y).is_greater_equal(HudTheme.BUTTON_HEIGHT)
		assert_float(r.end.y).is_equal_approx(HudTheme.H - 30.0, 1.0)
		assert_bool(r.grow(120.0).intersects(end_rect)).is_false()
		assert_int(b.focus_mode).is_equal(Control.FOCUS_NONE)
	var minus: Button = game.get("_minus")
	var plus: Button = game.get("_plus")
	# Centred about the screen's middle.
	assert_float((minus.get_global_rect().position.x + plus.get_global_rect().end.x) / 2.0).is_equal_approx(HudTheme.W / 2.0, 1.0)


func test_the_buttons_grey_out_at_the_pace_limits() -> void:
	var game := _game()
	var minus: Button = game.get("_minus")
	var plus: Button = game.get("_plus")
	while game.logic.request_pace(-1):
		pass
	game.call("_update_buttons")
	assert_bool(minus.disabled).is_true()
	assert_bool(plus.disabled).is_false()
	assert_float(minus.modulate.a).is_less(1.0)
	game.adjust_pace(1)
	assert_bool(minus.disabled).is_false()
	while game.logic.request_pace(1):
		pass
	game.call("_update_buttons")
	assert_bool(plus.disabled).is_true()


func test_the_target_is_the_hero() -> void:
	var game := _game()
	await await_millis(200)
	var status: CadenceStatus = game.get("_status")
	assert_str(status.target.text).is_equal(str(roundi(game.logic.target())))
	var hero_size := status.target.get_theme_font_size("font_size")
	assert_int(hero_size).is_equal(HudTheme.BIG)
	assert_object(status.target.material).is_not_null()  # the gradient
	for l: Label in game.hud.metrics.find_children("*", "Label", true, false):
		assert_int(l.get_theme_font_size("font_size")).is_less_equal(hero_size)
	# A pace change shows as a chip, then lands on the hero.
	game.adjust_pace(1)
	await await_millis(50)
	assert_bool(status.next_chip.visible).is_true()
	assert_str(status.next_label.text).starts_with(str(roundi(game.logic.target()) + 5))
	game.call("_on_tempo_swapped", "", 0.0)
	await await_millis(50)
	assert_str(status.target.text).is_equal(str(roundi(game.logic.target())))
	assert_bool(status.next_chip.visible).is_false()


func test_the_alert_says_which_way_and_ease_off_is_red() -> void:
	var status: CadenceStatus = auto_free(CadenceStatus.new())
	add_child(status)
	status.set_alert(CadenceStatus.ALERT_SLOW)
	assert_str(status.alert_label.text).is_equal("SLOW DOWN")
	status.set_alert(CadenceStatus.ALERT_FAST)
	assert_str(status.alert_label.text).is_equal("SPEED UP")
	status.set_alert(CadenceStatus.ALERT_EASE)
	assert_str(status.alert_label.text).is_equal("EASE OFF")
	var style: StyleBoxFlat = status.alert.get_theme_stylebox("panel")
	assert_that(style.bg_color).is_equal(GameTheme.BAD)
	status.set_alert(CadenceStatus.ALERT_NONE)
	assert_bool(status.alert.visible).is_false()


func test_the_streak_label_shows_the_max() -> void:
	var status: CadenceStatus = auto_free(CadenceStatus.new())
	add_child(status)
	status.set_info(50, 1.5)
	assert_str(status.streak.text).is_equal("×1.5")
	status.streak_up(CadenceLogic.STREAK_MULT_MAX)
	assert_str(status.streak.text).is_equal("×2!")


func test_the_look_follows_the_tunnel() -> void:
	var game := _game()
	var look: GameTheme = game.ui_theme()
	assert_that(look.accent).is_equal(CadenceWorld.THEMES.warmup)
	assert_that(look.ink).is_equal(Color("12052a"))
	game.change_option("look", "violet")
	var violet: GameTheme = game.ui_theme()
	assert_that(violet.accent).is_equal(CadenceWorld.THEMES.violet)
	var status: CadenceStatus = game.get("_status")
	var panel: StyleBoxFlat = status.get_theme_stylebox("panel")
	assert_that(panel.border_color).is_equal(violet.panel_edge)
	var hud_panel: StyleBoxFlat = game.hud.ride_panel.get_theme_stylebox("panel")
	assert_that(hud_panel.border_color).is_equal(violet.panel_edge)


## The colour option changes the look mid-segment: the game emits `ui_theme_changed`, and the
## session restyles the pause screen (where the option is picked), the intro card and the
## calibration with it, and keeps it for the summary.
func test_a_look_changed_mid_segment_reaches_the_pause_screen() -> void:
	var game := _start_session()
	var before: GameTheme = director.pause_overlay.theme
	assert_object(before).is_same(game.ui_theme())
	game.change_option("look", "violet")
	var violet: GameTheme = game.ui_theme()
	assert_object(violet).is_not_same(before)
	assert_object(director.pause_overlay.theme).is_same(violet)
	assert_object(director.intro_card.theme).is_same(violet)
	assert_object(director.calibration.theme).is_same(violet)
	assert_object(director.looks.get("cadence_karaoke")).is_same(violet)
