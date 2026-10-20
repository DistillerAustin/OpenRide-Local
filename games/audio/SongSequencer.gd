class_name SongSequencer
extends RefCounted
## Music that follows a tempo, from produced instruments (#55; Cadence Karaoke's song). A song is a
## **sample bank** (one OGG holding every note the song plays, each rendered once offline at the
## length the slowest tempo needs) and a **score** (per track: each note's beat, sample and gate),
## both written by games/tools/music (sequencer.py). This lays the score out at the requested
## tempo and returns looping stems for AudioDirector, like MusicGen does:
##
## - **Native work only, bar a few fades.** The bank is decoded once per session
##   (AudioStreamPlayback.mix_audio) to 16-bit PCM. Each track is built by copying slices of it
##   (one note at a time: a note plays until the next on its track, its gate plus the track's
##   release, or its end; a cut note fades over the release) and padding with silence. Each
##   stem's tracks are summed natively (AudioStreamSynchronized through mix_audio). Nothing is
##   time-stretched, so the instruments sound the same at every tempo.
## - **The tempo:** one beat per requested beat from `tempo_min` to `tempo_max`; below the range
##   it doubles (two beats a pedal stroke), above it halves.
## - **Safe on a worker thread** (AudioDirector runs generators on one).
##
## A game asks for it with a style naming the song script (a `SONG` const):
##   AudioDirector.play_music({"name": "neon_lines", "song": "res://.../CadenceMusic.gd",
##       "bars": 24, "stem_gates": {...}}, rpm, seed)

const BYTES_PER_FRAME := 4  ## 16-bit stereo
const DECODE_CHUNK_SEC := 8.0

static var _banks := {}  # bank path -> PackedByteArray (16-bit stereo PCM)
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
		var sync := AudioStreamSynchronized.new()
		var tracks: Array = by_stem[stem]
		sync.stream_count = tracks.size()
		for i in tracks.size():
			sync.set_sync_stream(i, _wav(track_pcm(tracks[i], song, bank, bpm, total), sr, false))
			sync.set_sync_stream_volume(i, float(tracks[i].gain_db))
		var playback := sync.instantiate_playback()
		playback.start(0.0)
		var frames: PackedVector2Array = playback.mix_audio(AudioServer.get_mix_rate() / sr, total)
		var wav := _wav_from_frames(frames, sr)
		if wav:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = total
			stems[stem] = wav
	return stems


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
		var wav := _wav_from_frames(playback.mix_audio(rate, n), sr)
		if wav == null:
			return PackedByteArray()
		pcm.append_array(wav.data)
		done += n
	_mutex.lock()
	_banks[path] = pcm
	_mutex.unlock()
	return pcm


## Drops the decoded banks (tests).
static func clear_cache() -> void:
	_mutex.lock()
	_banks.clear()
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
