extends GdUnitTestSuite
## The hub's bike-first rules (spec §8.2) on every screen at 1920x1080, with the longest
## strings: every touch target at least 120 px on its shorter side (cards 180), at least 24 px
## between targets, no text under 34 px (baked text included), everything on screen, and Exit
## games and Start never on one screen. Also: the hub's bakes stop rendering once settled (no
## viewport renders on an idle frame).

const LONG_NAME := "Bartholomew Montgomery-Smythe"

var local: Node
var hub: Node


func before() -> void:
	HubPrefs.path = "user://hub_prefs_layout_test.cfg"
	HubPrefs.reload()


func after() -> void:
	HubPrefs.path = HubPrefs.DEFAULT_PATH
	HubPrefs.reload()


func before_test() -> void:
	local = Session._local
	local.process_mode = Node.PROCESS_MODE_DISABLED
	local.hub.rider.name = LONG_NAME
	local.hub.rider.ftp_is_default = true
	local.hub.settings.camera_games = true
	Session.director.phase = SessionDirector.Phase.IDLE
	local.hub.begin_visit()
	hub = get_tree().current_scene
	await _settle()


func after_test() -> void:
	local.hub.rider.name = local.hub.RIDER_NAME
	local.hub.phase = ""
	Session.visit_id = ""
	Session.hub = {}
	Session.director.phase = SessionDirector.Phase.IDLE
	local.process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.max_fps = 0


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	await get_tree().process_frame


func _settle(frames := 12) -> void:
	for i in frames:
		await get_tree().process_frame


func test_the_hub_is_the_current_scene() -> void:
	assert_str(hub.scene_file_path).is_equal(SessionDirector.IDLE_SCENE)
	assert_object(hub.screen).is_instanceof(HomeScreen)


func test_home() -> void:
	_check_screen("home")
	var home: HomeScreen = hub.screen
	for card in home.game_cards.values() + home.circuit_cards.values():
		var r: Rect2 = card.target_rect()
		assert_float(minf(r.size.x, r.size.y)).override_failure_message("a card under 180 px").is_greater_equal(HubTheme.CARD_TARGET)


func test_home_with_bests_and_without_the_camera() -> void:
	local.hub.rider.ftp_is_default = false
	local.hub.settings.camera_games = false
	local.hub.plan_bests = {"circuit-20|standard": {"score": 123456, "stars": 30}}
	local.hub.send_state()
	await _settle()
	_check_screen("home without camera")
	local.hub.plan_bests = {}
	local.hub.settings.camera_games = true


func test_every_game_screen() -> void:
	for e in HubState.games(hub.state):
		hub.nav.push(HubNav.GAME, {"game_id": e.id})
		await _settle()
		_check_screen("game " + str(e.id))
		for mode in hub.screen.length_picker.modes.choices:
			hub.screen.length_picker.modes.pick(mode)
			await _wait(0.4)  # the pick's pop (a scale) settles
			_check_screen("game %s %s" % [e.id, mode])
		hub.nav.pop()
		await _settle(2)


func test_every_circuit_screen() -> void:
	for c in hub.state.circuits:
		hub.nav.push(HubNav.CIRCUIT, {"circuit_id": c.id})
		await _settle()
		_check_screen("circuit " + str(c.id))
		hub.nav.pop()
		await _settle(2)


func test_settings() -> void:
	hub.nav.push(HubNav.SETTINGS)
	await _settle()
	_check_screen("settings")


func test_the_exit_dialog() -> void:
	hub.ask_exit()
	await _wait(0.5)  # the card's slam settles
	var d: ConfirmDialog = hub.dialog
	_check_targets("exit dialog", [d.keep_button, d.act_button])
	assert_str(d.act_button.text).is_equal("Exit")
	assert_bool(d.act_button.get_global_rect().position.x > d.keep_button.get_global_rect().end.x + 120).is_true()  # UI_STYLE §6: 120 px from the safe button
	d.close()


func test_back_steps_back_then_asks_to_exit() -> void:
	hub.nav.push(HubNav.SETTINGS)
	await _settle(2)
	Session.back()
	assert_str(hub.nav.top_id()).is_equal(HubNav.HOME)
	Session.back()
	assert_bool(hub.dialog.visible).is_true()
	Session.back()  # back closes the dialog: never exits by itself
	assert_bool(hub.dialog.visible).is_false()
	assert_array(local.hub_calls.filter(func(c): return c[0] == "exit_hub")).is_empty()


func test_bakes_go_quiet_when_settled() -> void:
	await _settle(30)
	var bakes := _bakes(hub)
	assert_int(bakes.size()).is_greater(8)
	var before := _renders(bakes)
	await _settle(20)
	assert_int(_renders(bakes)).override_failure_message("a bake rendered on an idle frame").is_equal(before)
	for b in bakes:
		assert_bool(b.is_pending()).is_false()


func test_the_frame_cap_in_the_hub() -> void:
	assert_int(Engine.max_fps).is_equal(SessionDirector.HUB_MAX_FPS)


# --- Checks ---

func _check_screen(what: String) -> void:
	var screen: HubScreen = hub.screen
	var targets: Array = screen.targets()
	assert_bool(targets.is_empty()).is_false()
	_check_targets(what, targets)
	var names := targets.map(func(t): return str(t.name))
	assert_bool("Exit" in names and "Start" in names).override_failure_message("%s: Exit and Start on one screen" % what).is_false()
	_check_text(what, screen)
	for card in screen.find_children("*", "Control", true, false).filter(func(n): return n is HubCard):
		var c: HubCard = card
		assert_bool(c.content.size.x <= c.size.x + 0.5 and c.content.size.y <= c.size.y + 0.5) \
			.override_failure_message("%s: %s's content %s overflows its bake %s" % [what, c.name, c.content.size, c.size]).is_true()


func _check_targets(what: String, targets: Array) -> void:
	var screen_rect := Rect2(0, 0, HubTheme.W, HubTheme.H)
	var rects: Array[Rect2] = []
	for t in targets:
		var r: Rect2 = (t as Control).get_global_rect()
		assert_float(minf(r.size.x, r.size.y)).override_failure_message("%s: %s is %s, under 120 px" % [what, t.name, r.size]).is_greater_equal(HubTheme.TARGET)
		assert_bool(screen_rect.encloses(r)).override_failure_message("%s: %s %s is off screen" % [what, t.name, r]).is_true()
		rects.append(r)
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			var gap := _gap(rects[i], rects[j])
			assert_float(gap).override_failure_message("%s: %s and %s are %.0f px apart" % [what, targets[i].name, targets[j].name, gap]).is_greater_equal(HubTheme.GAP)


## The space between two rects (negative when they overlap).
static func _gap(a: Rect2, b: Rect2) -> float:
	return maxf(maxf(b.position.x - a.end.x, a.position.x - b.end.x), maxf(b.position.y - a.end.y, a.position.y - b.end.y))


## Every label and button, baked ones too, at 34 px or more, and inside the screen.
func _check_text(what: String, root: Node) -> void:
	for n in root.find_children("*", "Control", true, false):
		var c := n as Control
		if not c.is_visible_in_tree():
			continue
		if c is Label and not (c as Label).text.is_empty():
			var fs := c.get_theme_font_size("font_size")
			assert_int(fs).override_failure_message("%s: '%s' at %d px" % [what, (c as Label).text, fs]).is_greater_equal(HudTheme.SMALL)
		elif c is Button and not (c as Button).text.is_empty():
			var bs := c.get_theme_font_size("font_size")
			assert_int(bs).override_failure_message("%s: button '%s' at %d px" % [what, (c as Button).text, bs]).is_greater_equal(HudTheme.SMALL)


func _bakes(root: Node) -> Array:
	return root.find_children("*", "TextureRect", true, false).filter(func(n): return n is BakedView)


func _renders(bakes: Array) -> int:
	var total := 0
	for b in bakes:
		total += (b as BakedView).renders
	return total
