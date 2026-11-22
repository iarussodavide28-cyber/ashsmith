extends Node2D
## La partita: un capitolo di 12 stanze con forgia, nemici, mini-boss e boss.
## Tutto è disegnato in pixel art col codice (segnaposto finché non arriva la grafica vera).

enum St { PLAY, CLEAR, FORGE, PAUSE, DEAD, WIN, LEVEL }

# ---------- Aspetto ----------
const FLOOR_A := Color("2b2024")
const FLOOR_B := Color("30242a")
const WALL := Color("4a3838")
const WALL_TOP := Color("6b5050")
const BG := Color("120a0c")
const HERO := Color("ff8a2b")
const HERO_DARK := Color("b8541a")
const HERO_LIGHT := Color("ffd25a")
const BULLET := Color("ff3d6a")
const WARN := Color(1, 0.2, 0.25)

const TILE := 15
const WALL_SIZE := 8
const TOP_WALL := 24
const ROCK := 26.0
const HUD_H := 36.0
const BAR_H := 52.0
const HERO_SIZE := 19
const HERO_SPEED := 100.0
const ACCEL := 900.0
const FRICTION := 1100.0
const JOY_RADIUS := 28.0
const BASE_HP := 120
const ZOOM := 1.3            # camera più vicina: personaggi più grandi
const ROOM_H := 370.0        # stanze più alte dello schermo: la camera segue l'eroe

# ---------- Stato ----------
var state := St.PLAY
var room_n := 1
var time := 0.0
var shake := 0.0

var sparks := 0
var run_gold := 0
var run_gems := 0
var purchases := 0

var hero_pos := Vector2.ZERO
var hero_vel := Vector2.ZERO
var facing := Vector2.UP
var hero_hp := 120
var max_hp := 120
var bonus := {}
var revived := false
var run_mats := {"bone": 0, "stone": 0, "ember": 0}
var run_items: Array = []
var hero_inv := 0.0
var hero_flash := 0.0
var atk_t := 0.0
var step_t := 0.0

var weapons: Array = []     # [{key, slots:["",""], paid:[0,0]}, ...]
var cur_w := 0
var switch_t := 0.0

var touch_index := -1
var joy_origin := Vector2.ZERO
var joy_current := Vector2.ZERO

var enemies: Array = []
var shots: Array = []
var bullets: Array = []
var drops: Array = []
var clouds: Array = []
var patches: Array = []
var parts: Array = []
var floats: Array = []
var bolts: Array = []
var waves: Array = []
var wave_idx := 0
var wave_delay := 0.0

var anvil := {}
var obs: Array = []          # colonne di pietra (Rect2) che bloccano movimento e colpi
var floor_seed := 1
var anvil_lock := false
var win_delay := -1.0
var door_open := false
var end_t := 0.0
var banner := ""
var banner_t := 0.0
var hint_clear_shown := false

# forgia
var offers: Array = []
var sel_offer := -1
var forge_msg := ""
var forge_big := false
var forge_rects := {}
var end_info := {}
var ui_rects := {}

# livelli e abilità della partita (come negli action roguelite)
var xp := 0
var lvl := 1
var skills := {}
var level_choices: Array = []
var pending_lv := 0
var level_ret := St.PLAY
var lvl_t := 0.0
# sensazione dei colpi
var hitstop := 0.0
var volley_q: Array = []
var rings: Array = []
var aim_target = null
var fade_t := 0.0
var hurt_t := 0.0
var spirit_t := 0.0
var orb_ang := 0.0
var last_dir := Vector2.UP
var cam_y := 0.0
var corpses: Array = []       # nemici che si sbriciolano in cenere
var slowmo := 0.0
var intro_t := 0.0            # cartolina del capitolo a inizio partita
var altar := {}               # Altare delle braci (alcune stanze)
var level_mode := "level"
var recoil := 0.0
var dark_tex: GradientTexture2D
var boss_card_t := 0.0
var strike := {}              # colpo di martello alla forgia (tempismo)
var switch_bonus := false   # il primo attacco dopo il cambio arma è un critico potenziato

var autotest := false        # prova automatica (solo per i test, non nel gioco)
var auto_target = null
var auto_forged := false

func _ready() -> void:
	randomize()
	autotest = "--autotest" in OS.get_cmdline_user_args()
	if autotest and "--staff" in OS.get_cmdline_user_args():
		weapons = [{"key": "staff", "slots": ["", ""], "paid": [0, 0]}, {"key": "sword", "slots": ["", ""], "paid": [0, 0]}]
	bonus = Save.bonuses()
	max_hp = BASE_HP + int(bonus.hp)
	hero_hp = max_hp
	for k in Save.run_weapons():
		weapons.append({"key": k, "slots": ["", ""], "paid": [0, 0]})
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0.02, 0.0, 0.05, 0.68))
	g.add_point(0.42, Color(0, 0, 0, 0))
	dark_tex = GradientTexture2D.new()
	dark_tex.gradient = g
	dark_tex.width = 128
	dark_tex.height = 128
	dark_tex.fill = GradientTexture2D.FILL_RADIAL
	dark_tex.fill_from = Vector2(0.5, 0.5)
	dark_tex.fill_to = Vector2(1.0, 0.5)
	intro_t = 2.8
	_start_room()
	wave_delay = 2.4
	_debug_params()
	Sfx.music_on()

## Solo per le prove: ?room=7&sparks=200 nell'indirizzo salta a una stanza
func _debug_params() -> void:
	var q = ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("q="):
			q = a.substr(2)
	if q == "" and OS.has_feature("web"):
		q = JavaScriptBridge.eval("window.location.search", true)
	if typeof(q) != TYPE_STRING or q == "":
		return
	for pair in str(q).trim_prefix("?").split("&"):
		var kv := pair.split("=")
		if kv.size() != 2:
			continue
		if kv[0] == "room":
			room_n = clampi(int(kv[1]), 1, Data.ROOMS)
			_start_room()
		elif kv[0] == "sparks":
			sparks = int(kv[1])
		elif kv[0] == "clear":
			enemies.clear()
			waves = []
			_room_cleared()
		elif kv[0] == "levelup":
			pending_lv = int(kv[1])
		elif kv[0] == "skills":
			for k in kv[1].split(","):
				if Skills.LIST.has(k):
					skills[k] = _sk(k) + 1
		elif kv[0] == "forge" and not anvil.is_empty():
			_open_forge()
		elif kv[0] == "pause":
			state = St.PAUSE
		elif kv[0] == "end" and not OS.has_feature("web"):
			_end_run(kv[1] == "1")
			end_t = 5.0

# =====================================================================
#  Spazio di gioco
# =====================================================================
func _size() -> Vector2:
	return get_viewport_rect().size

func _view_w() -> float:
	return _size().x / ZOOM

func _view_h() -> float:
	return (_size().y - HUD_H - BAR_H) / ZOOM

## La stanza è in coordinate del mondo (non dello schermo)
func _room_rect() -> Rect2:
	return Rect2(WALL_SIZE, TOP_WALL, _view_w() - WALL_SIZE * 2, ROOM_H)

func _cam_target() -> float:
	var total := TOP_WALL + ROOM_H + WALL_SIZE
	return clampf(hero_pos.y - _view_h() * 0.6, 0.0, maxf(0.0, total - _view_h()))

func _w2s(p: Vector2) -> Vector2:
	return Vector2(p.x * ZOOM, (p.y - cam_y) * ZOOM + HUD_H)

var _base_off := Vector2.ZERO
## Trasformazioni di disegno dentro il mondo
func _xf(pos: Vector2, rot: float = 0.0, sc: Vector2 = Vector2.ONE) -> void:
	draw_set_transform(_base_off + pos * ZOOM, rot, sc * ZOOM)

func _xr() -> void:
	draw_set_transform(_base_off, 0, Vector2(ZOOM, ZOOM))

func _switch_rect() -> Rect2:
	var s := _size()
	return Rect2(s.x - 104, s.y - BAR_H + 6, 98, BAR_H - 12)

func _pause_rect() -> Rect2:
	return Rect2(_size().x - 22, 4, 18, 18)

func _door_rect() -> Rect2:
	var r := _room_rect()
	return Rect2(r.get_center().x - 18, r.position.y - TOP_WALL, 36, TOP_WALL)

func _w() -> Dictionary:
	return weapons[cur_w]

func _wdata(w: Dictionary = {}) -> Dictionary:
	if w.is_empty():
		w = _w()
	return Data.WEAPONS[w.key]

# =====================================================================
#  Stanze e ondate
# =====================================================================
func _start_room() -> void:
	var r := _room_rect()
	hero_pos = Vector2(r.get_center().x, r.end.y - 30)
	hero_vel = Vector2.ZERO
	cam_y = _cam_target()
	corpses.clear()
	altar = {}
	enemies.clear(); shots.clear(); bullets.clear(); drops.clear()
	clouds.clear(); patches.clear(); bolts.clear()
	anvil = {}
	_make_obstacles()
	door_open = false
	sparks += int(bonus.get("first_spark", 0))
	wave_idx = 0
	wave_delay = 0.8
	state = St.PLAY
	if room_n == Data.MINIBOSS_ROOM:
		waves = [["miniboss", "pebble", "pebble"]]
		boss_card_t = 2.4
		wave_delay = 2.0
		Sfx.play("boss", 0.0)
	elif room_n == Data.BOSS_ROOM:
		waves = [["boss"]]
		boss_card_t = 2.4
		wave_delay = 2.0
		Sfx.play("boss", 0.0)
	else:
		waves = Data.WAVES.get(room_n, [["zombie", "imp"]]).duplicate(true)
		_banner("STANZA %d" % room_n)

const ROCK_LAYOUTS := [
	[Vector2(0.22, 0.3), Vector2(0.78, 0.3), Vector2(0.22, 0.72), Vector2(0.78, 0.72)],
	[Vector2(0.2, 0.28), Vector2(0.8, 0.28), Vector2(0.35, 0.58), Vector2(0.65, 0.58), Vector2(0.2, 0.8), Vector2(0.8, 0.8)],
	[Vector2(0.28, 0.55), Vector2(0.72, 0.55)],
	[Vector2(0.15, 0.5), Vector2(0.3, 0.22), Vector2(0.7, 0.22), Vector2(0.85, 0.5)],
	[Vector2(0.3, 0.25), Vector2(0.7, 0.25), Vector2(0.3, 0.66), Vector2(0.7, 0.66)],
]

func _make_obstacles() -> void:
	obs.clear()
	floor_seed = room_n * 7919 + 13
	var layout: Array
	if room_n == Data.MINIBOSS_ROOM or room_n == Data.BOSS_ROOM:
		layout = ROCK_LAYOUTS[0]
	else:
		layout = ROCK_LAYOUTS[(room_n * 3 + 1) % ROCK_LAYOUTS.size()]
	var r := _room_rect()
	for f in layout:
		var c: Vector2 = r.position + r.size * f
		obs.append(Rect2(c - Vector2(ROCK, ROCK) / 2.0, Vector2(ROCK, ROCK)))

## Spinge fuori dalle colonne un cerchio di raggio "rad"
func _push_out(p: Vector2, rad: float) -> Vector2:
	for o in obs:
		var q := Vector2(clampf(p.x, o.position.x, o.end.x), clampf(p.y, o.position.y, o.end.y))
		var d := p - q
		var l := d.length()
		if l < rad:
			if l < 0.01:
				# dentro la colonna: esci dal lato più vicino
				var c: Vector2 = o.get_center()
				var dd := p - c
				d = Vector2(signf(dd.x), 0) if absf(dd.x) > absf(dd.y) else Vector2(0, signf(dd.y))
				if d == Vector2.ZERO:
					d = Vector2.UP
				p = c + d * (ROCK / 2.0 + rad)
			else:
				p = q + d / l * rad
	return p

func _in_rock(p: Vector2) -> bool:
	for o in obs:
		if o.has_point(p):
			return true
	return false

func _clear_line(a: Vector2, b: Vector2) -> bool:
	var n := int(a.distance_to(b) / 6.0)
	for i in range(1, n):
		if _in_rock(a.lerp(b, float(i) / n)):
			return false
	return true

func _banner(t: String) -> void:
	banner = t
	banner_t = 2.0

func _spawn_wave() -> void:
	var list: Array = waves[wave_idx]
	wave_idx += 1
	for k in list:
		_spawn_enemy(k, _free_spot())

func _free_spot() -> Vector2:
	var r := _room_rect()
	for i in 60:
		var p := Vector2(randf_range(r.position.x + 20, r.end.x - 20), randf_range(r.position.y + 20, r.position.y + r.size.y * 0.62))
		if p.distance_to(hero_pos) > 110 and not _in_rock(p) and _push_out(p, 14) == p:
			return p
	return Vector2(r.get_center().x, r.position.y + 40)

func _spawn_enemy(k: String, p: Vector2) -> Dictionary:
	var e := {
		"k": k, "pos": p, "vel": Vector2.ZERO, "spawn": 0.8, "flash": 0.0,
		"burn": 0.0, "burn_dps": 0.0, "slow": 0.0, "slow_amt": 0.0, "freeze": 0.0, "ice_hits": 0,
		"pois": 0, "pois_t": 0.0, "pois_dps": 0.0, "t": randf_range(1.2, 2.2), "st": "move",
		"aim": 0.0, "revived": false, "dead_t": 0.0, "patch_t": 0.0, "inv": 0.0, "tick": 0.0,
		"boss": false, "weak_known": false, "phase": 1, "summon_t": 6.0, "kb": Vector2.ZERO, "orb_cd": 0.0,
	}
	if k == "miniboss":
		e.merge({"fam": "golem", "hp": 950.0, "speed": 18.0, "size": 40, "dmg": 26, "sparks": 40, "kind": "slammer", "boss": true, "name": "GOLEM ANTICO"}, true)
		e.weak_known = true
	elif k == "boss":
		e.merge({"fam": "boss", "hp": 2000.0, "speed": 24.0, "size": 46, "dmg": 18, "sparks": 0, "kind": "boss", "boss": true, "name": "SIGNORE DELLA CENERE"}, true)
		e.spawn = 1.4
	else:
		var d: Dictionary = Data.ENEMIES[k]
		e.merge(d.duplicate(), true)
		e.hp = d.hp * (1.0 + 0.15 * (room_n - 1))
		# nemici élite: più grandi, più forti, più bottino
		if room_n >= 3 and randf() < 0.06 + 0.015 * room_n:
			e.elite = true
			e.hp *= 2.4
			e.size = int(e.size * 1.25)
			e.speed *= 1.1
			e.dmg = int(e.dmg * 1.3)
		e.dmg = int(round(d.dmg * (1.25 + 0.03 * (room_n - 1))))
	e.max = e.hp
	enemies.append(e)
	return e

func _boss_weak(e: Dictionary) -> String:
	if e.k != "boss":
		return ""
	return "ice" if e.phase == 1 else "thunder"

func _weak_of(e: Dictionary) -> String:
	if e.k == "boss":
		return _boss_weak(e)
	return Data.FAMILIES[e.fam].weak

# =====================================================================
#  Input
# =====================================================================
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if state == St.FORGE or state == St.PAUSE or state == St.DEAD or state == St.WIN or state == St.LEVEL:
				_ui_tap(t.position)
				return
			if _pause_rect().grow(6).has_point(t.position):
				state = St.PAUSE
				touch_index = -1
				return
			if _switch_rect().has_point(t.position):
				_try_switch()
				return
			if touch_index == -1:
				touch_index = t.index
				joy_origin = t.position
				joy_current = t.position
		elif t.index == touch_index:
			touch_index = -1
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == touch_index:
			joy_current = d.position
			var off := joy_current - joy_origin
			if off.length() > JOY_RADIUS:
				joy_origin = joy_current - off.normalized() * JOY_RADIUS

func _try_switch() -> void:
	if switch_t > 0.0 or weapons.size() < 2:
		return
	cur_w = 1 - cur_w
	switch_t = Data.SWITCH_COOLDOWN
	atk_t = minf(atk_t, 0.15)
	switch_bonus = true
	Sfx.play("switch", 0.03)
	rings.append({"pos": hero_pos, "r0": 8.0, "r1": 30.0, "life": 0.3, "max": 0.3, "col": Color("b9a8ff")})
	_float(hero_pos + Vector2(0, -16), _wdata().name, Color.WHITE)

# =====================================================================
#  Aggiornamento
# =====================================================================
func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	time += dt
	shake = maxf(0.0, shake - dt * 8.0)
	banner_t -= dt
	fade_t = maxf(0.0, fade_t - dt)
	hurt_t = maxf(0.0, hurt_t - dt * 2.5)
	if autotest:
		_autotest_step()
	if hitstop > 0.0:
		# piccolo fermo immagine quando un colpo va a segno forte
		hitstop -= delta
		queue_redraw()
		return
	if state == St.LEVEL:
		lvl_t += dt
	if state == St.FORGE and not strike.is_empty():
		strike.t += dt
		if strike.t > 2.6:
			_resolve_strike()
	cam_y = lerpf(cam_y, _cam_target(), minf(1.0, dt * 7.0))
	intro_t = maxf(0.0, intro_t - dt)
	boss_card_t = maxf(0.0, boss_card_t - dt)
	recoil = maxf(0.0, recoil - dt * 8.0)
	var gdt := dt
	if slowmo > 0.0:
		slowmo -= dt
		gdt = dt * 0.3
	if state == St.PLAY or state == St.CLEAR:
		_update_play(gdt)
	elif state == St.DEAD or state == St.WIN:
		end_t += dt
		_update_fx(dt)
	queue_redraw()

func _update_play(dt: float) -> void:
	switch_t = maxf(0.0, switch_t - dt)
	hero_inv = maxf(0.0, hero_inv - dt)
	hero_flash = maxf(0.0, hero_flash - dt * 5.0)
	_update_hero(dt)
	_update_attack(dt)
	_update_shots(dt)
	_update_enemies(dt)
	_update_bullets(dt)
	_update_ground(dt)
	_update_drops(dt)
	_update_fx(dt)
	_update_room_flow(dt)
	if win_delay > 0.0:
		win_delay -= dt
		if win_delay <= 0.0:
			_end_run(true)
	if pending_lv > 0 and win_delay < 0.0 and (state == St.PLAY or state == St.CLEAR):
		_open_level()

func _update_hero(dt: float) -> void:
	var target := Vector2.ZERO
	if auto_target != null:
		var off: Vector2 = auto_target - hero_pos
		if off.length() > 3.0:
			target = off.normalized() * HERO_SPEED
			facing = off.normalized()
	if touch_index != -1:
		var off := joy_current - joy_origin
		if off.length() > 3.0:
			var strength := clampf((off.length() - 3.0) / 9.0, 0.0, 1.0)
			target = off.normalized() * HERO_SPEED * (1.0 + bonus.speed_pct + 0.12 * _sk("speed")) * maxf(strength, 0.4)
			facing = off.normalized()
	if target != Vector2.ZERO:
		hero_vel = hero_vel.move_toward(target, ACCEL * dt)
	else:
		hero_vel = hero_vel.move_toward(Vector2.ZERO, FRICTION * dt)
	hero_pos += hero_vel * dt
	var r := _room_rect()
	var half := HERO_SIZE / 2.0
	# porta aperta: si può uscire dall'alto
	if state == St.CLEAR and door_open and absf(hero_pos.x - r.get_center().x) < 14 and hero_pos.y < r.position.y + half + 1:
		if hero_pos.y < r.position.y - 4:
			_next_room()
			return
	else:
		hero_pos.y = maxf(hero_pos.y, r.position.y + half)
	hero_pos = _push_out(hero_pos, half)
	hero_pos.x = clampf(hero_pos.x, r.position.x + half, r.end.x - half)
	hero_pos.y = minf(hero_pos.y, r.end.y - half)
	if hero_vel.length() > 5.0:
		step_t += dt * hero_vel.length() / 10.0
	# incudine
	if not anvil.is_empty():
		var d := hero_pos.distance_to(anvil.pos)
		if anvil_lock and d > 26:
			anvil_lock = false
		if not anvil_lock and d < 16:
			_open_forge()
	if not altar.is_empty() and not altar.used and hero_pos.distance_to(altar.pos) < 15:
		altar.used = true
		level_choices = ["altar_heal", "altar_skill"]
		level_mode = "altar"
		level_ret = state
		state = St.LEVEL
		lvl_t = 0.0
		touch_index = -1
		hero_vel = Vector2.ZERO
		Sfx.play("clang", 0.0)

func _alive_enemies() -> Array:
	return enemies.filter(func(e): return e.spawn <= 0.0 and e.dead_t <= 0.0)

func _nearest_enemy(from: Vector2, exclude: Array = [], max_d: float = 1e9) -> Variant:
	var best = null
	var bd := max_d
	for e in enemies:
		if e.spawn > 0.0 or e.dead_t > 0.0 or e in exclude:
			continue
		var d: float = from.distance_to(e.pos)
		if d < bd:
			bd = d
			best = e
	return best

func _nearest_visible(from: Vector2) -> Variant:
	var best = null
	var bd := 1e9
	var any = null
	var ad := 1e9
	for e in enemies:
		if e.spawn > 0.0 or e.dead_t > 0.0:
			continue
		var d: float = from.distance_to(e.pos)
		if d < ad:
			ad = d
			any = e
		if d < bd and _clear_line(from, e.pos):
			bd = d
			best = e
	return best if best != null else any

func _sk(k: String) -> int:
	return int(skills.get(k, 0))

func _atk_mult() -> float:
	return (1.0 + bonus.weapon_atk[cur_w]) * (1.0 + 0.18 * _sk("atk"))

func _update_attack(dt: float) -> void:
	atk_t = maxf(0.0, atk_t - dt)
	aim_target = _nearest_visible(hero_pos)
	_update_helpers(dt)
	# raffiche già partite (Colpo doppio)
	if not volley_q.is_empty():
		for v in volley_q:
			v.t -= dt
			if v.t <= 0.0:
				var d: Vector2 = last_dir
				if aim_target != null:
					d = (aim_target.pos - hero_pos).normalized()
				_fire_volley(d, 0.85)
		volley_q = volley_q.filter(func(v): return v.t > 0.0)
	var still := touch_index == -1 and auto_target == null and hero_vel.length() < 10.0
	if not still or atk_t > 0.0:
		return
	var tg = aim_target
	if tg == null:
		return
	var dir: Vector2 = (tg.pos - hero_pos).normalized()
	facing = dir
	last_dir = dir
	atk_t = _wdata().rate / (1.0 + bonus.aspd_pct + 0.2 * _sk("aspd"))
	_fire_volley(dir, 1.0, switch_bonus)
	switch_bonus = false
	for i in _sk("multi"):
		volley_q.append({"t": 0.12 * (i + 1)})

func _fire_volley(dir: Vector2, mult: float, sure_crit: bool = false) -> void:
	var wd := _wdata()
	var w := _w()
	var col := _shot_color(w)
	var dmg: float = wd.dmg * _atk_mult() * mult
	var dirs: Array = []      # [direzione, spostamento laterale]
	var base_angles: Array = [0.0] if not bonus.double_shot[cur_w] else [-0.14, 0.14]
	var nf := 1 + _sk("front")
	var front_mult := 1.0 if nf == 1 else 0.8
	for da in base_angles:
		for i in nf:
			dirs.append([dir.rotated(da), (i - (nf - 1) / 2.0) * 7.0])
	for i in _sk("diag"):
		var a: float = [0.75, 0.4][i]
		dirs.append([dir.rotated(a), 0.0])
		dirs.append([dir.rotated(-a), 0.0])
	if _sk("side") > 0:
		dirs.append([dir.rotated(PI / 2), 0.0])
		dirs.append([dir.rotated(-PI / 2), 0.0])
	if _sk("back") > 0:
		dirs.append([-dir, 0.0])
	var crit_ch: float = bonus.crit + 0.1 * _sk("crit") + wd.crit
	for idx in dirs.size():
		var d: Array = dirs[idx]
		var d2: Vector2 = d[0]
		var crit: bool = sure_crit or randf() < crit_ch
		var dm := dmg * (front_mult if idx < base_angles.size() * nf else 1.0) * (1.3 if sure_crit else 1.0)
		shots.append({
			"pos": hero_pos + d2 * 6 + d2.orthogonal() * d[1], "vel": d2 * wd.speed, "life": wd.range / wd.speed,
			"dmg": dm * (2.0 if crit else 1.0), "crit": crit, "w": w.key, "slots": w.slots.duplicate(), "size": wd.size,
			"area": wd.area, "hit": [], "col": col, "pierce": _sk("pierce") > 0, "bounce": 1 if _sk("bounce") > 0 else 0,
			"chain": _sk("chain"), "kb": {"sword": 150.0, "bow": 70.0, "staff": 55.0}.get(w.key, 60.0),
		})
	recoil = 1.0
	Sfx.play({"sword": "sword", "bow": "bow", "staff": "staff"}.get(w.key, "bow"))
	# lampo sulla punta dell'arma
	for i in 4:
		parts.append({"pos": hero_pos + dir * 11, "vel": dir.rotated(randf_range(-0.8, 0.8)) * randf_range(40, 90), "life": 0.15, "max": 0.15, "col": col.lightened(0.4), "size": 1})

## Martelli rotanti e fuocherelli
func _update_helpers(dt: float) -> void:
	orb_ang += dt * 3.6
	var n := _orbit_count()
	if n > 0:
		var dmg: float = 0.6 * _wdata().dmg * _atk_mult()
		for i in n:
			var p := _orbit_pos(i, n)
			for e in enemies:
				if e.spawn > 0.0 or e.dead_t > 0.0 or e.orb_cd > 0.0:
					continue
				if e.pos.distance_to(p) < e.size / 2.0 + 6:
					e.orb_cd = 0.45
					_hit_enemy(e, dmg, [], false, false, (e.pos - hero_pos).normalized() * 90.0)
					_burst(p, Color("e8ecf8"), 4)
	if _sk("spirit") > 0:
		spirit_t -= dt
		if spirit_t <= 0.0 and aim_target != null:
			spirit_t = 0.9
			for i in _sk("spirit"):
				var sp := _spirit_pos(i)
				var d: Vector2 = (aim_target.pos - sp).normalized()
				shots.append({
					"pos": sp, "vel": d * 210.0, "life": 1.6, "dmg": 7.0 * (1.0 + 0.18 * _sk("atk")), "crit": false,
					"w": "spirit", "slots": ["fire", ""], "size": 3, "area": 0.0, "hit": [], "col": Data.EL_COLOR.fire,
					"pierce": false, "bounce": 0, "chain": 0, "kb": 30.0,
				})

func _orbit_count() -> int:
	return 0 if _sk("orbit") == 0 else _sk("orbit") + 1

func _orbit_pos(i: int, n: int) -> Vector2:
	return hero_pos + Vector2.from_angle(orb_ang + TAU * i / n) * 27.0

func _spirit_pos(i: int) -> Vector2:
	var side := -1.0 if i == 0 else 1.0
	return hero_pos + Vector2(side * 15.0, -16.0 + sin(time * 3.0 + i) * 2.0)

func _shot_color(w: Dictionary) -> Color:
	var a: String = w.slots[0]
	var b: String = w.slots[1]
	if a == "" and b == "":
		return Data.WEAPONS[w.key].color
	if a == "":
		return Data.EL_COLOR[b]
	if b == "" or a == b:
		return Data.EL_COLOR[a]
	return Data.EL_COLOR[a].lerp(Data.EL_COLOR[b], 0.5)

func _update_shots(dt: float) -> void:
	var keep: Array = []
	var room := _room_rect()
	for s in shots:
		s.pos += s.vel * dt
		s.life -= dt
		var done := false
		# la spada distrugge i proiettili nemici
		if s.w == "sword":
			for b in bullets:
				if b.pos.distance_to(s.pos) < s.size + b.r:
					b.dead = true
					_burst(b.pos, Color.WHITE, 4)
		for e in enemies:
			if e.spawn > 0.0 or e.dead_t > 0.0 or e in s.hit:
				continue
			if e.pos.distance_to(s.pos) < e.size / 2.0 + s.size:
				s.hit.append(e)
				_hit_enemy(e, s.dmg, s.slots, s.w != "spirit", s.crit, s.vel.normalized() * s.kb)
				for i in (5 if s.crit else 3):
					parts.append({"pos": s.pos, "vel": (-s.vel.normalized()).rotated(randf_range(-1.0, 1.0)) * randf_range(50, 120), "life": 0.18, "max": 0.18, "col": s.col.lightened(0.5) if not s.crit else Color("ffd36b"), "size": 1})
				if s.area > 0.0:
					_explode(s.pos, s.area, s.dmg, s.slots, Color("c78cff"))
				if s.chain > 0:
					# salta sul nemico più vicino
					var n = _nearest_enemy(s.pos, s.hit, 95.0)
					if n != null:
						s.chain -= 1
						s.vel = (n.pos - s.pos).normalized() * s.vel.length()
						s.life = maxf(s.life, 0.6)
						s.dmg *= 0.8
						break
				if s.w == "sword":
					continue
				if s.pierce:
					s.dmg *= 0.75
					continue
				done = true
				break
		if not done and (_in_rock(s.pos) or not room.has_point(s.pos)):
			if s.bounce > 0:
				var prev: Vector2 = s.pos - s.vel * dt
				var tx := Vector2(s.pos.x, prev.y)
				if _in_rock(tx) or not room.has_point(tx):
					s.vel.x = -s.vel.x
				else:
					s.vel.y = -s.vel.y
				s.pos = prev
				s.bounce -= 1
				s.life = maxf(s.life, 0.5)
				s.hit.clear()
				_burst(s.pos, s.col, 3)
			elif _in_rock(s.pos):
				if s.area > 0.0:
					_explode(s.pos, s.area, s.dmg, s.slots, Color("c78cff"))
				_burst(s.pos, Color("8a8a96"), 3)
				done = true
		if not room.grow(4).has_point(s.pos):
			done = true
		if s.life <= 0.0:
			if s.area > 0.0 and s.hit.is_empty():
				_explode(s.pos, s.area, s.dmg, s.slots, Color("c78cff"))
			done = true
		if not done:
			keep.append(s)
	shots = keep
	bullets = bullets.filter(func(b): return not b.get("dead", false))

func _explode(p: Vector2, radius: float, dmg: float, slots: Array, col: Color) -> void:
	for i in 14:
		var a := TAU * i / 14.0
		parts.append({"pos": p, "vel": Vector2(cos(a), sin(a)) * radius * 3.0, "life": 0.25, "max": 0.25, "col": col, "size": 2})
	for e in enemies:
		if e.spawn > 0.0 or e.dead_t > 0.0:
			continue
		if e.pos.distance_to(p) < radius + e.size / 2.0:
			_hit_enemy(e, dmg * 0.7, slots, false)

# ---------------------------------------------------------------------
#  Colpi ed elementi
# ---------------------------------------------------------------------
func _count(slots: Array, el: String) -> int:
	var n := 0
	for s in slots:
		if s == el:
			n += 1
	return n

func _combo(slots: Array) -> String:
	if slots.size() < 2:
		return ""
	if slots[0] == "" or slots[1] == "" or slots[0] == slots[1]:
		return ""
	var k := Data.combo_key(slots[0], slots[1])
	return k if k in Save.recipes else ""

func _immune(e: Dictionary, el: String) -> bool:
	if e.fam == "boss":
		return false
	return Data.FAMILIES[e.fam].immune == el

func _hit_enemy(e: Dictionary, base: float, slots: Array, primary: bool, crit: bool = false, kb: Vector2 = Vector2.ZERO) -> void:
	if e.inv > 0.0:
		_float(e.pos + Vector2(0, -e.size), "IMMUNE", Art.TEXT_DIM)
		return
	var bw := _boss_weak(e)
	var mult := Data.element_mult(slots, e.fam, bw)
	if bw != "" and bw in slots and not e.weak_known:
		e.weak_known = true
		_banner("DEBOLEZZA SCOPERTA: %s!" % Data.EL_NAME[bw])
	var combo := _combo(slots)
	var dmg := base * mult
	if combo == "ice+thunder" and (e.slow > 0.0 or e.freeze > 0.0):
		dmg *= 1.5
	var col := Color.WHITE
	if crit:
		col = Color("ff9a2a")
		if bonus.crit_burn and not _immune(e, "fire"):
			e.burn = 3.0
			e.burn_dps = maxf(e.burn_dps, base * 0.2)
	elif mult >= 1.4:
		col = Color("ffe14a")
	elif mult < 0.8:
		col = Art.TEXT_DIM
	if kb != Vector2.ZERO:
		var resist := 0.2 if e.boss else (0.5 if e.size >= 26 else 1.0)
		e.kb = kb * resist
	if crit:
		hitstop = maxf(hitstop, 0.03)
		shake = maxf(shake, 0.4)
	_damage(e, dmg, col, slots, crit)
	if e.dead_t > 0.0 or e.hp <= 0.0:
		return
	# effetti degli elementi
	var nf := _count(slots, "fire")
	var ni := _count(slots, "ice")
	var nt := _count(slots, "thunder")
	var np := _count(slots, "poison")
	if nf > 0 and not _immune(e, "fire"):
		e.burn = 3.0 if nf == 1 else 4.0
		e.burn_dps = base * mult * (0.25 if nf == 1 else 0.55)
	if ni > 0 and not _immune(e, "ice"):
		e.slow = 1.5 if ni == 1 else 2.2
		e.slow_amt = 0.35 if ni == 1 else 0.6
		if ni == 2:
			e.ice_hits += 1
			if e.ice_hits >= 3:
				e.ice_hits = 0
				e.freeze = 0.35 if e.boss else 1.1
	if np > 0 and not _immune(e, "poison"):
		e.pois = mini(e.pois + np, 5 * np)
		e.pois_t = 4.0
		e.pois_dps = base * 0.08 * mult
	if primary and nt > 0:
		var exclude := [e]
		var from: Vector2 = e.pos
		for i in (1 if nt == 1 else 3):
			var n = _nearest_enemy(from, exclude, 75.0)
			if n == null:
				break
			exclude.append(n)
			bolts.append({"a": from, "b": n.pos, "life": 0.18})
			_hit_enemy(n, base * (0.5 if nt == 1 else 0.6), [] if combo != "poison+thunder" else ["poison", ""], false)
			if combo == "poison+thunder" and not _immune(n, "poison"):
				n.pois = mini(n.pois + 2, 8)
				n.pois_t = 4.0
				n.pois_dps = maxf(n.pois_dps, base * 0.08)
			from = n.pos
	if primary:
		match combo:
			"fire+thunder":
				_explode(e.pos, 28.0, base * 0.8, [], Color("ffb03a"))
			"fire+ice":
				if clouds.size() < 6:
					clouds.append({"pos": e.pos, "r": 26.0, "life": 2.2, "kind": "steam"})
			"fire+poison":
				if clouds.size() < 6:
					clouds.append({"pos": e.pos, "r": 22.0, "life": 2.6, "kind": "toxic", "dps": base * 0.5})

func _damage(e: Dictionary, amount: float, col: Color, slots: Array = [], crit: bool = false) -> void:
	if e.dead_t > 0.0:
		return
	e.hp -= amount
	e.flash = 1.0
	if amount >= 1.0:
		_float(e.pos + Vector2(randf_range(-4, 4), -e.size / 2.0 - 4), str(int(round(amount))) + ("!" if crit else ""), col, crit)
		Sfx.play("crit" if crit else "hit", 0.12)
	if e.hp <= 0.0:
		_kill(e, slots)

func _kill(e: Dictionary, slots: Array = []) -> void:
	# i non-morti si rialzano una volta
	if e.fam == "undead" and not e.revived:
		e.revived = true
		e.dead_t = 1.6
		e.hp = e.max * 0.5
		e.burn = 0.0; e.pois = 0; e.slow = 0.0; e.freeze = 0.0
		_burst(e.pos, Color("b8c4a0"), 8)
		return
	if _combo(slots) == "ice+thunder" and (e.slow > 0.0 or e.freeze > 0.0):
		_explode(e.pos, 26.0, 18.0, [], Color("bfefff"))
	e.dead = true
	Sfx.play("kill", 0.12, 3.0 if e.boss else 0.0)
	corpses.append({"pos": e.pos, "col": _enemy_color(e), "size": float(e.size), "t": 0.0, "k": e.k})
	for i in 8:
		parts.append({"pos": e.pos + Vector2(randf_range(-6, 6), randf_range(-6, 4)), "vel": Vector2(randf_range(-12, 12), randf_range(-45, -20)), "life": 0.9, "max": 0.9, "col": Color("8a8090"), "size": 2})
	shake = maxf(shake, 0.6 if not e.boss else 1.8)
	hitstop = maxf(hitstop, 0.04 if not e.boss else 0.2)
	_burst(e.pos, _enemy_color(e), 12 if not e.boss else 40)
	_burst(e.pos, Color.WHITE, 5)
	rings.append({"pos": e.pos, "r0": e.size * 0.4, "r1": e.size * 1.4, "life": 0.3, "max": 0.3, "col": Color.WHITE})
	# esperienza
	var gx := 2
	if e.k == "miniboss":
		gx = 25
	elif e.k == "boss":
		gx = 0
	elif e.size >= 26:
		gx = 4
	if e.get("elite", false):
		gx *= 3
		for i in 2:
			_drop("gem", e.pos)
	_gain_xp(gx, e.pos)
	if _sk("drain") > 0:
		hero_hp = mini(max_hp, hero_hp + 3 * _sk("drain"))
	# bottino
	var n: int = e.sparks + (1 if bonus.extra_spark else 0)
	if e.get("elite", false):
		n *= 2
	for i in _sk("spark"):
		if randf() < 0.5:
			n += 1
	for i in n:
		_drop("spark", e.pos)
	if Gear.FAMILY_MATERIAL.has(e.fam) and randf() < 0.22:
		_drop("mat_" + Gear.FAMILY_MATERIAL[e.fam], e.pos)
	if e.k == "miniboss":
		for i in 6:
			_drop("mat_stone", e.pos)
		run_items.append(Save.add_item(Gear.random_base(), Gear.roll_rarity([40.0, 40.0, 18.0, 2.0, 0.0])))
		_banner("BOTTINO: UN PEZZO DI EQUIPAGGIAMENTO!")
	if e.k == "boss":
		for m in ["bone", "stone", "ember"]:
			for i in 3:
				_drop("mat_" + m, e.pos)
		for i in 2:
			run_items.append(Save.add_item(Gear.random_base(), Gear.roll_rarity([10.0, 45.0, 35.0, 10.0, 0.0])))
	if randf() < 0.5 or e.boss:
		for i in (randi_range(1, 2) if not e.boss else 12):
			_drop("gold", e.pos)
	if randf() < 0.05 or e.boss:
		for i in (1 if not e.boss else 3):
			_drop("gem", e.pos)
	if e.k == "boss":
		for i in 60:
			_drop("gold", e.pos)
		for i in 5:
			_drop("gem", e.pos)

func _drop(kind: String, p: Vector2) -> void:
	var a := randf() * TAU
	drops.append({"kind": kind, "pos": p, "vel": Vector2(cos(a), sin(a)) * randf_range(30, 90), "t": 0.0, "z": 0.0, "vz": randf_range(70, 110)})

# ---------------------------------------------------------------------
#  Nemici
# ---------------------------------------------------------------------
func _update_enemies(dt: float) -> void:
	for e in enemies:
		e.flash = maxf(0.0, e.flash - dt * 7.0)
		e.inv = maxf(0.0, e.inv - dt)
		e.orb_cd = maxf(0.0, e.orb_cd - dt)
		if e.spawn > 0.0:
			e.spawn -= dt
			continue
		if e.dead_t > 0.0:
			e.dead_t -= dt
			continue
		# stati
		if e.burn > 0.0:
			e.burn -= dt
			e.hp -= e.burn_dps * dt
			if randf() < dt * 12.0:
				parts.append({"pos": e.pos + Vector2(randf_range(-5, 5), -2), "vel": Vector2(0, -25), "life": 0.4, "max": 0.4, "col": Data.EL_COLOR.fire, "size": 1})
		if e.pois > 0:
			e.hp -= e.pois_dps * e.pois * dt
			var keep_pois: bool = e.slow > 0.0 and _toxic_freeze_active(e)
			if not keep_pois:
				e.pois_t -= dt
			if e.pois_t <= 0.0:
				e.pois = 0
		e.tick -= dt
		if e.tick <= 0.0:
			e.tick = 0.5
			# piccolo numero per i danni nel tempo
		if e.hp <= 0.0 and not e.get("dead", false):
			_kill(e)
			continue
		e.slow = maxf(0.0, e.slow - dt)
		if e.freeze > 0.0:
			e.freeze -= dt
			continue
		var spd: float = e.speed * (1.0 - (e.slow_amt if e.slow > 0.0 else 0.0))
		for c in clouds:
			if c.kind == "steam" and c.pos.distance_to(e.pos) < c.r:
				spd *= 0.8
		var to_hero: Vector2 = hero_pos - e.pos
		var dist := to_hero.length()
		var dir := to_hero / maxf(dist, 0.01)
		match e.kind:
			"melee":
				e.vel = dir * spd
				if e.k == "imp":
					e.patch_t -= dt
					if e.patch_t <= 0.0:
						e.patch_t = 1.1
						patches.append({"pos": e.pos, "life": 3.0, "r": 7.0})
			"shooter", "spread":
				_ai_shooter(e, dt, dir, dist, spd)
			"slammer":
				_ai_slammer(e, dt, dir, dist, spd)
			"boss":
				_ai_boss(e, dt, dir, dist, spd)
		e.pos += e.vel * dt
		e.pos += e.kb * dt
		e.kb = e.kb.move_toward(Vector2.ZERO, 700.0 * dt)
		# contatto con l'eroe
		if dist < (e.size + HERO_SIZE) / 2.0 - 2:
			_hurt_hero(e.dmg if e.kind != "slammer" else 10)
	# separazione: i nemici non si sovrappongono
	for i in enemies.size():
		var a = enemies[i]
		if a.spawn > 0.0 or a.dead_t > 0.0:
			continue
		for j in range(i + 1, enemies.size()):
			var b = enemies[j]
			if b.spawn > 0.0 or b.dead_t > 0.0:
				continue
			var d: Vector2 = b.pos - a.pos
			var min_d: float = (a.size + b.size) / 2.0
			if d.length() < min_d and d.length() > 0.01:
				var push: Vector2 = d.normalized() * (min_d - d.length()) * 0.5
				if not a.boss:
					a.pos -= push
				if not b.boss:
					b.pos += push
	var r := _room_rect()
	for e in enemies:
		var h: float = e.size / 2.0
		if e.k != "boss" or e.st != "charge":
			e.pos = _push_out(e.pos, h)
		e.pos.x = clampf(e.pos.x, r.position.x + h, r.end.x - h)
		e.pos.y = clampf(e.pos.y, r.position.y + h, r.end.y - h)
	enemies = enemies.filter(func(e): return not e.get("dead", false))

func _toxic_freeze_active(_e: Dictionary) -> bool:
	# Congelamento tossico: vale se l'arma attuale o l'altra ha ghiaccio+veleno
	for w in weapons:
		if _combo(w.slots) == "ice+poison":
			return true
	return false

func _aim_error(e: Dictionary) -> float:
	for c in clouds:
		if c.kind == "steam" and c.pos.distance_to(e.pos) < c.r:
			return randf_range(-0.7, 0.7)
	return 0.0

func _ai_shooter(e: Dictionary, dt: float, dir: Vector2, dist: float, spd: float) -> void:
	e.t -= dt
	if e.st == "move":
		if dist > 125:
			e.vel = dir * spd
		elif dist < 60:
			e.vel = -dir * spd
		else:
			e.vel = dir.orthogonal() * spd * 0.5 * (1 if int(time / 2.0 + e.pos.x) % 2 == 0 else -1)
		if e.t <= 0.0:
			e.st = "aim"
			e.t = 0.75
			e.aim = dir.angle()
			e.vel = Vector2.ZERO
	elif e.st == "aim":
		e.vel = Vector2.ZERO
		if e.t <= 0.0:
			var a: float = e.aim + _aim_error(e)
			if e.kind == "spread":
				for k in [-0.35, 0.0, 0.35]:
					_enemy_shot(e.pos, a + k, 82.0, 4.0, e.dmg, Color("ff8a2b"))
			elif e.k == "pebble":
				_enemy_shot(e.pos, a, 70.0, 6.0, e.dmg, Color("b0a090"))
			else:
				_enemy_shot(e.pos, a, 95.0, 3.5, e.dmg, BULLET)
			e.st = "move"
			e.t = randf_range(1.8, 2.8)

func _ai_slammer(e: Dictionary, dt: float, dir: Vector2, dist: float, spd: float) -> void:
	e.t -= dt
	var slam_r: float = 44.0 if not e.boss else 64.0
	if e.st == "move":
		e.vel = dir * spd
		if dist < slam_r + 6 and e.t <= 0.0:
			e.st = "slam"
			e.t = 0.9
			e.vel = Vector2.ZERO
		elif e.boss and e.t <= -1.2:
			e.st = "throw"
			e.t = 0.8
			e.aim = dir.angle()
			e.vel = Vector2.ZERO
	elif e.st == "slam":
		e.vel = Vector2.ZERO
		if e.t <= 0.0:
			shake = maxf(shake, 1.0)
			Sfx.play("slam", 0.05)
			_burst(e.pos, Color("8a7a6a"), 16)
			rings.append({"pos": e.pos, "r0": 6.0, "r1": slam_r, "life": 0.35, "max": 0.35, "col": Color("d8c0a0")})
			if hero_pos.distance_to(e.pos) < slam_r:
				_hurt_hero(e.dmg)
			e.st = "move"
			e.t = 2.2
	elif e.st == "throw":
		e.vel = Vector2.ZERO
		if e.t <= 0.0:
			for k in 5:
				_enemy_shot(e.pos, e.aim + (k - 2) * 0.28, 80.0, 5.0, 14, Color("b0a090"))
			e.st = "move"
			e.t = 1.6

func _ai_boss(e: Dictionary, dt: float, dir: Vector2, dist: float, spd: float) -> void:
	# cambio fase a metà vita: la debolezza cambia
	if e.phase == 1 and e.hp < e.max * 0.5:
		e.phase = 2
		e.weak_known = false
		e.inv = 1.4
		e.st = "move"
		e.t = 1.6
		shake = 2.0
		bullets.clear()
		_burst(e.pos, Color("ffe14a"), 40)
		_banner("FASE 2: LA DEBOLEZZA CAMBIA!")
	e.t -= dt
	e.summon_t -= dt
	if e.summon_t <= 0.0:
		e.summon_t = 9.0 if e.phase == 1 else 7.0
		for i in 2:
			var s := _spawn_enemy("imp" if e.phase == 1 else "pebble", _free_spot())
			s.spawn = 0.9
	match e.st:
		"move":
			e.vel = dir * spd * (0.6 if dist < 90 else 1.0)
			if e.t <= 0.0:
				var pick := randi() % 2
				if e.phase == 1:
					e.st = "ring" if pick == 0 else "aimed"
				else:
					e.st = "charge_aim" if pick == 0 else "spiral"
				e.t = 0.8
				e.aim = dir.angle()
				e.vel = Vector2.ZERO
		"ring":
			e.vel = Vector2.ZERO
			if e.t <= 0.0:
				var gap: float = (hero_pos - e.pos).angle()
				for i in 16:
					var a := TAU * i / 16.0
					if absf(angle_difference(a, gap)) < 0.45:
						continue
					_enemy_shot(e.pos, a, 75.0, 4.5, e.dmg, BULLET)
				e.st = "move"
				e.t = 2.0
		"aimed":
			e.vel = Vector2.ZERO
			if e.t <= 0.0:
				for k in [-0.2, 0.0, 0.2]:
					_enemy_shot(e.pos, e.aim + k, 110.0, 4.0, e.dmg, Color("ff8a2b"))
				e.st = "move"
				e.t = 1.6
		"charge_aim":
			e.vel = Vector2.ZERO
			if e.t <= 0.0:
				e.st = "charge"
				e.t = 0.55
				e.vel = Vector2.from_angle(e.aim) * 230.0
		"charge":
			if e.t <= 0.0:
				e.st = "move"
				e.t = 1.4
				shake = 0.8
		"spiral":
			e.vel = Vector2.ZERO
			if e.t <= 0.0:
				e.st = "spiral_fire"
				e.t = 2.4
				e.spin = 0.0
				e.fire_t = 0.0
		"spiral_fire":
			e.vel = Vector2.ZERO
			e.spin = e.get("spin", 0.0) + dt * 2.2
			e.fire_t = e.get("fire_t", 0.0) - dt
			if e.fire_t <= 0.0:
				e.fire_t = 0.16
				for k in 3:
					_enemy_shot(e.pos, e.spin + TAU * k / 3.0, 70.0, 4.0, e.dmg, BULLET)
			if e.t <= 0.0:
				e.st = "move"
				e.t = 1.8

func _enemy_shot(p: Vector2, a: float, spd: float, r: float, dmg: int, col: Color) -> void:
	Sfx.play("shoot_enemy", 0.15)
	bullets.append({"pos": p, "vel": Vector2.from_angle(a) * spd, "r": r, "dmg": dmg, "col": col})

func _update_bullets(dt: float) -> void:
	var rr := _room_rect().grow(6)
	var keep: Array = []
	for b in bullets:
		b.pos += b.vel * dt
		if b.pos.distance_to(hero_pos) < b.r + HERO_SIZE / 2.0 - 3:
			_hurt_hero(b.dmg)
			continue
		if _in_rock(b.pos):
			_burst(b.pos, b.col, 3)
			continue
		if rr.has_point(b.pos):
			keep.append(b)
	bullets = keep

func _update_ground(dt: float) -> void:
	for c in clouds:
		c.life -= dt
		if c.kind == "toxic":
			for e in enemies:
				if e.spawn <= 0.0 and e.dead_t <= 0.0 and c.pos.distance_to(e.pos) < c.r:
					e.hp -= c.dps * dt
	clouds = clouds.filter(func(c): return c.life > 0.0)
	for p in patches:
		p.life -= dt
		if p.pos.distance_to(hero_pos) < p.r + 4:
			_hurt_hero(6)
	patches = patches.filter(func(p): return p.life > 0.0)

func _hurt_hero(dmg: int) -> void:
	if hero_inv > 0.0 or state != St.PLAY and state != St.CLEAR:
		return
	dmg = maxi(1, int(round(dmg * (1.0 - bonus.dmg_taken) * (1.0 - _wdata().guard))))
	hero_hp -= dmg
	hero_inv = 0.8
	hero_flash = 1.0
	hurt_t = 1.0
	Sfx.play("hurt", 0.05)
	shake = maxf(shake, 1.2)
	hitstop = maxf(hitstop, 0.05)
	_float(hero_pos + Vector2(0, -12), "-%d" % dmg, Art.HP)
	if hero_hp <= 0 and bonus.revive and not revived:
		revived = true
		hero_hp = int(max_hp * 0.4)
		hero_inv = 2.0
		bullets.clear()
		_burst(hero_pos, Art.GOLD, 30)
		_banner("SECONDA VITA!")
		return
	if hero_hp <= 0:
		hero_hp = 0
		_burst(hero_pos, HERO, 30)
		_end_run(false)

# ---------------------------------------------------------------------
#  Bottino, effetti, flusso
# ---------------------------------------------------------------------
func _update_drops(dt: float) -> void:
	var keep: Array = []
	for d in drops:
		d.t += dt
		d.vz -= 420.0 * dt
		d.z += d.vz * dt
		if d.z < 0.0:
			d.z = 0.0
			d.vz = -d.vz * 0.4 if absf(d.vz) > 25.0 else 0.0
		var to: Vector2 = hero_pos - d.pos
		var magnet := state == St.CLEAR or to.length() < 26
		if magnet and d.t > 0.35:
			d.vel = d.vel.lerp(to.normalized() * 260.0, minf(1.0, dt * 8.0))
		else:
			d.vel = d.vel.move_toward(Vector2.ZERO, 200 * dt)
		d.pos += d.vel * dt
		if to.length() < 8 and d.t > 0.3:
			Sfx.play("spark" if d.kind == "spark" else "coin", 0.1)
			match d.kind:
				"spark": sparks += 1
				"gold": run_gold += 1
				"gem": run_gems += 1
				_:
					run_mats[d.kind.substr(4)] += 1
			continue
		keep.append(d)
	drops = keep

func _update_fx(dt: float) -> void:
	for p in parts:
		p.pos += p.vel * dt
		p.vel *= 0.92
		p.life -= dt
	parts = parts.filter(func(p): return p.life > 0.0)
	for f in floats:
		f.pos += f.vel * dt
		f.vel.y += 140.0 * dt
		f.life -= dt
	floats = floats.filter(func(f): return f.life > 0.0)
	for r in rings:
		r.life -= dt
	rings = rings.filter(func(r): return r.life > 0.0)
	for c in corpses:
		c.t += dt
	corpses = corpses.filter(func(c): return c.t < 0.55)
	for b in bolts:
		b.life -= dt
	bolts = bolts.filter(func(b): return b.life > 0.0)

func _update_room_flow(dt: float) -> void:
	if state != St.PLAY:
		return
	if enemies.is_empty():
		if wave_idx < waves.size():
			wave_delay -= dt
			if wave_delay <= 0.0:
				_spawn_wave()
				wave_delay = 0.7
		else:
			_room_cleared()

func _room_cleared() -> void:
	state = St.CLEAR
	bullets.clear()
	slowmo = 0.45
	Sfx.play("clear", 0.0)
	if room_n == Data.BOSS_ROOM:
		win_delay = 2.5      # il tempo di raccogliere il bottino del boss
		_banner("IL SIGNORE DELLA CENERE E SCONFITTO!")
		return
	var r := _room_rect()
	anvil = {"pos": Vector2(r.get_center().x, r.position.y + r.size.y * 0.38), "big": room_n in Data.BIG_FORGE_ROOMS}
	anvil_lock = false
	door_open = true
	Sfx.play("door", 0.0)
	if room_n in [2, 5, 10]:
		altar = {"pos": Vector2(r.position.x + 30, r.position.y + r.size.y * 0.55), "used": false}
	_banner("STANZA LIBERA!" if not anvil.big else "FUCINA GRANDE!")
	forge_big = anvil.big
	_make_offers()

func _next_room() -> void:
	room_n += 1
	fade_t = 0.35
	volley_q.clear()
	hero_hp = mini(max_hp, hero_hp + int(bonus.room_heal))   # piccola cura tra le stanze
	_start_room()

func _burst(p: Vector2, col: Color, n: int) -> void:
	for i in n:
		var a := randf() * TAU
		parts.append({"pos": p, "vel": Vector2(cos(a), sin(a)) * randf_range(30, 110), "life": randf_range(0.25, 0.6), "max": 0.6, "col": col, "size": 2 if randf() < 0.5 else 1})

func _float(p: Vector2, t: String, col: Color, big: bool = false) -> void:
	floats.append({"pos": p, "txt": t, "col": col, "life": 0.75 if not big else 0.95, "big": big,
		"vel": Vector2(randf_range(-22, 22), -70.0 if not big else -90.0)})

# ---------------------------------------------------------------------
#  Livelli e abilità
# ---------------------------------------------------------------------
func _gain_xp(n: int, from: Vector2) -> void:
	if n <= 0:
		return
	xp += n
	for i in mini(n, 4):
		parts.append({"pos": from, "vel": Vector2.from_angle(randf() * TAU) * 40.0, "life": 0.5, "max": 0.5, "col": Color("7dffb0"), "size": 2})
	while xp >= Skills.xp_need(lvl):
		xp -= Skills.xp_need(lvl)
		lvl += 1
		pending_lv += 1

func _open_level() -> void:
	level_choices = Skills.roll(skills, float(hero_hp) / max_hp)
	if level_choices.is_empty():
		pending_lv = 0
		return
	level_ret = state
	level_mode = "level"
	state = St.LEVEL
	lvl_t = 0.0
	touch_index = -1
	hero_vel = Vector2.ZERO
	Sfx.play("level", 0.0)

func _pick_skill(i: int) -> void:
	if i >= level_choices.size() or lvl_t < 0.35:
		return
	var k: String = level_choices[i]
	Sfx.play("click", 0.0)
	if level_mode == "altar":
		state = level_ret
		level_mode = "level"
		_burst(hero_pos, Color("ff8a2b"), 24)
		if k == "altar_heal":
			hero_hp = mini(max_hp, hero_hp + int(max_hp * 0.6))
			_float(hero_pos + Vector2(0, -24), "Vita +60%", Art.GREEN)
		else:
			var pick: Array = Skills.roll(skills, 0.0)
			if not pick.is_empty():
				skills[pick[0]] = _sk(pick[0]) + 1
				_float(hero_pos + Vector2(0, -24), Skills.LIST[pick[0]].name, Color("ffd36b"))
				if pick[0] == "hp":
					max_hp += 25
					hero_hp += 25
		return
	skills[k] = _sk(k) + 1
	match k:
		"hp":
			max_hp += 25
			hero_hp += 25
		"heal":
			hero_hp = mini(max_hp, hero_hp + int(max_hp * 0.4))
	pending_lv -= 1
	state = level_ret
	_burst(hero_pos, Art.GOLD, 24)
	rings.append({"pos": hero_pos, "r0": 6.0, "r1": 46.0, "life": 0.45, "max": 0.45, "col": Art.GOLD})
	_float(hero_pos + Vector2(0, -24), Skills.LIST[k].name, Color("ffd36b"))

# =====================================================================
#  Forgia
# =====================================================================
func _price() -> int:
	var p := Data.BASE_PRICE + Data.PRICE_STEP * purchases
	return int(p * 0.75) if bonus.get("cheap_forge", false) else p

func _make_offers() -> void:
	# offerte legate alle famiglie delle prossime stanze
	var weights := {"fire": 1.0, "ice": 1.0, "thunder": 1.0, "poison": 1.2}
	for n in range(room_n + 1, mini(room_n + 4, Data.ROOMS + 1)):
		for wave in Data.WAVES.get(n, []):
			for k in wave:
				weights[Data.FAMILIES[Data.ENEMIES[k].fam].weak] += 0.4
		if n == Data.MINIBOSS_ROOM:
			weights.thunder += 2.0
		if n == Data.BOSS_ROOM:
			weights.ice += 1.5
			weights.thunder += 1.5
	offers.clear()
	for i in (5 if forge_big else 3):
		offers.append({"el": _weighted_pick(weights), "sold": false})
	sel_offer = -1
	forge_msg = ""

func _weighted_pick(w: Dictionary) -> String:
	var tot := 0.0
	for k in w:
		tot += w[k]
	var x := randf() * tot
	for k in w:
		x -= w[k]
		if x <= 0.0:
			return k
	return "fire"

func _open_forge() -> void:
	state = St.FORGE
	touch_index = -1
	hero_vel = Vector2.ZERO
	sel_offer = -1
	forge_msg = "SCEGLI UN ELEMENTO" if not offers.is_empty() else ""

func _close_forge() -> void:
	state = St.CLEAR
	anvil_lock = true

func _ui_tap(p: Vector2) -> void:
	if state == St.FORGE and not strike.is_empty():
		_resolve_strike()
		return
	for key in ui_rects:
		var r: Rect2 = ui_rects[key]
		if r.has_point(p):
			if not key.begins_with("skill"):
				Sfx.play("click", 0.0)
			_ui_action(key)
			return

func _ui_action(key: String) -> void:
	if key.begins_with("skill"):
		_pick_skill(int(key.substr(5)))
	elif key == "sound":
		Sfx.set_enabled(not Save.sound)
	elif key == "resume":
		state = St.PLAY if anvil.is_empty() else St.CLEAR
		if enemies.is_empty() and wave_idx >= waves.size():
			state = St.CLEAR
	elif key == "quit":
		_end_run(false)
	elif key == "home":
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
	elif key == "again":
		get_tree().reload_current_scene()
	elif key == "exit":
		_close_forge()
	elif key == "reroll":
		if sparks >= Data.REROLL_PRICE:
			sparks -= Data.REROLL_PRICE
			_make_offers()
			forge_msg = "NUOVE OFFERTE"
		else:
			forge_msg = "SCINTILLE INSUFFICIENTI"
	elif key.begins_with("offer"):
		var i := int(key.substr(5))
		if offers[i].sold:
			return
		if sparks < _price():
			forge_msg = "SCINTILLE INSUFFICIENTI"
			sel_offer = -1
			return
		sel_offer = i
		forge_msg = "TOCCA UN INCASTRO DI UN'ARMA"
	elif key.begins_with("slot"):
		var wi := int(key.substr(4, 1))
		var si := int(key.substr(5, 1))
		var w: Dictionary = weapons[wi]
		if sel_offer == -1:
			# nella fucina grande puoi togliere un elemento (ti torna metà)
			if forge_big and w.slots[si] != "":
				var back: int = w.paid[si] / 2
				sparks += back
				forge_msg = "TOLTO %s: +%d SCINTILLE" % [Data.EL_NAME[w.slots[si]], back]
				w.slots[si] = ""
				w.paid[si] = 0
			else:
				forge_msg = "PRIMA SCEGLI UN ELEMENTO"
			return
		var el: String = offers[sel_offer].el
		var price := _price()
		if sparks < price:
			forge_msg = "SCINTILLE INSUFFICIENTI"
			return
		var refund := 0
		if w.slots[si] != "":
			refund = w.paid[si] / 2
		sparks += refund - price
		w.slots[si] = el
		w.paid[si] = price
		purchases += 1
		offers[sel_offer].sold = true
		sel_offer = -1
		var info := Data.slots_info(w.slots, Save.recipes)
		forge_msg = "%s: %s!" % [Data.WEAPONS[w.key].name, info[0]]
		_burst(anvil.pos, Data.EL_COLOR[el], 20)
		strike = {"t": 0.0, "price": price, "el": el}

# =====================================================================
#  Fine partita
# =====================================================================
func _end_run(win: bool) -> void:
	if state == St.DEAD or state == St.WIN:
		return
	state = St.WIN if win else St.DEAD
	end_t = 0.0
	touch_index = -1
	var frac := 1.0 if win else clampf(float(room_n) / Data.ROOMS, 0.0, 1.0)
	var spark_gold := sparks / Data.SPARK_TO_GOLD
	var gold_kept := int(round((run_gold + spark_gold) * frac * (1.0 + bonus.get("gold_pct", 0.0))))
	var gems_kept := int(round(run_gems * frac))
	end_info = {"gold": run_gold, "spark_gold": spark_gold, "sparks": sparks, "frac": frac, "gold_kept": gold_kept, "gems_kept": gems_kept, "gems": run_gems, "mats": {}}
	for m in run_mats:
		var kept := int(round(run_mats[m] * frac))
		end_info.mats[m] = kept
		Save.materials[m] += kept
	Save.gold += gold_kept
	Save.gems += gems_kept
	Save.runs += 1
	if win:
		Save.wins += 1
	Save.best_room = maxi(Save.best_room, room_n)
	Save.save_game()

# =====================================================================
#  Disegno (stile Braceforte 2: forme tonde, contorno scuro, bagliori)
# =====================================================================
const OUT := Color("120c24")

func _draw() -> void:
	ui_rects.clear()
	var off := Vector2.ZERO
	if shake > 0.0:
		off = Vector2(randf_range(-2, 2), randf_range(-2, 2)) * shake * 1.3
	_base_off = Vector2(0, HUD_H - cam_y * ZOOM) + off
	_xr()
	_draw_room()
	_draw_ground()
	_draw_anvil()
	_draw_altar()
	_draw_aim_marker()
	for c in corpses:
		_draw_corpse(c)
	_draw_rocks_base()
	# ombre dei proiettili e del bottino: danno l'idea che volino sopra il pavimento
	for sh in shots:
		_xf(sh.pos + Vector2(0, 8), 0, Vector2(1, 0.4))
		draw_circle(Vector2.ZERO, sh.size * 0.9 + 1.5, Color(0, 0, 0, 0.28))
	for bl in bullets:
		_xf(bl.pos + Vector2(0, 8), 0, Vector2(1, 0.4))
		draw_circle(Vector2.ZERO, bl.r + 1.0, Color(0, 0, 0, 0.28))
	for d in drops:
		_xf(d.pos + Vector2(0, 3), 0, Vector2(1, 0.4))
		draw_circle(Vector2.ZERO, 3.5 - minf(d.z, 20.0) * 0.08, Color(0, 0, 0, 0.3))
	_xr()
	for d in drops:
		_draw_drop(d)
	# dall'alto in basso, così chi sta davanti copre chi sta dietro (anche le rocce)
	var actors: Array = []
	for e in enemies:
		actors.append({"y": e.pos.y, "e": e})
	for o in obs:
		actors.append({"y": (o as Rect2).end.y - 4, "rock": o})
	if state != St.DEAD:
		actors.append({"y": hero_pos.y, "hero": true})
	actors.sort_custom(func(x, y): return x.y < y.y)
	for ac in actors:
		if ac.has("hero"):
			_draw_hero()
			_draw_helpers()
		elif ac.has("rock"):
			_draw_rock(ac.rock)
		else:
			_draw_enemy(ac.e)
	# buio attorno all'eroe, poi tutto quello che fa luce
	_draw_darkness()
	_draw_lights()
	for e in enemies:
		_draw_enemy_telegraph(e)
	for sh in shots:
		_draw_shot(sh)
	for bl in bullets:
		Art.glow(self, bl.pos, bl.r * 3.4, Color(bl.col, 0.6))
		draw_circle(bl.pos, bl.r + 1.4, OUT)
		draw_circle(bl.pos, bl.r, bl.col)
		draw_arc(bl.pos, bl.r + 0.6, 0, TAU, 12, Color(1, 1, 1, 0.5 + 0.3 * sin(time * 20.0)), 0.8, true)
		draw_circle(bl.pos - Vector2(bl.r, bl.r) * 0.3, bl.r * 0.45, Color(1, 1, 1, 0.85))
	for bo in bolts:
		_draw_bolt(bo.a, bo.b)
	for rg in rings:
		var k: float = 1.0 - rg.life / rg.max
		draw_arc(rg.pos, lerpf(rg.r0, rg.r1, k), 0, TAU, 32, Color(rg.col, (1.0 - k) * 0.8), 2.5 * (1.0 - k) + 0.5, true)
	for pt in parts:
		var c: Color = pt.col
		c.a = clampf(pt.life / pt.max * 1.5, 0.0, 1.0)
		draw_circle(pt.pos, pt.size * 0.8, c)
	# da qui in poi: coordinate dello schermo
	draw_set_transform(Vector2.ZERO)
	for f in floats:
		var a: float = clampf(f.life * 3.0, 0.0, 1.0)
		var big: bool = f.get("big", false)
		var age: float = (0.95 if big else 0.75) - f.life
		var sc := 1.0 + maxf(0.0, 0.12 - age) * (5.0 if big else 3.0)
		var sp := _w2s(f.pos) + off
		if sp.y < HUD_H + 4 or sp.y > _size().y - BAR_H:
			continue
		draw_set_transform(sp, 0, Vector2(sc, sc))
		PixelFont.draw_centered(self, f.txt, 0, -6, 2 if big else 1, Color(f.col, a), Color(OUT, a))
	draw_set_transform(Vector2.ZERO)
	if touch_index != -1 and (state == St.PLAY or state == St.CLEAR):
		draw_circle(joy_origin, JOY_RADIUS + 2, Color(0, 0, 0, 0.18))
		draw_circle(joy_origin, JOY_RADIUS, Color(1, 1, 1, 0.07))
		draw_arc(joy_origin, JOY_RADIUS, 0, TAU, 40, Color(1, 1, 1, 0.3), 1.5, true)
		var jd := joy_current - joy_origin
		if jd.length() > 3.0:
			var ja := jd.angle()
			draw_arc(joy_origin, JOY_RADIUS, ja - 0.5, ja + 0.5, 12, Color(1, 0.75, 0.35, 0.9), 3.0, true)
		var knob := joy_origin + jd.limit_length(JOY_RADIUS)
		draw_circle(knob, 10, Color(0, 0, 0, 0.25))
		draw_circle(knob, 9, Color(1, 1, 1, 0.55))
		draw_circle(knob + Vector2(-2, -2), 4, Color(1, 1, 1, 0.5))
	var low := float(hero_hp) / max_hp < 0.3 and (state == St.PLAY or state == St.CLEAR)
	if hurt_t > 0.0 or low:
		var keep := hurt_t
		if low:
			hurt_t = maxf(hurt_t, 0.35 + 0.25 * sin(time * 5.0))
		_draw_hurt()
		hurt_t = keep
	if fade_t > 0.0:
		draw_rect(Rect2(0, HUD_H, _size().x, _size().y - HUD_H - BAR_H), Color(0.04, 0.02, 0.08, fade_t / 0.35))
	_draw_hud()
	_draw_bar()
	_draw_banner()
	if intro_t > 0.0 and room_n == 1:
		_draw_intro()
	if boss_card_t > 0.0:
		_draw_boss_card()
	match state:
		St.FORGE:
			_draw_forge()
			if not strike.is_empty():
				_draw_strike()
		St.PAUSE: _draw_pause()
		St.LEVEL: _draw_levelup()
		St.DEAD, St.WIN: _draw_end()

## Buio attorno all'eroe (luce calda che lo segue)
func _draw_darkness() -> void:
	var R := 165.0
	var dc := Color(0.02, 0.0, 0.05, 0.68)
	var c := hero_pos
	if state == St.DEAD:
		c = Vector2(_view_w() / 2.0, cam_y + _view_h() / 2.0)
	var v := Rect2(-30, cam_y - 30, _view_w() + 60, _view_h() + 60)
	var lr := Rect2(c - Vector2(R, R), Vector2(R, R) * 2.0)
	draw_texture_rect(dark_tex, lr, false)
	draw_rect(Rect2(v.position.x, v.position.y, v.size.x, maxf(0.0, lr.position.y - v.position.y)), dc)
	draw_rect(Rect2(v.position.x, lr.end.y, v.size.x, maxf(0.0, v.end.y - lr.end.y)), dc)
	draw_rect(Rect2(v.position.x, lr.position.y, maxf(0.0, lr.position.x - v.position.x), lr.size.y), dc)
	draw_rect(Rect2(lr.end.x, lr.position.y, maxf(0.0, v.end.x - lr.end.x), lr.size.y), dc)

## Fonti di luce disegnate sopra il buio
func _draw_lights() -> void:
	var r := _room_rect()
	for f in [0.12, 0.32, 0.68, 0.88]:
		var tx: float = r.position.x + r.size.x * f
		var ty := TOP_WALL * 0.45
		var fl := 0.8 + 0.2 * sin(time * 11.0 + tx)
		Art.glow(self, Vector2(tx, ty), 34 * fl, Color(1, 0.55, 0.2, 0.3))
		draw_circle(Vector2(tx, ty - 1), 3.0 * fl, Color("ff8a2b"))
		draw_circle(Vector2(tx, ty - 1.5), 1.6 * fl, Color("ffe14a"))
	for p in patches:
		Art.glow(self, p.pos, p.r * 2.6, Color(1, 0.45, 0.1, 0.3 * clampf(p.life, 0.0, 1.0)))
	if not anvil.is_empty():
		Art.glow(self, anvil.pos, 44, Color(1, 0.55, 0.2, 0.22 + 0.06 * sin(time * 4.0)))
	if not altar.is_empty() and not altar.used:
		Art.glow(self, altar.pos + Vector2(0, -8), 34, Color(1, 0.4, 0.15, 0.3 + 0.1 * sin(time * 5.0)))
	if door_open:
		var d := _door_rect()
		Art.glow(self, Vector2(d.get_center().x, d.end.y), 40, Color(1, 0.7, 0.3, 0.35))
	for e in enemies:
		if e.spawn <= 0.0 and (e.k == "imp" or e.k == "boss" or e.burn > 0.0):
			Art.glow(self, e.pos, e.size * 1.3, Color(1, 0.45, 0.15, 0.25))
		if e.get("elite", false) and e.spawn <= 0.0:
			Art.glow(self, e.pos, e.size * 1.5, Color(1, 0.8, 0.2, 0.18 + 0.06 * sin(time * 6.0)))

## Nemico che si sbriciola in cenere
func _draw_corpse(c: Dictionary) -> void:
	var k: float = c.t / 0.55
	var r: float = c.size / 2.0 + 1.0
	var col: Color = Color(c.col).lerp(Color("8a8090"), minf(1.0, k * 2.0))
	col.a = 1.0 - k
	_xf(c.pos + Vector2(0, r * k * 0.6), 0, Vector2(1.0 + k * 0.4, maxf(0.05, 1.0 - k)))
	draw_circle(Vector2.ZERO, r + 1.5, Color(OUT, 1.0 - k))
	draw_circle(Vector2.ZERO, r, col)
	_xr()

func _draw_altar() -> void:
	if altar.is_empty():
		return
	var p: Vector2 = altar.pos
	_xf(p + Vector2(0, 4), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 13, Color(0, 0, 0, 0.35))
	_xr()
	Art.rbox(self, Rect2(p.x - 10, p.y - 6, 20, 10), Color("4a3a46"), OUT, 3, 2)
	Art.rbox(self, Rect2(p.x - 12, p.y - 10, 24, 6), Color("6a5464"), OUT, 3, 2)
	if not altar.used:
		var fl := sin(time * 10.0) * 1.5
		_poly([p + Vector2(-5, -10), p + Vector2(-2, -20 + fl), p + Vector2(0, -15), p + Vector2(3, -23 - fl), p + Vector2(5, -10)], Color("ff6a2a"))
		draw_circle(p + Vector2(0, -12), 2.5, Color("ffe14a"))
		var y := p.y - 36 - 2 * sin(time * 3.0)
		var label := "Altare delle braci"
		var tw := PixelFont.text_width(label, 1) + 12
		Art.rbox(self, Rect2(p.x - 2, y - 2, tw, 14), Color(0, 0, 0, 0.6), Color("ff8a3d"), 7, 1)
		PixelFont.draw_text(self, label, Vector2(p.x + 4, y), 1, Color("ffc08a"))

## Presentazione del boss, con bande nere da film
func _draw_boss_card() -> void:
	var s := _size()
	var k := clampf((2.4 - boss_card_t) * 4.0, 0.0, 1.0) * clampf(boss_card_t * 3.0, 0.0, 1.0)
	var band := 44.0 * k
	draw_rect(Rect2(0, HUD_H, s.x, band), Color(0, 0, 0, 0.9))
	draw_rect(Rect2(0, s.y - BAR_H - band, s.x, band), Color(0, 0, 0, 0.9))
	var boss := room_n == Data.BOSS_ROOM
	var y := s.y * 0.36
	var slide := (1.0 - k) * 60.0
	Art.glow(self, Vector2(s.x / 2.0, y + 20), 120, Color(1, 0.25, 0.15, 0.35 * k))
	PixelFont.draw_centered(self, "Boss" if boss else "Mini-boss", s.x / 2.0 - slide, y, 2, Color(1, 0.55, 0.45, k), Color(OUT, k))
	PixelFont.draw_centered(self, "Signore della Cenere" if boss else "Golem antico", s.x / 2.0 + slide, y + 18, 3, Color(1, 1, 1, k), Color(OUT, k))
	var sub := "Debolezza nascosta: scoprila colpendolo" if boss else "Debole al Fulmine"
	PixelFont.draw_centered(self, sub, s.x / 2.0, y + 48, 1, Color(1, 0.85, 0.5, k), Color(OUT, k))

## Cartolina del capitolo con la mappa delle 12 stanze
func _draw_intro() -> void:
	var s := _size()
	var a := clampf(intro_t * 2.0, 0.0, 1.0) * clampf((2.8 - intro_t) * 4.0, 0.0, 1.0)
	var r := Rect2(14, s.y * 0.3, s.x - 28, 112)
	Art.rbox(self, r, Color(0.07, 0.05, 0.14, 0.92 * a), Color(1, 0.75, 0.35, a), 12, 2)
	PixelFont.draw_centered(self, "Capitolo 1", s.x / 2.0, r.position.y + 10, 2, Color(1, 0.79, 0.29, a), Color(OUT, a))
	PixelFont.draw_centered(self, "La Fonderia caduta", s.x / 2.0, r.position.y + 28, 3, Color(1, 1, 1, a), Color(OUT, a))
	_draw_map(Vector2(r.position.x + 14, r.position.y + 76), r.size.x - 28, a)

func _draw_map(pos: Vector2, w: float, a: float = 1.0) -> void:
	var n := Data.ROOMS
	var step := w / (n - 1)
	draw_line(pos, pos + Vector2(w, 0), Color(1, 1, 1, 0.2 * a), 2.0, true)
	draw_line(pos, pos + Vector2(step * (room_n - 1), 0), Color(1, 0.7, 0.3, 0.9 * a), 2.0, true)
	for i in n:
		var rn := i + 1
		var c := pos + Vector2(i * step, 0)
		var special := rn in Data.BIG_FORGE_ROOMS or rn == Data.MINIBOSS_ROOM or rn == Data.BOSS_ROOM
		var rad := 6.0 if special else 4.0
		var col := Color("ffb03a") if rn < room_n else (Color.WHITE if rn == room_n else Color("3a3540"))
		if rn == room_n:
			Art.glow(self, c, 14, Color(1, 0.8, 0.4, 0.6 * a))
		draw_circle(c, rad + 1.5, Color(OUT, a))
		draw_circle(c, rad, Color(col, a))
		if rn == Data.BOSS_ROOM or rn == Data.MINIBOSS_ROOM:
			Art.icon(self, "skull", c - Vector2(3.5, 3.5) * 1.1, 1.1, Color(Art.HP, a))
		elif rn in Data.BIG_FORGE_ROOMS:
			Art.icon(self, "anvil", c - Vector2(3.5, 3.5) * 1.1, 1.1, Color(OUT, a))

## Segno rosso sotto il nemico che stai mirando
func _draw_aim_marker() -> void:
	if aim_target == null or state != St.PLAY:
		return
	var e: Dictionary = aim_target
	if e.get("dead", false) or e.dead_t > 0.0:
		return
	var r: float = e.size / 2.0 + 5.0
	var c: Vector2 = e.pos + Vector2(0, e.size * 0.42)
	_xf(c, 0, Vector2(1, 0.45))
	draw_arc(Vector2.ZERO, r, 0, TAU, 32, Color(1, 0.25, 0.3, 0.35), 3.0, true)
	for i in 4:
		var a := time * 2.5 + i * TAU / 4.0
		draw_arc(Vector2.ZERO, r, a, a + 0.8, 8, Color(1, 0.35, 0.35, 0.95), 2.0, true)
	_xr()

func _draw_helpers() -> void:
	var n := _orbit_count()
	for i in n:
		var p := _orbit_pos(i, n)
		var a := orb_ang * 2.0 + i
		Art.glow(self, p, 9, Color(1, 0.6, 0.25, 0.4))
		# martello: manico + testa
		var d := Vector2.from_angle(a)
		draw_line(p - d * 5, p + d * 3, OUT, 3.5, true)
		draw_line(p - d * 5, p + d * 3, Color("8a6a40"), 2.0, true)
		var hd := p + d * 4
		var o := d.orthogonal()
		var pts := PackedVector2Array([hd - o * 4 - d * 2, hd + o * 4 - d * 2, hd + o * 4 + d * 2, hd - o * 4 + d * 2])
		draw_colored_polygon(pts, Color("d8dcef"))
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), OUT, 1.2, true)
	for i in _sk("spirit"):
		var sp := _spirit_pos(i)
		Art.glow(self, sp, 10, Color(1, 0.5, 0.15, 0.55))
		var fl := sin(time * 12.0 + i) * 1.2
		_poly([sp + Vector2(-4, 1), sp + Vector2(-1.5, -6 + fl), sp + Vector2(0.5, -3), sp + Vector2(2.5, -7 - fl), sp + Vector2(4, 1), sp + Vector2(0, 4)], Color("ff8a2b"))
		draw_circle(sp + Vector2(0, 0.5), 2.2, Color("ffe14a"))
		draw_circle(sp + Vector2(-1.2, 0), 0.7, OUT)
		draw_circle(sp + Vector2(1.2, 0), 0.7, OUT)

func _draw_hurt() -> void:
	var s := _size()
	var top := HUD_H
	var h := s.y - HUD_H - BAR_H
	for i in 5:
		var w := 4.0 + i * 5.0
		var a := hurt_t * 0.16 * (5 - i) / 5.0
		var c := Color(1, 0.1, 0.15, a)
		draw_rect(Rect2(0, top, w, h), c)
		draw_rect(Rect2(s.x - w, top, w, h), c)
		draw_rect(Rect2(0, top, s.x, w), c)
		draw_rect(Rect2(0, top + h - w, s.x, w), c)

func _lines(t: String, max_w: float, scale: int) -> Array:
	var out: Array = []
	var cur := ""
	for word in t.split(" "):
		var tryl := word if cur == "" else cur + " " + word
		if PixelFont.text_width(tryl, scale) > max_w and cur != "":
			out.append(cur)
			cur = word
		else:
			cur = tryl
	if cur != "":
		out.append(cur)
	return out

## Scelta dell'abilità quando sali di livello
func _draw_levelup() -> void:
	var s := _size()
	var a := clampf(lvl_t * 4.0, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.02, 0.01, 0.06, 0.8 * a))
	var ty := s.y * 0.13
	Art.glow(self, Vector2(s.x / 2.0, ty + 16), 90, Color(1, 0.7, 0.2, 0.35 * a))
	for i in 10:
		var ang := time * 0.6 + i * TAU / 10.0
		var p := Vector2(s.x / 2.0, ty + 16) + Vector2.from_angle(ang) * (54 + 6 * sin(time * 3.0 + i))
		draw_circle(p, 1.5, Color(1, 0.8, 0.3, 0.7 * a))
	var altar_mode := level_mode == "altar"
	PixelFont.draw_centered(self, "Altare delle braci" if altar_mode else "Livello %d!" % lvl, s.x / 2.0, ty, 3 if altar_mode else 4, Color(1, 0.79, 0.29, a), Color(OUT, a))
	PixelFont.draw_centered(self, "Scegli un dono" if altar_mode else "Scegli un'abilità", s.x / 2.0, ty + 40, 2, Color(1, 1, 1, a), Color(OUT, a))
	var cw := 82.0
	var ch := 158.0
	var gap := 5.0
	var x0 := (s.x - (cw * level_choices.size() + gap * (level_choices.size() - 1))) / 2.0
	var y0 := s.y * 0.3
	for i in level_choices.size():
		var k: String = level_choices[i]
		var info: Dictionary = Skills.LIST[k] if Skills.LIST.has(k) else Skills.ALTAR[k]
		var appear := clampf((lvl_t - i * 0.08) * 5.0, 0.0, 1.0)
		var r := Rect2(x0 + i * (cw + gap), y0 + (1.0 - appear) * 40.0, cw, ch)
		ui_rects["skill%d" % i] = r
		var edge: Color = Skills.CAT_COLOR[info.cat]
		Art.glow(self, r.get_center(), 70, Color(edge, 0.18 * appear))
		_card(r, edge)
		var ic := Vector2(r.get_center().x, r.position.y + 34)
		Art.glow(self, ic, 30, Color(edge, 0.5))
		Skills.icon(self, k if Skills.LIST.has(k) else info.icon, ic, 20)
		var ly := r.position.y + 62
		for line in _lines(info.name, cw - 8, 2):
			PixelFont.draw_centered(self, line, r.get_center().x, ly, 2, Color.WHITE, OUT)
			ly += 16
		ly += 4
		for line in _lines(info.desc, cw - 10, 1):
			PixelFont.draw_centered(self, line, r.get_center().x, ly, 1, Color("c9bce8"))
			ly += 11
		# livello dell'abilità
		var mx: int = info.get("max", 99)
		if mx <= 5:
			var have := _sk(k)
			var px := r.get_center().x - (mx * 9 - 3) / 2.0
			for j in mx:
				var dc := Rect2(px + j * 9, r.end.y - 14, 6, 6)
				Art.rbox(self, dc, edge if j < have + 1 else Color(1, 1, 1, 0.12), OUT if j == have else Color(0, 0, 0, 0), 3, 1)
	# abilità già prese
	var keys: Array = skills.keys()
	if not keys.is_empty():
		var by := y0 + ch + 26
		PixelFont.draw_centered(self, "Le tue abilità", s.x / 2.0, by, 1, Art.TEXT_DIM)
		_draw_skill_row(by + 22)

func _draw_skill_row(y: float) -> void:
	var keys: Array = skills.keys()
	var s := _size()
	var step := minf(22.0, (s.x - 20) / maxf(1, keys.size()))
	var x := s.x / 2.0 - step * (keys.size() - 1) / 2.0
	for k in keys:
		Skills.icon(self, k, Vector2(x, y), 8)
		if _sk(k) > 1:
			PixelFont.draw_centered(self, str(_sk(k)), x + 7, y + 2, 1, Color.WHITE, OUT)
		x += step

# ---------------------------------------------------------------------
#  Stanza
# ---------------------------------------------------------------------
const TILE_A := Color("4a3c3a")
const TILE_B := Color("54443f")

func _draw_room() -> void:
	var r := _room_rect()
	draw_rect(Rect2(-60, -60, _view_w() + 120, TOP_WALL + ROOM_H + 200), Art.INK)
	var rng := RandomNumberGenerator.new()
	rng.seed = floor_seed
	var tint := Color(1, 1, 1)
	if room_n == Data.BOSS_ROOM:
		tint = Color(1.15, 0.85, 0.82)
	elif room_n == Data.MINIBOSS_ROOM:
		tint = Color(0.92, 0.95, 1.08)
	# pavimento: lastre di basalto sfalsate, alcune con vene di lava
	draw_rect(r, Color("121014"))
	var sw := 30.0
	var shh := 21.0
	var rows := int(ceil(r.size.y / shh)) + 1
	var pulse := 0.55 + 0.45 * sin(time * 2.2)
	for y in rows:
		var offx := 0.0 if y % 2 == 0 else -sw * 0.5
		var x := offx
		while x < r.size.x:
			var t := Rect2(r.position + Vector2(x + 1, y * shh + 1), Vector2(sw - 2, shh - 2)).intersection(r)
			x += sw
			if t.size.x <= 2 or t.size.y <= 2:
				continue
			var base := Color("2a262e").lerp(Color("36303a"), rng.randf()) * tint
			Art.grad_poly(self, PackedVector2Array([t.position, Vector2(t.end.x, t.position.y), t.end, Vector2(t.position.x, t.end.y)]), base.lightened(0.06), base.darkened(0.12))
			draw_line(t.position + Vector2(1, 0.5), Vector2(t.end.x - 1, t.position.y + 0.5), base.lightened(0.18), 1.0)
			var roll := rng.randf()
			if roll < 0.05:
				# vena di lava
				var p0 := t.position + Vector2(rng.randf_range(3, t.size.x - 3), 2)
				var p1 := p0 + Vector2(rng.randf_range(-6, 6), t.size.y * 0.5)
				var p2 := p1 + Vector2(rng.randf_range(-5, 5), t.size.y * 0.45)
				var vl := PackedVector2Array([p0, p1, p2])
				Art.glow(self, p1, 10, Color(1, 0.35, 0.05, 0.22 * pulse))
				draw_polyline(vl, Color(0.25, 0.05, 0.0), 2.4, true)
				draw_polyline(vl, Color(1, 0.45 + 0.2 * pulse, 0.1, 0.9), 1.0, true)
			elif roll < 0.24:
				var p0 := t.position + Vector2(rng.randf_range(4, t.size.x - 8), rng.randf_range(3, t.size.y - 6))
				draw_polyline(PackedVector2Array([p0, p0 + Vector2(4, 3), p0 + Vector2(3, 7)]), base.darkened(0.45), 1.0, true)
			elif roll < 0.32:
				for i in 3:
					draw_circle(t.position + Vector2(rng.randf_range(3, t.size.x - 3), rng.randf_range(3, t.size.y - 3)), rng.randf_range(0.6, 1.3), Color(0.8, 0.75, 0.7, 0.12))
	# sigillo della forgia inciso al centro
	var sc := r.get_center() + Vector2(0, 20)
	draw_arc(sc, 46, 0, TAU, 48, Color(1, 0.5, 0.2, 0.12), 2.0, true)
	draw_arc(sc, 40, 0, TAU, 48, Color(1, 0.5, 0.2, 0.08), 1.0, true)
	for i in 6:
		var aa := i * TAU / 6.0 + 0.3
		draw_line(sc + Vector2.from_angle(aa) * 40, sc + Vector2.from_angle(aa + 2.1) * 40, Color(1, 0.5, 0.2, 0.07), 1.2, true)
	Art.icon(self, "anvil", sc - Vector2(3.5, 3.5) * 2.4, 2.4, Color(1, 0.5, 0.2, 0.1))
	# griglie con brace sotto, ossa, catene
	for i in 5:
		var dp := Vector2(rng.randf_range(r.position.x + 14, r.end.x - 14), rng.randf_range(r.position.y + 24, r.end.y - 20))
		var kind := rng.randi() % 3
		if kind == 0:
			var aa := rng.randf() * TAU
			var dv := Vector2.from_angle(aa) * 5.0
			draw_line(dp - dv, dp + dv, Color("bdb4a0", 0.5), 1.8, true)
			draw_circle(dp - dv, 1.5, Color("bdb4a0", 0.5))
			draw_circle(dp + dv, 1.5, Color("bdb4a0", 0.5))
		elif kind == 1:
			Art.glow(self, dp, 16, Color(1, 0.4, 0.1, 0.25 * pulse))
			draw_rect(Rect2(dp - Vector2(9, 6), Vector2(18, 12)), Color("1a0a06"))
			draw_rect(Rect2(dp - Vector2(7, 4), Vector2(14, 8)), Color(1, 0.35, 0.05, 0.35 * pulse))
			draw_rect(Rect2(dp - Vector2(9, 6), Vector2(18, 12)), Color("4a4450"), false, 1.5)
			for j in 4:
				draw_line(dp + Vector2(-6 + j * 4, -5), dp + Vector2(-6 + j * 4, 5), Color("4a4450"), 1.4, true)
		else:
			for j in 5:
				var cp := dp + Vector2(j * 3.2, sin(j * 1.3) * 1.5)
				draw_arc(cp, 1.6, 0, TAU, 8, Color("5a5660", 0.7), 1.0, true)
	# muro in alto: pietra scura, stendardi, torce in ferro
	var wall := Rect2(r.position.x - WALL_SIZE, r.position.y - TOP_WALL, r.size.x + WALL_SIZE * 2, TOP_WALL)
	Art.grad_poly(self, PackedVector2Array([wall.position, Vector2(wall.end.x, wall.position.y), wall.end, Vector2(wall.position.x, wall.end.y)]), Color("1e1a22"), Color("2c2630"))
	var bh := TOP_WALL / 3.0
	for row in 3:
		var y0 := wall.position.y + row * bh
		var ox := 0.0 if row % 2 == 0 else 13.0
		var x := wall.position.x - ox
		while x < wall.end.x:
			var br := Rect2(x + 1, y0 + 1, 25, bh - 2).intersection(wall)
			if br.size.x > 0:
				draw_rect(br, Color("2e2832").lerp(Color("3a3340"), rng.randf()))
				draw_line(br.position, Vector2(br.end.x, br.position.y), Color(1, 1, 1, 0.05), 1.0)
			x += 26
	draw_rect(Rect2(wall.position.x, wall.end.y - 3, wall.size.x, 3), Color("4a4450"))
	draw_rect(Rect2(wall.position.x, wall.end.y, wall.size.x, 1), Art.INK)
	draw_rect(Rect2(r.position.x, r.position.y + 1, r.size.x, 8), Color(0, 0, 0, 0.3))
	# stendardi
	for f in [0.22, 0.78]:
		var bx: float = r.position.x + r.size.x * f
		var sway := sin(time * 1.5 + f * 9.0) * 0.8
		var ban := [Vector2(bx - 7, wall.position.y + 2), Vector2(bx + 7, wall.position.y + 2), Vector2(bx + 7 + sway, wall.end.y + 6), Vector2(bx + sway, wall.end.y + 2), Vector2(bx - 7 + sway, wall.end.y + 6)]
		_gp(ban, Color("7a1c26"), Color("3e0c14"), 1.2)
		draw_line(Vector2(bx - 8, wall.position.y + 2), Vector2(bx + 8, wall.position.y + 2), Art.GOLD, 1.4)
		Art.icon(self, "anvil", Vector2(bx - 4.5 + sway * 0.5, wall.position.y + 9), 1.3, Art.GOLD)
	# muri laterali
	for wx in [r.position.x - WALL_SIZE, r.end.x]:
		Art.grad_poly(self, PackedVector2Array([Vector2(wx, r.position.y), Vector2(wx + WALL_SIZE, r.position.y), Vector2(wx + WALL_SIZE, r.end.y + WALL_SIZE), Vector2(wx, r.end.y + WALL_SIZE)]), Color("221e26"), Color("16131a"))
	draw_rect(Rect2(r.position.x - 1.5, r.position.y, 1.5, r.size.y), Color("4a4450"))
	draw_rect(Rect2(r.end.x, r.position.y, 1.5, r.size.y), Color("4a4450"))
	draw_rect(Rect2(r.position.x, r.end.y, r.size.x, WALL_SIZE), Color("16131a"))
	# torce (la luce si disegna dopo il buio)
	for f in [0.08, 0.4, 0.6, 0.92]:
		var tx: float = r.position.x + r.size.x * f
		var ty := TOP_WALL * 0.45
		draw_line(Vector2(tx, ty + 7), Vector2(tx, ty + 1), Color("3a3440"), 2.0)
		draw_rect(Rect2(tx - 2.5, ty - 1, 5, 2.5), Color("5a5460"))
	# cancello: arco di pietra con saracinesca di ferro
	var d := _door_rect()
	var gc := Vector2(d.get_center().x, d.position.y + 10)
	draw_circle(gc, 21, Art.INK)
	draw_circle(gc, 19, Color("3e3844"))
	draw_rect(Rect2(d.position.x - 3, gc.y, d.size.x + 6, d.end.y - gc.y), Art.INK)
	draw_rect(Rect2(d.position.x - 1, gc.y, d.size.x + 2, d.end.y - gc.y), Color("3e3844"))
	var inner := Rect2(d.position.x + 2, gc.y, d.size.x - 4, d.end.y - gc.y)
	draw_circle(gc, 15, Color("07050a"))
	draw_rect(inner, Color("07050a"))
	if door_open:
		Art.glow(self, Vector2(gc.x, d.end.y - 2), 30, Color(1, 0.6, 0.25, 0.6 + 0.2 * sin(time * 4.0)))
		var ay := r.position.y + 12 + 3 * sin(time * 6.0)
		_poly([Vector2(gc.x, ay - 6), Vector2(gc.x + 7, ay + 2), Vector2(gc.x - 7, ay + 2)], Art.GOLD)
	else:
		for i in 5:
			var bx := inner.position.x + 3 + i * (inner.size.x - 6) / 4.0
			draw_line(Vector2(bx, gc.y - 12 + absf(i - 2) * 2), Vector2(bx, d.end.y), Color("6a6474"), 2.2, true)
			draw_circle(Vector2(bx, d.end.y - 1), 1.4, Color("8a8494"))
		for yy in [gc.y + 2, gc.y + 9]:
			draw_line(Vector2(inner.position.x, yy), Vector2(inner.end.x, yy), Color("6a6474"), 2.0, true)

func _poly(pts: Array, col: Color, outline: bool = true) -> void:
	var p := PackedVector2Array(pts)
	if outline:
		var q := p.duplicate()
		q.append(p[0])
		draw_polyline(q, OUT, 2.0, true)
	draw_colored_polygon(p, col)

func _draw_rocks_base() -> void:
	for o in obs:
		var rr: Rect2 = o
		Art.rbox(self, Rect2(rr.position + Vector2(3, 3), rr.size), Color(0, 0, 0, 0.3), Color(0, 0, 0, 0), 7)

## Pilastro di ossidiana con fasce di ferro e cima incandescente
func _draw_rock(rr: Rect2) -> void:
	var front := Rect2(rr.position + Vector2(0, -8), rr.size + Vector2(0, 8))
	Art.grad_poly(self, Art.cut_pts(front, 4), Color("26222c"), Color("121016"))
	Art.outline(self, Art.cut_pts(front, 4), Art.INK, 2.0)
	for yy in [front.end.y - 7, front.end.y - 14]:
		draw_line(Vector2(front.position.x + 1, yy), Vector2(front.end.x - 1, yy), Color("4a4450"), 2.0)
		draw_circle(Vector2(front.position.x + 4, yy), 1.0, Art.BRONZE)
		draw_circle(Vector2(front.end.x - 4, yy), 1.0, Art.BRONZE)
	var top := Rect2(rr.position + Vector2(0, -10), Vector2(rr.size.x, rr.size.y - 6))
	Art.grad_poly(self, Art.cut_pts(top, 5), Color("4a4452"), Color("2a2630"))
	Art.outline(self, Art.cut_pts(top, 5), Art.INK, 2.0)
	var c := top.get_center()
	var pl := 0.55 + 0.45 * sin(time * 2.5 + rr.position.x)
	Art.glow(self, c, 12, Color(1, 0.4, 0.1, 0.3 * pl))
	draw_polyline(PackedVector2Array([c + Vector2(-6, -3), c + Vector2(-1, 0), c + Vector2(-2, 3), c + Vector2(5, 4)]), Color(1, 0.5, 0.15, pl), 1.2, true)
	draw_line(top.position + Vector2(5, 1.5), Vector2(top.end.x - 5, top.position.y + 1.5), Color(1, 1, 1, 0.12), 1.0)

func _draw_vignette() -> void:
	var s := _size()
	for i in 6:
		var a := 0.07 * (6 - i) / 6.0
		var w := 6.0 + i * 6.0
		draw_rect(Rect2(0, HUD_H, w, s.y - HUD_H - BAR_H), Color(0, 0, 0, a * 0.6))
		draw_rect(Rect2(s.x - w, HUD_H, w, s.y - HUD_H - BAR_H), Color(0, 0, 0, a * 0.6))
		draw_rect(Rect2(0, s.y - BAR_H - w, s.x, w), Color(0, 0, 0, a))

func _draw_ground() -> void:
	for p in patches:
		var a: float = clampf(p.life, 0.0, 1.0)
		Art.glow(self, p.pos, p.r * 2.2, Color(1, 0.4, 0.1, 0.45 * a))
		draw_circle(p.pos, p.r * 0.8, Color(1, 0.35, 0.1, 0.35 * a))
		for i in 3:
			var fx: float = p.pos.x + (i - 1) * 3.0
			var fy: float = p.pos.y - 2 - fmod(time * 10.0 + i * 3.0, 5.0)
			draw_circle(Vector2(fx, fy), 1.4, Color(1, 0.8, 0.3, a))
	for c in clouds:
		var a: float = clampf(c.life, 0.0, 1.0)
		var col := Color(0.9, 0.95, 1.0, 0.22 * a) if c.kind == "steam" else Color(0.45, 1.0, 0.35, 0.22 * a)
		for i in 4:
			var ang := time * 0.8 + i * TAU / 4.0
			draw_circle(c.pos + Vector2.from_angle(ang) * c.r * 0.35, c.r * 0.65, col)

func _draw_anvil() -> void:
	if anvil.is_empty():
		return
	var p: Vector2 = anvil.pos
	var big: bool = anvil.big
	Art.glow(self, p, 40 if not big else 54, Color(1, 0.55, 0.2, 0.35 + 0.1 * sin(time * 4.0)))
	_xf(p, 0, Vector2.ONE * (0.42 if not big else 0.55))
	# stessa incudine del titolo, più piccola
	draw_rect(Rect2(-26, 22, 52, 30), OUT)
	draw_rect(Rect2(-24, 24, 48, 26), Color("6b3d22"))
	var pts := [Vector2(-46, -4), Vector2(-30, -10), Vector2(30, -10), Vector2(34, -4), Vector2(34, 4), Vector2(16, 8), Vector2(20, 22), Vector2(-20, 22), Vector2(-16, 8), Vector2(-30, 4), Vector2(-46, 0)]
	_poly(pts, Color("5a5f7a"))
	draw_rect(Rect2(-30, -9, 62, 4), Color("8a90b0"))
	var hot := Color("ff7a1a").lerp(Color("ffe14a"), 0.5 + 0.3 * sin(time * 4.0))
	Art.rbox(self, Rect2(-26, -16, 44, 6), hot, OUT, 3, 2)
	_xr()
	var label := "Incudine" if not big else "Fucina grande"
	var y := p.y - 26 - 2 * sin(time * 3.0)
	var tw := PixelFont.text_width(label, 1) + 12
	Art.rbox(self, Rect2(p.x - tw / 2.0, y - 2, tw, 14), Color(0, 0, 0, 0.55), Color("ffc531"), 7, 1)
	PixelFont.draw_centered(self, label, p.x, y, 1, Color("ffd36b"))

func _draw_drop(d: Dictionary) -> void:
	var p: Vector2 = d.pos - Vector2(0, d.z + 2.0 + sin(time * 5.0 + d.pos.x) * 0.8)
	match d.kind:
		"spark":
			Art.glow(self, p, 6, Color(1, 0.55, 0.15, 0.6))
			Art.icon(self, "spark", p - Vector2(3, 3), 0.85, Color("ffb03a"))
		"gold":
			Art.glow(self, p, 6, Color(1, 0.8, 0.2, 0.35))
			Art.icon(self, "gold", p - Vector2(3, 3), 0.85, Art.GOLD)
		"gem":
			Art.glow(self, p, 7, Color(0.3, 0.7, 1, 0.5))
			Art.icon(self, "gem", p - Vector2(3.5, 3.5), 1.0, Art.GEM)
		_:
			var md: Dictionary = Gear.MATERIALS[d.kind.substr(4)]
			Art.icon(self, md.icon, p - Vector2(3.5, 3.5), 1.0, md.color)

# ---------------------------------------------------------------------
#  Personaggi
# ---------------------------------------------------------------------
func _enemy_color(e: Dictionary) -> Color:
	match e.k:
		"zombie": return Color("5e6a50")
		"archer": return Color("d6ccb4")
		"golem": return Color("6a6070")
		"pebble": return Color("7a7080")
		"imp": return Color("e0521a")
		"spitter": return Color("5a2a20")
		"miniboss": return Color("605868")
		"boss": return Color("3a1020")
	return Color.WHITE

func _gp(pts: Array, top: Color, bot: Color, w: float = 1.6) -> void:
	HeroArt._gpoly(self, pts, top, bot, w)

func _slit_eyes(c: Vector2, look: Vector2, sep: float, ln: float, col: Color) -> void:
	for sx in [-1.0, 1.0]:
		var ep := c + Vector2(sx * sep + look.x * 1.2, look.y * 0.8)
		Art.glow(self, ep, ln * 2.2, Color(col, 0.55))
		draw_line(ep - Vector2(ln * 0.5, -sx * ln * 0.18), ep + Vector2(ln * 0.5, sx * ln * 0.18), col, maxf(1.2, ln * 0.32), true)

## Nemici in stile "forgia oscura": niente occhioni, sagome adulte, crepe incandescenti
func _draw_enemy_body(e: Dictionary, bc: Vector2, r: float, col: Color, look: Vector2) -> void:
	var lx := look.x
	var pulse := 0.6 + 0.4 * sin(time * 4.0 + bc.x)
	match e.k:
		"zombie":
			var lean := Vector2(lx * 2.0, 0)
			for sx in [-1.0, 1.0]:
				var sh := bc + Vector2(sx * r * 0.55, -r * 0.25)
				var hand := sh + look * r * 0.9 + Vector2(sx * 2, 0)
				draw_line(sh, hand, OUT, 3.6, true)
				draw_line(sh, hand, col.lightened(0.15), 2.0, true)
				for f in 3:
					draw_line(hand, hand + (look.rotated((f - 1) * 0.4)) * 3.0, Color("c8c0a8"), 1.0, true)
			_gp([bc + Vector2(-r * 0.7, -r * 0.5) + lean, bc + Vector2(r * 0.7, -r * 0.5) + lean, bc + Vector2(r * 0.6, r * 0.6), bc + Vector2(r * 0.2, r * 0.45), bc + Vector2(-r * 0.1, r * 0.7), bc + Vector2(-r * 0.6, r * 0.55)], col.lightened(0.1), col.darkened(0.45))
			draw_line(bc + Vector2(-r * 0.4, 0), bc + Vector2(r * 0.3, r * 0.15), Color(0, 0, 0, 0.3), 1.0, true)
			var hc := bc + Vector2(lx * r * 0.25, -r * 0.75)
			_gp([hc + Vector2(-r * 0.42, -r * 0.3), hc + Vector2(0, -r * 0.5), hc + Vector2(r * 0.42, -r * 0.3), hc + Vector2(r * 0.36, r * 0.32), hc + Vector2(-r * 0.36, r * 0.32)], Color("9aa088"), Color("5a6050"), 1.4)
			_slit_eyes(hc, look, r * 0.17, r * 0.22, Color("ffa040"))
			draw_line(hc + Vector2(-r * 0.2, r * 0.22), hc + Vector2(r * 0.2, r * 0.22), OUT, 1.2, true)
		"archer":
			var hood := bc + Vector2(0, -r * 0.55)
			_gp([hood + Vector2(-r * 0.62, r * 0.4), hood + Vector2(-r * 0.5, -r * 0.45), hood + Vector2(0, -r * 0.75), hood + Vector2(r * 0.5, -r * 0.45), hood + Vector2(r * 0.62, r * 0.4)], Color("3a3040"), Color("1a1420"), 1.4)
			draw_line(bc + Vector2(0, -r * 0.1), bc + Vector2(0, r * 0.7), OUT, 2.6, true)
			draw_line(bc + Vector2(0, -r * 0.1), bc + Vector2(0, r * 0.7), col, 1.4, true)
			for i in 3:
				var ry := -r * 0.05 + i * r * 0.22
				draw_arc(bc + Vector2(0, ry), r * (0.45 - i * 0.06), PI * 0.15, PI * 0.85, 8, OUT, 2.4, true)
				draw_arc(bc + Vector2(0, ry), r * (0.45 - i * 0.06), PI * 0.15, PI * 0.85, 8, col, 1.2, true)
			var sk := hood + Vector2(lx * 1.5, r * 0.05)
			_gp([sk + Vector2(-r * 0.36, -r * 0.2), sk + Vector2(0, -r * 0.42), sk + Vector2(r * 0.36, -r * 0.2), sk + Vector2(r * 0.3, r * 0.22), sk + Vector2(r * 0.12, r * 0.38), sk + Vector2(-r * 0.12, r * 0.38), sk + Vector2(-r * 0.3, r * 0.22)], col.lightened(0.1), col.darkened(0.25), 1.3)
			for sx in [-1.0, 1.0]:
				draw_circle(sk + Vector2(sx * r * 0.15, 0), r * 0.11, OUT)
				Art.glow(self, sk + Vector2(sx * r * 0.15, 0), r * 0.3, Color(1, 0.2, 0.15, 0.7))
				draw_circle(sk + Vector2(sx * r * 0.15, 0), r * 0.045, Color("ff4a3a"))
			var bp := bc + look * r * 0.85
			draw_arc(bp, r * 0.75, look.angle() - 1.2, look.angle() + 1.2, 12, OUT, 3.2, true)
			draw_arc(bp, r * 0.75, look.angle() - 1.2, look.angle() + 1.2, 12, Color("5a3a24"), 1.8, true)
		"golem", "miniboss":
			var big: bool = e.k == "miniboss"
			for sx in [-1.0, 1.0]:
				var fist := bc + Vector2(sx * r * 0.95, r * 0.15) + look * r * 0.15
				_gp([fist + Vector2(-r * 0.25, -r * 0.25), fist + Vector2(r * 0.25, -r * 0.25), fist + Vector2(r * 0.3, r * 0.22), fist + Vector2(-r * 0.3, r * 0.22)], col.lightened(0.15), col.darkened(0.4))
			var body := [bc + Vector2(-r * 0.8, -r * 0.55), bc + Vector2(-r * 0.35, -r * 0.9), bc + Vector2(r * 0.4, -r * 0.88), bc + Vector2(r * 0.82, -r * 0.5), bc + Vector2(r * 0.75, r * 0.55), bc + Vector2(r * 0.2, r * 0.8), bc + Vector2(-r * 0.55, r * 0.7)]
			_gp(body, col.lightened(0.22), col.darkened(0.45), 2.0)
			var lava := Color(1, 0.45, 0.1, pulse)
			Art.glow(self, bc + Vector2(0, r * 0.1), r * 1.1, Color(1, 0.4, 0.1, 0.25 * pulse))
			draw_polyline(PackedVector2Array([bc + Vector2(-r * 0.5, -r * 0.4), bc + Vector2(-r * 0.15, 0), bc + Vector2(-r * 0.35, r * 0.45)]), lava, 1.4, true)
			draw_polyline(PackedVector2Array([bc + Vector2(r * 0.3, -r * 0.6), bc + Vector2(r * 0.1, -r * 0.15), bc + Vector2(r * 0.45, r * 0.3)]), lava, 1.4, true)
			var hc := bc + Vector2(lx * r * 0.15, -r * 0.45)
			draw_rect(Rect2(hc - Vector2(r * 0.32, r * 0.1), Vector2(r * 0.64, r * 0.2)), OUT)
			Art.glow(self, hc, r * 0.55, Color(1, 0.7, 0.2, 0.8))
			draw_line(hc - Vector2(r * 0.25, 0), hc + Vector2(r * 0.25, 0), Color("ffd060"), 1.6, true)
			if big:
				for i in 4:
					var sp := bc + Vector2(-r * 0.55 + i * r * 0.37, -r * 0.85)
					_gp([sp + Vector2(-r * 0.1, 0), sp + Vector2(0, -r * 0.35), sp + Vector2(r * 0.1, 0)], Color("6a6474"), Color("2a2630"), 1.2)
		"pebble":
			var core := bc + Vector2(0, -r * 0.2)
			Art.glow(self, core, r * 1.2, Color(1, 0.5, 0.15, 0.4 * pulse))
			for i in 3:
				var aa := time * 1.6 + i * TAU / 3.0
				var sp := core + Vector2(cos(aa) * r * 0.55, sin(aa) * r * 0.3)
				_gp([sp + Vector2(-r * 0.32, -r * 0.1), sp + Vector2(-r * 0.05, -r * 0.4), sp + Vector2(r * 0.3, -r * 0.15), sp + Vector2(r * 0.2, r * 0.3), sp + Vector2(-r * 0.25, r * 0.25)], col.lightened(0.25), col.darkened(0.4), 1.4)
			draw_circle(core, r * 0.26, OUT)
			draw_circle(core, r * 0.2, Color("ffb040"))
			draw_circle(core + look * r * 0.06, r * 0.09, Color("fff0c0"))
		"imp":
			var fl := sin(time * 14.0 + bc.y) * 1.5
			Art.glow(self, bc, r * 2.0, Color(1, 0.4, 0.1, 0.35))
			for sx in [-1.0, 1.0]:
				var wb := bc + Vector2(sx * r * 0.4, -r * 0.2)
				var flap := sin(time * 18.0) * r * 0.2
				_gp([wb, wb + Vector2(sx * r * 1.2, -r * 0.7 - flap), wb + Vector2(sx * r * 1.0, -r * 0.1), wb + Vector2(sx * r * 1.15, r * 0.25 - flap * 0.5), wb + Vector2(sx * r * 0.3, r * 0.3)], Color("5a1a14"), Color("2a0a08"), 1.2)
			_gp([bc + Vector2(-r * 0.6, -r * 0.1), bc + Vector2(-r * 0.3, -r * 0.75), bc + Vector2(0, -r * 0.55 + fl), bc + Vector2(r * 0.3, -r * 0.75), bc + Vector2(r * 0.6, -r * 0.1), bc + Vector2(r * 0.35, r * 0.6), bc + Vector2(0, r * 0.85 + fl), bc + Vector2(-r * 0.35, r * 0.6)], Color("ffb040"), Color("b0300c"), 1.6)
			for sx in [-1.0, 1.0]:
				_gp([bc + Vector2(sx * r * 0.25, -r * 0.6), bc + Vector2(sx * r * 0.6, -r * 1.15), bc + Vector2(sx * r * 0.42, -r * 0.5)], Color("e8dcc8"), Color("6a5a48"), 1.0)
			_slit_eyes(bc + Vector2(0, -r * 0.2), look, r * 0.2, r * 0.26, Color("fff060"))
		"spitter":
			var body := [bc + Vector2(-r * 0.95, r * 0.4), bc + Vector2(-r * 0.75, -r * 0.35), bc + Vector2(-r * 0.2, -r * 0.65), bc + Vector2(r * 0.25, -r * 0.65), bc + Vector2(r * 0.78, -r * 0.35), bc + Vector2(r * 0.95, r * 0.4), bc + Vector2(r * 0.4, r * 0.7), bc + Vector2(-r * 0.4, r * 0.7)]
			_gp(body, col.lightened(0.2), col.darkened(0.5), 1.8)
			for i in 4:
				var cp := bc + Vector2(-r * 0.55 + i * r * 0.36, -r * 0.2 + (i % 2) * r * 0.25)
				Art.glow(self, cp, r * 0.3, Color(1, 0.45, 0.1, 0.5 * pulse))
				draw_circle(cp, r * 0.08, Color(1, 0.6, 0.2, pulse))
			var mouth := bc + Vector2(0, r * 0.25) + look * r * 0.25
			Art.glow(self, mouth, r * 0.9, Color(1, 0.5, 0.1, 0.6))
			HeroArt.ellipse(self, mouth, r * 0.42, r * 0.18, OUT)
			HeroArt.ellipse(self, mouth, r * 0.34, r * 0.12, Color("ffb040"))
			_slit_eyes(bc + Vector2(0, -r * 0.4), look, r * 0.35, r * 0.2, Color("ffe060"))
		"boss":
			var crown_col := Color("ff7a2a") if e.phase == 1 else Color("ffd84a")
			Art.glow(self, bc, r * 2.4, Color(crown_col, 0.25 + 0.1 * pulse))
			var robe := [bc + Vector2(-r * 0.55, -r * 0.5), bc + Vector2(r * 0.55, -r * 0.5), bc + Vector2(r * 0.9, r * 0.75), bc + Vector2(r * 0.55, r * 0.6), bc + Vector2(r * 0.3, r * 0.85), bc + Vector2(0, r * 0.65), bc + Vector2(-r * 0.3, r * 0.85), bc + Vector2(-r * 0.55, r * 0.6), bc + Vector2(-r * 0.9, r * 0.75)]
			_gp(robe, Color("5a1828"), Color("14060c"), 2.0)
			for sx in [-1.0, 1.0]:
				var sh := bc + Vector2(sx * r * 0.55, -r * 0.35)
				var hand := sh + Vector2(sx * r * 0.35, r * 0.35) + look * r * 0.2
				draw_line(sh, hand, OUT, 4.5, true)
				draw_line(sh, hand, Color("3a1020"), 3.0, true)
				Art.glow(self, hand, r * 0.4, Color(crown_col, 0.6))
				draw_circle(hand, r * 0.1, crown_col)
			var hc := bc + Vector2(0, -r * 0.62)
			_gp([hc + Vector2(-r * 0.32, -r * 0.3), hc + Vector2(r * 0.32, -r * 0.3), hc + Vector2(r * 0.28, r * 0.15), hc + Vector2(0, r * 0.42), hc + Vector2(-r * 0.28, r * 0.15)], Color("e8dcc4"), Color("8a7c68"), 1.6)
			_slit_eyes(hc + Vector2(0, -r * 0.05), look, r * 0.13, r * 0.16, crown_col)
			var pts: Array = [hc + Vector2(-r * 0.4, -r * 0.25)]
			for i in 5:
				var x := -r * 0.4 + i * r * 0.2
				pts.append(hc + Vector2(x + r * 0.1, -r * (0.75 + (0.25 if i % 2 == 0 else 0.05)) - sin(time * 9.0 + i) * 2.5))
				pts.append(hc + Vector2(x + r * 0.2, -r * 0.4))
			pts.append(hc + Vector2(r * 0.4, -r * 0.25))
			_poly(pts, crown_col)

func _draw_enemy_telegraph(e: Dictionary) -> void:
	if e.spawn > 0.0:
		var k: float = 1.0 - e.spawn / 0.8
		draw_circle(e.pos, e.size * 0.6, Color(1, 0.3, 0.35, 0.12 + 0.15 * k))
		draw_arc(e.pos, e.size * (1.2 - 0.5 * k), 0, TAU, 28, Color(1, 0.35, 0.4, 0.8), 1.5, true)
		return
	if e.dead_t > 0.0:
		return
	var blink := 0.35 + 0.35 * (1 if fmod(time * 10.0, 2.0) < 1.0 else 0)
	var wc := Color(1, 0.25, 0.3)
	match e.st:
		"aim", "charge_aim":
			var a: float = e.aim
			if e.kind == "spread":
				for k in [-0.35, 0.0, 0.35]:
					draw_line(e.pos, e.pos + Vector2.from_angle(a + k) * 150, Color(wc, blink), 1.5, true)
			elif e.st == "charge_aim":
				draw_line(e.pos, e.pos + Vector2.from_angle(a) * 140, Color(wc, blink * 0.45), e.size * 0.8, true)
			else:
				var k: float = clampf(1.0 - e.t / 0.75, 0.0, 1.0)
				var dv := Vector2.from_angle(a)
				draw_line(e.pos, e.pos + dv * 160, Color(wc, 0.25), 3.0, true)
				draw_line(e.pos, e.pos + dv * 160 * k, Color(wc, 0.9), 1.5, true)
			PixelFont.draw_centered(self, "!", e.pos.x, e.pos.y - e.size / 2.0 - 22, 2, Color("ff3d5a"), OUT)
		"throw":
			for k in 5:
				draw_line(e.pos, e.pos + Vector2.from_angle(e.aim + (k - 2) * 0.28) * 120, Color(wc, blink * 0.8), 1.5, true)
		"slam":
			var r: float = 44.0 if not e.boss else 64.0
			var k: float = 1.0 - e.t / 0.9
			draw_circle(e.pos, r, Color(1, 0.2, 0.25, 0.12 + 0.18 * k))
			draw_circle(e.pos, r * k, Color(1, 0.2, 0.25, 0.2))
			draw_arc(e.pos, r, 0, TAU, 40, Color(wc, 0.9), 2.0, true)
		"ring", "aimed", "spiral":
			Art.glow(self, e.pos, e.size * 1.6, Color(1, 0.3, 0.3, blink * 0.8))

func _eyes(c: Vector2, look: Vector2, sep: float, r: float, pupil: Color = OUT, white: Color = Color.WHITE) -> void:
	for sx in [-1.0, 1.0]:
		var ep := c + Vector2(sx * sep, 0)
		draw_circle(ep, r + 0.8, OUT)
		draw_circle(ep, r, white)
		draw_circle(ep + look * r * 0.45, r * 0.55, pupil)

func _body(c: Vector2, r: float, col: Color, squash: float = 1.0) -> void:
	# corpo tondo con contorno, ombra e riflesso (come gli slime di Braceforte 2)
	_xf(c, 0, Vector2(1.0 / squash, squash))
	draw_circle(Vector2.ZERO, r + 1.6, OUT)
	draw_circle(Vector2.ZERO, r, col)
	draw_circle(Vector2(0, r * 0.25), r * 0.8, col.darkened(0.12))
	draw_circle(Vector2(0, -r * 0.08), r * 0.78, col)
	draw_circle(Vector2(-r * 0.38, -r * 0.42), r * 0.22, Color(1, 1, 1, 0.45))
	_xr()

func _draw_enemy(e: Dictionary) -> void:
	if e.spawn > 0.0:
		return
	var sz: float = e.size
	var r := sz / 2.0 + 1.0
	var c: Vector2 = e.pos
	var col := _enemy_color(e)
	var look: Vector2 = (hero_pos - c).normalized()
	# ombra
	_xf(c + Vector2(0, r * 0.85), 0, Vector2(1, 0.38))
	draw_circle(Vector2.ZERO, r * 0.95, Color(0, 0, 0, 0.32))
	_xr()
	if e.get("elite", false):
		_xf(c + Vector2(0, r * 0.85), 0, Vector2(1, 0.4))
		for i in 6:
			var aa := time * 2.0 + i * TAU / 6.0
			draw_arc(Vector2.ZERO, r + 5, aa, aa + 0.6, 6, Color(1, 0.8, 0.25, 0.9), 2.0, true)
		_xr()
	if e.dead_t > 0.0:
		# a terra: si sta per rialzare
		_body(c + Vector2(0, r * 0.4), r * 0.8, col.darkened(0.3), 0.55)
		if fmod(time * 6.0, 2.0) < 1.0:
			PixelFont.draw_centered(self, "!", c.x, c.y - r - 8, 2, Color("ff3d5a"), OUT)
		return
	var moving: bool = e.vel.length() > 3.0
	var bob: float = absf(sin(time * 9.0 + c.x)) * -2.0 if moving else sin(time * 4.0 + c.x) * 0.8
	var squash: float = 1.0 + sin(time * 7.0 + c.y) * 0.05 - e.flash * 0.18
	var bc := c + Vector2(0, bob)
	# piedi che camminano
	if e.k in ["zombie", "archer", "golem", "miniboss"]:
		var fc := col.darkened(0.55)
		var stp: float = sin(time * 12.0 + c.x) * (r * 0.22 if moving else 0.0)
		for sx in [-1.0, 1.0]:
			var fp := c + Vector2(sx * r * 0.42, r * 0.8 + stp * sx)
			HeroArt.ellipse(self, fp, r * 0.3 + 1.2, r * 0.2 + 1.2, OUT)
			HeroArt.ellipse(self, fp, r * 0.3, r * 0.2, fc)
	_draw_enemy_body(e, bc, r, col, look)
	if e.flash > 0.0:
		HeroArt.ellipse(self, bc, r * 1.05, r * 1.1, Color(1, 1, 1, minf(0.85, e.flash)))
	# stati
	if e.slow > 0.0 or e.freeze > 0.0:
		if e.freeze > 0.0:
			Art.rbox(self, Rect2(bc - Vector2(r + 3, r + 3), Vector2(r * 2 + 6, r * 2 + 6)), Color(0.6, 0.9, 1.0, 0.45), Color(0.85, 0.97, 1, 0.9), 4, 1)
		else:
			draw_arc(bc, r + 3, 0, TAU, 24, Color(0.45, 0.85, 1.0, 0.8), 1.5, true)
	if e.burn > 0.0:
		for i in 2:
			var fp := bc + Vector2(sin(time * 5.0 + i * 3.0) * r * 0.5, -r * 0.6 - fmod(time * 14.0 + i * 5.0, 6.0))
			draw_circle(fp, 1.6, Color("ffb03a"))
	if e.pois > 0:
		for i in mini(e.pois, 5):
			var bp := bc + Vector2(-r * 0.6 + i * r * 0.3, -r - 2 - fmod(time * 6.0 + i * 1.7, 4.0))
			draw_circle(bp, 1.3, Data.EL_COLOR.poison)
	if e.inv > 0.0 and fmod(time * 10.0, 2.0) < 1.0:
		draw_circle(bc, r + 2, Color(1, 1, 0.6, 0.35))
	# vita e debolezza
	if not e.boss:
		var bw := maxf(sz + 4, 18.0)
		var by := bc.y - r - 7
		if e.hp < e.max:
			Art.rbox(self, Rect2(c.x - bw / 2.0, by, bw, 4), Color("2a1020"), OUT, 2, 1)
			Art.rbox(self, Rect2(c.x - bw / 2.0 + 1, by + 1, (bw - 2) * clampf(e.hp / e.max, 0.0, 1.0), 2), Color("ffc531") if e.get("elite", false) else Color("ff3d5a"), Color(0, 0, 0, 0), 1)
		Art.el_badge(self, _weak_of(e), Vector2(c.x, by - 7), 4.5)

## Il Fabbro delle Ceneri (disegno condiviso con menu e titolo)
func _draw_hero() -> void:
	var blink := hero_inv > 0.0 and fmod(time * 16.0, 2.0) < 1.0
	var moving := hero_vel.length() > 5.0
	var wc := _shot_color(_w())
	if _w().slots != ["", ""]:
		Art.glow(self, hero_pos + Vector2(0, -4), 28, Color(wc, 0.2))
	if blink:
		HeroArt.ellipse(self, hero_pos + Vector2(0, 9.5), 9.5, 3.4, Color(0, 0, 0, 0.42))
	else:
		HeroArt.draw(self, hero_pos + Vector2(0, 9), facing, time, step_t * 1.6, moving, _w().key, wc, recoil, 1.0, hero_flash)
	# barra della vita sopra l'eroe
	var p := hero_pos
	var bw := 30.0
	var by := p.y - 40
	var hk := float(hero_hp) / max_hp
	var hcol := Art.GREEN if hk > 0.5 else (Color("e8c04a") if hk > 0.25 else Art.HP)
	Art.bar(self, Rect2(p.x - bw / 2.0, by, bw, 3.5), hk, hcol)
	PixelFont.draw_centered(self, str(hero_hp), p.x, by - 11, 1, Art.TEXT, OUT)

func _draw_shot(s: Dictionary) -> void:
	var col: Color = s.col
	var dir: Vector2 = s.vel.normalized()
	if s.w != "sword":
		# scia luminosa
		var tl: float = minf(s.vel.length() * 0.06, 18.0)
		draw_line(s.pos - dir * tl, s.pos, Color(col, 0.0), s.size * 1.4, true)
		for i in 3:
			var k := (i + 1) / 3.0
			draw_line(s.pos - dir * tl * k, s.pos - dir * tl * (k - 0.34), Color(col, 0.45 * (1.0 - k) + 0.1), maxf(1.0, s.size * (1.6 - k)), true)
	match s.w:
		"sword":
			var a := dir.angle()
			Art.glow(self, s.pos, 12, Color(col, 0.45))
			var pts := PackedVector2Array()
			for i in 9:
				var t := -1.1 + 2.2 * i / 8.0
				pts.append(s.pos + Vector2.from_angle(a + t) * 9.0)
			for i in range(8, -1, -1):
				var t := -1.0 + 2.0 * i / 8.0
				pts.append(s.pos - dir * 3 + Vector2.from_angle(a + t) * 6.0)
			draw_colored_polygon(pts, Color(col.lightened(0.3), 0.9))
			draw_arc(s.pos, 9.0, a - 1.0, a + 1.0, 10, Color.WHITE, 1.2, true)
		"bow":
			Art.glow(self, s.pos, 7, Color(col, 0.5))
			draw_line(s.pos - dir * 9, s.pos, OUT, 3.0, true)
			draw_line(s.pos - dir * 9, s.pos, Color("c8a070"), 1.5, true)
			_poly([s.pos + dir * 3, s.pos - dir * 1 + dir.orthogonal() * 2.5, s.pos - dir * 1 - dir.orthogonal() * 2.5], col)
		"spirit":
			Art.glow(self, s.pos, 9, Color(1, 0.5, 0.15, 0.6))
			draw_circle(s.pos, 3.5, OUT)
			draw_circle(s.pos, 2.6, Color("ffb03a"))
			draw_circle(s.pos - dir * 3, 1.6, Color(1, 0.6, 0.2, 0.6))
		"staff":
			Art.glow(self, s.pos, 14, Color(col, 0.6))
			draw_circle(s.pos, s.size + 1.5, OUT)
			draw_circle(s.pos, s.size, col)
			draw_circle(s.pos - Vector2(1.5, 1.5), 1.8, Color(1, 1, 1, 0.9))

func _draw_bolt(a: Vector2, b: Vector2) -> void:
	var col: Color = Data.EL_COLOR.thunder
	var pts := PackedVector2Array([a])
	for i in range(1, 5):
		pts.append(a.lerp(b, i / 5.0) + (b - a).orthogonal().normalized() * randf_range(-5, 5))
	pts.append(b)
	draw_polyline(pts, Color(col, 0.4), 4.0, true)
	draw_polyline(pts, Color.WHITE, 1.2, true)

# ---------------------------------------------------------------------
#  Interfaccia
# ---------------------------------------------------------------------
func _draw_hud() -> void:
	var s := _size()
	Art.grad_poly(self, PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, HUD_H), Vector2(0, HUD_H)]), Color("1c1a22"), Color("0e0c12"))
	draw_line(Vector2(0, HUD_H - 1), Vector2(s.x, HUD_H - 1), Color("4a4450"), 1.0)
	draw_line(Vector2(0, HUD_H), Vector2(s.x, HUD_H), Art.INK, 1.0)
	var title := "Stanza %d/%d" % [room_n, Data.ROOMS]
	if room_n == Data.BOSS_ROOM:
		title = "Boss · %d/%d" % [room_n, Data.ROOMS]
	elif room_n == Data.MINIBOSS_ROOM:
		title = "Mini-boss · %d/%d" % [room_n, Data.ROOMS]
	elif room_n in Data.BIG_FORGE_ROOMS:
		title += " · Fucina"
	PixelFont.draw_text(self, title, Vector2(7, 3), 2, Art.TEXT, OUT)
	# livello: rombo con numero, barra dell'esperienza
	var lc := Vector2(16, 27)
	var dia := PackedVector2Array([lc + Vector2(0, -8), lc + Vector2(9, 0), lc + Vector2(0, 8), lc + Vector2(-9, 0)])
	Art.grad_poly(self, dia, Color("5fe0a0"), Color("1f7a50"))
	Art.outline(self, dia, Art.INK, 2.0)
	PixelFont.draw_centered(self, str(lvl), lc.x, lc.y - 5, 1, Art.INK)
	var xk := clampf(float(xp) / Skills.xp_need(lvl), 0.0, 1.0)
	Art.bar(self, Rect2(28, 25, s.x - 36, 4), xk, Color("5fe0a0"))
	# risorse della partita
	var x := s.x - 28
	for item in [["gem", run_gems, Art.GEM], ["gold", run_gold, Art.GOLD], ["spark", sparks, Color("ff9a3a")]]:
		var t := str(item[1])
		var w := 18.0 + PixelFont.text_width(t, 1)
		x -= w
		Art.icon(self, item[0], Vector2(x, 6), 1.4, item[2])
		PixelFont.draw_text(self, t, Vector2(x + 12, 6), 1, Art.TEXT, OUT)
		x -= 3
	var pr := _pause_rect()
	Art.plate(self, pr, Color("2e2a36"), Color("16131a"), Color("57525f"), 4.0)
	draw_rect(Rect2(pr.position.x + 6, pr.position.y + 5, 2.2, 8), Art.TEXT)
	draw_rect(Rect2(pr.position.x + 10, pr.position.y + 5, 2.2, 8), Art.TEXT)
	# barra del boss: lunga, ornata
	for e in enemies:
		if e.boss and e.spawn <= 0.0:
			var r := Rect2(30, HUD_H + 10, s.x - 60, 7)
			var k: float = clampf(e.hp / e.max, 0, 1)
			var frame := Art.cut_pts(r.grow(3), 4)
			draw_colored_polygon(frame, Color(0, 0, 0, 0.7))
			Art.outline(self, frame, Art.GOLD.darkened(0.3), 1.0)
			Art.bar(self, r, k, Color("c02a2a").lerp(Color("ff7a2a"), 1.0 - k))
			var label: String = PixelFont.nice(e.name) if e.name != "" else ""
			if e.k == "boss":
				label += " · fase %d" % e.phase
			PixelFont.draw_centered(self, label, s.x / 2.0, r.end.y + 5, 1, Art.GOLD_L, OUT)
			var weak := _weak_of(e)
			Art.el_badge(self, weak if e.weak_known else "?", Vector2(r.end.x + 14, r.get_center().y), 7)
			break

## Barra in basso: le due armi come lastre di ferro, e il pulsante Cambia
func _draw_bar() -> void:
	var s := _size()
	var y0 := s.y - BAR_H
	Art.grad_poly(self, PackedVector2Array([Vector2(0, y0), Vector2(s.x, y0), Vector2(s.x, s.y), Vector2(0, s.y)]), Color("1c1a22"), Color("09080c"))
	draw_line(Vector2(0, y0), Vector2(s.x, y0), Art.INK, 1.0)
	draw_line(Vector2(0, y0 + 1), Vector2(s.x, y0 + 1), Color("4a4450"), 1.0)
	for i in weapons.size():
		var w: Dictionary = weapons[i]
		var wd: Dictionary = Data.WEAPONS[w.key]
		var r := Rect2(6 + i * 79, y0 + 7, 75, BAR_H - 14)
		var cur := i == cur_w
		if cur:
			Art.glow(self, r.get_center(), 50, Color(1, 0.55, 0.2, 0.15))
		Art.plate(self, r, Color("3a3442") if cur else Color("221e28"), Color("17141b") if cur else Color("100e13"), Art.GOLD if cur else Color("3a3640"), 6.0)
		Art.icon(self, w.key, r.position + Vector2(6, 6), 2.0, wd.color if cur else Color("6e6874"))
		PixelFont.draw_text(self, wd.name, r.position + Vector2(25, 5), 1, Art.TEXT if cur else Color("8a8490"))
		for si in 2:
			var sr := Rect2(r.position.x + 25 + si * 16, r.position.y + 17, 14, 14)
			var sp := Art.cut_pts(sr, 3)
			draw_colored_polygon(sp, Color(0, 0, 0, 0.55))
			Art.outline(self, sp, Color("57525f") if cur else Color("3a3640"), 1.0)
			var el: String = w.slots[si]
			if el != "":
				Art.glow(self, sr.get_center(), 8, Color(Data.EL_COLOR[el], 0.4))
				Art.el_icon(self, el, sr.position + Vector2(2.6, 2.6), 1.25)
	var sr := _switch_rect()
	var ready := switch_t <= 0.0
	if ready:
		Art.glow(self, sr.get_center(), 60, Color(1, 0.5, 0.15, 0.16 + 0.08 * sin(time * 4.0)))
	Art.button(self, sr, "", Art.MOLTEN if ready else Color("3a3440"), true)
	var other: Dictionary = weapons[1 - cur_w] if weapons.size() > 1 else weapons[0]
	Art.icon(self, other.key, sr.position + Vector2(8, 10), 2.6, Art.TEXT)
	PixelFont.draw_text(self, "Cambia", sr.position + Vector2(36, 6), 2, Art.TEXT, Color(0, 0, 0, 0.5))
	PixelFont.draw_text(self, "Colpo critico" if ready else Data.WEAPONS[other.key].name, sr.position + Vector2(36, 24), 1, Color("ffe0b0") if ready else Art.TEXT_DIM)
	if not ready:
		var k := switch_t / Data.SWITCH_COOLDOWN
		draw_colored_polygon(Art.cut_pts(Rect2(sr.position, Vector2(maxf(8.0, sr.size.x * k), sr.size.y)), 5), Color(0, 0, 0, 0.5))

func _draw_banner() -> void:
	var s := _size()
	if banner_t > 0.0 and not (intro_t > 0.0 and room_n == 1) and boss_card_t <= 0.0:
		var a := clampf(banner_t * 2.0, 0.0, 1.0)
		var y := HUD_H + 34
		var t := PixelFont.nice(banner)
		var w := PixelFont.text_width(t, 2) + 34
		var sc := 1.0 + maxf(0.0, banner_t - 1.8) * 2.5
		draw_set_transform(Vector2(s.x / 2.0, y + 8), 0, Vector2(sc, sc))
		# nastro con le code
		_poly([Vector2(-w / 2.0 - 12, -8), Vector2(-w / 2.0, -8), Vector2(-w / 2.0, 14), Vector2(-w / 2.0 - 12, 14), Vector2(-w / 2.0 - 6, 3)], Color(0.42, 0.09, 0.13, a))
		_poly([Vector2(w / 2.0 + 12, -8), Vector2(w / 2.0, -8), Vector2(w / 2.0, 14), Vector2(w / 2.0 + 12, 14), Vector2(w / 2.0 + 6, 3)], Color(0.42, 0.09, 0.13, a))
		Art.plate(self, Rect2(-w / 2.0, -14, w, 28), Color(0.16, 0.13, 0.17, 0.95 * a), Color(0.06, 0.05, 0.07, 0.95 * a), Color(Art.GOLD, a), 6.0)
		PixelFont.draw_centered(self, t, 0, -8, 2, Color(1, 1, 1, a), Color(OUT, a))
		draw_set_transform(Vector2.ZERO)
	var by := s.y - BAR_H
	if room_n == 1 and time < 9.0 and time > 2.8 and state == St.PLAY:
		PixelFont.draw_centered(self, "Trascina per muoverti", s.x / 2.0, by - 50, 2, Color.WHITE, OUT)
		PixelFont.draw_centered(self, "Fermati per attaccare", s.x / 2.0, by - 32, 2, Color("ffd36b"), OUT)
	if state == St.CLEAR and not anvil.is_empty() and not anvil_lock and room_n <= 2:
		PixelFont.draw_centered(self, "Vai all'incudine o esci dal cancello", s.x / 2.0, by - 22, 1, Color.WHITE, OUT)

## Carta in stile Braceforte 2
func _card(r: Rect2, edge: Color = Color("8e8898")) -> void:
	Art.plate(self, r, Color("26222c"), Color("121016"), edge, 8.0, true)

func _draw_forge() -> void:
	var s := _size()
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.02, 0.01, 0.06, 0.72))
	var pr := Rect2(8, 40, s.x - 16, 344)
	_card(pr, Color("ffb03a"))
	PixelFont.draw_centered(self, "Fucina grande" if forge_big else "Incudine", s.x / 2.0, pr.position.y + 8, 3, Color("ffc94a"), OUT)
	var pt := "Prezzo %d" % _price()
	Art.counter(self, "spark", sparks, Vector2(pr.position.x + 12, pr.position.y + 40), Color("ffb03a"))
	var ptw := PixelFont.text_width(pt, 1)
	Art.icon(self, "spark", Vector2(pr.end.x - ptw - 26, pr.position.y + 39), 1.5, Color("ffb03a"))
	PixelFont.draw_text(self, pt, Vector2(pr.end.x - ptw - 12, pr.position.y + 40), 1, Color.WHITE)
	var n := offers.size()
	var gap := 5.0
	var cw := (pr.size.x - 20 - gap * (n - 1)) / n
	var y := pr.position.y + 58
	for i in n:
		var o: Dictionary = offers[i]
		var r := Rect2(pr.position.x + 10 + i * (cw + gap), y, cw, 62)
		ui_rects["offer%d" % i] = r
		var el: String = o.el
		var col: Color = Data.EL_COLOR[el]
		var can: bool = sparks >= _price() and not o.sold
		var sel := i == sel_offer
		Art.rbox(self, r, Color("1e1b24"), Art.GOLD if sel else Color(col, 0.6 if can else 0.25), 10, 3 if sel else 2)
		if o.sold:
			PixelFont.draw_centered(self, "Preso", r.get_center().x, r.get_center().y - 5, 1, Art.TEXT_DIM)
			continue
		Art.glow(self, r.get_center() - Vector2(0, 8), 18, Color(col, 0.35 if can else 0.1))
		var k := 3.0 if cw > 50 else 2.6
		Art.el_icon(self, el, Vector2(r.get_center().x - 3.5 * k, r.position.y + 9), k)
		PixelFont.draw_centered(self, Data.EL_NAME[el], r.get_center().x, r.position.y + 42, 1, Color.WHITE if can else Art.TEXT_DIM)
		if not can:
			Art.rbox(self, r, Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 10)
	var dy := y + 72
	if sel_offer != -1:
		var el: String = offers[sel_offer].el
		PixelFont.draw_centered(self, Data.EL_NAME[el] + ": " + Data.EL_DESC[el], s.x / 2.0, dy, 1, Data.EL_COLOR[el])
	else:
		PixelFont.draw_centered(self, "2 uguali = effetto pieno · 2 diversi = combinazione", s.x / 2.0, dy, 1, Art.TEXT_DIM)
	var wy := dy + 16
	for wi in weapons.size():
		var w: Dictionary = weapons[wi]
		var wd: Dictionary = Data.WEAPONS[w.key]
		var r := Rect2(pr.position.x + 10, wy + wi * 64, pr.size.x - 20, 58)
		Art.rbox(self, r, Color("17141b"), Color(1, 1, 1, 0.1), 10, 1)
		Art.icon(self, w.key, r.position + Vector2(8, 8), 2.6, wd.color)
		PixelFont.draw_text(self, wd.name, r.position + Vector2(6, 32), 1, Color.WHITE)
		for si in 2:
			var sr := Rect2(r.position.x + 56 + si * 34, r.position.y + 9, 30, 30)
			ui_rects["slot%d%d" % [wi, si]] = sr
			var hl := sel_offer != -1
			var pulse := 0.5 + 0.5 * sin(time * 6.0)
			Art.rbox(self, sr, Color(0, 0, 0, 0.45), Color(1, 0.83, 0.42, 0.4 + 0.6 * pulse) if hl else Color(1, 1, 1, 0.15), 8, 2)
			var el: String = w.slots[si]
			if el != "":
				Art.glow(self, sr.get_center(), 14, Color(Data.EL_COLOR[el], 0.35))
				Art.el_icon(self, el, sr.position + Vector2(5, 5), 2.9)
			else:
				PixelFont.draw_centered(self, "+", sr.get_center().x, sr.position.y + 6, 2, Color(1, 1, 1, 0.3))
		var info := Data.slots_info(w.slots, Save.recipes)
		var tx := r.position.x + 128
		var ny := _wrap_text(info[0], Vector2(tx, r.position.y + 6), r.end.x - tx - 4, _shot_color(w) if w.slots != ["", ""] else Art.TEXT_DIM)
		_wrap_text(info[1], Vector2(tx, ny + 2), r.end.x - tx - 4, Art.TEXT_DIM)
		PixelFont.draw_text(self, _weak_hint(w.slots), Vector2(r.position.x + 56, r.position.y + 43), 1, Color("ffd36b"))
	var my := wy + 130
	PixelFont.draw_centered(self, forge_msg, s.x / 2.0, my, 1, Color("ffd36b"))
	var by := pr.end.y - 34
	if forge_big:
		PixelFont.draw_centered(self, "Tocca un incastro pieno per toglierlo (torna metà prezzo)", s.x / 2.0, by - 14, 1, Art.TEXT_DIM)
		var rr := Rect2(pr.position.x + 10, by, 120, 26)
		ui_rects["reroll"] = rr
		Art.button(self, rr, "Cambia (%d)" % Data.REROLL_PRICE, Art.STEEL, sparks >= Data.REROLL_PRICE)
		var er := Rect2(pr.end.x - 10 - 100, by, 100, 26)
		ui_rects["exit"] = er
		Art.button(self, er, "Esci", Color("1fa65a"))
	else:
		var er := Rect2(s.x / 2.0 - 60, by, 120, 26)
		ui_rects["exit"] = er
		Art.button(self, er, "Esci", Color("1fa65a"))

## Colpo di martello: tocca quando il segno è al centro
func _strike_pos() -> float:
	return absf(fmod(float(strike.t) * 1.7, 2.0) - 1.0)

func _resolve_strike() -> void:
	if strike.is_empty():
		return
	var d := absf(_strike_pos() - 0.5)
	var price: int = strike.price
	var col: Color = Data.EL_COLOR[strike.el]
	if strike.t > 2.6:
		d = 1.0
	if d < 0.08:
		var back := price / 2
		sparks += back
		forge_msg = "COLPO PERFETTO! +%d SCINTILLE" % back
		Sfx.play("clang", 0.0, 4.0)
		shake = maxf(shake, 1.4)
		_burst(anvil.pos, Color("ffe14a"), 30)
	elif d < 0.2:
		var back := price / 5
		sparks += back
		forge_msg = "BUON COLPO: +%d SCINTILLE" % back
		Sfx.play("clang", 0.05)
		shake = maxf(shake, 0.7)
	else:
		forge_msg = "COLPO STORTO: NESSUN RIMBORSO"
		Sfx.play("hit", 0.0)
	_burst(anvil.pos, col, 12)
	strike = {}

func _draw_strike() -> void:
	var s := _size()
	var r := Rect2(16, s.y * 0.6, s.x - 32, 104)
	draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.35))
	_card(r, Color("ffe14a"))
	PixelFont.draw_centered(self, "Colpisci al momento giusto!", s.x / 2.0, r.position.y + 10, 2, Color("ffd36b"), OUT)
	PixelFont.draw_centered(self, "Tocca quando il martello è nell'oro", s.x / 2.0, r.position.y + 28, 1, Art.TEXT_DIM)
	var bar := Rect2(r.position.x + 16, r.position.y + 64, r.size.x - 32, 14)
	Art.rbox(self, bar, Color("17141b"), OUT, 7, 2)
	var good := Rect2(bar.position.x + bar.size.x * 0.3, bar.position.y + 2, bar.size.x * 0.4, bar.size.y - 4)
	Art.rbox(self, good, Color("8a5a20"), Color(0, 0, 0, 0), 5)
	var perf := Rect2(bar.position.x + bar.size.x * 0.42, bar.position.y + 1, bar.size.x * 0.16, bar.size.y - 2)
	Art.glow(self, perf.get_center(), 22, Color(1, 0.8, 0.2, 0.5))
	Art.rbox(self, perf, Color("ffd24a"), Color(0, 0, 0, 0), 5)
	var mx := bar.position.x + bar.size.x * _strike_pos()
	draw_line(Vector2(mx, bar.position.y - 6), Vector2(mx, bar.end.y + 6), OUT, 5.0, true)
	draw_line(Vector2(mx, bar.position.y - 6), Vector2(mx, bar.end.y + 6), Color.WHITE, 2.5, true)
	Art.icon(self, "anvil", Vector2(mx - 7, bar.position.y - 22), 2.0, Color("d8dcef"))
	var left := maxf(0.0, 2.6 - float(strike.t))
	Art.rbox(self, Rect2(bar.position.x, bar.end.y + 10, bar.size.x * left / 2.6, 3), Color(1, 1, 1, 0.4), Color(0, 0, 0, 0), 2)

func _weak_hint(slots: Array) -> String:
	var parts_txt: Array = []
	for fam in Data.FAMILIES:
		var m := Data.element_mult(slots, fam)
		if m >= 1.4:
			parts_txt.append("Forte contro " + PixelFont.nice(Data.FAMILIES[fam].short))
	return parts_txt[0] if not parts_txt.is_empty() else ""

func _wrap_text(t: String, pos: Vector2, max_w: float, col: Color) -> float:
	var words := PixelFont.nice(t).split(" ")
	var line := ""
	var y := pos.y
	for wd in words:
		var test := wd if line == "" else line + " " + wd
		if PixelFont.text_width(test, 1) > max_w and line != "":
			PixelFont.draw_text(self, line, Vector2(pos.x, y), 1, col)
			y += 11
			line = wd
		else:
			line = test
	if line != "":
		PixelFont.draw_text(self, line, Vector2(pos.x, y), 1, col)
		y += 11
	return y

func _draw_pause() -> void:
	var s := _size()
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.02, 0.015, 0.02, 0.8))
	var pr := Rect2(18, s.y * 0.16, s.x - 36, 328)
	Art.plate(self, pr, Color("221e27"), Color("0f0d12"), Art.PANEL_EDGE, 10.0, true)
	PixelFont.draw_custom(self, "cinzel", "PAUSA", s.x / 2.0, pr.position.y + 14, 30, Art.GOLD, Art.INK, 4)
	draw_line(Vector2(pr.position.x + 30, pr.position.y + 54), Vector2(pr.end.x - 30, pr.position.y + 54), Color(Art.GOLD, 0.35), 1.0)
	var y := pr.position.y + 64
	PixelFont.draw_centered(self, "Capitolo 1 · stanza %d di %d" % [room_n, Data.ROOMS], s.x / 2.0, y, 1, Art.TEXT)
	_draw_map(Vector2(pr.position.x + 18, y + 26), pr.size.x - 36)
	y += 50
	Art.header(self, "Abilità · livello %d" % lvl, s.x / 2.0, y, pr.size.x - 40)
	if skills.is_empty():
		PixelFont.draw_centered(self, "Nessuna: sali di livello sconfiggendo nemici", s.x / 2.0, y + 22, 1, Art.TEXT_DIM)
	else:
		_draw_skill_row(y + 30)
	y += 58
	var r1 := Rect2(s.x / 2.0 - 84, y, 168, 40)
	var r2 := Rect2(s.x / 2.0 - 84, y + 50, 168, 30)
	var sr := Rect2(s.x / 2.0 - 84, y + 88, 168, 26)
	ui_rects["resume"] = r1
	ui_rects["quit"] = r2
	ui_rects["sound"] = sr
	Art.button(self, r1, "Riprendi", Art.MOLTEN, true, 2)
	Art.button(self, r2, "Abbandona", Art.STEEL, true, 1)
	Art.button(self, sr, "Suoni: sì" if Save.sound else "Suoni: no", Color("3d8a5a") if Save.sound else Art.IRON_L, true, 1)
	PixelFont.draw_centered(self, "Abbandonando tieni una parte del bottino", s.x / 2.0, sr.end.y + 10, 1, Art.TEXT_DIM)

func _draw_end() -> void:
	if end_t < 0.8:
		return
	var s := _size()
	var a := clampf((end_t - 0.8) * 3.0, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.02, 0.015, 0.02, 0.85 * a))
	var win := state == St.WIN
	var y := s.y * 0.08
	var tc: Color = Art.GOLD if win else Color("d8343e")
	Art.glow(self, Vector2(s.x / 2.0, y + 22), 120, Color(tc, 0.25 * a))
	PixelFont.draw_custom(self, "cinzel", "VITTORIA" if win else "SCONFITTA", s.x / 2.0, y, 34, Color(tc.lightened(0.15), a), Color(Art.INK, a), 5)
	var sub := ("La Fonderia caduta · capitolo completato · livello %d" % lvl) if win else "Stanza %d di %d · livello %d" % [room_n, Data.ROOMS, lvl]
	PixelFont.draw_centered(self, sub, s.x / 2.0, y + 44, 1, Color(Art.TEXT_DIM, a))
	var pr := Rect2(18, y + 62, s.x - 36, 156)
	Art.plate(self, pr, Color("221e27"), Color("0f0d12"), Art.GOLD if win else Art.PANEL_EDGE, 8.0, true)
	Art.header(self, "Bottino", s.x / 2.0, pr.position.y + 8, pr.size.x - 40)
	var lx := pr.position.x + 14
	var ly := pr.position.y + 28
	var lines := [
		["gold", "Oro raccolto", str(end_info.gold), Art.GOLD],
		["spark", "Scintille non spese: %d" % end_info.sparks, "+%d oro" % end_info.spark_gold, Art.MOLTEN_L],
		["gem", "Gemme raccolte", str(end_info.gems), Art.GEM],
	]
	for l in lines:
		Art.icon(self, l[0], Vector2(lx, ly), 1.5, l[3])
		PixelFont.draw_text(self, l[1], Vector2(lx + 16, ly), 1, Art.TEXT)
		var vw := PixelFont.text_width(l[2], 1)
		PixelFont.draw_text(self, l[2], Vector2(pr.end.x - 14 - vw, ly), 1, l[3])
		ly += 16
	var mx := lx
	for m in ["bone", "stone", "ember"]:
		var md: Dictionary = Gear.MATERIALS[m]
		Art.icon(self, md.icon, Vector2(mx, ly), 1.5, md.color)
		PixelFont.draw_text(self, "+%d %s" % [end_info.mats.get(m, 0), PixelFont.nice(md.name)], Vector2(mx + 15, ly), 1, Art.TEXT)
		mx += 74
	ly += 18
	draw_line(Vector2(pr.position.x + 20, ly - 3), Vector2(pr.end.x - 20, ly - 3), Color(Art.STEEL, 0.4), 1.0)
	var pct := "Tieni il %d%% del bottino" % int(round(end_info.frac * 100))
	PixelFont.draw_centered(self, pct, s.x / 2.0, ly + 2, 1, Art.TEXT_DIM if not win else Art.GREEN)
	ly += 16
	var tot := "+%d oro   +%d gemme" % [end_info.gold_kept, end_info.gems_kept]
	PixelFont.draw_centered(self, tot, s.x / 2.0, ly, 3, Art.GOLD_L, OUT)
	var by := pr.end.y + 12
	if not run_items.is_empty():
		PixelFont.draw_centered(self, "Bottino dei boss", s.x / 2.0, by, 1, Art.MOLTEN_L)
		var bx := s.x / 2.0 - (run_items.size() * 38 - 4) / 2.0
		for i in run_items.size():
			Art.item_box(self, run_items[i], Rect2(bx + i * 38, by + 14, 34, 34))
		by += 56
	var r1 := Rect2(s.x / 2.0 - 92, by + 6, 184, 42)
	var r2 := Rect2(s.x / 2.0 - 72, by + 58, 144, 30)
	ui_rects["again"] = r1
	ui_rects["home"] = r2
	Art.button(self, r1, "Rigioca", Art.MOLTEN, true, 2)
	Art.button(self, r2, "Campo base", Art.STEEL, true, 1)

var _dbg_t := 0.0
func _autotest_step() -> void:
	if time - _dbg_t > 10.0:
		_dbg_t = time
		print("T ", int(time), " lv ", lvl, " room ", room_n, " st ", state, " en ", enemies.size(), " wave ", wave_idx, "/", waves.size(), " shots ", shots.size())
	if not "--mortal" in OS.get_cmdline_user_args():
		hero_hp = max_hp
	if state == St.PLAY:
		auto_target = null
		auto_forged = false
		if int(time * 10) % 50 == 0:
			_try_switch()
	elif state == St.CLEAR:
		if not drops.is_empty():
			auto_target = null
		elif not auto_forged and not anvil.is_empty():
			auto_target = anvil.pos
		else:
			auto_target = Vector2(_room_rect().get_center().x, _room_rect().position.y - 20)
	elif state == St.FORGE:
		auto_target = null
		for i in offers.size():
			if not offers[i].sold and sparks >= _price():
				_ui_action("offer%d" % i)
				_ui_action("slot%d%d" % [purchases % 2, (purchases / 2) % 2])
				strike.t = randf() * 1.2
				_resolve_strike()
		if forge_big:
			_ui_action("reroll")
			_ui_action("slot00")
		print("FORGE room ", room_n, " sparks ", sparks, " weapons ", weapons)
		auto_forged = true
		_ui_action("exit")
	elif state == St.LEVEL:
		if lvl_t > 0.4:
			var pick := randi() % level_choices.size()
			print("LEVEL ", lvl, " room ", room_n, " pick ", level_choices[pick])
			_ui_action("skill%d" % pick)
	elif state == St.DEAD or state == St.WIN:
		if end_t > 1.0:
			print("END ", "WIN" if state == St.WIN else "DEAD", " room ", room_n, " info ", end_info, " t=", time)
			get_tree().quit()
