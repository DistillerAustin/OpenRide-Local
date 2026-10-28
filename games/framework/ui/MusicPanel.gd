class_name MusicPanel
extends CanvasLayer
## The rider's own music (docs/GAMES.md, "Music panel"), over the hub or a game: the track from
## their music app (`Session.now_playing`) with its art, title and artist, and previous,
## play/pause and next as big targets (`Session.music_control`). The hub header's ♪ and the
## HUD's Music button open it; in a game, SessionDirector pauses the ride while it's open and
## resumes it on Done (rider's ask, 2026-10-27). Done, or a tap outside the card, closes it.
## With nothing playing it says so, and how to start some.
##
## Previous and next stay in place, faded, when the app doesn't offer them (Pandora has no
## previous), so nothing shifts under a thumb.

## Done, or a tap outside: SessionDirector resumes a ride it paused for the panel.
signal closed

const LAYER := 27  ## over the HUD (10), intro card (20) and calibration (25); under pause (30)
const CARD_SIZE := Vector2(1240, 560)
const ART := 400.0
const CONTROL_SIZE := Vector2(150, 140)

var card: PanelContainer
var art: TextureRect
var art_note: Control
var title_label: Label
var artist_label: Label
var previous_button: IconButton
var play_button: IconButton
var next_button: IconButton
var done_button: Button
var track: Dictionary = {}


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var look := GameTheme.house()  # the app's own look, over the hub or any game
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.size = Vector2(HudTheme.W, HudTheme.H)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var shade := Button.new()  # a tap outside the card closes it
	shade.name = "Shade"
	shade.flat = true
	shade.focus_mode = Control.FOCUS_NONE
	shade.size = Vector2(HudTheme.W, HudTheme.H)
	shade.pressed.connect(close)
	add_child(shade)

	card = PanelContainer.new()
	card.name = "Card"
	var card_style := look.card_style()
	card_style.bg_color.a = 1.0  # solid: the hub's cards showed through the pause card's 96 %
	card.add_theme_stylebox_override("panel", card_style)
	card.size = CARD_SIZE
	card.position = (Vector2(HudTheme.W, HudTheme.H) - CARD_SIZE) / 2.0
	add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	card.add_child(row)

	var art_box := Control.new()
	art_box.custom_minimum_size = Vector2(ART, ART)
	art_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(art_box)
	art = TextureRect.new()
	art.size = Vector2(ART, ART)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art_box.add_child(art)
	art_note = _NoteSquare.new()  # no art: a note on a plain square
	art_note.size = Vector2(ART, ART)
	art_box.add_child(art_note)

	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 24)  # the hub's gap between targets
	row.add_child(side)
	title_label = look.label("", HudTheme.MEDIUM, GameTheme.INK, true)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.max_lines_visible = 2
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.custom_minimum_size = Vector2(CARD_SIZE.x - ART - 140, 0)
	side.add_child(title_label)
	artist_label = look.label("", HudTheme.BODY, GameTheme.MUTED, true)
	artist_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	artist_label.clip_text = true
	side.add_child(artist_label)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(fill)
	var controls := HBoxContainer.new()
	controls.name = "Controls"
	controls.add_theme_constant_override("separation", int(HubTheme.GAP))
	side.add_child(controls)
	previous_button = _control("previous", "previous")
	controls.add_child(previous_button)
	play_button = _control("play", "play_pause")
	controls.add_child(play_button)
	next_button = _control("next", "next")
	controls.add_child(next_button)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(gap)
	done_button = HudTheme.button("Done", close)
	look.style_button(done_button, GameTheme.GO)
	done_button.name = "Done"
	done_button.custom_minimum_size = Vector2(220, CONTROL_SIZE.y)  # on the controls' line, as tall
	controls.add_child(done_button)

	Session.now_playing_changed.connect(set_track)
	set_track(Session.now_playing)


func open() -> void:
	set_track(Session.now_playing)
	visible = true


func close() -> void:
	if visible:
		visible = false
		closed.emit()


func is_open() -> bool:
	return visible


## From Session.now_playing ({} when nothing plays).
func set_track(new_track: Dictionary) -> void:
	track = new_track
	var has := not track.is_empty()
	title_label.text = str(track.get("title", "")) if has else "Nothing playing"
	artist_label.text = str(track.get("artist", "")) if has else "Start music in your music app. It shows here."
	art.texture = AvatarView.load_png(track.get("art", "")) if has else null
	art_note.visible = art.texture == null
	play_button.set_icon("pause" if bool(track.get("playing", false)) else "play")
	play_button.set_enabled(has)
	previous_button.set_enabled(has and bool(track.get("can_previous", true)))
	next_button.set_enabled(has and bool(track.get("can_next", true)))


## The touch targets (for layout checks).
func targets() -> Array[Control]:
	return [previous_button, play_button, next_button, done_button]


func _control(icon: String, word: String) -> IconButton:
	var b := IconButton.new(icon, func(): Session.music_control(word))
	b.custom_minimum_size = CONTROL_SIZE
	return b


## The art's stand-in: a drawn note on a faint square (the display face has no ♪).
class _NoteSquare extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.08))
		var b := ShapeBatch.new()
		b.note(size / 2.0, 3.0, Color(1, 1, 1, 0.35))
		b.draw(self)
