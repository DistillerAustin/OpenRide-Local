extends GdUnitTestSuite
## AudioDirector: buses, segment audio settings, silence until generators register, the
## registration API #36 plugs into, music rendering off the main thread, crossfades, stem
## gates and ducking.

const SEGMENT_AUDIO := {"audio": {"music": true, "music_volume": 0.5, "sfx_volume": 0.25}}


static func _tone(seconds := 0.25) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 8000
	var data := PackedByteArray()
	data.resize(int(8000 * seconds) * 2)
	wav.data = data
	return wav


static func _stems(_request: Dictionary) -> Dictionary:
	return {"drums": _tone(), "bass": _tone(), "lead": _tone()}


func before_test() -> void:
	AudioDirector.begin_session()
	AudioDirector.begin_segment(SEGMENT_AUDIO)
	AudioDirector._sounds.clear()
	AudioDirector._sound_factories.clear()
	AudioDirector._music_generator = Callable()
	AudioDirector._music_cache.clear()
	AudioDirector.stop_music(0.0)
	AudioDirector._cue_left = 0.0
	AudioDirector._game_duck_left = 0.0
	AudioDirector.duck_db = 0.0


func after_test() -> void:
	InputBus._sim_rider_music = false
	AudioDirector.set_rider_music(false)
	AudioDirector.end_session()
	AudioDirector._music_generator = Callable()
	AudioDirector._sounds.clear()
	AudioDirector._sound_factories.clear()


func test_buses_exist_and_feed_master() -> void:
	for bus in ["Music", "SFX", "Cues"]:
		var index := AudioServer.get_bus_index(bus)
		assert_int(index).is_greater(0)
		assert_str(AudioServer.get_bus_send(index)).is_equal("Master")


func test_segment_audio_sets_bus_volumes() -> void:
	AudioDirector._process(0.0)
	assert_float(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))).is_equal_approx(linear_to_db(0.5), 0.01)
	assert_float(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))).is_equal_approx(linear_to_db(0.25), 0.01)
	assert_float(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Cues"))).is_equal_approx(linear_to_db(0.25), 0.01)


func test_unknown_sounds_are_silent() -> void:
	assert_bool(AudioDirector.play_sfx("whoosh")).is_false()
	assert_bool(AudioDirector.play_cue("go")).is_false()


func test_registered_sounds_play_on_their_bus() -> void:
	var played := []
	var record := func(sound, bus): played.append([sound, bus])
	AudioDirector.sound_played.connect(record)
	AudioDirector.register_sound("whoosh", _tone())
	AudioDirector.register_sound("go", _tone())
	assert_bool(AudioDirector.play_sfx("whoosh")).is_true()
	assert_bool(AudioDirector.play_cue("go")).is_true()
	AudioDirector.sound_played.disconnect(record)
	assert_array(played).is_equal([["whoosh", "SFX"], ["go", "Cues"]])


func test_a_sound_factory_renders_each_name_once() -> void:
	var asked := []
	AudioDirector.register_sound_factory(func(sound: String):
		asked.append(sound)
		return _tone() if sound == "thud" else null)
	assert_bool(AudioDirector.play_sfx("thud")).is_true()
	assert_bool(AudioDirector.play_sfx("thud")).is_true()
	assert_bool(AudioDirector.play_sfx("nothing")).is_false()
	assert_array(asked).is_equal(["thud", "nothing"])


func test_music_is_silent_without_a_generator() -> void:
	AudioDirector.play_music({"name": "x"}, 90.0, 1)
	await await_millis(50)
	assert_bool(AudioDirector.is_music_playing()).is_false()
	assert_bool(AudioDirector.has_music_generator()).is_false()


func test_music_renders_off_the_main_thread_then_plays() -> void:
	var main_thread := OS.get_thread_caller_id()
	var seen := [main_thread, {}]
	AudioDirector.register_music_generator(func(request: Dictionary):
		seen[0] = OS.get_thread_caller_id()
		seen[1] = request
		return _stems(request))
	AudioDirector.play_music({"name": "drive"}, 90.0, 7)
	await _until(func(): return AudioDirector.is_music_playing())
	assert_bool(AudioDirector.is_music_playing()).is_true()
	assert_int(seen[0]).is_not_equal(main_thread)
	assert_dict(seen[1]).is_equal({"style": {"name": "drive"}, "tempo_bpm": 90.0, "seed": 7})
	assert_str(AudioDirector.current_music_key()).is_equal(
		AudioDirector.music_key({"style": {"name": "drive"}, "tempo_bpm": 90.0, "seed": 7}))


func test_asking_again_for_the_same_music_changes_nothing() -> void:
	var renders := [0]
	AudioDirector.register_music_generator(func(request: Dictionary):
		renders[0] += 1
		return _stems(request))
	var started := []
	var record := func(key): started.append(key)
	AudioDirector.music_started.connect(record)
	AudioDirector.play_music({"name": "drive"}, 90.0, 7)
	await _until(func(): return AudioDirector.is_music_playing())
	AudioDirector.play_music({"name": "drive"}, 90.0, 7)
	await await_millis(50)
	AudioDirector.music_started.disconnect(record)
	assert_int(renders[0]).is_equal(1)
	assert_int(started.size()).is_equal(1)


func test_new_music_crossfades_in() -> void:
	AudioDirector.register_music_generator(_stems)
	AudioDirector.play_music({"name": "one"}, 90.0, 1)
	await _until(func(): return AudioDirector.is_music_playing())
	AudioDirector._process(AudioDirector.CROSSFADE_SEC)
	var first := AudioDirector.current_music_key()
	AudioDirector.play_music({"name": "two"}, 100.0, 1)
	await _until(func(): return AudioDirector.current_music_key() != first)
	var new_deck: AudioStreamPlayer = AudioDirector._decks[AudioDirector._deck]
	var old_deck: AudioStreamPlayer = AudioDirector._decks[1 - AudioDirector._deck]
	AudioDirector._process(AudioDirector.CROSSFADE_SEC / 2)
	assert_bool(old_deck.playing).is_true()  # both sound mid-fade
	assert_float(new_deck.volume_db).is_greater(AudioDirector.SILENT_DB)
	assert_float(old_deck.volume_db).is_greater(AudioDirector.SILENT_DB)
	AudioDirector._process(AudioDirector.CROSSFADE_SEC)
	assert_bool(old_deck.playing).is_false()
	assert_float(new_deck.volume_db).is_equal_approx(0.0, 0.01)


func test_music_off_keeps_the_request_but_plays_nothing() -> void:
	AudioDirector.register_music_generator(_stems)
	AudioDirector.begin_segment({"audio": {"music": false, "music_volume": 0.8, "sfx_volume": 1.0}})
	AudioDirector.play_music({"name": "drive"}, 90.0, 7)
	await await_millis(100)
	assert_bool(AudioDirector.is_music_playing()).is_false()
	assert_bool(AudioDirector.music_enabled).is_false()


func test_music_off_in_a_new_segment_fades_the_music_out() -> void:
	AudioDirector.register_music_generator(_stems)
	AudioDirector.play_music({"name": "drive"}, 90.0, 7)
	await _until(func(): return AudioDirector.is_music_playing())
	AudioDirector.begin_segment({"audio": {"music": false}})
	assert_bool(AudioDirector.is_music_playing()).is_false()
	AudioDirector._process(AudioDirector.CROSSFADE_SEC)
	assert_bool(AudioDirector._decks[0].playing or AudioDirector._decks[1].playing).is_false()


func test_the_riders_own_music_fades_game_music_out_and_back_in() -> void:
	AudioDirector.register_music_generator(_stems)
	AudioDirector.register_sound("whoosh", _tone())
	AudioDirector.play_music({"name": "drive"}, 90.0, 7)
	await _until(func(): return AudioDirector.is_music_playing())
	InputBus._sim_rider_music = true  # the frame says the rider's music app has a track
	await _until(func(): return AudioDirector.rider_music)
	assert_bool(AudioDirector.is_music_playing()).is_false()
	assert_bool(AudioDirector.play_sfx("whoosh")).override_failure_message("effects keep playing").is_true()
	# A game asking for its music meanwhile is kept, not played.
	AudioDirector.play_music({"name": "climb"}, 100.0, 7)
	await await_millis(100)
	assert_bool(AudioDirector.is_music_playing()).is_false()
	InputBus._sim_rider_music = false
	await _until(func(): return AudioDirector.is_music_playing())
	assert_str(AudioDirector.current_music_key()).contains("climb")


func test_stems_follow_intensity_gates() -> void:
	AudioDirector.register_music_generator(_stems)
	AudioDirector.set_intensity(0.2)
	AudioDirector.play_music({"name": "drive", "stem_gates": {"lead": 0.6}}, 90.0, 7)
	await _until(func(): return AudioDirector.is_music_playing())
	assert_float(AudioDirector.stem_level("drums")).is_equal(1.0)
	assert_float(AudioDirector.stem_level("lead")).is_equal(0.0)
	AudioDirector.set_intensity(0.8)
	AudioDirector._process(AudioDirector.STEM_FADE_SEC)
	assert_float(AudioDirector.stem_level("lead")).is_equal(1.0)
	assert_float(AudioDirector.stem_level("missing")).is_equal(-1.0)


func test_cues_duck_the_music_then_release() -> void:
	AudioDirector.register_sound("go", _tone(0.25))
	AudioDirector.play_cue("go")
	AudioDirector._process(0.1)
	assert_float(AudioDirector.duck_db).is_equal(AudioDirector.DUCK_DB)
	AudioDirector._process(0.2)  # the cue is over
	AudioDirector._process(AudioDirector.DUCK_RELEASE_SEC)
	assert_float(AudioDirector.duck_db).is_equal(0.0)


func test_pre_rendered_stem_files_play_without_a_generator_and_loop_past_the_intro() -> void:
	var path := "res://games/demo/music/warm_up_bed.ogg"
	AudioDirector.play_music({"name": "files", "stem_files": {"mix": path}, "loop_from": 1.5}, 150.0)
	await _until(func(): return AudioDirector.is_music_playing())
	assert_bool(AudioDirector.is_music_playing()).is_true()
	var sync := AudioDirector._decks[AudioDirector._deck].stream as AudioStreamSynchronized
	var s := sync.get_sync_stream(0) as AudioStreamOggVorbis
	assert_bool(s.loop).is_true()
	assert_float(s.loop_offset).is_equal(1.5)
	assert_str(str(s.get_meta("source_path"))).is_equal(path)
	# A missing file plays nothing (and doesn't crash).
	assert_dict(AudioDirector.stems_from_files({"stem_files": {"mix": "res://no/such.ogg"}})).is_empty()


func test_a_game_duck_holds_then_releases_and_the_deeper_duck_wins() -> void:
	AudioDirector.duck_music(-3.0, 0.5)
	AudioDirector._process(0.1)
	assert_float(AudioDirector.duck_db).is_equal(-3.0)
	AudioDirector.duck_music(-2.0, 1.0)  # extends the hold, keeps the deeper duck
	AudioDirector._process(0.6)
	assert_float(AudioDirector.duck_db).is_equal(-3.0)
	# A cue's duck is deeper: it wins while the cue sounds.
	AudioDirector.register_sound("go", _tone(0.25))
	AudioDirector.play_cue("go")
	AudioDirector._process(0.1)
	assert_float(AudioDirector.duck_db).is_equal(AudioDirector.DUCK_DB)
	AudioDirector._process(0.6)
	AudioDirector._process(AudioDirector.DUCK_RELEASE_SEC)
	assert_float(AudioDirector.duck_db).is_equal(0.0)
	# A new segment drops any duck still held.
	AudioDirector.duck_music(-3.0, 10.0)
	AudioDirector.begin_segment(SEGMENT_AUDIO)
	AudioDirector._process(AudioDirector.DUCK_RELEASE_SEC)
	assert_float(AudioDirector.duck_db).is_equal(0.0)


func test_a_game_can_put_a_limiter_on_master_and_each_segment_clears_it() -> void:
	var limiter := AudioEffectHardLimiter.new()
	AudioDirector.set_bus_effects(AudioDirector.MASTER_BUS, [limiter])
	assert_array(AudioDirector.bus_effects(AudioDirector.MASTER_BUS)).contains_exactly([limiter])
	AudioDirector.begin_segment(SEGMENT_AUDIO)
	assert_array(AudioDirector.bus_effects(AudioDirector.MASTER_BUS)).is_empty()


func test_pause_pauses_music_and_effects_not_cues() -> void:
	AudioDirector.register_music_generator(_stems)
	AudioDirector.register_sound("thud", _tone(5.0))
	AudioDirector.play_music({"name": "drive"}, 90.0, 7)
	await _until(func(): return AudioDirector.is_music_playing())
	var sfx: AudioStreamPlayer = AudioDirector._sfx_players[AudioDirector._next_sfx]
	var cue: AudioStreamPlayer = AudioDirector._cue_players[AudioDirector._next_cue]
	AudioDirector.play_sfx("thud")
	AudioDirector.play_cue("thud")
	var music: AudioStreamPlayer = AudioDirector._decks[AudioDirector._deck]
	AudioDirector.set_paused(true)
	assert_bool(music.stream_paused).is_true()
	assert_bool(sfx.stream_paused).is_true()
	assert_bool(cue.stream_paused).is_false()
	AudioDirector.set_paused(false)
	assert_bool(music.stream_paused).is_false()
	assert_bool(sfx.stream_paused).is_false()


func _until(condition: Callable, timeout_ms := 2000) -> void:
	var start := Time.get_ticks_msec()
	while not condition.call() and Time.get_ticks_msec() - start < timeout_ms:
		await get_tree().process_frame


## The music cache's size comes from each WAV's length: reading `data` copies it (6 MB a stem
## for Cadence Karaoke), which froze the main thread ~300 ms on every render on the bike.
func test_the_cache_size_doesnt_copy_the_stems() -> void:
	for stereo in [false, true]:
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.stereo = stereo
		wav.mix_rate = 32000
		var pcm := PackedByteArray()
		pcm.resize(32000 * (4 if stereo else 2))
		wav.data = pcm
		assert_int(AudioDirector.wav_bytes(wav)).is_equal(pcm.size())
