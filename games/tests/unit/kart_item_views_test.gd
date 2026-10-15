extends GdUnitTestSuite
## Kart Race's item views (#43): they build, follow the logic (pods, every item, bursts), stay
## inside the tablet budget, and the game scene wires items to the race, the bots and the
## Auto items option.

const Fixtures := preload("res://tests/kart_fixtures.gd")
const DT := 1.0 / 60.0
const SEGMENT := {"game_id": "kart_race", "role": "free", "difficulty": "standard", "duration_sec": 1200,
	"end_mode": "game", "seed": 7, "effort": true,
	"params": {"ftp_watts": 150, "bot_pcts": [0.45, 0.5, 0.55, 0.6, 0.65, 0.7, 0.75], "drift_resistance": 40}}

var _rider := ""
var _saved_plan := {}


func before_test() -> void:
	_rider = "test%d" % Time.get_ticks_usec()
	_saved_plan = Session.plan
	Session.plan = {"rider_id": _rider}


func after_test() -> void:
	GameOptions.forget_rider(_rider)
	Session.plan = _saved_plan


func _race(n := 4) -> KartRaceLogic:
	var race := KartRaceLogic.new()
	var racers := []
	for i in n:
		racers.append({"racer_id": "r%d" % i})
	race.setup(KartTrackModel.new(Fixtures.meadow()), racers, 3)
	race.start_countdown(0.0)
	race.step(DT, [])
	return race


func _views(race: KartRaceLogic, items: KartItemLogic) -> KartItemViews:
	var views: KartItemViews = auto_free(KartItemViews.new())
	add_child(views)
	views.bind(items, race)
	return views


func _visible_meshes(node: Node) -> int:
	var n := 0
	if node is GeometryInstance3D and (node as Node3D).is_visible_in_tree():
		n += 1
	for c in node.get_children():
		n += _visible_meshes(c)
	return n


func test_the_pods_are_drawn_where_the_logic_has_them() -> void:
	var race := _race()
	var items := KartItemLogic.new(race, 1)
	var views := _views(race, items)
	views.sync(DT)
	var glass: MultiMeshInstance3D = views.get_node("PodGlass")
	assert_int(glass.multimesh.instance_count).is_equal(items.pods.size())
	var xf := views.pod_transform(0, items.pods[0])
	assert_float(Vector2(xf.origin.x - items.pods[0].pos.x, xf.origin.z - items.pods[0].pos.z).length()).is_less(0.01)
	assert_float(xf.origin.y - items.pods[0].pos.y).is_between(0.8, 1.4)
	# A broken pod disappears and bursts.
	items.pods[0].respawn = 2.0
	items.pod_broken.emit(0, 1)
	views.sync(DT)
	assert_float(views.pod_transform(0, items.pods[0]).basis.get_scale().x).is_less(0.01)
	# And pops back in.
	items.pods[0].respawn = 0.0
	items.pods[0].age = 0.0
	assert_float(views.pod_transform(0, items.pods[0]).basis.get_scale().x).is_less(0.2)
	items.pods[0].age = 1.0
	assert_float(views.pod_transform(0, items.pods[0]).basis.get_scale().x).is_equal_approx(1.0, 0.01)
	var sparks: MultiMeshInstance3D = views.get_node("Sparkles")
	assert_int(sparks.multimesh.visible_instance_count).is_greater(5)


func test_every_item_has_a_view_and_idle_costs_few_draws() -> void:
	var race := _race()
	var items := KartItemLogic.new(race, 1)
	var views := _views(race, items)
	views.sync(DT)
	# Idle: pods (glass, bands, cores, halos) and the two burst pools.
	assert_int(_visible_meshes(views)).is_less_equal(6)
	for item in ["puck", "drone", "goo", "shield", "magnet"]:
		items.give(race.karts.size() - 1, item)
		items.use(race.karts.size() - 1)
	for i in 5:
		items.step(DT, [])
		views.sync(DT)
	assert_bool(views.get_node("Puck0").visible).is_true()
	assert_bool(views.get_node("Drone0").visible).is_true()
	assert_bool(views.get_node("Goo0").visible).is_true()
	assert_bool(views.get_node("Shield%d" % (race.karts.size() - 1)).visible).is_true()
	assert_bool(views.get_node("PuckTrail0").visible).is_true()
	# Everything at once still fits the budget comfortably.
	assert_int(_visible_meshes(views)).is_less_equal(30)


func test_a_blocked_hit_pops_the_shield() -> void:
	var race := _race()
	var items := KartItemLogic.new(race, 1)
	var views := _views(race, items)
	items.give(0, "shield")
	items.use(0)
	views.sync(DT)
	var shield: MeshInstance3D = views.get_node("Shield0")
	assert_bool(shield.visible).is_true()
	items.hit(race.karts[0], 1, "puck")
	views.sync(DT)
	assert_bool(shield.visible).is_true()  # popping
	for i in 30:
		views.sync(DT)
	assert_bool(shield.visible).is_false()


func test_the_game_steps_items_and_hands_them_to_the_bots() -> void:
	var game: Game = auto_free(load("res://games/kart_race/KartRace.tscn").instantiate())
	game.hud = auto_free(Hud.new())
	add_child(game)
	game.prepare(SEGMENT)
	var inp := KartInput.new()
	inp.power_w = 150.0
	inp.cadence = 85.0
	game.set("test_input", inp)
	game.start()
	var items: KartItemLogic = game.get("items")
	assert_object(items).is_not_null()
	assert_int(items.pods.size()).is_greater(0)
	for b in game.get("bots").slice(1):
		assert_object(b.items).is_same(items)
	assert_bool(items.auto_rider).is_false()
	# Racing: give the rider an item and tap.
	for i in roundi((preload("res://games/kart_race/KartRace.gd").FLYOVER_SEC + 4.0) / DT):
		game._on_frame(DT)
	var used := []
	game.get("race").events.item_used.connect(func(id: int, item: String): used.append([id, item]))
	items.give(0, "turbo")
	inp.use_item = true
	game._on_frame(DT)
	inp.use_item = false
	assert_array(used).contains([[0, "turbo"]])
	# Auto items, switched on mid-race, takes over.
	GameOptions.set_value(game.declared(), "auto_items", "on", _rider)
	game._on_option_changed("auto_items", "on")
	assert_bool(items.auto_rider).is_true()
