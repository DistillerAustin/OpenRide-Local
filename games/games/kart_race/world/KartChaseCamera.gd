class_name KartChaseCamera
extends Camera3D
## The chase camera (#43): it trails the rider's kart on a spring (exponential smoothing, so it's
## the same at any frame rate), looks a little ahead, widens with speed and kicks wider on a
## boost (`kick`). Before each race, `flyover(k, t)` swoops from a high view of the grid down to
## the chase spot. No physics: the track has no collision bodies, and the barrier is low.
##
## Modes (the rider's Camera option): "chase" and "close". `hold` (with `held`) pins the camera
## for screenshots and cut-scenes.

const MODES := {
	"chase": {"distance": 6.6, "height": 3.0, "look_ahead": 6.0, "look_height": 1.0},
	"close": {"distance": 4.4, "height": 1.9, "look_ahead": 4.0, "look_height": 0.8},
}
const POSITION_SPRING := 7.0  ## 1/s: how quickly the camera closes on its spot
const HEADING_SPRING := 5.0  ## 1/s: how quickly it swings round behind the kart
const FOV_SLOW := 66.0
const FOV_FAST := 76.0
const FOV_KICK := 10.0  ## extra degrees at a full boost kick
const FAST_SPEED := 30.0  ## m/s where the view is widest

var mode := "chase"
var hold := false
var held := Transform3D.IDENTITY

var _heading := 0.0
var _kick := 0.0


func _ready() -> void:
	fov = FOV_SLOW
	near = 0.2
	far = 1100.0


## Puts the camera straight behind `k` (a race start, a teleport).
func snap(k: KartState) -> void:
	_heading = k.heading
	global_transform = _target(k)


## A boost: widen the view for a moment (0-1).
func kick(amount := 1.0) -> void:
	_kick = maxf(_kick, amount)


func follow(k: KartState, dt: float) -> void:
	if hold:
		global_transform = held
		return
	_heading = lerp_angle(_heading, k.heading, 1.0 - exp(-HEADING_SPRING * dt))
	var goal := _target(k)
	var blend := 1.0 - exp(-POSITION_SPRING * dt)
	global_position = global_position.lerp(goal.origin, blend)
	var m: Dictionary = MODES.get(mode, MODES.chase)
	var ahead := Vector3(-sin(_heading), 0.0, -cos(_heading))
	var look := k.pos + ahead * float(m.look_ahead) + Vector3.UP * float(m.look_height)
	if global_position.distance_squared_to(look) > 0.01:
		look_at(look, Vector3.UP)
	_kick = maxf(0.0, _kick - dt * 1.4)
	if k.boost_time > 0.0:
		_kick = maxf(_kick, 0.7)
	var want := lerpf(FOV_SLOW, FOV_FAST, clampf(k.speed / FAST_SPEED, 0.0, 1.0)) + FOV_KICK * _kick
	fov = lerpf(fov, want, 1.0 - exp(-6.0 * dt))


## The pre-race fly-over at `t` (0-1): high over the infield looking across the grid, then a
## swoop down behind `k`, ending exactly on the chase spot (so `follow` takes over smoothly).
func flyover(k: KartState, t: float, track: KartTrackModel) -> void:
	if hold:
		global_transform = held
		return
	_heading = k.heading
	var end := _target(k)
	# The grid's middle, seen from the infield side (-d), high and wide.
	var mid_s := track.wrap(-22.0)
	var centre := track.position_at(mid_s, 0.0)
	var right := track.sample(mid_s).right
	var fwd := Vector3(-sin(track.yaw_at(mid_s)), 0.0, -cos(track.yaw_at(mid_s)))
	var start_pos := centre - right * 15.0 + Vector3.UP * 9.5 - fwd * 6.0
	var start_look := centre + right * 3.0 + fwd * 2.0
	var mid_pos := centre - right * 9.0 + Vector3.UP * 5.0 + fwd * 12.0
	var e := t * t * (3.0 - 2.0 * t)
	var pos: Vector3
	var look: Vector3
	var m: Dictionary = MODES.get(mode, MODES.chase)
	var end_look := k.pos + fwd.slerp(Vector3(-sin(k.heading), 0, -cos(k.heading)), 1.0) * float(m.look_ahead) + Vector3.UP * float(m.look_height)
	if e < 0.5:
		var u := e / 0.5
		pos = start_pos.lerp(mid_pos, u * u)
		look = start_look.lerp(centre + fwd * 6.0, u)
	else:
		var u := (e - 0.5) / 0.5
		var w := u * u * (3.0 - 2.0 * u)
		pos = mid_pos.lerp(end.origin, w)
		look = (centre + fwd * 6.0).lerp(end_look, w)
	global_transform = Transform3D(Basis.looking_at(look - pos, Vector3.UP), pos)
	fov = lerpf(50.0, FOV_SLOW, e)


func _target(k: KartState) -> Transform3D:
	var m: Dictionary = MODES.get(mode, MODES.chase)
	var behind := Vector3(sin(_heading), 0.0, cos(_heading))
	var at := k.pos + behind * float(m.distance) + Vector3.UP * float(m.height)
	var ahead := -behind
	var look := k.pos + ahead * float(m.look_ahead) + Vector3.UP * float(m.look_height)
	return Transform3D(Basis.looking_at(look - at, Vector3.UP), at)
