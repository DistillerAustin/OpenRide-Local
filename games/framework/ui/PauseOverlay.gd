class_name PauseOverlay
extends CanvasLayer
## The pause screen (Resume, End session) and the end-session confirmation. Session shows the
## pause screen on session_paused, whether the rider or auto-pause paused, and the
## confirmation from the HUD's End button or the pause screen's.

signal resume_pressed
signal end_confirmed
## The rider picked a new value for one of the game's options (`GameInfo.options`).
signal option_changed(key: String, value: String)

const LAYER := 30
## The kit's plain button colours by kind.
const PLAIN_COLOURS := {GameTheme.GO: Color(0.16, 0.45, 0.3), GameTheme.DANGER: Color(0.45, 0.16, 0.2)}

var _paused_box: VBoxContainer
var _confirm_box: VBoxContainer
var _options_box: VBoxContainer
var _options_button: Button
var _paused := false
## The game's declared options, and a getter for an option's current value.
var _options: Array[Dictionary] = []
var _value_of: Callable
## The game's look (`Game.ui_theme()`), or null for the kit's plain cards.
var theme: GameTheme
var _cards: Array[PanelContainer] = []


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	Stage.bleed(shade)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	_paused_box = _card("Paused", "Tap Resume to carry on.")
	_paused_box.add_child(_button("Resume", func(): resume_pressed.emit(), GameTheme.GO))
	_options_button = _button("Game options", show_options)
	_options_button.visible = false
	_paused_box.add_child(_options_button)
	_paused_box.add_child(_button("End session", show_confirm, GameTheme.DANGER))

	_options_box = _card("Game options", "Remembered for you, for this game.")

	_confirm_box = _card("End the session?", "Your ride so far is saved.")
	_confirm_box.add_child(_button("End session", func(): hide_confirm(); end_confirmed.emit(), GameTheme.DANGER))
	_confirm_box.add_child(_button("Keep riding", hide_confirm, GameTheme.GO))


## Styles the cards in a game's look (`Game.ui_theme()`): the card, the display face and pill
## buttons (Resume, Keep riding and Back green, End session red, the rest secondary). null puts
## the kit's plain cards back.
func apply_theme(new_theme: GameTheme) -> void:
	theme = new_theme
	for card in _cards:
		card.add_theme_stylebox_override("panel", theme.card_style() if theme else HudTheme.panel_style(HudTheme.CARD, 32))
		for node in card.find_children("*", "Label", true, false):
			var l := node as Label
			var heading: bool = l.get_meta(&"heading", false)
			if theme:
				theme.style_label(l, HudTheme.BIG if heading else HudTheme.BODY, GameTheme.INK if heading else GameTheme.MUTED, true)
				# On the solid card: no drop shadow on the heading and no outline on the line
				# under it. Each is another text pass; together they cost 3 draw calls a frame.
				if heading:
					theme.set_gradient(l)
					l.remove_theme_color_override("font_shadow_color")
				else:
					l.add_theme_constant_override("outline_size", 0)
			else:
				HudTheme.style_label(l, HudTheme.BIG if heading else HudTheme.BODY, HudTheme.INK if heading else HudTheme.MUTED)
		for node in card.find_children("*", "Button", true, false):
			_style(node as Button)


## A pause-screen button of a kind (GameTheme.GO, DANGER or SECONDARY), so a theme can restyle it.
func _button(text: String, action: Callable, kind := GameTheme.SECONDARY) -> Button:
	var b := HudTheme.button(text, action)
	b.set_meta(&"kind", kind)
	_style(b)
	return b


func _style(b: Button) -> void:
	var kind: String = b.get_meta(&"kind", GameTheme.SECONDARY)
	if theme:
		theme.style_button(b, kind)
	else:
		HudTheme.style_button(b, PLAIN_COLOURS.get(kind, Color(0.22, 0.28, 0.5)))


## The current game's options (`GameInfo.options`); `value_of(key) -> String` reads one. Only
## those with `where` pause or both show (a hub-only pick, like Kart Race's kart, doesn't). No
## such option hides the "Game options" button.
func set_options(options: Array[Dictionary], value_of: Callable) -> void:
	_options.assign(options.filter(func(o): return GameInfo.option_where(o) != "hub"))
	options = _options
	_value_of = value_of
	_options_button.visible = not options.is_empty()
	for child in _options_box.get_children().slice(2):
		child.queue_free()
	for spec in options:
		var key := str(spec.key)
		var button := _button("", func(): _cycle(key))
		button.name = "Option_%s" % key
		_options_box.add_child(button)
	_options_box.add_child(_button("Back", hide_options, GameTheme.GO))
	_refresh_options()


func show_options() -> void:
	_refresh_options()
	_paused_box.get_parent().visible = false
	_options_box.get_parent().visible = true


func hide_options() -> void:
	set_paused(_paused)


func is_showing_options() -> bool:
	return visible and _options_box.get_parent().visible


func _cycle(key: String) -> void:
	for spec in _options:
		if spec.key == key:
			option_changed.emit(key, GameOptions.next_choice(spec, str(_value_of.call(key))))
	_refresh_options()


func _refresh_options() -> void:
	if not _value_of.is_valid():
		return
	for spec in _options:
		var button := _options_box.get_node_or_null("Option_%s" % spec.key) as Button
		if button:
			button.text = "%s: %s" % [spec.label, GameOptions.label_for(spec, str(_value_of.call(spec.key)))]


func set_paused(paused: bool) -> void:
	_paused = paused
	_confirm_box.get_parent().visible = false
	_options_box.get_parent().visible = false
	_paused_box.get_parent().visible = paused
	visible = paused


func show_confirm() -> void:
	_paused_box.get_parent().visible = false
	_options_box.get_parent().visible = false
	_confirm_box.get_parent().visible = true
	visible = true


func hide_confirm() -> void:
	set_paused(_paused)


func is_confirming() -> bool:
	return visible and _confirm_box.get_parent().visible


func _card(heading: String, line: String) -> VBoxContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", HudTheme.panel_style(HudTheme.CARD, 32))
	card.custom_minimum_size = Vector2(900, 0)
	card.position = Vector2(HudTheme.W / 2 - 450, 220)
	card.visible = false
	add_child(card)
	_cards.append(card)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 28)
	card.add_child(box)
	var title := HudTheme.label(heading, HudTheme.BIG)
	title.set_meta(&"heading", true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var text := HudTheme.label(line, HudTheme.BODY, HudTheme.MUTED)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(text)
	return box
