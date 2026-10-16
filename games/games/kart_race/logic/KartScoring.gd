class_name KartScoring
extends RefCounted
## The rider's score and result stats over a Grand Prix (#43, DESIGN.md "Scoring"). It listens to
## each race's events and asks the scene to award points (`awarded`, which the scene passes to
## `Game.award`, so the effort multiplier applies).
##
## Live awards: an overtake +15 (a place better than any reached so far this race: being passed
## and passing back pays nothing), a mini-turbo +10/20/35 by tier (at most one per
## MINI_TURBO_GAP_SEC, so wiggling on a straight doesn't farm), an item hit +25, a lap +30; at
## each finish the race's points × 20.
##
## Stars are per minute of play (`STAR_THRESHOLDS`, KartRace's `info()`), tuned in simulation
## with the merged physics, bots and items: a bot-driven rider against each difficulty's field,
## one 3-lap race plus the 14.5 s around it, 3 seeds a point (tests/unit/kart_scoring_test.gd
## checks Meadow Ring). Re-validated in polish pass 3, when every track gained corners that pay a
## tier-2 or tier-3 mini-turbo: the cup's average barely moved (standard mid-pack 141 → 138,
## winning 240 → 237), but Meadow Ring, the old calibration track, rose from 114 to 141 (it had
## no drift corners before), and the cup average had always sat above the old Meadow-based
## thresholds. Points a minute at 1.0× now:
##
## | field    | mid-pack (4th-5th)          | podium (1st-2nd at 75% FTP) | winning at 1.0×   |
## | easy     | (0.6 FTP places 2nd: 163-214) | 163-214                   | Meadow 226-253, Harbor 248-271 |
## | standard | Meadow 138-147, cup 110-196 | Meadow 179-181, cup 177-218 | Meadow 224-257, cup 200-277 |
## | hard     | (0.6 FTP places 5th-7th: 104-182) | -                     | Meadow 205-246, Harbor 255-282 |
##
## So a mid-pack ride earns one star, a podium ride two, and three take podiums plus effort
## (the effort multiplier is up to 1.5×): a win at 1.0× stays under the third star (unless far
## above the field), a strong podium at full effort clears it. Provisional until the bike.

signal awarded(points: float, reason: String)

const OVERTAKE := 15.0
const MINI_TURBO := [10.0, 20.0, 35.0]
const ITEM_HIT := 25.0
const LAP := 30.0
const RACE_POINT := 20.0
const GHOST_MAX_POINTS := 3600
## A second mini-turbo inside this many seconds of the last scored one scores nothing.
const MINI_TURBO_GAP_SEC := 4.0
## Points per minute for one, two and three stars, by difficulty.
const STAR_THRESHOLDS := {
	"easy": [80, 140, 275],
	"standard": [90, 155, 270],
	"hard": [100, 165, 300],
}

var rider_id := 0
var boosts := 0
var items_hit := 0
var overtakes := 0
var laps := 0
var best_lap := 0.0  ## seconds, 0 before the first lap
var race_time := 0.0  ## seconds racing (GO to the rider's finish), all races
## The rider's distance (metres) every `ghost_interval` seconds of racing, at most
## GHOST_MAX_POINTS long (halved in resolution when it fills).
var ghost_trace: Array[int] = []
var ghost_interval := 1.0

var _race: KartRaceLogic
var _best_place := 99
var _power_sum := 0.0
var _power_time := 0.0
var _distance := 0.0
var _last_progress := 0.0
var _ghost_clock := 0.0
var _clock := 0.0  ## seconds stepped, for the mini-turbo gap
var _last_turbo_award := -INF


func begin_race(race: KartRaceLogic) -> void:
	_race = race
	_best_place = race.place_of(rider_id)
	_last_progress = race.progress(rider_id)
	var ev := race.events
	ev.lap_completed.connect(_on_lap)
	ev.position_changed.connect(_on_position)
	ev.boost_started.connect(_on_boost)
	ev.kart_hit.connect(_on_hit)
	ev.race_finished.connect(_on_race_finished)


## One fixed step while the race runs (the scene calls it with the rider's watts).
func step(dt: float, power_w: float) -> void:
	_clock += dt
	if _race == null or _race.phase != KartRaceLogic.Phase.RACING:
		return
	race_time += dt
	_power_sum += power_w * dt
	_power_time += dt
	var now := _race.progress(rider_id)
	_distance += maxf(0.0, now - _last_progress)
	_last_progress = now
	_ghost_clock += dt
	if _ghost_clock >= ghost_interval:
		_ghost_clock -= ghost_interval
		ghost_trace.append(roundi(_distance))
		if ghost_trace.size() > GHOST_MAX_POINTS:
			var halved: Array[int] = []
			for i in range(0, ghost_trace.size(), 2):
				halved.append(ghost_trace[i])
			ghost_trace = halved
			ghost_interval *= 2.0


func avg_power() -> float:
	return _power_sum / _power_time if _power_time > 0.0 else 0.0


## The result's stats (docs: spec "Scoring and result").
func stats(gp: KartGrandPrix) -> Dictionary:
	var wins := 0
	var podiums := 0
	for order in gp.results:
		var place: int = order.find(rider_id) + 1
		if place == 1:
			wins += 1
		if place >= 1 and place <= 3:
			podiums += 1
	var position := gp.place_of(rider_id) if gp.races_run() > 0 else (_race.place_of(rider_id) if _race else 0)
	return {
		"position": position,
		"races": gp.races_run(),
		"wins": wins,
		"podiums": podiums,
		"best_lap": snappedf(best_lap, 0.01),
		"race_time": roundi(race_time),
		"boosts": boosts,
		"items_hit": items_hit,
		"avg_power": roundi(avg_power()),
		"ghost_trace": ghost_trace.duplicate(),
	}


func _on_lap(kart_id: int, _lap: int, lap_time: float) -> void:
	if kart_id != rider_id:
		return
	laps += 1
	best_lap = lap_time if best_lap <= 0.0 else minf(best_lap, lap_time)
	awarded.emit(LAP, "lap")


func _on_position(kart_id: int, _old: int, new_place: int) -> void:
	if kart_id != rider_id or new_place >= _best_place:
		return
	var gained := _best_place - new_place
	_best_place = new_place
	if _race and _race.phase == KartRaceLogic.Phase.RACING:
		overtakes += gained
		awarded.emit(OVERTAKE * gained, "overtake")


func _on_boost(kart_id: int, kind: String, tier: int) -> void:
	if kart_id != rider_id:
		return
	boosts += 1
	if kind == "drift" and tier >= 1 and _clock - _last_turbo_award >= MINI_TURBO_GAP_SEC - 0.0001:
		_last_turbo_award = _clock
		awarded.emit(MINI_TURBO[mini(tier, 3) - 1], "mini_turbo")


func _on_hit(_kart_id: int, by_id: int, _item: String) -> void:
	if by_id != rider_id:
		return
	items_hit += 1
	awarded.emit(ITEM_HIT, "item_hit")


func _on_race_finished(order: Array) -> void:
	var place := order.find(rider_id)
	if place >= 0 and place < KartGrandPrix.POINTS.size():
		awarded.emit(KartGrandPrix.POINTS[place] * RACE_POINT, "race")
