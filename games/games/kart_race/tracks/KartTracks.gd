class_name KartTracks
extends RefCounted
## The cup's tracks, by id (#43). A track is a script under tracks/ whose static `build()`
## returns its `KartTrackDef`. The world agent adds Canyon Dash, Harbor Lights and Frost Pass
## here (CUP order is the Grand Prix's order).

const CUP := ["meadow_ring"]
const SCRIPTS := {
	"meadow_ring": "res://games/kart_race/tracks/meadow_ring.gd",
}

static var _lengths := {}


static func build(track_id: String) -> KartTrackDef:
	var path: String = SCRIPTS.get(track_id, SCRIPTS[CUP[0]])
	return load(path).build()


## The track's centre-line length, metres (cached: baking a model takes a few milliseconds).
static func length_of(track_id: String) -> float:
	if not _lengths.has(track_id):
		_lengths[track_id] = KartTrackModel.new(build(track_id)).length
	return _lengths[track_id]


## The cup's average lap length, for estimating race times before the track is known.
static func average_length() -> float:
	var total := 0.0
	for id in CUP:
		total += length_of(id)
	return total / CUP.size()
