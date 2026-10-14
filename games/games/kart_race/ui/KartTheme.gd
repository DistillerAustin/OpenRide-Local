class_name KartTheme
extends RefCounted
## Kart Race's game-UI look (#43, the hero slice): a heavy italic display face, outlines, slanted
## badges, gradients and a purple-night-and-sunset palette shared by the HUD, the title card and
## the boards.
##
## The display face is the engine's own font (already in every build, OFL) made heavy and slanted
## with a FontVariation; swap DISPLAY_FONT_PATH for a bundled OFL display font to change it in one
## place (none is bundled yet: adding one needs a download).

const DISPLAY_FONT_PATH := ""  ## e.g. "res://games/kart_race/ui/fonts/SomeDisplay.ttf" (OFL)

const INK := Color(1, 1, 1)
const OUTLINE := Color(0.13, 0.06, 0.24)
const PANEL := Color(0.16, 0.1, 0.34, 0.86)
const PANEL_EDGE := Color(0.55, 0.42, 1.0, 0.9)
const CHIP := Color(1.0, 0.8, 0.16)
const GOLD_TOP := Color(1.0, 0.97, 0.6)
const GOLD_BOTTOM := Color(1.0, 0.55, 0.1)
const VIOLET_TOP := Color(0.86, 0.8, 1.0)
const VIOLET_BOTTOM := Color(0.5, 0.32, 1.0)
const GREEN_TOP := Color(0.85, 1.0, 0.5)
const GREEN_BOTTOM := Color(0.2, 0.8, 0.35)

const SHADERS := "res://games/kart_race/ui/shaders/"

static var _fonts := {}
static var _gradient_shader: Shader


## The display face: heavy, and slanted unless `upright`.
static func display(upright := false) -> Font:
	var key := "u" if upright else "i"
	if _fonts.has(key):
		return _fonts[key]
	var base: Font = ThemeDB.fallback_font
	if DISPLAY_FONT_PATH != "" and ResourceLoader.exists(DISPLAY_FONT_PATH):
		base = load(DISPLAY_FONT_PATH)
	var v := FontVariation.new()
	v.base_font = base
	v.variation_embolden = 1.1
	v.spacing_glyph = 1
	if not upright:
		v.variation_transform = Transform2D(Vector2(1, 0), Vector2(-0.22, 1), Vector2.ZERO)
	_fonts[key] = v
	return v


## A label in the display face with a thick dark outline and a drop shadow.
static func label(text: String, size: int, color := INK, upright := false) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", display(upright))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", maxi(6, size / 6))
	l.add_theme_color_override("font_shadow_color", Color(0.05, 0.0, 0.15, 0.55))
	l.add_theme_constant_override("shadow_offset_x", maxi(2, size / 24))
	l.add_theme_constant_override("shadow_offset_y", maxi(3, size / 16))
	l.add_theme_constant_override("shadow_outline_size", maxi(6, size / 6))
	return l


## Fills a label's glyphs with a vertical gradient (the outline stays dark).
static func gradient(l: Label, top: Color, bottom: Color) -> void:
	if _gradient_shader == null:
		_gradient_shader = load(SHADERS + "text_gradient.gdshader")
	var mat := ShaderMaterial.new()
	mat.shader = _gradient_shader
	mat.set_shader_parameter("top", top)
	mat.set_shader_parameter("bottom", bottom)
	var size := float(l.get_theme_font_size("font_size"))
	mat.set_shader_parameter("span", Vector2(size * 0.32, size * 1.12))
	l.material = mat
	l.add_theme_color_override("font_color", Color.WHITE)


## A slanted badge panel (StyleBoxFlat skew), optionally with a bright edge.
static func badge(color := PANEL, skew := 0.18, radius := 14, edge := PANEL_EDGE) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.skew = Vector2(skew, 0)
	s.set_corner_radius_all(radius)
	s.border_color = edge
	s.set_border_width_all(3 if edge.a > 0.0 else 0)
	s.border_width_bottom = 6 if edge.a > 0.0 else 0
	s.shadow_color = Color(0.05, 0.0, 0.15, 0.45)
	s.shadow_size = 8
	s.shadow_offset = Vector2(4, 6)
	s.content_margin_left = 26
	s.content_margin_right = 26
	s.content_margin_top = 8
	s.content_margin_bottom = 10
	s.anti_aliasing = true
	return s


static func ordinal_suffix(n: int) -> String:
	var suffix := "th"
	if n % 100 < 11 or n % 100 > 13:
		match n % 10:
			1: suffix = "st"
			2: suffix = "nd"
			3: suffix = "rd"
	return suffix


## Race time as 0:12.345.
static func race_time(t: float) -> String:
	var ms := int(round(maxf(t, 0.0) * 1000.0))
	return "%d:%02d.%03d" % [ms / 60000, (ms / 1000) % 60, ms % 1000]
