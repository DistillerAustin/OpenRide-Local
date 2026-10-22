extends GdUnitTestSuite
## A game that counts its own start down (GameInfo.own_countdown) gets "Get ready" on the intro
## card instead of a second 3-2-1.


func _card(own: bool) -> IntroCard:
	var card: IntroCard = auto_free(IntroCard.new())
	add_child(card)
	var info := GameInfo.new()
	info.id = "x"
	info.title = "X"
	info.own_countdown = own
	card.show_segment(info, {"role": "free", "intro_sec": 5}, "", {}, "", false)
	return card


func test_the_card_counts_down_by_default() -> void:
	var card := _card(false)
	card.set_time_left(2.4)
	assert_str(card._count.text).is_equal("3")


func test_a_game_with_its_own_countdown_gets_get_ready() -> void:
	var card := _card(true)
	for t in [5.0, 2.4, 0.5]:
		card.set_time_left(t)
		assert_str(card._count.text).is_equal("Get ready")


func test_kart_race_counts_its_own_start_down() -> void:
	assert_bool(GameRegistry.info("kart_race").own_countdown).is_true()


## The shade dims around the card, not under it (the tablet's GPU is fill-bound), yet every
## touch outside the skip button still lands on the card or the shade.
func test_the_shade_frames_the_card_and_takes_every_touch() -> void:
	var card := _card(false)
	var screen := HudTheme.W * HudTheme.H
	var shaded := 0.0
	var stops: Array[Rect2] = [Rect2(card._card.position, card._card.size)]
	for child in card.get_children():
		if child is ColorRect and child.name.begins_with("Shade"):
			shaded += child.size.x * child.size.y
			if child.mouse_filter == Control.MOUSE_FILTER_STOP:
				stops.append(Rect2(child.position, child.size))
	assert_float(shaded / screen).is_less(0.6)
	assert_int(card._card.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	for p in [Vector2(5, 5), Vector2(HudTheme.W - 5, HudTheme.H - 5), Vector2(HudTheme.W / 2.0, HudTheme.H / 2.0),
			card._card.position - Vector2(1, 1), card._card.position + card._card.size + Vector2(1, 1)]:
		assert_bool(stops.any(func(r: Rect2) -> bool: return r.has_point(p))).override_failure_message(
			"no touch cover at %s" % p).is_true()


var _restyles := 0


## Review of PR #58: set_time_left runs every frame of the intro, and each theme override it set
## re-shaped the label. A frame that shows the same thing must not touch the styling.
func test_a_steady_countdown_doesnt_restyle_the_label_every_frame() -> void:
	for own in [true, false]:
		var card := _card(own)
		card.set_time_left(4.9)
		_restyles = 0
		card._count.theme_changed.connect(func(): _restyles += 1)
		for i in 30:
			card.set_time_left(4.9 - i * 0.016)
		assert_int(_restyles).override_failure_message("own_countdown=%s" % own).is_equal(0)
