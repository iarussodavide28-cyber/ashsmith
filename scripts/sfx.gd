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
	# solo per le prove: --shot=file.png --frames=N --scene=res://...
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shot="):
			_shot = a.substr(5)
		elif a.begins_with("frames="):
			_shot_frames = int(a.substr(7))
		elif a.begins_with("scene="):
			_goto = a.substr(6)
	if _goto != "":
		get_tree().change_scene_to_file.call_deferred(_goto)

var _shot := ""
var _shot_frames := 120
var _goto := ""
var _frame := 0

func _process(_d: float) -> void:
	if _shot == "":
		return
	_frame += 1
	if _frame == _shot_frames:
		get_viewport().get_texture().get_image().save_png(_shot)
		get_tree().quit()

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

## Suono di metallo: parziali non armoniche (come un'incudine o una lama)
func _ring(buf: PackedFloat32Array, start: int, dur: float, base: float, vol: float, curve: float = 3.0) -> void:
	var ratios := [1.0, 2.76, 5.40, 8.93]
	var amps := [1.0, 0.55, 0.3, 0.15]
	for i in ratios.size():
		var f: float = base * ratios[i]
		if f > RATE * 0.45:
			continue
		_add(buf, start, dur * (1.0 - i * 0.18), f, f * 0.998, "sine", vol * amps[i], 0.0008, curve + i)

## Filtro passa-basso: rende il suono più scuro
func _lowpass(buf: PackedFloat32Array, k: float) -> void:
	var y := 0.0
	for i in buf.size():
		y += (buf[i] - y) * k
		buf[i] = y

func _build_sfx() -> void:
	var b: PackedFloat32Array
	# armi
	b = _buf(0.14); _add(b, 0, 0.11, 4200, 900, "noise", 0.55, 0.002, 3.0); _add(b, 0, 0.05, 520, 260, "tri", 0.3)
	_reg("bow", b, -10.0)
	b = _buf(0.2); _add(b, 0, 0.16, 900, 3800, "noise", 0.7, 0.03, 2.0); _ring(b, int(0.02 * RATE), 0.16, 1900, 0.08, 4.0)
	_reg("sword", b, -9.0)
	# fendente che va a segno: colpo pesante e lama che vibra
	b = _buf(0.32); _add(b, 0, 0.14, 140, 40, "sine", 1.0, 0.001, 2.0); _add(b, 0, 0.08, 3000, 700, "noise", 0.6, 0.001, 2.5); _ring(b, 0, 0.28, 1320, 0.12, 4.0)
	_reg("slash_hit", b, -5.0)
	# esplosione della sfera di magma
	b = _buf(0.5); _add(b, 0, 0.45, 900, 90, "noise", 0.8, 0.002, 1.8); _add(b, 0, 0.35, 110, 35, "sine", 0.8, 0.002, 2.0)
	_lowpass(b, 0.45)
	_reg("boom", b, -8.0)
	b = _buf(0.3); _add(b, 0, 0.26, 260, 70, "sine", 0.7, 0.004, 2.0); _add(b, 0, 0.18, 1200, 200, "noise", 0.3, 0.01, 2.0)
	_reg("staff", b, -8.0)
	# colpi
	b = _buf(0.1); _add(b, 0, 0.08, 160, 55, "sine", 0.9, 0.001, 2.5); _add(b, 0, 0.05, 2200, 600, "noise", 0.4, 0.001, 3.0)
	_reg("hit", b, -8.0)
	b = _buf(0.3); _add(b, 0, 0.1, 180, 50, "sine", 0.9, 0.001, 2.0); _ring(b, 0, 0.28, 1150, 0.22, 3.0); _add(b, 0, 0.03, 6000, 2500, "noise", 0.5, 0.0005, 2.0)
	_reg("crit", b, -7.0)
	b = _buf(0.36); _add(b, 0, 0.3, 1800, 160, "noise", 0.75, 0.002, 2.0); _add(b, 0, 0.26, 150, 38, "sine", 0.85, 0.002, 2.0)
	_reg("kill", b, -6.0)
	# monete e scintille: piccoli rintocchi metallici
	b = _buf(0.3); _ring(b, 0, 0.14, 2100, 0.3, 4.0); _ring(b, int(0.055 * RATE), 0.22, 2650, 0.3, 4.0)
	_reg("coin", b, -15.0)
	b = _buf(0.1); _add(b, 0, 0.08, 1500, 2400, "tri", 0.3, 0.002, 2.0); _add(b, 0, 0.05, 7000, 4000, "noise", 0.15, 0.001, 3.0)
	_reg("spark", b, -16.0)
	# livello: accordo minore di ottoni + rintocco
	b = _buf(1.1)
	var notes := [220.0, 261.63, 329.63, 440.0]
	for i in notes.size():
		_add(b, int(i * 0.07 * RATE), 0.8, notes[i], notes[i], "saw", 0.09, 0.03, 1.6)
		_add(b, int(i * 0.07 * RATE), 0.8, notes[i] * 0.5, notes[i] * 0.5, "tri", 0.14, 0.03, 1.6)
	_ring(b, int(0.28 * RATE), 0.8, 880, 0.18, 3.0)
	_lowpass(b, 0.35)
	_reg("level", b, -4.0)
	b = _buf(0.3); _add(b, 0, 0.26, 130, 50, "saw", 0.45, 0.002, 1.5); _add(b, 0, 0.12, 1600, 300, "noise", 0.4, 0.001, 2.0)
	_lowpass(b, 0.5)
	_reg("hurt", b, -5.0)
	# incudine
	b = _buf(1.1)
	_ring(b, 0, 1.0, 640, 0.32, 3.5)
	_ring(b, 0, 0.6, 1370, 0.12, 4.0)
	_add(b, 0, 0.03, 6000, 2000, "noise", 0.55, 0.0005, 2.0)
	_add(b, 0, 0.12, 120, 50, "sine", 0.5, 0.001, 2.0)
	_reg("clang", b, -7.0)
	b = _buf(0.9); _add(b, 0, 0.8, 300, 60, "noise", 0.6, 0.06, 1.5); _add(b, 0, 0.75, 60, 38, "sine", 0.7, 0.05, 1.5); _ring(b, int(0.62 * RATE), 0.25, 300, 0.15, 3.0)
	_reg("door", b, -5.0)
	b = _buf(0.18); _add(b, 0, 0.1, 600, 3000, "noise", 0.4, 0.01, 2.0); _ring(b, int(0.08 * RATE), 0.1, 1500, 0.15, 4.0)
	_reg("switch", b, -9.0)
	# clic dell'interfaccia: tacca metallica breve
	b = _buf(0.08); _ring(b, 0, 0.06, 1650, 0.25, 5.0); _add(b, 0, 0.012, 5000, 3000, "noise", 0.3, 0.0005, 2.0)
	_reg("click", b, -11.0)
	b = _buf(1.6); _add(b, 0, 1.5, 55, 49, "saw", 0.4, 0.1, 1.2); _add(b, 0, 1.5, 82.4, 73.4, "saw", 0.28, 0.1, 1.2); _add(b, 0, 1.2, 240, 60, "noise", 0.35, 0.15, 1.5); _ring(b, 0, 1.4, 220, 0.2, 2.5)
	_lowpass(b, 0.25)
	_reg("boss", b, -3.0)
	b = _buf(1.2)
	var up := [293.66, 349.23, 440.0, 587.33]
	for i in up.size():
		_ring(b, int(i * 0.09 * RATE), 0.7, up[i], 0.16, 3.0)
		_add(b, int(i * 0.09 * RATE), 0.6, up[i] * 0.5, up[i] * 0.5, "tri", 0.14, 0.004, 2.0)
	_reg("clear", b, -6.0)
	b = _buf(0.45); _add(b, 0, 0.4, 500, 150, "noise", 0.55, 0.004, 2.0); _add(b, 0, 0.34, 110, 40, "sine", 0.8, 0.002, 2.0)
	_reg("slam", b, -4.0)
	b = _buf(0.14); _add(b, 0, 0.12, 500, 200, "saw", 0.2, 0.002, 2.0)
	_lowpass(b, 0.4)
	_reg("shoot_enemy", b, -14.0)

## Musica: 4 battute in Re minore, lenta e cupa: bordone, tamburi e incudine.
func _build_music() -> AudioStreamWAV:
	var bpm := 90.0
	var beat := 60.0 / bpm
	var bars := 4
	var b := _buf(beat * 4 * bars)
	var roots := [73.42, 58.27, 65.41, 55.0]          # Re, Sib, Do, La
	var mel := [[293.66, 349.23, 440.0, 349.23], [233.08, 293.66, 349.23, 293.66], [261.63, 329.63, 392.0, 329.63], [220.0, 277.18, 329.63, 440.0]]
	for bar in bars:
		var t0 := bar * 4 * beat
		var i0 := int(t0 * RATE)
		# bordone (due saw basse leggermente stonate)
		_add(b, i0, beat * 4.1, roots[bar], roots[bar], "saw", 0.14, 0.25, 0.6)
		_add(b, i0, beat * 4.1, roots[bar] * 1.003, roots[bar] * 1.003, "saw", 0.12, 0.25, 0.6)
		_add(b, i0, beat * 4.1, roots[bar] * 0.5, roots[bar] * 0.5, "sine", 0.3, 0.2, 0.8)
		for q in 4:
			var i := int((t0 + q * beat) * RATE)
			# tamburo grave
			_add(b, i, 0.35, 95, 42, "sine", 0.6 if q % 2 == 0 else 0.4, 0.002, 2.2)
			if q == 1 or q == 3:
				_add(b, i, 0.18, 1800, 500, "noise", 0.18, 0.002, 2.5)
			# arpeggio lento pizzicato
			var f: float = mel[bar][q]
			_add(b, i, beat * 0.9, f, f, "tri", 0.07, 0.004, 2.5)
		# tom in levare
		_add(b, int((t0 + 3.5 * beat) * RATE), 0.22, 140, 70, "sine", 0.35, 0.002, 2.0)
		# incudine sul quarto tempo
		_ring(b, int((t0 + 3.0 * beat) * RATE), 0.9, 523.0 if bar % 2 == 0 else 466.0, 0.07, 3.5)
	_lowpass(b, 0.3)
	# normalizza
	var peak := 0.01
	for x in b:
		peak = maxf(peak, absf(x))
	for i in b.size():
		b[i] = b[i] / peak * 0.8
	return _wav(b, true)
