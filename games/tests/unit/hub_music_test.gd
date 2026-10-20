extends GdUnitTestSuite
## HubMusic, the hub's theme (spec §8.5): the request it makes, silence with music off,
## intensity from cadence, and the duck held under a dialog and released after it.

var music: HubMusic
var _cadence := 0.0


func before_test() -> void:
	_cadence = InputBus.cadence
	AudioDirector.end_session()
	AudioDirector._game_duck_left = 0.0
	music = auto_free(HubMusic.new())
	add_child(music)


func after_test() -> void:
	InputBus.cadence = _cadence
	AudioDirector.end_session()
	AudioDirector.set_volumes(true, 0.8, 1.0)
	AudioDirector._game_duck_left = 0.0
	AudioDirector.set_bus_effects(AudioDirector.MASTER_BUS, [])


func test_the_theme_is_rendered_and_small() -> void:
	var total := 0
	for stem in HubMusicIndex.STEM_FILES:
		var path: String = HubMusicIndex.STEM_FILES[stem]
		assert_bool(ResourceLoader.exists(path)).override_failure_message(path).is_true()
		total += FileAccess.get_file_as_bytes(path).size()
	assert_array(HubMusicIndex.STEM_FILES.keys()).contains_exactly(["bed", "harmony", "lead"])
	assert_int(total).is_less_equal(1024 * 1024)
	assert_float(HubMusicIndex.LOOP_FROM).is_greater(0.0)


func test_it_asks_for_the_hub_theme_with_its_gates() -> void:
	music.play({"music": true, "music_volume": 0.6, "sfx_volume": 1.0})
	assert_bool(music.playing).is_true()
	var req: Dictionary = AudioDirector._requested
	assert_str(req.style.name).is_equal("hub")
	assert_dict(req.style.stem_gates).is_equal({"harmony": 0.3, "lead": 0.7})
	assert_float(req.tempo_bpm).is_equal(HubMusicIndex.BPM)
	assert_float(AudioDirector.music_volume).is_equal_approx(0.6, 0.001)
	assert_int(AudioDirector.bus_effects(AudioDirector.MASTER_BUS).size()).is_equal(1)  # the limiter


func test_music_off_is_silence() -> void:
	music.play({"music": false, "music_volume": 0.8, "sfx_volume": 1.0})
	assert_bool(music.playing).is_false()
	assert_bool(AudioDirector.music_enabled).is_false()
	assert_dict(AudioDirector._requested).is_empty()


func test_music_turned_off_in_settings_stops_it() -> void:
	music.play({"music": true, "music_volume": 0.8, "sfx_volume": 1.0})
	music.apply_audio({"music": false, "music_volume": 0.8, "sfx_volume": 1.0})
	assert_bool(music.playing).is_false()
	assert_bool(AudioDirector.music_enabled).is_false()


func test_intensity_follows_cadence() -> void:
	assert_float(HubMusic.intensity_for(0.0)).is_equal(0.0)
	assert_float(HubMusic.intensity_for(30.0)).is_equal_approx(0.25, 0.001)
	assert_float(HubMusic.intensity_for(60.0)).is_equal_approx(0.5, 0.001)
	assert_float(HubMusic.intensity_for(90.0)).is_equal_approx(1.0, 0.001)
	assert_float(HubMusic.intensity_for(120.0)).is_equal(1.0)
	music.play({"music": true})
	InputBus.cadence = 90.0
	music.tick()
	assert_float(AudioDirector.intensity).is_equal(1.0)
	InputBus.cadence = 0.0
	music.tick()
	assert_float(AudioDirector.intensity).is_equal(0.0)


func test_a_dialog_ducks_while_it_shows_and_releases_after() -> void:
	music.play({"music": true})
	music.set_dialog(true)
	assert_float(AudioDirector._game_duck_db).is_equal(GameMix.MOMENT_DUCK_DB)
	for i in 6:  # 3 s with the dialog up: each tick re-asks, so the duck holds
		AudioDirector._game_duck_left = maxf(0.0, AudioDirector._game_duck_left - HubMusic.TICK_SEC)
		music.tick()
		assert_float(AudioDirector._game_duck_left).is_greater(0.0)
	music.set_dialog(false)
	for i in 3:
		AudioDirector._game_duck_left = maxf(0.0, AudioDirector._game_duck_left - HubMusic.TICK_SEC)
		music.tick()
	assert_float(AudioDirector._game_duck_left).is_equal(0.0)


func test_leaving_for_a_game_stops_following_cadence() -> void:
	music.play({"music": true})
	music.leave()
	InputBus.cadence = 90.0
	AudioDirector.set_intensity(0.2)
	music.tick()
	assert_float(AudioDirector.intensity).is_equal_approx(0.2, 0.001)
