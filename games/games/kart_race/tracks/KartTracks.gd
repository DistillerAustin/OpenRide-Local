class_name KartTracks
extends RefCounted
## The cup's tracks, by id (#43). A track is a script under tracks/ whose static `build()`
## returns its `KartTrackDef` (CUP order is the Grand Prix's order). Each has its own theme
## (KartLook) and runs reversed too.

const CUP := ["meadow_ring", "canyon_dash", "harbor_lights", "frost_pass"]
const SCRIPTS := {
	"meadow_ring": "res://games/kart_race/tracks/meadow_ring.gd",
	"canyon_dash": "res://games/kart_race/tracks/canyon_dash.gd",
	"harbor_lights": "res://games/kart_race/tracks/harbor_lights.gd",
	"frost_pass": "res://games/kart_race/tracks/frost_pass.gd",
}

static var _lengths := {}
static var _titles: Array = []
## Developer aid (KartRace's tuning file, [world] track=...): every race is this track instead.
static var dev_track := ""


static func build(track_id: String) -> KartTrackDef:
	if dev_track != "" and SCRIPTS.has(dev_track):
		track_id = dev_track
	var path: String = SCRIPTS.get(track_id, SCRIPTS[CUP[0]])
	return load(path).build()


## The cup's track titles, CUP order (the Starting track option's labels).
static func titles() -> Array:
	if _titles.is_empty():
		for id in CUP:
			_titles.append(load(SCRIPTS[id]).build().title)
	return _titles.duplicate()


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
