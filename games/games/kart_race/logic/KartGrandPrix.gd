class_name KartGrandPrix
extends RefCounted
## A Grand Prix (#43, DESIGN.md "Grand Prix"): back-to-back races on the cup's tracks, standings
## points carried over. A timed GP picks its final race by the time left, so the ride lands near
## the chosen length; an open-ended one runs 3-lap races until the rider ends the session.
##
## - Before each race, `next_race(time_left, est_lap)`: when the time left is under 1.5 × an
##   estimated race (3 laps + RACE_OVERHEAD_SEC), this is the final race, with
##   clamp(round(time_left / est_lap), 1, 5) laps. Otherwise a normal 3-lap race.
## - Tracks go in cup order; the second time round they're reversed, then forward again.
## - Points per place: POINTS. Ties go to the better place in the last race.

const POINTS := [15, 12, 10, 8, 6, 4, 2, 1]
const NORMAL_LAPS := 3
const MAX_LAPS := 5
## The fly-over, countdown, results board and finishing spread around each race's laps, seconds.
const RACE_OVERHEAD_SEC := 25.0
## A race is the last when the time left is under this many estimated races.
const FINAL_FACTOR := 1.5
## The estimated lap assumes this share of FTP.
const EST_FTP_SHARE := 0.6

var duration_sec := -1.0  ## -1 = open-ended
var track_ids: Array = []
var racer_count := 8
var results: Array = []  ## each race's finishing order (kart ids), in order

var _index := 0
var _points := {}  ## kart_id -> points
var _wins := {}  ## kart_id -> wins


func _init(duration: float, tracks: Array, racers := 8) -> void:
	duration_sec = duration
	track_ids = tracks.duplicate()
	racer_count = racers
	for id in racer_count:
		_points[id] = 0
		_wins[id] = 0


## The cup in its usual order, starting at `first` (the picker's starting track): the others
## follow round it. An unknown id leaves the order as it is.
static func cup_from(tracks: Array, first: String) -> Array:
	var i := tracks.find(first)
	if i <= 0:
		return tracks.duplicate()
	return tracks.slice(i) + tracks.slice(0, i)


## The estimated lap time, seconds: the track's length at the kart speed EST_FTP_SHARE of FTP
## holds on the flat.
static func estimate_lap_sec(track_length: float, ftp_w: float) -> float:
	var v := KartPhysics.steady_bike_speed(EST_FTP_SHARE * maxf(ftp_w, 1.0), 0.0) * KartPhysics.SPEED_SCALE
	return track_length / maxf(v, 0.5)


## The next race: {track_id, reversed, laps, is_final, index}. Call it once per race.
## `time_left_sec` < 0 means open-ended.
func next_race(time_left_sec: float, est_lap_sec: float) -> Dictionary:
	var index := _index
	_index += 1
	var n := maxi(1, track_ids.size())
	var race := {
		"track_id": track_ids[index % n] if not track_ids.is_empty() else "",
		"reversed": (index / n) % 2 == 1,
		"laps": NORMAL_LAPS,
		"is_final": false,
		"index": index,
	}
	if duration_sec >= 0.0 and time_left_sec >= 0.0:
		var est_race := NORMAL_LAPS * est_lap_sec + RACE_OVERHEAD_SEC
		if time_left_sec < FINAL_FACTOR * est_race:
			race.is_final = true
			race.laps = clampi(roundi(time_left_sec / maxf(est_lap_sec, 1.0)), 1, MAX_LAPS)
	return race


## Scores a race's finishing order (kart ids, first to last).
func record(order: Array) -> void:
	results.append(order.duplicate())
	for i in order.size():
		var id := int(order[i])
		_points[id] = int(_points.get(id, 0)) + (POINTS[i] if i < POINTS.size() else 0)
		if i == 0:
			_wins[id] = int(_wins.get(id, 0)) + 1


func races_run() -> int:
	return results.size()


## [{kart_id, points, wins, best_place_last}], best first. `best_place_last` is the kart's place
## in the last race (0 before any), which breaks ties.
func standings() -> Array:
	var last: Array = results.back() if not results.is_empty() else []
	var rows := []
	for id in _points:
		var place := last.find(id) + 1
		rows.append({"kart_id": id, "points": _points[id], "wins": _wins.get(id, 0),
			"best_place_last": place if place > 0 else racer_count + 1})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.points != b.points:
			return a.points > b.points
		if a.best_place_last != b.best_place_last:
			return a.best_place_last < b.best_place_last
		return a.kart_id < b.kart_id)
	return rows


func champion() -> int:
	return int(standings()[0].kart_id)


## A kart's 1-based place in the standings.
func place_of(kart_id: int) -> int:
	var table := standings()
	for i in table.size():
		if int(table[i].kart_id) == kart_id:
			return i + 1
	return 0
