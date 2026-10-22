class_name LoadClock
extends RefCounted
## Load-time marks for the tablet log (the rider's "first launch / starting a game takes too
## long", 2026-10-20): `OPENRIDE_GAMES <kind> <label> t=<ms since engine start> +<ms since the
## kind's previous mark>`. Kinds: `boot` (engine start to the hub's first frame) and `start`
## (start_plan to a playable game). Also logs any frame longer than HITCH_MSEC as
## `OPENRIDE_GAMES hitch ms=… where=…` (SessionDirector calls `frame()` every frame).
##
## Read on the bike: adb logcat -s godot | grep -E "OPENRIDE_GAMES (boot|start|hitch)"

const HITCH_MSEC := 250

static var _last := {}  # kind -> ticks msec of its previous mark
static var _frame_usec := 0


## Prints a mark and returns the milliseconds since the kind's previous one (0 for its first).
static func mark(kind: String, label: String) -> int:
	var now := Time.get_ticks_msec()
	var since: int = now - int(_last.get(kind, now))
	_last[kind] = now
	print("OPENRIDE_GAMES %s %s t=%d +%d" % [kind, label, now, since])
	return since


## Starts a kind afresh: its next mark measures from now.
static func begin(kind: String, label: String) -> void:
	_last.erase(kind)
	mark(kind, label)


## Call once per frame; logs a long frame (a load, a shader compile on first draw, a mesh build).
static func frame(where: String) -> int:
	var now := Time.get_ticks_usec()
	var ms := 0 if _frame_usec == 0 else int((now - _frame_usec) / 1000)
	_frame_usec = now
	if ms >= HITCH_MSEC:
		print("OPENRIDE_GAMES hitch ms=%d where=%s t=%d" % [ms, where, now / 1000])
	return ms
