class_name KartBotDriver
extends RefCounted
## A bot's driving (#43, spec "Opponents"). It produces the same `KartInput` the rider's pedals and
## lean do, and goes through the same `KartPhysics`, so the race is honest.
##
## - **Power:** its share of the rider's FTP, wandering ±4% slowly (simplex noise) for life. It
##   never reacts to the rider: no rubber-banding. Your watts decide the race.
## - **Line:** pure pursuit of a point ahead on the track's racing line, shifted by its own
##   `line_offset` (eased out in sharp corners), clamped inside the road's edge. The lateral
##   target moves at a capped rate, so the bot never swerves.
## - **Modes** (an enum FSM; one target lane each, highest priority first):
##   DODGE (goo or a puck in its lane ahead) → PASS (a slower kart ahead in its lane: pick a side
##   and hold it until clear) → CRUISE (its line; drawn to a pod row when it holds no item).
##   Side-by-side karts push the target lane apart in every mode.
## - **Drift:** before a sharp corner, a bot with drift skill holds a hard lean into it (the
##   physics' drift entry), keeps the lean past the release threshold through the corner while
##   it stays on its line, and eases off on the exit to cash the mini-turbo. It lets go early if
##   it drifts more than DRIFT_SLIP off its line.
## - **Items:** through `KartItemLogic.wants_use` with its item skill (and hazards and pods from
##   the same logic). Set `items` when the race's item logic exists.
##
## profile: {power_pct, line_offset, drift_skill, item_skill, aggression}

enum Mode { CRUISE, PASS, DODGE }

const POWER_WANDER := 0.04  ## ± share of the bot's power, slowly over time
const WANDER_HZ := 0.01  ## a wander over minutes, not seconds
const LOOKAHEAD_SEC := 0.6
const LOOKAHEAD_MIN := 6.0
const LOOKAHEAD_MAX := 18.0
const EDGE_MARGIN := 1.2  ## the bot's line keeps this far inside the road's edge
const CADENCE := 85.0
const RESISTANCE := 30.0
const LATERAL_RATE := 2.4  ## m/s: how fast the target lane moves
const DODGE_RATE := 4.5
## Line offsets fade out in corners sharper than this (1/m), so the bots take the apex.
const OFFSET_FADE_CURV := 0.025

## Overtaking: karts within this lane width ahead are in the way.
const LANE := 1.9
const PASS_GAP := [2.7, 2.1]  ## lateral clearance when passing, careful .. aggressive
const PASS_LOOK_SEC := [0.7, 1.1]  ## look this many seconds ahead (by speed), careful .. aggressive
const PASS_LOOK_MIN := 8.0
const BESIDE := 2.6  ## m along the track: karts this close are side by side
const SIDE_GAP := 2.2  ## m across the road kept from a kart alongside

## Drift: corners sharper than this (1/m) within DRIFT_LOOK are worth a drift.
const DRIFT_CURV := 0.016
const DRIFT_LOOK := [8.0, 34.0]  ## m ahead
const DRIFT_ENTRY_LEAN := 0.72
const DRIFT_ENTRY_SEC := 0.16  ## the physics wants ≥ 0.65 held for 0.12 s
const DRIFT_ENTRY_PSI := 0.18  ## rad: only from a kart running roughly along the road
const DRIFT_COOLDOWN := 1.5  ## s after a drift before the next
const DRIFT_HOLD_LEAN := 0.34  ## stays above the 0.3 release threshold while drifting
const DRIFT_SLIP := 1.2  ## m off its line before it lets go
const DRIFT_MIN_SPEED := 9.0  ## m/s (the physics needs 40% of top speed)
const DRIFT_OUTSIDE := 1.0  ## m: the drift's line starts this far toward the outside

## Outside a drift the lean stays under the physics' drift entry (0.65), so drifts are only ever
## on purpose.
const MAX_STEER_LEAN := 0.6
const POD_LOOK := 40.0
const HAZARD_LOOK_SEC := 1.4
const ROCKET_CADENCE := 90.0
const LAZY_CADENCE := 55.0

## Seven distinct personalities (in kart order 1..7): line offset, drift, items, aggression.
const PERSONAS := [
	{"line_offset": -1.5, "drift_skill": 0.85, "item_skill": 0.8, "aggression": 0.7},
	{"line_offset": 1.5, "drift_skill": 0.7, "item_skill": 0.6, "aggression": 0.9},
	{"line_offset": -0.5, "drift_skill": 0.55, "item_skill": 0.9, "aggression": 0.4},
	{"line_offset": 0.5, "drift_skill": 0.9, "item_skill": 0.5, "aggression": 0.6},
	{"line_offset": -2.0, "drift_skill": 0.4, "item_skill": 0.7, "aggression": 0.3},
	{"line_offset": 2.0, "drift_skill": 0.6, "item_skill": 0.4, "aggression": 0.8},
	{"line_offset": 0.0, "drift_skill": 0.3, "item_skill": 0.55, "aggression": 0.5},
]

var profile: Dictionary
var ftp_w: float
var power_pct: float
var line_offset: float
var drift_skill: float
var item_skill: float
var aggression: float
## The race's item logic (hazards, pods, the item policy); null races without items.
var items: KartItemLogic = null
var mode := Mode.CRUISE
## Driving state, readable for tests and debugging.
var drifting := 0  ## -1 / +1 while holding a drift (lean direction), 0 otherwise
var lane := NAN  ## the current target d

var _noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _input := KartInput.new()
var _pass_side := 0.0
var _pass_id := -1
var _drift_t := 0.0
var _corner_decided := false
var _corner_drift := false
var _rocket := false
var _drift_cool := 0.0


func _init(bot_profile: Dictionary, rider_ftp_w: float, rng_seed: int) -> void:
	profile = bot_profile
	ftp_w = rider_ftp_w
	power_pct = float(profile.get("power_pct", 0.6))
	line_offset = float(profile.get("line_offset", 0.0))
	drift_skill = clampf(float(profile.get("drift_skill", 0.5)), 0.0, 1.0)
	item_skill = clampf(float(profile.get("item_skill", 0.5)), 0.0, 1.0)
	aggression = clampf(float(profile.get("aggression", 0.5)), 0.0, 1.0)
	_noise.seed = rng_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = WANDER_HZ
	_rng.seed = rng_seed
	_rocket = _rng.randf() < 0.35 + 0.6 * drift_skill


## The profile for bot number `index` (0..6, kart id − 1) at `power_pct` of the rider's FTP.
static func profile_for(index: int, pct: float) -> Dictionary:
	var p: Dictionary = PERSONAS[posmod(index, PERSONAS.size())].duplicate()
	p["power_pct"] = pct
	return p


## The watts the bot pedals at `t` seconds into its life.
func power_at(t: float) -> float:
	return ftp_w * power_pct * (1.0 + POWER_WANDER * clampf(_noise.get_noise_1d(t) * 1.6, -1.0, 1.0))


func think(k: KartState, race: KartRaceLogic, dt: float) -> KartInput:
	_t += dt
	var track := race.track
	_input.power_w = power_at(_t)
	_input.resistance = RESISTANCE
	_input.use_item = false
	_input.standing = false
	if race.phase == KartRaceLogic.Phase.COUNTDOWN or race.phase == KartRaceLogic.Phase.GRID:
		# Some bots nail the rocket start (cadence up through the countdown), some don't.
		_input.cadence = ROCKET_CADENCE if _rocket else LAZY_CADENCE
		_input.lean = 0.0
		lane = k.d
		return _input
	_input.cadence = CADENCE
	if is_nan(lane):
		lane = k.d
	if k.spin_time > 0.0:
		_input.lean = 0.0
		drifting = 0
		lane = k.d
		return _input
	if items:
		_input.use_item = items.wants_use(k.id, item_skill)

	var ahead := clampf(k.speed * LOOKAHEAD_SEC, LOOKAHEAD_MIN, LOOKAHEAD_MAX)
	var s_ahead := track.wrap(k.s + ahead)
	var limit := maxf(0.0, track.half_width(s_ahead) - EDGE_MARGIN)
	var want := _lane_for(k, race, s_ahead)
	want = _keep_apart(k, race, want)
	var rate := DODGE_RATE if mode == Mode.DODGE else LATERAL_RATE
	lane = clampf(move_toward(lane, want, rate * dt), -limit, limit)

	# Pure pursuit toward the lane ahead.
	var target := track.position_at(s_ahead, lane)
	var to := target - k.pos
	var alpha := angle_difference(k.heading, atan2(-to.x, -to.z))  # + = the target is to the left
	var dist := maxf(1.0, Vector2(to.x, to.z).length())
	var yaw_rate := 2.0 * k.speed * sin(alpha) / dist
	var lean := clampf(race.physics.lean_for_yaw_rate(k, track, yaw_rate), -MAX_STEER_LEAN, MAX_STEER_LEAN)
	_input.lean = _drift(k, track, lean, dt)
	return _input


## The lane (d) the bot wants at `s_ahead`: dodge, pass, a pod, or its own line.
func _lane_for(k: KartState, race: KartRaceLogic, s_ahead: float) -> float:
	var track := race.track
	var curv := absf(track.curvature(s_ahead))
	var fade := clampf(1.0 - curv / OFFSET_FADE_CURV, 0.0, 1.0)
	var own := track.racing_line(s_ahead) + line_offset * fade
	if drifting != 0:
		# Start the slide a little outside: the drift tightens it.
		own += float(drifting) * DRIFT_OUTSIDE * clampf(1.0 - _drift_t, 0.0, 1.0)
	if items:
		var dodge := items.dodge_d(k.s, lane, maxf(12.0, k.speed * HAZARD_LOOK_SEC))
		if not is_nan(dodge):
			mode = Mode.DODGE
			return dodge
	var passing := _pass_lane(k, race)
	if not is_nan(passing):
		mode = Mode.PASS
		return passing
	mode = Mode.CRUISE
	if items and k.item == "" and k.roulette_time <= 0.0 and item_skill > 0.3:
		var pod := items.pod_d(k.s, lane, POD_LOOK)
		if not is_nan(pod) and absf(pod - own) < 3.5:
			return lerpf(own, pod, item_skill)
	return own


## A slower kart ahead in the bot's lane: the lane beside it (a side chosen once, kept until the
## pass is done), or NAN when the way is clear.
func _pass_lane(k: KartState, race: KartRaceLogic) -> float:
	var track := race.track
	var look := maxf(PASS_LOOK_MIN, k.speed * lerpf(PASS_LOOK_SEC[0], PASS_LOOK_SEC[1], aggression))
	var block := -1
	var block_ds := INF
	for o: KartState in race.karts:
		if o.id == k.id:
			continue
		var ds := track.delta(k.s, o.s)
		if ds <= 0.5 or ds > look or ds >= block_ds:
			continue
		if absf(o.d - lane) > LANE and o.id != _pass_id:
			continue
		if o.speed > k.speed + 0.5 and o.id != _pass_id:
			continue  # pulling away: no need
		block = o.id
		block_ds = ds
	if block < 0:
		_pass_id = -1
		return NAN
	var o: KartState = race.karts[block]
	var gap := lerpf(PASS_GAP[0], PASS_GAP[1], aggression)
	var limit := maxf(0.0, track.half_width(o.s) - EDGE_MARGIN)
	if block != _pass_id:
		_pass_id = block
		# The side with room, preferring the inside of what comes next.
		var inside := -signf(track.curvature(track.wrap(o.s + 20.0)))
		var room_r := limit - (o.d + gap)
		var room_l := (o.d - gap) + limit
		if room_r < 0.0 and room_l < 0.0:
			_pass_side = 1.0 if room_r > room_l else -1.0
		elif room_r < 0.0:
			_pass_side = -1.0
		elif room_l < 0.0:
			_pass_side = 1.0
		elif absf(inside) > 0.0 and absf(track.curvature(track.wrap(o.s + 20.0))) > 0.006:
			_pass_side = inside
		else:
			_pass_side = 1.0 if lane >= o.d else -1.0
	if absf(o.d - lane) > gap + 0.4 and track.delta(k.s, o.s) < 1.0:
		return NAN
	return clampf(o.d + _pass_side * gap, -limit, limit)


## Pushes the wanted lane away from karts alongside.
func _keep_apart(k: KartState, race: KartRaceLogic, want: float) -> float:
	var track := race.track
	for o: KartState in race.karts:
		if o.id == k.id:
			continue
		var ds := track.delta(k.s, o.s)
		if absf(ds) > BESIDE:
			continue
		var dd := k.d - o.d
		if absf(dd) >= SIDE_GAP:
			continue
		var side := signf(dd) if absf(dd) > 0.05 else (1.0 if k.id > o.id else -1.0)
		var away := o.d + side * SIDE_GAP
		want = maxf(want, away) if side > 0.0 else minf(want, away)
	return want


## The lean, with the drift on top: entry pulse, hold, release on the exit.
func _drift(k: KartState, track: KartTrackModel, lean: float, dt: float) -> float:
	var sharp := _corner_ahead(track, k.s)
	_drift_cool = maxf(0.0, _drift_cool - dt)
	if drifting == 0:
		if sharp == 0.0:
			_corner_decided = false
			return lean
		if not _corner_decided:
			_corner_decided = true
			_corner_drift = _rng.randf() < drift_skill
		if not _corner_drift or k.speed < DRIFT_MIN_SPEED or mode == Mode.DODGE or _drift_cool > 0.0:
			return lean
		# Start from the line or outside it, running along the road.
		var side := -signf(sharp)  # the lean's direction
		if (k.d - lane) * side > 0.3 or absf(angle_difference(track.yaw_at(k.s), k.heading)) > DRIFT_ENTRY_PSI:
			return lean
		# Lean +1 is right; a left-hand corner (curvature +) wants a left lean.
		drifting = -int(signf(sharp))
		_drift_t = 0.0
	_drift_t += dt
	var dir := float(drifting)
	if _drift_t < DRIFT_ENTRY_SEC:
		return dir * DRIFT_ENTRY_LEAN
	var off := (k.d - lane) * dir  # + = inside the line (toward the lean)
	var over := absf(track.curvature(k.s)) < DRIFT_CURV * 0.45 and sharp == 0.0
	if over or off > DRIFT_SLIP or lean * dir < -0.5 or k.speed < DRIFT_MIN_SPEED * 0.8:
		drifting = 0
		_corner_decided = sharp != 0.0
		_drift_cool = DRIFT_COOLDOWN
		return clampf(lean, -0.25, 0.25)  # under the release threshold: the mini-turbo
	return dir * clampf(lean * dir, DRIFT_HOLD_LEAN, 1.0)


## The signed curvature of the sharpest corner within DRIFT_LOOK ahead, or 0 when there is none.
func _corner_ahead(track: KartTrackModel, s: float) -> float:
	var best := 0.0
	var x: float = DRIFT_LOOK[0]
	while x <= DRIFT_LOOK[1]:
		var c := track.curvature(track.wrap(s + x))
		if absf(c) > absf(best):
			best = c
		x += 6.0
	return best if absf(best) >= DRIFT_CURV else 0.0
