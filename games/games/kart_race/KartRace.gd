extends Game
## Kart Race (#43): a Grand Prix of 3-lap races against seven bots. Pedal to drive, lean to
## steer (the head tracker), tap to use items. The contract is games/kart_race/DESIGN.md.
##
## The logic lives in plain classes under logic/ (track space, physics, race, Grand Prix, bots,
## scoring), stepped here at a fixed 60 Hz from `_on_frame`; the nodes only draw it. This scene
## wires it to the framework: declarations, options, the GP flow, inputs, HUD, audio, the result.
##
## Ownership (Phase 2 agents edit only their own builder plus a few lines of wiring):
##   _build_world()   world agent      the track's look (KartWorld)
##   _build_camera()  handling agent   KartChaseCamera
##   _build_racers()  racers agent     KartView per kart (bots: race-systems agent)
##   _build_items()   race-systems     items and their views
##   _build_hud()     presentation     KartStatus, the boards, countdown, banners
##   _build_audio()   presentation     music and effects
##   _build_fx()      presentation     sparks, flames, dust, speed lines
## Each race's logic is announced by `race_began(race)` before its countdown: hook its `events`
## there rather than editing `_begin_race`.
##
## GP flow (enum FSM, `flow`): IDLE (the grid behind the intro card) → COUNTDOWN → RACING →
## RESULTS (8 s, karts drive on) → the next race's COUNTDOWN, or PODIUM after the final race →
## DONE (end_segment). `request_finish` ends at once with the standings so far.

signal race_began(race: KartRaceLogic)

enum Flow { IDLE, COUNTDOWN, RACING, RESULTS, PODIUM, DONE }

## The 3D view renders into a SubViewport at this share of 1080p, drawn scaled under the HUD
## (Dodge Ball's pattern: the tablet's GPU is fill-rate bound; scaling_3d_scale < 1 hangs it).
const RENDER_SCALE := 0.62
const MSAA := Viewport.MSAA_DISABLED  ## 2x halved the frame rate on the tablet (Dodge Ball)
## Developer aid, off in every build: set true to read `user://kart_tuning.cfg` ([render]
## scale, msaa; [world] road, walls, ground, scenery) and log the frame cost every 5 s.
const DEV_TUNING := false
const TUNING_PATH := "user://kart_tuning.cfg"
const PERF_LOG_SEC := 5.0

const TICK := 1.0 / 60.0
const MAX_TICKS := 8  ## per frame, so a stall never snowballs
const RIDER := KartRaceLogic.RIDER
const RACERS := 8
const COUNTDOWN_SEC := 3.0
const RESULTS_SEC := 8.0
const PODIUM_SEC := 6.0
const GO_SEC := 0.8
const DEFAULT_FTP := 150.0
## The bots' shares of the rider's FTP, weakest to strongest, by difficulty (forgiving: rider
## feedback 2026-10-04). Kotlin sends `params.bot_pcts`; these are the fallback.
const BOT_PCTS := {
	"easy": [0.35, 0.60],
	"standard": [0.45, 0.75],
	"hard": [0.55, 0.90],
}
const BOT_LINES := [-1.5, 1.5, -0.5, 0.5, -2.0, 2.0, 0.0]
const ASSIST := {"off": 0.0, "low": 0.5, "high": 1.0}
const MUSIC_STYLE := {"name": "racer", "stem_gates": {"harmony": 0.4, "lead": 0.75}}
const MUSIC_BPM := 90.0

var race: KartRaceLogic
var gp: KartGrandPrix
var scoring: KartScoring
var track: KartTrackModel
var world: KartWorld
var camera: KartChaseCamera
var views: Array[KartView] = []
var bots: Array = []  ## KartBotDriver per kart id; null for the rider
var lineup: Array = []  ## KartRoster entries per kart id
var flow := Flow.IDLE
var current := {}  ## this race: {track_id, reversed, laps, is_final, index}
var ftp_w := DEFAULT_FTP
var sim_time := 0.0  ## seconds simulated this segment
## Tests: the rider's input, instead of InputBus.
var test_input: KartInput = null

var _view: SubViewport
var _status: KartStatus
var _board: KartRaceBoard
var _acc := 0.0
var _flow_left := 0.0
var _est_lap := 60.0
var _built_track := ""
var _rider_input := KartInput.new()
var _item_key := false
var _item_edge := false
var _countdown_shown := -1
var _message_left := 0.0
var _lineup_dirty := false
var _tuning := ConfigFile.new()
var _tuned := false
var _perf_usec := 0
var _perf_frames := 0
var _perf_left := PERF_LOG_SEC


func info() -> GameInfo:
	var i := GameInfo.new()
	i.id = "kart_race"
	i.title = "Kart Race"
	i.how_to = "Pedal to drive · lean to steer · lean hard to drift · tap to use items"
	i.supports = ["minutes", "open"]
	i.min_sec = 300
	i.max_sec = 3600
	i.roles = []
	# Lean steers; standing (reported in every camera mode) is for the climbs.
	i.tracker_mode = "lean_stand"
	i.effort_in_just_ride = true
	i.timed_end_mode = "game"  # a timed GP ends on the final race's finish line
	i.stars_per_minute = true
	# Points a minute. Provisional until the bike: about 1 star mid-pack at 1.0×, 3 stars takes
	# podiums and effort (the race-systems agent tunes these in simulation).
	i.star_thresholds = {
		"easy": [80, 170, 280],
		"standard": [100, 200, 320],
		"hard": [120, 240, 380],
	}
	i.options = [
		{"key": "driver", "label": "Driver", "choices": KartRoster.ids(), "labels": KartRoster.names(),
			"default": "fox"},
		{"key": "assist", "label": "Steering assist", "choices": ["off", "low", "high"],
			"labels": ["Off", "Low", "High"], "default": "high"},
		{"key": "camera", "label": "Camera", "choices": ["chase", "close"],
			"labels": ["Chase", "Close"], "default": "chase"},
		{"key": "auto_items", "label": "Auto items", "choices": ["off", "on"],
			"labels": ["Off", "On"], "default": "off"},
	]
	return i


func target_text(seg: Dictionary) -> String:
	var duration := float(seg.get("duration_sec", -1))
	if duration < 0.0:
		return "Grand Prix · race as long as you like"
	var p: Dictionary = seg.get("params", {})
	var n := planned_races(duration, KartGrandPrix.estimate_lap_sec(KartTracks.average_length(), _ftp_of(p)))
	return "Grand Prix · %d race%s" % [n, "" if n == 1 else "s"]


## How many races a GP of `duration` seconds plans, if each race takes its estimate.
static func planned_races(duration: float, est_lap: float) -> int:
	var plan := KartGrandPrix.new(duration, KartTracks.CUP)
	var left := duration
	var n := 0
	while n < 60:
		var next := plan.next_race(left, est_lap)
		n += 1
		if next.is_final:
			break
		left -= next.laps * est_lap + KartGrandPrix.RACE_OVERHEAD_SEC
	return n


static func _ftp_of(p: Dictionary) -> float:
	var ftp := float(p.get("ftp_watts", DEFAULT_FTP))
	return ftp if ftp > 0.0 else DEFAULT_FTP


func _ready() -> void:
	_tuned = DEV_TUNING and _tuning.load(TUNING_PATH) == OK
	var scale := RENDER_SCALE
	if _tuned:
		scale = clampf(float(_tuning.get_value("render", "scale", RENDER_SCALE)), 0.4, 1.0)
	_view = SubViewport.new()
	_view.name = "View3D"
	_view.size = Vector2i(roundi(HudTheme.W * scale), roundi(HudTheme.H * scale))
	_view.msaa_3d = int(_tuning.get_value("render", "msaa", MSAA)) if _tuned else MSAA
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_view.audio_listener_enable_3d = false
	add_child(_view)
	var shown := TextureRect.new()
	shown.name = "View3DImage"
	shown.texture = _view.get_texture()
	shown.size = Vector2(HudTheme.W, HudTheme.H)
	shown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shown.stretch_mode = TextureRect.STRETCH_SCALE
	shown.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	shown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shown)
	if _tuned:
		print("OPENRIDE_GAMES kart_race render scale=%.2f size=%s msaa=%d" % [scale, _view.size, _view.msaa_3d])


func _on_prepare(seg: Dictionary) -> void:
	ftp_w = _ftp_of(params)
	flow = Flow.IDLE
	sim_time = 0.0
	_acc = 0.0
	_built_track = ""
	gp = KartGrandPrix.new(float(seg.get("duration_sec", -1)), KartTracks.CUP, RACERS)
	scoring = KartScoring.new()
	scoring.rider_id = RIDER
	scoring.awarded.connect(func(points: float, _why: String): award(points))
	lineup = KartRoster.lineup(option("driver"), RACERS)
	_est_lap = KartGrandPrix.estimate_lap_sec(KartTracks.average_length(), ftp_w)
	_build_world()
	_build_camera()
	_build_racers()
	_build_items()
	_build_hud()
	_build_audio()
	_build_fx()
	# The first race's grid shows behind the intro card.
	_begin_race()
	stats = scoring.stats(gp)


func _on_start() -> void:
	_start_countdown()


func _on_option_changed(key: String, _value: String) -> void:
	match key:
		"assist":
			if race:
				race.physics.assist = ASSIST.get(option("assist"), 1.0)
		"camera":
			if camera:
				camera.mode = option("camera")
		"driver":
			_lineup_dirty = true
			if playing:
				_show_message("New driver from the next race", 2.0)


func _on_finish_requested() -> void:
	# The race in progress counts as it stands.
	if race and race.phase == KartRaceLogic.Phase.RACING and flow == Flow.RACING:
		gp.record(race.order())
	_finish_gp()


# --- Builders: one per Phase 2 agent ---

## World agent: the 3D world for the track (KartWorld builds per track in `_begin_race`).
func _build_world() -> void:
	world = KartWorld.new()
	world.name = "World"
	if _tuned and _tuning.has_section("world"):
		for key in _tuning.get_section_keys("world"):
			world.tuning[key] = bool(_tuning.get_value("world", key))
	_view.add_child(world)


## Handling agent: the chase camera (Chase / Close option).
func _build_camera() -> void:
	camera = KartChaseCamera.new()
	camera.name = "ChaseCamera"
	camera.mode = option("camera")
	world.add_child(camera)
	camera.current = true


## Racers agent (views) and race-systems agent (bots): a KartView per kart, a KartBotDriver per
## bot. Kart id = index in `lineup`; 0 is the rider.
func _build_racers() -> void:
	for v in views:
		v.queue_free()
	views = []
	for i in lineup.size():
		var v := KartView.new()
		v.setup(lineup[i])
		world.add_child(v)
		views.append(v)
	var pcts := _bot_pcts()
	bots = [null]
	for i in range(1, lineup.size()):
		# Kart 1 is on pole and the strongest; the weakest starts just ahead of the rider.
		var profile := {
			"power_pct": pcts[clampi(lineup.size() - 1 - i, 0, pcts.size() - 1)],
			"line_offset": BOT_LINES[(i - 1) % BOT_LINES.size()],
			"drift_skill": 0.5, "item_skill": 0.5, "aggression": 0.5,
		}
		bots.append(KartBotDriver.new(profile, ftp_w, rng.randi()))


## Race-systems agent: item pods, the held item and projectiles (and the Auto items option).
func _build_items() -> void:
	pass


## Presentation agent: the HUD widget and the boards.
func _build_hud() -> void:
	_status = KartStatus.new()
	hud.add_widget(_status)
	_board = KartRaceBoard.new()
	add_child(_board)


## Presentation agent: music and effects.
func _build_audio() -> void:
	AudioDirector.play_music(MUSIC_STYLE, MUSIC_BPM, int(segment.get("seed", 0)))
	AudioDirector.set_intensity(0.5)


## Presentation agent: sparks, flames, dust, speed lines.
func _build_fx() -> void:
	pass


# --- The Grand Prix ---

## Sets up the next race on its grid (the countdown starts separately).
func _begin_race() -> void:
	if _lineup_dirty:
		_lineup_dirty = false
		lineup = KartRoster.lineup(option("driver"), RACERS)
		_build_racers()
	current = gp.next_race(_time_left(), _est_lap)
	var key := "%s:%s" % [current.track_id, current.reversed]
	if key != _built_track:
		track = KartTrackModel.new(KartTracks.build(current.track_id), current.reversed)
		world.build(track)
		_built_track = key
	race = KartRaceLogic.new()
	race.physics.assist = ASSIST.get(option("assist"), 1.0)
	race.physics.drift_resistance = float(params.get("drift_resistance", race.physics.drift_resistance))
	var racers := []
	for r in lineup:
		racers.append({"racer_id": r.id, "weight": r.weight})
	race.setup(track, racers, current.laps)
	scoring.begin_race(race)
	race.events.race_started.connect(_on_race_started)
	race.events.race_finished.connect(_on_race_finished)
	race.events.final_lap.connect(_on_final_lap)
	flow = Flow.IDLE
	_sync_views(0.0)
	camera.snap(race.karts[RIDER])
	race_began.emit(race)


func _start_countdown() -> void:
	race.start_countdown(COUNTDOWN_SEC)
	flow = Flow.COUNTDOWN
	_countdown_shown = -1


func _on_race_started() -> void:
	flow = Flow.RACING
	_show_message("GO!", GO_SEC)


func _on_final_lap(kart_id: int) -> void:
	if kart_id == RIDER and race.laps > 1:
		_show_message("Final lap!", 1.6)


func _on_race_finished(order: Array) -> void:
	gp.record(order)
	stats = scoring.stats(gp)
	won = gp.champion() == RIDER
	flow = Flow.RESULTS
	_flow_left = RESULTS_SEC
	var rows := []
	for i in order.size():
		var id: int = order[i]
		rows.append({"name": _racer_name(id), "detail": "+%d" % KartGrandPrix.POINTS[i] if i < KartGrandPrix.POINTS.size() else ""})
	var title := "Race %d results" % (int(current.index) + 1)
	_board.show_board(title, rows)


## The board's time is up: the next race, the podium, or the end.
func _after_board() -> void:
	if flow == Flow.RESULTS and bool(current.get("is_final", false)):
		flow = Flow.PODIUM
		_flow_left = PODIUM_SEC
		var rows := []
		for row in gp.standings():
			rows.append({"name": _racer_name(row.kart_id), "detail": "%d pts" % row.points})
		_board.show_board("Grand Prix standings", rows)
		return
	if flow == Flow.PODIUM:
		_finish_gp()
		if has_ended():
			return
	# Another race (also when a timed slot refused to end early).
	_board.hide_board()
	_begin_race()
	_start_countdown()


func _finish_gp() -> void:
	stats = scoring.stats(gp)
	won = gp.races_run() > 0 and gp.champion() == RIDER
	flow = Flow.DONE
	end_segment()


func _time_left() -> float:
	var duration := float(segment.get("duration_sec", -1))
	if duration < 0.0:
		return -1.0
	if not InputBus.is_simulated() and InputBus.segment_time_left >= 0.0:
		return InputBus.segment_time_left
	return maxf(0.0, duration - played_sec)


func _bot_pcts() -> Array:
	var given = params.get("bot_pcts")
	if given is Array and given.size() == RACERS - 1:
		return given.map(func(v): return float(v))
	var span: Array = BOT_PCTS.get(difficulty, BOT_PCTS.standard)
	var out := []
	for i in RACERS - 1:
		out.append(lerpf(span[0], span[1], float(i) / (RACERS - 2)))
	return out


func _racer_name(kart_id: int) -> String:
	var n := str(lineup[kart_id].name) if kart_id < lineup.size() else "?"
	return n + " (you)" if kart_id == RIDER else n


# --- Every frame ---

func _on_frame(delta: float) -> void:
	if not DEV_TUNING:
		_frame(delta)
		return
	var started := Time.get_ticks_usec()
	_frame(delta)
	_perf_usec += Time.get_ticks_usec() - started
	_perf_frames += 1
	_perf_left -= delta
	if _perf_left <= 0.0:
		print("OPENRIDE_GAMES kart_race perf game_ms=%.2f process_ms=%.2f fps=%d draw_calls=%d objects=%d primitives=%d karts=%d" % [
			_perf_usec / 1000.0 / maxi(_perf_frames, 1),
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			race.karts.size() if race else 0])
		_perf_usec = 0
		_perf_frames = 0
		_perf_left = PERF_LOG_SEC


func _frame(delta: float) -> void:
	var key := InputBus.is_simulated() and Input.is_key_pressed(KEY_E)
	_item_edge = _item_edge or (key and not _item_key)
	_item_key = key
	_acc = minf(_acc + delta, TICK * MAX_TICKS)
	while _acc >= TICK:
		_acc -= TICK
		_tick(TICK)
		if has_ended():
			return
	_sync_views(delta)
	_update_hud(delta)


## One fixed step of the whole game.
func _tick(dt: float) -> void:
	sim_time += dt
	match flow:
		Flow.IDLE, Flow.DONE:
			return
		Flow.RESULTS, Flow.PODIUM:
			_flow_left -= dt
			if _flow_left <= 0.0:
				_after_board()
				return
	var inputs := _inputs(dt)
	race.step(dt, inputs)
	scoring.step(dt, inputs[RIDER].power_w)


func _inputs(dt: float) -> Array:
	var inputs := []
	inputs.resize(race.karts.size())
	inputs[RIDER] = _read_rider()
	for id in range(1, race.karts.size()):
		inputs[id] = bots[id].think(race.karts[id], race, dt)
	return inputs


func _read_rider() -> KartInput:
	if test_input:
		return test_input
	_rider_input.power_w = InputBus.power
	_rider_input.cadence = InputBus.cadence
	_rider_input.lean = InputBus.lean_x
	_rider_input.resistance = InputBus.resistance
	_rider_input.standing = InputBus.standing
	_rider_input.use_item = _item_edge
	_item_edge = false
	return _rider_input


func _sync_views(delta: float) -> void:
	for i in views.size():
		views[i].sync(race.karts[i], delta)
	camera.follow(race.karts[RIDER], delta)


func _update_hud(delta: float) -> void:
	var k: KartState = race.karts[RIDER]
	var race_text := "Final race" if bool(current.get("is_final", false)) else "Race %d" % (int(current.get("index", 0)) + 1)
	_status.set_state(k.place, race.karts.size(), k.lap, race.laps, race_text)
	if flow == Flow.COUNTDOWN:
		var n := ceili(race.countdown)
		if n != _countdown_shown and n > 0:
			_countdown_shown = n
			hud.show_message(str(n))
			_message_left = 0.0
	elif _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0:
			hud.hide_message()


func _show_message(text: String, seconds: float) -> void:
	hud.show_message(text)
	_message_left = seconds
