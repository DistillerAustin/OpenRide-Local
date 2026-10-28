extends GdUnitTestSuite
## MusicPanel, the rider's own music over the hub or a game: the track it shows, the words its
## buttons send, play/pause following the app, skips the app doesn't offer faded, the "nothing
## playing" state, and the HUD's Music button showing only with a track.

const TRACK := {"title": "Die With A Smile", "artist": "Lady Gaga, Bruno Mars", "art": "",
	"playing": true, "can_previous": true, "can_next": true}

var panel: MusicPanel


func before_test() -> void:
	panel = auto_free(MusicPanel.new())
	add_child(panel)
	Session._local.hub_calls.clear()


func after_test() -> void:
	Session._on_now_playing({})


func test_it_shows_the_track_and_follows_it() -> void:
	Session._on_now_playing(TRACK)
	panel.open()
	assert_bool(panel.is_open()).is_true()
	assert_str(panel.title_label.text).is_equal("Die With A Smile")
	assert_str(panel.artist_label.text).is_equal("Lady Gaga, Bruno Mars")
	assert_str(panel.play_button.icon_name).is_equal("pause")
	var paused := TRACK.duplicate()
	paused.playing = false
	paused.can_previous = false  # Pandora has no previous
	Session._on_now_playing(paused)
	assert_str(panel.play_button.icon_name).is_equal("play")
	assert_bool(panel.previous_button.disabled).is_true()
	assert_bool(panel.next_button.disabled).is_false()


func test_the_buttons_reach_the_music_app() -> void:
	Session._on_now_playing(TRACK)
	panel.open()
	panel.previous_button.pressed.emit()
	panel.next_button.pressed.emit()
	panel.play_button.pressed.emit()
	assert_array(Session._local.hub_calls).is_equal([["music_control", "previous"], ["music_control", "next"],
		["music_control", "play_pause"]])
	assert_bool(bool(Session.now_playing.playing)).override_failure_message("the desktop stand-in flips play/pause").is_false()


func test_nothing_playing_says_how_to_start_some() -> void:
	panel.open()
	assert_str(panel.title_label.text).is_equal("Nothing playing")
	assert_bool(panel.play_button.disabled).is_true()


func test_done_and_a_tap_outside_close_it() -> void:
	panel.open()
	panel.done_button.pressed.emit()
	assert_bool(panel.is_open()).is_false()
	panel.open()
	(panel.get_node("Shade") as Button).pressed.emit()
	assert_bool(panel.is_open()).is_false()


func test_the_huds_music_button_shows_only_with_a_track() -> void:
	var hud: Hud = auto_free(Hud.new())
	add_child(hud)
	assert_bool(hud.music_button.visible).is_false()
	Session._on_now_playing(TRACK)
	assert_bool(hud.music_button.visible).is_true()
	var opened := []
	hud.music_pressed.connect(func(): opened.append(true))
	hud.music_button.pressed.emit()
	assert_array(opened).has_size(1)
