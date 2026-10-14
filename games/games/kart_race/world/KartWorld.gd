class_name KartWorld
extends Node3D
## Kart Race's world (#43), dressed for the hero slice: Meadow Ring in late-afternoon sun.
## Built from a `KartTrackModel`, so any track and either direction works.
##
## Everything is procedural (KartMeshKit) and lit by hand (KartLook, shaders/): no engine light
## pass, no per-pixel fog. The road is one unshaded mesh whose shader paints asphalt, lines, the
## chequered line, grid boxes, kerbs, tyre marks and verges from track-space UVs. Repeated
## things are MultiMeshes: trees, tyre stacks, fences, flowers, flags, the crowd, clouds.
##
## Draw calls (about 22): sky, road, barriers, ground, embankments, hills, 3 tree kinds, tyre
## stacks, fences, flowers, stand, crowd, gate, lamps, banners, flag poles, flags, windmill (2),
## clouds.

const ROAD_STEP := 2.0  ## metres between mesh rows along the track
const SKIRT := 30.0  ## the embankment beyond the barrier, sloping down to the ground
const GROUND_Y := -0.6
const WALL_HEIGHT := 0.95
const TREE_CLEARANCE := 5.0  ## trees keep this far beyond the barrier
const HILL_R0 := 300.0  ## the hills start this far from the track's centre
const HILL_R1 := 760.0

const WALL_A := Color(0.96, 0.96, 0.97)
const WALL_B := Color(0.16, 0.52, 0.86)
const WALL_RAIL := Color(0.9, 0.2, 0.16)
const FLAG_COLORS := [Color(0.95, 0.25, 0.2), Color(1.0, 0.8, 0.15), Color(0.2, 0.6, 1.0),
	Color(0.35, 0.85, 0.35), Color(0.75, 0.35, 0.95), Color(1.0, 0.5, 0.15), Color(0.98, 0.98, 0.98)]

## Dev switches (KartRace's tuning file, [world] section): road, walls, ground, scenery, each
## true by default. Set before `build`.
var tuning := {}
var track: KartTrackModel
var centre := Vector3.ZERO

var _built: Node3D
var _road_mat: ShaderMaterial
var _ground_mat: ShaderMaterial
var _scenery_mat: ShaderMaterial
var _foliage_mat: ShaderMaterial
var _tint_mat: ShaderMaterial
var _flag_mat: ShaderMaterial
var _banner_mat: ShaderMaterial
var _crowd_mat: ShaderMaterial
var _lamps_mat: ShaderMaterial
var _blades: Node3D
var _env: WorldEnvironment
var _halos: MultiMeshInstance3D


func _ready() -> void:
	_build_environment()
	_road_mat = KartLook.material("road.gdshader")
	_road_mat.set_shader_parameter("kerb_width", KartTrackModel.KERB_WIDTH)
	_road_mat.set_shader_parameter("grid_first", KartRaceLogic.GRID_FIRST)
	_road_mat.set_shader_parameter("grid_gap", KartRaceLogic.GRID_GAP)
	_road_mat.set_shader_parameter("grid_d", KartRaceLogic.GRID_D)
	_ground_mat = KartLook.material("ground.gdshader")
	_scenery_mat = KartLook.material("scenery.gdshader")
	_foliage_mat = KartLook.material("scenery.gdshader")
	_foliage_mat.set_shader_parameter("sway", 0.22)
	_tint_mat = KartLook.material("scenery.gdshader")
	_tint_mat.set_shader_parameter("tint_custom", true)
	_flag_mat = KartLook.material("flag.gdshader")
	_flag_mat.set_shader_parameter("tint_custom", true)
	_banner_mat = KartLook.material("flag.gdshader")
	_banner_mat.set_shader_parameter("hang", 1.0)
	_banner_mat.set_shader_parameter("amplitude", 0.12)
	_banner_mat.set_shader_parameter("speed", 3.0)
	_crowd_mat = KartLook.material("crowd.gdshader")
	_crowd_mat.set_shader_parameter("sprite", _crowd_sprite())
	_lamps_mat = ShaderMaterial.new()
	_lamps_mat.shader = KartLook.shader("lamps.gdshader")


## (Re)builds everything for `model` (a new track, or the same one reversed).
func build(model: KartTrackModel) -> void:
	track = model
	if _built:
		_built.queue_free()
	_built = Node3D.new()
	_built.name = "Track"
	add_child(_built)
	centre = _track_centre()
	_road_mat.set_shader_parameter("track_length", track.length)
	var road := KartMeshKit.mesh_node(_road_mesh(), _road_mat, "Road")
	road.visible = tuning.get("road", true)
	_built.add_child(road)
	var walls := KartMeshKit.mesh_node(_wall_mesh(), _scenery_mat, "Barriers")
	walls.visible = tuning.get("walls", true)
	_built.add_child(walls)
	var ground := Node3D.new()
	ground.name = "Ground"
	ground.visible = tuning.get("ground", true)
	_built.add_child(ground)
	ground.add_child(KartMeshKit.mesh_node(_ground_mesh(), _ground_mat, "Meadow"))
	ground.add_child(KartMeshKit.mesh_node(_skirt_mesh(), _ground_mat, "Embankments"))
	ground.add_child(KartMeshKit.mesh_node(_hill_mesh(), _ground_mat, "Hills"))
	var scenery := Node3D.new()
	scenery.name = "Scenery"
	scenery.visible = tuning.get("scenery", true)
	_built.add_child(scenery)
	var woods := _sector_kits()
	var foliage := {}
	_build_trees(foliage, woods)
	_build_flowers(foliage)
	_commit_cells(scenery, foliage, "Foliage", _foliage_mat)
	_commit_sectors(scenery, woods, "Woods", _foliage_mat)
	var props := {}
	_build_tyres(props)
	_build_fences(props)
	_commit_cells(scenery, props, "Props", _scenery_mat)
	_build_grandstand(scenery)
	_build_gate(scenery)
	_build_flags(scenery)
	_build_windmill(scenery)
	_build_clouds(scenery)
	set_start_lights(0)


## The start gantry: 0 dark, 1-5 red lamps lit, 6 all green.
func set_start_lights(stage: int) -> void:
	_lamps_mat.set_shader_parameter("stage", stage)
	if _halos:
		var mm := _halos.multimesh
		mm.visible_instance_count = mini(stage, 5) if stage < 6 else 5
		var color := Color(1.0, 0.25, 0.15, 0.85) if stage < 6 else Color(0.4, 1.0, 0.5, 0.85)
		for i in mm.instance_count:
			mm.set_instance_color(i, color)


## Environment glow (a dev switch, KartRace's tuning file [render] glow): two levels over the
## bright sky, lines and lamps. Off by default: the faked additive halos cost nothing.
func set_glow(on: bool) -> void:
	var env := _env.environment
	env.glow_enabled = on
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.85
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	for i in 7:
		env.set_glow_level(i, 1.0 if i == 1 or i == 2 else 0.0)


func _process(delta: float) -> void:
	if _blades:
		_blades.rotate_object_local(Vector3.FORWARD, delta * 0.7)


# --- Environment ---

func _build_environment() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = KartLook.shader("sky.gdshader")
	sky_mat.set_shader_parameter("noise_tex", KartLook.noise())
	sky_mat.set_shader_parameter("sun_dir", KartLook.SUN_DIR.normalized())
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = KartLook.SKY_AMBIENT
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_env = WorldEnvironment.new()
	_env.name = "Environment"
	_env.environment = env
	add_child(_env)


func _track_centre() -> Vector3:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var s := 0.0
	while s < track.length:
		var p := track.sample(s).position
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
		s += 10.0
	return Vector3((lo.x + hi.x) * 0.5, GROUND_Y, (lo.y + hi.y) * 0.5)


# --- Road ---

## Rows every ROAD_STEP metres, columns at the road edges, kerbs and barrier feet. UV = (d, s),
## UV2.x = half-width, COLOR = (racing line, corner strength).
func _road_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := maxi(8, roundi(track.length / ROAD_STEP))
	var step := track.length / rows
	var kerb := KartTrackModel.KERB_WIDTH
	var cols := []  # per row: [s, hw, [d...], color]
	for i in rows + 1:
		var s := i * step
		var hw := track.half_width(s)
		var edge := hw + track.verge
		var line := clampf(track.racing_line(s), -10.0, 10.0)
		var corner := clampf(absf(track.curvature(s)) * 45.0, 0.0, 1.0)
		cols.append([s, hw, [-edge, -hw - kerb, -hw, 0.0, hw, hw + kerb, edge],
			Color((line + 10.0) / 20.0, corner, 0.0)])
	for i in rows:
		var a: Array = cols[i]
		var b: Array = cols[i + 1]
		for c in 6:
			var p := [[a, c], [b, c], [b, c + 1], [a, c], [b, c + 1], [a, c + 1]]
			for v in p:
				var row: Array = v[0]
				var d: float = row[2][v[1]]
				var s: float = row[0]
				st.set_color(row[3])
				st.set_uv(Vector2(d, s))
				st.set_uv2(Vector2(row[1], 0.0))
				st.set_normal(Vector3.UP)
				st.add_vertex(track.position_at(fmod(s, track.length), d))
	return st.commit()


## The barrier: panels alternating white and blue under a red rail, darker at the foot.
func _wall_mesh() -> ArrayMesh:
	var kit := KartMeshKit.new()
	var rows := maxi(8, roundi(track.length / ROAD_STEP))
	var step := track.length / rows
	var top := Vector3.UP * WALL_HEIGHT
	var rail := Vector3.UP * (WALL_HEIGHT + 0.14)
	for i in rows:
		var s0 := i * step
		var s1 := (i + 1) * step
		var color: Color = WALL_A if (i >> 1) & 1 == 0 else WALL_B
		for side: float in [-1.0, 1.0]:
			var e0 := track.half_width(s0) + track.verge
			var e1 := track.half_width(fmod(s1, track.length)) + track.verge
			var a := track.position_at(s0, side * e0)
			var b := track.position_at(fmod(s1, track.length), side * e1)
			var a2 := track.position_at(s0, side * (e0 + 0.45))
			var b2 := track.position_at(fmod(s1, track.length), side * (e1 + 0.45))
			var foot := color.darkened(0.35)
			# Front face (towards the road), shaded darker at the foot: two strips.
			var mid := Vector3.UP * (WALL_HEIGHT * 0.35)
			if side > 0.0:
				kit.quad(a, a + mid, b + mid, b, foot)
				kit.quad(a + mid, a + top, b + top, b + mid, color)
				kit.quad(a + top, a + rail, b + rail, b + top, WALL_RAIL)
				kit.quad(a + rail, a2 + rail, b2 + rail, b + rail, WALL_RAIL.darkened(0.1))
			else:
				kit.quad(b, b + mid, a + mid, a, foot)
				kit.quad(b + mid, b + top, a + top, a + mid, color)
				kit.quad(b + top, b + rail, a + rail, a + top, WALL_RAIL)
				kit.quad(b + rail, b2 + rail, a2 + rail, a + rail, WALL_RAIL.darkened(0.1))
	return kit.commit()


# --- Ground ---

func _ground_mesh() -> ArrayMesh:
	var kit := KartMeshKit.new()
	var r := HILL_R0 + 40.0
	var segs := 32
	var c := centre + Vector3.UP * 0.0
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		kit.quad(c, c + Vector3(cos(a1), 0, sin(a1)) * r, c + Vector3(cos(a0), 0, sin(a0)) * r, c, Color.WHITE)
	return kit.commit()


## From the barrier's foot out and down to the meadow.
func _skirt_mesh() -> ArrayMesh:
	var kit := KartMeshKit.new()
	var rows := maxi(8, roundi(track.length / (ROAD_STEP * 2.0)))
	var step := track.length / rows
	for i in rows:
		var s0 := i * step
		var s1 := fmod((i + 1) * step, track.length)
		for side: float in [-1.0, 1.0]:
			var e0 := track.half_width(s0) + track.verge + 0.4
			var e1 := track.half_width(s1) + track.verge + 0.4
			var a := track.position_at(s0, side * e0)
			var b := track.position_at(s1, side * e1)
			var cc := track.position_at(s1, side * (e1 + SKIRT))
			var d := track.position_at(s0, side * (e0 + SKIRT))
			cc.y = GROUND_Y + 0.02
			d.y = GROUND_Y + 0.02
			kit.quad(a, b, cc, d, Color.WHITE)
	var mesh := kit.commit()
	return mesh


func _hill_height(p: Vector2, noise: FastNoiseLite) -> float:
	var r := p.distance_to(Vector2(centre.x, centre.z))
	var rise := smoothstep(HILL_R0, HILL_R0 + 180.0, r)
	var n := noise.get_noise_2d(p.x, p.y) * 0.5 + 0.5
	return GROUND_Y + rise * (12.0 + 55.0 * n) + smoothstep(HILL_R0 + 200.0, HILL_R1, r) * 40.0


## A ring of rolling hills around the whole circuit.
func _hill_mesh() -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = 31
	noise.frequency = 0.006
	noise.fractal_octaves = 3
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 72
	var rings := 12
	var pts := []
	for j in rings + 1:
		var r := lerpf(HILL_R0, HILL_R1, pow(float(j) / rings, 1.3))
		var row := []
		for i in segs:
			var a := TAU * i / segs
			var p := Vector2(centre.x + cos(a) * r, centre.z + sin(a) * r)
			row.append(Vector3(p.x, _hill_height(p, noise), p.y))
		pts.append(row)
	for j in rings:
		for i in segs:
			var i1 := (i + 1) % segs
			var tint := Color.WHITE.lerp(Color(0.86, 0.92, 1.0), float(j) / rings)
			for v in [pts[j][i], pts[j + 1][i], pts[j + 1][i1], pts[j][i], pts[j + 1][i1], pts[j][i1]]:
				st.set_color(tint)
				st.add_vertex(v)
	st.generate_normals()
	return st.commit()


## The surface height out here: the embankment, the meadow, or the hills.
func _ground_at(p: Vector3, near: KartTrackPoint) -> float:
	var edge := track.half_width(near.s) + track.verge + 0.4
	var out := absf(near.d) - edge
	var foot := track.position_at(near.s, signf(near.d) * edge).y
	return lerpf(foot, GROUND_Y, clampf(out / SKIRT, 0.0, 1.0))


## A spot `out` metres beyond the barrier at s on `side`, clear of every other stretch of road.
func _beyond(s: float, side: float, out: float, clearance := TREE_CLEARANCE) -> Variant:
	var edge := track.half_width(s) + track.verge
	var p := track.position_at(s, side * (edge + out))
	var near := track.project(p)
	if absf(near.d) < track.half_width(near.s) + track.verge + clearance:
		return null
	p.y = _ground_at(p, near)
	return p


# --- Scenery ---

func _tree_meshes() -> Array:
	var leaf := Color(0.30, 0.56, 0.18, 1.0)
	var trunk := Color(0.42, 0.28, 0.17, 0.0)
	# Round broadleaf: a trunk and a cluster of blobs, darker underneath.
	var kit := KartMeshKit.new()
	kit.ao_y0 = 1.0
	kit.ao_y1 = 5.5
	kit.ao_min = 0.5
	kit.add(KartMeshKit.cylinder(0.18, 0.3, 2.4, 5), KartMeshKit.xf(Vector3(0, 1.2, 0)), trunk)
	for b in [[Vector3(0, 3.6, 0), 1.95], [Vector3(1.1, 3.0, 0.3), 1.35], [Vector3(-1.0, 3.1, -0.4), 1.4],
			[Vector3(0.1, 4.6, -0.1), 1.3]]:
		var c := leaf.lerp(Color(0.45, 0.68, 0.22, 1.0), clampf((b[0].y - 3.0) / 1.7, 0.0, 1.0))
		c.a = clampf(b[0].y / 5.0, 0.0, 1.0)
		kit.add(KartMeshKit.sphere(b[1], 7, 3), KartMeshKit.xf(b[0]), c)
	var broad := kit.commit()
	# Pine: three stacked cones.
	kit = KartMeshKit.new()
	kit.ao_y0 = 0.5
	kit.ao_y1 = 7.0
	kit.ao_min = 0.45
	kit.add(KartMeshKit.cylinder(0.15, 0.25, 1.6, 5), KartMeshKit.xf(Vector3(0, 0.8, 0)), trunk)
	for k in 3:
		var y := 1.4 + k * 1.7
		var c := Color(0.16, 0.40, 0.22, clampf(y / 6.0, 0.0, 1.0)).lerp(Color(0.24, 0.5, 0.26, 1.0), k / 3.0)
		kit.add(KartMeshKit.cylinder(0.0, 2.1 - k * 0.55, 2.6, 7), KartMeshKit.xf(Vector3(0, y + 1.3, 0)), c)
	var pine := kit.commit()
	# Bush.
	kit = KartMeshKit.new()
	kit.ao_y0 = 0.0
	kit.ao_y1 = 1.4
	kit.ao_min = 0.5
	for b in [[Vector3(0, 0.6, 0), 0.9], [Vector3(0.7, 0.45, 0.2), 0.65]]:
		kit.add(KartMeshKit.sphere(b[1], 6, 3), KartMeshKit.xf(b[0]), Color(0.34, 0.58, 0.2, 0.5))
	var bush := kit.commit()
	# Far pine for the hills: two cones, few sides.
	kit = KartMeshKit.new()
	kit.ao_y0 = 0.0
	kit.ao_y1 = 6.0
	kit.ao_min = 0.5
	kit.add(KartMeshKit.cylinder(0.0, 2.0, 3.6, 5), KartMeshKit.xf(Vector3(0, 2.6, 0)), Color(0.18, 0.42, 0.22, 0.6))
	kit.add(KartMeshKit.cylinder(0.0, 1.4, 2.8, 5), KartMeshKit.xf(Vector3(0, 4.6, 0)), Color(0.24, 0.5, 0.26, 1.0))
	var far := kit.commit()
	return [broad, pine, bush, far]


## Static scenery is baked into one mesh per cell: the trackside scenery into CELL-metre squares
## (culled by the frustum and beyond CELL_RANGE metres), the woods on the hills into SECTORS
## wedges around the circuit's centre (culled by the frustum). One draw call each.
const SECTORS := 12
const CELL := 110.0
const CELL_RANGE := 330.0


func _sector_of(p: Vector3) -> int:
	var a := atan2(p.z - centre.z, p.x - centre.x)
	return posmod(int(floor((a + PI) / TAU * SECTORS)), SECTORS)


func _sector_kits() -> Array:
	var kits := []
	for i in SECTORS:
		kits.append(KartMeshKit.new())
	return kits


func _commit_sectors(parent: Node3D, kits: Array, node_name: String, mat: Material) -> void:
	for i in kits.size():
		var kit: KartMeshKit = kits[i]
		if not kit.is_empty():
			parent.add_child(KartMeshKit.mesh_node(kit.commit(), mat, "%s%d" % [node_name, i]))


## The trackside cell kit for `p` (created on demand).
func _cell(cells: Dictionary, p: Vector3) -> KartMeshKit:
	var key := Vector2i(floori((p.x - centre.x) / CELL), floori((p.z - centre.z) / CELL))
	if not cells.has(key):
		cells[key] = KartMeshKit.new()
	return cells[key]


func _commit_cells(parent: Node3D, cells: Dictionary, node_name: String, mat: Material) -> void:
	for key: Vector2i in cells:
		var kit: KartMeshKit = cells[key]
		if kit.is_empty():
			continue
		var node := KartMeshKit.mesh_node(kit.commit(), mat, "%s_%d_%d" % [node_name, key.x, key.y])
		node.visibility_range_end = CELL_RANGE
		node.visibility_range_end_margin = 20.0
		parent.add_child(node)


func _build_trees(cells: Dictionary, kits: Array) -> void:
	var meshes := _tree_meshes()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(track.def.id) + 7
	var placed := 0
	var tries := 0
	while placed < 200 and tries < 5000:
		tries += 1
		var s := rng.randf_range(0.0, track.length)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var out := TREE_CLEARANCE + rng.randf_range(0.0, 60.0) * rng.randf()
		if side > 0.0 and out < 22.0 and _in_stand(s):
			continue
		var spot = _beyond(s, side, out)
		if spot == null:
			continue
		var kind := 2 if rng.randf() < 0.22 else (1 if rng.randf() < 0.35 else 0)
		var size := rng.randf_range(0.8, 1.35)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(size, size * rng.randf_range(0.9, 1.25), size))
		var p: Vector3 = spot - Vector3.UP * 0.15
		_cell(cells, p).add_baked(meshes[kind], Transform3D(basis, p))
		placed += 1
	# Woods on the hills' lower slopes.
	var noise := FastNoiseLite.new()
	noise.seed = 31
	noise.frequency = 0.006
	noise.fractal_octaves = 3
	for i in 100:
		var a := rng.randf() * TAU
		var r := rng.randf_range(HILL_R0 - 20.0, HILL_R0 + 170.0)
		var p := Vector2(centre.x + cos(a) * r, centre.z + sin(a) * r)
		var kind := 3 if rng.randf() < 0.7 else 0
		var size := rng.randf_range(1.3, 2.1)
		var at := Vector3(p.x, _hill_height(p, noise) - 0.3, p.y)
		kits[_sector_of(at)].add_baked(meshes[kind], Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), at))


## Tyre stacks in front of the barrier on the outside of the corners.
func _build_tyres(cells: Dictionary) -> void:
	var kit := KartMeshKit.new()
	var tyre := KartMeshKit.cylinder(0.42, 0.42, 0.3, 6)
	for k in 3:
		kit.add(tyre, KartMeshKit.xf(Vector3(0, 0.15 + k * 0.3, 0)), Color(0.15, 0.15, 0.16, 0.0) if k != 1 else Color(1, 1, 1, 0.0))
	var mesh := kit.commit()
	var tints := [Color(0.95, 0.2, 0.16), Color(0.98, 0.98, 0.98), Color(0.2, 0.55, 1.0), Color(1.0, 0.8, 0.15)]
	var s := 0.0
	var n := 0
	while s < track.length:
		var k := track.curvature(s)
		if absf(k) > 0.011:
			var side := -signf(k)  # the outside of the corner
			var edge := track.half_width(s) + track.verge - 0.5
			var p := track.position_at(s, side * edge)
			var tint: Color = tints[n % tints.size()]
			_cell(cells, p).add_baked(mesh, Transform3D(Basis(Vector3.UP, track.yaw_at(s)), p), Color(lerpf(1.0, tint.r, 0.8), lerpf(1.0, tint.g, 0.8), lerpf(1.0, tint.b, 0.8)) if n % 2 == 0 else tint)
			n += 1
			s += 1.6
		else:
			s += 4.0


## White post-and-rail fences along the meadows.
func _build_fences(cells: Dictionary) -> void:
	var kit := KartMeshKit.new()
	var white := Color(0.97, 0.96, 0.92, 0.0)
	kit.ao_y0 = 0.0
	kit.ao_y1 = 1.1
	kit.ao_min = 0.7
	kit.add(KartMeshKit.box(Vector3(0.14, 1.15, 0.14)), KartMeshKit.xf(Vector3(0, 0.57, 0)), white)
	for y: float in [0.45, 0.9]:
		kit.add(KartMeshKit.box(Vector3(0.07, 0.11, 3.0)), KartMeshKit.xf(Vector3(0, y, -1.5)), white)
	var mesh := kit.commit()
	for side: float in [-1.0, 1.0]:
		var s := 0.0
		while s < track.length:
			var spot = _beyond(s, side, 14.0, 6.0)
			var spot2 = _beyond(s + 4.0, side, 14.0, 6.0)
			if spot != null and spot2 != null:
				var dir: Vector3 = (spot2 - spot)
				dir.y = 0.0
				if dir.length() > 2.0 and dir.length() < 6.5:
					var basis := Basis.looking_at(dir.normalized(), Vector3.UP).scaled(Vector3(1, 1, dir.length() / 3.0))
					_cell(cells, spot).add_baked(mesh, Transform3D(basis, spot))
			s += 4.0


## Clumps of wildflowers on the embankments.
func _build_flowers(cells: Dictionary) -> void:
	var kit := KartMeshKit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var colors := [Color(1.0, 0.9, 0.25), Color(1, 1, 1), Color(0.95, 0.45, 0.75), Color(0.7, 0.5, 1.0), Color(1.0, 0.55, 0.2)]
	kit.add(KartMeshKit.sphere(0.32, 5, 1, true), KartMeshKit.xf(Vector3.ZERO, Vector3.ZERO, Vector3(1.4, 0.6, 1.4)), Color(0.3, 0.55, 0.18, 0.4))
	for i in 6:
		var p := Vector3(rng.randf_range(-0.55, 0.55), rng.randf_range(0.18, 0.42), rng.randf_range(-0.55, 0.55))
		var c: Color = colors[rng.randi() % colors.size()]
		c.a = 1.0
		kit.add(KartMeshKit.sphere(0.085, 4, 1), KartMeshKit.xf(p), c)
	var mesh := kit.commit()
	var placed := 0
	var tries := 0
	while placed < 360 and tries < 4000:
		tries += 1
		var s := rng.randf_range(0.0, track.length)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var spot = _beyond(s, side, rng.randf_range(1.0, 22.0), 0.8)
		if spot == null:
			continue
		var sc := rng.randf_range(0.8, 1.6)
		var p: Vector3 = spot
		_cell(cells, p).add_baked(mesh, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), p))
		placed += 1


## Whether s is along the grandstand (outside the start straight).
func _in_stand(s: float) -> bool:
	var ss := s - track.length if s > track.length * 0.5 else s
	return ss > -70.0 and ss < 26.0


## The grandstand on the outside of the start straight, full of fans.
func _build_grandstand(parent: Node3D) -> void:
	var s_mid := track.wrap(-22.0)
	var hw := track.half_width(s_mid)
	var yaw := track.yaw_at(s_mid)
	var side := 1.0
	var origin := track.position_at(s_mid, side * (hw + track.verge + 3.2))
	origin.y = track.position_at(s_mid, 0.0).y
	var stand := Node3D.new()
	stand.name = "Grandstand"
	# Local frame: -z along the track (forward), +x away from the road.
	stand.transform = Transform3D(Basis(Vector3.UP, yaw), origin)
	parent.add_child(stand)
	var length := 84.0
	var rows := 8
	var depth := 0.95
	var rise := 0.6
	var kit := KartMeshKit.new()
	kit.ao_y0 = 0.0
	kit.ao_y1 = 6.0
	kit.ao_min = 0.6
	var concrete := Color(0.78, 0.77, 0.74, 0.0)
	var seat_a := Color(0.15, 0.45, 0.85, 0.0)
	var seat_b := Color(1.0, 0.78, 0.15, 0.0)
	# Front wall with a coloured fascia.
	kit.add(KartMeshKit.box(Vector3(0.4, 1.4, length)), KartMeshKit.xf(Vector3(0.0, 0.7, 0)), concrete)
	kit.add(KartMeshKit.box(Vector3(0.45, 0.35, length)), KartMeshKit.xf(Vector3(-0.02, 1.25, 0)), Color(0.9, 0.2, 0.18, 0.0))
	for r in rows:
		var x := 0.6 + r * depth
		var y := 1.2 + r * rise
		kit.add(KartMeshKit.box(Vector3(depth, y, length)), KartMeshKit.xf(Vector3(x + depth * 0.5, y * 0.5, 0)), concrete)
		kit.add(KartMeshKit.box(Vector3(0.35, 0.22, length)), KartMeshKit.xf(Vector3(x + 0.55, y + 0.11, 0)), seat_a if r % 2 == 0 else seat_b)
	var back_x := 0.6 + rows * depth
	var top_y := 1.2 + rows * rise
	kit.add(KartMeshKit.box(Vector3(0.4, top_y + 2.6, length)), KartMeshKit.xf(Vector3(back_x + 0.2, (top_y + 2.6) * 0.5, 0)), Color(0.2, 0.26, 0.55, 0.0))
	kit.add(KartMeshKit.box(Vector3(0.1, 0.5, length)), KartMeshKit.xf(Vector3(back_x - 0.02, top_y + 0.9, 0)), Color(1.0, 0.8, 0.2, 0.0))
	# Roof on posts, striped.
	for i in 8:
		var z := -length * 0.5 + 2.0 + i * (length - 4.0) / 7.0
		kit.add(KartMeshKit.cylinder(0.12, 0.12, 4.6, 6), KartMeshKit.xf(Vector3(0.3, top_y + 0.6 - 1.6, z)), Color(0.9, 0.9, 0.92, 0.0))
	for i in 12:
		var z0 := -length * 0.5 + i * length / 12.0
		var stripe := Color(0.97, 0.97, 0.97, 0.0) if i % 2 == 0 else Color(0.92, 0.24, 0.2, 0.0)
		kit.add(KartMeshKit.box(Vector3(back_x + 1.4, 0.25, length / 12.0)),
			KartMeshKit.xf(Vector3(back_x * 0.5 + 0.1, top_y + 2.75, z0 + length / 24.0), Vector3(0, 0, -7)), stripe)
	stand.add_child(KartMeshKit.mesh_node(kit.commit(), _scenery_mat, "Stand"))
	# The crowd.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var quad := QuadMesh.new()
	quad.size = Vector2(0.7, 1.0)
	quad.center_offset = Vector3(0, 0.5, 0)
	var xfs := []
	var custom := []
	var shirts := [Color(0.95, 0.25, 0.2), Color(1.0, 0.8, 0.2), Color(0.25, 0.55, 1.0), Color(0.3, 0.8, 0.4),
		Color(0.95, 0.5, 0.8), Color(0.98, 0.98, 0.98), Color(0.6, 0.35, 0.9), Color(1.0, 0.55, 0.15), Color(0.2, 0.75, 0.8)]
	for r in rows:
		var x := 0.6 + r * depth + 0.45
		var y := 1.2 + r * rise - 0.15
		var z := -length * 0.5 + 0.6
		while z < length * 0.5 - 0.5:
			if rng.randf() < 0.9:
				var sc := rng.randf_range(0.85, 1.1)
				xfs.append(Transform3D(Basis().scaled(Vector3.ONE * sc), Vector3(x + rng.randf_range(-0.1, 0.1), y, z)))
				var c: Color = shirts[rng.randi() % shirts.size()]
				c.a = rng.randf()
				custom.append(c)
			z += rng.randf_range(0.55, 0.75)
	stand.add_child(_mm(quad, xfs, "Crowd", _crowd_mat, custom))


## The start gate over the line: pillars, a beam with five lamps, chequered banners, pennants.
func _build_gate(parent: Node3D) -> void:
	var s := 1.0
	var hw := track.half_width(s)
	var yaw := track.yaw_at(s)
	var gate := Node3D.new()
	gate.name = "StartGate"
	gate.transform = Transform3D(Basis(Vector3.UP, yaw), track.position_at(s, 0.0))
	parent.add_child(gate)
	var span := hw + KartTrackModel.KERB_WIDTH + 1.4
	var height := 6.4
	var kit := KartMeshKit.new()
	kit.ao_y0 = 0.0
	kit.ao_y1 = 4.0
	kit.ao_min = 0.65
	var navy := Color(0.12, 0.14, 0.3, 0.0)
	var white := Color(0.96, 0.96, 0.97, 0.0)
	for side: float in [-1.0, 1.0]:
		kit.add(KartMeshKit.box(Vector3(1.0, height + 1.2, 1.0)), KartMeshKit.xf(Vector3(side * span, (height + 1.2) * 0.5, 0)), white)
		for k in 4:
			kit.add(KartMeshKit.box(Vector3(1.04, 0.4, 1.04)), KartMeshKit.xf(Vector3(side * span, 0.8 + k * 1.5, 0)), Color(0.9, 0.2, 0.17, 0.0))
		kit.add(KartMeshKit.box(Vector3(1.6, 0.5, 1.6)), KartMeshKit.xf(Vector3(side * span, 0.25, 0)), navy)
	kit.add(KartMeshKit.box(Vector3(span * 2.0 + 1.0, 1.5, 1.1)), KartMeshKit.xf(Vector3(0, height, 0)), navy)
	# Chequered fascia on both faces of the beam.
	var cells := 24
	for face: float in [-1.0, 1.0]:
		for i in cells:
			for j in 2:
				var x0 := -span - 0.5 + (span * 2.0 + 1.0) * i / cells
				var x1 := -span - 0.5 + (span * 2.0 + 1.0) * (i + 1) / cells
				var y0 := height + 0.75 - 0.4 * (j + 1)
				var y1 := y0 + 0.4
				var c := Color(0.05, 0.05, 0.06) if (i + j) % 2 == 0 else Color(0.97, 0.97, 0.97)
				var z := face * 0.56
				if face > 0.0:
					kit.quad(Vector3(x0, y0, z), Vector3(x0, y1, z), Vector3(x1, y1, z), Vector3(x1, y0, z), c)
				else:
					kit.quad(Vector3(x1, y0, z), Vector3(x1, y1, z), Vector3(x0, y1, z), Vector3(x0, y0, z), c)
	# Lamp housings on the grid side (+z: behind the line, where the karts wait).
	kit.add(KartMeshKit.box(Vector3(5.2, 1.0, 0.5)), KartMeshKit.xf(Vector3(0, height - 1.15, 0.5)), Color(0.08, 0.08, 0.1, 0.0))
	gate.add_child(KartMeshKit.mesh_node(kit.commit(), _scenery_mat, "Gate"))
	var lamps := KartMeshKit.new()
	var halo_xfs := []
	for i in 5:
		var x := -2.0 + i * 1.0
		lamps.add(KartMeshKit.sphere(0.3, 10, 5), KartMeshKit.xf(Vector3(x, height - 1.15, 0.78)), Color(i / 5.0, 1.0, 0.0))
		halo_xfs.append(Transform3D(Basis().scaled(Vector3.ONE * 1.6), gate.transform * Vector3(x, height - 1.15, 0.95)))
	gate.add_child(KartMeshKit.mesh_node(lamps.commit(), _lamps_mat, "Lamps"))
	# Fake glow: additive halos for the lit lamps (cheaper than Environment glow).
	var halo_mat := StandardMaterial3D.new()
	halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	halo_mat.billboard_keep_scale = true
	halo_mat.vertex_color_use_as_albedo = true
	halo_mat.albedo_texture = KartMeshKit.soft_disc(64)
	halo_mat.no_depth_test = false
	halo_mat.disable_fog = true
	var hq := QuadMesh.new()
	hq.size = Vector2(1.0, 1.0)
	hq.material = halo_mat
	_halos = MultiMeshInstance3D.new()
	_halos.name = "LampHalos"
	_halos.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = hq
	mm.instance_count = halo_xfs.size()
	for i in halo_xfs.size():
		mm.set_instance_transform(i, halo_xfs[i])
		mm.set_instance_color(i, Color(1, 0.3, 0.2, 0.9))
	_halos.multimesh = mm
	parent.add_child(_halos)
	# Chequered banners hanging from the beam on the road side.
	var banner := SurfaceTool.new()
	banner.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b: float in [-1.0, 1.0]:
		var x0 := b * (span - 2.6) - 1.0
		var top := height - 0.75
		var w := 2.0
		var h := 1.6
		var nx := 6
		var ny := 5
		for i in nx:
			for j in ny:
				var c := Color(0.05, 0.05, 0.06) if (i + j) % 2 == 0 else Color(0.97, 0.97, 0.97)
				var u0 := float(i) / nx
				var u1 := float(i + 1) / nx
				var v0 := float(j) / ny
				var v1 := float(j + 1) / ny
				var corners := [[u0, v0], [u1, v0], [u1, v1], [u0, v0], [u1, v1], [u0, v1]]
				for uv in corners:
					banner.set_color(c)
					banner.set_uv(Vector2(uv[0], uv[1]))
					banner.set_normal(Vector3.BACK)
					banner.add_vertex(Vector3(x0 + uv[0] * w, top - uv[1] * h, 0.62))
	var bn := KartMeshKit.mesh_node(banner.commit(), _banner_mat, "Banners")
	gate.add_child(bn)


## Flags on tall poles along the infield side of the start straight, and on the gate.
func _build_flags(parent: Node3D) -> void:
	var poles := KartMeshKit.new()
	var flag_xfs := []
	var custom := []
	var n := 0
	var s := -70.0
	while s < 40.0:
		var ss := track.wrap(s)
		var hw := track.half_width(ss)
		for side: float in [-1.0, 1.0]:
			if side > 0.0 and s > -66.0 and s < 22.0:
				continue  # the grandstand is there
			var p := track.position_at(ss, side * (hw + track.verge + 1.2))
			poles.add(KartMeshKit.cylinder(0.06, 0.08, 7.0, 5), KartMeshKit.xf(p + Vector3.UP * 3.5), Color(0.92, 0.92, 0.94, 0.0))
			var yaw := track.yaw_at(ss) + PI * 0.5
			flag_xfs.append(Transform3D(Basis(Vector3.UP, yaw), p + Vector3.UP * 6.3))
			custom.append(FLAG_COLORS[n % FLAG_COLORS.size()])
			n += 1
		s += 7.0
	parent.add_child(KartMeshKit.mesh_node(poles.commit(), _scenery_mat, "FlagPoles"))
	var cloth := PlaneMesh.new()
	cloth.size = Vector2(1.7, 1.05)
	cloth.subdivide_width = 8
	cloth.orientation = PlaneMesh.FACE_Z
	cloth.center_offset = Vector3(0.85, -0.5, 0)
	# UV.x runs along the cloth from the pole (the wave grows with it).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var arr := cloth.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	for i in idx:
		st.set_color(Color.WHITE if uvs[i].y > 0.25 else Color(0.85, 0.85, 0.85))
		st.set_uv(Vector2(verts[i].x / 1.7, uvs[i].y))
		st.set_normal(Vector3.BACK)
		st.add_vertex(verts[i])
	parent.add_child(_mm(st.commit(), flag_xfs, "Flags", _flag_mat, custom))


## A windmill on a rise in the infield, its sails turning.
func _build_windmill(parent: Node3D) -> void:
	var spot := Vector3.ZERO
	var found := false
	for attempt in [[70.0, -48.0], [40.0, -55.0], [110.0, -50.0], [70.0, 48.0]]:
		var s: float = track.wrap(attempt[0])
		var p := track.position_at(s, attempt[1])
		var near := track.project(p)
		if absf(near.d) > track.half_width(near.s) + track.verge + 18.0:
			spot = p
			spot.y = GROUND_Y
			found = true
			break
	if not found:
		return
	var mill := Node3D.new()
	mill.name = "Windmill"
	var look := track.position_at(track.wrap(-20.0), 0.0)
	look.y = spot.y
	mill.transform = Transform3D(Basis.looking_at((look - spot).normalized(), Vector3.UP), spot)
	parent.add_child(mill)
	var kit := KartMeshKit.new()
	kit.ao_y0 = 0.0
	kit.ao_y1 = 10.0
	kit.ao_min = 0.65
	kit.add(KartMeshKit.cylinder(2.3, 3.6, 13.0, 8), KartMeshKit.xf(Vector3(0, 6.5, 0)), Color(0.96, 0.93, 0.86, 0.0))
	kit.add(KartMeshKit.cylinder(0.0, 2.8, 3.4, 8), KartMeshKit.xf(Vector3(0, 14.6, 0)), Color(0.55, 0.25, 0.18, 0.0))
	kit.add(KartMeshKit.box(Vector3(1.2, 2.2, 0.3)), KartMeshKit.xf(Vector3(0, 1.1, -3.4)), Color(0.4, 0.26, 0.16, 0.0))
	for y: float in [5.5, 9.5]:
		kit.add(KartMeshKit.box(Vector3(0.9, 0.9, 0.2)), KartMeshKit.xf(Vector3(0, y, -3.0 + (y - 5.5) * 0.14)), Color(0.25, 0.35, 0.5, 0.0))
	kit.add(KartMeshKit.cylinder(0.35, 0.35, 1.2, 8), KartMeshKit.xf(Vector3(0, 13.2, -2.6), Vector3(90, 0, 0)), Color(0.3, 0.2, 0.15, 0.0))
	mill.add_child(KartMeshKit.mesh_node(kit.commit(), _scenery_mat, "Tower"))
	var blades := KartMeshKit.new()
	for i in 4:
		var rot := Basis(Vector3.FORWARD, i * PI * 0.5)
		blades.add(KartMeshKit.box(Vector3(0.3, 7.5, 0.2)), Transform3D(rot, rot * Vector3(0, 4.0, 0)), Color(0.45, 0.32, 0.22, 0.0))
		blades.add(KartMeshKit.box(Vector3(1.5, 6.0, 0.08)), Transform3D(rot, rot * Vector3(0.85, 4.6, 0.05)), Color(0.97, 0.95, 0.9, 0.0))
	_blades = Node3D.new()
	_blades.name = "Sails"
	_blades.position = Vector3(0, 13.2, -3.3)
	mill.add_child(_blades)
	_blades.add_child(KartMeshKit.mesh_node(blades.commit(), _scenery_mat, "SailMesh"))


## Soft cumulus cards far away, over the hills.
func _build_clouds(parent: Node3D) -> void:
	var img := Image.create(128, 64, true, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var blobs := []
	for i in 9:
		blobs.append([Vector2(rng.randf_range(22, 106), rng.randf_range(30, 44) - absf(i - 4) * 1.5), rng.randf_range(12, 22)])
	for y in 64:
		for x in 128:
			var a := 0.0
			for b in blobs:
				var r: float = Vector2(x, y).distance_to(b[0]) / b[1]
				a = maxf(a, clampf(1.2 - r, 0.0, 1.0))
			a *= smoothstep(60.0, 44.0, float(y))
			var shade := lerpf(1.0, 0.82, clampf((y - 26.0) / 30.0, 0.0, 1.0))
			img.set_pixel(x, y, Color(shade, shade * 0.99, shade * 1.02, clampf(a * 1.4, 0.0, 1.0)))
	img.generate_mipmaps()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.billboard_keep_scale = true
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.albedo_color = Color(1.0, 0.97, 0.93)
	mat.disable_fog = true
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 1.0)
	quad.material = mat
	var xfs := []
	for i in 26:
		var a := TAU * i / 26.0 + rng.randf_range(-0.12, 0.12)
		var r := rng.randf_range(560.0, 820.0)
		var sc := rng.randf_range(70.0, 150.0)
		xfs.append(Transform3D(Basis().scaled(Vector3(sc, sc * 0.55, sc)),
			centre + Vector3(cos(a) * r, rng.randf_range(90.0, 230.0), sin(a) * r)))
	parent.add_child(KartMeshKit.multimesh_node(quad, xfs, "Clouds"))


# --- Helpers ---

func _mm(mesh: Mesh, xfs: Array, node_name: String, mat: Material, custom: Array = []) -> MultiMeshInstance3D:
	var node := KartMeshKit.multimesh_node(mesh, xfs, node_name, custom)
	node.material_override = mat
	return node


## The crowd sprite: a fan in a T-shirt (R), the head (G) and raised arms (B), 32x48.
static func _crowd_sprite() -> ImageTexture:
	var w := 32
	var h := 48
	var img := Image.create(w, h, true, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var head := p.distance_to(Vector2(16, 12)) < 7.0
			var body := Rect2(7, 19, 18, 29).has_point(p) and p.distance_to(Vector2(16, 26)) < 13.5
			var arms := (absf(p.x - 5.0) < 2.2 or absf(p.x - 27.0) < 2.2) and p.y > 6.0 and p.y < 24.0
			var c := Color(0, 0, 0, 0)
			if head:
				c = Color(0, 1, 0, 1)
			elif body:
				c = Color(1, 0, 0, 1)
			elif arms:
				c = Color(0, 0, 1, 1)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
