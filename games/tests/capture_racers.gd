extends SceneTree
## Desktop screenshots of Kart Race's racers (#43) (not headless; needs a window):
##   $GODOT_BIN --path games --resolution 1920x1080 -s res://tests/capture_racers.gd -- --out=DIR
## Lines the eight karts up on a plain road under the game's light and saves: the grid from the
## front and from the chase camera's distance behind, a close-up, the poses (steering, drift,
## boost, spin-out, celebration), and the HUD portraits. --bench also times the views' `sync`
## and the 3D render (with and without the karts) and prints draw calls and triangles.

var _out := "user://captures"
var _views: Array = []
var _states: Array = []
var _cam: Camera3D
var _world: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var bench := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.get_slice("=", 1)
		elif arg == "--bench":
			bench = true
	DirAccess.make_dir_recursive_absolute(_out)
	_stage()
	await _frames(4)
	if bench:
		await _bench()
		quit()
		return
	# The grid from the front, low.
	_shot(Vector3(5.5, 1.5, -7.5), Vector3(0.0, 0.7, 2.0), 38.0)
	await _save("racers_front")
	# From behind, at about the chase camera's distance.
	_shot(Vector3(1.0, 2.6, 9.5), Vector3(0.0, 0.6, -2.0), 55.0)
	await _save("racers_back")
	# A close-up of the first two.
	_shot(Vector3(-3.6, 1.25, -5.2), Vector3(-4.4, 0.8, -0.4), 30.0)
	await _save("racers_close")
	_shot(Vector3(4.6, 1.25, -5.0), Vector3(3.2, 0.8, -0.4), 30.0)
	await _save("racers_close2")
	# Poses: steer left, steer right, boost, spin-out, cheer (podium), cheer (wave).
	var poses := ["left", "right", "boost", "spin", "cheer", "wave", "hop", "idle"]
	for i in _views.size():
		_states[i].speed = 18.0
		match poses[i]:
			"left": _states[i].steer = -1.0
			"right": _states[i].steer = 1.0
			"boost": _states[i].boost_time = 1.0
			"spin": _states[i].spin_time = 0.55
			"cheer":
				_states[i].finished = true
				_states[i].place = 1
			"wave":
				_states[i].finished = true
				_states[i].place = 6
			"hop": _states[i].hop = 0.35
			"idle": _states[i].speed = 0.0
	await _frames(40)
	_shot(Vector3(5.5, 1.6, -7.5), Vector3(0.0, 0.7, 2.0), 38.0)
	await _save("racers_poses")
	_shot(Vector3(1.0, 2.6, 9.5), Vector3(0.0, 0.6, -2.0), 55.0)
	await _save("racers_poses_back")
	# Portraits, on a strip.
	var strip := HBoxContainer.new()
	strip.position = Vector2(40, 40)
	strip.add_theme_constant_override("separation", 16)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	layer.add_child(strip)
	var shader: Shader = load("res://games/kart_race/ui/shaders/portrait.gdshader")
	for r in KartRoster.RACERS:
		var pic := TextureRect.new()
		pic.texture = KartPortraits.texture(root, r, 200)
		pic.custom_minimum_size = Vector2(200, 200)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("backdrop", r.color)
		mat.set_shader_parameter("ring", Color.WHITE)
		pic.material = mat
		strip.add_child(pic)
	await _frames(6)
	await _save("racers_portraits")
	quit()


func _stage() -> void:
	_world = Node3D.new()
	root.add_child(_world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.78, 0.95)
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = Color(0.33, 0.33, 0.38)
	ground.material_override = gm
	_world.add_child(ground)
	_cam = Camera3D.new()
	_world.add_child(_cam)
	_cam.current = true
	for i in KartRoster.RACERS.size():
		var r: Dictionary = KartRoster.RACERS[i]
		var v := KartView.new()
		v.setup(r)
		_world.add_child(v)
		var k := KartState.new()
		k.racer_id = r.id
		k.pos = Vector3((i % 4) * 2.9 - 4.35, 0.0, (i / 4) * 4.5)
		k.heading = 0.0
		_views.append(v)
		_states.append(k)


func _shot(eye: Vector3, at: Vector3, fov: float) -> void:
	_cam.fov = fov
	_cam.look_at_from_position(eye, at, Vector3.UP)


var _static := false


func _frames(n: int) -> void:
	for i in n:
		for j in _views.size() if not _static else 0:
			_views[j].sync(_states[j], 1.0 / 60.0)
		await process_frame


func _save(file: String) -> void:
	await _frames(3)
	var img := root.get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_out, file]
	img.save_png(path)
	print("CAPTURE %s draw_calls=%d primitives=%d" % [path,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])


## Times `sync` on the CPU and the render with and without the karts (desktop numbers; the
## tablet's are several times larger, but the ratio is what matters).
func _bench() -> void:
	_shot(Vector3(1.0, 2.6, 9.5), Vector3(0.0, 0.6, -2.0), 55.0)
	for j in _states.size():
		_states[j].speed = 15.0
		_states[j].steer = sin(j * 1.3)
	var t0 := Time.get_ticks_usec()
	var n := 600
	for f in n:
		for j in _views.size():
			_views[j].sync(_states[j], 1.0 / 60.0)
	var sync_us := float(Time.get_ticks_usec() - t0) / n
	print("BENCH sync 8 karts: %.1f us a frame (%.1f us a kart)" % [sync_us, sync_us / 8.0])
	var vp := root.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	if OS.get_environment("BENCH_NO_OUTLINE") != "":
		for v in _views:
			for m in v.find_children("*", "MeshInstance3D", true, false):
				if m.material_override is ShaderMaterial:
					m.material_override.next_pass = null
	if OS.get_environment("BENCH_STATIC") != "":
		_static = true
	for shown in [true, false]:
		for v in _views:
			v.visible = shown
		await _frames(30)
		var cpu := 0.0
		var gpu := 0.0
		var dc := 0.0
		var prims := 0.0
		for f in 120:
			await _frames(1)
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
			dc += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		print("BENCH karts=%s render cpu=%.3f ms gpu=%.3f ms draw_calls=%.0f primitives=%.0f" % [shown, cpu / 120.0,
			gpu / 120.0, dc / 120.0, prims / 120.0])
