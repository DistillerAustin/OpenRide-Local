extends SceneTree
## Renders Kart Race's audio offline to WAV files, for listening and analysis without speakers
## (#43, the audio pass). Headless Godot has no audio output, so this mixes every player itself,
## the way the AudioServer would: each AudioStreamPlayer's stream read at its pitch_scale and
## volume_db, through its bus's volume (the music duck included), frame by frame.
##   $GODOT_BIN --headless --path games -s res://tests/render_kart_audio.gd -- --out=/abs/dir
##       [--only=sfx,engine,bots,music,race] [--seconds=0]
## Writes 22.05 kHz mono 32-bit float WAVs (floats keep any overs visible), plus JSON timelines:
## - `sfx/<name>.wav`: every kart effect and racer horn, as AudioDirector would play it.
## - `engine_sweep.wav` (+ `.json`): KartAudio driven by a scripted kart: idle, full throttle to
##   cruise, a drift through its three tiers, the boost, a coast down and idle again.
## - `bots_pass.wav` (+ `.json`): the rider cruising while seven bots close in, pass and drop
##   back, with the bot-engine voices KartAudio keeps.
## - `music_<state>.wav`: one loop of the kart_circuit stems at each state's intensity (intro,
##   race, front, final lap, results), and `music_lift.wav`: the race music crossfading into
##   the final lap's.
## - `race_mix.wav` (+ `race_music.wav`, `race_sfx.wav`, `race.json`): a headless race (a bot
##   drives the rider) from the flyover to the results, every sound mixed as played; the JSON
##   has each sound with its frame, the HUD's pops with theirs, and the duck. `--seconds=N`
##   stops after N seconds of racing (0: the whole race).
## Mono throughout: every game sound is mono and non-positional.

const Dsp := preload("res://audio/Dsp.gd")
const SR := 22050
const DT := 1.0 / 60.0

var out_dir := ""
var KA: GDScript  # KartAudio, loaded once the autoloads exist (it uses them)
var _input_bus: Node  # an autoload: a -s script compiles before they exist
var _pcm := {}  # stream instance id -> PackedFloat32Array


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var only := "sfx,engine,bots,music,race"
	var seconds := 0.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.get_slice("=", 1)
		elif a.begins_with("--only="):
			only = a.get_slice("=", 1)
		elif a.begins_with("--seconds="):
			seconds = float(a.get_slice("=", 1))
	if out_dir.is_empty():
		push_error("render_kart_audio: --out=<dir> is required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out_dir + "/sfx")
	var director: Node = root.get_node("AudioDirector")
	director.set_process(false)  # this script steps it, frame by frame
	KA = load("res://games/kart_race/audio/KartAudio.gd")
	_input_bus = root.get_node("InputBus")
	_input_bus.set_process(false)  # and sets the rider's power itself
	KartSfx.register()
	while not KartSfx.warmed():  # the kart sounds render on a worker thread
		await process_frame
	var t0 := Time.get_ticks_msec()
	if "sfx" in only:
		_render_sfx(director)
	if "engine" in only:
		await _render_engine(director)
	if "bots" in only:
		await _render_bots(director)
	if "music" in only:
		_render_music()
	if "race" in only:
		await _render_race(director, seconds)
	print("RENDER done in %.1f s -> %s" % [(Time.get_ticks_msec() - t0) / 1000.0, out_dir])
	quit()


# --- Effects ---

func _render_sfx(director: Node) -> void:
	var names: Array = KartSfx.names()
	for id in KartRoster.ids():
		names.append(KartSfx.horn(id))
	for sound in names:
		var stream: AudioStream = director._stream_for(sound)
		if stream is AudioStreamWAV:
			write_wav("%s/sfx/%s.wav" % [out_dir, sound], pcm(stream))
	print("RENDER sfx %d" % names.size())


# --- Scripted kart scenes ---

## A race on a test oval with the karts placed by hand, and a KartAudio listening to it.
func _scene() -> Dictionary:
	var race := KartRaceLogic.new()
	var racers := []
	for i in 8:
		racers.append({"racer_id": KartRoster.ids()[i % KartRoster.ids().size()]})
	race.setup(KartTrackModel.new(load("res://tests/kart_fixtures.gd").oval(600.0, 60.0)), racers, 3)
	race.phase = KartRaceLogic.Phase.RACING
	var audio: Node = KA.new()
	root.add_child(audio)
	audio.listen(race)
	for i in range(1, race.karts.size()):  # the bots far off unless placed
		_place(race, i, race.track.length * 0.5, 0.0)
	return {"race": race, "audio": audio}


func _place(race: KartRaceLogic, id: int, s: float, d: float) -> void:
	var k: KartState = race.karts[id]
	k.s = race.track.wrap(s)
	k.d = d
	k.pos = race.track.position_at(k.s, d)
	k.heading = race.track.yaw_at(k.s)


func _render_engine(director: Node) -> void:
	var sc := _scene()
	var race: KartRaceLogic = sc.race
	var audio: Node = sc.audio
	var k: KartState = race.karts[0]
	var mix := Mixer.new(self, director, audio)
	var log := []
	var s := 200.0  # clear of the grandstand at the start line
	var tier_at := [10.0, 11.3, 12.6]
	var tier := 0
	var t := 0.0
	while t < 22.0:
		var power := 0.0
		var speed := 0.0
		if t < 1.5:
			speed = 0.0
		elif t < 8.0:
			power = 260.0
			speed = 20.0 * (1.0 - exp(-(t - 1.5) / 1.8))
		elif t < 14.0:
			power = 200.0
			speed = 19.5
		elif t < 16.0:
			power = 220.0
			speed = 19.5 + 6.5 * minf(1.0, (t - 14.0) / 0.35) * (1.0 if t < 15.4 else maxf(0.0, 1.0 - (t - 15.4) / 0.6))
		elif t < 20.0:
			speed = 19.5 * exp(-(t - 16.0) / 1.6)
		else:
			speed = 0.0
		# The drift: 9.0-14.0, three tiers, then the boost.
		var drifting := t >= 9.0 and t < 14.0
		k.drift_dir = 1 if drifting else 0
		while tier < 3 and drifting and t >= tier_at[tier]:
			tier += 1
			k.drift_tier = tier
			race.events.drift_tier.emit(0, tier)
		if not drifting and tier > 0:
			tier = 0
			k.drift_tier = 0
			k.boost_time = 1.4
			race.events.boost_started.emit(0, "drift", 3)
		k.boost_time = maxf(0.0, k.boost_time - DT)
		k.speed = speed
		s += speed * DT
		_place(race, 0, s, 0.0)
		k.speed = speed
		_input_bus.power = power
		_input_bus.cadence = 85.0 if power > 0.0 else 0.0
		audio.step(race, "RACING", DT)
		director._process(DT)
		mix.frame()
		log.append({"t": snappedf(t, 0.001), "speed": snappedf(speed, 0.01), "tier": k.drift_tier,
			"boost": k.boost_time > 0.0, "power": power})
		t += DT
	write_wav(out_dir + "/engine_sweep.wav", limited(mix.master))
	_write_json(out_dir + "/engine_sweep.json", {"frames": log, "events": mix.events})
	audio.queue_free()
	await process_frame
	print("RENDER engine_sweep %.1f s" % t)


## The rider cruising at 18 m/s; seven bots start spread behind and ahead at their own speeds,
## so they close in, pass and fall back.
func _render_bots(director: Node) -> void:
	var sc := _scene()
	var race: KartRaceLogic = sc.race
	var audio: Node = sc.audio
	var mix := Mixer.new(self, director, audio)
	var start := [-40.0, -25.0, -12.0, -5.0, 8.0, 20.0, 35.0]  # metres from the rider
	var speed := [21.5, 20.5, 19.6, 18.8, 17.0, 16.2, 15.5]  # m/s (the rider: 18)
	var log := []
	var t := 0.0
	while t < 14.0:
		var s := 100.0 + 18.0 * t
		race.karts[0].speed = 18.0
		_place(race, 0, s, 0.0)
		var near := 0
		for i in 7:
			var k: KartState = race.karts[i + 1]
			k.speed = speed[i]
			_place(race, i + 1, 100.0 + start[i] + speed[i] * t, -3.0 + 1.0 * i)
			if absf(start[i] + (speed[i] - 18.0) * t) < 25.0:
				near += 1
		_input_bus.power = 180.0
		_input_bus.cadence = 85.0
		audio.step(race, "RACING", DT)
		director._process(DT)
		mix.frame()
		log.append({"t": snappedf(t, 0.001), "bots_within_25m": near, "voices": mix.voices_playing("rival")})
		t += DT
	write_wav(out_dir + "/bots_pass.wav", limited(mix.master))
	_write_json(out_dir + "/bots_pass.json", {"frames": log})
	audio.queue_free()
	await process_frame
	print("RENDER bots_pass %.1f s" % t)


# --- Music ---

func _render_music() -> void:
	var cadence: float = KA.DEFAULT_CADENCE
	var seed := 7
	var base: Dictionary = KA.STYLE.duplicate(true)
	var final: Dictionary = KA.STYLE.duplicate(true)
	final.merge(KA.FINAL_LAP, true)
	var gates: Dictionary = base.stem_gates
	for a in OS.get_cmdline_user_args():  # --final=<json>: try other final-lap overrides
		if a.begins_with("--final="):
			final.merge(JSON.parse_string(a.substr(8)), true)
	var bpm := MusicGen.music_tempo(MusicGen.resolve_style(base), cadence)
	var normal := MusicGen.render_samples(MusicGen.resolve_style(base), bpm, seed)
	var lifted := MusicGen.render_samples(MusicGen.resolve_style(final), bpm, seed)
	var states := {
		"intro": [normal, KA.intensity_for("COUNTDOWN", 8, false, false)],
		"race": [normal, KA.intensity_for("RACING", 6, false, false)],
		"front": [normal, KA.intensity_for("RACING", 2, false, false)],
		"final": [lifted, KA.intensity_for("RACING", 4, false, true)],
		"results": [normal, KA.intensity_for("RESULTS", 4, false, false)],
	}
	var gain := db_to_linear(linear_to_db(0.8))  # the Music bus at the default music_volume
	for state in states:
		var stems: Dictionary = states[state][0]
		var level: float = states[state][1]
		var out := PackedFloat32Array()
		out.resize((stems.drums as PackedFloat32Array).size())
		for stem in stems:
			if level >= float(gates.get(stem, 0.0)):
				Dsp.mix_into(out, stems[stem], 0, gain)
		write_wav("%s/music_%s.wav" % [out_dir, state], out)
	# The lift: 16 s of the race music (intensity 0.55), then the final lap's crossfading in
	# over AudioDirector's 2 s, as the final-lap banner shows.
	var n := int(30.0 * SR)
	var lift := PackedFloat32Array()
	lift.resize(n)
	var at := int(16.0 * SR)
	var fade := int(2.0 * SR)  # AudioDirector.CROSSFADE_SEC
	var race_level: float = KA.intensity_for("RACING", 6, false, false)
	for stem in normal:
		var a: PackedFloat32Array = normal[stem]
		var b: PackedFloat32Array = lifted[stem]
		var on_a: bool = race_level >= float(gates.get(stem, 0.0))
		for i in n:
			var w := clampf(float(i - at) / fade, 0.0, 1.0)
			var y := 0.0
			if on_a:
				y += a[i % a.size()] * cos(w * PI / 2)
			if i >= at:
				y += b[(i - at) % b.size()] * sin(w * PI / 2)
			lift[i] += y * gain
	write_wav(out_dir + "/music_lift.wav", lift)
	_write_json(out_dir + "/music.json", {"tempo_bpm": bpm, "final": final,
		"loop_sec": float((normal.drums as PackedFloat32Array).size()) / SR, "gates": gates,
		"levels": states.keys().map(func(s): return [s, states[s][1]])})
	print("RENDER music")


# --- A race ---

func _render_race(director: Node, seconds: float) -> void:
	var game = load("res://games/kart_race/KartRace.tscn").instantiate()
	game.hud = load("res://framework/hud/Hud.gd").new()
	root.add_child(game.hud)
	root.add_child(game)
	director.begin_segment({"audio": {"music": true, "music_volume": 0.8, "sfx_volume": 1.0}})
	game.prepare({"game_id": "kart_race", "role": "free", "difficulty": "standard", "duration_sec": 1200,
		"end_mode": "game", "seed": 7, "effort": true, "params": {"ftp_watts": 150}})
	var driver := KartBotDriver.new(KartBotDriver.profile_for(2, 1.15), 150.0, 99)
	game.test_input = KartInput.new()
	game.start()
	game.set_process(false)  # this script steps the frame
	var audio: Node = game.get("_audio")
	var mix := Mixer.new(self, director, game)
	var hud: Node = game.get("_kart_hud")
	var pops := []
	var watch := {}
	var duck := []
	var f := 0
	var raced := 0.0
	var finished_at := -1.0
	while true:
		var race: KartRaceLogic = game.race
		driver.items = game.items
		var inp: KartInput = driver.think(race.karts[0], race, DT)
		inp.power_w = 170.0
		inp.cadence = 85.0
		game.test_input = inp
		_input_bus.power = inp.power_w
		_input_bus.cadence = inp.cadence
		game._on_frame(DT)
		director._process(DT)
		mix.frame()
		_watch_hud(hud, watch, pops, mix.t - DT)
		duck.append(snappedf(director.duck_db, 0.01))
		f += 1
		if game.flow == game.Flow.RACING:
			raced += DT
		if race.karts[0].finished and finished_at < 0.0:
			finished_at = mix.t
		if seconds > 0.0 and raced >= seconds:
			break
		if finished_at >= 0.0 and mix.t > finished_at + 8.0:
			break
		if mix.t > 400.0:
			break
		if f % 120 == 0:
			await process_frame  # tweens and the music render's completion
	var pre_peak := 0.0
	for v in mix.master:
		pre_peak = maxf(pre_peak, absf(v))
	write_wav(out_dir + "/race_mix.wav", limited(mix.master))
	write_wav(out_dir + "/race_music.wav", mix.groups.get("music", PackedFloat32Array()))
	write_wav(out_dir + "/race_sfx.wav", mix.minus("music"))
	for g in mix.groups:
		if g != "music":
			write_wav("%s/race_%s.wav" % [out_dir, g], mix.groups[g])
	_write_json(out_dir + "/race.json", {"events": mix.events, "hud": pops, "duck_db": duck,
		"race_start": mix.race_start, "finished_at": finished_at, "laps": game.race.laps,
		"groups": mix.groups.keys(), "pre_limiter_peak_db": linear_to_db(pre_peak),
		"master_limiter": _master_limiter() != null})
	print("RENDER race %.1f s (raced %.1f s, finished at %.1f)" % [mix.t, raced, finished_at])
	game.queue_free()
	await process_frame


## The HUD's pops, by what changed on screen this frame (the audio must land on the same frame).
func _watch_hud(hud: Node, w: Dictionary, pops: Array, t: float) -> void:
	if hud == null:
		return
	var now := {
		"place": hud.get("_shown_place"),
		"count": (hud.get("_count") as Label).text if (hud.get("_count") as Label).visible else "",
		"banner": (hud.get("_banner_label") as Label).text if (hud.get("_banner") as Control).visible else "",
		"item": hud.item_button.get("_shown_item"),
		"tier": hud.item_button.get("_tier"),
	}
	for key in now:
		if w.has(key) and now[key] != w[key] and str(now[key]) != "" and str(now[key]) != "0":
			pops.append({"t": snappedf(t, 0.0001), "what": key, "value": str(now[key])})
		w[key] = now[key]


# --- Output ---

func _master_limiter() -> AudioEffectHardLimiter:
	for i in AudioServer.get_bus_effect_count(0):
		var e := AudioServer.get_bus_effect(0, i)
		if e is AudioEffectHardLimiter and AudioServer.is_bus_effect_enabled(0, i):
			return e
	return null


## The mix through Master's hard limiter, if the game put one there (the AudioServer would
## apply it): pre-gain, then a gain that never lets a sample over the ceiling and recovers over
## the release. No look-ahead, so it reads a touch harsher than Godot's.
func limited(buf: PackedFloat32Array) -> PackedFloat32Array:
	var lim := _master_limiter()
	if lim == null:
		return buf
	var out := buf.duplicate()
	var pre := db_to_linear(lim.pre_gain_db)
	var ceiling := db_to_linear(lim.ceiling_db)
	var rel := exp(-1.0 / (maxf(lim.release, 0.001) * SR))
	var env := 0.0
	for i in out.size():
		var x := out[i] * pre
		env = maxf(absf(x), env * rel)
		out[i] = x * (ceiling / env if env > ceiling else 1.0)
	return out

## A 16-bit or float AudioStreamWAV's samples as floats (cached per stream).
func pcm(stream: AudioStreamWAV) -> PackedFloat32Array:
	var id := stream.get_instance_id()
	if _pcm.has(id):
		return _pcm[id]
	var data := stream.data
	var out := PackedFloat32Array()
	if stream.format == AudioStreamWAV.FORMAT_16_BITS:
		var n := data.size() / 2
		out.resize(n)
		for i in n:
			out[i] = data.decode_s16(i * 2) / 32768.0
	elif stream.format == AudioStreamWAV.FORMAT_8_BITS:
		out.resize(data.size())
		for i in data.size():
			out[i] = data.decode_s8(i) / 128.0
	_pcm[id] = out
	return out


static func write_wav(path: String, samples: PackedFloat32Array) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	var n := samples.size()
	f.store_32(0x46464952)
	f.store_32(36 + n * 4)
	f.store_32(0x45564157)
	f.store_32(0x20746d66)
	f.store_32(16)
	f.store_16(3)  # IEEE float
	f.store_16(1)
	f.store_32(SR)
	f.store_32(SR * 4)
	f.store_16(4)
	f.store_16(32)
	f.store_32(0x61746164)
	f.store_32(n * 4)
	f.store_buffer(samples.to_byte_array())
	f.close()


func _write_json(path: String, data: Variant) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()


## Mixes every AudioStreamPlayer under `scope` and AudioDirector's own, one 60 Hz frame at a time:
## reads each player's state after the frame's update and renders that frame's samples.
class Mixer:
	var tool
	var director: Node
	var scope: Node
	var master := PackedFloat32Array()
	var groups := {}  # group name -> PackedFloat32Array
	var events := []  # [{t, sound, bus, db, pitch}]
	var t := 0.0
	var race_start := -1.0
	var _voices := {}  # key -> Voice
	var _n := 0  # samples rendered

	func _init(render_tool, audio_director: Node, root_node: Node) -> void:
		tool = render_tool
		director = audio_director
		scope = root_node
		director.sound_played.connect(_on_sound)
		director.music_started.connect(_on_music)

	func _on_sound(sound: String, bus: String) -> void:
		var players: Array = director._sfx_players if bus == director.SFX_BUS else director._cue_players
		var next: int = director._next_sfx if bus == director.SFX_BUS else director._next_cue
		var p: AudioStreamPlayer = players[posmod(next - 1, players.size())]
		events.append({"t": snappedf(t, 0.0001), "sound": sound, "bus": bus, "db": snappedf(p.volume_db, 0.1),
			"pitch": snappedf(p.pitch_scale, 0.001)})
		if sound == "kart_go" and race_start < 0.0:
			race_start = t
		var v := Voice.new()
		v.data = tool.pcm(p.stream)
		v.loop = false
		v.player = p
		v.group = "oneshot"
		v.name = sound
		v.gain = _gain(p)
		_voices["p%d" % p.get_instance_id()] = v  # a pooled player cuts off its last sound

	func _on_music(_key: String) -> void:
		var deck: AudioStreamPlayer = director._decks[director._deck]
		var sync := deck.stream as AudioStreamSynchronized
		for i in sync.stream_count:
			var v := Voice.new()
			v.stream = sync.get_sync_stream(i)
			v.data = tool.pcm(v.stream)
			v.loop = true
			v.player = deck
			v.stem = i
			v.group = "music"
			v.name = "music"
			v.pos = deck.get_playback_position() * SR
			v.gain = 0.0
			_voices["d%d_%d" % [deck.get_instance_id(), i]] = v

	## The voices of a group playing above -40 dB.
	func voices_playing(group: String) -> int:
		var n := 0
		for v: Voice in _voices.values():
			if v.group == group and v.active and v.gain > 0.01:
				n += 1
		return n

	func minus(group: String) -> PackedFloat32Array:
		var out := master.duplicate()
		var g: PackedFloat32Array = groups.get(group, PackedFloat32Array())
		for i in mini(out.size(), g.size()):
			out[i] -= g[i]
		return out

	func _gain(p: AudioStreamPlayer) -> float:
		var bus := AudioServer.get_bus_index(p.bus)
		return db_to_linear(p.volume_db + AudioServer.get_bus_volume_db(bus) + AudioServer.get_bus_volume_db(0))

	func frame() -> void:
		t += DT
		var end := int(round(t * SR))
		var n := end - _n
		master.resize(end)
		for g in groups:
			var gb: PackedFloat32Array = groups[g]  # a copy on write: store it back
			gb.resize(end)
			groups[g] = gb
		# Loops on the scene's own players (KartAudio's engine, tyres, crowd, ...).
		for p: AudioStreamPlayer in scope.find_children("*", "AudioStreamPlayer", true, false):
			var key := "p%d" % p.get_instance_id()
			var v: Voice = _voices.get(key)
			if p.playing and p.stream is AudioStreamWAV:
				if v == null or v.player != p or not v.active or v.stream != p.stream:
					v = Voice.new()
					v.data = tool.pcm(p.stream)
					v.stream = p.stream
					v.loop = (p.stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED
					v.player = p
					v.group = _group_of(p)
					v.name = str(p.name)
					v.gain = 0.0
					_voices[key] = v
			elif v:
				v.active = false
		var dead := []
		for key in _voices:
			var v: Voice = _voices[key]
			if not v.active:
				dead.append(key)
				continue
			var g1 := 0.0
			var pitch := 1.0
			if is_instance_valid(v.player):
				pitch = v.player.pitch_scale if not v.player.stream_paused else 0.0
				if v.stem >= 0:
					var sync := v.player.stream as AudioStreamSynchronized
					if not v.player.playing or sync == null or v.stem >= sync.stream_count or sync.get_sync_stream(v.stem) != v.stream:
						v.active = false
						continue
					g1 = db_to_linear(sync.get_sync_stream_volume(v.stem)) * _gain(v.player)
				elif v.group == "oneshot":
					g1 = _gain(v.player)
				else:
					g1 = _gain(v.player) if v.player.playing else 0.0
			if not groups.has(v.group):
				var buf := PackedFloat32Array()
				buf.resize(end)
				groups[v.group] = buf
			var buf: PackedFloat32Array = groups[v.group]
			v.render(master, buf, _n, n, g1, pitch)
			groups[v.group] = buf
		for key in dead:
			_voices.erase(key)
		_n = end

	func _group_of(p: AudioStreamPlayer) -> String:
		var nm := str(p.name).to_lower()
		for g in ["engine", "rival", "bot", "screech", "sizzle", "crowd", "wind"]:
			if nm.contains(g):
				return "rival" if g == "bot" else g
		# The players KartAudio didn't name (before the audio pass): by the field holding them.
		var owner := p.get_parent()
		for field in ["_engine", "_rival", "_screech", "_crowd"]:
			if field in owner and owner.get(field) == p:
				return field.substr(1)
		return "loop"


class Voice:
	var data: PackedFloat32Array
	var stream: AudioStream
	var loop := false
	var player: AudioStreamPlayer
	var stem := -1
	var group := ""
	var name := ""
	var pos := 0.0
	var gain := 0.0  # the previous frame's, ramped to this frame's
	var active := true

	func render(master: PackedFloat32Array, group_buf: PackedFloat32Array, start: int, n: int, g1: float, pitch: float) -> void:
		var size := data.size()
		if size == 0 or n <= 0:
			return
		var g0 := gain
		gain = g1
		if g0 < 1e-5 and g1 < 1e-5:
			pos = fmod(pos + pitch * n, size) if loop else pos + pitch * n
			if not loop and pos >= size:
				active = false
			return
		var p := pos
		var dg := (g1 - g0) / n
		var g := g0
		for i in n:
			var ip := int(p)
			var fr := p - ip
			var a := data[ip]
			var b := data[ip + 1] if ip + 1 < size else (data[0] if loop else 0.0)
			var y := (a + (b - a) * fr) * g
			master[start + i] += y
			group_buf[start + i] += y
			g += dg
			p += pitch
			if p >= size:
				if loop:
					p -= size
				else:
					active = false
					break
		pos = p
