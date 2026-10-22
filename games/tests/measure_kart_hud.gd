extends SceneTree
## The kart HUD's draw calls on the desktop counter (#43, the tablet budget); needs a window:
##   $GODOT_BIN --path games -s res://tests/measure_kart_hud.gd
## KartHud alone over an empty screen, driven by a race of bots on Meadow Ring (the order
## changing, the rider holding an item, speed lines on). Prints the mean draw calls a frame over
## 300 frames with the HUD shown, and with it hidden: `MEASURE kart_hud draw_calls=…`.

const Fixtures := preload("res://tests/kart_fixtures.gd")
const DT := 1.0 / 60.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame  # the autoloads are in by now
	var race := KartRaceLogic.new()
	var racers := []
	for i in 8:
		racers.append({"racer_id": "r%d" % i})
	race.setup(KartTrackModel.new(Fixtures.meadow()), racers, 3)
	race.start_countdown(0.0)
	var bots := []
	for i in 8:
		bots.append(KartBotDriver.new(KartBotDriver.profile_for(i, 0.5 + 0.04 * i), 150.0, i + 1))
	var hud = load("res://games/kart_race/ui/KartHud.gd").new()  # untyped: compiled before the autoloads
	root.add_child(hud)
	hud.setup(KartRoster.lineup(KartRoster.ids()[0], 8), race.track)
	hud.set_gameplay_visible(true, false)
	var inputs := []
	inputs.resize(8)
	var results := []
	for shown in [true, false]:
		hud.visible = shown
		var total := 0.0
		for f in 360:
			for i in 8:
				inputs[i] = bots[i].think(race.karts[i], race, DT)
			race.step(DT, inputs)
			race.karts[0].item = "turbo"
			hud.speed_lines = 1.0
			hud.update(race, DT)
			hud.ride_strip.source = {"cadence": 80.0 + (f % 30), "power": 150.0 + (f % 7), "resistance": 35.0,
				"effort_enabled": true, "multiplier": 1.1}
			await process_frame
			if f >= 60:
				total += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		results.append(total / 300.0)
	print("MEASURE kart_hud draw_calls=%.1f (shown %.1f, hidden %.1f, mean of 300 frames)" % [results[0] - results[1], results[0], results[1]])
	quit()
