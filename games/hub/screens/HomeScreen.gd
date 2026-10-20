class_name HomeScreen
extends HubScreen
## The hub's home (spec §8.3): the header (rider, ride so far, live metrics, camera, Settings,
## Exit games), the FTP nudge when the rider's FTP is the default, a card per game and a card
## per circuit. Every card is baked (one draw call), and a tap opens the game's or circuit's
## screen. A game that needs the camera while it's off is dimmed and says so; a tap explains.
##
##   HomeScreen
##   ├ HubHeader
##   ├ Nudge (HubCard, not a target) + Set FTP (Button)   only when ftp_is_default
##   ├ Games: heading, HBox of HubCard ×5
##   └ Circuits: heading, HBox of HubCard ×3

signal camera_explain(game_id: String)  ## a dimmed card was tapped

const NUDGE_SIZE := Vector2(1400, 104)

var header: HubHeader
var game_cards: Dictionary = {}  ## game_id → HubCard
var circuit_cards: Dictionary = {}  ## circuit id → HubCard
var _column: VBoxContainer
var _signature := ""


func build() -> void:
	header = HubHeader.new(queue)
	header.settings_pressed.connect(func(): open.emit(HubNav.SETTINGS, {}))
	header.exit_pressed.connect(func(): exit_requested.emit())
	add_child(header)
	header.set_state(state)
	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.position = Vector2(HubTheme.MARGIN, HubTheme.HEADER_H)
	_column.size = Vector2(HubTheme.W - 2 * HubTheme.MARGIN, HubTheme.H - HubTheme.HEADER_H - 40)
	_column.add_theme_constant_override("separation", 14)
	_column.alignment = BoxContainer.ALIGNMENT_CENTER  # without the nudge, the rows sit mid-screen
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_column)
	_fill()


func refresh(hub_state: Dictionary) -> void:
	state = hub_state
	header.set_state(state)
	if _content_signature() != _signature:
		for c in _column.get_children():
			c.queue_free()
		game_cards.clear()
		circuit_cards.clear()
		_fill()


## What the cards show: rebuilt only when it changes (bests, the camera, the catalog).
func _content_signature() -> String:
	return JSON.stringify([state.catalog, state.circuits, state.bests, state.camera.available,
		state.rider.ftp_is_default, state.rider.ftp_watts])


func _fill() -> void:
	_signature = _content_signature()
	if bool(state.rider.get("ftp_is_default", false)):
		_column.add_child(_nudge())
	_column.add_child(HubTheme.heading("Play a game"))
	var games := HBoxContainer.new()
	games.name = "Games"
	games.add_theme_constant_override("separation", int(_gap(5, HubTheme.GAME_CARD.x)))
	games.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(games)
	for e in HubState.games(state):
		var card := HubCard.new(game_card(e), HubTheme.GAME_CARD, queue)
		card.name = "Game_" + str(e.id)
		var playable := HubState.playable(state, e)
		card.set_dimmed(not playable)
		var id := str(e.id)
		card.pressed.connect(func():
			if HubState.playable(state, HubState.entry(state, id)):
				open.emit(HubNav.GAME, {"game_id": id})
			else:
				camera_explain.emit(id))
		games.add_child(card)
		game_cards[id] = card
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(spacer)
	_column.add_child(HubTheme.heading("Circuits"))
	var circuits := HBoxContainer.new()
	circuits.name = "Circuits"
	circuits.add_theme_constant_override("separation", int(_gap(5, HubTheme.CIRCUIT_CARD.x)))
	circuits.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(circuits)
	for c in state.circuits:
		var card := HubCard.new(circuit_card(c), HubTheme.CIRCUIT_CARD, queue)
		var id := str(c.id)
		card.name = "Circuit_" + id
		card.pressed.connect(func(): open.emit(HubNav.CIRCUIT, {"circuit_id": id}))
		circuits.add_child(card)
		circuit_cards[id] = card


## The gap that spreads `count` cards of `width` across the column.
static func _gap(count: int, width: float) -> float:
	return floorf((HubTheme.W - 2 * HubTheme.MARGIN - count * width) / (count - 1))


func _nudge() -> Control:
	var row := HBoxContainer.new()
	row.name = "Nudge"
	row.add_theme_constant_override("separation", int(HubTheme.GAP))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	var nudge_style := HubTheme.look().panel_style(Color(HubTheme.look().ink, 0.86), 0.0, 22)
	nudge_style.border_color = GameTheme.WARN
	panel.add_theme_stylebox_override("panel", nudge_style)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 20)
	panel.add_child(line)
	var mark := PanelContainer.new()  # "!" on an amber disc: the warning's shape, not just its colour
	var disc := StyleBoxFlat.new()
	disc.bg_color = GameTheme.WARN
	disc.set_corner_radius_all(30)
	disc.content_margin_left = 22
	disc.content_margin_right = 22
	mark.add_theme_stylebox_override("panel", disc)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.add_child(HubTheme.label("!", HudTheme.BODY, HubTheme.look().ink, true))
	line.add_child(mark)
	var text := HubTheme.label("Set your FTP for the right targets. Games assume %d W." % int(state.rider.get("ftp_watts", 150)),
		HudTheme.BODY, GameTheme.INK, true)
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	line.add_child(text)
	row.add_child(HubCard.new(panel, NUDGE_SIZE, queue, false))
	var set_ftp := HubTheme.button("Set FTP", func(): set_ftp_requested.emit(), GameTheme.PRIMARY,
		Vector2(HubTheme.W - 2 * HubTheme.MARGIN - NUDGE_SIZE.x - HubTheme.GAP, HubTheme.TARGET))
	set_ftp.name = "SetFtp"
	set_ftp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(set_ftp)
	return row


## A game's card: its picture inset evenly, its title, then its best or why it can't start.
func game_card(e: Dictionary) -> Control:
	var id := str(e.id)
	var look := HubTheme.game_look(id)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", card_style(look))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	var inset := HubTheme.PICTURE_INSET
	var pic_size := Vector2(HubTheme.GAME_CARD.x - 2 * inset, (HubTheme.GAME_CARD.x - 2 * inset) * 9.0 / 16.0)
	box.add_child(HubArt.picture(id, pic_size, HubTheme.CARD_RADIUS - inset))
	var info := GameRegistry.info(id)
	var title_text: String = info.title if info else str(e.title)
	var title := HubTheme.label(title_text, fit_size(title_text, HubTheme.CARD_TITLE, pic_size.x), GameTheme.INK, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	title.custom_minimum_size = Vector2(pic_size.x, 0)
	box.add_child(title)
	box.add_child(_best_line(e))
	return panel


func _best_line(e: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	if not HubState.playable(state, e):
		row.add_child(HubTheme.label("Needs the camera", HudTheme.SMALL, GameTheme.WARN, true))
		return row
	var best := HubState.game_best(state, str(e.id))
	if best.is_empty():
		row.add_child(HubTheme.label("Not played yet", HudTheme.SMALL, GameTheme.MUTED, true))
		return row
	row.add_child(HubTheme.label("Best %d" % best.score, HudTheme.SMALL, GameTheme.TARGET, true))
	var stars := StarRow.new(int(best.stars), 30.0)
	stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(stars)
	return row


## The largest text size, from `size` down to HudTheme.SMALL, at which `text` fits `width`.
static func fit_size(text: String, size: int, width: float) -> int:
	var font := GameTheme.display_font()
	var s := size
	while s > HudTheme.SMALL and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > width:
		s -= 2
	return s


## A circuit's card: its length, its time, its lineup as pills, and its best.
func circuit_card(c: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var style := card_style(HubTheme.look())
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 12
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	box.add_child(top)
	var minutes := HubTheme.look().label("%d MIN" % int(c.get("minutes", 0)), HudTheme.MEDIUM, GameTheme.INK, false)
	top.add_child(minutes)
	var strip := LineupStrip.new(c.get("slots", []), Vector2(HubTheme.CIRCUIT_CARD.x - 48, 30))
	box.add_child(strip)
	# The time on its own line: beside "20 MIN" it would widen the card past its bake.
	var line := HubTheme.label("%s · %d games" % [HubTheme.duration(int(c.get("total_sec", -1))),
		(c.get("slots", []) as Array).size()], HudTheme.SMALL, GameTheme.MUTED, true)
	line.clip_text = true
	box.add_child(line)
	var best := HubState.circuit_best(state, str(c.id))
	var best_row := HBoxContainer.new()
	best_row.add_theme_constant_override("separation", 12)
	box.add_child(best_row)
	if best.is_empty():
		best_row.add_child(HubTheme.label("Not ridden yet", HudTheme.SMALL, GameTheme.MUTED, true))
	else:
		best_row.add_child(HubTheme.label("Best %d" % best.score, HudTheme.SMALL, GameTheme.TARGET, true))
	return panel


## A card's panel: the look's ink, an accent edge and a thicker bottom edge, upright.
static func card_style(look: GameTheme) -> StyleBoxFlat:
	var s := look.panel_style(Color(look.ink.lerp(look.accent, 0.16), 0.97), 0.0, HubTheme.CARD_RADIUS)
	s.set_border_width_all(4)
	s.border_width_bottom = 10
	s.content_margin_left = HubTheme.PICTURE_INSET
	s.content_margin_right = HubTheme.PICTURE_INSET
	s.content_margin_top = HubTheme.PICTURE_INSET
	s.content_margin_bottom = 10
	s.shadow_size = 0  # baked: the shadow would be clipped by the bake's edge
	return s


func targets() -> Array[Control]:
	var out: Array[Control] = []
	out.append_array(header.targets())
	for card in game_cards.values():
		out.append(card.hit)
	for card in circuit_cards.values():
		out.append(card.hit)
	var nudge := _column.get_node_or_null("Nudge/SetFtp")
	if nudge:
		out.append(nudge)
	return out
