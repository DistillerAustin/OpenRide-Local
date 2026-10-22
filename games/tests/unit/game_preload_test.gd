extends GdUnitTestSuite
## Loading ahead (bike test, 2026-10-20: "loading games on first launch / starting games takes too
## long"): the hub's cards never wait for a game's declarations, every game's declarations load
## in the background, and the game whose screen is open loads before Start.

var local: Node
var hub: Node


func before_test() -> void:
	local = Session._local
	local.process_mode = Node.PROCESS_MODE_DISABLED
	Session.director.phase = SessionDirector.Phase.IDLE
	local.hub.begin_visit()
	hub = get_tree().current_scene
	await _settle()


func after_test() -> void:
	local.hub.phase = ""
	Session.visit_id = ""
	Session.hub = {}
	local.process_mode = Node.PROCESS_MODE_INHERIT
	GameRegistry.release()


func test_the_hub_starts_loading_a_game_when_its_screen_opens() -> void:
	hub.nav.push(HubNav.GAME, {"game_id": "tug_of_war"})
	await _settle()
	assert_bool(GameRegistry.is_prefetched("tug_of_war")).is_true()
	assert_bool(GameRegistry.is_prefetched("dodge_ball")).is_false()
	# Another game's screen holds that one instead; home holds none.
	hub.nav.pop()
	hub.nav.push(HubNav.GAME, {"game_id": "dodge_ball"})
	await _settle()
	assert_bool(GameRegistry.is_prefetched("dodge_ball")).is_true()
	assert_bool(GameRegistry.is_prefetched("tug_of_war")).is_false()
	hub.nav.pop()
	await _settle()
	assert_bool(GameRegistry.is_prefetched("dodge_ball")).is_false()


func test_a_circuit_screen_loads_its_first_game() -> void:
	var circuit: Dictionary = hub.state.circuits[0]
	hub.nav.push(HubNav.CIRCUIT, {"circuit_id": circuit.id})
	await _settle()
	assert_bool(GameRegistry.is_prefetched(str(circuit.slots[0].game_id))).is_true()
	hub.nav.pop()
	await _settle()


func test_a_prefetched_game_instantiates_from_the_loaded_scene() -> void:
	GameRegistry.prefetch(["safe_cracker"])
	var game := GameRegistry.instantiate("safe_cracker")
	assert_object(game).is_not_null()
	assert_str(game.declared().id).is_equal("safe_cracker")
	game.free()
	# Instantiating again (a second plan) works from the held scene.
	var again := GameRegistry.instantiate("safe_cracker")
	assert_object(again).is_not_null()
	again.free()


func test_declarations_load_in_the_background() -> void:
	GameRegistry.warm_infos()
	var waited := 0
	while not GameRegistry.infos_ready() and waited < 600:
		GameRegistry.poll()
		await get_tree().process_frame
		waited += 1
	assert_bool(GameRegistry.infos_ready()).is_true()
	for game_id in GameRegistry.ids():
		assert_object(GameRegistry.cached_info(game_id)).is_same(GameRegistry.info(game_id))


func _settle(frames := 10) -> void:
	for i in frames:
		await get_tree().process_frame
