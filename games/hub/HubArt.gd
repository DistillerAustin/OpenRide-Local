class_name HubArt
extends RefCounted
## The hub's pictures (spec §8.3): a game's `res://games/<id>/hub_card.png` (512x288), or, for a
## game without one, a gradient in its accent with its title. Each is masked to a rounded rect
## concentric with its card (`framework/ui/shaders/rounded_mask.gdshader`, radius R - inset),
## and drawn inside the card's bake.

const MASK_SHADER := "res://framework/ui/shaders/rounded_mask.gdshader"

static var _mask: Shader


static func card_path(game_id: String) -> String:
	return "res://games/%s/hub_card.png" % game_id


static func has_card(game_id: String) -> bool:
	return ResourceLoader.exists(card_path(game_id))


## A picture for `game_id` at `size`, masked with corner `radius`.
static func picture(game_id: String, size: Vector2, radius: float) -> Control:
	var rect := TextureRect.new()
	rect.custom_minimum_size = size
	rect.size = size
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = mask(size, radius)
	if has_card(game_id):
		rect.texture = load(card_path(game_id))
		return rect
	# The placeholder: the accent's gradient, its title across it.
	var look := HubTheme.game_look(game_id)
	var g := Gradient.new()
	g.colors = PackedColorArray([look.accent.lightened(0.15), look.accent.darkened(0.45)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0.2, 0.0)
	tex.fill_to = Vector2(0.8, 1.0)
	tex.width = 64
	tex.height = 64
	rect.texture = tex
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	var info := GameRegistry.info(game_id)
	var title := look.label((info.title if info else game_id.capitalize()).to_upper(), HudTheme.MEDIUM, GameTheme.INK, false)
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rect.add_child(title)
	return rect


static func mask(size: Vector2, radius: float) -> ShaderMaterial:
	if _mask == null:
		_mask = load(MASK_SHADER)
	var m := ShaderMaterial.new()
	m.shader = _mask
	m.set_shader_parameter("rect_size", size)
	m.set_shader_parameter("radius", radius)
	return m
