class_name KartPicker
extends CanvasLayer
## The kart and track pick screen (#43, rider request 2026-10-19): the first thing a Kart Race
## session shows once gameplay starts, before the title fly-over and the grid's 3-2-1-GO. One
## screen, two choices and a Start button, all big enough to hit while pedalling:
##
##   top left      the title and a one-line how-to
##   left          1 · YOUR KART: the eight racers as cards (portrait, name, kart colour, class)
##   right         the chosen kart up close: a big portrait, the rider's name, "driving Juniper
##                 the fox", the class and its feel, the racer's tagline
##   bottom left   2 · STARTING TRACK: the four courses as cards with baked thumbnails
##   bottom right  START!, with the auto-start count under it
##
## Nothing touchable sits within 120 px of the framework's End (top right): the kart detail is
## only a picture, and Start is in the bottom-right corner. Every card is at least 180 px.
##
## It starts by itself AUTO_SEC after it opens, with whatever is selected (the rider's last kart
## and track): the rider may not want to tap while pedalling. Any tap on a choice restarts that
## count. The game ticks it (`advance`) from its frame, so pausing freezes it.
##
## The tablet's budget: everything is drawn into five bakes (KartBaked: the header, the kart grid,
## the detail, the track row, the Start button), which render only when a selection or the
## count's whole second changes. The hit areas are bare Buttons over them that draw nothing.

## The rider confirmed (Start, or the count ran out): race this kart from this track.
signal started(racer_id: String, track_id: String)
## The selection changed (a tap): for the game's options and tests.
signal changed(racer_id: String, track_id: String)

const LAYER := 9  ## with the boards: under the framework HUD (10), over the 3D view and KartHud
const W := 1920.0
const H := 1080.0
const M := 40.0
const AUTO_SEC := 20.0
## Touch targets: every card's shorter side is at least this (the bike's "huge targets").
const MIN_TARGET := 180.0
const HEADER_RECT := Rect2(M, 26, 1200, 160)
const KART_HEAD_Y := 190.0
const KART_CARD := Vector2(214, 186)
const KART_GAP := 14.0
const KART_COLS := 4
const KART_GRID_POS := Vector2(M, 240)
## Under the framework's clock and Recalibrate | Pause | End (they end at about y 290) and left
## of End (about x 1720-1880): nothing of the picker is drawn near End either.
const DETAIL_RECT := Rect2(966, 318, 600, 308)
const TRACK_HEAD_Y := 632.0
const TRACK_CARD := Vector2(300, 254)
const TRACK_GAP := 18.0
const TRACK_ROW_POS := Vector2(M, 682)
const THUMB := Vector2(284, 160)
const START_RECT := Rect2(1330, 682, 550, 254)
const THUMBS := "res://games/kart_race/ui/tracks/%s.png"
## A kart class's feel: weight only matters in a bump (KartRoster.weight, kart-kart contacts).
const CLASS_FEEL := {
	"light": "Light kart · nimble, but bumped around",
	"medium": "Medium kart · holds its own in a bump",
	"heavy": "Heavy kart · shoves the others aside",
}

var racers: Array = []  ## KartRoster entries, roster order
var track_ids: Array = []
var racer_id := ""
var track_id := ""
var rider_name := "You"
var auto_left := AUTO_SEC
## Whether it's waiting for a pick (open and not yet started).
var picking := false
var portrait_maker: Callable  ## (racer_id, size, you) -> Control (KartHud.portrait_rect)
## Bakes, for tests and the render probe: header, karts, detail, tracks, start.
var bakes: Array[KartBaked] = []
var kart_buttons := {}  ## racer id -> Button
var track_buttons := {}  ## track id -> Button
var start_button: Button

var _root: Control
var _backdrop: ColorRect
var _karts: Control
var _kart_cards := {}  ## racer id -> Panel
var _detail: Control
var _detail_view: KartBaked
var _detail_pic: Control
var _detail_name: Label
var _detail_driving: Label
var _detail_class: Label
var _detail_tag: Label
var _detail_swatch: Panel
var _tracks: Control
var _track_cards := {}  ## track id -> Panel
var _start: Control
var _start_count: Label
var _shown_count := -1
var _loading: Control
var _loading_label: Label
var _loading_pic: TextureRect
var _queue := KartBakeQueue.new()


func _init() -> void:
	layer = LAYER
	visible = false
	_root = Control.new()
	_root.name = "Picker"
	_root.size = Vector2(W, H)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	# A deep violet wash over the grid (the 3D view holds still behind it).
	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.size = _root.size
	_backdrop.color = Color(0.1, 0.05, 0.24, 0.72)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_backdrop)
	_queue.per_frame = 2


## Opens the picker: `roster` (KartRoster entries), `tracks` (track ids, cup order), the rider's
## last kart and track, and their name for the detail. The count starts at AUTO_SEC.
func open(roster: Array, tracks: Array, pick_racer: String, pick_track: String, name_shown: String) -> void:
	racers = roster.duplicate()
	track_ids = tracks.duplicate()
	rider_name = name_shown
	racer_id = pick_racer if _has_racer(pick_racer) else str(racers[0].id)
	track_id = pick_track if track_ids.has(pick_track) else str(track_ids[0])
	_build()
	_restyle()
	auto_left = AUTO_SEC
	_shown_count = -1
	_update_count()
	picking = true
	visible = true
	_loading.visible = false
	for b in bakes:
		b.pivot_offset = b.size * 0.5
	var header: KartBaked = bakes[0]
	header.scale = Vector2(0.6, 0.6)
	header.create_tween().tween_property(header, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The game's frame: counts down to the auto-start. Returns true on the frame it starts.
func advance(delta: float) -> bool:
	if not picking:
		return false
	auto_left -= delta
	_update_count()
	if auto_left <= 0.0:
		start()
		return true
	return false


## The rider tapped a kart: select it and restart the count.
func select_racer(id: String) -> void:
	if not picking or not _has_racer(id):
		return
	auto_left = AUTO_SEC
	_update_count()
	if id == racer_id:
		return
	racer_id = id
	_restyle()
	_detail_view.scale = Vector2(0.92, 0.92)
	_detail_view.create_tween().tween_property(_detail_view, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	changed.emit(racer_id, track_id)


## The rider tapped a track: select it and restart the count.
func select_track(id: String) -> void:
	if not picking or not track_ids.has(id):
		return
	auto_left = AUTO_SEC
	_update_count()
	if id == track_id:
		return
	track_id = id
	_restyle()
	changed.emit(racer_id, track_id)


## Start (the button or the count): once.
func start() -> void:
	if not picking:
		return
	picking = false
	started.emit(racer_id, track_id)


## Seconds until it starts by itself (as shown: whole seconds, rounded up).
func seconds_left() -> int:
	return ceili(maxf(auto_left, 0.0))


## A short "building the track" card while the game builds a track other than the one behind
## (the choices hide; the game builds a frame or two later, so this shows first).
func show_loading(title: String, chosen_track: String) -> void:
	for b in bakes:
		b.visible = false
	for b in _buttons():
		b.visible = false
	_loading_label.text = "Building %s…" % title
	_loading_pic.texture = thumbnail(chosen_track)
	_loading.visible = true


func close() -> void:
	picking = false
	visible = false
	for b in bakes:
		if is_instance_valid(b):
			b.queue_free()
	bakes.clear()
	for b in _buttons():
		b.queue_free()
	kart_buttons.clear()
	track_buttons.clear()
	start_button = null
	if _loading:
		_loading.queue_free()
		_loading = null


## The track's baked thumbnail (tests/capture_track_thumbs.gd), or null.
static func thumbnail(id: String) -> Texture2D:
	var path := THUMBS % id
	return load(path) if ResourceLoader.exists(path) else null


## Every touch target with its screen rect: [{id, kind, rect}] (kind "kart", "track", "start").
func targets() -> Array:
	var out := []
	for id in kart_buttons:
		out.append({"id": id, "kind": "kart", "rect": (kart_buttons[id] as Control).get_global_rect()})
	for id in track_buttons:
		out.append({"id": id, "kind": "track", "rect": (track_buttons[id] as Control).get_global_rect()})
	if start_button:
		out.append({"id": "start", "kind": "start", "rect": start_button.get_global_rect()})
	return out


func kart_card_rect(i: int) -> Rect2:
	var col := i % KART_COLS
	var row := i / KART_COLS
	return Rect2(KART_GRID_POS + Vector2(col * (KART_CARD.x + KART_GAP), row * (KART_CARD.y + KART_GAP)), KART_CARD)


func track_card_rect(i: int) -> Rect2:
	return Rect2(TRACK_ROW_POS + Vector2(i * (TRACK_CARD.x + TRACK_GAP), 0.0), TRACK_CARD)


# --- Building ---

func _build() -> void:
	close()
	visible = false
	_kart_cards.clear()
	_track_cards.clear()
	_build_header()
	_build_karts()
	_build_detail()
	_build_tracks()
	_build_start()
	_build_loading()


func _bake(w: Control, bake_size := Vector2.ZERO) -> KartBaked:
	_root.add_child(w)
	var b := KartBaked.new(w, _root, bake_size)
	b.queue = _queue
	bakes.append(b)
	return b


func _build_header() -> void:
	var header := Control.new()
	header.name = "Header"
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.position = HEADER_RECT.position
	header.size = HEADER_RECT.size
	var title := KartTheme.label("PICK YOUR RIDE", 96, KartTheme.INK)
	title.name = "Title"
	title.size = Vector2(HEADER_RECT.size.x, 110)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 24)
	KartTheme.gradient(title, KartTheme.GOLD_TOP, KartTheme.GOLD_BOTTOM)
	header.add_child(title)
	var sub := KartTheme.label("Tap a kart and a track, or just ride: it starts by itself", 34, KartTheme.CHIP)
	sub.name = "Subtitle"
	sub.position = Vector2(6, 110)
	sub.size = Vector2(HEADER_RECT.size.x, 46)
	header.add_child(sub)
	_bake(header)


func _section_label(parent: Control, text: String, at: Vector2) -> void:
	var l := KartTheme.label(text, 38, KartTheme.INK)
	l.position = at
	l.size = Vector2(700, 48)
	parent.add_child(l)


func _build_karts() -> void:
	_karts = Control.new()
	_karts.name = "Karts"
	_karts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_karts.position = Vector2(0, KART_HEAD_Y)
	var last := kart_card_rect(racers.size() - 1)
	_karts.size = Vector2(KART_GRID_POS.x + KART_COLS * (KART_CARD.x + KART_GAP), last.end.y - KART_HEAD_Y)
	_section_label(_karts, "1 · YOUR KART", Vector2(M + 4, 0))
	for i in racers.size():
		var r: Dictionary = racers[i]
		var rect := kart_card_rect(i)
		var card := Panel.new()
		card.name = "Kart_%s" % r.id
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.position = rect.position - _karts.position
		card.size = rect.size
		_karts.add_child(card)
		_kart_cards[str(r.id)] = card
		if portrait_maker.is_valid():
			var pic: Control = portrait_maker.call(str(r.id), 104.0, false)
			pic.position = Vector2((rect.size.x - 104.0) * 0.5, 12)
			card.add_child(pic)
		var name_label := KartTheme.label(str(r.name), 34, KartTheme.INK, true)
		name_label.name = "Name"
		name_label.position = Vector2(0, 112)
		name_label.size = Vector2(rect.size.x, 40)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(name_label)
		var cls := KartTheme.label(KartRoster.kart_class(r).to_upper(), 24, KartTheme.INK, true)
		cls.name = "Class"
		cls.position = Vector2(0, 148)
		cls.size = Vector2(rect.size.x, 30)
		cls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cls.add_theme_constant_override("outline_size", 6)
		card.add_child(cls)
		var b := _hit_button("KartHit_%s" % r.id, rect)
		var id := str(r.id)
		b.pressed.connect(func(): select_racer(id))
		kart_buttons[id] = b
	_bake(_karts)


func _build_detail() -> void:
	_detail = Panel.new()
	_detail.name = "Detail"
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.position = DETAIL_RECT.position
	_detail.size = DETAIL_RECT.size
	_detail.add_theme_stylebox_override("panel", KartTheme.badge(KartTheme.PANEL, 0.03, 22))
	_detail_pic = Control.new()  # replaced by the chosen racer's portrait in _restyle
	_detail.add_child(_detail_pic)
	_detail_name = KartTheme.label("", 74, KartTheme.INK)
	_detail_name.name = "RiderName"
	_detail_name.position = Vector2(206, 10)
	_detail_name.size = Vector2(374, 92)
	_detail_name.clip_text = true
	KartTheme.gradient(_detail_name, KartTheme.GOLD_TOP, KartTheme.GOLD_BOTTOM)
	_detail.add_child(_detail_name)
	_detail_driving = KartTheme.label("", 32, KartTheme.CHIP, true)
	_detail_driving.position = Vector2(210, 100)
	_detail_driving.size = Vector2(370, 84)
	_detail_driving.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(_detail_driving)
	_detail_swatch = Panel.new()
	_detail_swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_swatch.position = Vector2(24, 192)
	_detail_swatch.size = Vector2(552, 50)
	_detail.add_child(_detail_swatch)
	_detail_class = KartTheme.label("", 30, KartTheme.INK, true)
	_detail_class.position = Vector2(40, 192)
	_detail_class.size = Vector2(520, 50)
	_detail_class.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail.add_child(_detail_class)
	_detail_tag = KartTheme.label("", 34, KartTheme.INK)
	_detail_tag.position = Vector2(26, 246)
	_detail_tag.size = Vector2(552, 50)
	_detail_tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(_detail_tag)
	_detail_view = _bake(_detail, DETAIL_RECT.size + KartRaceBoard.SHADOW_ROOM)


func _build_tracks() -> void:
	_tracks = Control.new()
	_tracks.name = "Tracks"
	_tracks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tracks.position = Vector2(0, TRACK_HEAD_Y)
	var last := track_card_rect(track_ids.size() - 1)
	_tracks.size = Vector2(last.end.x + 16, last.end.y - TRACK_HEAD_Y + 16)
	_section_label(_tracks, "2 · STARTING TRACK", Vector2(M + 4, 0))
	for i in track_ids.size():
		var id := str(track_ids[i])
		var rect := track_card_rect(i)
		var card := Panel.new()
		card.name = "Track_%s" % id
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.position = rect.position - _tracks.position
		card.size = rect.size
		_tracks.add_child(card)
		_track_cards[id] = card
		var pic := TextureRect.new()
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.texture = thumbnail(id)
		pic.position = Vector2((rect.size.x - THUMB.x) * 0.5, 8)
		pic.size = THUMB
		card.add_child(pic)
		var title := KartTheme.label(_track_title(id), 36, KartTheme.INK, true)
		title.name = "Name"
		title.position = Vector2(0, THUMB.y + 14)
		title.size = Vector2(rect.size.x, 44)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(title)
		var length := KartTheme.label("%s m" % _thousands(roundi(KartTracks.length_of(id))), 26, KartTheme.INK, true)
		length.name = "Length"
		length.position = Vector2(0, THUMB.y + 56)
		length.size = Vector2(rect.size.x, 32)
		length.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		length.add_theme_constant_override("outline_size", 6)
		card.add_child(length)
		var b := _hit_button("TrackHit_%s" % id, rect)
		b.pressed.connect(func(): select_track(id))
		track_buttons[id] = b
	_bake(_tracks)


func _build_start() -> void:
	_start = Panel.new()
	_start.name = "Start"
	_start.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_start.position = START_RECT.position
	_start.size = START_RECT.size
	var style := KartTheme.badge(Color(0.22, 0.78, 0.34), 0.12, 28, Color(0.85, 1.0, 0.6))
	style.border_width_bottom = 12
	style.border_color = Color(0.1, 0.42, 0.18)
	_start.add_theme_stylebox_override("panel", style)
	var go := KartTheme.label("START!", 108, KartTheme.INK)
	go.position = Vector2(0, 26)
	go.size = Vector2(START_RECT.size.x, 130)
	go.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	go.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	go.add_theme_constant_override("outline_size", 22)
	KartTheme.gradient(go, KartTheme.GOLD_TOP, KartTheme.GOLD_BOTTOM)
	_start.add_child(go)
	_start_count = KartTheme.label("", 36, KartTheme.INK, true)
	_start_count.name = "Count"
	_start_count.position = Vector2(0, 166)
	_start_count.size = Vector2(START_RECT.size.x, 48)
	_start_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_start.add_child(_start_count)
	_bake(_start, START_RECT.size + KartRaceBoard.SHADOW_ROOM)
	start_button = _hit_button("StartHit", START_RECT)
	start_button.pressed.connect(start)


func _build_loading() -> void:
	_loading = PanelContainer.new()
	_loading.name = "Loading"
	_loading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading.add_theme_stylebox_override("panel", KartTheme.badge(KartTheme.PANEL, 0.08, 26))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	_loading.add_child(box)
	_loading_pic = TextureRect.new()
	_loading_pic.custom_minimum_size = THUMB * 2.0
	_loading_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_loading_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	box.add_child(_loading_pic)
	_loading_label = KartTheme.label("", 64, KartTheme.INK)
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	KartTheme.gradient(_loading_label, KartTheme.GOLD_TOP, KartTheme.GOLD_BOTTOM)
	box.add_child(_loading_label)
	_loading.visible = false
	_root.add_child(_loading)
	_loading.size = Vector2(760, 520)
	_loading.position = (Vector2(W, H) - _loading.size) * 0.5


## A touch target that draws nothing: the bake under it is the picture.
func _hit_button(node_name: String, rect: Rect2) -> Button:
	var b := Button.new()
	b.name = node_name
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.position = rect.position
	b.size = rect.size
	_root.add_child(b)
	return b


func _buttons() -> Array:
	var out := kart_buttons.values() + track_buttons.values()
	if start_button:
		out.append(start_button)
	return out


# --- Showing the selection ---

## Every card's look for the current selection, and the detail for the chosen kart.
func _restyle() -> void:
	for id in _kart_cards:
		var r := KartRoster.racer(id)
		var on: bool = id == racer_id
		var card: Panel = _kart_cards[id]
		card.add_theme_stylebox_override("panel", _card_style(on, r.get("color", KartTheme.PANEL_EDGE)))
		(card.get_node("Name") as Label).add_theme_color_override("font_color", KartTheme.CHIP if on else KartTheme.INK)
	for id in _track_cards:
		var on: bool = id == track_id
		var card: Panel = _track_cards[id]
		card.add_theme_stylebox_override("panel", _card_style(on, KartTheme.PANEL_EDGE))
		(card.get_node("Name") as Label).add_theme_color_override("font_color", KartTheme.CHIP if on else KartTheme.INK)
	var r := KartRoster.racer(racer_id)
	_detail_pic.queue_free()
	if portrait_maker.is_valid():
		_detail_pic = portrait_maker.call(racer_id, 164.0, true)
	else:
		_detail_pic = Control.new()
	_detail_pic.position = Vector2(26, 16)
	_detail.add_child(_detail_pic)
	_detail_name.text = rider_name
	var font_size := KartRacerList.fit_size(rider_name, _detail_name.size.x - 10.0, 74, 40)
	_detail_name.add_theme_font_size_override("font_size", font_size)
	KartTheme.gradient(_detail_name, KartTheme.GOLD_TOP, KartTheme.GOLD_BOTTOM)  # fits the new size
	_detail_driving.text = "driving %s the %s" % [r.name, r.species]
	var swatch := KartTheme.badge(Color(r.get("color", KartTheme.PANEL_EDGE)).darkened(0.15), 0.18, 12, Color(1, 1, 1, 0.6))
	swatch.content_margin_left = 0
	_detail_swatch.add_theme_stylebox_override("panel", swatch)
	_detail_class.text = CLASS_FEEL.get(KartRoster.kart_class(r), "")
	_detail_class.add_theme_font_size_override("font_size", KartRacerList.fit_size(_detail_class.text, _detail_class.size.x, 30, 22))
	_detail_tag.text = "“%s”" % str(r.get("tagline", ""))


func _card_style(on: bool, accent: Color) -> StyleBoxFlat:
	var s := KartTheme.badge(Color(0.32, 0.2, 0.66, 0.96) if on else KartTheme.NIGHT, 0.06, 18,
		KartTheme.CHIP if on else Color(0.55, 0.42, 1.0, 0.55))
	s.set_border_width_all(7 if on else 3)
	s.border_width_bottom = 14
	# The kart's colour as the card's bottom edge (the gold ring marks the pick).
	if accent != KartTheme.PANEL_EDGE:
		s.border_color = KartTheme.CHIP if on else accent
	s.content_margin_left = 0
	s.content_margin_right = 0
	return s


func _update_count() -> void:
	var n := seconds_left()
	if n == _shown_count or _start_count == null:
		return
	_shown_count = n
	_start_count.text = "Starts by itself in %d" % n


func _has_racer(id: String) -> bool:
	for r in racers:
		if str(r.id) == id:
			return true
	return false


static func _track_title(id: String) -> String:
	var i := KartTracks.CUP.find(id)
	return str(KartTracks.titles()[i]) if i >= 0 else id


static func _thousands(n: int) -> String:
	return "%d,%03d" % [n / 1000, n % 1000] if n >= 1000 else str(n)
