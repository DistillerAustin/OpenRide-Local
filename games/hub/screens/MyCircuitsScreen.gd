class_name MyCircuitsScreen
extends HubScreen
## The rider's saved circuits (spec §8.3 "My circuits"): HubPrefs' three places as baked cards,
## each with its lineup as role-coloured pills, its time, its games and its best (at any
## difficulty). A saved card opens it in the builder (Start, edit, Delete there); an empty one
## opens the builder to fill that place.
##
##   MyCircuitsScreen
##   ├ TopBar: Back, "MY CIRCUITS"
##   └ Cards (HBox): Circuit_0..2 (HubCard)

const BODY_TOP := 210.0
const CARD_H := 500.0

var cards: Array[HubCard] = []
var saved: Array = []


func build() -> void:
	top_bar("My circuits")
	saved = HubPrefs.custom_circuits(rider_id)
	var row := HBoxContainer.new()
	row.name = "Cards"
	row.position = Vector2(HubTheme.MARGIN, BODY_TOP)
	row.add_theme_constant_override("separation", int(HubTheme.GAP * 2))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var w := floorf((HubTheme.W - 2 * HubTheme.MARGIN - HubTheme.GAP * 2 * (HubPrefs.CUSTOM_MAX - 1)) / HubPrefs.CUSTOM_MAX)
	for i in HubPrefs.CUSTOM_MAX:
		var c = saved[i]
		var card := HubCard.new(_card(i, c, w), Vector2(w, CARD_H), queue)
		card.name = "Circuit_%d" % i
		card.pressed.connect(func(): open.emit(HubNav.BUILDER, {"index": i} if c != null else {"index": -1}))
		row.add_child(card)
		cards.append(card)
	var note := HubTheme.label("Saved on this bike for %s. Build up to %d." % [HubTheme.short_name(str(state.rider.get("name", ""))),
		HubPrefs.CUSTOM_MAX], HudTheme.SMALL, GameTheme.MUTED)
	note.position = Vector2(HubTheme.MARGIN, BODY_TOP + CARD_H + 40)
	add_child(note)


func _card(i: int, c, w: float) -> Control:
	var panel := PanelContainer.new()
	var style := HomeScreen.card_style(HubTheme.look())
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 22
	style.content_margin_bottom = 26
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	box.add_child(HubTheme.look().label(HubPrefs.custom_name(i).to_upper(), HudTheme.MEDIUM, GameTheme.INK, false))
	if c == null:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 60)
		box.add_child(spacer)
		var plus := HubTheme.label("+", HudTheme.HUGE, GameTheme.MUTED, true)
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(plus)
		var line := HubTheme.label("Empty: tap to build one", HudTheme.BODY, GameTheme.MUTED, true)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(line)
		return panel
	var b := CircuitBuilder.new(state.catalog, c.get("slots", []), str(c.get("difficulty", "standard")))
	box.add_child(HubTheme.label("%s · %d %s" % [HubTheme.clock(float(b.total_sec())), b.size(), "game" if b.size() == 1 else "games"],
		HudTheme.BODY, GameTheme.INK, true))
	box.add_child(LineupStrip.new(b.lineup(), Vector2(w - 60, 64), true))
	var counts := {}
	for s in b.slots:
		counts[str(s.game_id)] = int(counts.get(str(s.game_id), 0)) + 1
	var names: PackedStringArray = []
	for id in counts:
		names.append("%s ×%d" % [HubTheme.fit_title(id, 9999), counts[id]] if counts[id] > 1 else HubTheme.fit_title(id, 9999))
	var games := HubTheme.label(", ".join(names), HudTheme.SMALL, GameTheme.MUTED, true)
	games.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	games.custom_minimum_size = Vector2(w - 60, 0)
	games.max_lines_visible = 3
	box.add_child(games)
	var best := HubState.circuit_best(state, b.plan_id())
	box.add_child(HubTheme.label("Best %d" % best.score if not best.is_empty() else "Not ridden yet", HudTheme.SMALL,
		GameTheme.TARGET if not best.is_empty() else GameTheme.MUTED, true))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var tap := HubTheme.label("Tap to play or edit  ›", HudTheme.SMALL, GameTheme.INK, true)
	tap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(tap)
	return panel


func targets() -> Array[Control]:
	var out: Array[Control] = []
	_collect(get_node("TopBar"), out)
	for card in cards:
		out.append(card.hit)
	return out


## A saved card's best line (for tests): its plan id's best at any difficulty.
func best_text(i: int) -> String:
	var c = saved[i]
	if c == null:
		return ""
	var best := HubState.circuit_best(state, CircuitBuilder.new(state.catalog, c.slots).plan_id())
	return "Best %d" % best.score if not best.is_empty() else "Not ridden yet"
