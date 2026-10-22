extends SceneTree
## Screenshots of every game's hub screen with its options (plan C), at 1920x1080, for UI reviews
## against framework/ui/UI_STYLE.md. Not headless; needs a window:
##   $GODOT_BIN --path games --resolution 1920x1080 -s res://tests/capture_hub_options.gd -- --out=DIR
## Saves opt_<game>.png per game, opt_kart_race_picked.png (a kart and a track picked: the
## rider's name moves to the new kart), and opt_<game>_more.png with "More options" open. Each
## line it prints carries the frame's draw calls.

var _out := "user://captures"
var _session: Node
var _hub: Node


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
	local.hub.rider.ftp_is_default = false
	change_scene_to_file("res://hub/Hub.tscn")
	await process_frame
	await process_frame
	local.hub.begin_visit()
	await _settle()
	_hub = current_scene
	for e in _hub.state.catalog:
		var id := str(e.id)
		_hub.nav.push("game", {"game_id": id})
		await _settle()
		var screen: Node = _hub.screen
		if id == "kart_race":  # the defaults first (untyped: this script compiles before the autoloads)
			screen.option_controls["driver"].pick("fox")
			screen.option_controls["track"].pick("meadow_ring")
			await _settle()
		await _shot("opt_" + id)
		if id == "kart_race":
			screen.option_controls["driver"].cards["rabbit"].hit.pressed.emit()
			screen.option_controls["track"].cards["canyon_dash"].hit.pressed.emit()
			await _settle()
			await _shot("opt_kart_race_picked")
		if screen.more_button:
			screen.open_more()
			await _settle(0.6)
			await _shot("opt_%s_more" % id)
			screen.close_more()
		_hub.nav.pop()
		await _settle(0.4)
	quit()


func _settle(seconds := 1.0) -> void:
	await create_timer(seconds).timeout
	await process_frame


func _shot(name: String) -> void:
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_out, name]
	img.save_png(path)
	print("CAPTURE %s %dx%d draw_calls=%d objects=%d" % [path, img.get_width(), img.get_height(),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
