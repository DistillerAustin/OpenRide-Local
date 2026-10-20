extends GdUnitTestSuite
## Cadence Karaoke's 3D view (GFX_POLISH.md): the ring frame mesh, the themes' secondaries, the
## beat visuals following the scene's clock (rings, the floor's reflections, the equaliser) and the
## pooled sparks.


func _world() -> CadenceWorld:
	var world: CadenceWorld = auto_free(CadenceWorld.new())
	add_child(world)
	return world


func test_the_frame_mesh_is_a_thin_frame_not_a_quad() -> void:
	var mesh := CadenceWorld.frame_mesh(CadenceWorld.RING_SIZE, CadenceWorld.RING_STRIP)
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	assert_int(verts.size()).is_equal(24)
	assert_int(indices.size() / 3).is_equal(16)
	var aabb := mesh.get_aabb()
	assert_float(aabb.size.x).is_equal_approx(CadenceWorld.RING_SIZE.x, 0.001)
	assert_float(aabb.size.y).is_equal_approx(CadenceWorld.RING_SIZE.y, 0.001)
	# The frame's area is its strips, a small share of the old full quad.
	var area := 0.0
	for t in indices.size() / 3:
		var a := verts[indices[t * 3]]
		var b := verts[indices[t * 3 + 1]]
		var c := verts[indices[t * 3 + 2]]
		area += (b - a).cross(c - a).length() / 2.0
	var s := CadenceWorld.RING_SIZE
	var w := CadenceWorld.RING_STRIP
	assert_float(area).is_equal_approx(s.x * s.y - (s.x - 2.0 * w) * (s.y - 2.0 * w), 0.01)
	assert_float(area / (s.x * s.y)).is_less(0.3)
	# UV.y: 0 on the outer edge, 1 on the inner; UV.x: 0 at the corners.
	for i in verts.size():
		var v := verts[i]
		var on_outer := absf(absf(v.x) - s.x / 2.0) < 0.001 or absf(absf(v.y) - s.y / 2.0) < 0.001
		assert_float(uvs[i].y).is_equal(0.0 if on_outer else 1.0)
		var at_corner := absf(absf(v.x) - s.x / 2.0) < 0.001 and absf(absf(v.y) - s.y / 2.0) < 0.001
		if at_corner:
			assert_float(uvs[i].x).is_equal(0.0)


func test_the_rings_draw_the_frame_without_discard() -> void:
	var world := _world()
	var rings: MultiMeshInstance3D = world.get_node("Rings")
	assert_object(rings.multimesh.mesh).is_instanceof(ArrayMesh)
	assert_int(rings.multimesh.instance_count).is_equal(CadenceWorld.RING_COUNT)
	var mat: ShaderMaterial = rings.material_override
	assert_bool(mat.shader.code.contains("discard;")).is_false()


func test_every_theme_has_a_secondary_and_cool_down_is_dimmer() -> void:
	for key in CadenceWorld.THEMES:
		assert_bool(CadenceWorld.SECONDARY.has(key)).is_true()
		assert_that(CadenceWorld.SECONDARY[key]).is_not_equal(CadenceWorld.THEMES[key])
	var world := _world()
	world.set_theme("recovery")
	assert_that(world.theme_color).is_equal(CadenceWorld.THEMES.recovery)
	assert_that(world.secondary_color).is_equal(CadenceWorld.SECONDARY.recovery)
	assert_float(world.theme_energy).is_equal(1.0)
	world.set_theme("cooldown")
	assert_float(world.theme_energy).is_less(1.0)
	# A plain colour finds its theme's secondary; an unknown name is the free theme.
	world.set_theme_color(CadenceWorld.THEMES.pink)
	assert_that(world.secondary_color).is_equal(CadenceWorld.SECONDARY.pink)
	world.set_theme("nope")
	assert_that(world.theme_color).is_equal(CadenceWorld.THEMES.free)
	var floor_mat: ShaderMaterial = world.get("_floor_mat")
	assert_that(floor_mat.get_shader_parameter("line2_color")).is_equal(CadenceWorld.SECONDARY.free)


func test_the_beat_visuals_follow_the_scenes_clock() -> void:
	var world := _world()
	var floor_mat: ShaderMaterial = world.get("_floor_mat")
	var wall_mats: Array = world.get("_wall_mats")
	var phases: Array[float] = [0.2, 0.6, 0.95, 0.1, 0.5]
	for phase in phases:
		world.update_view(1.0 / 60.0, 0.0, 0.2, phase, "in_band", false, 0.0, 1.0)
		assert_float(floor_mat.get_shader_parameter("ring_phase")).is_equal(phase)
		# Every ring sits on a whole k of the floor shader's model of them:
		# k = (line_z - z) / ring_spacing + 1 + ring_phase.
		for i in CadenceWorld.RING_COUNT:
			var z := CadenceWorld.ring_z(i, phase)
			var k: float = (CadenceWorld.ORB_Z - z) / CadenceWorld.RING_SPACING + 1.0 + phase
			assert_float(k).is_equal_approx(float(i), 0.0001)
		# A ring lands on the line as the phase wraps.
		assert_float(CadenceWorld.ring_z(1, 0.0)).is_equal(CadenceWorld.ORB_Z)
	# The phase wrapped once (0.95 → 0.1): the equaliser's clock counts the beat.
	assert_float(wall_mats[0].get_shader_parameter("beat_clock")).is_equal_approx(1.5, 0.0001)


func test_sparks_fire_on_a_landing_in_the_bonus_band_only() -> void:
	var world := _world()
	var sparks: MultiMeshInstance3D = world.get_node("Sparks")
	# Drawn for the first frames (the shader compiles under the intro card), then hidden.
	for i in 30:
		world.update_view(1.0 / 60.0, 0.0, 0.2, 0.01 * i, "in_band", false, 0.0, 1.0)
	assert_bool(sparks.visible).is_false()
	world.update_view(1.0 / 60.0, 0.0, 0.2, 0.9, "in_band", false, 0.0, 1.0)
	world.update_view(1.0 / 60.0, 0.0, 0.2, 0.05, "in_band", false, 0.0, 1.0)  # a landing, in band
	assert_bool(sparks.visible).is_false()
	world.update_view(1.0 / 60.0, 0.0, 0.2, 0.9, "in_bonus", false, 0.0, 1.0)
	world.update_view(1.0 / 60.0, 0.0, 0.2, 0.05, "in_bonus", false, 0.0, 1.0)  # a landing, bonus
	assert_bool(sparks.visible).is_true()
	for i in 60:
		world.update_view(1.0 / 60.0, 0.0, 0.2, 0.1 + 0.01 * i, "in_bonus", false, 0.0, 1.0)
	assert_bool(sparks.visible).is_false()


func test_ease_off_desaturates_the_tunnel_gradually() -> void:
	var world := _world()
	var floor_mat: ShaderMaterial = world.get("_floor_mat")
	world.update_view(0.1, 0.0, 0.2, 0.1, "out", true, 0.0, 1.0)
	var first: float = floor_mat.get_shader_parameter("frozen")
	assert_float(first).is_between(0.01, 0.99)
	for i in 10:
		world.update_view(0.1, 0.0, 0.2, 0.1, "out", true, 0.0, 1.0)
	assert_float(floor_mat.get_shader_parameter("frozen")).is_equal(1.0)
	for i in 10:
		world.update_view(0.1, 0.0, 0.2, 0.1, "in_band", false, 0.0, 1.0)
	assert_float(floor_mat.get_shader_parameter("frozen")).is_equal(0.0)
