class_name HubCard
extends Control
## A baked card (spec §8.4): its content (a panel, a picture, titles, a best line) renders into
## a BakedView once, and again only when it changes, so on screen the whole card is one draw
## call. A flat, invisible Button over it takes the touch (the bake's viewport takes no input).
## A press pops the card (a scale tween on the bake: no re-render, no re-layout).
##
##   HubCard (Control, the card's size: containers lay it out)
##   ├ Baked_<content> (BakedView: a TextureRect drawing the SubViewport, PAD outside the card)
##   │ └ Bake (SubViewport) → content (the card's controls)
##   └ Hit (Button, flat, full rect)

signal pressed

var content: Control
var bake: BakedView
var hit: Button
## A dimmed card (a game that needs the camera when it's off) still takes the tap: it explains.
var dimmed := false


## `content` is laid out at `card_size` (its own containers fill it).
## Without `interactive` it is only a bake (a header part): no Hit button.
func _init(card_content: Control, card_size: Vector2, queue: BakeQueue = null, interactive := true) -> void:
	content = card_content
	custom_minimum_size = card_size
	size = card_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.position = Vector2.ZERO
	content.size = card_size
	content.custom_minimum_size = card_size
	bake = BakedView.new(content, self, card_size)
	bake.queue = queue
	if not interactive:
		return
	hit = Button.new()
	hit.name = "Hit"
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		hit.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit.button_down.connect(func(): GameTheme.pop(bake, 0.96, 0.25))
	hit.pressed.connect(func(): pressed.emit())
	add_child(hit)


## The touch rectangle, in the canvas (for the layout test).
func target_rect() -> Rect2:
	return hit.get_global_rect() if hit else Rect2()


func set_dimmed(on: bool) -> void:
	dimmed = on
	# The bake draws premultiplied: darken the colour (an alpha-only modulate would brighten it).
	bake.modulate = Color(0.5, 0.5, 0.55) if on else Color.WHITE
