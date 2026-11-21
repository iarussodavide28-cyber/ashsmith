extends Node2D
## La partita: un capitolo di 12 stanze con forgia, nemici, mini-boss e boss.
## Tutto è disegnato in pixel art col codice (segnaposto finché non arriva la grafica vera).

enum St { PLAY, CLEAR, FORGE, PAUSE, DEAD, WIN }

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
const HUD_H := 30.0
const BAR_H := 52.0
const HERO_SIZE := 19
const HERO_SPEED := 95.0
const ACCEL := 900.0
const FRICTION := 1100.0
const JOY_RADIUS := 28.0
const BASE_HP := 120

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
	_start_room()
	_debug_params()

## Solo per le prove: ?room=7&sparks=200 nell'indirizzo salta a una stanza
func _debug_params() -> void:
	if not OS.has_feature("web"):
		return
	var q = JavaScriptBridge.eval("window.location.search", true)
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
		elif kv[0] == "forge" and not anvil.is_empty():
			_open_forge()

# =====================================================================
#  Spazio di gioco
# =====================================================================
func _size() -> Vector2:
	return get_viewport_rect().size

func _room_rect() -> Rect2:
	var s := _size()
	return Rect2(WALL_SIZE, HUD_H + TOP_WALL, s.x - WALL_SIZE * 2, s.y - HUD_H - BAR_H - TOP_WALL - WALL_SIZE)

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
		_banner("MINI-BOSS: GOLEM ANTICO")
	elif room_n == Data.BOSS_ROOM:
		waves = [["boss"]]
		_banner("BOSS: SIGNORE DELLA CENERE")
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
		if p.distance_to(hero_pos) > 90 and not _in_rock(p) and _push_out(p, 14) == p:
			return p
	return Vector2(r.get_center().x, r.position.y + 40)

func _spawn_enemy(k: String, p: Vector2) -> Dictionary:
	var e := {
		"k": k, "pos": p, "vel": Vector2.ZERO, "spawn": 0.8, "flash": 0.0,
		"burn": 0.0, "burn_dps": 0.0, "slow": 0.0, "slow_amt": 0.0, "freeze": 0.0, "ice_hits": 0,
		"pois": 0, "pois_t": 0.0, "pois_dps": 0.0, "t": randf_range(1.2, 2.2), "st": "move",
		"aim": 0.0, "revived": false, "dead_t": 0.0, "patch_t": 0.0, "inv": 0.0, "tick": 0.0,
		"boss": false, "weak_known": false, "phase": 1, "summon_t": 6.0,
	}
	if k == "miniboss":
		e.merge({"fam": "golem", "hp": 760.0, "speed": 18.0, "size": 40, "dmg": 26, "sparks": 40, "kind": "slammer", "boss": true, "name": "GOLEM ANTICO"}, true)
		e.weak_known = true
	elif k == "boss":
		e.merge({"fam": "boss", "hp": 1500.0, "speed": 24.0, "size": 46, "dmg": 18, "sparks": 0, "kind": "boss", "boss": true, "name": "SIGNORE DELLA CENERE"}, true)
		e.spawn = 1.4
	else:
		var d: Dictionary = Data.ENEMIES[k]
		e.merge(d.duplicate(), true)
		e.hp = d.hp * (1.0 + 0.07 * (room_n - 1))
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
			if state == St.FORGE or state == St.PAUSE or state == St.DEAD or state == St.WIN:
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
	_float(hero_pos + Vector2(0, -16), _wdata().name, Color.WHITE)

# =====================================================================
#  Aggiornamento
# =====================================================================
func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	time += dt
	shake = maxf(0.0, shake - dt * 8.0)
	banner_t -= dt
	if autotest:
		_autotest_step()
	if state == St.PLAY or state == St.CLEAR:
		_update_play(dt)
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
			var strength := clampf((off.length() - 3.0) / (JOY_RADIUS - 3.0), 0.0, 1.0)
			target = off.normalized() * HERO_SPEED * (1.0 + bonus.speed_pct) * maxf(strength, 0.35)
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

func _update_attack(dt: float) -> void:
	atk_t = maxf(0.0, atk_t - dt)
	var still := touch_index == -1 and auto_target == null and hero_vel.length() < 10.0
	if not still or atk_t > 0.0:
		return
	var tg = _nearest_visible(hero_pos)
	if tg == null:
		return
	var wd := _wdata()
	var dir: Vector2 = (tg.pos - hero_pos).normalized()
	facing = dir
	atk_t = wd.rate / (1.0 + bonus.aspd_pct)
	var w := _w()
	var col := _shot_color(w)
	var dmg: float = wd.dmg * (1.0 + bonus.weapon_atk[cur_w])
	var angles: Array = [0.0] if not bonus.double_shot[cur_w] else [-0.14, 0.14]
	for da in angles:
		var d2 := dir.rotated(da)
		var crit: bool = randf() < bonus.crit
		shots.append({
			"pos": hero_pos + d2 * 6, "vel": d2 * wd.speed, "life": wd.range / wd.speed,
			"dmg": dmg * (2.0 if crit else 1.0), "crit": crit, "w": w.key, "slots": w.slots.duplicate(), "size": wd.size,
			"area": wd.area, "hit": [], "col": col,
		})

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
				_hit_enemy(e, s.dmg, s.slots, true, s.crit)
				if s.area > 0.0:
					_explode(s.pos, s.area, s.dmg, s.slots, Color("c78cff"))
				if s.w != "sword":
					done = true
					break
		if not done and _in_rock(s.pos):
			if s.area > 0.0:
				_explode(s.pos, s.area, s.dmg, s.slots, Color("c78cff"))
			_burst(s.pos, Color("8a8a96"), 3)
			done = true
		if not _room_rect().grow(4).has_point(s.pos):
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
			_hit_enemy(e, dmg * 0.6, slots, false)

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

func _hit_enemy(e: Dictionary, base: float, slots: Array, primary: bool, crit: bool = false) -> void:
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
	_damage(e, dmg, col, slots)
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

func _damage(e: Dictionary, amount: float, col: Color, slots: Array = []) -> void:
	if e.dead_t > 0.0:
		return
	e.hp -= amount
	e.flash = 1.0
	if amount >= 1.0:
		_float(e.pos + Vector2(randf_range(-4, 4), -e.size / 2.0 - 4), str(int(round(amount))), col)
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
	shake = maxf(shake, 0.5 if not e.boss else 1.5)
	_burst(e.pos, _enemy_color(e), 10 if not e.boss else 40)
	# bottino
	var n: int = e.sparks + (1 if bonus.extra_spark else 0)
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
	drops.append({"kind": kind, "pos": p, "vel": Vector2(cos(a), sin(a)) * randf_range(30, 90), "t": 0.0})

# ---------------------------------------------------------------------
#  Nemici
# ---------------------------------------------------------------------
func _update_enemies(dt: float) -> void:
	for e in enemies:
		e.flash = maxf(0.0, e.flash - dt * 6.0)
		e.inv = maxf(0.0, e.inv - dt)
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
			_burst(e.pos, Color("8a7a6a"), 16)
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
	dmg = maxi(1, int(round(dmg * (1.0 - bonus.dmg_taken))))
	hero_hp -= dmg
	hero_inv = 0.8
	hero_flash = 1.0
	shake = maxf(shake, 1.0)
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
		var to: Vector2 = hero_pos - d.pos
		var magnet := state == St.CLEAR or to.length() < 26
		if magnet and d.t > 0.35:
			d.vel = d.vel.lerp(to.normalized() * 260.0, minf(1.0, dt * 8.0))
		else:
			d.vel = d.vel.move_toward(Vector2.ZERO, 200 * dt)
		d.pos += d.vel * dt
		if to.length() < 8 and d.t > 0.3:
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
		f.pos.y -= 18 * dt
		f.life -= dt
	floats = floats.filter(func(f): return f.life > 0.0)
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
	if room_n == Data.BOSS_ROOM:
		win_delay = 2.5      # il tempo di raccogliere il bottino del boss
		_banner("IL SIGNORE DELLA CENERE E SCONFITTO!")
		return
	var r := _room_rect()
	anvil = {"pos": Vector2(r.get_center().x, r.position.y + r.size.y * 0.38), "big": room_n in Data.BIG_FORGE_ROOMS}
	anvil_lock = false
	door_open = true
	_banner("STANZA LIBERA!" if not anvil.big else "FUCINA GRANDE!")
	forge_big = anvil.big
	_make_offers()

func _next_room() -> void:
	room_n += 1
	hero_hp = mini(max_hp, hero_hp + int(bonus.room_heal))   # piccola cura tra le stanze
	_start_room()

func _burst(p: Vector2, col: Color, n: int) -> void:
	for i in n:
		var a := randf() * TAU
		parts.append({"pos": p, "vel": Vector2(cos(a), sin(a)) * randf_range(30, 110), "life": randf_range(0.25, 0.6), "max": 0.6, "col": col, "size": 2 if randf() < 0.5 else 1})

func _float(p: Vector2, t: String, col: Color) -> void:
	floats.append({"pos": p, "txt": t, "col": col, "life": 0.7})

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
	for key in ui_rects:
		var r: Rect2 = ui_rects[key]
		if r.has_point(p):
			_ui_action(key)
			return

func _ui_action(key: String) -> void:
	if key == "resume":
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
	var gold_kept := int(round((run_gold + spark_gold) * frac))
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
		off = Vector2(randf_range(-2, 2), randf_range(-2, 2)) * shake
	draw_set_transform(off)
	_draw_room()
	_draw_ground()
	_draw_anvil()
	for d in drops:
		_draw_drop(d)
	for e in enemies:
		_draw_enemy_telegraph(e)
	_draw_rocks()
	# dall'alto in basso, così chi sta davanti copre chi sta dietro
	var actors: Array = enemies.duplicate()
	actors.sort_custom(func(a, b): return a.pos.y < b.pos.y)
	var hero_drawn := false
	for e in actors:
		if not hero_drawn and e.pos.y > hero_pos.y and state != St.DEAD:
			_draw_hero()
			hero_drawn = true
		_draw_enemy(e)
	if not hero_drawn and state != St.DEAD:
		_draw_hero()
	for sh in shots:
		_draw_shot(sh)
	for b in bullets:
		Art.glow(self, b.pos, b.r * 3.2, Color(b.col, 0.55))
		draw_circle(b.pos, b.r + 1.2, OUT)
		draw_circle(b.pos, b.r, b.col)
		draw_circle(b.pos - Vector2(b.r, b.r) * 0.3, b.r * 0.45, Color(1, 1, 1, 0.85))
	for b in bolts:
		_draw_bolt(b.a, b.b)
	for p in parts:
		var c: Color = p.col
		var a: float = clampf(p.life / p.max * 1.5, 0.0, 1.0)
		c.a = a
		draw_circle(p.pos, p.size * 0.9, c)
	for f in floats:
		var a: float = clampf(f.life * 2.5, 0.0, 1.0)
		var big: bool = f.get("big", false)
		PixelFont.draw_centered(self, f.txt, f.pos.x, f.pos.y - 6, 2 if big else 1, Color(f.col, a), Color(OUT, a))
	if touch_index != -1 and (state == St.PLAY or state == St.CLEAR):
		draw_circle(joy_origin, JOY_RADIUS, Color(1, 1, 1, 0.08))
		draw_arc(joy_origin, JOY_RADIUS, 0, TAU, 40, Color(1, 1, 1, 0.35), 1.5, true)
		var knob := joy_origin + (joy_current - joy_origin).limit_length(JOY_RADIUS)
		draw_circle(knob, 9, Color(1, 1, 1, 0.45))
	draw_set_transform(Vector2.ZERO)
	_draw_vignette()
	_draw_hud()
	_draw_bar()
	_draw_banner()
	match state:
		St.FORGE: _draw_forge()
		St.PAUSE: _draw_pause()
		St.DEAD, St.WIN: _draw_end()

# ---------------------------------------------------------------------
#  Stanza
# ---------------------------------------------------------------------
const TILE_A := Color("4a3c3a")
const TILE_B := Color("54443f")

func _draw_room() -> void:
	var s := _size()
	var r := _room_rect()
	draw_rect(Rect2(Vector2(-4, -4), s + Vector2(8, 8)), Color("0a0816"))
	var rng := RandomNumberGenerator.new()
	rng.seed = floor_seed
	var tint := Color(1, 1, 1)
	if room_n == Data.BOSS_ROOM:
		tint = Color(1.12, 0.86, 0.82)
	elif room_n == Data.MINIBOSS_ROOM:
		tint = Color(0.9, 0.95, 1.06)
	var ts := 19.25
	var cols := int(ceil(r.size.x / ts))
	var rows := int(ceil(r.size.y / ts))
	draw_rect(r, Color("2a201f") * tint)
	for y in rows:
		for x in cols:
			var base := TILE_A.lerp(TILE_B, rng.randf()) * tint
			var t := Rect2(r.position + Vector2(x * ts + 1, y * ts + 1), Vector2(ts - 2, ts - 2)).intersection(r)
			if t.size.x <= 0 or t.size.y <= 0:
				continue
			draw_rect(t, base)
			draw_rect(Rect2(t.position, Vector2(t.size.x, 1.5)), base.lightened(0.12))
			draw_rect(Rect2(t.position, Vector2(1.5, t.size.y)), base.lightened(0.06))
			draw_rect(Rect2(t.position + Vector2(0, t.size.y - 1.5), Vector2(t.size.x, 1.5)), base.darkened(0.2))
			var roll := rng.randf()
			if roll < 0.18:
				# crepa
				var a := t.position + Vector2(rng.randf_range(3, ts - 6), rng.randf_range(3, ts - 6))
				var b := a + Vector2(rng.randf_range(-5, 5), rng.randf_range(2, 6))
				var c := b + Vector2(rng.randf_range(-4, 4), rng.randf_range(1, 4))
				draw_polyline(PackedVector2Array([a, b, c]), base.darkened(0.45), 1.0, true)
			elif roll < 0.28:
				# cenere
				for i in 3:
					draw_circle(t.position + Vector2(rng.randf_range(3, ts - 4), rng.randf_range(3, ts - 4)), rng.randf_range(0.8, 1.6), Color(0.75, 0.7, 0.65, 0.18))
			elif roll < 0.31:
				# brace nel pavimento
				var p := t.position + Vector2(rng.randf_range(4, ts - 5), rng.randf_range(4, ts - 5))
				var fl := 0.6 + 0.4 * sin(time * 3.0 + p.x)
				Art.glow(self, p, 6, Color(1, 0.45, 0.1, 0.35 * fl))
				draw_line(p - Vector2(2, 1), p + Vector2(2, 1), Color(1, 0.55, 0.2, 0.8 * fl), 1.0, true)
	# muro in alto con mattoni
	var wall := Rect2(r.position.x - WALL_SIZE, r.position.y - TOP_WALL, r.size.x + WALL_SIZE * 2, TOP_WALL)
	draw_rect(wall, Color("3a2c2c"))
	var bh := TOP_WALL / 3.0
	for row in 3:
		var y0 := wall.position.y + row * bh
		var offx := 0.0 if row % 2 == 0 else 11.0
		var x := wall.position.x - offx
		while x < wall.end.x:
			var br := Rect2(x + 1, y0 + 1, 21, bh - 2).intersection(wall)
			if br.size.x > 0:
				draw_rect(br, Color("4e3b38").lerp(Color("5a4541"), rng.randf()))
				draw_rect(Rect2(br.position, Vector2(br.size.x, 1)), Color(1, 1, 1, 0.06))
			x += 22
	draw_rect(Rect2(wall.position.x, wall.end.y - 2, wall.size.x, 2), Color(0, 0, 0, 0.4))
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 6), Color(0, 0, 0, 0.18))
	# muri laterali e in basso
	draw_rect(Rect2(r.position.x - WALL_SIZE, r.position.y, WALL_SIZE, r.size.y + WALL_SIZE), Color("2e2323"))
	draw_rect(Rect2(r.end.x, r.position.y, WALL_SIZE, r.size.y + WALL_SIZE), Color("2e2323"))
	draw_rect(Rect2(r.position.x, r.end.y, r.size.x, WALL_SIZE), Color("2e2323"))
	draw_rect(Rect2(r.position.x - 1, r.position.y, 1, r.size.y), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(r.end.x, r.position.y, 1, r.size.y), Color(0, 0, 0, 0.5))
	# torce
	for f in [0.12, 0.32, 0.68, 0.88]:
		var tx: float = r.position.x + r.size.x * f
		var ty := wall.position.y + TOP_WALL * 0.45
		var fl := 0.8 + 0.2 * sin(time * 11.0 + tx)
		Art.glow(self, Vector2(tx, ty), 22 * fl, Color(1, 0.6, 0.25, 0.45))
		draw_rect(Rect2(tx - 1.5, ty, 3, 7), Color("6b3d22"))
		draw_circle(Vector2(tx, ty - 1), 3.0 * fl, Color("ff8a2b"))
		draw_circle(Vector2(tx, ty - 1.5), 1.6 * fl, Color("ffe14a"))
	# cancello
	var d := _door_rect()
	var gc := Vector2(d.get_center().x, d.position.y + 10)
	draw_circle(gc, 20, OUT)
	draw_circle(gc, 18, Color("3a2c2c"))
	draw_rect(Rect2(d.position.x - 2, gc.y, d.size.x + 4, d.end.y - gc.y), OUT)
	var inner := Rect2(d.position.x + 2, gc.y, d.size.x - 4, d.end.y - gc.y)
	draw_circle(gc, 15, Color("120a0a"))
	draw_rect(inner, Color("120a0a"))
	if door_open:
		Art.glow(self, Vector2(gc.x, d.end.y - 4), 26, Color(1, 0.6, 0.25, 0.5 + 0.2 * sin(time * 4.0)))
		var ay := r.position.y + 14 + 3 * sin(time * 6.0)
		_poly([Vector2(gc.x, ay - 6), Vector2(gc.x + 7, ay + 2), Vector2(gc.x - 7, ay + 2)], Color("ffe14a"))
	else:
		for i in 5:
			var bx := inner.position.x + 3 + i * (inner.size.x - 6) / 4.0
			draw_line(Vector2(bx, gc.y - 12 + absf(i - 2) * 2), Vector2(bx, d.end.y), Color("6a6070"), 2.0, true)
		draw_line(Vector2(inner.position.x, gc.y + 2), Vector2(inner.end.x, gc.y + 2), Color("6a6070"), 2.0, true)

func _poly(pts: Array, col: Color, outline: bool = true) -> void:
	var p := PackedVector2Array(pts)
	if outline:
		var q := p.duplicate()
		q.append(p[0])
		draw_polyline(q, OUT, 2.0, true)
	draw_colored_polygon(p, col)

func _draw_rocks() -> void:
	for o in obs:
		var rr: Rect2 = o
		Art.rbox(self, Rect2(rr.position + Vector2(3, 5), rr.size), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 6)
		Art.rbox(self, rr, Color("5a4a46"), OUT, 6, 2)
		Art.rbox(self, Rect2(rr.position + Vector2(2, 2), Vector2(rr.size.x - 4, rr.size.y * 0.55)), Color("6e5c56"), Color(0, 0, 0, 0), 5)
		var c := rr.get_center()
		draw_polyline(PackedVector2Array([c + Vector2(-3, -7), c + Vector2(1, -1), c + Vector2(-2, 4), c + Vector2(1, 8)]), Color("3a2c2a"), 1.2, true)

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
	draw_set_transform(p + Vector2(0, 0), 0, Vector2.ONE * (0.42 if not big else 0.55))
	# stessa incudine del titolo, più piccola
	draw_rect(Rect2(-26, 22, 52, 30), OUT)
	draw_rect(Rect2(-24, 24, 48, 26), Color("6b3d22"))
	var pts := [Vector2(-46, -4), Vector2(-30, -10), Vector2(30, -10), Vector2(34, -4), Vector2(34, 4), Vector2(16, 8), Vector2(20, 22), Vector2(-20, 22), Vector2(-16, 8), Vector2(-30, 4), Vector2(-46, 0)]
	_poly(pts, Color("5a5f7a"))
	draw_rect(Rect2(-30, -9, 62, 4), Color("8a90b0"))
	var hot := Color("ff7a1a").lerp(Color("ffe14a"), 0.5 + 0.3 * sin(time * 4.0))
	Art.rbox(self, Rect2(-26, -16, 44, 6), hot, OUT, 3, 2)
	draw_set_transform(Vector2.ZERO)
	var label := "Incudine" if not big else "Fucina grande"
	var y := p.y - 26 - 2 * sin(time * 3.0)
	var tw := PixelFont.text_width(label, 1) + 12
	Art.rbox(self, Rect2(p.x - tw / 2.0, y - 2, tw, 14), Color(0, 0, 0, 0.55), Color("ffc531"), 7, 1)
	PixelFont.draw_centered(self, label, p.x, y, 1, Color("ffd36b"))

func _draw_drop(d: Dictionary) -> void:
	var p: Vector2 = d.pos
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
		"zombie": return Color("8ab07a")
		"archer": return Color("f0ecdc")
		"golem": return Color("9a9aa8")
		"pebble": return Color("b0a898")
		"imp": return Color("ff6a2a")
		"spitter": return Color("d0402a")
		"miniboss": return Color("8a8a9a")
		"boss": return Color("5a2438")
	return Color.WHITE

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
				draw_line(e.pos, e.pos + Vector2.from_angle(a) * 160, Color(wc, blink), 1.5, true)
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
	draw_set_transform(c, 0, Vector2(1.0 / squash, squash))
	draw_circle(Vector2.ZERO, r + 1.6, OUT)
	draw_circle(Vector2.ZERO, r, col)
	draw_circle(Vector2(0, r * 0.25), r * 0.8, col.darkened(0.12))
	draw_circle(Vector2(0, -r * 0.08), r * 0.78, col)
	draw_circle(Vector2(-r * 0.38, -r * 0.42), r * 0.22, Color(1, 1, 1, 0.45))
	draw_set_transform(Vector2.ZERO)

func _draw_enemy(e: Dictionary) -> void:
	if e.spawn > 0.0:
		return
	var sz: float = e.size
	var r := sz / 2.0 + 1.0
	var c: Vector2 = e.pos
	var col := _enemy_color(e)
	var look: Vector2 = (hero_pos - c).normalized()
	# ombra
	draw_set_transform(c + Vector2(0, r * 0.85), 0, Vector2(1, 0.38))
	draw_circle(Vector2.ZERO, r * 0.95, Color(0, 0, 0, 0.32))
	draw_set_transform(Vector2.ZERO)
	if e.dead_t > 0.0:
		# a terra: si sta per rialzare
		_body(c + Vector2(0, r * 0.4), r * 0.8, col.darkened(0.3), 0.55)
		if fmod(time * 6.0, 2.0) < 1.0:
			PixelFont.draw_centered(self, "!", c.x, c.y - r - 8, 2, Color("ff3d5a"), OUT)
		return
	var bob := sin(time * 6.0 + c.x) * 1.0
	var squash := 1.0 + sin(time * 7.0 + c.y) * 0.05
	var bc := c + Vector2(0, bob)
	match e.k:
		"zombie":
			_body(bc, r, col, squash)
			draw_line(bc + Vector2(-r * 0.5, r * 0.45), bc + Vector2(r * 0.3, r * 0.55), OUT, 1.0, true)
			for i in 3:
				var x := -r * 0.35 + i * r * 0.3
				draw_line(bc + Vector2(x, r * 0.38), bc + Vector2(x, r * 0.62), OUT, 1.0, true)
			_eyes(bc + Vector2(0, -r * 0.15), look, r * 0.36, r * 0.26, Color("6a1a2a"), Color("e8f0c0"))
		"archer":
			# scheletro: teschio sopra, corpo stretto
			draw_rect(Rect2(bc.x - r * 0.45, bc.y + r * 0.1, r * 0.9, r * 0.9), OUT)
			draw_rect(Rect2(bc.x - r * 0.35, bc.y + r * 0.15, r * 0.7, r * 0.8), Color("d8d0b8"))
			for i in 2:
				draw_line(Vector2(bc.x - r * 0.3, bc.y + r * (0.4 + i * 0.25)), Vector2(bc.x + r * 0.3, bc.y + r * (0.4 + i * 0.25)), OUT, 1.0, true)
			_body(bc + Vector2(0, -r * 0.35), r * 0.75, col)
			_eyes(bc + Vector2(0, -r * 0.4), look * 0.4, r * 0.28, r * 0.2, Color("ff4a3a"), OUT)
			var bp := bc + look * r * 0.9
			draw_arc(bp, r * 0.7, look.angle() - 1.2, look.angle() + 1.2, 10, Color("8a6a40"), 2.0, true)
		"golem", "pebble", "miniboss":
			var rr := Rect2(bc - Vector2(r, r * 0.95), Vector2(r * 2, r * 1.9))
			Art.rbox(self, rr, col, OUT, int(r * 0.45), 2)
			Art.rbox(self, Rect2(rr.position + Vector2(2, 2), Vector2(rr.size.x - 4, rr.size.y * 0.45)), col.lightened(0.12), Color(0, 0, 0, 0), int(r * 0.4))
			draw_polyline(PackedVector2Array([bc + Vector2(-r * 0.5, r * 0.1), bc + Vector2(-r * 0.2, r * 0.4), bc + Vector2(-r * 0.4, r * 0.8)]), col.darkened(0.4), 1.2, true)
			draw_circle(bc + Vector2(r * 0.55, -r * 0.6), r * 0.18, Color("6a9a4a"))
			var ec := bc + Vector2(0, -r * 0.2) + look * r * 0.12
			for sx in [-1.0, 1.0]:
				Art.glow(self, ec + Vector2(sx * r * 0.38, 0), r * 0.5, Color(1, 0.85, 0.3, 0.7))
				draw_circle(ec + Vector2(sx * r * 0.38, 0), r * 0.13, Color("fff0a0"))
			if e.k == "miniboss":
				for i in 3:
					draw_circle(bc + Vector2(-r * 0.6 + i * r * 0.6, -r * 0.95), r * 0.14, Color("6a9a4a"))
		"imp":
			var fl := sin(time * 14.0 + c.y) * 1.5
			Art.glow(self, bc, r * 2.2, Color(1, 0.45, 0.1, 0.35))
			_poly([bc + Vector2(-r * 0.8, -r * 0.1), bc + Vector2(-r * 0.4, -r * 1.3 + fl), bc + Vector2(0, -r * 0.7), bc + Vector2(r * 0.4, -r * 1.5 - fl), bc + Vector2(r * 0.8, -r * 0.1)], Color("ffb03a"))
			_body(bc, r, col, squash)
			_eyes(bc + Vector2(0, -r * 0.05), look, r * 0.34, r * 0.24, OUT, Color("fff0b0"))
		"spitter":
			_body(bc, r, col, squash)
			draw_circle(bc + Vector2(0, r * 0.4) + look * 2, r * 0.3, OUT)
			draw_circle(bc + Vector2(0, r * 0.4) + look * 2, r * 0.18, Color("ff8a2b"))
			_eyes(bc + Vector2(0, -r * 0.25), look, r * 0.34, r * 0.22, OUT, Color("ffe0a0"))
		"boss":
			var glow_a := 0.35 + 0.15 * sin(time * 3.0)
			Art.glow(self, bc, r * 2.4, Color(1, 0.4, 0.15, glow_a) if e.phase == 1 else Color(1, 0.9, 0.3, glow_a))
			_body(bc, r, col, squash)
			# corona di fiamme
			var crown_col := Color("ff8a2b") if e.phase == 1 else Color("ffe14a")
			var pts: Array = [bc + Vector2(-r * 0.6, -r * 0.7)]
			for i in 5:
				var x := -r * 0.6 + i * r * 0.3
				pts.append(bc + Vector2(x + r * 0.15, -r * (1.25 + (0.25 if i % 2 == 0 else 0.0)) - sin(time * 9.0 + i) * 2.0))
				pts.append(bc + Vector2(x + r * 0.3, -r * 0.85))
			pts.append(bc + Vector2(r * 0.6, -r * 0.7))
			_poly(pts, crown_col)
			_eyes(bc + Vector2(0, -r * 0.05), look, r * 0.3, r * 0.2, Color("ff3a1a"), Color("ffe0c0"))
			draw_arc(bc + Vector2(0, r * 0.35), r * 0.3, 0.3, PI - 0.3, 10, OUT, 2.0, true)
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
	if e.flash > 0.0:
		draw_circle(bc, r + 1, Color(1, 1, 1, e.flash * 0.7))
	if e.inv > 0.0 and fmod(time * 10.0, 2.0) < 1.0:
		draw_circle(bc, r + 2, Color(1, 1, 0.6, 0.35))
	# vita e debolezza
	if not e.boss:
		var bw := maxf(sz + 4, 18.0)
		var by := bc.y - r - 7
		if e.hp < e.max:
			Art.rbox(self, Rect2(c.x - bw / 2.0, by, bw, 4), Color("2a1020"), OUT, 2, 1)
			Art.rbox(self, Rect2(c.x - bw / 2.0 + 1, by + 1, (bw - 2) * clampf(e.hp / e.max, 0.0, 1.0), 2), Color("ff3d5a"), Color(0, 0, 0, 0), 1)
		Art.el_badge(self, _weak_of(e), Vector2(c.x, by - 7), 4.5)

func _draw_hero() -> void:
	var half := HERO_SIZE / 2.0
	var blink := hero_inv > 0.0 and fmod(time * 16.0, 2.0) < 1.0
	var moving := hero_vel.length() > 5.0
	var bob := absf(sin(step_t * 1.6)) * 2.0 if moving else sin(time * 3.0) * 0.6
	var c := hero_pos + Vector2(0, -bob)
	var r := half + 1.5
	# ombra
	draw_set_transform(hero_pos + Vector2(0, r * 0.9), 0, Vector2(1, 0.38))
	draw_circle(Vector2.ZERO, r, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)
	if blink:
		return
	var wc := _shot_color(_w())
	if _w().slots != ["", ""]:
		Art.glow(self, c, r * 2.2, Color(wc, 0.25))
	# corpo (armatura scura)
	draw_circle(c + Vector2(0, 2), r + 1.6, OUT)
	draw_circle(c + Vector2(0, 2), r, Color("3d3a5c"))
	draw_circle(c + Vector2(0, 4), r * 0.55, Color("2a2844"))
	draw_circle(c + Vector2(0, r * 0.5 + 2), 1.6, Art.GOLD)
	# casco
	var hc := c + Vector2(0, -r * 0.35)
	draw_circle(hc, r * 0.82 + 1.6, OUT)
	draw_circle(hc, r * 0.82, Color("5a5f7a"))
	draw_circle(hc + Vector2(-r * 0.25, -r * 0.3), r * 0.25, Color(1, 1, 1, 0.35))
	# visiera con occhi che guardano dove va
	var vf := facing * Vector2(2.0, 1.0)
	Art.rbox(self, Rect2(hc.x - r * 0.6 + vf.x, hc.y - 1 + maxf(vf.y, -1), r * 1.2, 4), OUT, Color(0, 0, 0, 0), 2)
	draw_circle(hc + Vector2(-2.2 + vf.x, 1 + maxf(vf.y, -1)), 0.9, Color("ffd36b"))
	draw_circle(hc + Vector2(2.2 + vf.x, 1 + maxf(vf.y, -1)), 0.9, Color("ffd36b"))
	# pennacchio di fiamma
	var fl := sin(time * 10.0) * 1.0
	_poly([hc + Vector2(-1.5, -r * 0.75), hc + Vector2(1, -r * 1.55 + fl), hc + Vector2(4.5, -r * 1.1 - fl), hc + Vector2(2.5, -r * 0.7)], Color("ff5a2a"))
	# arma in mano
	var hand := c + facing * (r + 2) + Vector2(0, 2)
	var a := facing.angle()
	match _w().key:
		"sword":
			var tip := hand + facing * 10
			draw_line(hand, tip, OUT, 4.0, true)
			draw_line(hand, tip, Color("e8ecf8"), 2.0, true)
			draw_line(hand - facing.orthogonal() * 3, hand + facing.orthogonal() * 3, Color("8a6a40"), 2.0, true)
			if wc != Data.WEAPONS.sword.color:
				draw_line(hand + facing * 3, tip, Color(wc, 0.8), 1.0, true)
		"bow":
			draw_arc(hand, 6, a - 1.3, a + 1.3, 10, OUT, 3.5, true)
			draw_arc(hand, 6, a - 1.3, a + 1.3, 10, Color("c8a070"), 2.0, true)
			draw_line(hand + Vector2.from_angle(a - 1.3) * 6, hand + Vector2.from_angle(a + 1.3) * 6, Color(1, 1, 1, 0.7), 1.0, true)
		"staff":
			var top := hand + Vector2(facing.x * 4, -8)
			draw_line(hand + Vector2(0, 5), top, OUT, 3.5, true)
			draw_line(hand + Vector2(0, 5), top, Color("8a6a40"), 2.0, true)
			Art.glow(self, top, 7, Color(wc, 0.7))
			draw_circle(top, 2.6, OUT)
			draw_circle(top, 2.0, wc)
	if hero_flash > 0.0:
		draw_circle(c, r + 2, Color(1, 0.2, 0.2, hero_flash * 0.55))
	# barra della vita sopra l'eroe (come Braceforte 2)
	var bw := 30.0
	var by := c.y - r - 16
	Art.rbox(self, Rect2(hero_pos.x - bw / 2.0, by, bw, 5), Color("10201a"), OUT, 3, 1)
	Art.rbox(self, Rect2(hero_pos.x - bw / 2.0 + 1, by + 1, (bw - 2) * float(hero_hp) / max_hp, 3), Art.GREEN, Color(0, 0, 0, 0), 2)
	PixelFont.draw_centered(self, str(hero_hp), hero_pos.x, by - 11, 1, Color.WHITE, OUT)

func _draw_shot(s: Dictionary) -> void:
	var col: Color = s.col
	var dir: Vector2 = s.vel.normalized()
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
	draw_rect(Rect2(0, 0, s.x, HUD_H), Color("140f2a"))
	var title := "Stanza %d/%d" % [room_n, Data.ROOMS]
	if room_n == Data.BOSS_ROOM:
		title += " · Boss"
	elif room_n == Data.MINIBOSS_ROOM:
		title += " · Mini-boss"
	elif room_n in Data.BIG_FORGE_ROOMS:
		title += " · Fucina"
	PixelFont.draw_text(self, title, Vector2(6, 4), 2, Color.WHITE, OUT)
	# barra di avanzamento del capitolo
	Art.rbox(self, Rect2(6, 23, s.x - 12, 4), Color(1, 1, 1, 0.08), Color(0, 0, 0, 0), 2)
	Art.rbox(self, Rect2(6, 23, (s.x - 12) * float(room_n - 1) / Data.ROOMS, 4), Color("5ab4ff"), Color(0, 0, 0, 0), 2)
	# monete a destra
	var x := s.x - 30
	for item in [["gem", run_gems, Art.GEM], ["gold", run_gold, Art.GOLD], ["spark", sparks, Color("ffb03a")]]:
		var t := str(item[1])
		var w := 18.0 + PixelFont.text_width(t, 1)
		x -= w
		Art.icon(self, item[0], Vector2(x, 6), 1.4, item[2])
		PixelFont.draw_text(self, t, Vector2(x + 12, 6), 1, Color.WHITE, OUT)
		x -= 2
	var pr := _pause_rect()
	Art.rbox(self, pr, Color(0, 0, 0, 0.35), Color(1, 1, 1, 0.15), 5, 1)
	draw_rect(Rect2(pr.position.x + 6, pr.position.y + 5, 2.5, 8), Color.WHITE)
	draw_rect(Rect2(pr.position.x + 10, pr.position.y + 5, 2.5, 8), Color.WHITE)
	# barra del boss
	for e in enemies:
		if e.boss and e.spawn <= 0.0:
			var r := Rect2(24, HUD_H + TOP_WALL + 6, s.x - 48, 7)
			Art.rbox(self, r.grow(1), Color("1a0c18"), OUT, 4, 1)
			var k: float = clampf(e.hp / e.max, 0, 1)
			Art.rbox(self, Rect2(r.position, Vector2(r.size.x * k, r.size.y)), Color("ff3d5a").lerp(Color("ffb03a"), 1.0 - k), Color(0, 0, 0, 0), 3)
			var label: String = e.name.capitalize() if e.name != "" else ""
			if e.k == "boss":
				label += " · Fase %d" % e.phase
			PixelFont.draw_centered(self, label, s.x / 2.0, r.end.y + 3, 1, Color.WHITE, OUT)
			var weak := _weak_of(e)
			Art.el_badge(self, weak if e.weak_known else "?", Vector2(r.end.x + 8, r.get_center().y), 6)
			break

func _draw_bar() -> void:
	var s := _size()
	var y0 := s.y - BAR_H
	draw_rect(Rect2(0, y0, s.x, BAR_H), Color("140f2a"))
	draw_rect(Rect2(0, y0, s.x, 1), Color(1, 1, 1, 0.08))
	for i in weapons.size():
		var w: Dictionary = weapons[i]
		var wd: Dictionary = Data.WEAPONS[w.key]
		var r := Rect2(6 + i * 79, y0 + 6, 75, BAR_H - 12)
		var cur := i == cur_w
		Art.rbox(self, r, Color("3d2d78") if cur else Color("1b1535"), Color("ffd36b") if cur else Color(1, 1, 1, 0.1), 8, 2 if cur else 1)
		Art.icon(self, w.key, r.position + Vector2(5, 5), 2.0, wd.color if cur else Art.TEXT_DIM)
		PixelFont.draw_text(self, wd.name, r.position + Vector2(24, 4), 1, Color.WHITE if cur else Art.TEXT_DIM)
		for si in 2:
			var sr := Rect2(r.position.x + 24 + si * 15, r.position.y + 16, 13, 13)
			Art.rbox(self, sr, Color(0, 0, 0, 0.4), Color(1, 1, 1, 0.12), 4, 1)
			var el: String = w.slots[si]
			if el != "":
				Art.el_icon(self, el, sr.position + Vector2(2.3, 2.3), 1.2)
		if w.slots[0] != "" and w.slots[1] != "":
			var info := Data.slots_info(w.slots, Save.recipes)
			var nm: String = PixelFont.nice(info[0])
			if PixelFont.text_width(nm, 1) > r.size.x - 8:
				nm = nm.substr(0, 10) + "."
			PixelFont.draw_text(self, nm, r.position + Vector2(5, r.size.y - 11), 1, _shot_color(w))
	var sr := _switch_rect()
	var ready := switch_t <= 0.0
	Art.button(self, sr, "", Color("7d6bff") if ready else Color("3a3070"), true)
	var other: Dictionary = weapons[1 - cur_w] if weapons.size() > 1 else weapons[0]
	Art.icon(self, other.key, sr.position + Vector2(8, 10), 2.8, Color.WHITE)
	PixelFont.draw_text(self, "Cambia", sr.position + Vector2(38, 8), 2, Color.WHITE, Color(0, 0, 0, 0.3))
	PixelFont.draw_text(self, Data.WEAPONS[other.key].name, sr.position + Vector2(38, 24), 1, Color("e0d8ff"))
	if not ready:
		var k := switch_t / Data.SWITCH_COOLDOWN
		Art.rbox(self, Rect2(sr.position, Vector2(sr.size.x * k, sr.size.y)), Color(0, 0, 0, 0.45), Color(0, 0, 0, 0), 8)

func _draw_banner() -> void:
	var s := _size()
	if banner_t > 0.0:
		var a := clampf(banner_t * 2.0, 0.0, 1.0)
		var y := HUD_H + TOP_WALL + 30
		var t := PixelFont.nice(banner)
		var w := PixelFont.text_width(t, 2) + 28
		Art.rbox(self, Rect2(s.x / 2.0 - w / 2.0, y - 6, w, 28), Color(0.08, 0.06, 0.16, 0.85 * a), Color(1, 0.83, 0.42, a), 9, 2)
		PixelFont.draw_centered(self, t, s.x / 2.0, y, 2, Color(1, 1, 1, a))
	var r := _room_rect()
	if room_n == 1 and time < 7.0 and state == St.PLAY:
		PixelFont.draw_centered(self, "Trascina per muoverti", s.x / 2.0, r.end.y - 44, 2, Color.WHITE, OUT)
		PixelFont.draw_centered(self, "Fermati per attaccare", s.x / 2.0, r.end.y - 26, 2, Color("ffd36b"), OUT)
	if state == St.CLEAR and not anvil.is_empty() and not anvil_lock and room_n <= 2:
		PixelFont.draw_centered(self, "Vai all'incudine o esci dal cancello", s.x / 2.0, r.end.y - 24, 1, Color.WHITE, OUT)

## Carta in stile Braceforte 2
func _card(r: Rect2, edge: Color = Color("a6a0c0")) -> void:
	Art.rbox(self, Rect2(r.position + Vector2(0, 3), r.size), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 12)
	Art.rbox(self, r, Color("221a44"), edge, 12, 2)
	Art.rbox(self, Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, r.size.y * 0.4)), Color(1, 1, 1, 0.03), Color(0, 0, 0, 0), 10)

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
		Art.rbox(self, r, Color("2a2150"), Color("5ab4ff") if sel else Color(col, 0.6 if can else 0.25), 10, 3 if sel else 2)
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
		Art.rbox(self, r, Color("1b1535"), Color(1, 1, 1, 0.1), 10, 1)
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
		Art.button(self, rr, "Cambia (%d)" % Data.REROLL_PRICE, Color("7d6bff"), sparks >= Data.REROLL_PRICE)
		var er := Rect2(pr.end.x - 10 - 100, by, 100, 26)
		ui_rects["exit"] = er
		Art.button(self, er, "Esci", Color("1fa65a"))
	else:
		var er := Rect2(s.x / 2.0 - 60, by, 120, 26)
		ui_rects["exit"] = er
		Art.button(self, er, "Esci", Color("1fa65a"))

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
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.02, 0.01, 0.06, 0.72))
	PixelFont.draw_centered(self, "Pausa", s.x / 2.0, s.y * 0.28, 4, Color("ffc94a"), OUT)
	var r1 := Rect2(s.x / 2.0 - 80, s.y * 0.42, 160, 36)
	var r2 := Rect2(s.x / 2.0 - 80, s.y * 0.42 + 50, 160, 30)
	ui_rects["resume"] = r1
	ui_rects["quit"] = r2
	Art.button(self, r1, "Riprendi", Color("ff8a1a"), true, 2)
	Art.button(self, r2, "Abbandona", Color("5b5577"), true, 1)
	PixelFont.draw_centered(self, "Abbandonando tieni una parte del bottino", s.x / 2.0, r2.end.y + 12, 1, Art.TEXT_DIM)

func _draw_end() -> void:
	if end_t < 0.8:
		return
	var s := _size()
	var a := clampf((end_t - 0.8) * 3.0, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.02, 0.01, 0.06, 0.78 * a))
	var win := state == St.WIN
	var y := s.y * 0.12
	PixelFont.draw_centered(self, "Vittoria!" if win else "Sei caduta", s.x / 2.0, y, 4, Color("ffc94a") if win else Color("ff5a6a"), OUT)
	var sub := "La Fonderia caduta · capitolo completato" if win else "Arrivata alla stanza %d di %d" % [room_n, Data.ROOMS]
	PixelFont.draw_centered(self, sub, s.x / 2.0, y + 36, 1, Color("c9b8ff"))
	var pr := Rect2(18, y + 54, s.x - 36, 150)
	Art.rbox(self, pr, Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.15), 12, 1)
	var lx := pr.position.x + 12
	var ly := pr.position.y + 12
	var lines := [
		["gold", "Oro raccolto", str(end_info.gold), Art.GOLD],
		["spark", "Scintille non spese: %d" % end_info.sparks, "+%d oro" % end_info.spark_gold, Color("ffb03a")],
		["gem", "Gemme raccolte", str(end_info.gems), Art.GEM],
	]
	for l in lines:
		Art.icon(self, l[0], Vector2(lx, ly), 1.5, l[3])
		PixelFont.draw_text(self, l[1], Vector2(lx + 16, ly), 1, Color.WHITE)
		var vw := PixelFont.text_width(l[2], 1)
		PixelFont.draw_text(self, l[2], Vector2(pr.end.x - 12 - vw, ly), 1, l[3])
		ly += 16
	var mx := lx
	for m in ["bone", "stone", "ember"]:
		var md: Dictionary = Gear.MATERIALS[m]
		Art.icon(self, md.icon, Vector2(mx, ly), 1.5, md.color)
		PixelFont.draw_text(self, "+%d %s" % [end_info.mats.get(m, 0), PixelFont.nice(md.name)], Vector2(mx + 15, ly), 1, Color.WHITE)
		mx += 74
	ly += 18
	var pct := "Tieni il %d%% del bottino" % int(round(end_info.frac * 100))
	PixelFont.draw_centered(self, pct, s.x / 2.0, ly, 1, Art.TEXT_DIM if not win else Art.GREEN)
	ly += 16
	var tot := "+%d oro   +%d gemme" % [end_info.gold_kept, end_info.gems_kept]
	PixelFont.draw_centered(self, tot, s.x / 2.0, ly, 3, Color("ffc94a"), OUT)
	var by := pr.end.y + 10
	if not run_items.is_empty():
		PixelFont.draw_centered(self, "Bottino dei boss:", s.x / 2.0, by, 1, Color("ffb03a"))
		var bx := s.x / 2.0 - (run_items.size() * 38 - 4) / 2.0
		for i in run_items.size():
			Art.item_box(self, run_items[i], Rect2(bx + i * 38, by + 14, 34, 34))
		by += 56
	var r1 := Rect2(s.x / 2.0 - 90, by + 6, 180, 38)
	var r2 := Rect2(s.x / 2.0 - 70, by + 54, 140, 28)
	ui_rects["again"] = r1
	ui_rects["home"] = r2
	Art.button(self, r1, "Rigioca", Color("ff8a1a"), true, 2)
	Art.button(self, r2, "Campo base", Color("5b5577"), true, 1)

var _dbg_t := 0.0
func _autotest_step() -> void:
	if time - _dbg_t > 10.0:
		_dbg_t = time
		print("T ", int(time), " room ", room_n, " st ", state, " en ", enemies.size(), " wave ", wave_idx, "/", waves.size(), " shots ", shots.size())
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
		if forge_big:
			_ui_action("reroll")
			_ui_action("slot00")
		print("FORGE room ", room_n, " sparks ", sparks, " weapons ", weapons)
		auto_forged = true
		_ui_action("exit")
	elif state == St.DEAD or state == St.WIN:
		if end_t > 1.0:
			print("END ", "WIN" if state == St.WIN else "DEAD", " room ", room_n, " info ", end_info, " t=", time)
			get_tree().quit()
