extends GdUnitTestSuite
## SongSequencer (#55): music that follows a tempo, laid out from a sample bank and a score
## (Cadence Karaoke's "Neon Lines"), and the games' rendered music and effects.

const CADENCE_MUSIC := "res://games/cadence_karaoke/CadenceMusic.gd"
const GAME_MUSIC := ["res://games/dodge_ball/DodgeMusic.gd", "res://games/tug_of_war/TugMusic.gd",
	"res://games/safe_cracker/SafeMusic.gd", "res://games/demo/DemoMusic.gd"]


func _song() -> Dictionary:
	return load(CADENCE_MUSIC).get_script_constant_map().SONG


func test_the_tempo_is_the_cadence_doubled_below_the_range() -> void:
	var song := _song()
	assert_float(SongSequencer.music_tempo(song, 90.0)).is_equal(90.0)
	assert_float(SongSequencer.music_tempo(song, 70.0)).is_equal(70.0)
	assert_float(SongSequencer.music_tempo(song, 60.0)).is_equal(120.0)
	assert_float(SongSequencer.music_tempo(song, 40.0)).is_equal(80.0)
	assert_float(SongSequencer.music_tempo(song, 120.0)).is_equal(120.0)


func test_stems_are_the_loop_long_at_every_tempo() -> void:
	var song := _song()
	for bpm in [70.0, 100.0, 130.0]:
		var stems := SongSequencer.render(song, bpm)
		assert_array(stems.keys()).contains_exactly_in_any_order(["bed", "harmony", "lead"])
		var frames := SongSequencer.loop_frames(song, bpm)
		assert_int(frames).is_equal(roundi(24 * 4 * 60.0 / bpm * float(song.sr)))
		for stem in stems:
			var wav: AudioStreamWAV = stems[stem]
			assert_int(wav.data.size() / 4).is_equal(frames)
			assert_bool(wav.stereo).is_true()
			assert_int(wav.loop_mode).is_equal(AudioStreamWAV.LOOP_FORWARD)
			assert_int(wav.loop_end).is_equal(frames)
		# Not silence: the bed has the drums and bass.
		var bed: AudioStreamWAV = stems.bed
		var loud := 0
		for i in range(0, bed.data.size(), 4000):
			loud = maxi(loud, absi(bed.data.decode_s16(i)))
		assert_int(loud).is_greater(3000)


func test_a_note_plays_to_its_gate_and_fades() -> void:
	# A bank of one sample (1000 frames of full scale) and a track with two notes.
	var bank := PackedByteArray()
	bank.resize(1000 * 4)
	for f in 1000:
		bank.encode_s16(f * 4, 20000)
		bank.encode_s16(f * 4 + 2, 20000)
	var song := {"sr": 1000, "samples": [[0, 1000]]}
	# 60 bpm at 1000 frames/s: a beat is 1000 frames. Note 1 at beat 0, gated at 0.3 beats with a
	# 0.1 s release: 300 frames, then a 100-frame fade. Note 2 at beat 1, ungated: it runs on.
	var track := {"release": 0.1, "notes": [0.0, 0, 0.3, 1.0, 0, -1.0]}
	var pcm := SongSequencer.track_pcm(track, song, bank, 60.0, 1500)
	assert_int(pcm.size()).is_equal(1500 * 4)
	assert_int(pcm.decode_s16(299 * 4)).is_equal(20000)
	assert_int(pcm.decode_s16(399 * 4)).is_equal(0)
	assert_int(pcm.decode_s16(350 * 4)).is_between(8000, 12000)
	assert_int(pcm.decode_s16(700 * 4)).is_equal(0)
	assert_int(pcm.decode_s16(1000 * 4)).is_equal(20000)
	# Cut by the loop's end (500 frames into a 1000-frame sample): faded to silence there.
	assert_int(absi(pcm.decode_s16(1499 * 4))).is_less(300)


## The stems come from an offline AudioStreamPolyphonic (no whole-loop WAV per track, whose data
## copy held the AudioServer lock and made the live music skip, 2026-10-20). They must sound like
## the tracks laid out by track_pcm and summed at their gains.
func test_a_stem_is_its_tracks_laid_out_and_summed() -> void:
	var song := _song()
	var bank := SongSequencer.bank_pcm(song)
	var bpm := 130.0
	var total := SongSequencer.loop_frames(song, bpm)
	var tracks: Array = song.tracks.filter(func(t): return t.stem == "bed")
	var got := SongSequencer.stem_frames(tracks, song, bpm, total)
	assert_int(got.size()).is_equal(total)
	# The reference: each track's PCM, padded, summed through AudioStreamSynchronized.
	var sync := AudioStreamSynchronized.new()
	sync.stream_count = tracks.size()
	for i in tracks.size():
		var pcm := SongSequencer.track_pcm(tracks[i], song, bank, bpm, total)
		pcm.resize(pcm.size() + 1024 * 4)
		sync.set_sync_stream(i, SongSequencer._wav(pcm, int(song.sr), false))
		sync.set_sync_stream_volume(i, float(tracks[i].gain_db))
	var playback := sync.instantiate_playback()
	playback.start(0.0)
	var want := playback.mix_audio(AudioServer.get_mix_rate() / float(song.sr), total)
	var err := 0.0
	var power := 0.0
	for i in range(0, total - 256, 5):
		err += (got[i] - want[i]).length_squared()
		power += want[i].length_squared()
	assert_float(sqrt(err / power)).is_less(0.02)


func test_the_generator_answers_a_song_style() -> void:
	var stems := SongSequencer.generate({"style": {"song": CADENCE_MUSIC}, "tempo_bpm": 60.0, "seed": 0})
	assert_int((stems.bed as AudioStreamWAV).data.size() / 4).is_equal(SongSequencer.loop_frames(_song(), 120.0))
	assert_dict(SongSequencer.generate({"style": {"song": "res://no/such.gd"}, "tempo_bpm": 60.0})).is_empty()


func test_every_game_ships_its_stems_and_sounds() -> void:
	for path in GAME_MUSIC:
		var consts: Dictionary = load(path).get_script_constant_map()
		assert_array(consts.STEM_FILES.keys()).contains_exactly_in_any_order(["bed", "harmony", "lead"])
		var stems := AudioDirector.stems_from_files({"stem_files": consts.STEM_FILES, "loop_from": consts.LOOP_FROM})
		assert_int(stems.size()).is_equal(3)
		var length: float = (stems.bed as AudioStream).get_length()
		for stem in stems:
			assert_float((stems[stem] as AudioStream).get_length()).is_equal_approx(length, 0.05)
		assert_float(consts.LOOP_FROM).is_between(0.5, length - 30.0)
		for sound in consts.SOUNDS:
			assert_object(load(consts.SOUNDS[sound])).is_not_null()
	var cadence: Dictionary = load(CADENCE_MUSIC).get_script_constant_map()
	for sound in cadence.SOUNDS:
		assert_object(load(cadence.SOUNDS[sound])).is_not_null()


func test_the_cues_are_rendered_and_registered() -> void:
	var cues: Dictionary = load("res://audio/CueSounds.gd").get_script_constant_map().SOUNDS
	for cue in ["countdown", "go", "segment_end", "pause", "resume", "summary"]:
		assert_bool(cues.has(cue)).is_true()
		assert_object(AudioDirector._stream_for(cue)).is_same(AudioDirector._sounds.get(cue))
