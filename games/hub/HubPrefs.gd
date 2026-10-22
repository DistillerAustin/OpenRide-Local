class_name HubPrefs
extends RefCounted
## The hub's own picks per rider (spec §7.3): the last mode, length and difficulty per game,
## the last difficulty per circuit, and up to CUSTOM_MAX saved custom circuits. Presentation only: app settings stay in Kotlin.
## Stored next to GameOptions in `user://hub_prefs.cfg`, section `<rider>/hub`, with GameOptions'
## rider rule ("guest" without an active rider).

const DEFAULT_PATH := "user://hub_prefs.cfg"
const DIFFICULTIES := ["easy", "standard", "hard"]
## Saved custom circuits per rider (spec §7.3).
const CUSTOM_MAX := 3

## Tests point this elsewhere.
static var path := DEFAULT_PATH

static var _file: ConfigFile
static var _loaded_path := ""


## The hub's rider: hub_state's `rider.id`, or "guest".
static func rider(state: Dictionary) -> String:
	var id = state.get("rider", {}).get("id")
	return "guest" if id == null else str(id).trim_suffix(".0")


static func get_pick(rider_id: String, key: String, default: Variant) -> Variant:
	return _config().get_value(_section(rider_id), key, default)


static func set_pick(rider_id: String, key: String, value: Variant) -> void:
	var config := _config()
	if config.has_section_key(_section(rider_id), key) and config.get_value(_section(rider_id), key) == value:
		return
	config.set_value(_section(rider_id), key, value)
	var err := config.save(path)
	if err != OK:
		push_warning("HubPrefs: can't save %s (%d)" % [path, err])


## A game's Just Ride pick, defaulted from its catalog entry: {mode, length, difficulty}.
## The mode is one it supports (minutes first); the length is one of its steps (minutes) or
## within its rounds; the difficulty "standard".
static func game_pick(rider_id: String, entry: Dictionary) -> Dictionary:
	var id := str(entry.get("id", ""))
	var supports: Array = entry.get("supports", ["minutes"])
	var mode := str(get_pick(rider_id, "%s.mode" % id, ""))
	if mode not in supports:
		mode = "minutes" if "minutes" in supports else str(supports[0]) if not supports.is_empty() else "open"
	var length := int(get_pick(rider_id, "%s.%s" % [id, mode], 0))
	length = valid_length(entry, mode, length)
	var difficulty := str(get_pick(rider_id, "%s.difficulty" % id, "standard"))
	if difficulty not in DIFFICULTIES:
		difficulty = "standard"
	return {"mode": mode, "length": length, "difficulty": difficulty}


static func set_game_pick(rider_id: String, game_id: String, pick: Dictionary) -> void:
	set_pick(rider_id, "%s.mode" % game_id, pick.mode)
	if pick.mode != "open":
		set_pick(rider_id, "%s.%s" % [game_id, pick.mode], int(pick.length))
	set_pick(rider_id, "%s.difficulty" % game_id, pick.difficulty)


## `length` made valid for the mode: a minute step (the nearest, 10 min or the first step by
## default) or a round count within the game's limits (3 by default); 0 for open.
static func valid_length(entry: Dictionary, mode: String, length: int) -> int:
	match mode:
		"minutes":
			var steps: Array = entry.get("minute_steps", [10])
			if steps.is_empty():
				return maxi(1, int(entry.get("min_sec", 600)) / 60)
			var want := length if length > 0 else 10
			var best := int(steps[0])
			for s in steps:
				if absi(int(s) - want) < absi(best - want):
					best = int(s)
			return best
		"rounds":
			var lo := int(entry.get("min_rounds", 1))
			var hi := int(entry.get("max_rounds", 10))
			return clampi(length if length > 0 else 3, lo, hi)
	return 0


static func circuit_difficulty(rider_id: String, circuit_id: String) -> String:
	var d := str(get_pick(rider_id, "%s.difficulty" % circuit_id, "standard"))
	return d if d in DIFFICULTIES else "standard"


static func set_circuit_difficulty(rider_id: String, circuit_id: String, difficulty: String) -> void:
	set_pick(rider_id, "%s.difficulty" % circuit_id, difficulty)


## The rider's saved custom circuits (spec §8.3): CUSTOM_MAX places, each {v, slots: [{game_id,
## duration_sec}], difficulty} or null (empty). Place n is "My circuit n+1": no keyboard, so no
## names to type. Not in OpenRide's backup (`user://`; accepted by the rider).
static func custom_circuits(rider_id: String) -> Array:
	var out: Array = []
	for i in CUSTOM_MAX:
		var c = get_pick(rider_id, "custom.%d" % (i + 1), {})  # never a null default: ConfigFile errors on one
		out.append(c if c is Dictionary and c.get("slots") is Array and not (c.slots as Array).is_empty() else null)
	return out


static func custom_circuit(rider_id: String, index: int) -> Variant:
	return custom_circuits(rider_id)[index] if index >= 0 and index < CUSTOM_MAX else null


## Saves `circuit` (CircuitBuilder.to_saved) in place `index` (0-based), replacing what's there.
static func save_custom(rider_id: String, index: int, circuit: Dictionary) -> void:
	if index >= 0 and index < CUSTOM_MAX:
		set_pick(rider_id, "custom.%d" % (index + 1), circuit)


static func delete_custom(rider_id: String, index: int) -> void:
	var config := _config()
	var key := "custom.%d" % (index + 1)
	if config.has_section_key(_section(rider_id), key):
		config.erase_section_key(_section(rider_id), key)
		config.save(path)


## The first empty place, or -1 when all CUSTOM_MAX are taken (Save then asks which to replace).
static func free_custom(rider_id: String) -> int:
	return custom_circuits(rider_id).find(null)


static func custom_name(index: int) -> String:
	return "My circuit %d" % (index + 1)


## Forgets everything stored for `rider_id` (tests clean up with this).
static func forget_rider(rider_id: String) -> void:
	var config := _config()
	if config.has_section(_section(rider_id)):
		config.erase_section(_section(rider_id))
		config.save(path)


static func reload() -> void:
	_file = null


static func _section(rider_id: String) -> String:
	return "%s/hub" % rider_id


static func _config() -> ConfigFile:
	if _file == null or _loaded_path != path:
		_file = ConfigFile.new()
		_loaded_path = path
		if FileAccess.file_exists(path):
			_file.load(path)
	return _file
