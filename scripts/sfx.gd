extends Node
## Suoni e musica creati dal gioco stesso (nessun file audio da scaricare).
## Sfx.play("hit") per un effetto, Sfx.music_on() per la musica.

const RATE := 22050

var streams := {}
var vols := {}
var players: Array = []
var last := {}
var music: AudioStreamPlayer
var music_stream: AudioStreamWAV
var _next := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	music = AudioStreamPlayer.new()
	music.volume_db = -13.0
	add_child(music)
	_build_sfx()

func enabled() -> bool:
	return Save.sound

func play(name: String, pitch_var: float = 0.08, vol_add: float = 0.0) -> void:
	if not enabled() or not streams.has(name):
		return
	var now := Time.get_ticks_msec()
	if now - int(last.get(name, -1000)) < 45:
		return
	last[name] = now
	var p: AudioStreamPlayer = players[_next]
	_next = (_next + 1) % players.size()
	p.stream = streams[name]
	p.volume_db = vols.get(name, 0.0) + vol_add
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()

func music_on() -> void:
	if not enabled():
		music.stop()
		return
	if music_stream == null:
		music_stream = _build_music()
	if not music.playing:
		music.stream = music_stream
		music.play()

func music_off() -> void:
	music.stop()

func set_enabled(v: bool) -> void:
	Save.sound = v
	Save.save_game()
	if v:
		music_on()
	else:
		music.stop()

# ---------------------------------------------------------------------
#  Sintesi
# ---------------------------------------------------------------------
func _wav(data: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	for i in data.size():
		bytes.encode_s16(i * 2, int(clampf(data[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = data.size()
	return w

## Aggiunge a "buf" (dalla posizione start) un suono: frequenza da f0 a f1,
## forma d'onda, volume, attacco e decadimento.
func _add(buf: PackedFloat32Array, start: int, dur: float, f0: float, f1: float, wave: String, vol: float, attack: float = 0.005, curve: float = 2.0) -> void:
	var n := int(dur * RATE)
	var ph := 0.0
	var lp := 0.0
	for i in n:
		var idx := start + i
		if idx >= buf.size():
			break
		var t := float(i) / n
		var f := f0 * pow(f1 / f0, t)
		ph += f / RATE
		var x := 0.0
		match wave:
			"sine": x = sin(ph * TAU)
			"square": x = 1.0 if fmod(ph, 1.0) < 0.5 else -1.0
			"saw": x = fmod(ph, 1.0) * 2.0 - 1.0
			"tri": x = absf(fmod(ph, 1.0) * 4.0 - 2.0) - 1.0
			"noise":
				lp += (randf_range(-1.0, 1.0) - lp) * clampf(f / 6000.0, 0.02, 1.0)
				x = lp * 2.0
		var env := minf(1.0, (float(i) / RATE) / maxf(attack, 0.0001)) * pow(1.0 - t, curve)
		buf[idx] += x * env * vol

func _buf(dur: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(dur * RATE))
	return b

func _reg(name: String, b: PackedFloat32Array, vol_db: float = 0.0) -> void:
	streams[name] = _wav(b)
	vols[name] = vol_db

func _build_sfx() -> void:
	var b: PackedFloat32Array
	b = _buf(0.12); _add(b, 0, 0.1, 5000, 1500, "noise", 0.5, 0.002, 3.0); _add(b, 0, 0.06, 1400, 700, "tri", 0.25)
	_reg("bow", b, -10.0)
	b = _buf(0.16); _add(b, 0, 0.15, 1200, 4000, "noise", 0.7, 0.04, 2.0)
	_reg("sword", b, -9.0)
	b = _buf(0.22); _add(b, 0, 0.2, 420, 140, "sine", 0.6, 0.004, 2.0); _add(b, 0, 0.12, 900, 300, "tri", 0.2)
	_reg("staff", b, -9.0)
	b = _buf(0.09); _add(b, 0, 0.08, 220, 70, "sine", 0.8, 0.001, 2.5); _add(b, 0, 0.04, 3000, 800, "noise", 0.35, 0.001, 3.0)
	_reg("hit", b, -8.0)
	b = _buf(0.14); _add(b, 0, 0.1, 1500, 900, "square", 0.22, 0.001, 2.0); _add(b, 0, 0.09, 260, 60, "sine", 0.8, 0.001, 2.0)
	_reg("crit", b, -7.0)
	b = _buf(0.3); _add(b, 0, 0.26, 2500, 300, "noise", 0.7, 0.002, 2.0); _add(b, 0, 0.22, 240, 45, "sine", 0.7, 0.002, 2.0)
	_reg("kill", b, -7.0)
	b = _buf(0.14); _add(b, 0, 0.06, 1320, 1320, "sine", 0.45, 0.002, 1.5); _add(b, int(0.05 * RATE), 0.09, 1980, 1980, "sine", 0.45, 0.002, 2.0)
	_reg("coin", b, -14.0)
	b = _buf(0.07); _add(b, 0, 0.06, 1700, 2600, "sine", 0.4, 0.002, 2.0)
	_reg("spark", b, -16.0)
	b = _buf(0.7)
	var notes := [523.25, 659.25, 783.99, 1046.5]
	for i in notes.size():
		_add(b, int(i * 0.08 * RATE), 0.4, notes[i], notes[i], "square", 0.16, 0.003, 2.0)
		_add(b, int(i * 0.08 * RATE), 0.45, notes[i] * 2.0, notes[i] * 2.0, "sine", 0.12, 0.003, 2.5)
	_reg("level", b, -6.0)
	b = _buf(0.28); _add(b, 0, 0.25, 180, 70, "saw", 0.45, 0.002, 1.5); _add(b, 0, 0.12, 2000, 400, "noise", 0.4, 0.001, 2.0)
	_reg("hurt", b, -6.0)
	b = _buf(0.9)
	for f in [523.0, 1307.0, 2093.0, 2950.0, 3700.0]:
		_add(b, 0, 0.85, f, f * 0.995, "sine", 0.18, 0.001, 3.5)
	_add(b, 0, 0.03, 6000, 2000, "noise", 0.5, 0.0005, 2.0)
	_reg("clang", b, -8.0)
	b = _buf(0.7); _add(b, 0, 0.65, 400, 90, "noise", 0.6, 0.05, 1.5); _add(b, 0, 0.6, 80, 50, "sine", 0.6, 0.05, 1.5)
	_reg("door", b, -6.0)
	b = _buf(0.16); _add(b, 0, 0.12, 800, 5000, "noise", 0.5, 0.01, 2.0); _add(b, int(0.1 * RATE), 0.04, 1800, 1800, "square", 0.15, 0.001, 2.0)
	_reg("switch", b, -9.0)
	b = _buf(0.05); _add(b, 0, 0.04, 1100, 900, "sine", 0.5, 0.001, 2.0)
	_reg("click", b, -10.0)
	b = _buf(1.3); _add(b, 0, 1.2, 98, 92, "saw", 0.35, 0.08, 1.2); _add(b, 0, 1.2, 147, 138, "saw", 0.25, 0.08, 1.2); _add(b, 0, 1.0, 300, 80, "noise", 0.3, 0.1, 1.5)
	_reg("boss", b, -5.0)
	b = _buf(0.9)
	var up := [392.0, 523.25, 659.25, 783.99]
	for i in up.size():
		_add(b, int(i * 0.06 * RATE), 0.6, up[i], up[i], "tri", 0.25, 0.003, 2.0)
	_reg("clear", b, -6.0)
	b = _buf(0.4); _add(b, 0, 0.35, 700, 300, "noise", 0.5, 0.004, 2.0); _add(b, 0, 0.3, 150, 60, "sine", 0.6, 0.002, 2.0)
	_reg("slam", b, -5.0)
	b = _buf(0.12); _add(b, 0, 0.1, 700, 300, "square", 0.18, 0.002, 2.0)
	_reg("shoot_enemy", b, -16.0)

## Musica: 4 battute in La minore, con un colpo d'incudine a fine battuta.
func _build_music() -> AudioStreamWAV:
	var bpm := 112.0
	var beat := 60.0 / bpm
	var bars := 4
	var b := _buf(beat * 4 * bars)
	var roots := [110.0, 87.31, 98.0, 82.41]          # La, Fa, Sol, Mi
	var arp := [[220.0, 261.63, 329.63], [174.61, 220.0, 261.63], [196.0, 246.94, 293.66], [164.81, 207.65, 246.94]]
	for bar in bars:
		var t0 := bar * 4 * beat
		for q in 8:
			var t := t0 + q * beat * 0.5
			var i := int(t * RATE)
			# basso a ottavi
			_add(b, i, beat * 0.45, roots[bar], roots[bar], "tri", 0.32, 0.004, 1.2)
			# charleston sui controtempi
			if q % 2 == 1:
				_add(b, i, 0.05, 8000, 6000, "noise", 0.12, 0.001, 3.0)
		for q in 4:
			var i := int((t0 + q * beat) * RATE)
			# cassa
			_add(b, i, 0.18, 120, 45, "sine", 0.55, 0.001, 2.5)
			if q == 1 or q == 3:
				_add(b, i, 0.12, 2500, 900, "noise", 0.2, 0.001, 2.5)
		# arpeggio leggero a sedicesimi
		for s in 16:
			var i := int((t0 + s * beat * 0.25) * RATE)
			var f: float = arp[bar][s % 3] * (2.0 if s % 8 >= 4 else 1.0)
			_add(b, i, beat * 0.22, f, f, "square", 0.045, 0.002, 2.0)
		# incudine
		var ia := int((t0 + 3.5 * beat) * RATE)
		for f in [1046.0, 2614.0, 4186.0]:
			_add(b, ia, 0.35, f, f, "sine", 0.06, 0.001, 3.0)
	# normalizza
	var peak := 0.01
	for x in b:
		peak = maxf(peak, absf(x))
	for i in b.size():
		b[i] = b[i] / peak * 0.8
	return _wav(b, true)
