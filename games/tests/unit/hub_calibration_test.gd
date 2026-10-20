extends GdUnitTestSuite
## Calibrating from the hub (plan phase E, spec §6): the camera chip's states, what a tap does
## (ask for the permission first, explain when it can't), `full` false the first time and
## true after, stray taps ignored, Cancel, the music ducked meanwhile, and the visit's
## calibration carried into the next camera game.

var local: Node
var hub: Node


func _state(camera := {}, camera_games := true) -> Dictionary:
	return HubState.normalized({"settings": {"camera_games": camera_games}, "camera": camera})


# --- The chip ---

func test_the_chip_for_every_camera_state() -> void:
	var cases := [
		[{}, false, "CAMERA OFF", "Turn on"],
		[{"permission": "denied", "available": false}, true, "NOT ALLOWED", "How to allow"],
		[{"permission": "ask", "available": false}, true, "CAMERA", "Allow"],
		[{"permission": "granted", "available": false}, true, "CAN'T SEE YOU", "Try again"],
		[{"permission": "granted", "available": true, "calibrated": ""}, true, "CAMERA", "Calibrate"],
		[{"permission": "granted", "available": true, "calibrated": "lean_x"}, true, "CAMERA READY", "Recalibrate"],
		[{"permission": "granted", "available": true, "calibrated": "lean_2d"}, true, "CAMERA READY", "Recalibrate"],
	]
	for c in cases:
		var chip := HubHeader.camera_chip(_state(c[0], c[1]))
		assert_str("%s / %s" % [chip.caption, chip.text]).is_equal("%s / %s" % [c[2], c[3]])


# --- HubCalibration ---

func test_a_tap_with_permission_ask_asks_first_then_calibrates_once_granted() -> void:
	var flow := HubCalibration.new()
	assert_str(flow.tap(_state({"permission": "ask", "available": false}), 10000)).is_equal("ask")
	assert_bool(flow.running()).is_false()
	assert_str(flow.on_state(_state({"permission": "granted"}), InputBus.TRACKER_OFF, 12000)).is_equal("calibrate")
	assert_bool(flow.running()).is_true()
	assert_bool(flow.full).is_false()


func test_a_refused_permission_stops_asking() -> void:
	var flow := HubCalibration.new()
	flow.tap(_state({"permission": "ask", "available": false}), 10000)
	assert_str(flow.on_state(_state({"permission": "ask", "available": false}), InputBus.TRACKER_OFF, 12000)).is_equal("refused")
	assert_str(flow.tap(_state({"permission": "denied", "available": false}), 14000)).is_equal("denied")
	assert_str(HubCalibration.new().tap(_state({}, false), 10000)).is_equal("camera_off")


func test_full_is_false_the_first_time_and_true_after() -> void:
	var flow := HubCalibration.new()
	assert_str(flow.tap(_state({"calibrated": ""}), 10000)).is_equal("calibrate")
	assert_bool(flow.full).is_false()
	assert_str(flow.on_state(_state({"calibrated": "lean_x"}), InputBus.TRACKER_OFF, 14000)).is_equal("done")
	assert_str(flow.tap(_state({"calibrated": "lean_x"}), 20000)).is_equal("calibrate")
	assert_bool(flow.full).is_true()


func test_stray_taps_during_a_run_are_ignored() -> void:
	var flow := HubCalibration.new()
	flow.tap(_state(), 10000)
	assert_str(flow.tap(_state(), 10300)).is_equal("ignore")
	assert_str(flow.tap(_state(), 15000)).is_equal("ignore")  # still running
	flow.cancel()
	assert_str(flow.tap(_state(), 15500)).is_equal("calibrate")  # the 1 s debounce has passed
	flow.cancel()
	assert_str(flow.tap(_state(), 15900)).is_equal("ignore")  # a double tap


func test_an_end_needs_the_tracker_to_have_stopped() -> void:
	var flow := HubCalibration.new()
	flow.tap(_state(), 10000)
	assert_str(flow.on_state(_state({"calibrated": "lean_x"}), InputBus.TRACKER_OFF, 10100)).is_equal("")  # too soon: from before
	assert_str(flow.on_state(_state(), InputBus.TRACKER_CALIBRATING, 12000)).is_equal("")  # a hub_state mid-run
	assert_str(flow.on_state(_state({"available": false}), InputBus.TRACKER_OFF, 15000)).is_equal("failed")


# --- In the hub ---

func _open_hub() -> void:
	local = Session._local
	local.hub.permission = "granted"
	local.hub.settings.camera_games = true
	Session.director.phase = SessionDirector.Phase.IDLE
	local.hub.begin_visit()
	hub = get_tree().current_scene
	await _settle()


func after_test() -> void:
	if hub == null:
		return
	if hub.calibrating():
		hub.cancel_calibration()
	hub.dialog.close()
	local.hub.permission = "granted"
	local.hub.settings.camera_games = true
	local.hub.phase = ""
	Session.visit_id = ""
	Session.hub = {}
	Session.director.phase = SessionDirector.Phase.IDLE
	Engine.max_fps = 0
	hub = null


func _settle(frames := 6) -> void:
	for i in frames:
		await get_tree().process_frame


func _until_done(seconds: float) -> void:
	var left := seconds
	while hub.calibrating() and left > 0.0:
		await get_tree().create_timer(0.1).timeout
		left -= 0.1


func test_calibrate_from_the_chip_then_recalibrate() -> void:
	await _open_hub()
	var calls_before: int = local.hub_calls.size()
	hub.screen.header.camera_card.hit.pressed.emit()
	await _settle(2)
	assert_bool(hub.calibrating()).is_true()
	assert_bool(hub.calibration_overlay.visible).is_true()
	assert_bool(hub.calibration_overlay.cancel_button.is_visible_in_tree()).is_true()
	assert_bool(hub.music._dialog).override_failure_message("the hub's music ducks under the calibration").is_true()
	assert_array(local.hub_calls.slice(calls_before)).contains([["hub_calibrate", "lean_x", false]])
	hub.screen.header.camera_card.hit.pressed.emit()  # a stray tap mid-run
	assert_int(local.hub_calls.filter(func(c): return c[0] == "hub_calibrate").size()).is_equal(1)
	await _until_done(12.0)
	assert_bool(hub.calibrating()).is_false()
	assert_bool(hub.calibration_overlay.visible).is_false()
	assert_str(str(hub.state.camera.calibrated)).is_equal("lean_x")
	assert_bool(hub.music._dialog).is_false()
	await _settle(2)
	assert_str(hub.screen.header.camera_label.text).is_equal("Recalibrate")
	await get_tree().create_timer(1.1).timeout  # past the debounce
	hub.calibrate()
	assert_array(local.hub_calls.back()).is_equal(["hub_calibrate", "lean_x", true])
	hub.cancel_calibration()


func test_cancel_stops_it() -> void:
	await _open_hub()
	hub.calibrate()
	await _settle(2)
	hub.calibration_overlay.cancel_button.pressed.emit()
	assert_bool(hub.calibrating()).is_false()
	assert_array(local.hub_calls.back()).is_equal(["cancel_calibration"])
	assert_bool(local.hub_calibrating).is_false()
	assert_str(str(local.hub.calibrated)).is_equal("")
	assert_bool(hub.calibration_overlay.visible).is_false()


func test_back_cancels_it_too() -> void:
	await _open_hub()
	hub.calibrate()
	await _settle(2)
	Session.back()
	assert_bool(hub.calibrating()).is_false()
	assert_bool(hub.dialog.visible).is_false()  # it didn't also ask to exit


func test_with_permission_ask_the_chip_asks_then_calibrates() -> void:
	local = Session._local
	local.hub.permission = "ask"
	Session.director.phase = SessionDirector.Phase.IDLE
	local.hub.begin_visit()
	hub = get_tree().current_scene
	await _settle()
	assert_str(hub.screen.header.camera_label.text).is_equal("Allow")
	hub.calibrate()  # the desktop grants at once
	await _settle(2)
	var names: Array = local.hub_calls.slice(-2).map(func(c): return c[0])
	assert_array(names).is_equal(["request_camera_permission", "hub_calibrate"])
	assert_bool(hub.calibrating()).is_true()


func test_denied_or_off_explains() -> void:
	local = Session._local
	local.hub.permission = "denied"
	Session.director.phase = SessionDirector.Phase.IDLE
	local.hub.begin_visit()
	hub = get_tree().current_scene
	await _settle()
	var before: int = local.hub_calls.size()
	hub.calibrate()
	assert_bool(hub.dialog.visible).is_true()
	assert_str(hub.dialog.title.text).is_equal("Camera not allowed")
	assert_bool(hub.calibrating()).is_false()
	assert_bool(local.hub_calls.slice(before).any(func(c): return c[0] == "hub_calibrate")).is_false()


func test_the_visits_calibration_goes_into_the_next_camera_game() -> void:
	await _open_hub()
	hub.calibrate()
	await _until_done(12.0)
	var started: int = local.calibrations_started
	var built: Dictionary = local.hub.build_plan({"kind": "just_ride", "game_id": "dodge_ball", "mode": "minutes", "length": 5})
	assert_str(str(local.hub.state().camera.calibrated)).is_equal("lean_x")
	local.hub.start_plan({"kind": "just_ride", "game_id": "dodge_ball", "mode": "minutes", "length": 5, "difficulty": "standard"})
	await _settle(4)
	assert_str(str(Session.plan.calibrated)).is_equal("lean_x")
	assert_int(local.calibrations_started).override_failure_message("no calibration in the game").is_equal(started)
	assert_bool(local.is_calibrating()).is_false()
	assert_dict(built).contains_keys(["plan"])
	Session.request_end()
	await _settle(4)
	Session.director.return_to_hub()
	await _settle(4)
	hub = get_tree().current_scene
