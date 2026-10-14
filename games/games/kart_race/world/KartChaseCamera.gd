class_name KartChaseCamera
extends Camera3D
## The chase camera (#43): it sells speed. It trails the rider's kart in the kart's frame, so its
## distance never depends on the frame rate or on lag:
##
## - **Yaw** swings round behind the kart on a spring (so corners and drifts show the kart's side).
## - **Distance** is a critically damped spring toward a speed-scaled goal: a boost throws the goal
##   back, so the kart surges away from the camera, then the camera catches up.
## - **Height** follows the road on its own spring, so crests and dips don't jolt the view.
## - **FOV** widens with speed, kicks wider on a boost (`kick`), and a boost adds a light rumble.
## - **Roll** leans into a drift.
## - **Shake** is trauma-based (`shake`, trauma² × noise, decaying): wall bumps, kart bumps, hits.
##
## `watch(events, kart_id)` hooks a race's events (boosts kick, bumps and hits shake). Before each
## race, `flyover(k, t, track)` swoops from a hero shot in front of the grid, round its side and
## down behind the rider, ending exactly on the chase spot so `follow` takes over seamlessly. No
## physics bodies: the track has no colliders, and the barrier is low.
##
## Modes (the rider's Camera option): "chase" and "close". `hold` (with `held`) pins the camera
## for screenshots and cut-scenes.

const MODES := {
	"chase": {"distance": 5.0, "height": 1.95, "look_ahead": 9.0, "look_height": 1.15, "fov": 0.0},
	"close": {"distance": 3.5, "height": 1.45, "look_ahead": 7.0, "look_height": 0.95, "fov": 4.0},
}
const YAW_SPRING := 5.0  ## 1/s: how quickly the camera swings round behind the kart
const DIST_OMEGA := 7.0  ## the distance spring's natural frequency (critically damped)
const HEIGHT_OMEGA := 6.0
const SPEED_DISTANCE := 0.045  ## extra metres back per m/s
const BOOST_DISTANCE := 1.8  ## extra metres back while boosting: the kart surges away
const SPEED_DIP := 0.012  ## metres lower per m/s (closer to the road feels faster)
const FOV_SLOW := 64.0
const FOV_FAST := 80.0
const FOV_KICK := 14.0  ## extra degrees at a full boost kick
const KICK_DECAY := 1.1  ## per second
const SLOW_SPEED := 6.0  ## m/s where the view starts to widen ...
const FAST_SPEED := 34.0  ## ... and where it's widest
const DRIFT_ROLL := 0.075  ## radians of roll into a drift
const STEER_ROLL := 0.025
const ROLL_RATE := 5.0
const SHAKE_DECAY := 1.8  ## trauma per second
const SHAKE_OFFSET := 0.32  ## metres at full trauma
const SHAKE_ROLL := 0.045  ## radians at full trauma
const SHAKE_HZ := 22.0
const BOOST_RUMBLE := 0.22  ## a trauma floor while boosting
const MIN_CLEARANCE := 0.9  ## above the kart's road height

var mode := "chase"
var hold := false
var held := Transform3D.IDENTITY
## The kart this camera watches for kicks and shakes (`watch`).
var kart_id := 0

var _yaw := 0.0
var _dist := 6.0
var _dist_v := 0.0
var _y := 0.0
var _y_v := 0.0
var _roll := 0.0
var _kick := 0.0
var _trauma := 0.0
var _time := 0.0
var _noise := FastNoiseLite.new()
var _events: KartRaceEvents = null


func _ready() -> void:
	fov = FOV_SLOW
	near = 0.2
	far = 1100.0
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.seed = 4242
	_noise.frequency = 1.0


## Hooks a race's events for kart `id` (the rider): boosts kick the FOV, bumps and hits shake.
func watch(events: KartRaceEvents, id := 0) -> void:
	if _events:
		for pair in _handlers():
			if _events.is_connected(pair[0], pair[1]):
				_events.disconnect(pair[0], pair[1])
	_events = events
	kart_id = id
	_trauma = 0.0
	_kick = 0.0
	if events:
		for pair in _handlers():
			events.connect(pair[0], pair[1])


func _handlers() -> Array:
	return [["boost_started", _on_boost], ["wall_bump", _on_wall], ["kart_bump", _on_bump],
		["kart_hit", _on_hit], ["drift_started", _on_drift]]


## Puts the camera straight behind `k` (a race start, a teleport).
func snap(k: KartState) -> void:
	_yaw = k.heading
	var m := _mode()
	_dist = _goal_distance(k, m)
	_dist_v = 0.0
	_y = k.pos.y + float(m.height)
	_y_v = 0.0
	_roll = 0.0
	global_transform = _place(k, m, Vector3.ZERO, 0.0)


## A boost: widen the view for a moment (0-1).
func kick(amount := 1.0) -> void:
	_kick = maxf(_kick, amount)


## A bump or hit: shake (trauma 0-1, adding up to 1).
func shake(amount: float) -> void:
	_trauma = minf(1.0, _trauma + amount)


## The shake's trauma now (0-1), for tests.
func trauma() -> float:
	return _trauma


func follow(k: KartState, dt: float) -> void:
	if hold:
		global_transform = held
		return
	if dt <= 0.0:
		return
	_time += dt
	var m := _mode()
	_yaw = lerp_angle(_yaw, k.heading, 1.0 - exp(-YAW_SPRING * dt))
	var goal := _goal_distance(k, m)
	var hv := _spring(_dist, _dist_v, goal, DIST_OMEGA, dt)
	_dist = hv.x
	_dist_v = hv.y
	var y := _spring(_y, _y_v, k.pos.y + float(m.height) - SPEED_DIP * k.speed, HEIGHT_OMEGA, dt)
	_y = maxf(y.x, k.pos.y + MIN_CLEARANCE)
	_y_v = y.y
	var roll_goal := -k.drift_dir * DRIFT_ROLL - k.steer * STEER_ROLL
	_roll = lerpf(_roll, roll_goal, 1.0 - exp(-ROLL_RATE * dt))
	# Shake: trauma² × smooth noise, with a light rumble while boosting.
	if k.boost_time > 0.0:
		_trauma = maxf(_trauma, BOOST_RUMBLE * minf(1.0, k.boost_time * 2.0))
		_kick = maxf(_kick, 0.6)
	var amount := _trauma * _trauma
	var jitter := Vector3.ZERO
	var jroll := 0.0
	if amount > 0.0:
		var t := _time * SHAKE_HZ
		jitter = Vector3(_noise.get_noise_2d(t, 0.0), _noise.get_noise_2d(0.0, t), 0.0) * SHAKE_OFFSET * amount
		jroll = _noise.get_noise_2d(t, t) * SHAKE_ROLL * amount
	_trauma = maxf(0.0, _trauma - SHAKE_DECAY * dt)
	global_transform = _place(k, m, jitter, _roll + jroll)
	# FOV by speed, plus the boost kick.
	_kick = maxf(0.0, _kick - KICK_DECAY * dt)
	var want := lerpf(FOV_SLOW, FOV_FAST, smoothstep(SLOW_SPEED, FAST_SPEED, k.speed)) + FOV_KICK * _kick + float(m.fov)
	fov = lerpf(fov, want, 1.0 - exp(-7.0 * dt))


## The pre-race fly-over at `t` (0-1): a hero shot in front of the grid looking back at the
## karts, a sweep round the grid's infield side, then down behind `k`, ending exactly on the chase
## spot (so `follow` takes over without a jump).
func flyover(k: KartState, t: float, track: KartTrackModel) -> void:
	if hold:
		global_transform = held
		return
	snap(k)  # the end of the path, and follow's starting state
	if t >= 1.0:
		fov = FOV_SLOW + float(_mode().fov)
		return
	var end := global_transform
	var m := _mode()
	# The grid's middle and its frame.
	var mid_s := track.wrap(-20.0)
	var centre := track.position_at(mid_s, 0.0)
	var right := track.sample(mid_s).right
	var yaw := track.yaw_at(mid_s)
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var up := Vector3.UP
	# The path: in front and above, looking back down the grid; round the infield side; behind the
	# rider's kart; the chase spot.
	var p0 := centre + fwd * 17.5 - right * 0.5 + up * 4.2
	var p1 := centre + fwd * 4.0 - right * 9.5 + up * 6.0
	var p2 := k.pos - fwd * 12.0 - right * 4.0 + up * 4.5
	var p3 := end.origin
	var l0 := centre + up * 0.8 - fwd * 2.0
	var l1 := centre + up * 0.8 - fwd * 6.0
	var l3 := k.pos + Vector3(-sin(k.heading), 0.0, -cos(k.heading)) * float(m.look_ahead) + up * float(m.look_height)
	var e := t * t * t * (t * (6.0 * t - 15.0) + 10.0)  # smootherstep
	var pos: Vector3
	var look: Vector3
	if e < 0.5:
		var u := e / 0.5
		pos = _catmull(p0 - (p1 - p0), p0, p1, p2, u)
		look = l0.lerp(l1, u)
	else:
		var u := (e - 0.5) / 0.5
		pos = _blend_half(p0, p1, p2, p3, u)
		look = l1.lerp(l3, smoothstep(0.0, 1.0, u))
	global_transform = Transform3D(Basis.looking_at(look - pos, up), pos)
	fov = lerpf(52.0, FOV_SLOW + float(m.fov), e)


## The second half of the path, p1 → p3 through p2, Catmull-Rom.
func _blend_half(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, u: float) -> Vector3:
	if u < 0.5:
		return _catmull(p0, p1, p2, p3, u / 0.5)
	return _catmull(p1, p2, p3, p3 + (p3 - p2), (u - 0.5) / 0.5)


static func _catmull(a: Vector3, b: Vector3, c: Vector3, d: Vector3, u: float) -> Vector3:
	return b.cubic_interpolate(c, a, d, u)


## A critically damped spring step: returns (value, velocity).
static func _spring(x: float, v: float, goal: float, omega: float, dt: float) -> Vector2:
	var e := exp(-omega * dt)
	var delta := x - goal
	var temp := (v + omega * delta) * dt
	return Vector2(goal + (delta + temp) * e, (v - omega * temp) * e)


func _mode() -> Dictionary:
	return MODES.get(mode, MODES.chase)


func _goal_distance(k: KartState, m: Dictionary) -> float:
	return float(m.distance) + SPEED_DISTANCE * k.speed + (BOOST_DISTANCE if k.boost_time > 0.0 else 0.0)


func _place(k: KartState, m: Dictionary, jitter: Vector3, roll: float) -> Transform3D:
	var back := Vector3(sin(_yaw), 0.0, cos(_yaw))
	var at := k.pos + back * _dist
	at.y = _y
	var look := k.pos - back * float(m.look_ahead) + Vector3.UP * float(m.look_height)
	var basis := Basis.looking_at(look - at, Vector3.UP)
	basis = basis * Basis(Vector3.BACK, roll)
	return Transform3D(basis, at + basis * jitter)


func _on_boost(id: int, kind: String, tier: int) -> void:
	if id != kart_id:
		return
	match kind:
		"drift":
			kick([0.55, 0.75, 1.0][clampi(tier - 1, 0, 2)])
		_:
			kick(1.0)
	shake(0.18)


func _on_wall(id: int, strength: float) -> void:
	if id == kart_id:
		shake(0.25 + 0.45 * strength)


func _on_bump(a: int, b: int, strength: float) -> void:
	if a == kart_id or b == kart_id:
		shake(0.12 + 0.3 * strength)


func _on_hit(id: int, _by: int, _item: String) -> void:
	if id == kart_id:
		shake(0.75)


func _on_drift(id: int, _dir: int) -> void:
	if id == kart_id:
		shake(0.1)
