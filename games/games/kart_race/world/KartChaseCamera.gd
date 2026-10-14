class_name KartChaseCamera
extends Camera3D
## The chase camera (#43), v0: it trails the rider's kart on a spring (exponential smoothing, so
## it's the same at any frame rate), looks a little ahead, and widens with speed. No physics:
## the track has no collision bodies, and the barrier is low, so nothing comes between the camera
## and the kart. The handling agent owns this file (boost kick, drift roll, hit shake, the
## race fly-over).
##
## Modes (the rider's Camera option): "chase" and "close".

const MODES := {
	"chase": {"distance": 6.2, "height": 2.4, "look_ahead": 5.0, "look_height": 0.9},
	"close": {"distance": 4.2, "height": 1.7, "look_ahead": 4.0, "look_height": 0.8},
}
const POSITION_SPRING := 7.0  ## 1/s: how quickly the camera closes on its spot
const HEADING_SPRING := 5.0  ## 1/s: how quickly it swings round behind the kart
const FOV_SLOW := 68.0
const FOV_FAST := 78.0
const FAST_SPEED := 30.0  ## m/s where the view is widest

var mode := "chase"

var _heading := 0.0


func _ready() -> void:
	fov = FOV_SLOW
	near = 0.2
	far = 900.0


## Puts the camera straight behind `k` (a race start, a teleport).
func snap(k: KartState) -> void:
	_heading = k.heading
	global_transform = _target(k)


func follow(k: KartState, dt: float) -> void:
	_heading = lerp_angle(_heading, k.heading, 1.0 - exp(-HEADING_SPRING * dt))
	var goal := _target(k)
	var blend := 1.0 - exp(-POSITION_SPRING * dt)
	global_position = global_position.lerp(goal.origin, blend)
	var m: Dictionary = MODES.get(mode, MODES.chase)
	var ahead := Vector3(-sin(_heading), 0.0, -cos(_heading))
	var look := k.pos + ahead * float(m.look_ahead) + Vector3.UP * float(m.look_height)
	if global_position.distance_squared_to(look) > 0.01:
		look_at(look, Vector3.UP)
	fov = lerpf(fov, lerpf(FOV_SLOW, FOV_FAST, clampf(k.speed / FAST_SPEED, 0.0, 1.0)), blend)


func _target(k: KartState) -> Transform3D:
	var m: Dictionary = MODES.get(mode, MODES.chase)
	var behind := Vector3(sin(_heading), 0.0, cos(_heading))
	var at := k.pos + behind * float(m.distance) + Vector3.UP * float(m.height)
	var ahead := -behind
	var look := k.pos + ahead * float(m.look_ahead) + Vector3.UP * float(m.look_height)
	return Transform3D(Basis.looking_at(look - at, Vector3.UP), at)
