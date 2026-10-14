extends GdUnitTestSuite
## Kart Race's chase camera (#43, Phase 2 Task A1): the spring follow, FOV by speed, the boost
## kick and surge, drift roll, hit shake, the Chase/Close option and the start fly-over.

const Fixtures := preload("res://tests/kart_fixtures.gd")
const DT := 1.0 / 60.0


func _camera() -> KartChaseCamera:
	var root: Node3D = auto_free(Node3D.new())
	add_child(root)
	var cam := KartChaseCamera.new()
	root.add_child(cam)
	return cam


func _kart(speed := 20.0) -> KartState:
	var k := KartState.new()
	k.pos = Vector3(0, 0, 0)
	k.heading = 0.0  # facing -Z
	k.speed = speed
	return k


## Drives k straight ahead for `seconds`, the camera following.
func _drive(cam: KartChaseCamera, k: KartState, seconds: float) -> void:
	for i in roundi(seconds / DT):
		k.pos += k.forward() * k.speed * DT
		cam.follow(k, DT)


func _behind(cam: KartChaseCamera, k: KartState) -> float:
	return (cam.global_position - k.pos).dot(-k.forward())


func test_snap_sits_behind_and_above_looking_ahead() -> void:
	var cam := _camera()
	var k := _kart(0.0)
	cam.snap(k)
	assert_float(_behind(cam, k)).is_between(5.0, 8.0)
	assert_float(cam.global_position.y).is_between(1.5, 3.5)
	# Looking forward, a little down.
	var view := -cam.global_transform.basis.z
	assert_float(view.dot(k.forward())).is_greater(0.9)
	assert_float(view.y).is_less(0.0)


func test_follow_holds_a_steady_distance_at_any_frame_rate() -> void:
	var at := {}
	for step in [1.0 / 30.0, 1.0 / 60.0, 1.0 / 144.0]:
		var cam := _camera()
		var k := _kart(25.0)
		cam.snap(k)
		for i in roundi(4.0 / step):
			k.pos += k.forward() * k.speed * step
			cam.follow(k, step)
		at[step] = _behind(cam, k)
	assert_float(float(at[1.0 / 30.0])).is_equal_approx(float(at[1.0 / 144.0]), 0.05)
	# Further back at speed than at rest.
	var still := _camera()
	still.snap(_kart(0.0))
	assert_float(float(at[1.0 / 60.0])).is_greater(_behind(still, _kart(0.0)) + 0.5)


func test_the_view_widens_with_speed_and_kicks_on_a_boost() -> void:
	var slow := _camera()
	var k := _kart(8.0)
	slow.snap(k)
	_drive(slow, k, 3.0)
	var fast := _camera()
	var kf := _kart(30.0)
	fast.snap(kf)
	_drive(fast, kf, 3.0)
	assert_float(fast.fov).is_greater(slow.fov + 8.0)
	# A boost through the events: a wider view, and the kart surges away from the camera.
	var events := KartRaceEvents.new()
	fast.watch(events, 0)
	var cruise_fov := fast.fov
	var cruise_back := _behind(fast, kf)
	events.boost_started.emit(0, "drift", 3)
	kf.boost_time = 1.4
	_drive(fast, kf, 0.4)
	assert_float(fast.fov).is_greater(cruise_fov + 6.0)
	assert_float(_behind(fast, kf)).is_greater(cruise_back + 0.5)
	# Another kart's boost does nothing.
	var other := _camera()
	var ko := _kart(30.0)
	other.snap(ko)
	_drive(other, ko, 3.0)
	other.watch(events, 0)
	var before := other.fov
	events.boost_started.emit(3, "pad", 0)
	_drive(other, ko, 0.3)
	assert_float(other.fov).is_equal_approx(before, 0.5)


func test_a_drift_rolls_the_view_into_the_slide() -> void:
	var cam := _camera()
	var k := _kart(20.0)
	cam.snap(k)
	k.drift_dir = 1
	_drive(cam, k, 1.0)
	var roll_right := cam.global_transform.basis.x.y
	k.drift_dir = -1
	_drive(cam, k, 1.0)
	var roll_left := cam.global_transform.basis.x.y
	assert_float(absf(roll_right)).is_greater(0.03)
	assert_float(signf(roll_right)).is_equal(-signf(roll_left))


func test_bumps_and_hits_shake_then_settle() -> void:
	var cam := _camera()
	var k := _kart(20.0)
	cam.snap(k)
	var events := KartRaceEvents.new()
	cam.watch(events, 0)
	events.wall_bump.emit(0, 1.0)
	assert_float(cam.trauma()).is_greater(0.5)
	events.kart_hit.emit(0, 2, "puck")
	assert_float(cam.trauma()).is_equal(1.0)
	_drive(cam, k, 1.0)
	assert_float(cam.trauma()).is_equal(0.0)
	# Bumps between other karts don't shake the rider's camera.
	events.kart_bump.emit(2, 3, 1.0)
	assert_float(cam.trauma()).is_equal(0.0)
	events.kart_bump.emit(2, 0, 0.5)
	assert_float(cam.trauma()).is_greater(0.1)


func test_close_mode_sits_closer_and_lower() -> void:
	var chase := _camera()
	chase.snap(_kart(0.0))
	var close := _camera()
	close.mode = "close"
	close.snap(_kart(0.0))
	assert_float(_behind(close, _kart(0.0))).is_less(_behind(chase, _kart(0.0)) - 1.0)
	assert_float(close.global_position.y).is_less(chase.global_position.y)


func test_the_flyover_starts_high_in_front_and_lands_on_the_chase_spot() -> void:
	var track := KartTrackModel.new(Fixtures.meadow())
	var race := KartRaceLogic.new()
	var racers := []
	for i in 8:
		racers.append({"racer_id": "r%d" % i})
	race.setup(track, racers, 3)
	var k: KartState = race.karts[0]
	var cam := _camera()
	cam.flyover(k, 0.0, track)
	var start := cam.global_position
	# In front of the grid (ahead of the rider along the road), above it.
	assert_float((start - k.pos).dot(k.forward())).is_greater(10.0)
	assert_float(start.y - k.pos.y).is_greater(3.0)
	# Smooth: no jumps between frames.
	var last := start
	for i in range(1, 211):
		cam.flyover(k, i / 210.0, track)
		assert_float(cam.global_position.distance_to(last)).is_less(1.5)
		last = cam.global_position
	# It ends where the chase camera starts, and follow carries on without a jump.
	var snapped := _camera()
	snapped.snap(k)
	assert_vector(cam.global_position).is_equal_approx(snapped.global_position, Vector3.ONE * 0.01)
	cam.follow(k, DT)
	assert_float(cam.global_position.distance_to(last)).is_less(0.1)
