extends GdUnitTestSuite
## Safe Cracker's UI (games/safe_cracker/UI_POLISH.md): the status widget fits its HUD slot, the
## banner sits between the HUD and the safe without covering the dial or a HUD element, nothing
## the needle sweeps crosses the target plate or the reading, the tumbler lights stay on the door,
## and the alarm and tumbler events drive the banner and the light pop (never the HUD's centre
## message, which would sit on the dial).

const SEGMENT := {"game_id": "safe_cracker", "role": "recovery", "difficulty": "standard", "duration_sec": -1,
	"end_mode": "timer", "seed": 11, "params": {"power_cap_watts": 120.0}}
const SCREEN := Rect2(0, 0, 1920, 1080)
const SafeCrackerScript := preload("res://games/safe_cracker/SafeCracker.gd")
const STATUS_BUDGET := Vector2(850, 120)  ## UI_STYLE.md §5

var _rider := ""
var _saved_plan := {}


func before_test() -> void:
	_rider = "test%d" % Time.get_ticks_usec()
	_saved_plan = Session.plan
	Session.plan = {"rider_id": _rider}


func after_test() -> void:
	GameOptions.forget_rider(_rider)
	Session.plan = _saved_plan


func _game() -> Game:
	var game: Game = auto_free(load("res://games/safe_cracker/SafeCracker.tscn").instantiate())
	game.hud = auto_free(Hud.new())
	add_child(game.hud)
	add_child(game)
	game.prepare(SEGMENT)
	game.start()
	return game


func _settle() -> void:
	for i in 4:
		await get_tree().process_frame


## A door-space rect of the dial on the 1920x1080 canvas.
func _on_screen(r: Rect2) -> Rect2:
	return Rect2(r.position + SafeCrackerScript.BODY_HOME, r.size)


func _labels(root: Node) -> Array[Label]:
	var out: Array[Label] = []
	for n in root.find_children("*", "Label", true, false):
		out.append(n as Label)
	return out


func test_the_status_widget_fits_its_slot_with_the_longest_texts() -> void:
	var game := _game()
	var status: SafeStatus = game.get("_status")
	status.set_state(99, 12, 120.0, true, "Follow the ticks")
	await _settle()
	var size := status.get_combined_minimum_size()
	assert_float(size.x).override_failure_message("status is %s wide" % size.x).is_less_equal(STATUS_BUDGET.x)
	assert_float(size.y).override_failure_message("status is %s tall" % size.y).is_less_equal(STATUS_BUDGET.y)
	for l in _labels(status):
		assert_int(l.get_theme_font_size("font_size")).is_greater_equal(HudTheme.SMALL)
		assert_object(l.get_theme_font("font")).is_same(GameTheme.display_font(true))
	# No sentence: the cap is a short caption that turns amber, and says so, when over it.
	var power: Label = status.get("_power")
	assert_str(power.text).starts_with("OVER 120 W")
	assert_that(power.get_theme_color("font_color")).is_equal(GameTheme.WARN)
	status.set_state(99, 12, 120.0, false)
	assert_str(power.text).is_equal("MAX 120 W")
	assert_that(power.get_theme_color("font_color")).is_equal(GameTheme.MUTED)


func test_the_banner_sits_between_the_hud_and_the_safe() -> void:
	var game := _game()
	var banner: SafeBanner = game.get("_banner")
	var status: SafeStatus = game.get("_status")
	status.set_state(99, 12, 120.0, true, "Follow the ticks")
	game.hud.metrics.refresh(118, 1888, 100)
	game.hud.score.set_value("99999")
	banner.alarm_badge.visible = true
	banner.hero.text = "CRACKED! +1200"
	banner.hero.visible = true
	await _settle()
	var plate := _on_screen(SafeDial.TARGET_PLATE)
	var hud_leaves: Array[Control] = [status, game.hud.pause_button, game.hud.end_button, game.hud.clock_panel, game.hud.ride_panel]
	for c: Control in [banner.alarm_badge, banner.hero]:
		var r := c.get_global_rect()
		assert_bool(SCREEN.encloses(r)).override_failure_message("%s %s is off screen" % [c.name, r]).is_true()
		assert_float(absf(r.get_center().x - 960.0)).override_failure_message("%s isn't centred" % c.name).is_less(2.0)
		# Above the target plate (the safe's top) and so clear of the whole dial.
		assert_float(r.end.y).override_failure_message("%s %s reaches the safe (plate at %s)" % [c.name, r, plate]).is_less_equal(plate.position.y)
		for h in hud_leaves:
			assert_bool(r.grow(-0.5).intersects(h.get_global_rect().grow(-0.5))).override_failure_message(
				"%s %s overlaps %s %s" % [c.name, r, h.name, h.get_global_rect()]).is_false()
	assert_int(banner.layer).is_less(Hud.LAYER)
	assert_int(banner.alarm_label.get_theme_font_size("font_size")).is_greater_equal(HudTheme.MEDIUM)


func test_the_needle_never_crosses_the_target_or_the_reading() -> void:
	# The reading's text box (96 px, up to three digits) at the bottom of the dial.
	var reading := Rect2(-95, SafeDial.READING_BASELINE - 74, 190, 92)
	for v in range(0, 101):
		var a := SafeDial.angle_for(float(v))
		var dir := Vector2(cos(a), sin(a))
		for step in 41:
			var p := -dir * 40.0 + dir * (SafeDial.R - 12.0 + 40.0) * step / 40.0
			assert_bool(SafeDial.TARGET_PLATE.grow(6).has_point(p)).override_failure_message(
				"the needle at %d crosses the target at %s" % [v, p]).is_false()
			assert_bool(reading.has_point(p)).override_failure_message(
				"the needle at %d crosses the reading at %s" % [v, p]).is_false()


func test_the_tumbler_lights_sit_on_the_door_clear_of_the_bezel() -> void:
	var door := SafeDial.DOOR.grow(-8)  # inside its border
	var r := SafeDial.LIGHT_R * (1.0 + SafeDial.LIGHT_POP) + 4.0
	for total in range(3, 7):
		for i in total:
			var at := SafeDial.light_at(i, total)
			assert_bool(door.encloses(Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0))).override_failure_message(
				"light %d/%d at %s leaves the door" % [i, total, at]).is_true()
			assert_float(at.length() - r).override_failure_message("light %d/%d sits on the bezel" % [i, total]).is_greater(SafeDial.R + 40.0)
	assert_float(SafeDial.LIGHT_R).is_greater_equal(22.0)


func test_the_reading_is_the_hero_and_green_on_target() -> void:
	assert_int(SafeDial.READING_SIZE).is_equal(HudTheme.BIG)
	assert_int(SafeDial.READING_SIZE).is_greater(SafeDial.TARGET_SIZE)
	assert_int(SafeDial.NUMERAL_SIZE).is_greater_equal(HudTheme.SMALL)
	var dial: SafeDial = auto_free(SafeDial.new())
	dial.target = 30
	dial.tolerance = 2.0
	dial.reading = 31.5
	assert_bool(dial.on_target()).is_true()
	dial.reading = 33.0
	assert_bool(dial.on_target()).is_false()
	dial.reading = 30.0
	dial.target_hidden = true  # a hidden target never gives itself away by colour
	assert_bool(dial.on_target()).is_false()
	var source := FileAccess.get_file_as_string("res://games/safe_cracker/SafeDial.gd")
	assert_bool(source.contains("fallback" + "_font")).override_failure_message("the dial uses the engine's face").is_false()


func test_the_alarm_is_a_state_in_the_banner_not_the_hud_message() -> void:
	var game := _game()
	var banner: SafeBanner = game.get("_banner")
	var logic: SafeLogic = game.get("logic")
	logic.alarm_left = 2.0
	game._handle({"type": "alarm"})
	await _settle()
	assert_bool(banner.is_alarm_showing()).is_true()
	assert_bool(banner.alarm_badge.visible).is_true()
	assert_bool(game.hud.is_showing_message()).is_false()
	await await_millis(450)
	var body: Node2D = game.get("_body_root")
	assert_bool(body.modulate.is_equal_approx(Color.WHITE)).override_failure_message("the safe doesn't glow red").is_false()
	logic.alarm_left = 0.0
	await await_millis(500)
	assert_bool(banner.is_alarm_showing()).is_false()
	assert_bool(banner.alarm_badge.visible).is_false()
	assert_bool(body.modulate.is_equal_approx(Color.WHITE)).is_true()


func test_a_tumbler_pops_its_light_and_a_crack_slams_the_hero() -> void:
	var game := _game()
	var dial: SafeDial = game.get("_dial")
	var banner: SafeBanner = game.get("_banner")
	game._handle({"type": "tumbler", "index": 0})
	await get_tree().process_frame
	await get_tree().process_frame
	assert_float(dial.light_pop).is_greater(0.3)
	await await_millis(500)
	assert_float(dial.light_pop).is_equal(0.0)
	game._handle({"type": "vault_open", "points": 1150.0})
	await _settle()
	assert_bool(banner.hero.visible).is_true()
	assert_str(banner.hero.text).is_equal("CRACKED! +1150")
	assert_object(banner.hero.material).is_not_null()  # the gold gradient
	assert_bool(game.hud.is_showing_message()).is_false()


func test_the_theme_is_brass_and_soot_and_upright() -> void:
	var game := _game()
	var look: GameTheme = game.ui_theme()
	assert_object(look).is_not_null()
	assert_that(look.accent).is_equal(Color("e8b04a"))
	assert_that(look.ink).is_equal(Color("14110d"))
	assert_float(look.skew).is_equal(0.0)
	assert_bool(look.italic).is_false()
	assert_str(game.target_text({})).is_equal("Spin easy: keep it light")
