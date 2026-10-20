extends GdUnitTestSuite
## The shared game-UI kit (framework/ui/GameTheme.gd, UI_STYLE.md): the display face, the size
## floor, outlines, shared gradient materials, touch-sized buttons, the HUD skin and the opt-in
## theming of the intro card and the pause screen, which a null theme fully undoes (games that
## don't opt in, Kart Race among them, look exactly as before).

const ACCENT := Color(0.22, 0.71, 1.0)
const INK_COLOUR := Color(0.05, 0.1, 0.24)

var theme: GameTheme


func before_test() -> void:
	theme = GameTheme.new(ACCENT, INK_COLOUR, 0.2)


func test_the_display_face_is_the_bundled_ofl_font() -> void:
	assert_bool(ResourceLoader.exists(GameTheme.FONT_PATH)).is_true()
	assert_bool(FileAccess.file_exists("res://assets/fonts/LilitaOne-OFL.txt")).is_true()
	var f := GameTheme.display_font() as FontVariation
	assert_object(f.base_font).is_same(load(GameTheme.FONT_PATH))
	# One face per slant, shared by every label (one glyph atlas: the HUD batches).
	assert_object(GameTheme.display_font()).is_same(GameTheme.display_font(true))
	assert_object(GameTheme.display_font(false)).is_not_same(GameTheme.display_font(true))


func test_labels_are_outlined_in_the_ink_and_never_below_the_floor() -> void:
	var small: Label = auto_free(theme.label("x", 20))
	assert_int(small.get_theme_font_size("font_size")).is_equal(HudTheme.SMALL)
	assert_object(small.get_theme_font("font")).is_same(theme.font())
	assert_that(small.get_theme_color("font_outline_color")).is_equal(INK_COLOUR)
	assert_int(small.get_theme_constant("outline_size")).is_greater_equal(6)
	assert_bool(small.has_theme_color_override("font_shadow_color")).is_false()
	assert_int(small.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	var big: Label = auto_free(theme.label("x", 120))
	assert_int(big.get_theme_constant("outline_size")).is_equal(20)
	assert_bool(big.has_theme_color_override("font_shadow_color")).is_true()


func test_restyling_a_kit_label_and_back() -> void:
	var l: Label = auto_free(HudTheme.label("x", HudTheme.BODY, HudTheme.MUTED))
	theme.style_label(l)
	assert_int(l.get_theme_font_size("font_size")).is_equal(HudTheme.BODY)
	assert_that(l.get_theme_color("font_color")).is_equal(HudTheme.MUTED)
	assert_bool(l.has_theme_font_override("font")).is_true()
	theme.set_gradient(l)
	HudTheme.style_label(l, HudTheme.BODY, HudTheme.MUTED)
	assert_bool(l.has_theme_font_override("font")).is_false()
	assert_object(l.material).is_null()


func test_hero_labels_of_one_size_share_a_material() -> void:
	var a: Label = auto_free(theme.hero("A", 96))
	var b: Label = auto_free(theme.hero("B", 96))
	var c: Label = auto_free(theme.hero("C", 160))
	var gold: Label = auto_free(theme.hero("D", 96, GameTheme.GOLD_GRADIENT))
	assert_object(a.material).is_not_null()
	assert_object(a.material).is_same(b.material)
	assert_object(a.material).is_not_same(c.material)
	assert_object(a.material).is_not_same(gold.material)
	theme.set_gradient(a, [], true)
	assert_object(a.material).is_null()


func test_buttons_are_touch_sized_pills_without_focus() -> void:
	var b: Button = auto_free(theme.button("Go", func(): pass, GameTheme.DANGER))
	assert_float(b.custom_minimum_size.x).is_greater_equal(300.0)
	assert_float(b.custom_minimum_size.y).is_greater_equal(HudTheme.BUTTON_HEIGHT)
	assert_int(b.focus_mode).is_equal(Control.FOCUS_NONE)
	var normal := b.get_theme_stylebox("normal") as StyleBoxFlat
	var pressed := b.get_theme_stylebox("pressed") as StyleBoxFlat
	assert_float(normal.bg_color.r).is_greater(normal.bg_color.g * 2.0)  # red
	assert_bool(pressed.bg_color.v > normal.bg_color.v).is_true()
	assert_int(normal.corner_radius_top_left).is_greater_equal(20)


func test_the_hud_skin_restyles_the_message_and_clears() -> void:
	var hud: Hud = auto_free(Hud.new())
	add_child(hud)
	hud.set_skin(theme.hud_skin())
	assert_object(hud._message.get_theme_font("font")).is_same(theme.font())
	assert_object(hud.pause_button.get_theme_font("font")).is_same(theme.font(true))
	hud.show_message("Wave 2")
	assert_bool(hud._message.has_meta(&"_ui_pop")).is_true()
	# The same text again (a game calls it every frame) doesn't pop again.
	var t: Tween = hud._message.get_meta(&"_ui_pop")
	hud.show_message("Wave 2")
	assert_object(hud._message.get_meta(&"_ui_pop")).is_same(t)
	hud.clear_skin()
	assert_bool(hud._message.has_theme_font_override("font")).is_false()
	assert_bool(hud.pause_button.has_theme_font_override("font")).is_false()
	hud.hide_message()
	hud._message.remove_meta(&"_ui_pop")
	hud.show_message("Plain")
	assert_bool(hud._message.has_meta(&"_ui_pop")).is_false()


func _intro() -> IntroCard:
	var card: IntroCard = auto_free(IntroCard.new())
	add_child(card)
	var info := GameInfo.new()
	info.id = "x"
	info.title = "X"
	card.show_segment(info, {"role": "work", "intro_sec": 9}, "Hold 200 W", {}, "", true)
	return card


func test_the_intro_card_takes_a_theme_and_gives_it_back() -> void:
	var card := _intro()
	var plain_title_colour := card._title.get_theme_color("font_color")
	var plain_card := (card._card.get_theme_stylebox("panel") as StyleBoxFlat).bg_color
	card.apply_theme(theme)
	assert_object(card._title.get_theme_font("font")).is_same(theme.font())
	assert_object(card._title.material).is_not_null()
	assert_that(card._target.get_theme_color("font_color")).is_equal(GameTheme.TARGET)
	assert_object(card.skip_button.get_theme_font("font")).is_same(theme.font(true))
	card.apply_theme(null)
	assert_bool(card._title.has_theme_font_override("font")).is_false()
	assert_object(card._title.material).is_null()
	assert_that(card._title.get_theme_color("font_color")).is_equal(plain_title_colour)
	assert_that((card._card.get_theme_stylebox("panel") as StyleBoxFlat).bg_color).is_equal(plain_card)
	assert_that(card._target.get_theme_color("font_color")).is_equal(HudTheme.GOOD)


func test_a_themed_countdown_slams_each_number_once() -> void:
	var card := _intro()
	card.apply_theme(theme)
	card.set_time_left(6.5)
	assert_str(card._count.text).is_equal("7")
	assert_bool(card._count.has_meta(&"_ui_pop")).is_false()  # only 3-2-1 slam
	card.set_time_left(2.5)
	assert_str(card._count.text).is_equal("3")
	assert_int(card._count.get_theme_font_size("font_size")).is_equal(HudTheme.HUGE)
	var slam: Tween = card._count.get_meta(&"_ui_pop")
	card.set_time_left(2.2)
	assert_object(card._count.get_meta(&"_ui_pop")).is_same(slam)
	card.set_time_left(0.0)
	assert_str(card._count.text).is_equal("Go!")


func test_the_pause_screen_takes_a_theme_and_gives_it_back() -> void:
	var overlay: PauseOverlay = auto_free(PauseOverlay.new())
	add_child(overlay)
	var options: Array[Dictionary] = [{"key": "mode", "label": "Mode", "choices": ["a", "b"], "labels": ["A", "B"], "default": "a"}]
	overlay.set_options(options, func(_k): return "a")
	var buttons := overlay.find_children("*", "Button", true, false)
	var plain := {}
	for b in buttons:
		plain[b] = (b.get_theme_stylebox("normal") as StyleBoxFlat).bg_color
	overlay.apply_theme(theme)
	for b in buttons:
		assert_object(b.get_theme_font("font")).is_same(theme.font(true))
		assert_float(b.custom_minimum_size.y).is_greater_equal(HudTheme.BUTTON_HEIGHT)
	var resume: Button = overlay._paused_box.get_child(2)
	assert_str(resume.text).is_equal("Resume")
	assert_that((resume.get_theme_stylebox("normal") as StyleBoxFlat).bg_color).is_equal(
		theme.button_style(GameTheme.GO).bg_color)
	overlay.apply_theme(null)
	for b in buttons:
		assert_bool(b.has_theme_font_override("font")).is_false()
		assert_that((b.get_theme_stylebox("normal") as StyleBoxFlat).bg_color).is_equal(plain[b])


func test_a_game_has_no_theme_unless_it_opts_in() -> void:
	var game: Game = auto_free(GameRegistry.instantiate("demo"))
	assert_object(game.ui_theme()).is_null()


func test_motion_helpers_settle() -> void:
	var c: Control = auto_free(Control.new())
	add_child(c)
	c.size = Vector2(100, 40)
	GameTheme.pulse(c, true)
	assert_bool(c.has_meta(&"_ui_pulse")).is_true()
	GameTheme.pulse(c, false)
	assert_that(c.scale).is_equal(Vector2.ONE)
	GameTheme.slam(c)
	GameTheme.pop(c)  # replaces the slam, and never leaves it faded
	assert_float(c.modulate.a).is_equal(1.0)
	await get_tree().create_timer(GameTheme.POP_SEC + 0.15).timeout
	assert_that(c.scale).is_equal(Vector2.ONE)
	GameTheme.fade(c, false)
	await get_tree().create_timer(GameTheme.FADE_SEC + 0.1).timeout
	assert_bool(c.visible).is_false()


func test_a_fade_can_keep_its_place_in_the_layout() -> void:
	var c: Control = auto_free(Control.new())
	add_child(c)
	GameTheme.fade(c, false, 0.05, true)
	await get_tree().create_timer(0.15).timeout
	assert_bool(c.visible).is_true()  # still laid out, so its neighbours don't move
	assert_float(c.modulate.a).is_equal(0.0)
	GameTheme.fade(c, true, 0.05)
	await get_tree().create_timer(0.15).timeout
	assert_float(c.modulate.a).is_equal(1.0)


func test_stop_ends_one_motion_or_all() -> void:
	var c: Control = auto_free(Control.new())
	add_child(c)
	GameTheme.pulse(c, true)
	GameTheme.fade(c, false)
	GameTheme.stop(c, "fade")
	assert_bool(c.has_meta(&"_ui_fade")).is_false()
	assert_bool(c.has_meta(&"_ui_pulse")).is_true()  # the other motion runs on
	GameTheme.flash(c)
	GameTheme.stop(c)
	for key in GameTheme.MOTIONS.values():
		assert_bool(c.has_meta(key)).is_false()
	await get_tree().create_timer(GameTheme.FADE_SEC + 0.1).timeout
	assert_bool(c.visible).is_true()  # the stopped fade-out never hid it


func test_a_slim_badge_trims_only_its_padding() -> void:
	var full := theme.badge_style(GameTheme.WARN)
	var slim := theme.badge_style(GameTheme.WARN, true)
	assert_float(slim.content_margin_top).is_less(full.content_margin_top)
	assert_float(slim.content_margin_left).is_less(full.content_margin_left)
	assert_int(slim.border_width_bottom).is_less(full.border_width_bottom)
	assert_that(slim.bg_color).is_equal(full.bg_color)
	assert_float(slim.skew.x).is_equal(full.skew.x)


func test_the_house_look_is_shared_and_no_meaning_colour() -> void:
	var house := GameTheme.house()
	assert_object(house).is_same(GameTheme.house())
	for meaning in [GameTheme.GOOD, GameTheme.BAD, GameTheme.WARN, GameTheme.TARGET]:
		assert_float(absf(house.accent.h - meaning.h)).is_greater(0.08)
