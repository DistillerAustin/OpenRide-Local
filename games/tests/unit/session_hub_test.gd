extends GdUnitTestSuite
## Session's Games hub additions (Bridge v1.1, docs/GAMES.md "Games hub"): the three new
## signals with their payloads parsed, the visit id, and the hub methods reaching the desktop
## stand-in (LocalSession records them until LocalHub plays them, plan phase B1).

var local: Node


func before_test() -> void:
	local = Session._local
	local.hub_calls.clear()
	Session.hub = {}
	Session.visit_id = ""


func test_hub_state_is_kept_and_re_emitted() -> void:
	var got: Array = []
	var on_state := func(state: Dictionary): got.append(state)
	Session.hub_state_changed.connect(on_state)
	Session._on_hub_state({"hub_version": 1.0, "visit_id": "v-1", "phase": "hub"})
	Session.hub_state_changed.disconnect(on_state)
	assert_int(got.size()).is_equal(1)
	assert_str(Session.hub.phase).is_equal("hub")
	assert_str(Session.visit_id).is_equal("v-1")


func test_a_new_visit_id_is_signalled_once() -> void:
	var visits: Array = []
	var on_visit := func(id: String): visits.append(id)
	Session.visit_changed.connect(on_visit)
	Session._on_hub_state({"visit_id": "v-1"})
	Session._on_hub_state({"visit_id": "v-1"})
	Session._on_hub_state({"visit_id": "v-2"})
	Session.visit_changed.disconnect(on_visit)
	assert_array(visits).is_equal(["v-1", "v-2"])


func test_a_visit_plan_carries_its_visit_id() -> void:
	Session._on_session_started({"kind": "just_ride", "plan_id": "p", "segments": [], "visit_id": "v-9", "plan_index": 0.0})
	assert_str(Session.visit_id).is_equal("v-9")
	# A v1 plan (no visit_id) leaves it alone.
	Session._on_session_started({"kind": "just_ride", "plan_id": "p", "segments": []})
	assert_str(Session.visit_id).is_equal("v-9")
	Session.active = false


func test_plan_rejected_and_visit_ended_are_re_emitted() -> void:
	var got: Array = []
	var on_rejected := func(reason: Dictionary): got.append(reason.reason)
	var on_ended := func(result: Dictionary): got.append(result.next)
	Session.plan_rejected.connect(on_rejected)
	Session.visit_ended.connect(on_ended)
	Session._on_plan_rejected({"request": {}, "reason": "busy"})
	Session._on_visit_ended({"visit_id": "v-1", "ride_id": null, "saved": false, "next": "app"})
	Session.plan_rejected.disconnect(on_rejected)
	Session.visit_ended.disconnect(on_ended)
	assert_array(got).is_equal(["busy", "app"])


func test_hub_methods_reach_the_desktop_stand_in() -> void:
	Session.start_plan({"kind": "circuit", "preset_id": "circuit-20", "difficulty": "standard"})
	Session.update_setting("music", "off")
	Session.hub_calibrate("lean_x", true)
	Session.cancel_calibration()
	Session.request_camera_permission()
	Session.hub_activity()
	Session.exit_hub("edit_profile")
	assert_array(local.hub_calls).is_equal([
		["start_plan", {"kind": "circuit", "preset_id": "circuit-20", "difficulty": "standard"}],
		["update_setting", "music", "off"],
		["hub_calibrate", "lean_x", true],
		["cancel_calibration"],
		["request_camera_permission"],
		["hub_activity"],
		["exit_hub", "edit_profile"],
	])
