class_name KartItemLogic
extends RefCounted
## Kart Race's items (#43, spec "Items"): the item pods, the roulette, the odds by position, the
## six items, their projectiles and puddles, and the policy that fires them for the bots (and for
## the rider when the Auto items option is on). One instance per race, stepped by the scene right
## after `KartRaceLogic.step`, with the same inputs (each `use_item` is an edge).
##
## Effects on karts go only through `KartPhysics.apply_boost` / `apply_spinout` / `apply_pull`; everything that
## happens goes out through the race's `KartRaceEvents` (item_picked, item_used, kart_hit,
## shield_blocked, boost_started "item"). Plain logic, no nodes: `KartItemViews` draws `pods`,
## `shots`, `goos` and the magnets from here.
##
## | Item | Effect |
## | turbo  | Turbo Can: an instant TURBO_SEC boost |
## | puck   | Bumper Puck: a heavy puck fired forward; bounces off walls up to PUCK_BOUNCES times and
##            spins out the first kart it hits (its owner too, once it has flown a moment) |
## | drone  | Seeker Drone: flies along the track to the kart one place ahead and spins it out |
## | goo    | Goo Puddle: dropped behind; the first kart through it spins out |
## | shield | Shield Bubble: SHIELD_SEC, blocks one hit (KartPhysics.apply_spinout uses it up) |
## | magnet | Draft Magnet: MAGNET_SEC of pull toward the kart ahead, with a full draft |

## Emitted when a kart breaks a pod (for the pod's burst and the pickup sound; the item itself
## lands later for the rider: `item_picked` fires when the roulette stops).
signal pod_broken(pod_index: int, kart_id: int)

const ITEMS := ["turbo", "puck", "drone", "goo", "shield", "magnet"]
const NAMES := {"turbo": "Turbo Can", "puck": "Bumper Puck", "drone": "Seeker Drone",
	"goo": "Goo Puddle", "shield": "Shield Bubble", "magnet": "Draft Magnet"}

## Weights by position bucket: the leader, the front (to ~35%), the middle (to ~75%), the back.
## The leaders draw defensive items, the back of the pack catch-up items (spec: no speed
## rubber-banding; catch-up comes from the odds, drafting and drift boosts).
const ODDS := {
	"turbo": [10, 18, 24, 26],
	"puck": [18, 30, 26, 14],
	"drone": [0, 4, 16, 26],
	"goo": [36, 24, 12, 4],
	"shield": [36, 18, 10, 6],
	"magnet": [0, 6, 12, 24],
}

const ROULETTE_SEC := 0.9
const POD_RESPAWN_SEC := 3.0
const POD_REACH := 1.7  ## horizontal metres from a pod's centre to a kart's that pick it up
const POD_EDGE := 1.3  ## the outer pods keep this far inside the road's edge
const POD_ROWS_GAP := 1.0  ## m: the s of a row is its zone's middle

const TURBO_SEC := 1.2
const SHIELD_SEC := 8.0
const MAGNET_SEC := 3.0
const MAGNET_ACCEL := 11.0  ## m/s² toward the target's speed + MAGNET_GAIN (physics eases back at 7)
const MAGNET_GAIN := 4.0
const MAGNET_LATERAL := 2.2  ## m/s toward the target's line
const MAGNET_RANGE := 90.0  ## m: the pull lets go beyond this

const PUCK_SPEED := 36.0  ## m/s, or the thrower's speed + PUCK_OVER if faster
const PUCK_OVER := 12.0
const PUCK_BOUNCES := 3
const PUCK_LIFE_SEC := 7.0
const PUCK_RADIUS := 0.45
const PUCK_ARM_SEC := 0.5  ## the thrower can't be hit by its own puck before this
const PUCK_WALL_INSET := 0.35

const DRONE_SPEED := 40.0
const DRONE_LIFE_SEC := 10.0
const DRONE_FIZZLE_M := 220.0  ## with nobody ahead, it flies this far and fizzles
const DRONE_HOMING_M := 25.0  ## from here on it steers onto the target's line
const DRONE_LATERAL := 3.0  ## m/s across the road on the racing line
const DRONE_HOMING_LATERAL := 14.0
const DRONE_HIT_REACH := 1.5

const GOO_BEHIND := 3.4  ## m behind the kart's centre
const GOO_RADIUS := 1.35
const GOO_ARM_SEC := 1.0
const GOO_LIFE_SEC := 40.0
const GOO_MAX := 8
## Live pucks and drones at once (the views draw this many): firing another retires the oldest,
## as GOO_MAX does for goo, so a hazard is never live without being drawn.
const PUCK_MAX := 4
const DRONE_MAX := 3

const HIT_REACH := KartPhysics.KART_RADIUS + PUCK_RADIUS
## Hits and pickups are swept over a tick's movement; a kart that moved further than this in one
## (placed by hand) is tested where it is.
const SWEEP_MAX := 4.0

## Bot and Auto-items policy.
const AUTO_SKILL := 0.85
const HOLD_MIN := [2.6, 0.6]  ## s: low skill .. high skill
const HOLD_MAX := 11.0


## An item pod: a glass capsule floating over the road.
class Pod:
	var s := 0.0
	var d := 0.0
	var pos := Vector3.ZERO
	var respawn := 0.0  ## seconds until it is back; 0 = ready
	var age := 10.0  ## seconds since it last came back (views pop it in)

	func ready() -> bool:
		return respawn <= 0.0


## A projectile: a puck or a drone.
class Shot:
	var kind := ""
	var owner := -1
	var target := -1  ## drones: the kart id it chases, -1 none
	var pos := Vector3.ZERO  ## on the road surface (views lift it)
	var prev_pos := Vector3.ZERO  ## at the start of the last tick (the views draw in between)
	var s := 0.0
	var d := 0.0
	var progress := 0.0  ## drones: lap × length + s, like KartRaceLogic.progress
	var heading := 0.0  ## yaw, like KartState.heading
	var speed := 0.0
	var age := 0.0
	var bounces := 0
	var alive := true
	var height := 0.0  ## drones: hover height over the road, metres


## A goo puddle on the road.
class Goo:
	var owner := -1
	var s := 0.0
	var d := 0.0
	var pos := Vector3.ZERO
	var heading := 0.0
	var age := 0.0
	var alive := true


var race: KartRaceLogic
var rider_id := KartRaceLogic.RIDER
## The Auto items option: the rider's item fires through the same policy as the bots'.
var auto_rider := false
var pods: Array[Pod] = []
var shots: Array[Shot] = []
var goos: Array[Goo] = []
var magnet_time := PackedFloat32Array()  ## per kart, seconds of pull left
var magnet_target := PackedInt32Array()  ## per kart, the kart pulled toward, -1 none

var _rng := RandomNumberGenerator.new()
var _pending: Array[String] = []  ## per kart: the item the roulette will land on
var _held := PackedFloat32Array()  ## per kart: seconds the current item has been held
var _urge := PackedFloat32Array()  ## per kart: the policy's random "just use it" threshold


func _init(race_logic: KartRaceLogic, rng_seed := 0) -> void:
	race = race_logic
	_rng.seed = rng_seed
	var n := race.karts.size()
	magnet_time.resize(n)
	magnet_target.resize(n)
	_held.resize(n)
	_urge.resize(n)
	for i in n:
		magnet_target[i] = -1
		_pending.append("")
		_urge[i] = _rng.randf()
	for z in race.track.zones:
		if str(z.get("type", "")) == "items":
			_add_row(z)


# --- Odds ---

## The weights {item: weight} for a kart in `place` (1-based) of `racers`.
static func odds(place: int, racers: int) -> Dictionary:
	var bucket := _bucket(place, racers)
	var out := {}
	for item in ITEMS:
		out[item] = ODDS[item][bucket]
	return out


## A random item for `place` of `racers`, by the odds.
static func roll(place: int, racers: int, rng: RandomNumberGenerator) -> String:
	var bucket := _bucket(place, racers)
	var total := 0.0
	for item in ITEMS:
		total += float(ODDS[item][bucket])
	var pick := rng.randf() * total
	for item in ITEMS:
		pick -= float(ODDS[item][bucket])
		if pick < 0.0:
			return item
	return ITEMS[0]


static func _bucket(place: int, racers: int) -> int:
	if place <= 1:
		return 0
	var f := float(place - 1) / maxf(1.0, float(racers - 1))
	if f < 0.35:
		return 1
	if f < 0.75:
		return 2
	return 3


# --- Pods ---

## Adds a pod at (s, d) on the road (rows come from the track's "items" zones).
func add_pod(s: float, d: float) -> Pod:
	var pod := Pod.new()
	pod.s = race.track.wrap(s)
	pod.d = d
	pod.pos = race.track.position_at(pod.s, d)
	pods.append(pod)
	return pod


func _add_row(zone: Dictionary) -> void:
	var track := race.track
	var s0 := float(zone.s0)
	var span := track.delta(s0, float(zone.s1))
	var s := track.wrap(s0 + span * 0.5)
	var limit := track.half_width(s) - POD_EDGE
	var count := 5 if limit >= 4.6 else 4
	for i in count:
		add_pod(s, lerpf(-limit, limit, float(i) / (count - 1)))


# --- The step ---

## One fixed step, right after the race's: roulettes, pickups, uses, projectiles, puddles,
## magnets. `inputs[id].use_item` is the edge that fires kart id's item.
func step(dt: float, inputs: Array) -> void:
	if race.phase != KartRaceLogic.Phase.RACING and race.phase != KartRaceLogic.Phase.FINISHED:
		return
	for pod in pods:
		if pod.respawn > 0.0:
			pod.respawn = maxf(0.0, pod.respawn - dt)
			if pod.respawn <= 0.0:
				pod.age = 0.0
		else:
			pod.age += dt
	for shot in shots:
		shot.prev_pos = shot.pos
	for k: KartState in race.karts:
		_step_kart(k, inputs[k.id] if k.id < inputs.size() else null, dt)
	for shot in shots:
		if shot.alive:
			if shot.kind == "puck":
				_step_puck(shot, dt)
			else:
				_step_drone(shot, dt)
	for goo in goos:
		if goo.alive:
			_step_goo(goo, dt)
	_compact()


func _step_kart(k: KartState, inp: KartInput, dt: float) -> void:
	var id := k.id
	if k.roulette_time > 0.0:
		k.roulette_time = maxf(0.0, k.roulette_time - dt)
		if k.roulette_time <= 0.0:
			_land(k)
	if k.item != "":
		_held[id] += dt
		var want := false
		if id == rider_id and not auto_rider:
			want = inp != null and inp.use_item
		elif id == rider_id:
			want = wants_use(id, AUTO_SKILL)
		else:
			want = inp != null and inp.use_item
		if want:
			use(id)
	if not k.finished:
		_pickups(k)
	if magnet_time[id] > 0.0:
		_pull(k, dt)


func _pickups(k: KartState) -> void:
	var reach2 := POD_REACH * POD_REACH
	var from := _swept_from(k)
	for i in pods.size():
		var pod := pods[i]
		if not pod.ready():
			continue
		if not passes_within(from - pod.pos, k.pos - pod.pos, reach2) or absf(pod.pos.y - k.pos.y) > 2.0:
			continue
		pod.respawn = POD_RESPAWN_SEC
		pod_broken.emit(i, k.id)
		if k.item != "" or k.roulette_time > 0.0:
			continue
		_pending[k.id] = roll(maxi(k.place, 1), race.karts.size(), _rng)
		if k.id == rider_id:
			k.roulette_time = ROULETTE_SEC
		else:
			_land(k)


func _land(k: KartState) -> void:
	k.item = _pending[k.id]
	_pending[k.id] = ""
	_held[k.id] = 0.0
	_urge[k.id] = _rng.randf()
	if k.item != "":
		race.events.item_picked.emit(k.id, k.item)


## Gives kart `kart_id` an item at once (tests, dev keys).
func give(kart_id: int, item: String) -> void:
	var k: KartState = race.karts[kart_id]
	k.roulette_time = 0.0
	_pending[kart_id] = item
	_land(k)


## Uses kart `kart_id`'s held item now. Returns false when it holds none.
func use(kart_id: int) -> bool:
	var k: KartState = race.karts[kart_id]
	if k.item == "" or k.roulette_time > 0.0:
		return false
	var item := k.item
	k.item = ""
	_held[kart_id] = 0.0
	match item:
		"turbo":
			race.physics.apply_boost(k, TURBO_SEC)
			race.events.boost_started.emit(kart_id, "item", 0)
		"puck":
			_fire_puck(k)
		"drone":
			_fire_drone(k)
		"goo":
			_drop_goo(k)
		"shield":
			k.shield_time = SHIELD_SEC
		"magnet":
			magnet_time[kart_id] = MAGNET_SEC
			magnet_target[kart_id] = _ahead_of(k)
	race.events.item_used.emit(kart_id, item)
	return true


## A puck, drone or goo got kart `k`: spin it out, or its shield takes the hit.
func hit(k: KartState, by_id: int, item: String) -> void:
	if race.physics.apply_spinout(k):
		magnet_time[k.id] = 0.0
		race.events.kart_hit.emit(k.id, by_id, item)
	else:
		race.events.shield_blocked.emit(k.id)


# --- Pucks ---

func _fire_puck(k: KartState) -> void:
	var shot := Shot.new()
	shot.kind = "puck"
	shot.owner = k.id
	shot.heading = k.heading
	shot.speed = maxf(PUCK_SPEED, k.speed + PUCK_OVER)
	var p := race.track.project(k.pos + k.forward() * (KartPhysics.KART_RADIUS + PUCK_RADIUS + 0.4), k.s)
	shot.pos = p.position
	shot.s = p.s
	shot.d = p.d
	shot.prev_pos = shot.pos
	_add_shot(shot, PUCK_MAX)


func _step_puck(shot: Shot, dt: float) -> void:
	var track := race.track
	shot.age += dt
	if shot.age >= PUCK_LIFE_SEC:
		shot.alive = false
		return
	var fwd := Vector3(-sin(shot.heading), 0.0, -cos(shot.heading))
	var was := shot.pos
	var p := track.project(shot.pos + fwd * shot.speed * dt, shot.s)
	var reach := track.half_width(p.s) + track.verge - PUCK_WALL_INSET
	if absf(p.d) > reach:
		shot.bounces += 1
		if shot.bounces > PUCK_BOUNCES:
			shot.alive = false
			return
		var road_yaw := track.yaw_at(p.s)
		var psi := angle_difference(road_yaw, shot.heading)
		shot.heading = wrapf(road_yaw - psi, -PI, PI)
		shot.speed *= 0.92
		p = track.project(track.position_at(p.s, signf(p.d) * (reach - 0.02)), p.s)
	shot.pos = p.position
	shot.s = p.s
	shot.d = p.d
	var reach2 := HIT_REACH * HIT_REACH
	for k: KartState in race.karts:
		if k.id == shot.owner and shot.age < PUCK_ARM_SEC:
			continue
		if passes_within(_swept_from(k) - was, k.pos - shot.pos, reach2) and absf(k.pos.y - shot.pos.y) < 2.0:
			shot.alive = false
			hit(k, shot.owner, "puck")
			return


# --- Drones ---

func _fire_drone(k: KartState) -> void:
	var shot := Shot.new()
	shot.kind = "drone"
	shot.owner = k.id
	shot.target = _ahead_of(k)
	shot.progress = race.progress(k.id) + 1.0
	shot.s = race.track.wrap(shot.progress)
	shot.d = k.d
	shot.speed = maxf(DRONE_SPEED, k.speed + 10.0)
	shot.height = 1.2
	shot.pos = race.track.position_at(shot.s, shot.d)
	shot.heading = race.track.yaw_at(shot.s)
	shot.prev_pos = shot.pos
	_add_shot(shot, DRONE_MAX)


## Adds `shot`, retiring the oldest live one of its kind past `limit`.
func _add_shot(shot: Shot, limit: int) -> void:
	shots.append(shot)
	var live := 0
	for other in shots:
		if other.alive and other.kind == shot.kind:
			live += 1
	if live <= limit:
		return
	for other in shots:
		if other.alive and other.kind == shot.kind:
			other.alive = false
			return


func _step_drone(shot: Shot, dt: float) -> void:
	var track := race.track
	shot.age += dt
	if shot.target >= 0 and race.karts[shot.target].finished and race.phase == KartRaceLogic.Phase.RACING:
		shot.target = _ahead_of(race.karts[shot.target])
	if shot.age >= DRONE_LIFE_SEC or (shot.target < 0 and shot.age * shot.speed > DRONE_FIZZLE_M):
		shot.alive = false
		return
	shot.progress += shot.speed * dt
	shot.s = track.wrap(shot.progress)
	var want_d := track.racing_line(shot.s)
	var rate := DRONE_LATERAL
	var gap := INF
	if shot.target >= 0:
		var t: KartState = race.karts[shot.target]
		gap = race.progress(t.id) - shot.progress
		if gap < DRONE_HOMING_M:
			want_d = t.d
			rate = DRONE_HOMING_LATERAL
	shot.d = move_toward(shot.d, want_d, rate * dt)
	var limit := track.half_width(shot.s) + KartTrackModel.KERB_WIDTH
	shot.d = clampf(shot.d, -limit, limit)
	shot.pos = track.position_at(shot.s, shot.d)
	shot.heading = track.yaw_at(shot.s)
	# Cruise high, dive onto the target over the last metres.
	shot.height = lerpf(0.5, 2.2, clampf((gap - 1.0) / 10.0, 0.0, 1.0)) if gap < INF else 2.2
	if shot.target >= 0 and gap < 1.0:
		var t: KartState = race.karts[shot.target]
		if absf(t.d - shot.d) < DRONE_HIT_REACH or gap < -2.0:
			shot.alive = false
			hit(t, shot.owner, "drone")


# --- Goo ---

func _drop_goo(k: KartState) -> void:
	var goo := Goo.new()
	goo.owner = k.id
	goo.s = race.track.wrap(k.s - GOO_BEHIND)
	var limit := race.track.half_width(goo.s) + KartTrackModel.KERB_WIDTH
	goo.d = clampf(k.d, -limit, limit)
	goo.pos = race.track.position_at(goo.s, goo.d)
	goo.heading = k.heading
	goos.append(goo)
	if live_goos() > GOO_MAX:
		for g in goos:
			if g.alive:
				g.alive = false
				break


func _step_goo(goo: Goo, dt: float) -> void:
	goo.age += dt
	if goo.age >= GOO_LIFE_SEC:
		goo.alive = false
		return
	var reach := GOO_RADIUS + KartPhysics.KART_RADIUS * 0.6
	var reach2 := reach * reach
	for k: KartState in race.karts:
		if k.id == goo.owner and goo.age < GOO_ARM_SEC:
			continue
		if k.spin_time > 0.0:
			continue
		if passes_within(_swept_from(k) - goo.pos, k.pos - goo.pos, reach2) and absf(k.pos.y - goo.pos.y) < 1.5:
			goo.alive = false
			hit(k, goo.owner, "goo")
			return


# --- Swept contacts ---

## Where kart k started this tick, for the swept tests: its pose at the tick's start, or where
## it is now if it moved further than a tick could take it (placed by hand: tests, the grid).
func _swept_from(k: KartState) -> Vector3:
	return k.prev_pos if k.prev_pos.distance_squared_to(k.pos) < SWEEP_MAX * SWEEP_MAX else k.pos


## Whether something moving from offset `a0` to offset `a1` (from a target, horizontally) came
## within sqrt(reach2) of it on the way: swept, so a 30 Hz tick never steps through a hit.
static func passes_within(a0: Vector3, a1: Vector3, reach2: float) -> bool:
	var ex := a1.x - a0.x
	var ez := a1.z - a0.z
	var len2 := ex * ex + ez * ez
	var t := clampf(-(a0.x * ex + a0.z * ez) / len2, 0.0, 1.0) if len2 > 0.000001 else 1.0
	var x := a0.x + ex * t
	var z := a0.z + ez * t
	return x * x + z * z <= reach2


# --- Magnets ---

func _pull(k: KartState, dt: float) -> void:
	var id := k.id
	magnet_time[id] = maxf(0.0, magnet_time[id] - dt)
	var t_id := magnet_target[id]
	if t_id < 0 or k.spin_time > 0.0:
		return
	var t: KartState = race.karts[t_id]
	var gap := race.progress(t_id) - race.progress(id)
	if gap < 1.5 or gap > MAGNET_RANGE:
		return
	race.physics.apply_pull(k, race.track, t.speed + MAGNET_GAIN, MAGNET_ACCEL, t.d, MAGNET_LATERAL, dt)


## The id of the kart one place ahead of `k` (-1 for the leader).
func _ahead_of(k: KartState) -> int:
	var want := k.place - 1
	if want < 1:
		return -1
	for o: KartState in race.karts:
		if o.place == want and o.id != k.id:
			return o.id
	return -1


# --- Queries (views, bots) ---

func live_shots() -> int:
	var n := 0
	for shot in shots:
		if shot.alive:
			n += 1
	return n


func live_goos() -> int:
	var n := 0
	for goo in goos:
		if goo.alive:
			n += 1
	return n


## The lateral position a kart at (s, d) should move to to miss a hazard (goo, or a puck coming
## its way) within `ahead` metres, or NAN when its line is clear.
func dodge_d(s: float, d: float, ahead: float) -> float:
	var track := race.track
	var clear := GOO_RADIUS + KartPhysics.KART_RADIUS + 0.5
	for goo in goos:
		if not goo.alive:
			continue
		var ds := track.delta(s, goo.s)
		if ds > 1.0 and ds < ahead and absf(goo.d - d) < clear:
			return _side_step(goo.s, goo.d, d, clear + 0.3)
	for shot in shots:
		if not shot.alive or shot.kind != "puck":
			continue
		var ds := track.delta(s, shot.s)
		if ds > 2.0 and ds < ahead and absf(shot.d - d) < HIT_REACH + 0.6:
			var toward := angle_difference(track.yaw_at(shot.s), shot.heading)
			if absf(toward) > PI * 0.5:  # coming back down the track
				return _side_step(shot.s, shot.d, d, HIT_REACH + 1.0)
	return NAN


func _side_step(s: float, hazard_d: float, d: float, gap: float) -> float:
	var limit := race.track.half_width(s) - 1.0
	var left := hazard_d - gap
	var right := hazard_d + gap
	var go_right := d >= hazard_d
	if go_right and right > limit:
		go_right = false
	elif not go_right and left < -limit:
		go_right = true
	return clampf(right if go_right else left, -limit, limit)


## The d of the ready pod nearest to `d` in the next `ahead` metres, or NAN.
func pod_d(s: float, d: float, ahead: float) -> float:
	var best := NAN
	var best_gap := INF
	var length := race.track.length
	for pod in pods:
		if pod.respawn > 0.0:  # not ready()
			continue
		var ds := fposmod(pod.s - s, length)  # track.delta, inline (bots ask every think)
		if ds > length * 0.5:
			ds -= length
		if ds < 2.0 or ds > ahead:
			continue
		var gap := absf(pod.d - d)
		if gap < best_gap:
			best_gap = gap
			best = pod.d
	return best


## True while a puck or drone is coming for kart `kart_id`.
func threatened(kart_id: int) -> bool:
	var k: KartState = race.karts[kart_id]
	for shot in shots:
		if not shot.alive or shot.owner == kart_id:
			continue
		if shot.kind == "drone" and shot.target == kart_id:
			return true
		if shot.kind == "puck":
			var ds := race.track.delta(shot.s, k.s)
			if absf(ds) < 30.0 and absf(shot.d - k.d) < 3.0:
				return true
	return false


# --- The policy (bots, Auto items) ---

## Whether kart `kart_id` should use its held item now. `skill` 0..1: higher skill waits for a
## good moment (a target in range, a straight for the turbo, a threat for the shield); lower
## skill fires sooner and more at random.
func wants_use(kart_id: int, skill: float) -> bool:
	var k: KartState = race.karts[kart_id]
	if k.item == "" or k.roulette_time > 0.0 or k.spin_time > 0.0:
		return false
	var held := _held[kart_id]
	if held < lerpf(HOLD_MIN[0], HOLD_MIN[1], skill):
		return false
	if held > HOLD_MAX:
		return true
	# Careless: now and then just use it.
	if held > lerpf(3.0, 9.0, skill) * (0.5 + _urge[kart_id]):
		return true
	match k.item:
		"turbo":
			return k.surface == KartTrackModel.Surface.OFFROAD or _straight_ahead(k, 40.0)
		"puck":
			return _target_in_lane(k, 4.0, 40.0, 2.2)
		"drone":
			return _ahead_of(k) >= 0
		"goo":
			return _kart_behind(k, 3.0, 25.0, 2.5)
		"shield":
			return threatened(kart_id) or k.place == 1 or held > lerpf(2.0, 5.0, skill)
		"magnet":
			var t := _ahead_of(k)
			if t < 0:
				return false
			var gap := race.progress(t) - race.progress(kart_id)
			return gap > 8.0 and gap < 60.0
	return true


func _straight_ahead(k: KartState, metres: float) -> bool:
	var s := k.s
	var step := 8.0
	var x := 0.0
	while x <= metres:
		if absf(race.track.curvature(race.track.wrap(s + x))) > 0.012:
			return false
		x += step
	return true


func _target_in_lane(k: KartState, near: float, far: float, lane: float) -> bool:
	for o: KartState in race.karts:
		if o.id == k.id or o.finished:
			continue
		var ds := race.track.delta(k.s, o.s)
		if ds > near and ds < far and absf(o.d - k.d) < lane:
			return true
	return false


func _kart_behind(k: KartState, near: float, far: float, lane: float) -> bool:
	for o: KartState in race.karts:
		if o.id == k.id or o.finished:
			continue
		var ds := race.track.delta(o.s, k.s)
		if ds > near and ds < far and absf(o.d - k.d) < lane:
			return true
	return false


func _compact() -> void:
	if shots.size() > 16:
		shots.assign(shots.filter(func(x: Shot) -> bool: return x.alive))
	if goos.size() > GOO_MAX * 2:
		goos.assign(goos.filter(func(x: Goo) -> bool: return x.alive))
