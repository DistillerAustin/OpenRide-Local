class_name KartRaceLogic
extends RefCounted
## One race (#43, DESIGN.md "Race logic"): the grid, the countdown, the fixed-step simulation of
## every kart, laps, positions and the finish. Plain logic: the scene steps it at 60 Hz with one
## `KartInput` per kart and draws `karts`; everything that happens goes out through `events`.
##
## Phases (enum FSM): GRID (lined up, nothing moves) → COUNTDOWN (inputs ignored) → RACING →
## FINISHED (the rider crossed the line for the last time; karts drive on, nothing changes).
##
## Laps: a kart's `lap` counts its start-line crossings (0 on the grid, 1 on the first lap,
## laps + 1 at the finish), up on a forward wrap of s and down on a backward one, so
## `progress = lap × length + s` is continuous and wrong-way driving can't gain anything. Lap
## events fire only when a kart reaches a lap it has never reached before.

enum Phase { GRID, COUNTDOWN, RACING, FINISHED }

const RIDER := 0
## The grid: staggered slots, alternately left and right, each GRID_GAP further back.
const GRID_FIRST := 6.0
const GRID_GAP := 4.5
const GRID_D := 2.5
## A kart still running when the race ends is timed as if it kept at least this speed.
const PROJECT_MIN_SPEED := 3.0

var events := KartRaceEvents.new()
var physics := KartPhysics.new()
var track: KartTrackModel
var karts: Array = []  ## Array[KartState]; index == id; 0 is the rider
var laps := 3
var phase := Phase.GRID
var time := 0.0  ## race seconds since GO
var countdown := 0.0  ## seconds left in the countdown

var _best_lap: Array[int] = []  ## the highest lap each kart has reached
var _lap_start: Array[float] = []  ## race time each kart's current lap began
var _finish_order: Array[int] = []
var _idle := KartInput.new()
var _progress_scratch := PackedFloat64Array()  ## order(): the running karts' progress


func _init() -> void:
	physics.events = events


## Lines the karts up. racers: [{racer_id, weight, grid?}], index = kart id (0 is the rider).
## `grid` (0 = pole) is optional: by default the bots fill the grid in id order and the rider
## starts at the back.
func setup(track_model: KartTrackModel, racers: Array, race_laps: int) -> void:
	track = track_model
	laps = maxi(1, race_laps)
	phase = Phase.GRID
	time = 0.0
	countdown = 0.0
	karts = []
	_best_lap = []
	_lap_start = []
	_finish_order = []
	var n := racers.size()
	for id in n:
		var r: Dictionary = racers[id]
		var k := KartState.new()
		k.id = id
		k.racer_id = str(r.get("racer_id", "racer%d" % id))
		k.weight = float(r.get("weight", 1.0))
		var slot := int(r.get("grid", n - 1 if id == RIDER else id - 1))
		var s := track.wrap(-(GRID_FIRST + GRID_GAP * slot))
		var d := -GRID_D if slot % 2 == 0 else GRID_D
		var p := track.project(track.position_at(s, d), s)
		k.pos = p.position
		k.s = p.s
		k.d = p.d
		k.normal = p.normal
		k.surface = track.surface(p.s, p.d)
		k.heading = track.yaw_at(p.s)
		k.snap()
		karts.append(k)
		_best_lap.append(0)
		_lap_start.append(0.0)
	var start_order := order()
	for i in start_order.size():
		karts[start_order[i]].place = i + 1


func start_countdown(seconds := 3.0) -> void:
	phase = Phase.COUNTDOWN
	countdown = seconds


## One fixed step. `inputs[id]` drives kart id (missing inputs coast). Inputs are ignored on the
## grid and during the countdown.
func step(dt: float, inputs: Array) -> void:
	for k: KartState in karts:
		k.snap()  # the pose this tick starts from, for drawing between ticks
	match phase:
		Phase.GRID:
			return
		Phase.COUNTDOWN:
			# Handling hook (Phase 2): the karts stay put, but the rocket start reads the cadence.
			for k: KartState in karts:
				physics.countdown_step(k, _input_of(k, inputs), countdown, dt)
			countdown -= dt
			if countdown <= 0.0:
				countdown = 0.0
				phase = Phase.RACING
				time = 0.0
				events.race_started.emit()
				for k: KartState in karts:
					physics.launch(k)  # handling hook: rocket starts
			return
	time += dt
	KartPhysics.update_drafts(karts)  # handling hook: who's in whose slipstream this tick
	for k: KartState in karts:
		var prev_s := k.s
		physics.step(k, _input_of(k, inputs), track, dt)
		if phase == Phase.RACING and not k.finished:
			_check_line(k, prev_s, dt)
	for hit in KartPhysics.resolve_contacts(karts):
		events.kart_bump.emit(int(hit[0]), int(hit[1]), float(hit[2]))
	if phase == Phase.RACING:
		_update_places()


func _input_of(k: KartState, inputs: Array) -> KartInput:
	return inputs[k.id] if k.id < inputs.size() and inputs[k.id] != null else _idle


## Kart ids by race position: finishers in finishing order, then the rest by progress.
func order() -> Array:
	# Running karts by progress (ties by id): an insertion sort over at most eight, on progress
	# read once each (the HUD asks every frame, the places every tick; no comparator calls).
	var ids := []
	ids.append_array(_finish_order)
	var first := ids.size()
	var length := track.length
	_progress_scratch.clear()
	for k: KartState in karts:
		if k.finished:
			continue
		var p := k.lap * length + k.s
		var at := ids.size()
		while at > first:
			var q := _progress_scratch[at - 1 - first]
			if q > p or (q == p and ids[at - 1] < k.id):
				break
			at -= 1
		ids.insert(at, k.id)
		_progress_scratch.insert(at - first, p)
	return ids


## 1-based race position.
func place_of(kart_id: int) -> int:
	return order().find(kart_id) + 1


## Distance covered from the start line, metres: lap × length + s.
func progress(kart_id: int) -> float:
	var k: KartState = karts[kart_id]
	return k.lap * track.length + k.s


## The race distance: from the line on lap 1 to the finish.
func race_length() -> float:
	return laps * track.length


func _check_line(k: KartState, prev_s: float, dt: float) -> void:
	var moved := track.delta(prev_s, k.s)
	if prev_s + moved < 0.0:
		k.lap -= 1  # backwards over the line
		return
	if prev_s + moved < track.length:
		return
	k.lap += 1
	if k.lap <= _best_lap[k.id]:
		return  # back over the line after reversing over it: nothing new
	_best_lap[k.id] = k.lap
	var crossed := time - dt + dt * clampf((track.length - prev_s) / maxf(moved, 0.0001), 0.0, 1.0)
	if k.lap >= 2:
		events.lap_completed.emit(k.id, k.lap - 1, crossed - _lap_start[k.id])
		_lap_start[k.id] = crossed
	if k.lap == laps:
		events.final_lap.emit(k.id)
	if k.lap > laps:
		_finish(k, crossed)


func _finish(k: KartState, at: float) -> void:
	k.finished = true
	k.finish_time = at
	_finish_order.append(k.id)
	k.place = _finish_order.size()
	events.kart_finished.emit(k.id, k.place, at)
	if k.id == RIDER:
		_end_race()


## The rider is home: everyone still running is placed by progress, timed as if they kept going.
func _end_race() -> void:
	var last := time
	for id in order():
		var k: KartState = karts[id]
		if k.finished:
			last = maxf(last, k.finish_time)
			continue
		var left := maxf(0.0, (laps + 1) * track.length - progress(id))
		var projected := maxf(time + left / maxf(k.speed, PROJECT_MIN_SPEED), last + 0.01)
		k.finished = true
		k.finish_time = projected
		_finish_order.append(id)
		k.place = _finish_order.size()
		events.kart_finished.emit(id, k.place, projected)
		last = projected
	phase = Phase.FINISHED
	_update_places()
	events.race_finished.emit(order())


func _update_places() -> void:
	var now := order()
	for i in now.size():
		var k: KartState = karts[now[i]]
		var place := i + 1
		if k.place != place:
			var old := k.place
			k.place = place
			if old != 0:
				events.position_changed.emit(k.id, old, place)
