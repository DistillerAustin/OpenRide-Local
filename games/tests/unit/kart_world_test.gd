extends GdUnitTestSuite
## Kart Race's world (#43, Task B1): every track builds headless in both directions, in its own
## theme, inside the tablet's draw-call and triangle budget, with the land kept under the road
## and the track furniture (pads, item rows) on it.

## The world's share of the tablet budget (DESIGN.md: 120 calls and ~250k triangles in all,
## with eight karts at ~5 calls and ~3k triangles each, plus the HUD). These count every mesh
## node in the built track: the frustum and the visibility ranges cull many in play.
const MAX_CALLS := 72
const MAX_TRIANGLES := 190000


func after_test() -> void:
	KartLook.set_theme("meadow")


func _world() -> KartWorld:
	var w: KartWorld = auto_free(KartWorld.new())
	add_child(w)
	return w


func test_every_track_builds_in_budget_both_ways() -> void:
	var w := _world()
	for id in KartTracks.CUP:
		for rev: bool in [false, true]:
			var model := KartTrackModel.new(KartTracks.build(id), rev)
			w.build(model)
			assert_str(KartLook.theme).is_equal(model.def.theme)
			var budget := w.draw_budget()
			assert_int(budget.calls).override_failure_message("%s rev=%s: %d calls" % [id, rev, budget.calls]).is_less_equal(MAX_CALLS)
			assert_int(budget.triangles).override_failure_message("%s rev=%s: %d triangles" % [id, rev, budget.triangles]).is_less_equal(MAX_TRIANGLES)
			# The pads and item rows are painted.
			assert_object(w.find_child("Pads", true, false)).is_not_null()
			await get_tree().process_frame


func test_the_land_stays_under_the_road() -> void:
	var w := _world()
	for id in KartTracks.CUP:
		var model := KartTrackModel.new(KartTracks.build(id))
		w.build(model)
		var worst := -INF
		var at := ""
		var s := 0.0
		while s < model.length:
			var edge := model.half_width(s) + model.verge
			for d: float in [-edge, -edge * 0.5, 0.0, edge * 0.5, edge]:
				var p := model.position_at(s, d)
				var above := w.terrain.height_at(p.x, p.z) - p.y
				if above > worst:
					worst = above
					at = "s=%.0f d=%.1f" % [s, d]
			s += 3.0
		assert_float(worst).override_failure_message("%s: the land pokes %.2f m through the road at %s" % [id, worst, at]).is_less(-0.05)
		await get_tree().process_frame


func test_themed_set_pieces() -> void:
	var w := _world()
	var expect := {"meadow_ring": "Windmill", "canyon_dash": "Windpump", "harbor_lights": "Sea", "frost_pass": "Ice"}
	for id in KartTracks.CUP:
		w.build(KartTrackModel.new(KartTracks.build(id)))
		assert_object(w.find_child(expect[id], true, false)).override_failure_message("%s has no %s" % [id, expect[id]]).is_not_null()
		await get_tree().process_frame


func test_a_theme_relights_every_material() -> void:
	var mat := KartLook.material("scenery.gdshader")
	KartLook.set_theme("harbor")
	assert_that(mat.get_shader_parameter("sun_color")).is_equal(KartLook.THEMES.harbor.light.sun_color)
	# The sun keeps its bearing (blob shadows stay right), only its height changes.
	var flat := Vector2(KartLook.sun_dir().x, KartLook.sun_dir().z).normalized()
	var meadow := Vector2(KartLook.SUN_DIR.x, KartLook.SUN_DIR.z).normalized()
	assert_float(flat.dot(meadow)).is_greater(0.999)
	assert_float(KartLook.sun_dir().y).is_less(KartLook.SUN_DIR.y)
	KartLook.set_theme("meadow")
	assert_that(mat.get_shader_parameter("sun_color")).is_equal(KartLook.THEMES.meadow.light.sun_color)


func test_the_barrier_faces_out_of_its_profile() -> void:
	# The cap's top faces the sky and the panels face the road (the old wall was inside out: the
	# road saw its shaded back).
	var w := _world()
	var model := KartTrackModel.new(KartTracks.build("meadow_ring"))
	w.build(model)
	var walls: MeshInstance3D = w.find_child("Barriers", true, false)
	var arrays := walls.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var up := 0
	var down := 0
	var to_road := 0
	var away := 0
	for i in range(0, verts.size(), 6):
		var n := normals[i]
		if n.y > 0.9:
			up += 1
		elif n.y < -0.9:
			down += 1
		elif absf(n.y) < 0.1 and verts[i].y > 0.3 and verts[i].y < 0.8 and (to_road + away) < 200:
			# A panel: a step along its normal brings it nearer the road's centre line.
			var here := model.project(verts[i])
			var there := model.project(verts[i] + n * 0.3, here.s)
			if absf(there.d) < absf(here.d):
				to_road += 1
			else:
				away += 1
	assert_int(up).is_greater(100)
	assert_int(down).is_equal(0)
	assert_int(to_road).is_greater_equal(away)


func test_a_theme_s_optional_surfaces_reset_on_the_next_track() -> void:
	var w := _world()
	w.build(KartTrackModel.new(KartTracks.build("frost_pass")))
	assert_float(float(w.ground_mat.get_shader_parameter("snow"))).is_equal(1.0)
	await get_tree().process_frame
	w.build(KartTrackModel.new(KartTracks.build("meadow_ring")))
	assert_float(float(w.ground_mat.get_shader_parameter("snow"))).is_equal(0.0)
	assert_float(float(w.road_mat.get_shader_parameter("verge_gain"))).is_equal(1.0)


func test_each_track_s_title_shot_frames_its_landmark_over_the_grid() -> void:
	# Polish pass 3 (punch list 9): every grid and title shot used to be the same composition.
	# Now each track's opens on its own landmark, clear of the HUD, with no kart half-hidden
	# under the title band, both ways round.
	var w := _world()
	var screen := Rect2(Vector2.ZERO, KartWorld.SHOT_SIZE)
	var band := KartWorld.TITLE_BAND
	var eyes := []
	for id in KartTracks.CUP:
		for rev: bool in [false, true]:
			w.build(KartTrackModel.new(KartTracks.build(id), rev))
			var what := "%s rev=%s" % [id, rev]
			var shot := w.grid_shot
			assert_bool(shot.is_empty()).override_failure_message("%s: no title shot" % what).is_false()
			if shot.is_empty():
				continue
			# The landmark: in front of the lens, inside the frame, clear of the band and the
			# clock and buttons.
			var fp := KartWorld.shot_project(shot.eye, shot.look, shot.fov, shot.focus)
			var at := Vector2(fp.x, fp.y)
			assert_float(fp.z).override_failure_message("%s: landmark behind the lens" % what).is_greater(0.0)
			assert_bool(screen.grow(-60.0).has_point(at)).override_failure_message("%s: landmark at %s" % [what, at]).is_true()
			assert_bool(band.has_point(at) or KartWorld.SHOT_CORNER.has_point(at)).override_failure_message("%s: landmark under the HUD" % what).is_false()
			# The karts: wholly above the band, or wholly out of shot; at least four whole.
			var whole := 0
			for r: Rect2 in w.shot_kart_rects(shot.eye, shot.look, shot.fov):
				assert_bool(r.position.x == -1.0 and r.size == Vector2.ZERO).override_failure_message("%s: the lens inside a kart" % what).is_false()
				if r.size == Vector2.ZERO or not r.intersects(screen):
					continue
				assert_bool(r.intersects(band)).override_failure_message("%s: a kart under the title band %s" % [what, r]).is_false()
				if screen.encloses(r):
					whole += 1
			assert_int(whole).override_failure_message(what).is_greater_equal(4)
			eyes.append(shot.eye)
			await get_tree().process_frame
	# The flyover opens on it: the camera's first frame is the shot.
	var cam: KartChaseCamera = auto_free(KartChaseCamera.new())
	add_child(cam)
	cam.shot = w.grid_shot
	var k := KartState.new()
	k.pos = w.track.position_at(w.track.wrap(-40.0), 0.0)
	k.heading = w.track.yaw_at(w.track.wrap(-40.0))
	cam.flyover(k, 0.0, w.track)
	assert_vector(cam.global_position).is_equal_approx(w.grid_shot.eye, Vector3.ONE * 0.01)
	# And still lands on the chase spot.
	cam.flyover(k, 0.999, w.track)
	var end := cam.global_position
	cam.snap(k)
	assert_float(end.distance_to(cam.global_position)).is_less(0.2)


func test_the_crowd_varies_by_row_and_waves() -> void:
	# Punch list 18: heights and shirts vary per row (INSTANCE_CUSTOM.r, the instance colour),
	# some fans wave (custom.a >= 2), and accent banners hang from the stand's roof.
	var w := _world()
	w.build(KartTrackModel.new(KartTracks.build("harbor_lights")))
	assert_object(w.find_child("Crowd", true, false)).is_not_null()
	var data := KartWorld.crowd_data(KartLook.look, "harbor", KartWorld.STAND_ROWS, 0.95, 0.6, KartWorld.STAND_LENGTH)
	var count: int = data.custom.size()
	assert_int(data.colors.size()).is_equal(count)
	var lo := INF
	var hi := -INF
	var wavers := 0
	var shirts := {}
	for i in count:
		var c: Color = data.custom[i]
		lo = minf(lo, c.r)
		hi = maxf(hi, c.r)
		if c.a >= 2.0:
			wavers += 1
		shirts[(data.colors[i] as Color).to_html()] = true
	assert_float(lo).is_greater(0.6)
	assert_float(hi).is_less(1.4)
	assert_float(hi - lo).is_greater(0.2)
	assert_int(wavers).is_between(count / 10, count / 2)
	assert_int(shirts.size()).is_greater(20)
	assert_object(w.find_child("StandBanners", true, false)).is_not_null()
	# Harbor's stand carries lit lamps.
	assert_object(w.find_child("StandHalos", true, false)).is_not_null()
