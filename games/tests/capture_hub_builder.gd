extends SceneTree
## Screenshots of the hub's circuit builder and calibration (plan phases D and E) at 1920x1080.
## Not headless; needs a window:
##   $GODOT_BIN --path games --resolution 1920x1080 -s res://tests/capture_hub_builder.gd -- --out=DIR
## Saves:
##   builder_1_home.png         home with My circuits and Build your own
##   builder_2_empty.png        the builder, empty
##   builder_3_lineup.png       a 6-game lineup with its total, roles and pills
##   builder_4_twelve.png       12 games, scrolled to the end
##   builder_5_replace.png      Save with 3 saved: which to replace
##   builder_6_my_circuits.png  My circuits, one with a best
##   builder_7_no_camera.png    camera off: Kart Race can't play
##   calib_1_home_chip.png      home: the camera chip says Calibrate
##   calib_2_running.png        calibrating from the hub (Cancel)
##   calib_3_done.png           back on home: the chip says Ready / Recalibrate
##   calib_4_ask.png            permission not asked yet: the chip asks first
##   calib_5_denied.png         permission refused: how to allow it
## Each line it prints carries the frame's draw calls.

var _out := "user://captures"
var _session: Node
var _hub: Node
var _local: Node
## Loaded at run time: a -s script compiles before the autoloads these classes use.
var HubPrefs: Script
var CircuitBuilder: Script


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(_out)
	HubPrefs = load("res://hub/HubPrefs.gd")
	CircuitBuilder = load("res://hub/CircuitBuilder.gd")
	HubPrefs.path = "user://hub_prefs_capture.cfg"
	HubPrefs.reload()
	HubPrefs.forget_rider("1")
	_session = root.get_node("Session")
	_local = _session._local
	_local.hub.rider.name = "Alex"
	_local.hub.rider.ftp_is_default = false
	change_scene_to_file("res://hub/Hub.tscn")
	await process_frame
	await process_frame
	_local.hub.begin_visit()
	await _settle()
	_hub = current_scene
	if "--only-calibration" not in OS.get_cmdline_user_args():
		await _builder()
	await _calibration()
	HubPrefs.forget_rider("1")
	quit()


func _builder() -> void:
	var catalog: Array = _hub.state.catalog
	HubPrefs.save_custom("1", 0, CircuitBuilder.new(catalog, [{"game_id": "cadence_karaoke", "duration_sec": 180},
		{"game_id": "kart_race", "duration_sec": 600}, {"game_id": "dodge_ball", "duration_sec": 120},
		{"game_id": "cadence_karaoke", "duration_sec": 180}]).to_saved())
	_hub.nav.reset_to_home()
	await _settle()
	await _shot("builder_1_home")
	_hub.nav.push("builder", {"index": -1})
	await _settle()
	await _shot("builder_2_empty")
	var s = _hub.screen
	for id in ["cadence_karaoke", "tug_of_war", "safe_cracker", "dodge_ball", "kart_race", "cadence_karaoke"]:
		s.add_game(id)
	s.rows[1].stepper.step(1)
	s.rows[4].stepper.step(1)
	s.difficulty_row.segmented.pick("hard")
	s.scroll.scroll_vertical = 0
	await _settle()
	await _shot("builder_3_lineup")
	for id in ["tug_of_war", "safe_cracker", "dodge_ball", "safe_cracker", "tug_of_war", "safe_cracker"]:
		s.add_game(id)
	await _settle()
	await _shot("builder_4_twelve")
	HubPrefs.save_custom("1", 1, CircuitBuilder.new(catalog, [{"game_id": "tug_of_war", "duration_sec": 120}]).to_saved())
	HubPrefs.save_custom("1", 2, CircuitBuilder.new(catalog, [{"game_id": "safe_cracker", "duration_sec": 300},
		{"game_id": "dodge_ball", "duration_sec": 300}]).to_saved())
	s.save()
	await _settle()
	await _shot("builder_5_replace")
	s.close_replace()
	_hub.nav.reset_to_home()
	var first = CircuitBuilder.new(catalog, HubPrefs.custom_circuit("1", 0).slots)
	_local.hub.plan_bests[first.plan_id() + "|standard"] = {"score": 5240, "stars": 9}
	_local.hub.send_state()
	_hub.nav.push("my_circuits")
	await _settle()
	await _shot("builder_6_my_circuits")
	_local.hub.settings.camera_games = false
	_local.hub.send_state()
	_hub.nav.push("builder", {"index": 0})
	await _settle()
	await _shot("builder_7_no_camera")
	_local.hub.settings.camera_games = true
	_local.hub.send_state()
	_hub.nav.reset_to_home()
	await _settle()


func _calibration() -> void:
	_hub.nav.reset_to_home()
	await _settle()
	if not _hub.has_method("calibrate"):
		return
	await _shot("calib_1_home_chip")
	_hub.calibrate()
	await _settle(2.0)
	await _shot("calib_2_running")
	await _settle(6.0)
	await _shot("calib_3_done")
	_local.hub.permission = "ask"
	_local.hub.send_state()
	await _settle()
	await _shot("calib_4_ask")
	_local.hub.permission = "denied"
	_local.hub.send_state()
	await _settle(0.3)
	_hub.calibrate()
	await _settle(0.6)
	await _shot("calib_5_denied")
	_hub.dialog.close()
	_local.hub.permission = "granted"
	_local.hub.send_state()


func _settle(seconds := 1.0) -> void:
	await create_timer(seconds).timeout
	await process_frame


func _shot(name: String) -> void:
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_out, name]
	img.save_png(path)
	print("CAPTURE %s %dx%d fps=%d draw_calls=%d" % [path, img.get_width(), img.get_height(),
		Engine.get_frames_per_second(), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
