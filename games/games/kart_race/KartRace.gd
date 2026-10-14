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
## scale, msaa, outlines, glow; [world] road, walls, ground, scenery, hud, fx) and log the frame
## cost every 5 s.
const DEV_TUNING := false
const TUNING_PATH := "user://kart_tuning.cfg"
const PERF_LOG_SEC := 5.0

const TICK := 1.0 / 60.0
const MAX_TICKS := 8  ## per frame, so a stall never snowballs
const RIDER := KartRaceLogic.RIDER
const RACERS := 8
const COUNTDOWN_SEC := 3.0
## Before each countdown the camera flies over the grid under the title card (the race logic's
## countdown runs FLYOVER_SEC + COUNTDOWN_SEC; the numbers show for the last three).
const FLYOVER_SEC := 3.5
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
var _kart_hud: KartHud
var _fx: KartFx
var _hud_lineup := ""
var _lights := -1
var _acc := 0.0
var _flow_left := 0.0
var _est_lap := 60.0
var _built_track := ""
var _rider_input := KartInput.new()
var _input_list := []  ## reused every tick
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
	# No full-screen pass: the colour grade is folded into every world shader, and speed lines
	# are drawn as thin polygons by KartHud (a graded upscaling blit cost about 5 fps).
	KartView.outlines = not _tuned or bool(_tuning.get_value("render", "outlines", true))
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
	if _tuned and bool(_tuning.get_value("render", "glow", false)):
		world.set_glow(true)


## Handling agent: the chase camera (Chase / Close option), and each race's handling: the camera
## watches the rider's boosts, bumps and hits; the drift thresholds scale with the rider's FTP.
func _build_camera() -> void:
	camera = KartChaseCamera.new()
	camera.name = "ChaseCamera"
	camera.mode = option("camera")
	world.add_child(camera)
	camera.current = true
	race_began.connect(func(r: KartRaceLogic):
		camera.watch(r.events, RIDER)
		r.physics.top_speed = KartPhysics.steady_bike_speed(0.6 * ftp_w, 0.0) * KartPhysics.SPEED_SCALE)


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


## Presentation agent: the HUD widget, the game HUD, the framework HUD's skin and the boards.
func _build_hud() -> void:
	_status = KartStatus.new()
	hud.add_widget(_status)
	hud.set_skin(_hud_skin())
	_kart_hud = KartHud.new()
	add_child(_kart_hud)
	if _tuned:
		_kart_hud.visible = bool(_tuning.get_value("world", "hud", true))
	_kart_hud.item_pressed.connect(_on_item_pressed)
	_board = KartRaceBoard.new()
	_board.portrait_maker = _kart_hud.portrait_rect
	add_child(_board)
	race_began.connect(func(_r: KartRaceLogic):
		var key := ",".join(lineup.map(func(r): return str(r.id)))
		if key != _hud_lineup:
			_hud_lineup = key
			_kart_hud.setup(lineup, track)
		_kart_hud.set_gameplay_visible(false, false)
		_lights = -1)


## The framework HUD's panels in Kart Race's look (Hud.set_skin: fonts, panels, buttons only).
static func _hud_skin() -> Dictionary:
	var panel := KartTheme.badge(KartTheme.PANEL, 0.0, 22, KartTheme.PANEL_EDGE)
	panel.content_margin_left = 28
	panel.content_margin_right = 28
	panel.content_margin_top = 14
	panel.content_margin_bottom = 16
	var button := KartTheme.badge(Color(0.36, 0.22, 0.86, 0.95), 0.0, 22, Color(0.75, 0.66, 1.0))
	var pressed := KartTheme.badge(Color(0.5, 0.36, 1.0, 1.0), 0.0, 22, Color(0.9, 0.85, 1.0))
	var end := KartTheme.badge(Color(0.75, 0.16, 0.32, 0.95), 0.0, 22, Color(1.0, 0.6, 0.7))
	return {"font": KartTheme.display(true), "outline_color": KartTheme.OUTLINE, "outline_size": 8,
		"panel": panel, "button": button, "button_pressed": pressed, "end_button": end}


## Presentation agent: music and effects.
func _build_audio() -> void:
	AudioDirector.play_music(MUSIC_STYLE, MUSIC_BPM, int(segment.get("seed", 0)))
	AudioDirector.set_intensity(0.5)


## Presentation agent: sparks, flames, dust, speed lines.
func _build_fx() -> void:
	_fx = KartFx.new()
	_fx.name = "Fx"
	_fx.camera = camera
	world.add_child(_fx)
	if _tuned and not bool(_tuning.get_value("world", "fx", true)):
		_fx.visible = false
		_fx.demo_drifts = false
	race_began.connect(func(_r: KartRaceLogic): _fx.begin(views))


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
	race.start_countdown(COUNTDOWN_SEC + FLYOVER_SEC)
	flow = Flow.COUNTDOWN
	_countdown_shown = -1
	var total := gp.races_run() + 1
	var chip := "Grand Prix · %s" % ("Final race" if bool(current.get("is_final", false)) else "Race %d" % total)
	if _kart_hud:
		_kart_hud.show_title(chip, track.def.title + (" (reversed)" if track.reversed else ""), FLYOVER_SEC - 0.6)


func _on_race_started() -> void:
	flow = Flow.RACING
	_kart_hud.go()


func _on_final_lap(kart_id: int) -> void:
	if kart_id == RIDER and race.laps > 1:
		_kart_hud.banner("FINAL LAP!", 1.6)


func _on_race_finished(order: Array) -> void:
	gp.record(order)
	stats = scoring.stats(gp)
	won = gp.champion() == RIDER
	flow = Flow.RESULTS
	_flow_left = RESULTS_SEC
	var rows := []
	for i in order.size():
		var id: int = order[i]
		var k: KartState = race.karts[id]
		rows.append({"name": _racer_name(id), "detail": "+%d" % KartGrandPrix.POINTS[i] if i < KartGrandPrix.POINTS.size() else "",
			"racer_id": str(lineup[id].id), "you": id == RIDER,
			"time": KartTheme.race_time(k.finish_time) if i == 0 else "+%.3f" % maxf(0.0, k.finish_time - race.karts[order[0]].finish_time)})
	var place := order.find(RIDER) + 1
	var title := "Victory!" if place == 1 else ("On the podium!" if place <= 3 else "Nice drive!")
	var subtitle := "Grand Prix · Race %d · %s" % [gp.races_run(), track.def.title]
	_board.show_board(title, rows, subtitle, RESULTS_SEC, "Final standings" if bool(current.get("is_final", false)) else "Next race")
	_kart_hud.set_gameplay_visible(false)
	_status.visible = false


## The board's time is up: the next race, the podium, or the end.
func _after_board() -> void:
	if flow == Flow.RESULTS and bool(current.get("is_final", false)):
		flow = Flow.PODIUM
		_flow_left = PODIUM_SEC
		var rows := []
		for row in gp.standings():
			rows.append({"name": _racer_name(row.kart_id), "detail": "%d pts" % row.points,
				"racer_id": str(lineup[row.kart_id].id), "you": row.kart_id == RIDER,
				"time": "%d win%s" % [row.wins, "" if row.wins == 1 else "s"]})
		var champ := gp.champion() == RIDER
		_board.show_board("Champion!" if champ else "Grand Prix standings", rows, "Final standings", PODIUM_SEC, "Ride summary")
		return
	if flow == Flow.PODIUM:
		_finish_gp()
		if has_ended():
			return
	# Another race (also when a timed slot refused to end early).
	_board.hide_board()
	_status.visible = true
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
	var inputs := _input_list
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
	_rider_input.tracking = InputBus.tracker_state != InputBus.TRACKER_FACE_LOST  # handling: no drifts on face loss
	_rider_input.use_item = _item_edge
	_item_edge = false
	return _rider_input


func _sync_views(delta: float) -> void:
	for i in views.size():
		views[i].sync(race.karts[i], delta)
	var k: KartState = race.karts[RIDER]
	if flow == Flow.IDLE:
		camera.flyover(k, 0.0, track)
	elif flow == Flow.COUNTDOWN and race.countdown > COUNTDOWN_SEC:
		camera.flyover(k, 1.0 - (race.countdown - COUNTDOWN_SEC) / FLYOVER_SEC, track)
	else:
		camera.follow(k, delta)
	if _fx:
		_fx.step(race, delta)
	if _kart_hud:
		var lines := clampf((k.speed - 17.0) / 8.0, 0.0, 1.0) if flow == Flow.RACING else 0.0
		_kart_hud.speed_lines = maxf(lines, minf(k.boost_time, 1.0))


func _update_hud(delta: float) -> void:
	var k: KartState = race.karts[RIDER]
	var race_text := "Final race" if bool(current.get("is_final", false)) else "Race %d" % (int(current.get("index", 0)) + 1)
	_status.set_state(k.place, race.karts.size(), k.lap, race.laps, race_text)
	_kart_hud.update(race, _fx.drift_charge if _fx else 0.0, _fx.drift_tier if _fx else 0)
	var lights := 0
	if flow == Flow.COUNTDOWN:
		if race.countdown <= COUNTDOWN_SEC:
			lights = clampi(5 - ceili(race.countdown / (COUNTDOWN_SEC / 5.0)) + 1, 1, 5)
		var n := ceili(race.countdown)
		if n != _countdown_shown and n > 0 and n <= int(COUNTDOWN_SEC):
			_countdown_shown = n
			_kart_hud.countdown(n)
			if n == int(COUNTDOWN_SEC):
				_kart_hud.set_gameplay_visible(true)
	elif flow == Flow.RACING and race.time < 2.0:
		lights = 6
	if lights != _lights:
		_lights = lights
		world.set_start_lights(lights)
	if _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0:
			hud.hide_message()


## The item slot was tapped: use the item (the race-systems agent's KartItemLogic reads the
## edge). For the hero slice it also fires the boost's look.
func _on_item_pressed() -> void:
	_item_edge = true
	if _fx and flow == Flow.RACING:
		_fx.boost(RIDER, 1.2)


func _show_message(text: String, seconds: float) -> void:
	hud.show_message(text)
	_message_left = seconds
