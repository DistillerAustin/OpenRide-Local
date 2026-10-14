class_name KartWorld
extends Node3D
## Kart Race's world (#43), placeholder art for the walking skeleton: one vertex-coloured, unshaded
## mesh for the road, kerbs, verges and a terrain skirt; one for the barriers; a ground plane; a
## MultiMesh of cone trees; a flat sky colour and one sun (for the karts). Built from a
## `KartTrackModel`, so any track and either direction works. The world agent replaces all of it
## (themes, shaders, props, sky, the start gate) and owns this file.
##
## Draw calls: road 1, barriers 1, ground 1, trees 1.

const ROAD_STEP := 2.0  ## metres between mesh rows along the track
const SKIRT := 30.0  ## the terrain band beyond the barrier, sloping down to the ground
const GROUND_Y := -0.6
const WALL_HEIGHT := 0.9
const TREES := 160
const TREE_CLEARANCE := 4.0  ## trees keep this far beyond the barrier

const ROAD := Color(0.33, 0.34, 0.38)
const ROAD_ALT := Color(0.36, 0.37, 0.41)
const KERB_A := Color(0.88, 0.16, 0.14)
const KERB_B := Color(0.96, 0.96, 0.96)
const VERGE := Color(0.42, 0.7, 0.28)
const SKIRT_COLOR := Color(0.36, 0.62, 0.25)
const GROUND := Color(0.34, 0.58, 0.24)
const WALL_A := Color(0.92, 0.92, 0.95)
const WALL_B := Color(0.2, 0.45, 0.95)
const LINE_A := Color(0.05, 0.05, 0.06)
const LINE_B := Color(0.97, 0.97, 0.97)
const BOOST := Color(1.0, 0.55, 0.1)
const ITEMS := Color(0.3, 0.9, 1.0)
const SKY := Color(0.55, 0.78, 0.98)

## Dev switches (KartRace's tuning file, [world] section): road, walls, ground, scenery, each
## true by default. Set before `build`.
var tuning := {}
var track: KartTrackModel

var _road: MeshInstance3D
var _walls: MeshInstance3D
var _ground: MeshInstance3D
var _trees: MultiMeshInstance3D
var _flat: StandardMaterial3D


func _ready() -> void:
	_build_environment()
	_flat = StandardMaterial3D.new()
	_flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flat.vertex_color_use_as_albedo = true
	_flat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_road = _mesh_node("Road")
	_walls = _mesh_node("Barriers")
	_ground = _mesh_node("Ground")
	_trees = MultiMeshInstance3D.new()
	_trees.name = "Trees"
	_trees.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trees)


## (Re)builds everything for `model` (a new track, or the same one reversed).
func build(model: KartTrackModel) -> void:
	track = model
	_road.mesh = _road_mesh()
	_walls.mesh = _wall_mesh()
	_ground.mesh = _ground_mesh()
	_trees.multimesh = _tree_multimesh()
	_road.visible = tuning.get("road", true)
	_walls.visible = tuning.get("walls", true)
	_ground.visible = tuning.get("ground", true)
	_trees.visible = tuning.get("scenery", true)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.8, 0.9)
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_env := WorldEnvironment.new()
	world_env.name = "Environment"
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = false
	sun.light_energy = 1.0
	sun.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	add_child(sun)


func _mesh_node(node_name: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.material_override = _flat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


## Rows every ROAD_STEP metres; each row is split across the road into bands.
func _road_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := maxi(8, roundi(track.length / ROAD_STEP))
	var step := track.length / rows
	for i in rows:
		var s0 := i * step
		var s1 := (i + 1) * step
		var hw0 := track.half_width(s0)
		var hw1 := track.half_width(s1)
		var edge0 := hw0 + track.verge
		var edge1 := hw1 + track.verge
		var kerb := KartTrackModel.KERB_WIDTH
		_band(st, s0, s1, -hw0, hw0, -hw1, hw1, ROAD if (i >> 1) & 1 == 0 else ROAD_ALT)
		var kerb_color := KERB_A if i % 2 == 0 else KERB_B
		for side in [-1.0, 1.0]:
			_band(st, s0, s1, side * hw0, side * (hw0 + kerb), side * hw1, side * (hw1 + kerb), kerb_color)
			_band(st, s0, s1, side * (hw0 + kerb), side * edge0, side * (hw1 + kerb), side * edge1, VERGE)
			# The skirt: from the barrier's foot out and down to the ground.
			var a := track.position_at(s0, side * edge0)
			var b := track.position_at(s1, side * edge1)
			var c := track.position_at(s1, side * (edge1 + SKIRT))
			var d := track.position_at(s0, side * (edge0 + SKIRT))
			c.y = GROUND_Y + 0.05
			d.y = GROUND_Y + 0.05
			_quad(st, a, b, c, d, SKIRT_COLOR)
	_start_line(st)
	for z in track.zones:
		match str(z.type):
			"boost":
				var w := float(z.get("w", 1.4))
				var dz := float(z.get("d", 0.0))
				_band(st, z.s0, z.s0 + track.delta(z.s0, z.s1), dz - w, dz + w, dz - w, dz + w, BOOST, 0.02)
			"items":
				var hw := track.half_width(z.s0)
				_band(st, z.s0, z.s0 + 0.6, -hw, hw, -hw, hw, ITEMS, 0.02)
	return st.commit()


func _start_line(st: SurfaceTool) -> void:
	var hw := track.half_width(0.0)
	var cols := 8
	for row in 2:
		for col in cols:
			var d0 := -hw + 2.0 * hw * col / cols
			var d1 := -hw + 2.0 * hw * (col + 1) / cols
			var s0 := row * 0.8
			_band(st, s0, s0 + 0.8, d0, d1, d0, d1, LINE_A if (row + col) % 2 == 0 else LINE_B, 0.02)


## A quad between s0 and s1 from d = a0..b0 (at s0) to a1..b1 (at s1), lifted by `lift`.
func _band(st: SurfaceTool, s0: float, s1: float, a0: float, b0: float, a1: float, b1: float, color: Color, lift := 0.0) -> void:
	var up := Vector3.UP * lift
	_quad(st, track.position_at(s0, a0) + up, track.position_at(s1, a1) + up,
		track.position_at(s1, b1) + up, track.position_at(s0, b0) + up, color)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	st.set_color(color)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)


func _wall_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := maxi(8, roundi(track.length / ROAD_STEP))
	var step := track.length / rows
	for i in rows:
		var s0 := i * step
		var s1 := (i + 1) * step
		var color := WALL_A if (i >> 1) & 1 == 0 else WALL_B
		for side in [-1.0, 1.0]:
			var a := track.position_at(s0, side * (track.half_width(s0) + track.verge))
			var b := track.position_at(s1, side * (track.half_width(s1) + track.verge))
			var top := Vector3.UP * WALL_HEIGHT
			_quad(st, a, b, b + top, a + top, color)
	return st.commit()


func _ground_mesh() -> PlaneMesh:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var s := 0.0
	while s < track.length:
		var p := track.sample(s).position
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
		s += 10.0
	var plane := PlaneMesh.new()
	plane.size = (hi - lo) + Vector2(600.0, 600.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = GROUND
	plane.material = mat
	_ground.position = Vector3((lo.x + hi.x) * 0.5, GROUND_Y, (lo.y + hi.y) * 0.5)
	_ground.material_override = null
	return plane


func _tree_multimesh() -> MultiMesh:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 2.0
	cone.height = 6.0
	cone.radial_segments = 6
	cone.rings = 1
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mat.albedo_color = Color(0.18, 0.45, 0.2)
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	cone.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cone
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(track.def.id)
	var spots: Array[Transform3D] = []
	var tries := 0
	while spots.size() < TREES and tries < TREES * 20:
		tries += 1
		var s := rng.randf_range(0.0, track.length)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var edge := track.half_width(s) + track.verge
		var out := edge + TREE_CLEARANCE + rng.randf_range(0.0, 45.0)
		var p := track.position_at(s, side * out)
		# On the skirt's slope, or on the ground beyond it.
		var foot := lerpf(track.position_at(s, side * edge).y, GROUND_Y, clampf((out - edge) / SKIRT, 0.0, 1.0))
		# Keep clear of every other stretch of road too.
		var near := track.project(p)
		if absf(near.d) < track.half_width(near.s) + track.verge + TREE_CLEARANCE:
			continue
		var size := rng.randf_range(0.7, 1.4)
		var basis := Basis().scaled(Vector3(size, size * rng.randf_range(0.9, 1.3), size))
		p.y = foot + 3.0 * basis.y.y - 0.2
		spots.append(Transform3D(basis, p))
	mm.instance_count = spots.size()
	for i in spots.size():
		mm.set_instance_transform(i, spots[i])
	return mm
