extends GdUnitTestSuite
## HubNav, the hub's screen stack: home at the bottom, push and pop, and a snapshot restored
## when the hub comes back after a plan.


func test_home_is_always_at_the_bottom() -> void:
	var nav := HubNav.new()
	assert_str(nav.top_id()).is_equal(HubNav.HOME)
	assert_bool(nav.pop()).is_false()
	assert_int(nav.depth()).is_equal(1)


func test_push_and_pop_signal_the_new_top() -> void:
	var nav := HubNav.new()
	var seen: Array = []
	nav.changed.connect(func(id: String, args: Dictionary): seen.append([id, args]))
	nav.push(HubNav.GAME, {"game_id": "kart_race"})
	nav.push(HubNav.SETTINGS)
	assert_bool(nav.pop()).is_true()
	assert_array(seen).is_equal([[HubNav.GAME, {"game_id": "kart_race"}], [HubNav.SETTINGS, {}],
		[HubNav.GAME, {"game_id": "kart_race"}]])
	assert_str(nav.top().args.game_id).is_equal("kart_race")


func test_a_snapshot_restores_the_stack() -> void:
	var nav := HubNav.new()
	nav.push(HubNav.CIRCUIT, {"circuit_id": "circuit-30"})
	var snap := nav.snapshot()
	var again := HubNav.new()
	again.restore(snap)
	assert_str(again.top_id()).is_equal(HubNav.CIRCUIT)
	assert_int(again.depth()).is_equal(2)


func test_a_bad_snapshot_restores_home() -> void:
	var nav := HubNav.new()
	nav.restore([{"id": HubNav.GAME, "args": {}}])
	assert_str(nav.top_id()).is_equal(HubNav.HOME)
	nav.restore([])
	assert_int(nav.depth()).is_equal(1)


func test_reset_goes_home() -> void:
	var nav := HubNav.new()
	nav.push(HubNav.GAME, {"game_id": "dodge_ball"})
	nav.reset_to_home()
	assert_str(nav.top_id()).is_equal(HubNav.HOME)
	assert_int(nav.depth()).is_equal(1)
