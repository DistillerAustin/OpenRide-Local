class_name KartPhysics
extends RefCounted
## Kart Race's arcade physics (#43, DESIGN.md "Physics"), stepped at a fixed 60 Hz in track space.
## Every kart, the rider's and the bots', goes through the same model, so the race is honest:
##
## - **A virtual bike** turns watts into speed: P/max(v, 2) − (rolling + climbing + air) = m·a,
##   with the issue's numbers (85 kg, Crr 0.005, CdA 0.32 m², ρ 1.2). The steady speed matches
##   the power balance exactly; only the inertia is lighter than a real bike's (INERTIA_KG), so
##   the kart answers the pedals in seconds rather than half a minute. With no pedalling a gentle
##   coast brake stops it in about 15 s, and it never rolls backwards.
## - **The kart** runs at the bike's speed × SPEED_SCALE, times its surface and boost multipliers,
##   approaching that target at KART_ACCEL / KART_DECEL (so bumps and caps ease in and out).
## - **Steering**: the lean, with a dead zone and a curve, sets a yaw rate. The assist (the
##   rider's option) adds the road's curvature and a pull back parallel to the road, so a rider
##   who leans roughly right still follows the road, and a held lean moves the kart across it.
## - **Surfaces**: kerbs are as fast as the road; off-road caps the speed at 55% (a boost halves
##   the penalty) and adds rolling drag; the wall bounces the kart back in and costs speed.
##
## Drift, mini-turbo, the knob, boost pads, rocket starts, drafting and climbs (standing) are
## Phase 2 (DESIGN.md "Handling"): their KartState fields exist, `_update_drift` is the hook.
## Logic only: no nodes. Deterministic: the same inputs give the same states.

const SPEED_SCALE := 2.4

# The virtual bike (issue #43).
const MASS_KG := 85.0
const G := 9.81
const C_RR := 0.005
const CDA := 0.32
const RHO := 1.2
## Drafting cuts CdA by up to this share (CdA × 0.7 in a full draft).
const DRAFT_CDA_CUT := 0.3
## Below this bike speed the pedal force stops growing (P / v would be infinite at rest).
const MIN_FORCE_SPEED := 2.0
## The inertia the pedals push against. A real 85 kg rider takes ~25 s to reach a steady speed;
## this makes it ~10 s. Weight still counts in full on hills (MASS_KG).
const INERTIA_KG := 20.0
## With no pedalling, a gentle brake (fading out by COAST_BRAKE_FADE_W) stops the kart in ~15 s.
const COAST_BRAKE_N := 3.0
const COAST_BRAKE_FADE_W := 30.0
## The share of the road's grade the bike feels (a kart track's hills at full grade would crawl
## up at 20 km/h and fly down at 120).
const GRADE_EFFECT := 0.5

# The kart.
const KART_ACCEL := 9.0  ## m/s², toward a higher target speed
const KART_DECEL := 7.0  ## m/s², toward a lower one
const OFFROAD_CAP := 0.55
const OFFROAD_CRR := 4.0  ## rolling resistance × this off-road
const BOOST_MULT := 1.35
const BOOST_PUSH := 3.0  ## m/s added at once when a boost starts
const SPIN_SEC := 1.0
const SPIN_SPEED := 0.4  ## a spin-out cuts the speed to this share
const KART_RADIUS := 0.95  ## for kart-kart contacts

# Steering.
const DEAD_ZONE := 0.06
const STEER_CURVE := 1.4  ## lean past the dead zone, to this power
const STEER_RATE := 1.4  ## rad/s at full lean
const MIN_TURN_RADIUS := 9.0  ## so slow karts can't spin on the spot
## The assist's pull back parallel to the road, 1/s.
const ALIGN_GAIN := 2.0
## Below this speed the assist's pull fades out (no turning on the spot).
const ALIGN_FULL_SPEED := 5.0

# Walls.
const WALL_SPEED_LOSS := 0.6  ## × the sine of the impact angle
const WALL_BOUNCE := 0.3  ## the share of the impact angle kept, mirrored away from the wall
const WALL_BUMP_SPEED := 15.0  ## m/s across the wall for a full-strength bump

## 0 off, 0.5 low, 1 high: the share of the assist (curvature feed-forward and alignment).
var assist := 1.0
## Drift charges faster while resistance is at least this (Phase 2).
var drift_resistance := 40.0
## When set (KartRaceLogic does), the physics emits wall bumps (and, in Phase 2, drift and boost
## events) into it.
var events: KartRaceEvents = null


## The bike speed (m/s) that `power_w` holds on `grade` (dy/ds) in a `draft` (0..1): the root
## of P = v·(Crr·m·g·cosθ + m·g·sinθ + ½·ρ·CdA·v²).
static func steady_bike_speed(power_w: float, grade: float, draft := 0.0) -> float:
	var lo := 0.0
	var hi := 60.0
	if hi * bike_resistance(hi, grade, draft) - power_w < 0.0:
		return hi
	for i in 60:
		var mid := (lo + hi) * 0.5
		if mid * bike_resistance(mid, grade, draft) - power_w < 0.0:
			lo = mid
		else:
			hi = mid
	return lo


## The forces against the bike at speed v, newtons: rolling (× crr_mult), climbing and air.
static func bike_resistance(v: float, grade: float, draft := 0.0, crr_mult := 1.0) -> float:
	var theta := atan(grade)
	return C_RR * crr_mult * MASS_KG * G * cos(theta) + MASS_KG * G * sin(theta) \
		+ 0.5 * RHO * CDA * (1.0 - DRAFT_CDA_CUT * clampf(draft, 0.0, 1.0)) * v * v


## Lean (-1..1) through the dead zone and the response curve: the steering share, -1..1.
static func shape_lean(lean: float) -> float:
	var a := absf(lean)
	if a <= DEAD_ZONE:
		return 0.0
	return signf(lean) * pow(minf(1.0, (a - DEAD_ZONE) / (1.0 - DEAD_ZONE)), STEER_CURVE)


## The lean that `shape_lean` turns into `steer` (for bots that know the yaw rate they want).
static func lean_for_steer(steer: float) -> float:
	var a := absf(steer)
	if a <= 0.0:
		return 0.0
	return signf(steer) * (DEAD_ZONE + (1.0 - DEAD_ZONE) * pow(minf(1.0, a), 1.0 / STEER_CURVE))


## The yaw rate (rad/s) a full lean gives at `speed`.
static func max_yaw_rate(speed: float) -> float:
	return minf(STEER_RATE, speed / MIN_TURN_RADIUS)


## The lean (-1..1) that, on top of the assist, turns the kart at `yaw_rate` (+ = left).
func lean_for_yaw_rate(k: KartState, track: KartTrackModel, yaw_rate: float) -> float:
	var full := max_yaw_rate(k.speed)
	if full <= 0.0:
		return 0.0
	return lean_for_steer(clampf(-(yaw_rate - assist_yaw_rate(k, track)) / full, -1.0, 1.0))


## The assist's share of the yaw rate (rad/s, + = left): the road's curvature and a pull back
## parallel to it.
func assist_yaw_rate(k: KartState, track: KartTrackModel) -> float:
	if assist <= 0.0:
		return 0.0
	var psi := angle_difference(track.yaw_at(k.s), k.heading)
	var pull := ALIGN_GAIN * minf(1.0, k.speed / ALIGN_FULL_SPEED)
	return assist * (track.curvature(k.s) * k.speed - pull * psi)


func step(k: KartState, inp: KartInput, track: KartTrackModel, dt: float) -> void:
	var spinning := k.spin_time > 0.0
	k.spin_time = maxf(0.0, k.spin_time - dt)
	k.boost_time = maxf(0.0, k.boost_time - dt)
	k.shield_time = maxf(0.0, k.shield_time - dt)
	var offroad := k.surface == KartTrackModel.Surface.OFFROAD

	# The virtual bike: pedal force against rolling, climbing and air.
	var grade := track.grade(k.s) * GRADE_EFFECT
	var resist := bike_resistance(k.v_bike, grade, k.draft, OFFROAD_CRR if offroad else 1.0)
	var brake := COAST_BRAKE_N * clampf(1.0 - inp.power_w / COAST_BRAKE_FADE_W, 0.0, 1.0)
	var force := inp.power_w / maxf(k.v_bike, MIN_FORCE_SPEED) - resist - brake
	k.v_bike = maxf(0.0, k.v_bike + force / INERTIA_KG * dt)

	# The kart's speed eases toward the bike's, scaled by surface and boost.
	var target := k.v_bike * SPEED_SCALE
	if offroad:
		target *= OFFROAD_CAP if k.boost_time <= 0.0 else 1.0 - (1.0 - OFFROAD_CAP) * 0.5
	if k.boost_time > 0.0:
		target *= BOOST_MULT
	if spinning:
		target = minf(target, k.speed)
	k.speed = move_toward(k.speed, target, (KART_ACCEL if target > k.speed else KART_DECEL) * dt)

	# Steering: lean plus the assist; none while spinning out.
	var yaw_rate := 0.0
	if not spinning:
		yaw_rate = -shape_lean(inp.lean) * max_yaw_rate(k.speed) + assist_yaw_rate(k, track)
		yaw_rate += _update_drift(k, inp, track, dt)
	k.steer = clampf(-yaw_rate / STEER_RATE, -1.0, 1.0)
	k.heading = wrapf(k.heading + yaw_rate * dt, -PI, PI)

	# Move, then find where on the track that is.
	var p := track.project(k.pos + k.forward() * k.speed * dt, k.s)
	var reach := track.half_width(p.s) + track.verge
	if absf(p.d) > reach:
		p = _hit_wall(k, track, p, reach)
	k.pos = p.position
	k.s = p.s
	k.d = p.d
	k.surface = track.surface(p.s, p.d)
	k.normal = p.normal


## Starts (or extends) a boost: BOOST_MULT on the target speed for `seconds`, and a push.
func apply_boost(k: KartState, seconds: float) -> void:
	k.boost_time = maxf(k.boost_time, seconds)
	k.speed += BOOST_PUSH


## Spins the kart out (SPIN_SEC without control, the speed cut to SPIN_SPEED). A shield absorbs
## it instead and is used up: then it returns false.
func apply_spinout(k: KartState) -> bool:
	if k.shield_time > 0.0:
		k.shield_time = 0.0
		return false
	k.spin_time = SPIN_SEC
	k.speed *= SPIN_SPEED
	return true


## Pushes overlapping karts apart (circles of KART_RADIUS, in the horizontal plane), the lighter
## one further. Returns [[a_id, b_id, strength 0..1], ...] for the pairs that touched.
static func resolve_contacts(karts: Array) -> Array:
	var hits := []
	var reach := 2.0 * KART_RADIUS
	var touch := reach - 0.001  # karts pushed apart last time sit at `reach`, give or take rounding
	for i in karts.size():
		var a: KartState = karts[i]
		for j in range(i + 1, karts.size()):
			var b: KartState = karts[j]
			var dx := b.pos.x - a.pos.x
			var dz := b.pos.z - a.pos.z
			var dist2 := dx * dx + dz * dz
			if dist2 >= touch * touch or absf(b.pos.y - a.pos.y) > 2.0:
				continue
			var dist := sqrt(dist2)
			var n := Vector3(dx / dist, 0.0, dz / dist) if dist > 0.0001 else Vector3.RIGHT
			var overlap := reach - dist
			var total := a.weight + b.weight
			a.pos -= n * overlap * (b.weight / total)
			b.pos += n * overlap * (a.weight / total)
			hits.append([a.id, b.id, clampf(overlap / reach, 0.0, 1.0)])
	return hits


## Phase 2 (handling): drift entry, charge, tiers, release into a mini-turbo, the knob. Returns
## the drift's extra yaw rate (rad/s, + = left). Emit drift_started / drift_tier / boost_started
## through `events`.
func _update_drift(_k: KartState, _inp: KartInput, _track: KartTrackModel, _dt: float) -> float:
	return 0.0


## The kart went past the barrier: put it back against it, and when it was heading into it,
## bounce it off and take speed in proportion to the impact angle.
func _hit_wall(k: KartState, track: KartTrackModel, p: KartTrackPoint, reach: float) -> KartTrackPoint:
	var side := signf(p.d)
	var road_yaw := track.yaw_at(p.s)
	var psi := angle_difference(road_yaw, k.heading)
	# The share of the kart's speed going across the road toward this wall (d grows as -sin ψ).
	var into := -sin(psi) * side
	if into > 0.0:
		var strength := clampf(into * k.speed / WALL_BUMP_SPEED, 0.0, 1.0)
		k.speed *= 1.0 - WALL_SPEED_LOSS * into
		k.heading = wrapf(road_yaw - psi * WALL_BOUNCE, -PI, PI)
		if events and strength >= 0.05:
			events.wall_bump.emit(k.id, strength)
	var inside := side * (reach - 0.01)
	var back := track.project(track.position_at(p.s, inside), p.s)
	return back
