extends GdUnitTestSuite
## Tug of War's one quality step (TugQualityGovernor): a slow round window steps the 3D view
## down to the low render scale once; fast windows and frames outside a round never do.


func _run(gov: TugQualityGovernor, fps: float, seconds: float, pulling := true) -> int:
	var steps := 0
	for i in roundi(fps * seconds):
		if gov.sample(1.0 / fps, pulling):
			steps += 1
	return steps


func test_a_fast_round_keeps_full_quality() -> void:
	var gov := TugQualityGovernor.new()
	assert_int(_run(gov, 60.0, 20.0)).is_equal(0)
	assert_int(gov.tier).is_equal(0)
	assert_float(gov.render_scale(0.62)).is_equal(0.62)


func test_a_slow_window_steps_down_once_and_never_back() -> void:
	var gov := TugQualityGovernor.new()
	assert_int(_run(gov, 40.0, 4.5)).is_equal(1)
	assert_float(gov.last_fps).is_equal_approx(40.0, 0.5)
	assert_float(gov.render_scale(0.62)).is_equal(TugQualityGovernor.LOW_SCALE)
	assert_float(TugQualityGovernor.LOW_SCALE).is_less(0.62)
	assert_int(_run(gov, 30.0, 20.0)).is_equal(0)  # there's no lower tier
	_run(gov, 60.0, 20.0)
	assert_int(gov.tier).is_equal(1)  # and no way back up


func test_slow_frames_outside_a_round_dont_count() -> void:
	var gov := TugQualityGovernor.new()
	assert_int(_run(gov, 20.0, 30.0, false)).is_equal(0)
	# A window is only judged after WINDOW_SEC of round frames in a row.
	_run(gov, 30.0, 3.0)
	_run(gov, 30.0, 1.0, false)
	assert_int(_run(gov, 60.0, 4.5)).is_equal(0)
	assert_int(gov.tier).is_equal(0)
