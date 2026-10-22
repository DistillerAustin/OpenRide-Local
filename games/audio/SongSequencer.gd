class_name SongSequencer
extends RefCounted
## Music that follows a tempo, from produced instruments (#55; Cadence Karaoke's song). A song is a
## **sample bank** (one OGG holding every note the song plays, each rendered once offline at the
## length the slowest tempo needs) and a **score** (per track: each note's beat, sample and gate),
## both written by games/tools/music (sequencer.py). This lays the score out at the requested
## tempo and returns looping stems for AudioDirector, like MusicGen does:
##
## - **Native work only.** The bank is decoded once per session (AudioStreamPlayback.mix_audio)
##   to 16-bit PCM, and cut into one AudioStreamWAV per sample. A stem's notes (a note plays
##   until the next on its track, its gate plus the track's release, or its end; a cut note
##   fades over the release) play through an AudioStreamPolyphonic mixed offline (`stem_frames`).
##   Nothing is time-stretched, so the instruments sound the same at every tempo. `track_pcm`
##   lays out one track the same way, as PCM (tests compare the two).
## - **The tempo:** one beat per requested beat from `tempo_min` to `tempo_max`; below the range
##   it doubles (two beats a pedal stroke), above it halves.
## - **Safe on a worker thread** (AudioDirector runs generators on one).
##
## A game asks for it with a style naming the song script (a `SONG` const):
##   AudioDirector.play_music({"name": "neon_lines", "song": "res://.../CadenceMusic.gd",
##       "bars": 24, "stem_gates": {...}}, rpm, seed)

const BYTES_PER_FRAME := 4  ## 16-bit stereo
const DECODE_CHUNK_SEC := 1.0  ## small WAVs (their data copy holds the AudioServer lock)

const FADE_STEP := 32  ## frames per volume step of a note's fade (1 ms)

static var _banks := {}  # bank path -> PackedByteArray (16-bit stereo PCM)
static var _sample_wavs := {}  # bank path -> [AudioStreamWAV per sample]
static var _mutex := Mutex.new()


## The AudioDirector music generator for styles with `song`: {stem: looping AudioStreamWAV}.
static func generate(request: Dictionary) -> Dictionary:
	var style: Dictionary = request.get("style", {})
	var script: Resource = load(str(style.get("song", ""))) if ResourceLoader.exists(str(style.get("song", ""))) else null
	if script == null or not (script is GDScript) or not (script as GDScript).get_script_constant_map().has("SONG"):
		push_warning("SongSequencer: no song %s" % style.get("song", ""))
		return {}
	var song: Dictionary = (script as GDScript).get_script_constant_map().SONG
	return render(song, music_tempo(song, float(request.get("tempo_bpm", 100.0))))


## The tempo the song plays at for a requested tempo (a cadence): doubled below the song's range,
## halved above it.
static func music_tempo(song: Dictionary, tempo_bpm: float) -> float:
	var bpm := maxf(tempo_bpm, 1.0)
	if bpm < float(song.tempo_min):
		bpm *= 2.0
	if bpm > float(song.tempo_max):
		bpm /= 2.0
	return bpm


## Frames in one loop of the song at `bpm`.
static func loop_frames(song: Dictionary, bpm: float) -> int:
	return int(round(float(song.bars) * 4.0 * 60.0 / bpm * float(song.sr)))


## The stems at `bpm`, each a looping 16-bit stereo AudioStreamWAV exactly loop_frames() long.
static func render(song: Dictionary, bpm: float) -> Dictionary:
	var bank := bank_pcm(song)
	if bank.is_empty():
		return {}
	var sr := int(song.sr)
	var total := loop_frames(song, bpm)
	var by_stem := {}
	for track in song.tracks:
		by_stem.get_or_add(str(track.stem), []).append(track)
	var stems := {}
	for stem in by_stem:
		var frames := stem_frames(by_stem[stem], song, bpm, total)
		if frames.is_empty():
			return {}
		var wav := _wav_from_frames(frames, sr)
		if wav == null:
			return {}
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = total
		stems[stem] = wav
	return stems


## A stem's tracks laid out at `bpm` and summed: `total` stereo frames. The notes play from the
## bank's samples (one AudioStreamWAV each, made once per session) through an
## AudioStreamPolyphonic mixed offline, one span between note events at a time; a cut note's
## fade steps its volume. Nothing here sets a WAV's data, which holds the AudioServer lock while
## it copies: the old way built a whole-loop WAV per track (73 MB a render), and the live mixer,
## which skips a buffer when it can't take that lock, dropped ~0.3 s of music on every tempo
## change (Cadence Karaoke on the bike, 2026-10-20). Same layout as `track_pcm`.
static func stem_frames(tracks: Array, song: Dictionary, bpm: float, total: int) -> PackedVector2Array:
	var waves := sample_wavs(song)
	if waves.is_empty():
		return PackedVector2Array()
	var sr := float(song.sr)
	var frames_per_beat := 60.0 / bpm * sr
	var samples: Array = song.samples
	# Notes as [onset, end, fade, sample, gain_db], from the same rules as track_pcm.
	var notes := []
	for track: Dictionary in tracks:
		var release := int(float(track.release) * sr)
		var list: Array = track.notes
		var count := list.size() / 3
		for i in count:
			var onset := int(round(float(list[i * 3]) * frames_per_beat))
			if onset >= total:
				break
			var next := total if i + 1 >= count else mini(int(round(float(list[i * 3 + 3]) * frames_per_beat)), total)
			var index := int(list[i * 3 + 1])
			var length := int(samples[index][1])
			var gate := float(list[i * 3 + 2])
			var n := mini(length, next - onset)
			var fade := 0
			if gate >= 0.0 and int(gate * frames_per_beat) + release < n:
				n = int(gate * frames_per_beat) + release
				fade = release
			elif n < length:
				fade = mini(release, n)
			notes.append([onset, onset + n, fade, index, float(track.gain_db)])
	notes.sort_custom(func(a, b): return a[0] < b[0])
	# Event frames: every onset, fade start and end.
	var marks := {}
	for note in notes:
		marks[note[0]] = true
		var f: int = note[1] - note[2]
		while f < note[1]:
			marks[f] = true  # a fade steps its volume every FADE_STEP frames
			f += FADE_STEP
		marks[note[1]] = true
	marks[total] = true
	var cuts := marks.keys().filter(func(f): return f <= total)
	cuts.sort()
	var poly := AudioStreamPolyphonic.new()
	poly.polyphony = 64
	var playback := poly.instantiate_playback() as AudioStreamPlaybackPolyphonic
	playback.start(0.0)
	var rate := AudioServer.get_mix_rate() / sr
	var out := PackedVector2Array()
	var next_note := 0
	var voices := []  # [id, note]
	var at := 0
	for cut: int in cuts:
		# Notes starting now begin; notes ending now stop.
		var still := []
		for v in voices:
			if v[1][1] <= at:
				playback.stop_stream(v[0])
			else:
				still.append(v)
		voices = still
		while next_note < notes.size() and notes[next_note][0] <= at:
			var note: Array = notes[next_note]
			next_note += 1
			if note[1] <= note[0]:
				continue
			var id := playback.play_stream(waves[note[3]], 0.0, note[4])
			if id != AudioStreamPlaybackPolyphonic.INVALID_ID:
				voices.append([id, note])
		if cut <= at:
			continue
		# Fading voices play this span at their level halfway through it (volume changes apply
		# at once, so a fade is a staircase of FADE_STEP-frame steps).
		for v in voices:
			var note: Array = v[1]
			var fade_from: int = note[1] - note[2]
			if note[2] > 0 and cut > fade_from:
				var left := clampf(1.0 - (0.5 * (at + cut) - fade_from) / note[2], 0.0, 1.0)
				playback.set_stream_volume(v[0], note[4] + (linear_to_db(left) if left > 0.0001 else -80.0))
		out.append_array(playback.mix_audio(rate, cut - at))
		at = cut
	return out


## The bank's samples as AudioStreamWAVs (16-bit stereo), made once per bank: the only WAV data a
## song sets, all at its first render.
static func sample_wavs(song: Dictionary) -> Array:
	var path := str(song.bank)
	_mutex.lock()
	var cached: Array = _sample_wavs.get(path, [])
	_mutex.unlock()
	if not cached.is_empty():
		return cached
	var bank := bank_pcm(song)
	if bank.is_empty():
		return []
	var out := []
	for span: Array in song.samples:
		var from := int(span[0]) * BYTES_PER_FRAME
		out.append(_wav(bank.slice(from, from + int(span[1]) * BYTES_PER_FRAME), int(song.sr), false))
	_mutex.lock()
	_sample_wavs[path] = out
	_mutex.unlock()
	return out


## One track's PCM (16-bit stereo) at `bpm`: its notes laid out, `total` frames long.
static func track_pcm(track: Dictionary, song: Dictionary, bank: PackedByteArray, bpm: float, total: int) -> PackedByteArray:
	var sr := float(song.sr)
	var frames_per_beat := 60.0 / bpm * sr
	var release := int(float(track.release) * sr)
	var samples: Array = song.samples
	var notes: Array = track.notes
	var out := PackedByteArray()
	var count := notes.size() / 3
	if count == 0:
		out.resize(total * BYTES_PER_FRAME)
		return out
	out.resize(mini(int(round(float(notes[0]) * frames_per_beat)), total) * BYTES_PER_FRAME)
	for i in count:
		var onset := int(round(float(notes[i * 3]) * frames_per_beat))
		if onset >= total:
			break
		var next := total if i + 1 >= count else mini(int(round(float(notes[i * 3 + 3]) * frames_per_beat)), total)
		var span: Array = samples[int(notes[i * 3 + 1])]
		var length := int(span[1])
		var gate := float(notes[i * 3 + 2])
		var n := mini(length, next - onset)
		var fade := 0
		if gate >= 0.0 and int(gate * frames_per_beat) + release < n:
			n = int(gate * frames_per_beat) + release
			fade = release
		elif n < length:
			fade = mini(release, n)
		var at := out.size()
		var from := int(span[0]) * BYTES_PER_FRAME
		out.append_array(bank.slice(from, from + n * BYTES_PER_FRAME))
		if fade > 0:
			_fade_out(out, at + (n - fade) * BYTES_PER_FRAME, fade)
		out.resize(out.size() + (next - onset - n) * BYTES_PER_FRAME)
	out.resize(total * BYTES_PER_FRAME)
	return out


## The song's bank as 16-bit stereo PCM at the song's rate, decoded once (native decoding, in
## chunks so no long float buffer is held).
static func bank_pcm(song: Dictionary) -> PackedByteArray:
	var path := str(song.bank)
	_mutex.lock()
	var cached: PackedByteArray = _banks.get(path, PackedByteArray())
	_mutex.unlock()
	if not cached.is_empty():
		return cached
	var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
	if stream == null:
		push_warning("SongSequencer: no bank %s" % path)
		return PackedByteArray()
	var sr := int(song.sr)
	var total := int(song.bank_frames)
	var playback := stream.instantiate_playback()
	playback.start(0.0)
	var rate := AudioServer.get_mix_rate() / sr
	var pcm := PackedByteArray()
	var chunk := int(DECODE_CHUNK_SEC * sr)
	var done := 0
	while done < total:
		var n := mini(chunk, total - done)
		var part := pcm16(playback.mix_audio(rate, n), sr)
		if part.is_empty():
			return PackedByteArray()
		pcm.append_array(part)
		done += n
	_mutex.lock()
	_banks[path] = pcm
	_mutex.unlock()
	return pcm


## Drops the decoded banks (tests).
static func clear_cache() -> void:
	_mutex.lock()
	_banks.clear()
	_sample_wavs.clear()
	_mutex.unlock()


static func _fade_out(pcm: PackedByteArray, at: int, frames: int) -> void:
	for f in frames:
		var g := 1.0 - float(f + 1) / frames
		var i := at + f * BYTES_PER_FRAME
		pcm.encode_s16(i, int(pcm.decode_s16(i) * g))
		pcm.encode_s16(i + 2, int(pcm.decode_s16(i + 2) * g))


static func _wav(pcm: PackedByteArray, sr: int, loop: bool) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = true
	wav.mix_rate = sr
	wav.data = pcm
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = pcm.size() / BYTES_PER_FRAME
	return wav


## Float stereo frames -> 16-bit stereo PCM, converted natively through a small WAV (keep
## `frames` short: the WAV's data copy holds the AudioServer lock).
static func pcm16(frames: PackedVector2Array, sr: int) -> PackedByteArray:
	var wav := _wav_from_frames(frames, sr)
	return wav.data if wav else PackedByteArray()


## Float stereo frames -> a 16-bit stereo AudioStreamWAV, converted natively (Godot's WAV loader
## reads 32-bit float data).
static func _wav_from_frames(frames: PackedVector2Array, sr: int) -> AudioStreamWAV:
	var data := frames.to_byte_array()
	var bytes := PackedByteArray()
	bytes.resize(44)
	bytes.encode_u32(0, 0x46464952)  # "RIFF"
	bytes.encode_u32(4, 36 + data.size())
	bytes.encode_u32(8, 0x45564157)  # "WAVE"
	bytes.encode_u32(12, 0x20746d66)  # "fmt "
	bytes.encode_u32(16, 16)
	bytes.encode_u16(20, 3)  # IEEE float
	bytes.encode_u16(22, 2)
	bytes.encode_u32(24, sr)
	bytes.encode_u32(28, sr * 8)
	bytes.encode_u16(32, 8)
	bytes.encode_u16(34, 32)
	bytes.encode_u32(36, 0x61746164)  # "data"
	bytes.encode_u32(40, data.size())
	bytes.append_array(data)
	return AudioStreamWAV.load_from_buffer(bytes, {
		"compress/mode": 0, "edit/trim": false, "edit/normalize": false, "edit/loop_mode": 0,
		"force/mono": false, "force/8_bit": false, "force/max_rate": false,
	})
