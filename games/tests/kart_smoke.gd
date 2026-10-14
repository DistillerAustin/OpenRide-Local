extends SceneTree
## Headless smoke check for Kart Race's scene (#43): loads it, prepares a race, runs a few
## seconds of frames and prints SMOKE OK (or the first errors). A quick loop for development:
##   $GODOT_BIN --headless --path games -s res://tests/kart_smoke.gd

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(60.0).timeout.connect(func(): print("SMOKE TIMEOUT"); quit(1))
	await process_frame
	var scene: PackedScene = load("res://games/kart_race/KartRace.tscn")
	var game = scene.instantiate()
	game.hud = load("res://framework/hud/Hud.gd").new()
	root.add_child(game.hud)
	root.add_child(game)
	game.prepare({"game_id": "kart_race", "role": "free", "difficulty": "standard", "duration_sec": 600,
		"end_mode": "game", "seed": 7, "effort": true, "params": {"ftp_watts": 150}})
	var inp = load("res://games/kart_race/logic/KartInput.gd").new()
	inp.power_w = 180.0
	inp.cadence = 90.0
	game.set("test_input", inp)
	game.start()
	for i in 900:
		game._on_frame(1.0 / 60.0)
		if i % 60 == 0:
			await process_frame
	print("SMOKE OK sim_time=%.1f place=%d speed=%.1f" % [game.sim_time, game.race.karts[0].place, game.race.karts[0].speed])
	quit()
