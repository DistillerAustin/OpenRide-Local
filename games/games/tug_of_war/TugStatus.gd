class_name TugStatus
extends PanelContainer
## Tug of War's HUD widget, in the HUD's top-centre slot: the hero tug meter. Two rows, at most
## 800 x 120 px with the longest texts (`tug_status_layout_test`):
##
##        215 W  ▕▓▓▓▓▓▓▓▓▓●     ▏  120 W
##          YOU     ● ● ○  Rust Mule    BOT
##
## Row 1: the watts either side (56 px, display face) and the rope bar (420 x 40), filled from
## the centre towards the leader in that team's colour, with a rope knot at `p`. The teams have
## their own colours, not good and bad: YOU in the rider's glove blue, BOT in the current bot's
## body colour (lifted for contrast). The side of the bar carries the meaning too, so colour is
## never alone. The leader's watts pop when the lead changes hands.
## Row 2: the captions, and in the middle the round state (best-of pips in a match, a "RUNG 3"
## badge on the ladder, "WON 3" in an endless ride) and the bot's name. A state badge ("PEDAL!",
## "SURGE!", "REST 12") takes the round state's place while it holds.
##
## Budget (UI_STYLE.md §8): labels change only on a change (watts round to 5 W), the bar redraws
## only when the knot moves a pixel, and the surge's flashing knot is a modulate tween on its own
## node, not a redraw.

const BAR_SIZE := Vector2(420, 40)
const SIDE_WIDTH := 160.0  ## each watts column: "1885 W" at 56 px with room to spare
const CENTRE_WIDTH := BAR_SIZE.x
const KNOT := 40.0
const PIP := 30.0
const PIP_GAP := 8.0
const PIPS_MAX_WIDTH := 190.0
const MAX_PIPS := 7  ## more rounds than this show as a "3-2" badge
const LEAD_MARGIN := 10  ## watts: the lead changes hands past this, so a tie doesn't flicker
const RIDER_COLOR := Color("5b8cff")  ## the rider's gloves in TugWorld
const ROPE := Color(0.86, 0.72, 0.46)

var look: GameTheme
var p := 0.0
var surge := ""
var bot_color := Color(0.82, 0.48, 0.25)  ## the bot's colour for the UI (lifted)

var you_watts: Label
var bot_watts: Label
var you_caption: Label
var bot_caption: Label
var bot_name: Label
var bar: Control
var knot: Control
var pips: Control
var badge: PanelContainer
var badge_label: Label

var _you_text := ""
var _bot_text := ""
var _bar_px := 99999
var _leader := 0  ## 1 rider, -1 bot, 0 not yet
var _mode := "match"
var _best_of := 3
var _results: Array[bool] = []
var _rung := 0
var _wins := 0
var _losses := 0
var _alert := ""  ## "", "pedal", "rest"
var _rest_sec := 0
var _badge_key := ""
var _knot_tween: Tween
var _track: StyleBoxFlat
var _knot_box: StyleBoxFlat


func _init(theme: GameTheme = null) -> void:
	look = theme if theme else GameTheme.new(Color("ff9f1c"), Color("2a160b"), 0.12)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := look.panel_style()
	style.content_margin_top = 4
	style.content_margin_bottom = 6
	style.content_margin_left = 20
	style.content_margin_right = 20
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	add_child(box)

	var top := _row(box)
	you_watts = _watts_column(top, true)
	bar = Control.new()
	bar.name = "RopeBar"
	bar.custom_minimum_size = BAR_SIZE
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(_draw_bar)
	bar.resized.connect(_place_knot)
	top.add_child(bar)
	knot = Control.new()
	knot.name = "Knot"
	knot.size = Vector2(KNOT, KNOT)
	knot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knot.draw.connect(_draw_knot)
	bar.add_child(knot)
	bot_watts = _watts_column(top, false)

	var bottom := _row(box)
	you_caption = _caption(tr("YOU"), RIDER_COLOR)
	you_caption.custom_minimum_size = Vector2(SIDE_WIDTH, 0)
	you_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bottom.add_child(you_caption)
	var centre := HBoxContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.custom_minimum_size = Vector2(CENTRE_WIDTH, 0)
	centre.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_theme_constant_override("separation", 12)
	bottom.add_child(centre)
	pips = Control.new()
	pips.name = "Pips"
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pips.draw.connect(_draw_pips)
	centre.add_child(pips)
	badge = PanelContainer.new()
	badge.name = "Badge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge_label = look.label("", HudTheme.SMALL, GameTheme.INK, true)
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(badge_label)
	badge.visible = false
	centre.add_child(badge)
	bot_name = _caption("", bot_color)
	centre.add_child(bot_name)
	bot_caption = _caption(tr("BOT"), bot_color)
	bot_caption.custom_minimum_size = Vector2(SIDE_WIDTH, 0)
	bottom.add_child(bot_caption)
	_refresh_round()


func _row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	return row


## A 34 px caption on the panel. The panel is ink at 86%, not the 3D scene, so captions skip the
## outline: an outlined label is two draw calls (the outline's glyph atlas, then the fill's),
## and plain captions of one size batch into one. The watts and the badge keep theirs.
func _caption(text: String, color: Color) -> Label:
	var l := look.label(text, HudTheme.SMALL, color, true)
	l.add_theme_constant_override("outline_size", 0)
	return l


## A watts column: the number at 56 px and a 34 px "W", hugging the bar.
func _watts_column(parent: Control, rider: bool) -> Label:
	var col := HBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.custom_minimum_size = Vector2(SIDE_WIDTH, 0)
	col.alignment = BoxContainer.ALIGNMENT_END if rider else BoxContainer.ALIGNMENT_BEGIN
	col.add_theme_constant_override("separation", 4)
	parent.add_child(col)
	var number := look.label("0", HudTheme.MEDIUM, GameTheme.INK, true)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if rider else HORIZONTAL_ALIGNMENT_LEFT
	var unit := _caption("W", GameTheme.MUTED)
	unit.size_flags_vertical = Control.SIZE_SHRINK_END
	col.add_child(number)
	col.add_child(unit)
	return number


## A new bot: its name and its body colour (lifted here until it reads over the dark panel).
func set_bot(display_name: String, body_color: Color) -> void:
	bot_color = ui_color(body_color)
	if bot_name.text != display_name:
		bot_name.text = display_name
	bot_name.add_theme_color_override("font_color", bot_color)
	bot_caption.add_theme_color_override("font_color", bot_color)
	pips.queue_redraw()
	bar.queue_redraw()


## `color`, lightened until it reads as a team colour over the ink panel.
static func ui_color(color: Color) -> Color:
	var c := Color(color, 1.0)
	for i in 8:
		if c.get_luminance() >= 0.5:
			break
		c = c.lerp(Color.WHITE, 0.15)
	return c


## The round state: `mode` "match" (best-of pips, `results` in order, true for a win),
## "ladder" (the rung badge, `rung` from 1) or "endless" (rounds won so far).
func set_rounds(mode: String, best_of: int, results: Array[bool], rung: int) -> void:
	var grew := results.size() > _results.size()
	_mode = mode
	_best_of = maxi(best_of, 1)
	_results = results.duplicate()
	_rung = rung
	_wins = results.count(true)
	_losses = results.count(false)
	_refresh_round()
	if grew:
		GameTheme.pop(pips if pips.visible else badge, 1.3)


## Every frame: the watts, the rope (-1..1), the surge state ("", "telegraph", "surge") and the
## call to action: "" , "pedal" (cadence too low) or "rest" with `rest_sec` left.
func set_state(rider_watts: float, bot_watts_now: float, rope: float, surge_state: String, alert := "", rest_sec := 0) -> void:
	var you_w := roundi(rider_watts / 5.0) * 5
	var bot_w := roundi(bot_watts_now / 5.0) * 5
	var you_text := str(you_w)
	if you_text != _you_text:
		_you_text = you_text
		you_watts.text = you_text
	var bot_text := str(bot_w)
	if bot_text != _bot_text:
		_bot_text = bot_text
		bot_watts.text = bot_text
	var leader := _leader
	if you_w - bot_w >= LEAD_MARGIN:
		leader = 1
	elif bot_w - you_w >= LEAD_MARGIN:
		leader = -1
	if leader != _leader:
		if _leader != 0:
			GameTheme.pop(you_watts if leader > 0 else bot_watts, 1.2)
		_leader = leader
	p = clampf(rope, -1.0, 1.0)
	var px := roundi(p * BAR_SIZE.x * 0.5)
	if px != _bar_px:
		_bar_px = px
		_place_knot()
		bar.queue_redraw()
	var changed := false
	if surge_state != surge:
		surge = surge_state
		_set_knot_alarm()
		changed = true
	if alert != _alert or rest_sec != _rest_sec:
		_alert = alert
		_rest_sec = rest_sec
		changed = true
	# The badge's key is a formatted string: only rebuilt when its inputs change, not per frame.
	if changed:
		_refresh_round()


## The badge (or the pips) for the current state; only re-laid out when it changes.
func _refresh_round() -> void:
	var text := ""
	var fill = null
	var key := ""
	if _alert == "pedal":
		key = "pedal"
		text = tr("PEDAL!")
		fill = Color(GameTheme.WARN.darkened(0.25), 0.96)
	elif surge != "":
		key = "surge"
		text = tr("SURGE!")
		fill = Color(GameTheme.BAD, 0.96)
	elif _alert == "rest":
		key = "rest:%d" % _rest_sec
		text = tr("REST %d") % _rest_sec
		fill = Color(look.ink.lerp(look.accent, 0.25), 0.96)
	elif _mode == "ladder":
		key = "rung:%d" % _rung
		text = tr("RUNG %d") % _rung
	elif _mode == "endless":
		key = "won:%d" % _wins
		text = tr("WON %d") % _wins
		fill = Color(RIDER_COLOR.darkened(0.3), 0.96)
	elif _best_of > MAX_PIPS:
		key = "score:%d-%d" % [_wins, _losses]
		text = "%d-%d" % [_wins, _losses]
	else:
		key = "pips:%d:%s" % [_best_of, str(_results)]
	if key == _badge_key:
		return
	var was_surge := _badge_key == "surge"
	_badge_key = key
	var show_badge := text != ""
	pips.visible = not show_badge
	badge.visible = show_badge
	if show_badge:
		if badge_label.text != text:
			badge_label.text = text
		var style := look.badge_style(fill)
		style.content_margin_top = 0
		style.content_margin_bottom = 2
		style.content_margin_left = 16
		style.content_margin_right = 16
		badge.add_theme_stylebox_override("panel", style)
	else:
		var n := _best_of
		var d := minf(PIP, (PIPS_MAX_WIDTH - PIP_GAP * (n - 1)) / n)
		pips.custom_minimum_size = Vector2(n * d + (n - 1) * PIP_GAP, PIP + 6.0)
		pips.queue_redraw()
	if key == "surge":
		GameTheme.pulse(badge, true)
	elif was_surge:
		GameTheme.pulse(badge, false)


func _place_knot() -> void:
	# Kept inside the bar at the ends, so it never covers the watts beside it.
	var x := clampf(BAR_SIZE.x * 0.5 * (1.0 + p), KNOT * 0.5, BAR_SIZE.x - KNOT * 0.5)
	knot.position = Vector2(x - KNOT * 0.5, (bar.size.y - KNOT) * 0.5)


## The knot flashes during a surge and goes amber in the telegraph: a modulate tween on the
## knot's own node (no redraws).
func _set_knot_alarm() -> void:
	if _knot_tween and _knot_tween.is_valid():
		_knot_tween.kill()
	_knot_tween = null
	match surge:
		"telegraph":
			knot.modulate = GameTheme.WARN.lerp(Color.WHITE, 0.2)
		"surge":
			knot.modulate = Color.WHITE
			_knot_tween = knot.create_tween().set_loops()
			_knot_tween.tween_property(knot, "modulate", GameTheme.BAD.lerp(Color.WHITE, 0.25), 0.22) \
				.set_trans(Tween.TRANS_SINE)
			_knot_tween.tween_property(knot, "modulate", Color.WHITE, 0.22).set_trans(Tween.TRANS_SINE)
		_:
			knot.modulate = Color.WHITE


func _draw_bar() -> void:
	var r := Rect2(Vector2.ZERO, BAR_SIZE)
	var mid := BAR_SIZE.x * 0.5
	if _track == null:
		_track = StyleBoxFlat.new()
		_track.bg_color = Color(look.ink, 0.85)
		_track.set_corner_radius_all(int(BAR_SIZE.y * 0.5))
		_track.border_color = Color(Color.WHITE, 0.35)
		_track.set_border_width_all(3)
		_track.anti_aliasing = true
	bar.draw_style_box(_track, r)
	var x := mid + p * mid
	if absf(x - mid) >= 1.0:
		var fill := RIDER_COLOR if p > 0.0 else bot_color
		var inset := 6.0
		bar.draw_rect(Rect2(minf(mid, x), inset, absf(x - mid), BAR_SIZE.y - inset * 2.0), fill)
	# The centre line: who's past it is winning.
	bar.draw_rect(Rect2(mid - 2.0, 2.0, 4.0, BAR_SIZE.y - 4.0), Color(Color.WHITE, 0.8))


## The rope knot: a rope-coloured disc in an ink ring, drawn as one rounded StyleBox (one draw
## call; circles and lines are a call each).
func _draw_knot() -> void:
	if _knot_box == null:
		_knot_box = StyleBoxFlat.new()
		_knot_box.bg_color = ROPE
		_knot_box.border_color = look.ink
		_knot_box.set_border_width_all(5)
		_knot_box.set_corner_radius_all(int(KNOT * 0.5))
		_knot_box.anti_aliasing = true
	knot.draw_style_box(_knot_box, Rect2(Vector2.ZERO, Vector2(KNOT, KNOT)))


## Best-of pips: won rounds filled in the rider's blue, lost ones in the bot's colour with a
## cross (so it's a shape too), the round being played with an accent ring, the rest empty.
func _draw_pips() -> void:
	var n := _best_of
	var d := minf(PIP, (PIPS_MAX_WIDTH - PIP_GAP * (n - 1)) / n)
	var y := pips.size.y * 0.5
	for i in n:
		var c := Vector2(d * 0.5 + i * (d + PIP_GAP), y)
		var r := d * 0.5
		pips.draw_circle(c, r, look.ink)
		if i < _results.size():
			var won: bool = _results[i]
			pips.draw_circle(c, r - 3.0, RIDER_COLOR if won else bot_color)
			if not won:
				var k := r * 0.42
				pips.draw_line(c + Vector2(-k, -k), c + Vector2(k, k), look.ink, 3.0, true)
				pips.draw_line(c + Vector2(-k, k), c + Vector2(k, -k), look.ink, 3.0, true)
		else:
			pips.draw_circle(c, r - 3.0, Color(Color.WHITE, 0.22))
			if i == _results.size():
				pips.draw_arc(c, r - 1.5, 0.0, TAU, 24, look.accent, 3.0, true)
