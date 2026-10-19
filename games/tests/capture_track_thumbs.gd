extends SceneTree
## Bakes the kart and track picker's track thumbnails (#43) from the game's own renders: each
## track's title shot (the grid under its landmark, as the fly-over opens), 3D only, scaled to
## THUMB and saved as games/kart_race/ui/tracks/<track_id>.png. Not headless; run it again after
## a track's look changes:
##   $GODOT_BIN --path games --resolution 1920x1080 -s res://tests/capture_track_thumbs.gd

const THUMB := Vector2i(384, 216)
const OUT := "res://games/kart_race/ui/tracks/"

var _session: Node
var _director: Node  # untyped: a -s script compiles before the autoloads exist


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_session = root.get_node("Session")
	_director = _session.director
	Engine.time_scale = 4.0
	_session._local.start({"kind": "just_ride", "plan_id": "thumbs", "difficulty": "standard", "total_sec": -1,
		"segments": [{"game_id": "kart_race", "role": "free", "duration_sec": -1}]})
	await process_frame
	var game: Node = _director.game
	game.set("picker_enabled", false)
	var deadline := Time.get_ticks_msec() + 30000
	while _director.phase_name() != "PLAYING" and Time.get_ticks_msec() < deadline:
		await process_frame
	Engine.time_scale = 1.0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for id in KartTracks.CUP:
		game._board.hide_board()
		game.gp = KartGrandPrix.new(-1.0, [id], 8)
		game._begin_race()  # the grid on this track, IDLE: the camera holds the title shot
		for i in 20:
			await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = game._view.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.resize(THUMB.x, THUMB.y, Image.INTERPOLATE_LANCZOS)
		var path := ProjectSettings.globalize_path(OUT + id + ".png")
		var err := img.save_png(path)
		print("THUMB %s -> %s (%d)" % [id, path, err])
	quit(0)
