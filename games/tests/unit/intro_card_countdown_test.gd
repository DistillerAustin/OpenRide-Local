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
