class_name GameTheme
extends RefCounted
## A game's UI look, on the shared kit (framework/ui/UI_STYLE.md): one display face, outlined
## labels, gradient hero text, badge panels, pill buttons and a few motion helpers. It
## generalises Kart Race's `KartTheme`; Kart keeps its own.
##
## A game makes one from its accent and its ink, and returns it from `Game.ui_theme()`:
##
##   static var look := GameTheme.new(Color("38b6ff"), Color("0e1b3d"))   # accent, ink
##   func ui_theme() -> GameTheme: return look
##   func _on_prepare(seg): hud.set_skin(look.hud_skin()); hud.add_widget(look.label("WAVE 2", 40))
##
## The session then styles the intro card and the pause screen with it. The meaning colours
## (GOOD, WARN, BAD, TARGET) are the same in every game; only the accent and the ink are the
## game's. Sizes come from `HudTheme` (1920x1080 canvas, read from about 1 m); no text goes
## below `HudTheme.SMALL`.
##
## The display face is Lilita One (SIL OFL 1.1, `assets/fonts/`, listed in assets/SOURCES.md).
## Without the file it falls back to the engine's font, made heavy.

const FONT_PATH := "res://assets/fonts/LilitaOne-Regular.ttf"
const GRADIENT_SHADER := "res://framework/ui/shaders/text_gradient.gdshader"

## Meaning colours, shared by every game (and by HudTheme's ride metrics). Never use one as a
## game's accent, and never let colour alone carry the meaning: pair it with a word or a shape.
const INK := Color(1, 1, 1)
const MUTED := Color(0.78, 0.8, 0.9)
const GOOD := HudTheme.GOOD
const WARN := HudTheme.WARN
const BAD := HudTheme.BAD
const TARGET := Color(1.0, 0.8, 0.16)  ## the thing to aim for: a target number, band or chip
## Gradient pairs (top, bottom) for hero text in a meaning colour.
const GOLD_GRADIENT := [Color(1.0, 0.97, 0.6), Color(1.0, 0.55, 0.1)]
const GOOD_GRADIENT := [Color(0.85, 1.0, 0.5), Color(0.2, 0.8, 0.35)]
const BAD_GRADIENT := [Color(1.0, 0.72, 0.62), Color(0.88, 0.16, 0.18)]

## Button kinds for `button` and `style_button`.
const PRIMARY := "primary"  ## the game's accent
const SECONDARY := "secondary"  ## a dark outlined pill (Recalibrate, Back, options)
const GO := "go"  ## Resume, Keep riding
const DANGER := "danger"  ## End, End session: only ever one per screen, far from other targets

## Motion (UI_STYLE.md, "Motion").
const POP_SEC := 0.35
const FLASH_SEC := 0.3
const FADE_SEC := 0.2
## The tween each motion keeps on its node, by the name `stop` takes.
const MOTIONS := {"pop": &"_ui_pop", "flash": &"_ui_flash", "pulse": &"_ui_pulse", "fade": &"_ui_fade"}

## The game's identity colour: panel edges, primary buttons, hero gradients.
var accent: Color
## The game's dark ink: text outlines, panel fills, shadows. Never pure black.
var ink: Color
## Hero text gradient, top → bottom (from the accent unless set).
var accent_top: Color
var accent_bottom: Color
## HUD and card panel fill, and its edge.
var panel: Color
var panel_edge: Color
## How far badges lean (StyleBoxFlat skew): 0 upright (Safe Cracker), up to about 0.3.
var skew := 0.0
## Whether the display face leans too (badges and banners); buttons and numbers stay upright.
var italic := false

static var _fonts := {}
static var _gradient_shader: Shader
static var _house: GameTheme
var _hero_materials := {}


func _init(accent_color: Color, ink_color: Color, badge_skew := 0.0, italic_face := false) -> void:
	accent = accent_color
	ink = Color(ink_color, 1.0)
	accent_top = accent_color.lerp(Color.WHITE, 0.55)
	accent_bottom = accent_color.darkened(0.12)
	panel = Color(ink.lerp(accent, 0.12), 0.86)
	panel_edge = Color(accent, 0.9)
	skew = badge_skew
	italic = italic_face


## The app's own look, for the framework's screens (the summary, calibration) when a game has
## no `ui_theme()` (Kart Race, the demo) and for a circuit's summary, which spans several
## games: a periwinkle accent on a deep indigo ink, upright. Close to Kart Race's violet night,
## so a Kart session ends in a look that matches it, and far from every meaning colour.
static func house() -> GameTheme:
	if _house == null:
		_house = GameTheme.new(Color("7a7cff"), Color("17143a"), 0.12)
	return _house


## The shared display face: heavy, and leaning unless `upright`.
static func display_font(upright := true) -> Font:
	var key := "u" if upright else "i"
	if _fonts.has(key):
		return _fonts[key]
	var base: Font = ThemeDB.fallback_font
	var bundled := ResourceLoader.exists(FONT_PATH)
	if bundled:
		base = load(FONT_PATH)
	var v := FontVariation.new()
	v.base_font = base
	v.variation_embolden = 0.0 if bundled else 1.1
	v.spacing_glyph = 1
	if not upright:
		v.variation_transform = Transform2D(Vector2(1, 0), Vector2(-0.16, 1), Vector2.ZERO)
	_fonts[key] = v
	return v


## This game's face: leaning when the theme is `italic`, unless `upright`.
func font(upright := false) -> Font:
	return display_font(upright or not italic)


## A label in the display face with the game's dark outline (and a drop shadow from 70 px).
## Sizes below `HudTheme.SMALL` are raised to it.
func label(text: String, size: int, color := INK, upright := false) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	style_label(l, size, color, upright)
	return l


## Restyles an existing label (e.g. one made with `HudTheme.label`) in this theme. `size` 0
## keeps its size.
func style_label(l: Label, size := 0, color = null, upright := false) -> void:
	var s := maxi(size if size > 0 else l.get_theme_font_size("font_size"), HudTheme.SMALL)
	l.add_theme_font_override("font", font(upright))
	l.add_theme_font_size_override("font_size", s)
	if color != null:
		l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", ink)
	l.add_theme_constant_override("outline_size", outline_for(s))
	if s >= 70:
		l.add_theme_color_override("font_shadow_color", Color(ink, 0.55))
		l.add_theme_constant_override("shadow_offset_x", maxi(2, s / 24))
		l.add_theme_constant_override("shadow_offset_y", maxi(3, s / 16))
		l.add_theme_constant_override("shadow_outline_size", outline_for(s))
	else:
		l.remove_theme_color_override("font_shadow_color")


## The outline width for a text size: thick enough to read over any 3D scene.
static func outline_for(size: int) -> int:
	return maxi(6, size / 6)


## A hero label (a title, a countdown digit, a big result) with a vertical gradient fill: the
## accent's by default, or `gradient` ([top, bottom], e.g. GOLD_GRADIENT). Each gradient is its
## own material (its own draw call): at most two on screen during play.
func hero(text: String, size: int, gradient: Array = [], upright := false) -> Label:
	var l := label(text, size, INK, upright)
	set_gradient(l, gradient)
	return l


## Gives a label this theme's gradient fill (or `gradient`), or takes it off with `[]` on a
## label that has one and `clear` true. Labels of one size and gradient share one material.
func set_gradient(l: Label, gradient: Array = [], clear := false) -> void:
	if clear:
		l.material = null
		return
	var top: Color = gradient[0] if gradient.size() == 2 else accent_top
	var bottom: Color = gradient[1] if gradient.size() == 2 else accent_bottom
	var size := l.get_theme_font_size("font_size")
	var key := "%d|%s|%s" % [size, top.to_html(), bottom.to_html()]
	if not _hero_materials.has(key):
		if _gradient_shader == null:
			_gradient_shader = load(GRADIENT_SHADER)
		var mat := ShaderMaterial.new()
		mat.shader = _gradient_shader
		mat.set_shader_parameter("top", top)
		mat.set_shader_parameter("bottom", bottom)
		mat.set_shader_parameter("span", Vector2(size * 0.32, size * 1.12))
		_hero_materials[key] = mat
	l.material = _hero_materials[key]
	l.add_theme_color_override("font_color", Color.WHITE)


## A panel: the theme's fill with a bright edge, a thicker bottom edge and a soft shadow,
## leaning by `lean` (default: the theme's skew; 0 for big cards and HUD panels).
func panel_style(fill = null, lean := 0.0, radius := 22) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill if fill != null else panel
	s.skew = Vector2(lean, 0)
	s.set_corner_radius_all(radius)
	s.border_color = panel_edge
	s.set_border_width_all(3)
	s.border_width_bottom = 6
	s.shadow_color = Color(ink, 0.45)
	s.shadow_size = 8
	s.shadow_offset = Vector2(4, 6)
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 8
	s.content_margin_bottom = 10
	s.anti_aliasing = true
	return s


## A slanted badge (a chip, a banner, a callout) in `fill` (default: the accent). `slim` trims
## its padding for a chip in a tight row (two rows of chips fit a 120 px widget).
func badge_style(fill = null, slim := false) -> StyleBoxFlat:
	var s := panel_style(fill if fill != null else Color(accent, 0.95), skew, 14)
	s.border_color = Color(Color.WHITE, 0.55)
	s.content_margin_left = 18 if slim else 26
	s.content_margin_right = 18 if slim else 26
	if slim:
		s.content_margin_top = 1
		s.content_margin_bottom = 3
		s.border_width_bottom = 4
	return s


## The big card behind the intro and pause screens.
func card_style() -> StyleBoxFlat:
	var s := panel_style(Color(ink.lerp(accent, 0.18), 0.96), 0.0, 32)
	s.set_border_width_all(4)
	s.border_width_bottom = 10
	s.content_margin_left = 40
	s.content_margin_right = 40
	s.content_margin_top = 24
	s.content_margin_bottom = 28
	return s


## A pill's style for a button kind (PRIMARY, SECONDARY, GO, DANGER); `pressed` lightens it.
func button_style(kind := PRIMARY, pressed := false) -> StyleBoxFlat:
	var fill: Color
	var edge := Color(Color.WHITE, 0.6)
	match kind:
		SECONDARY:
			fill = Color(ink, 0.78)
			edge = Color(accent, 0.95)
		GO:
			fill = Color(0.13, 0.55, 0.32, 0.96)
		DANGER:
			fill = Color(0.72, 0.15, 0.24, 0.96)
		_:
			fill = Color(accent.darkened(0.25), 0.96)
	if pressed:
		fill = fill.lightened(0.2)
	var s := panel_style(fill, 0.0, 28)
	s.border_color = edge
	s.set_border_width_all(4 if kind == SECONDARY else 3)
	s.border_width_bottom = 7
	s.content_margin_left = 28
	s.content_margin_right = 28
	return s


## A touch button: at least 300 x HudTheme.BUTTON_HEIGHT, no focus (Space is the simulator's
## stand), in the display face.
func button(text: String, action: Callable, kind := PRIMARY) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(300, HudTheme.BUTTON_HEIGHT)
	style_button(b, kind)
	b.pressed.connect(action)
	return b


## Restyles an existing button in this theme (its size and action are kept).
func style_button(b: Button, kind := PRIMARY) -> void:
	b.add_theme_font_override("font", font(true))
	b.add_theme_font_size_override("font_size", maxi(b.get_theme_font_size("font_size"), HudTheme.BUTTON_FONT))
	b.add_theme_color_override("font_outline_color", ink)
	b.add_theme_constant_override("outline_size", 6)
	for state in ["normal", "hover", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, button_style(kind))
	b.add_theme_stylebox_override("pressed", button_style(kind, true))


## The skin for `Hud.set_skin`: the framework's panels, Pause, End, Recalibrate and the centre
## message in this theme. Layout keys (`ride_panel`, `reserve_right`, …) are the game's to add.
func hud_skin() -> Dictionary:
	var hud_panel := panel_style()
	hud_panel.content_margin_top = 6
	return {"font": font(true), "outline_color": ink, "outline_size": 8, "panel": hud_panel,
		"button": button_style(PRIMARY), "button_pressed": button_style(PRIMARY, true),
		"end_button": button_style(DANGER), "recalibrate_button": button_style(SECONDARY),
		"message_font": font(), "message_outline_color": ink}


# --- Motion: transforms and modulate only, never a re-layout ---

## A pop: scales `c` up to `peak` (below 1 for a loss) and springs back, about its centre.
## A new pop replaces a running one.
static func pop(c: Control, peak := 1.25, sec := POP_SEC) -> Tween:
	_kill(c, &"_ui_pop")
	c.modulate.a = 1.0  # a slam cut short leaves it faded
	c.pivot_offset = c.size / 2.0
	var t := c.create_tween()
	# The centre again on the first step: a label whose text just changed is laid out by then.
	t.tween_callback(func(): c.pivot_offset = c.size / 2.0)
	t.tween_property(c, "scale", Vector2(peak, peak), sec * 0.3).from(Vector2.ONE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "scale", Vector2.ONE, sec * 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	c.set_meta(&"_ui_pop", t)
	return t


## A slam: `c` lands from `from_scale` down to its size, fading in (a countdown digit, a
## banner, a result).
static func slam(c: Control, from_scale := 1.8, sec := POP_SEC) -> Tween:
	_kill(c, &"_ui_pop")
	c.pivot_offset = c.size / 2.0
	c.scale = Vector2(from_scale, from_scale)
	c.modulate.a = 0.0
	var t := c.create_tween().set_parallel()
	t.tween_callback(func(): c.pivot_offset = c.size / 2.0)
	t.tween_property(c, "scale", Vector2.ONE, sec).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "modulate:a", 1.0, sec * 0.4)
	c.set_meta(&"_ui_pop", t)
	return t


## A brief brightening (good for a widget in a container: it never grows over its neighbours).
static func flash(c: CanvasItem, strength := 1.6, sec := FLASH_SEC) -> Tween:
	_kill(c, &"_ui_flash")
	var t := c.create_tween()
	t.tween_property(c, "modulate", Color(strength, strength, strength), sec * 0.2)
	t.tween_property(c, "modulate", Color.WHITE, sec * 0.8)
	c.set_meta(&"_ui_flash", t)
	return t


## A slow breathe (1.0 → `peak` and back) while a state holds (an alarm, an unused item); call
## again with `on` false to stop it and settle.
static func pulse(c: Control, on: bool, peak := 1.06, period := 0.9) -> void:
	_kill(c, &"_ui_pulse")
	c.pivot_offset = c.size / 2.0
	if not on:
		c.scale = Vector2.ONE
		return
	var t := c.create_tween().set_loops()
	t.tween_property(c, "scale", Vector2(peak, peak), period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(c, "scale", Vector2.ONE, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	c.set_meta(&"_ui_pulse", t)


## Fades `c` in (or out, and hides it) over FADE_SEC. With `keep_layout`, a fade-out leaves it
## visible at alpha 0, so it keeps its place in a container and its neighbours don't move.
static func fade(c: CanvasItem, show: bool, sec := FADE_SEC, keep_layout := false) -> Tween:
	_kill(c, &"_ui_fade")
	if show:
		c.visible = true
	var t := c.create_tween()
	t.tween_property(c, "modulate:a", 1.0 if show else 0.0, sec)
	if not show and not keep_layout:
		t.tween_callback(c.hide)
	c.set_meta(&"_ui_fade", t)
	return t


## Stops the kit's motion on `c`: one of "pop" (pop and slam), "flash", "pulse" or "fade", or
## every one with "". It stops where it is: nothing settles (`pulse(c, false)` settles a pulse).
static func stop(c: Object, motion := "") -> void:
	for key in MOTIONS:
		if motion.is_empty() or motion == key:
			_kill(c, MOTIONS[key])


static func _kill(c: Object, key: StringName) -> void:
	if c.has_meta(key):
		var old: Tween = c.get_meta(key)
		if old and old.is_valid():
			old.kill()
		c.remove_meta(key)
