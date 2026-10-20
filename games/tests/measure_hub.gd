extends SceneTree
## The hub's cost on the desktop (spec §8.4): per screen, the draw calls of an idle frame, the
## bakes rendered over 60 idle frames (the target is none), the canvas items and the frame
## rate under the hub's 30 fps cap. The budget: the home screen at 25 draw calls or fewer and
## no bake rendering on an idle frame. Needs a window (draw calls aren't counted headless):
##   $GODOT_BIN --path games --resolution 1920x1080 -s res://tests/measure_hub.gd
## Prints one MEASURE line per screen and PASS or FAIL.

const HOME_BUDGET := 25
const IDLE_FRAMES := 60

var _session: Node
var _ok := true


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_session = root.get_node("Session")
	var local: Node = _session._local
	change_scene_to_file("res://hub/Hub.tscn")
	await process_frame
	await process_frame
	local.hub.begin_visit()
	var hub: Node = current_scene
	await _measure(hub, "home (FTP nudge)", HOME_BUDGET)
	local.hub.rider.ftp_is_default = false
	local.hub.send_state()
	await _measure(hub, "home", HOME_BUDGET)
	for screen in [["game", {"game_id": "kart_race"}], ["game", {"game_id": "dodge_ball"}],
			["game", {"game_id": "tug_of_war"}], ["game", {"game_id": "safe_cracker"}],
			["game", {"game_id": "cadence_karaoke"}], ["circuit", {"circuit_id": "circuit-30"}], ["settings", {}]]:
		hub.nav.push(screen[0], screen[1])
		await _measure(hub, "%s %s" % [screen[0], screen[1].values()], -1)
		if screen[0] == "game" and hub.screen.more_button:  # More options over the left column
			hub.screen.open_more()
			await _measure(hub, "%s %s more options" % [screen[0], screen[1].values()], -1)
			hub.screen.close_more()
		hub.nav.pop()
	print("PASS measure hub" if _ok else "FAIL measure hub")
	quit(0 if _ok else 1)


func _measure(hub: Node, what: String, budget: int) -> void:
	await create_timer(2.0).timeout  # every bake has rendered
	var bakes := hub.find_children("*", "TextureRect", true, false).filter(func(n): return n is BakedView)
	var before := _renders(bakes)
	var calls_max := 0
	var t0 := Time.get_ticks_usec()
	for i in IDLE_FRAMES:
		await process_frame
		calls_max = maxi(calls_max, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	var fps := IDLE_FRAMES / ((Time.get_ticks_usec() - t0) / 1e6)
	var renders := _renders(bakes) - before
	print("MEASURE %s: draw_calls=%d bake_renders_idle=%d bakes=%d canvas_items=%d fps=%.1f" % [what, calls_max,
		renders, bakes.size(), int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)), fps])
	if (budget > 0 and calls_max > budget) or renders > 0:
		_ok = false


func _renders(bakes: Array) -> int:
	var total := 0
	for b in bakes:
		total += (b as BakedView).renders
	return total
