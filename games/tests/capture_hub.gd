extends SceneTree
## Screenshots of the Games hub's screens at 1920x1080, for UI reviews against
## framework/ui/UI_STYLE.md and the games. Not headless; needs a window:
##   $GODOT_BIN --path games --resolution 1920x1080 -s res://tests/capture_hub.gd -- --out=DIR
## Plays a desktop visit (LocalHub) and saves:
##   hub_1_home.png            the home screen (the FTP nudge, no bests yet)
##   hub_2_game_kart.png       Kart Race's screen
##   hub_3_game_tug.png        Tug of War's (rounds)
##   hub_4_circuit.png         the 30 min circuit
##   hub_5_settings.png        Settings
##   hub_6_exit.png            the Exit games confirmation
##   hub_7_home_bests.png      home after a played visit: bests on cards, the camera off
##   hub_8_camera_explain.png  a dimmed game's explanation
##   hub_9_idle_saved.png      after the idle guard saved the ride
##   hub_10_result.png         a plan's result card in a visit ("Back to games")
## Each line it prints carries the frame's draw calls and the bakes rendered that frame.

var _out := "user://captures"
var _session: Node
var _hub_node: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(_out)
	_session = root.get_node("Session")
	var local: Node = _session._local
	local.hub.rider.name = "Alex"
	change_scene_to_file("res://hub/Hub.tscn")
	await process_frame
	await process_frame
	local.hub.begin_visit()
	await _settle()
	_hub_node = current_scene
	await _shot("hub_1_home")

	_hub_node.nav.push("game", {"game_id": "kart_race"})
	await _settle()
	await _shot("hub_2_game_kart")
	_hub_node.nav.pop()
	_hub_node.nav.push("game", {"game_id": "tug_of_war"})
	await _settle()
	_hub_node.screen.length_picker.modes.pick("rounds")
	await _settle()
	await _shot("hub_3_game_tug")
	_hub_node.nav.pop()
	_hub_node.nav.push("circuit", {"circuit_id": "circuit-30"})
	await _settle()
	await _shot("hub_4_circuit")
	_hub_node.nav.pop()
	_hub_node.nav.push("settings", {})
	await _settle()
	await _shot("hub_5_settings")
	_hub_node.nav.pop()
	await _settle()
	_hub_node.ask_exit()
	await _settle(0.5)
	await _shot("hub_6_exit")
	_hub_node.dialog.close()

	# A played visit: bests and ride time; the camera off; the FTP set.
	var hub: Node = local.hub
	hub.rider.ftp_is_default = false
	hub.plans = [{"plan_id": "just-ride:kart_race:minutes:10", "difficulty": "standard", "score": 812, "stars": 2,
		"game_ids": ["kart_race"]}, {"plan_id": "circuit-20", "difficulty": "standard", "score": 6150, "stars": 21,
		"game_ids": ["cadence_karaoke", "tug_of_war", "safe_cracker", "dodge_ball", "cadence_karaoke"]}]
	hub.ride_sec = 1854.0
	hub.gameplay_sec = 1800.0
	hub.game_bests = {
		"a": {"game_id": "kart_race", "plan_id": "just-ride:kart_race:minutes:10", "difficulty": "standard", "variant": "", "score": 812, "stars": 2, "plays": 1},
		"b": {"game_id": "tug_of_war", "plan_id": "just-ride:tug_of_war:rounds:3", "difficulty": "standard", "variant": "", "score": 2400, "stars": 3, "plays": 2},
		"c": {"game_id": "safe_cracker", "plan_id": "just-ride:safe_cracker:minutes:5", "difficulty": "standard", "variant": "", "score": 1500, "stars": 1, "plays": 1},
	}
	hub.plan_bests = {"circuit-20|standard": {"score": 6150, "stars": 21}}
	hub.settings.camera_games = false
	hub.calibrated = "lean_x"
	hub.send_state()
	await _settle()
	await _shot("hub_7_home_bests")
	_hub_node._explain_camera("kart_race")
	await _settle(0.5)
	await _shot("hub_8_camera_explain")
	_hub_node.dialog.close()
	hub.settings.camera_games = true
	hub.send_state()
	hub._process(hub.IDLE_SAVE_SEC + 1.0)
	await _settle(0.6)
	await _shot("hub_9_idle_saved")
	_session.hub_activity()
	await _settle()

	# A plan's result card in the visit.
	_session.start_plan({"kind": "just_ride", "game_id": "safe_cracker", "mode": "open", "difficulty": "standard"})
	await _settle(2.0)
	_session.request_end()
	await _settle(1.8)
	await _shot("hub_10_result")
	_session.director.summary_screen.done_pressed.emit()
	await _settle()
	await _shot("hub_11_back_home")
	quit()


func _settle(seconds := 1.0) -> void:
	await create_timer(seconds).timeout
	await process_frame


func _shot(name: String) -> void:
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_out, name]
	img.save_png(path)
	print("CAPTURE %s %dx%d fps=%d draw_calls=%d objects=%d" % [path, img.get_width(), img.get_height(),
		Engine.get_frames_per_second(), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
