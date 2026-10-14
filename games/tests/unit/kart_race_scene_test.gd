extends GdUnitTestSuite
## Kart Race's scene with the framework (#43): the race runs from the grid, the rider drives
## forward on the road, pause freezes everything, `request_finish` ends at once with the
## result's stats, and the rider's options apply.

const SEGMENT := {"game_id": "kart_race", "role": "free", "difficulty": "standard", "duration_sec": 1200,
	"end_mode": "game", "seed": 7, "effort": true,
	"params": {"ftp_watts": 150, "bot_pcts": [0.45, 0.5, 0.55, 0.6, 0.65, 0.7, 0.75], "drift_resistance": 40}}
const STATS := ["position", "races", "wins", "podiums", "best_lap", "race_time", "boosts", "items_hit",
	"avg_power", "ghost_trace", "effort_avg"]
const DT := 1.0 / 60.0

var _rider := ""
var _saved_plan := {}


func before_test() -> void:
	_rider = "test%d" % Time.get_ticks_usec()
	_saved_plan = Session.plan
	Session.plan = {"rider_id": _rider}


func after_test() -> void:
	GameOptions.forget_rider(_rider)
	Session.plan = _saved_plan


func _game(seg := SEGMENT) -> Game:
	var game: Game = auto_free(load("res://games/kart_race/KartRace.tscn").instantiate())
	game.hud = auto_free(Hud.new())
	add_child(game)
	game.prepare(seg)
	var inp := KartInput.new()
	inp.power_w = 150.0
	inp.cadence = 85.0
	game.set("test_input", inp)
	game.start()
	return game


func _frames(game: Game, n: int) -> void:
	for i in n:
		game._on_frame(DT)


func test_the_grid_shows_behind_the_intro_card() -> void:
	var game: Game = auto_free(load("res://games/kart_race/KartRace.tscn").instantiate())
	game.hud = auto_free(Hud.new())
	add_child(game)
	game.prepare(SEGMENT)
	var race: KartRaceLogic = game.get("race")
	assert_object(race).is_not_null()
	assert_int(race.karts.size()).is_equal(8)
	assert_int(race.phase).is_equal(KartRaceLogic.Phase.GRID)
	assert_int(game.get("views").size()).is_equal(8)
	# Every view's anchors exist.
	for v: KartView in game.get("views"):
		for a in KartView.ANCHORS:
			assert_object(v.anchor(a)).override_failure_message("missing anchor %s" % a).is_not_null()
	assert_str(game.target_text(SEGMENT)).contains("race")


func test_the_rider_drives_forward_and_stays_on_the_road() -> void:
	var game := _game()
	var race: KartRaceLogic = game.get("race")
	var k: KartState = race.karts[0]
	var start := race.progress(0)
	for i in 600:
		game._on_frame(DT)
		assert_float(absf(k.d)).override_failure_message("off the road at %.0f m: d %.2f" % [k.s, k.d]) \
			.is_less(race.track.half_width(k.s) + KartTrackModel.KERB_WIDTH)
	assert_int(race.phase).is_equal(KartRaceLogic.Phase.RACING)
	# Three seconds of countdown, then seven of racing.
	assert_float(race.progress(0) - start).is_greater(60.0)
	assert_float(k.speed).is_greater(10.0)
	# The bots race too.
	for bot: KartState in race.karts.slice(1):
		assert_float(bot.speed).is_greater(5.0)


func test_pause_freezes_the_race() -> void:
	var game := _game()
	await await_millis(300)
	var simulated: float = game.get("sim_time")
	assert_float(simulated).is_greater(0.0)
	game.set_paused(true)
	var race: KartRaceLogic = game.get("race")
	var countdown := race.countdown
	var pos: Vector3 = race.karts[1].pos
	await await_millis(300)
	assert_float(game.get("sim_time")).is_equal(simulated)
	assert_float(race.countdown).is_equal(countdown)
	assert_vector(race.karts[1].pos).is_equal(pos)
	game.set_paused(false)
	await await_millis(200)
	assert_float(game.get("sim_time")).is_greater(simulated)


func test_request_finish_ends_at_once_with_the_stats() -> void:
	var game := _game()
	_frames(game, 900)
	game.request_finish()
	assert_bool(game.has_ended()).is_true()
	var result := game.finish()
	for key in STATS:
		assert_bool(result.stats.has(key)).override_failure_message("missing stats.%s" % key).is_true()
	assert_bool(result.won is bool).is_true()
	# The race in progress counted.
	assert_int(int(result.stats.races)).is_equal(1)
	assert_int(int(result.stats.position)).is_between(1, 8)
	assert_bool(result.stats.ghost_trace is Array).is_true()
	assert_int(result.stats.ghost_trace.size()).is_greater(5)
	assert_float(float(result.stats.avg_power)).is_equal_approx(150.0, 1.0)


func test_request_finish_during_the_countdown_still_has_valid_stats() -> void:
	var game := _game()
	_frames(game, 30)
	game.request_finish()
	assert_bool(game.has_ended()).is_true()
	var result := game.finish()
	assert_int(int(result.stats.races)).is_equal(0)
	assert_bool(result.won).is_false()
	for key in STATS:
		assert_bool(result.stats.has(key)).is_true()


func test_options_apply() -> void:
	var game := _game()
	var race: KartRaceLogic = game.get("race")
	assert_float(race.physics.assist).is_equal(1.0)
	game.change_option("assist", "off")
	assert_float(race.physics.assist).is_equal(0.0)
	game.change_option("camera", "close")
	assert_str(game.get("camera").mode).is_equal("close")


func test_a_short_grand_prix_runs_to_the_podium_and_ends() -> void:
	# Five minutes plans a single final race; strong legs finish it well inside the time.
	var seg := SEGMENT.duplicate(true)
	seg.duration_sec = 300
	Effort.begin_segment(true)
	Effort.set_live(true)
	var game := _game(seg)
	game.get("test_input").power_w = 300.0
	var current: Dictionary = game.get("current")
	assert_bool(current.is_final).is_true()
	var frames := 0
	while not game.has_ended() and frames < 60 * 400:
		game._on_frame(DT)
		frames += 1
	assert_bool(game.has_ended()).is_true()
	var result := game.finish()
	assert_int(int(result.stats.races)).is_equal(1)
	assert_float(float(result.stats.best_lap)).is_greater(10.0)
	assert_int(int(result.stats.race_time)).is_greater(60)
	assert_float(float(result.score)).is_greater(0.0)
	Effort.set_live(false)
	Effort.begin_segment(false)
