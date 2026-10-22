extends GdUnitTestSuite
## A new visit with a different rider (rider A exits games, rider B enters; the engine keeps its
## Hub): the hub's screens are built for B, never from A's state (review of PR #58).

var local: Node
var hub: Node


func before() -> void:
	HubPrefs.path = "user://hub_prefs_visit_rider_test.cfg"
	HubPrefs.reload()


func after() -> void:
	HubPrefs.path = HubPrefs.DEFAULT_PATH
	HubPrefs.reload()


func before_test() -> void:
	local = Session._local
	local.process_mode = Node.PROCESS_MODE_DISABLED
	Session.director.phase = SessionDirector.Phase.IDLE
	local.hub.rider.id = 1
	local.hub.begin_visit()
	hub = get_tree().current_scene
	await _settle()


func after_test() -> void:
	local.hub.rider.id = 1
	local.hub.phase = ""
	Session.visit_id = ""
	Session.hub = {}
	Session.director.phase = SessionDirector.Phase.IDLE
	local.process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.max_fps = 0


func _settle(frames := 6) -> void:
	for i in frames:
		await get_tree().process_frame


func test_a_new_visit_by_another_rider_builds_home_for_that_rider() -> void:
	assert_str(hub.screen.rider_id).is_equal("1")
	local.hub.rider.id = 2
	local.hub.begin_visit()
	await _settle()
	assert_object(hub.screen).is_instanceof(HomeScreen)
	assert_str(hub.screen.rider_id).is_equal("2")
	assert_str(HubPrefs.rider(hub.screen.state)).is_equal("2")


func test_another_riders_saved_circuits_are_not_shown() -> void:
	HubPrefs.save_custom("1", 0, {"slots": [{"game_id": "tug_of_war", "duration_sec": 120}], "difficulty": "standard"})
	local.hub.rider.id = 2
	local.hub.begin_visit()
	await _settle()
	var saved := HubPrefs.custom_circuits(hub.screen.rider_id).filter(func(c): return c != null)
	assert_int(saved.size()).is_equal(0)
	HubPrefs.delete_custom("1", 0)
