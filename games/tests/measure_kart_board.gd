extends SceneTree
## The results board's and the podium's draw calls on the desktop counter (#43, the tablet
## budget); needs a window:
##   $GODOT_BIN --path games -s res://tests/measure_kart_board.gd
## Each board's first 150 frames are traced too: the bakes take turns (KartBakeQueue), so no
## frame should draw more than about 30 calls for the board (90 with the race behind it).
## KartRaceBoard over an empty screen (a hidden KartHud renders the portraits). Each board is
## shown with eight rows, given 2 s to settle (rows slid in, the podium risen), then measured
## for 300 frames against the same frames with the board hidden:
## `MEASURE kart_board results=… podium=…`.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame  # the autoloads are in by now
	var hud = load("res://games/kart_race/ui/KartHud.gd").new()  # untyped: compiled before the autoloads
	root.add_child(hud)
	var lineup := KartRoster.lineup(KartRoster.ids()[0], 8)
	hud.setup(lineup, KartTrackModel.new(load("res://tests/kart_fixtures.gd").meadow()))
	hud.visible = false
	var board := KartRaceBoard.new()
	board.portrait_maker = hud.portrait_rect
	root.add_child(board)
	var rows := []
	for i in 8:
		rows.append({"name": str(lineup[i].name), "detail": "+%d" % KartGrandPrix.POINTS[i], "points": "%d pts" % (40 - i * 4),
			"total": "%d pts" % (40 - i * 4), "racer_id": str(lineup[i].id), "you": i == 2,
			"time": KartTheme.race_time(102.3) if i == 0 else KartTheme.race_gap(i * 1.37)})
	await create_timer(0.5).timeout  # the HUD's portrait atlas renders first
	var out := {}
	for which in ["results", "podium"]:
		if which == "results":
			board.show_board("On the podium!", rows, "Grand Prix · Race 1 · Meadow Ring", 30.0, "Next race")
		else:
			board.show_podium("Grand Prix podium!", rows, "Final standings · 4 races", 30.0, "Ride summary")
		var trace := await _trace(150)
		print("MEASURE kart_board %s first frames: peak %d, frames over 90: %d, trace %s" % [which, trace.max(), trace.filter(func(v): return v > 90).size(), trace.slice(0, 40)])
		var shown := await _mean()
		board.visible = false
		var hidden := await _mean()
		board.visible = true
		out[which] = shown - hidden
		print("MEASURE kart_board %s: shown %.1f, hidden %.1f, renders %d" % [which, shown, hidden, _renders(board)])
	print("MEASURE kart_board results=%.1f podium=%.1f (draw calls, mean of 300 frames)" % [out.results, out.podium])
	quit()


## Draw calls in each of the next `frames` frames (the bakes' first renders, the slide-ins).
func _trace(frames: int) -> Array:
	var out := []
	for f in frames:
		await process_frame
		out.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	return out


func _mean() -> float:
	var total := 0.0
	for f in 300:
		await process_frame
		total += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	return total / 300.0


## Bake renders over the board's lifetime (0 before baking), to see the bakes settle.
func _renders(n: Node) -> int:
	var count := 0
	if n is KartBaked:
		count += (n as KartBaked).renders
	for c in n.get_children():
		count += _renders(c)
	return count
