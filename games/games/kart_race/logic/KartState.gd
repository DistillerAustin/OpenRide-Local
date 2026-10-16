class_name KartState
extends RefCounted
## One kart's whole simulated state (#43). The logic writes it; the views only read it.

var id: int  ## its index in KartRaceLogic.karts; 0 is the rider
var racer_id: String  ## KartRoster's id
var weight := 1.0  ## 0.85 light .. 1.15 heavy (kart-kart contacts)
var pos: Vector3  ## on the road surface
var heading := 0.0  ## yaw, radians (Node3D.rotation.y: forward is -Z at 0, + turns left)
var speed := 0.0  ## kart m/s (world)
var v_bike := 0.0  ## virtual bike m/s
var s := 0.0  ## track space (KartTrackModel)
var d := 0.0
var lap := 0  ## start-line crossings: 0 on the grid, 1 on the first lap, laps + 1 when finished
var surface := 0  ## KartTrackModel.Surface under the kart
var normal := Vector3.UP  ## the road surface's normal under the kart (for the views)
var steer := 0.0  ## -1..1, + = right, for visuals
var drift_dir := 0  ## -1 left, 0 none, +1 right
var drift_charge := 0.0  ## seconds of charge
var drift_tier := 0  ## 0 none, 1-3 spark tiers
var knob_boosting := false  ## the resistance knob is speeding up the drift charge
var boost_time := 0.0  ## seconds of boost left
var spin_time := 0.0  ## seconds of spin-out left (no control)
var shield_time := 0.0  ## seconds of shield left
var hop := 0.0  ## visual hop height, metres
var item := ""  ## the held item's id, "" for none
var roulette_time := 0.0  ## seconds of item roulette left
var finished := false
var finish_time := 0.0  ## race seconds at the finish (projected for karts placed early)
var place := 0  ## 1-based race position
var draft := 0.0  ## 0..1 this tick

# Handling (Phase 2, KartPhysics). The views may read these; only the physics writes them.
var slide := 0.0  ## the drift's visual body yaw, radians, + = nose left (a right drift slides nose right: < 0)
var lean_smooth := 0.0  ## the lean after the steering response lag
var drift_time := 0.0  ## seconds into the current drift (the hop is its start)
var boost_kind := ""  ## the latest boost's kind ("drift"|"pad"|"item"|"start"), for the views
var boost_tier := 0  ## the latest drift boost's tier (0 for other kinds)
var climbing := false  ## on a climb zone this tick
var standing_bonus := false  ## standing on a climb: the drag cut applies
var on_pad := false  ## on a boost pad this tick (a pad fires once per visit)
var rocket_hold := 0.0  ## seconds of cadence >= ROCKET_CADENCE in the countdown's "2" window
var drift_hold := 0.0  ## seconds the lean has been held hard toward drift_hold_dir
var drift_hold_dir := 0
var drift_release := 0.0  ## seconds the lean has been eased off during a drift
var drift_res0 := 0.0  ## the resistance when the drift began (the knob's rise)
var drift_cool := 0.0  ## seconds before another drift may start

## Further than this (metres) in one tick is a placement, not a move (`draw_into`).
const TELEPORT_M := 4.0

# The pose at the start of the last logic tick (`snap`), for drawing between ticks: the logic
# steps at 30 Hz and the views draw at 60, between the two poses (`draw_into`).
var prev_pos := Vector3.ZERO
var prev_heading := 0.0
var prev_normal := Vector3.UP
var prev_hop := 0.0
var prev_slide := 0.0
var prev_steer := 0.0
var prev_speed := 0.0


func forward() -> Vector3:
	return Vector3(-sin(heading), 0.0, -cos(heading))


## Remembers the current pose as the previous one (KartRaceLogic, at the start of each tick and
## when it places the karts).
func snap() -> void:
	prev_pos = pos
	prev_heading = heading
	prev_normal = normal
	prev_hop = hop
	prev_slide = slide
	prev_steer = steer
	prev_speed = speed


## A copy to draw, into `out`: the pose `alpha` (0..1) of the way from the last tick's start to
## now, and the rest of the state as it is (the views, the camera and the item views read it).
## A kart moved further than a tick could take it (placed by hand) is drawn where it is.
func draw_into(out: KartState, alpha: float) -> void:
	if prev_pos.distance_squared_to(pos) > TELEPORT_M * TELEPORT_M:
		alpha = 1.0
	out.id = id
	out.racer_id = racer_id
	out.weight = weight
	out.pos = prev_pos.lerp(pos, alpha)
	out.heading = wrapf(prev_heading + angle_difference(prev_heading, heading) * alpha, -PI, PI)
	out.normal = prev_normal.lerp(normal, alpha).normalized()
	out.hop = lerpf(prev_hop, hop, alpha)
	out.slide = lerpf(prev_slide, slide, alpha)
	out.steer = lerpf(prev_steer, steer, alpha)
	out.speed = lerpf(prev_speed, speed, alpha)
	out.v_bike = v_bike
	out.s = s
	out.d = d
	out.lap = lap
	out.surface = surface
	out.drift_dir = drift_dir
	out.drift_charge = drift_charge
	out.drift_tier = drift_tier
	out.knob_boosting = knob_boosting
	out.boost_time = boost_time
	out.spin_time = spin_time
	out.shield_time = shield_time
	out.item = item
	out.roulette_time = roulette_time
	out.finished = finished
	out.finish_time = finish_time
	out.place = place
	out.draft = draft
	out.lean_smooth = lean_smooth
	out.drift_time = drift_time
	out.boost_kind = boost_kind
	out.boost_tier = boost_tier
