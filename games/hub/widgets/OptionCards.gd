class_name OptionCards
extends VBoxContainer
## A `kind: cards` game option on the hub's game screen (spec §7.1-7.2): its heading, then a
## grid of picture cards, one per choice (Kart Race's eight karts and four tracks). A tap picks
## the card at once (the screen saves it: GameOptions, per rider).
##
## Each card is a HubCard: its panel, picture, title and subtitle bake into one texture (one draw
## call), and a flat Button over it takes the tap and pops it. A pick restyles two cards (the
## old and the new): only those two bakes render again. Nothing runs per frame.
##
## The picture sits in a slot inset evenly by PICTURE_INSET from the card's edge, masked to a
## rounded rect of radius CARD_RADIUS - PICTURE_INSET (framework/ui/shaders/rounded_mask), so it
## is concentric with the card's outline: no square corner pokes past it (the rider's bug with
## the old picker's slanted cards). Cards never lean. A wide picture (a track thumbnail) covers
## the slot; a narrower one (a racer's round portrait) is fitted in it, centred.
##
## The chosen card has a thicker gold edge and a gold title (shape and colour, never colour
## alone). With `rider_badge` it also wears the rider's name on a gold chip over its picture.
##
##   OptionCards (VBox)
##   ├ Heading (the option's label)
##   └ Grid (GridContainer, `columns`)
##     └ Card_<value> (HubCard) → PanelContainer → VBox: Slot (picture, badge), Title, Subtitle

signal changed(key: String, value: String)

## The picture slot's height, as a share of its width (a 16:9 thumbnail is cropped a little);
## an option may set its own (`slot_aspect`: the builder's flatter game tiles).
const SLOT_ASPECT := 0.5
const TITLE_H := 54.0
const SUBTITLE_H := 40.0
const BOTTOM := 10.0  ## the card style's bottom content margin
const EDGE := 4  ## a card's edge
const EDGE_CHOSEN := 6
const BADGE_H := 48.0

var spec: Dictionary
var key := ""
var value := ""
var rider_name := ""
var card_size := Vector2.ZERO
var cards: Dictionary = {}  ## value → HubCard
var grid: GridContainer
var _look: GameTheme
var _parts: Dictionary = {}  ## value → {panel, title, badge, accent}


func _init(option: Dictionary, current: String, width: float, queue: BakeQueue, look: GameTheme = null, rider := "") -> void:
	spec = option
	key = str(option.key)
	value = current
	rider_name = rider
	_look = look if look else HubTheme.look()
	name = "Cards_" + key
	add_theme_constant_override("separation", 10)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var heading := HubTheme.heading(str(option.get("label", key)))
	heading.name = "Heading"
	add_child(heading)
	grid = GridContainer.new()
	grid.name = "Grid"
	grid.columns = columns_of(option)
	grid.add_theme_constant_override("h_separation", int(HubTheme.GAP))
	grid.add_theme_constant_override("v_separation", int(HubTheme.GAP))
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grid)
	card_size = size_for(option, width)
	for choice in option.get("choices", []):
		var v := str(choice)
		var card := HubCard.new(_card(v), card_size, queue)
		card.name = "Card_" + v
		card.pressed.connect(func(): pick(v))
		grid.add_child(card)
		cards[v] = card
	_restyle()


## The grid's columns (default 4).
static func columns_of(option: Dictionary) -> int:
	return int(option.get("columns", 4))


## A card's size for `option` in a grid `width` wide.
static func size_for(option: Dictionary, width: float) -> Vector2:
	var cols := columns_of(option)
	var w := floorf((width - HubTheme.GAP * (cols - 1)) / cols)
	return Vector2(w, HubTheme.PICTURE_INSET + slot_size(w, aspect_of(option)).y + TITLE_H + SUBTITLE_H + BOTTOM)


## The picture slot's height as a share of its width: the option's `slot_aspect`, or SLOT_ASPECT.
static func aspect_of(option: Dictionary) -> float:
	return float(option.get("slot_aspect", SLOT_ASPECT))


## The picture slot of a card `card_width` wide: inset evenly by PICTURE_INSET.
static func slot_size(card_width: float, aspect := SLOT_ASPECT) -> Vector2:
	var inner := card_width - 2.0 * HubTheme.PICTURE_INSET
	return Vector2(inner, roundf(inner * aspect))


## The mask radius for a card's picture: concentric with the card's outline.
static func mask_radius() -> float:
	return HubTheme.CARD_RADIUS - HubTheme.PICTURE_INSET


## The whole grid's height (heading included), for layouts.
func grid_height() -> float:
	var rows := ceili(float(cards.size()) / grid.columns)
	return rows * card_size.y + (rows - 1) * HubTheme.GAP


## Picks `v` (a tap): restyles the old and the new card and emits `changed`.
func pick(v: String) -> void:
	if v == value or not cards.has(v):
		return
	var old := value
	value = v
	_restyle([old, v])
	changed.emit(key, v)


## No card chosen (the builder's game tiles are actions, not a pick: each tap adds a game).
func clear_pick() -> void:
	var old := value
	value = ""
	_restyle([old])


## The picture node of a card (for tests): a TextureRect with the rounded mask.
func picture(v: String) -> TextureRect:
	return _parts[v].picture


func badge(v: String) -> Control:
	return _parts[v].badge


func _card(v: String) -> Control:
	var c := GameInfo.card_for(spec, v)
	var accent: Color = c.accent if c.accent is Color else _look.accent
	var panel := PanelContainer.new()
	panel.name = "Panel"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	var slot_rect := slot_size(card_size.x, aspect_of(spec))
	var slot := Control.new()
	slot.name = "Slot"
	slot.custom_minimum_size = slot_rect
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(slot)
	var pic := _picture(c, accent, slot_rect)
	slot.add_child(pic)
	var badge_chip: Control = null
	if bool(spec.get("rider_badge", false)):
		badge_chip = _badge(slot_rect)
		slot.add_child(badge_chip)
	var title_text := str(c.title)
	var title := HubTheme.label(title_text, HomeScreen.fit_size(title_text, HubTheme.CARD_TITLE, slot_rect.x - 8), GameTheme.INK, true)
	title.name = "Title"
	title.custom_minimum_size = Vector2(slot_rect.x, TITLE_H)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.clip_text = true
	box.add_child(title)
	var sub_text := str(c.subtitle)
	var sub := HubTheme.label(sub_text, HudTheme.SMALL, GameTheme.MUTED, true)
	sub.name = "Subtitle"
	sub.custom_minimum_size = Vector2(slot_rect.x, SUBTITLE_H)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	sub.clip_text = true
	box.add_child(sub)
	_parts[v] = {"panel": panel, "title": title, "badge": badge_chip, "accent": accent, "picture": pic}
	return panel


## The card's picture in its slot: the image (a wide one covers the slot, a narrower one is fitted
## and centred), or, without one, the accent's gradient. Masked to the card's rounded outline.
func _picture(c: Dictionary, accent: Color, slot_rect: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = "Picture"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var path := str(c.image)
	var tex: Texture2D = load(path) if not path.is_empty() and ResourceLoader.exists(path) else null
	var pic_size := slot_rect
	if tex == null:
		var g := Gradient.new()
		g.colors = PackedColorArray([accent.lightened(0.15), accent.darkened(0.45)])
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill_from = Vector2(0.2, 0.0)
		gt.fill_to = Vector2(0.8, 1.0)
		gt.width = 32
		gt.height = 32
		tex = gt
		rect.stretch_mode = TextureRect.STRETCH_SCALE
	elif float(tex.get_width()) / tex.get_height() >= 1.5:
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	else:
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		pic_size = Vector2(slot_rect.y * tex.get_width() / tex.get_height(), slot_rect.y)
	rect.texture = tex
	rect.position = Vector2(roundf((slot_rect.x - pic_size.x) * 0.5), 0)
	rect.size = pic_size
	rect.material = HubArt.mask(pic_size, mask_radius())
	return rect


## The rider's name on a gold chip, over the bottom of the picture (the chosen card only).
func _badge(slot_rect: Vector2) -> Control:
	var chip := PanelContainer.new()
	chip.name = "RiderBadge"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = GameTheme.TARGET
	style.set_corner_radius_all(int(BADGE_H * 0.5))
	style.border_color = _look.ink
	style.set_border_width_all(3)
	style.content_margin_left = 14
	style.content_margin_right = 14
	chip.add_theme_stylebox_override("panel", style)
	var text := HubTheme.short_name(rider_name)
	var fs := HomeScreen.fit_size(text, HudTheme.SMALL + 2, slot_rect.x - 48)
	var label := HubTheme.label(text, fs, _look.ink, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true  # a clipped label has no minimum width: size the chip from the text
	chip.add_child(label)
	var text_w := GameTheme.display_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w := minf(slot_rect.x - 12, ceilf(text_w) + 28 + 10)
	chip.custom_minimum_size = Vector2(w, BADGE_H)
	chip.size = Vector2(w, BADGE_H)
	chip.position = Vector2(roundf((slot_rect.x - w) * 0.5), slot_rect.y - BADGE_H + 6)
	return chip


## The cards' look for the current pick: `only` these (a pick touches two), or all of them.
func _restyle(only: Array = []) -> void:
	for v in (only if not only.is_empty() else _parts.keys()):
		if not _parts.has(v):
			continue
		var p: Dictionary = _parts[v]
		var on: bool = v == value
		var style := HomeScreen.card_style(_look)
		style.border_color = GameTheme.TARGET if on else p.accent
		style.set_border_width_all(EDGE_CHOSEN if on else EDGE)
		style.border_width_bottom = 12 if on else 10
		if on:
			style.bg_color = style.bg_color.lerp(GameTheme.TARGET, 0.12)
		(p.panel as PanelContainer).add_theme_stylebox_override("panel", style)
		(p.title as Label).add_theme_color_override("font_color", GameTheme.TARGET if on else GameTheme.INK)
		if p.badge:
			(p.badge as Control).visible = on
