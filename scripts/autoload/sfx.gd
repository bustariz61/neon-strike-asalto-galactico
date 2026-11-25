extends Node
## Audio 100% procedural: efectos sintetizados y música chiptune generada en un hilo.

const RATE := 22050
const MUSIC_RATE := 16000

var sounds := {}
var _pool: Array = []
var _next := 0
var _music: AudioStreamPlayer
var _tracks := {}
var _wanted := ""
var _playing := ""
var _thread: Thread
var _last_play := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for i in 28:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.volume_db = -4.0
	add_child(_music)
	_build_sounds()
	_thread = Thread.new()
	_thread.start(_build_music)


func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()


func _process(_delta: float) -> void:
	if _wanted != _playing and (_wanted == "" or _tracks.has(_wanted)):
		_switch_music()


func _setup_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus_name)
			AudioServer.set_bus_send(i, "Master")


# ---------------------------------------------------------------- API
func play(sound_name: String, vol_db: float = 0.0, pitch_var: float = 0.08) -> void:
	if not sounds.has(sound_name):
		return
	var now := Time.get_ticks_msec()
	if int(_last_play.get(sound_name, -1000)) + 35 > now:
		return
	_last_play[sound_name] = now
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = sounds[sound_name]
	p.volume_db = vol_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()


func play_music(track: String) -> void:
	_wanted = track


func stop_music() -> void:
	_wanted = ""


func _switch_music() -> void:
	_playing = _wanted
	if _wanted == "":
		_music.stop()
		return
	_music.stream = _tracks[_wanted]
	_music.volume_db = -30.0
	_music.play()
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", -4.0, 1.2)


# ---------------------------------------------------------------- Efectos
func _build_sounds() -> void:
	# _synth(dur, f0, f1, onda(0 cuadrada,1 sierra,2 triangulo,3 seno), ruido, volumen, caida, vibrato)
	sounds["shoot"] = _synth(0.09, 1100.0, 320.0, 0, 0.0, 0.18, 2.0)
	sounds["smg"] = _synth(0.06, 1300.0, 500.0, 0, 0.1, 0.15, 2.0)
	sounds["shotgun"] = _synth(0.28, 400.0, 70.0, 1, 0.75, 0.5, 1.6)
	sounds["plasma"] = _synth(0.3, 220.0, 900.0, 1, 0.0, 0.25, 1.2, 18.0)
	sounds["rocket"] = _synth(0.45, 180.0, 60.0, 1, 0.6, 0.4, 1.2)
	sounds["rail"] = _synth(0.5, 2200.0, 90.0, 1, 0.2, 0.35, 1.4)
	sounds["hit"] = _synth(0.05, 500.0, 200.0, 0, 0.3, 0.15, 2.0)
	sounds["enemy_shoot"] = _synth(0.12, 700.0, 250.0, 2, 0.0, 0.25, 1.5)
	sounds["explosion"] = _synth(0.55, 140.0, 35.0, 1, 0.9, 0.6, 1.6)
	sounds["big_explosion"] = _synth(1.4, 100.0, 22.0, 1, 0.95, 0.85, 1.3)
	sounds["player_hit"] = _synth(0.3, 320.0, 70.0, 1, 0.3, 0.45, 1.3)
	sounds["pickup"] = _synth(0.14, 700.0, 1600.0, 0, 0.0, 0.2, 1.0)
	sounds["coin"] = _synth(0.08, 1500.0, 2200.0, 3, 0.0, 0.25, 1.5)
	sounds["powerup"] = _arp([523.0, 659.0, 784.0, 1046.0], 0.07, 0, 0.18)
	sounds["dash"] = _synth(0.22, 500.0, 1600.0, 3, 0.6, 0.3, 1.2)
	sounds["bomb"] = _synth(1.3, 220.0, 20.0, 1, 0.92, 0.95, 1.1)
	sounds["click"] = _synth(0.05, 1200.0, 900.0, 0, 0.0, 0.15, 2.0)
	sounds["hover"] = _synth(0.03, 1800.0, 1900.0, 3, 0.0, 0.12, 2.0)
	sounds["wave"] = _synth(0.7, 300.0, 600.0, 0, 0.0, 0.22, 0.6, 6.0)
	sounds["wave_clear"] = _arp([392.0, 523.0, 659.0, 784.0], 0.09, 0, 0.18)
	sounds["boss_warn"] = _synth(1.5, 160.0, 90.0, 1, 0.1, 0.4, 0.5, 4.0)
	sounds["charge"] = _synth(0.5, 200.0, 1300.0, 3, 0.0, 0.2, 0.4)
	sounds["victory"] = _arp([523.0, 659.0, 784.0, 1046.0, 784.0, 1046.0, 1318.0], 0.12, 0, 0.2)
	sounds["gameover"] = _arp([392.0, 330.0, 262.0, 196.0], 0.22, 1, 0.22)
	sounds["achievement"] = _arp([784.0, 988.0, 1175.0, 1568.0], 0.08, 3, 0.25)
	sounds["buy"] = _arp([660.0, 990.0], 0.07, 0, 0.2)


func _synth(dur: float, f0: float, f1: float, wave: int, noise: float, vol: float, decay: float = 1.0, vib: float = 0.0) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase := 0.0
	var lp := 0.0
	for i in n:
		var k := float(i) / float(n)
		var f := f0 * pow(f1 / f0, k)
		if vib > 0.0:
			f *= 1.0 + 0.08 * sin(float(i) / RATE * TAU * vib)
		phase = fmod(phase + f / RATE, 1.0)
		var s := 0.0
		if wave == 0:
			s = 1.0 if phase < 0.5 else -1.0
		elif wave == 1:
			s = phase * 2.0 - 1.0
		elif wave == 2:
			s = 4.0 * absf(phase - 0.5) - 1.0
		else:
			s = sin(phase * TAU)
		if noise > 0.0:
			var coef := clampf(f / 2000.0, 0.04, 1.0)
			lp = lerpf(lp, randf() * 2.0 - 1.0, coef)
			s = s * (1.0 - noise) + lp * noise * (0.6 / sqrt(coef))
		var env := pow(1.0 - k, decay)
		if i < 80:
			env *= float(i) / 80.0
		buf[i] = s * env * vol
	return _to_wav(buf, RATE)


func _arp(freqs: Array, nd: float, wave: int, vol: float) -> AudioStreamWAV:
	var per := int(nd * RATE)
	var tail := int(RATE * 0.3)
	var buf := PackedFloat32Array()
	buf.resize(per * freqs.size() + tail)
	for j in freqs.size():
		var f: float = freqs[j]
		var phase := 0.0
		var ln := per + tail if j == freqs.size() - 1 else per
		for i in ln:
			phase = fmod(phase + f / RATE, 1.0)
			var s := 0.0
			if wave == 0:
				s = 1.0 if phase < 0.5 else -1.0
			elif wave == 1:
				s = phase * 2.0 - 1.0
			else:
				s = sin(phase * TAU)
			var env := pow(1.0 - float(i) / float(ln), 1.5)
			if i < 60:
				env *= float(i) / 60.0
			buf[j * per + i] += s * env * vol
	return _to_wav(buf, RATE)


func _to_wav(buf: PackedFloat32Array, rate: int, loop: bool = false) -> AudioStreamWAV:
	var n := buf.size()
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = n
	return w


# ---------------------------------------------------------------- Música (hilo)
func _build_music() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var menu := _render_track(rng, 92.0, [[50, 53, 57], [46, 50, 53], [41, 45, 48], [48, 52, 55]], 32, 8, false, true, 0.035, 0.03, 0.09)
	call_deferred("_on_track_ready", "menu", menu)
	var battle := _render_track(rng, 138.0, [[45, 48, 52], [41, 45, 48], [48, 52, 55], [43, 47, 50]], 32, 4, true, true, 0.05, 0.022, 0.13)
	call_deferred("_on_track_ready", "battle", battle)
	var boss := _render_track(rng, 152.0, [[40, 43, 47], [36, 40, 43], [38, 42, 45], [35, 39, 42]], 32, 2, true, true, 0.06, 0.028, 0.15)
	call_deferred("_on_track_ready", "boss", boss)


func _on_track_ready(track: String, stream: AudioStreamWAV) -> void:
	_tracks[track] = stream


func _hz(midi: int) -> float:
	return 440.0 * pow(2.0, (midi - 69) / 12.0)


func _render_track(rng: RandomNumberGenerator, bpm: float, chords: Array, steps_per_chord: int, kick_every: int, snare: bool, hat: bool, arp_vol: float, pad_vol: float, bass_vol: float) -> AudioStreamWAV:
	var step := 60.0 / bpm / 4.0
	var total := chords.size() * steps_per_chord
	var n := int(total * step * MUSIC_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n + MUSIC_RATE * 2)
	var arp_pat := [0, 1, 2, 1, 2, 0, 1, 2]
	for s in total:
		var ch: Array = chords[s / steps_per_chord]
		var t0 := int(s * step * MUSIC_RATE)
		var b := s % 16
		if kick_every > 0 and b % kick_every == 0:
			_kick(buf, t0)
		if snare and (b == 4 or b == 12):
			_noise_hit(rng, buf, t0, 0.15, 0.2, false)
		if hat and b % 2 == 1:
			_noise_hit(rng, buf, t0, 0.04, 0.06, true)
		if bass_vol > 0.0 and b % 2 == 0:
			var root: int = ch[0]
			var oct := 0 if b % 8 != 6 else 12
			_note(buf, t0, step * 1.8, _hz(root - 12 + oct), 1, bass_vol, 1.2)
		if arp_vol > 0.0:
			var octave := 12 if (s / 8) % 2 == 0 else 24
			var nt: int = ch[arp_pat[s % arp_pat.size()]]
			_note(buf, t0, step * 0.95, _hz(nt + octave), 0, arp_vol, 2.0)
		if pad_vol > 0.0 and s % steps_per_chord == 0:
			for nt in ch:
				_note(buf, t0, step * steps_per_chord, _hz(int(nt) + 12), 2, pad_vol, 0.4)
	for i in MUSIC_RATE * 2:
		buf[i] += buf[n + i]
	buf.resize(n)
	return _to_wav(buf, MUSIC_RATE, true)


func _note(buf: PackedFloat32Array, start: int, dur: float, f: float, wave: int, vol: float, decay: float) -> void:
	var ln := int(dur * MUSIC_RATE)
	var phase := 0.0
	var inc := f / MUSIC_RATE
	var att := mini(240, ln)
	var size := buf.size()
	for i in ln:
		var idx := start + i
		if idx >= size:
			break
		phase += inc
		if phase >= 1.0:
			phase -= 1.0
		var s: float
		if wave == 0:
			s = 1.0 if phase < 0.5 else -1.0
		elif wave == 1:
			s = phase * 2.0 - 1.0
		else:
			s = 4.0 * absf(phase - 0.5) - 1.0
		var env := pow(1.0 - float(i) / float(ln), decay)
		if i < att:
			env *= float(i) / float(att)
		buf[idx] += s * env * vol


func _kick(buf: PackedFloat32Array, start: int) -> void:
	var ln := int(0.2 * MUSIC_RATE)
	var phase := 0.0
	for i in ln:
		var idx := start + i
		if idx >= buf.size():
			break
		var k := float(i) / float(ln)
		var f := 150.0 * pow(40.0 / 150.0, k)
		phase += f / MUSIC_RATE
		buf[idx] += sin(phase * TAU) * pow(1.0 - k, 2.0) * 0.45


func _noise_hit(rng: RandomNumberGenerator, buf: PackedFloat32Array, start: int, dur: float, vol: float, bright: bool) -> void:
	var ln := int(dur * MUSIC_RATE)
	var prev := 0.0
	for i in ln:
		var idx := start + i
		if idx >= buf.size():
			break
		var nz := rng.randf() * 2.0 - 1.0
		var s := nz - prev if bright else nz
		prev = nz
		buf[idx] += s * pow(1.0 - float(i) / float(ln), 2.0) * vol
