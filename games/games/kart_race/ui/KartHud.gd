class_name KartHud
extends CanvasLayer
## Kart Race's game HUD (#43), over the 3D view and under the framework's HUD. Its layout follows
## the console party racers' grammar (and the web slice the rider liked), each element where the
## eye expects it, the road kept clear from the horizon down except for the slim ride strip:
##
##   top left      the slanted lap badge and race chip (KartStatus), the race clock under it,
##                 then the racer list with portraits (KartRacerList)
##   top right     the framework's compact time left and score, with Recalibrate | Pause | End
##                 under it (Hud.set_skin "recalibrate_top"; End keeps the corner)
##   right         the big gradient position number, which pops on every change
##   bottom right  the round item button (KartItemButton), the drift meter wrapped round its
##                 upper-left edge as an arc with the knob glyph. It sits at the far end of the
##                 screen from End: a rushed tap can't end the ride.
##   bottom left   the minimap (KartMinimap)
##   bottom centre the ride metrics strip (KartRideStrip) in place of the framework's ride panel;
##                 the camera strip, when steering is off, sits just above it, between the minimap
##                 and the item button (Hud.set_skin "status_width", "reserve_bottom")
##
## Over everything: speed lines and draft streaks, the title card, the countdown and the lap
## banners. Everything except the clock changes only with its value; the clock, the minimap's
## dots and the effect overlays are free-standing (no container), so their per-frame changes
## never re-lay out the HUD.

signal item_pressed

const LAYER := 8
const M := 40.0  ## HudTheme.MARGIN
const W := 1920.0
const H := 1080.0
const STATUS_POS := Vector2(M, M)
const CLOCK_RECT := Rect2(M + 6, 156, 268, 58)
const LIST_POS := Vector2(M, 236)
const MAP_POS := Vector2(M, H - M - KartMinimap.SIZE.y)
## The item button's square: its disc (KartItemButton.SIZE) touches the margins in the bottom-right
## corner; the hit circle round it (1.25×) fills the square.
const ITEM_CENTRE := Vector2(W - M - KartItemButton.SIZE * 0.5, H - M - KartItemButton.SIZE * 0.5)
const ITEM_POS := ITEM_CENTRE - Vector2(KartItemButton.HIT_SIZE, KartItemButton.HIT_SIZE) * 0.5
const BADGE_RECT := Rect2(W - M - 400, 336, 400, 260)
const PORTRAIT_PX := 160
const ATLAS_COLS := 4
const ATLAS_ROWS := 2
## The camera strip's width ("Camera steering is off", …): between the minimap and the item
## button, so it covers neither (it wraps to two lines).
const STATUS_WIDTH := 1080.0
const STATUS_WIDTH_BOARD := 1640.0
const STATUS_BAKE := Vector2(560, 104)  ## room for the lap badge at its widest ("FINAL RACE")

## racer id -> its portrait (a rendered head), also used by the boards.
var portraits := {}
## 0-1: radial speed lines at the screen's edges (thin polygons, so only their pixels cost).
var speed_lines := 0.0:
	set(v):
		speed_lines = v
		_update_overlay()
## 0-1 and the screen point the draft streaks flow toward (the kart ahead).
var draft := 0.0:
	set(v):
		draft = v
		_update_overlay()
var draft_point := Vector2(W * 0.5, H * 0.45)
var lineup: Array = []

var status: KartStatus
var racer_list: KartRacerList
var minimap: KartMinimap
var ride_strip: KartRideStrip
var item_button: KartItemButton
var _map_track: KartTrackModel  ## the track the minimap shows
var _bakes: Array[KartBaked] = []  ## status, racer list, ride strip, place badge
var _badge_view: KartBaked  ## the place badge on screen (its pop tweens here)

var _root: Control
var _gameplay: Control
var _clock: Label
var _badge: Control
var _place: Label
var _suffix: Label
var _shown_place := 0
var _title: Control
var _title_chip: Label
var _title_name: Label
var _count: Label
var _count_ring: Control
var _ring_t := 1.0
var _banner: Control
var _banner_label: Label
var _banner_sub: Label
var _tweens := {}
var _shown_clock := ""
var _portrait_shader: Shader
var _overlay: Control
var _overlay_kit := KartDraw.new()
var _line_rng := RandomNumberGenerator.new()
var _time := 0.0
var _pics: Array[WeakRef] = []  ## every portrait made, to re-dress once the atlas is baked
var _atlas_mats: Array[ShaderMaterial] = []
var _atlas_ids := {}


func _init() -> void:
	layer = LAYER
	_root = Control.new()
	_root.name = "KartHud"
	_root.size = Vector2(W, H)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_portrait_shader = load(KartTheme.SHADERS + "portrait.gdshader")
	_overlay = Control.new()
	_overlay.name = "SpeedLines"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.size = _root.size
	_overlay.visible = false
	_overlay.draw.connect(_draw_overlay)
	_root.add_child(_overlay)
	_gameplay = Control.new()
	_gameplay.name = "Gameplay"
	_gameplay.size = _root.size
	_gameplay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_gameplay)
	status = KartStatus.new()
	status.position = STATUS_POS
	_gameplay.add_child(status)
	_build_clock()
	racer_list = KartRacerList.new()
	racer_list.position = LIST_POS
	_gameplay.add_child(racer_list)
	minimap = KartMinimap.new()
	minimap.position = MAP_POS
	_gameplay.add_child(minimap)
	ride_strip = KartRideStrip.new()
	ride_strip.position = Vector2((W - ride_strip.size.x) * 0.5, H - M - ride_strip.size.y)
	_gameplay.add_child(ride_strip)
	_build_badge()
	# The slow-changing widgets render into textures only when they change (KartBaked: one draw
	# call each on screen instead of a pair per label).
	_bakes = [KartBaked.new(status, _gameplay, STATUS_BAKE), KartBaked.new(racer_list, _gameplay),
		KartBaked.new(ride_strip, _gameplay), KartBaked.new(_badge, _gameplay, BADGE_RECT.size + Vector2(0, 40))]
	_badge_view = _bakes[3]
	_bakes[2].min_interval = 0.2  # the ride strip's readouts: 5 Hz is plenty
	# At most two re-render a frame (a place change redrew all four at once: ~130 draw calls).
	var queue := KartBakeQueue.new()
	queue.per_frame = 2
	for b in _bakes:
		b.queue = queue
	item_button = KartItemButton.new()
	item_button.position = ITEM_POS
	item_button.used.connect(func(): item_pressed.emit())
	_gameplay.add_child(item_button)
	_build_title()
	_build_countdown()
	_build_banner()


## The framework HUD's skin for this layout: Kart Race's fonts and panels, the ride panel hidden
## (the ride strip replaces it), a compact clock, Recalibrate moved up beside Pause | End (the
## bottom right is the item button's) as a quieter outline pill, and the camera strip kept
## between the minimap and the item button, above the ride strip. While a board shows (`board`),
## the gameplay widgets are gone and the strip takes the bottom band under the board's rows on
## one line.
static func hud_skin(board := false) -> Dictionary:
	var panel := KartTheme.badge(KartTheme.PANEL, 0.0, 22, KartTheme.PANEL_EDGE)
	panel.content_margin_left = 24
	panel.content_margin_right = 24
	panel.content_margin_top = 6
	panel.content_margin_bottom = 10
	var button := KartTheme.badge(Color(0.36, 0.22, 0.86, 0.95), 0.0, 22, Color(0.75, 0.66, 1.0))
	var pressed := KartTheme.badge(Color(0.5, 0.36, 1.0, 1.0), 0.0, 22, Color(0.9, 0.85, 1.0))
	var end := KartTheme.badge(Color(0.75, 0.16, 0.32, 0.95), 0.0, 22, Color(1.0, 0.6, 0.7))
	# Secondary: a dark pill with a violet outline, so End never sits beside a twin.
	var recal := KartTheme.badge(Color(0.1, 0.06, 0.24, 0.72), 0.0, 22, Color(0.75, 0.66, 1.0))
	recal.set_border_width_all(4)
	recal.border_width_bottom = 6
	recal.content_margin_left = 22
	recal.content_margin_right = 22
	return {"font": KartTheme.display(true), "outline_color": KartTheme.OUTLINE, "outline_size": 8,
		"panel": panel, "button": button, "button_pressed": pressed, "end_button": end,
		"recalibrate_button": recal, "recalibrate_top": true,
		"ride_panel": false, "clock_value_size": HudTheme.MEDIUM,
		"status_width": status_area(board)[0], "reserve_bottom": status_area(board)[1]}


## The camera strip's row (Hud.set_status_area): [width, reserve_bottom], racing or on a board.
static func status_area(board := false) -> Array:
	return [STATUS_WIDTH_BOARD, 0.0] if board else [STATUS_WIDTH, KartRideStrip.TILE.y + 12.0]


## A new grid: the racers (KartRoster entries, kart id order) and the track for the minimap.
func setup(racers: Array, track: KartTrackModel) -> void:
	lineup = racers
	_make_portraits()
	racer_list.setup(racers, portrait_rect)
	_map_track = null
	set_track(track)


## A race's track (each race calls it): the minimap redraws when the track or direction changes.
func set_track(track: KartTrackModel) -> void:
	if track == _map_track:
		return
	_map_track = track
	minimap.set_track(track, lineup)


# --- Per frame ---

## The race's state each frame.
func update(race: KartRaceLogic, delta := 0.0) -> void:
	_time += delta
	var k: KartState = race.karts[KartRaceLogic.RIDER]
	var t := race.time if race.phase != KartRaceLogic.Phase.FINISHED else k.finish_time
	if race.phase == KartRaceLogic.Phase.RACING or race.phase == KartRaceLogic.Phase.FINISHED:
		var text := KartTheme.race_time(t)
		if text != _shown_clock:
			_shown_clock = text
			_clock.text = text
	elif _shown_clock != "0:00.000":
		_shown_clock = "0:00.000"
		_clock.text = _shown_clock
	_set_place(k.place)
	racer_list.set_order(race.order())
	minimap.set_karts(race.karts)
	item_button.set_item(k.item, k.roulette_time, delta)
	item_button.set_drift(k.drift_dir, k.drift_charge, k.drift_tier, k.knob_boosting, delta)
	if _overlay.visible:
		_overlay.queue_redraw()
	if _ring_t < 1.0:
		_ring_t = minf(1.0, _ring_t + delta * 1.6)
		_count_ring.visible = _ring_t < 1.0
		_count_ring.queue_redraw()


func _update_overlay() -> void:
	if _overlay:
		_overlay.visible = speed_lines > 0.01 or draft > 0.01


## Speed lines: thin tapered streaks from the screen's edges toward the centre, re-scattered
## every frame. Draft streaks: pale ribbons flowing in toward the kart being drafted.
func _draw_overlay() -> void:
	var c := _root.size * 0.5
	if speed_lines > 0.01:
		var n := int(10 + 18 * speed_lines)
		for i in n:
			var a := _line_rng.randf() * TAU
			var dir := Vector2(cos(a), sin(a) * 0.62)
			var r0 := _line_rng.randf_range(0.62, 0.8)
			var r1 := r0 + _line_rng.randf_range(0.2, 0.5)
			var p0 := c + dir * c.x * r0
			var p1 := c + dir * c.x * r1
			var side := Vector2(-dir.y, dir.x) * _line_rng.randf_range(1.5, 4.0)
			_overlay_kit.convex(PackedVector2Array([p0, p1 + side, p1 - side]), Color(1.0, 0.98, 0.92, 0.35 * speed_lines))
	if draft > 0.01:
		# Ribbons on a fixed fan of angles, each sliding inward over time.
		for i in 14:
			var a := -0.25 + (PI + 0.5) * float(i) / 13.0  # a fan from the right, under, to the left
			var dir := Vector2(cos(a), sin(a) * 0.55).normalized()
			var phase := fposmod(_time * 1.6 + float(i) * 0.37, 1.0)
			var far := 900.0 * (1.0 - phase) + 140.0
			var near := far - 260.0
			var p_far := draft_point + dir * far
			var p_near := draft_point + dir * maxf(near, 70.0)
			var side := Vector2(-dir.y, dir.x) * 3.5
			var alpha := 0.42 * draft * sin(phase * PI)
			_overlay_kit.convex(PackedVector2Array([p_near, p_far + side, p_far - side]), Color(0.75, 0.95, 1.0, alpha))
	_overlay_kit.flush(_overlay)  # every streak in one draw call


func set_gameplay_visible(on: bool, animate := true) -> void:
	if _gameplay.visible == on and _gameplay.modulate.a > 0.99:
		return
	_kill("gameplay")
	_gameplay.visible = true
	if not animate:
		_gameplay.modulate.a = 1.0 if on else 0.0
		_gameplay.visible = on
		return
	var tw := create_tween()
	_tweens["gameplay"] = tw
	tw.tween_property(_gameplay, "modulate:a", 1.0 if on else 0.0, 0.35)
	if not on:
		tw.tween_callback(func(): _gameplay.visible = false)


func is_gameplay_visible() -> bool:
	return _gameplay.visible and _gameplay.modulate.a > 0.5


# --- Title card, countdown, banners ---

func show_title(chip: String, title: String, seconds := 3.2) -> void:
	_title_chip.text = chip.to_upper()
	_title_name.text = title
	_kill("title")
	_title.visible = true
	_title.modulate.a = 0.0
	_title.position.x = -120.0
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tweens["title"] = tw
	tw.tween_property(_title, "position:x", 0.0, 0.5)
	tw.parallel().tween_property(_title, "modulate:a", 1.0, 0.3)
	tw.tween_interval(seconds)
	tw.tween_property(_title, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): _title.visible = false)


func countdown(n: int) -> void:
	_count.text = str(n)
	KartTheme.gradient(_count, KartTheme.GOLD_TOP, KartTheme.GOLD_BOTTOM)
	_pop(_count, 0.9)
	_ring_t = 0.0
	_count_ring.visible = true


func go() -> void:
	_count.text = "GO!"
	KartTheme.gradient(_count, KartTheme.GREEN_TOP, KartTheme.GREEN_BOTTOM)
	_pop(_count, 0.9)
	_ring_t = 0.0
	_count_ring.visible = true


## A ribbon that sweeps in from the right, holds, and sweeps out left: "LAP 2/3", "FINAL LAP!".
## `final` makes it gold and red, with the subtitle.
func banner(text: String, seconds := 1.6, subtitle := "", final := false) -> void:
	_banner_label.text = text
	_banner_sub.text = subtitle.to_upper()
	_banner_sub.visible = subtitle != ""
	if final:
		KartTheme.gradient(_banner_label, KartTheme.GOLD_TOP, Color(1.0, 0.3, 0.15))
	else:
		KartTheme.gradient(_banner_label, Color(1, 1, 1), KartTheme.VIOLET_TOP)
	(_banner.get_child(0) as Panel).add_theme_stylebox_override("panel", _ribbon(final))
	_kill("banner")
	_banner.visible = true
	_banner.modulate.a = 1.0
	_banner.position.x = W
	var tw := create_tween()
	_tweens["banner"] = tw
	tw.tween_property(_banner, "position:x", 0.0, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_banner_label, "scale", Vector2.ONE, 0.5).from(Vector2(1.4, 1.4)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(seconds)
	tw.tween_property(_banner, "position:x", -W, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): _banner.visible = false)


func _pop(l: Control, hold: float) -> void:
	_kill(str(l.get_instance_id()))
	l.visible = true
	l.modulate.a = 1.0
	l.scale = Vector2(2.0, 2.0)
	var tw := create_tween()
	_tweens[str(l.get_instance_id())] = tw
	tw.tween_property(l, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.0, hold - 0.55))
	tw.tween_property(l, "modulate:a", 0.0, 0.22)
	tw.parallel().tween_property(l, "scale", Vector2(0.8, 0.8), 0.22)
	tw.tween_callback(func(): l.visible = false)


func _kill(key: String) -> void:
	var tw: Tween = _tweens.get(key)
	if tw and tw.is_valid():
		tw.kill()


# --- Builders ---

func _build_clock() -> void:
	var plate := Panel.new()
	plate.name = "ClockPlate"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := KartTheme.badge(Color(0.08, 0.05, 0.2, 0.78), 0.2, 12, Color(0, 0, 0, 0))
	plate.add_theme_stylebox_override("panel", style)
	plate.size = CLOCK_RECT.size
	plate.position = CLOCK_RECT.position
	_gameplay.add_child(plate)
	_clock = KartTheme.label("0:00.000", 46, KartTheme.INK, true)
	_clock.name = "Clock"
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_clock.size = CLOCK_RECT.size
	plate.add_child(_clock)


func _build_badge() -> void:
	_badge = Control.new()
	_badge.name = "PositionBadge"
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.size = BADGE_RECT.size
	_badge.position = BADGE_RECT.position
	_badge.pivot_offset = Vector2(280, 170)
	_gameplay.add_child(_badge)
	_place = KartTheme.label("8", 250, KartTheme.INK)
	_place.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_place.size = Vector2(260, 260)
	_place.position = Vector2(20, 0)
	_place.add_theme_constant_override("outline_size", 34)
	KartTheme.gradient(_place, KartTheme.VIOLET_TOP, KartTheme.VIOLET_BOTTOM)
	_badge.add_child(_place)
	_suffix = KartTheme.label("th", 96, KartTheme.INK)
	_suffix.position = Vector2(282, 40)
	_suffix.size = Vector2(118, 110)
	_suffix.add_theme_constant_override("outline_size", 20)
	KartTheme.gradient(_suffix, KartTheme.VIOLET_TOP, KartTheme.VIOLET_BOTTOM)
	_badge.add_child(_suffix)


func _set_place(place: int) -> void:
	if place == _shown_place or place <= 0:
		return
	var better := _shown_place == 0 or place < _shown_place
	_shown_place = place
	_place.text = str(place)
	_suffix.text = KartTheme.ordinal_suffix(place)
	var top: Color = KartTheme.GOLD_TOP if place == 1 else (KartTheme.ORANGE_TOP if place <= 3 else KartTheme.VIOLET_TOP)
	var bottom: Color = KartTheme.GOLD_BOTTOM if place == 1 else (KartTheme.ORANGE_BOTTOM if place <= 3 else KartTheme.VIOLET_BOTTOM)
	for l: Label in [_place, _suffix]:
		(l.material as ShaderMaterial).set_shader_parameter("top", top)
		(l.material as ShaderMaterial).set_shader_parameter("bottom", bottom)
	_kill("badge")
	var tw := create_tween()
	_tweens["badge"] = tw
	var view: Control = _badge_view if _badge_view else _badge
	view.scale = Vector2(1.35, 1.35) if better else Vector2(0.8, 0.8)
	view.rotation = -0.08 if better else 0.05
	tw.tween_property(view, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(view, "rotation", 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_title() -> void:
	_title = Control.new()
	_title.name = "TitleCard"
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.size = _root.size
	_title.visible = false
	_root.add_child(_title)
	# A dark slanted band behind the name, fading to the right.
	var band := Panel.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.08, 0.04, 0.2, 0.62)
	bs.skew = Vector2(0.25, 0)
	bs.set_corner_radius_all(14)
	bs.border_color = KartTheme.CHIP
	bs.border_width_left = 14
	bs.anti_aliasing = true
	band.add_theme_stylebox_override("panel", bs)
	band.position = KartWorld.TITLE_BAND.position
	band.size = KartWorld.TITLE_BAND.size
	_title.add_child(band)
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := KartTheme.badge(KartTheme.CHIP, 0.2, 10, Color(1, 1, 1, 0.0))
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 2
	style.content_margin_bottom = 4
	chip.add_theme_stylebox_override("panel", style)
	chip.position = Vector2(80, 812)
	_title.add_child(chip)
	_title_chip = KartTheme.label("", 38, KartTheme.OUTLINE)
	_title_chip.add_theme_constant_override("outline_size", 0)
	_title_chip.add_theme_constant_override("shadow_offset_y", 0)
	_title_chip.add_theme_constant_override("shadow_offset_x", 0)
	chip.add_child(_title_chip)
	_title_name = KartTheme.label("", 150, KartTheme.INK)
	_title_name.position = Vector2(64, 856)
	_title_name.add_theme_constant_override("outline_size", 30)
	KartTheme.gradient(_title_name, Color(1, 1, 1), Color(0.86, 0.84, 1.0))
	_title.add_child(_title_name)


func _build_countdown() -> void:
	_count_ring = Control.new()
	_count_ring.name = "CountRing"
	_count_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count_ring.size = _root.size
	_count_ring.visible = false
	_count_ring.draw.connect(func():
		if _ring_t >= 1.0:
			return
		var e := 1.0 - pow(1.0 - _ring_t, 3.0)
		var col := KartTheme.GREEN_TOP if _count.text == "GO!" else KartTheme.GOLD_TOP
		_count_ring.draw_arc(Vector2(W * 0.5, 360), 120.0 + 380.0 * e, 0, TAU, 64, Color(col, 0.7 * (1.0 - _ring_t)), 26.0 * (1.0 - _ring_t) + 2.0, true))
	_root.add_child(_count_ring)
	_count = KartTheme.label("", 280, KartTheme.INK)
	_count.name = "Countdown"
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count.size = Vector2(1000, 380)
	_count.position = Vector2((W - 1000) * 0.5, 170)
	_count.pivot_offset = _count.size * 0.5
	_count.add_theme_constant_override("outline_size", 44)
	_count.visible = false
	_root.add_child(_count)


func _build_banner() -> void:
	_banner = Control.new()
	_banner.name = "Banner"
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.size = Vector2(W, 220)
	_banner.position = Vector2(0, 272)
	_banner.visible = false
	_root.add_child(_banner)
	var ribbon := Panel.new()
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ribbon.position = Vector2(W * 0.5 - 520, 36)
	ribbon.size = Vector2(1040, 150)
	ribbon.add_theme_stylebox_override("panel", _ribbon(false))
	_banner.add_child(ribbon)
	_banner_label = KartTheme.label("", 124, KartTheme.INK)
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_label.size = Vector2(1400, 200)
	_banner_label.position = Vector2((W - 1400) * 0.5, 0)
	_banner_label.pivot_offset = _banner_label.size * 0.5
	_banner_label.add_theme_constant_override("outline_size", 30)
	_banner.add_child(_banner_label)
	_banner_sub = KartTheme.label("", 38, KartTheme.CHIP, true)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub.size = Vector2(1000, 50)
	_banner_sub.position = Vector2((W - 1000) * 0.5, 172)
	_banner.add_child(_banner_sub)


static func _ribbon(final: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.85, 0.15, 0.25, 0.9) if final else Color(0.3, 0.18, 0.8, 0.88)
	s.skew = Vector2(0.3, 0)
	s.set_corner_radius_all(16)
	s.border_color = Color(1.0, 0.85, 0.3) if final else Color(0.8, 0.72, 1.0)
	s.set_border_width_all(5)
	s.border_width_bottom = 10
	s.shadow_color = Color(0.05, 0.0, 0.15, 0.5)
	s.shadow_size = 12
	s.shadow_offset = Vector2(6, 10)
	s.anti_aliasing = true
	return s


# --- Portraits ---

## A round portrait of a racer at `size` px (gold ring for the rider). Once the heads are baked
## into one atlas, every portrait shares its texture and one material (two for the rider's gold
## ring), so a column of them draws as one batch.
func portrait_rect(racer_id: String, size: float, you := false) -> TextureRect:
	var pic := TextureRect.new()
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.size = Vector2(size, size)
	pic.custom_minimum_size = Vector2(size, size)
	pic.z_index = 1  # after the labels, so the portraits batch together
	pic.set_meta("racer_id", racer_id)
	pic.set_meta("you", you)
	_dress_portrait(pic)
	_pics.append(weakref(pic))
	return pic


func _dress_portrait(pic: TextureRect) -> void:
	var racer_id: String = pic.get_meta("racer_id")
	var you: bool = pic.get_meta("you")
	pic.texture = portraits.get(racer_id)
	if _atlas_mats.size() == 2 and _atlas_ids.has(racer_id):
		pic.material = _atlas_mats[1 if you else 0]
		return
	var mat := ShaderMaterial.new()
	mat.shader = _portrait_shader
	var racer := KartRoster.racer(racer_id)
	mat.set_shader_parameter("backdrop", racer.get("color", Color(0.5, 0.4, 0.9)))
	mat.set_shader_parameter("ring", Color(1.0, 0.82, 0.2) if you else Color(1, 1, 1))
	pic.material = mat


## Renders each racer's head once (KartPortraits: a small transparent SubViewport, framed from
## the head's bounds), then bakes them into one atlas texture and frees the viewports.
func _make_portraits() -> void:
	var made := []
	for racer in lineup:
		var id := str(racer.id)
		if portraits.has(id):
			continue
		var tex := KartPortraits.texture(self, racer, PORTRAIT_PX)
		portraits[id] = tex
		made.append(get_child(get_child_count() - 1))  # the viewport texture() just added
	if not made.is_empty() and DisplayServer.get_name() != "headless":
		_bake_atlas.call_deferred(made)


func _bake_atlas(viewports: Array) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var ids := []
	for r in lineup:
		ids.append(str(r.id))
	if ids.size() > ATLAS_COLS * ATLAS_ROWS:
		return
	var atlas := Image.create(ATLAS_COLS * PORTRAIT_PX, ATLAS_ROWS * PORTRAIT_PX, false, Image.FORMAT_RGBA8)
	for i in ids.size():
		var tex: Texture2D = portraits.get(ids[i])
		var img := tex.get_image() if tex else null
		if img == null or img.is_empty():
			return  # keep the viewports' own textures
		img.convert(Image.FORMAT_RGBA8)
		atlas.blit_rect(img, Rect2i(0, 0, PORTRAIT_PX, PORTRAIT_PX), Vector2i((i % ATLAS_COLS) * PORTRAIT_PX, (i / ATLAS_COLS) * PORTRAIT_PX))
	atlas.generate_mipmaps()
	var atlas_tex := ImageTexture.create_from_image(atlas)
	var backdrops := PackedColorArray()
	backdrops.resize(ATLAS_COLS * ATLAS_ROWS)
	_atlas_ids.clear()
	for i in ids.size():
		var at := AtlasTexture.new()
		at.atlas = atlas_tex
		at.region = Rect2((i % ATLAS_COLS) * PORTRAIT_PX, (i / ATLAS_COLS) * PORTRAIT_PX, PORTRAIT_PX, PORTRAIT_PX)
		portraits[ids[i]] = at
		_atlas_ids[ids[i]] = i
		backdrops[i] = KartRoster.racer(ids[i]).get("color", Color(0.5, 0.4, 0.9))
	_atlas_mats.clear()
	for ring in [Color(1, 1, 1), Color(1.0, 0.82, 0.2)]:
		var mat := ShaderMaterial.new()
		mat.shader = load(KartTheme.SHADERS + "portrait_atlas.gdshader")
		mat.set_shader_parameter("backdrops", backdrops)
		mat.set_shader_parameter("ring", ring)
		_atlas_mats.append(mat)
	for ref: WeakRef in _pics:
		var pic: TextureRect = ref.get_ref()
		if pic:
			_dress_portrait(pic)
	_pics.assign(_pics.filter(func(r: WeakRef): return r.get_ref() != null))
	for vp in viewports:
		if is_instance_valid(vp):
			vp.queue_free()
