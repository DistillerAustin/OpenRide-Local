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
