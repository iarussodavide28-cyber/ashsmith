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
const WALL_SIZE := 10
const HUD_H := 30.0
const BAR_H := 52.0
const HERO_SIZE := 14
const HERO_SPEED := 95.0
const ACCEL := 900.0
const FRICTION := 1100.0
const JOY_RADIUS := 28.0
const HERO_MAX_HP := 120

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
var hero_hp := HERO_MAX_HP
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
var anvil_lock := false
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
	for k in Save.weapons:
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

# =====================================================================
#  Spazio di gioco
# =====================================================================
func _size() -> Vector2:
	return get_viewport_rect().size

func _room_rect() -> Rect2:
	var s := _size()
	return Rect2(WALL_SIZE, HUD_H + WALL_SIZE, s.x - WALL_SIZE * 2, s.y - HUD_H - BAR_H - WALL_SIZE * 2)

func _switch_rect() -> Rect2:
	var s := _size()
	return Rect2(s.x - 104, s.y - BAR_H + 6, 98, BAR_H - 12)

func _pause_rect() -> Rect2:
	return Rect2(_size().x - 22, 4, 18, 18)

func _door_rect() -> Rect2:
	var r := _room_rect()
	return Rect2(r.get_center().x - 18, r.position.y - WALL_SIZE, 36, WALL_SIZE)

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
	door_open = false
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
		if p.distance_to(hero_pos) > 90:
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
		e.merge({"fam": "golem", "hp": 760.0, "speed": 18.0, "size": 30, "dmg": 26, "sparks": 40, "kind": "slammer", "boss": true, "name": "GOLEM ANTICO"}, true)
		e.weak_known = true
	elif k == "boss":
		e.merge({"fam": "boss", "hp": 1500.0, "speed": 24.0, "size": 34, "dmg": 18, "sparks": 0, "kind": "boss", "boss": true, "name": "SIGNORE DELLA CENERE"}, true)
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
			target = off.normalized() * HERO_SPEED * maxf(strength, 0.35)
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

func _update_attack(dt: float) -> void:
	atk_t = maxf(0.0, atk_t - dt)
	var still := touch_index == -1 and auto_target == null and hero_vel.length() < 10.0
	if not still or atk_t > 0.0:
		return
	var tg = _nearest_enemy(hero_pos)
	if tg == null:
		return
	var wd := _wdata()
	var dir: Vector2 = (tg.pos - hero_pos).normalized()
	facing = dir
	atk_t = wd.rate
	var w := _w()
	var col := _shot_color(w)
	shots.append({
		"pos": hero_pos + dir * 6, "vel": dir * wd.speed, "life": wd.range / wd.speed,
		"dmg": wd.dmg, "w": w.key, "slots": w.slots.duplicate(), "size": wd.size,
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
				_hit_enemy(e, s.dmg, s.slots, true)
				if s.area > 0.0:
					_explode(s.pos, s.area, s.dmg, s.slots, Color("c78cff"))
				if s.w != "sword":
					done = true
					break
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
	return Data.combo_key(slots[0], slots[1])

func _immune(e: Dictionary, el: String) -> bool:
	if e.fam == "boss":
		return false
	return Data.FAMILIES[e.fam].immune == el

func _hit_enemy(e: Dictionary, base: float, slots: Array, primary: bool) -> void:
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
	if mult >= 1.4:
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
	var n: int = e.sparks
	for i in n:
		_drop("spark", e.pos)
	if randf() < 0.35 or e.boss:
		for i in (randi_range(1, 2) if not e.boss else 12):
			_drop("gold", e.pos)
	if randf() < 0.05 or e.boss:
		for i in (1 if not e.boss else 3):
			_drop("gem", e.pos)
	if e.k == "boss":
		for i in 30:
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
	var slam_r: float = 36.0 if not e.boss else 54.0
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
	hero_hp -= dmg
	hero_inv = 0.8
	hero_flash = 1.0
	shake = maxf(shake, 1.0)
	_float(hero_pos + Vector2(0, -12), "-%d" % dmg, Art.HP)
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
		_end_run(true)
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
	hero_hp = mini(HERO_MAX_HP, hero_hp + 8)   # piccola cura tra le stanze
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
	return Data.BASE_PRICE + Data.PRICE_STEP * purchases

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
		get_tree().change_scene_to_file("res://scenes/lobby.tscn")
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
		var info := Data.slots_info(w.slots)
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
	end_info = {"gold": run_gold, "spark_gold": spark_gold, "sparks": sparks, "frac": frac, "gold_kept": gold_kept, "gems_kept": gems_kept, "gems": run_gems}
	Save.gold += gold_kept
	Save.gems += gems_kept
	Save.runs += 1
	if win:
		Save.wins += 1
	Save.best_room = maxi(Save.best_room, room_n)
	Save.save_game()

# =====================================================================
#  Disegno
# =====================================================================
func _draw() -> void:
	var s := _size()
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
	for e in enemies:
		_draw_enemy(e)
	if state != St.DEAD:
		_draw_hero()
	for sh in shots:
		_draw_shot(sh)
	for b in bullets:
		draw_circle(b.pos, b.r + 1, Art.DARK)
		draw_circle(b.pos, b.r, b.col)
		draw_circle(b.pos - Vector2(1, 1), b.r * 0.4, Color(1, 1, 1, 0.8))
	for b in bolts:
		_draw_bolt(b.a, b.b)
	for p in parts:
		var c: Color = p.col
		c.a = clampf(p.life / p.max * 1.5, 0.0, 1.0)
		draw_rect(Rect2(floorf(p.pos.x), floorf(p.pos.y), p.size, p.size), c)
	for f in floats:
		PixelFont.draw_centered(self, f.txt, f.pos.x, floorf(f.pos.y), 1, f.col, Art.DARK)
	if touch_index != -1 and state == St.PLAY or touch_index != -1 and state == St.CLEAR:
		draw_arc(joy_origin, JOY_RADIUS, 0, TAU, 32, Color(1, 1, 1, 0.18), 1.0)
		draw_circle(joy_origin + (joy_current - joy_origin).limit_length(JOY_RADIUS), 7, Color(1, 1, 1, 0.3))
	draw_set_transform(Vector2.ZERO)
	_draw_hud()
	_draw_bar()
	_draw_banner()
	match state:
		St.FORGE: _draw_forge()
		St.PAUSE: _draw_pause()
		St.DEAD, St.WIN: _draw_end()

func _draw_room() -> void:
	var s := _size()
	var r := _room_rect()
	draw_rect(Rect2(Vector2(-4, -4), s + Vector2(8, 8)), BG)
	var tint := Color(1, 1, 1)
	if room_n == Data.BOSS_ROOM:
		tint = Color(1.15, 0.85, 0.8)
	elif room_n == Data.MINIBOSS_ROOM:
		tint = Color(0.9, 0.95, 1.05)
	var cols := int(ceil(r.size.x / TILE))
	var rows := int(ceil(r.size.y / TILE))
	for y in rows:
		for x in cols:
			var tile := Rect2(r.position + Vector2(x * TILE, y * TILE), Vector2(TILE, TILE)).intersection(r)
			draw_rect(tile, (FLOOR_A if (x + y) % 2 == 0 else FLOOR_B) * tint)
	draw_rect(Rect2(r.position.x - WALL_SIZE, r.position.y - WALL_SIZE, r.size.x + WALL_SIZE * 2, WALL_SIZE), WALL)
	draw_rect(Rect2(r.position.x - WALL_SIZE, r.position.y - WALL_SIZE, r.size.x + WALL_SIZE * 2, 3), WALL_TOP)
	draw_rect(Rect2(r.position.x - WALL_SIZE, r.end.y, r.size.x + WALL_SIZE * 2, WALL_SIZE), WALL)
	draw_rect(Rect2(r.position.x - WALL_SIZE, r.position.y, WALL_SIZE, r.size.y), WALL)
	draw_rect(Rect2(r.end.x, r.position.y, WALL_SIZE, r.size.y), WALL)
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 2), Color(0, 0, 0, 0.35))
	# torce sul muro
	for tx in [r.position.x + 30, r.end.x - 30]:
		var fl := 0.7 + 0.3 * sin(time * 9.0 + tx)
		draw_circle(Vector2(tx, r.position.y + 4), 10, Color(1, 0.55, 0.2, 0.12 * fl))
		draw_rect(Rect2(tx - 1, r.position.y - 6, 3, 5), Color("6b3d22"))
		draw_rect(Rect2(tx - 1, r.position.y - 9, 3, 3), HERO_LIGHT if fl > 0.85 else HERO)
	# porta
	var d := _door_rect()
	if door_open:
		draw_rect(d, Color("0a0506"))
		var a := 0.5 + 0.5 * sin(time * 5.0)
		draw_rect(Rect2(d.position.x, d.end.y - 2, d.size.x, 2), Color(Art.SPARK, a))
		# freccia
		var c := Vector2(d.get_center().x, d.end.y + 12 + 2 * sin(time * 6.0))
		for i in 4:
			draw_rect(Rect2(c.x - i, c.y + i, 1 + i * 2, 1), Color(1, 1, 1, 0.6))
	else:
		draw_rect(d, Color("3a2a2a"))
		draw_rect(Rect2(d.position.x + 2, d.position.y + 2, d.size.x - 4, d.size.y - 2), Color("5a3e30"))
		draw_rect(Rect2(d.get_center().x - 1, d.position.y + 2, 2, d.size.y - 2), Color("3a2a22"))

func _draw_ground() -> void:
	for p in patches:
		var a: float = clampf(p.life, 0.0, 1.0)
		draw_circle(p.pos, p.r, Color(1, 0.35, 0.1, 0.35 * a))
		draw_rect(Rect2(floorf(p.pos.x - 1), floorf(p.pos.y - 3 - fmod(time * 8.0, 3.0)), 2, 2), Color(1, 0.8, 0.3, a))
	for c in clouds:
		var a: float = clampf(c.life, 0.0, 1.0)
		var col := Color(0.85, 0.9, 1.0, 0.25 * a) if c.kind == "steam" else Color(0.45, 1.0, 0.35, 0.25 * a)
		draw_circle(c.pos, c.r, col)
		draw_circle(c.pos + Vector2(sin(time * 2) * 4, -3), c.r * 0.6, col)

func _draw_anvil() -> void:
	if anvil.is_empty():
		return
	var p: Vector2 = anvil.pos
	var g := 0.3 + 0.1 * sin(time * 4.0)
	draw_circle(p, 22 if not anvil.big else 30, Color(1, 0.55, 0.2, g * 0.4))
	var steel := Color("5b5f6e")
	draw_rect(Rect2(p.x - 10, p.y - 4, 18, 4), steel)
	draw_rect(Rect2(p.x - 10, p.y - 4, 18, 1), Color("8a90a3"))
	draw_rect(Rect2(p.x - 15, p.y - 3, 5, 2), steel)
	draw_rect(Rect2(p.x - 5, p.y, 8, 4), Color("33353f"))
	draw_rect(Rect2(p.x - 9, p.y + 4, 16, 3), steel)
	draw_rect(Rect2(p.x - 8, p.y - 6, 12, 2), HERO.lerp(HERO_LIGHT, 0.5 + 0.5 * sin(time * 5.0)))
	if anvil.big:
		draw_rect(Rect2(p.x + 10, p.y - 14, 6, 21), Color("4a3030"))
		draw_rect(Rect2(p.x + 11, p.y - 12, 4, 4), HERO_LIGHT)
	var label := "INCUDINE" if not anvil.big else "FUCINA GRANDE"
	PixelFont.draw_centered(self, label, p.x, p.y - 20 - 2 * sin(time * 3.0), 1, HERO_LIGHT, Art.DARK)

func _draw_drop(d: Dictionary) -> void:
	var p := Vector2(floorf(d.pos.x), floorf(d.pos.y))
	match d.kind:
		"spark":
			var c := HERO if fmod(time * 6.0 + p.x, 2.0) < 1.0 else HERO_LIGHT
			draw_rect(Rect2(p.x - 1, p.y - 2, 2, 4), c)
			draw_rect(Rect2(p.x - 2, p.y - 1, 4, 2), c)
		"gold":
			draw_rect(Rect2(p.x - 2, p.y - 2, 5, 5), Color("a87a10"))
			draw_rect(Rect2(p.x - 2, p.y - 2, 4, 4), Art.GOLD)
		"gem":
			draw_rect(Rect2(p.x - 2, p.y - 3, 5, 6), Color("2a7aa0"))
			draw_rect(Rect2(p.x - 1, p.y - 2, 3, 3), Art.GEM)

func _enemy_color(e: Dictionary) -> Color:
	match e.k:
		"zombie": return Color("7a9a6a")
		"archer": return Color("d8d0b8")
		"golem": return Color("8a8a96")
		"pebble": return Color("a09a8a")
		"imp": return Color("ff5a2a")
		"spitter": return Color("c03a2a")
		"miniboss": return Color("7a7a8a")
		"boss": return Color("3a2030")
	return Color.WHITE

func _draw_enemy_telegraph(e: Dictionary) -> void:
	if e.spawn > 0.0:
		var k: float = 1.0 - e.spawn / 0.8
		draw_arc(e.pos, e.size * (1.4 - 0.4 * k), 0, TAU, 20, Color(1, 0.3, 0.3, 0.7), 1.0)
		draw_rect(Rect2(e.pos.x - 1, e.pos.y - 1, 2, 2), WARN)
		return
	if e.dead_t > 0.0:
		return
	var blink := 0.35 + 0.35 * (1 if fmod(time * 10.0, 2.0) < 1.0 else 0)
	match e.st:
		"aim", "charge_aim":
			var a: float = e.aim
			var len := 160.0 if e.st == "aim" else 140.0
			var w := 1.0 if e.kind != "spread" else 1.0
			if e.kind == "spread":
				for k in [-0.35, 0.0, 0.35]:
					draw_line(e.pos, e.pos + Vector2.from_angle(a + k) * len, Color(WARN, blink), w)
			elif e.st == "charge_aim":
				draw_line(e.pos, e.pos + Vector2.from_angle(a) * len, Color(WARN, blink * 0.6), e.size * 0.8)
			else:
				draw_line(e.pos, e.pos + Vector2.from_angle(a) * len, Color(WARN, blink), w)
		"throw":
			for k in 5:
				draw_line(e.pos, e.pos + Vector2.from_angle(e.aim + (k - 2) * 0.28) * 120, Color(WARN, blink * 0.8), 1.0)
		"slam":
			var r: float = 36.0 if not e.boss else 54.0
			var k: float = 1.0 - e.t / 0.9
			draw_circle(e.pos, r, Color(1, 0.2, 0.2, 0.12 + 0.15 * k))
			draw_arc(e.pos, r * k, 0, TAU, 28, Color(WARN, 0.8), 1.0)
			draw_arc(e.pos, r, 0, TAU, 28, Color(WARN, 0.9), 1.0)
		"ring", "aimed", "spiral":
			draw_circle(e.pos, e.size * 0.9, Color(1, 0.3, 0.3, blink * 0.5))

func _draw_enemy(e: Dictionary) -> void:
	if e.spawn > 0.0:
		return
	var sz: int = e.size
	var p := Vector2(roundf(e.pos.x - sz / 2.0), roundf(e.pos.y - sz / 2.0))
	if e.dead_t > 0.0:
		# a terra, si sta per rialzare
		draw_rect(Rect2(p.x, p.y + sz / 2.0, sz, sz / 2.0), Color("4a5040"))
		if fmod(time * 6.0, 2.0) < 1.0:
			PixelFont.draw_centered(self, "!", e.pos.x, p.y - 4, 1, WARN)
		return
	var col := _enemy_color(e)
	var bob := sin(time * 6.0 + e.pos.x) * 1.0
	p.y += roundf(bob)
	draw_rect(Rect2(p.x + 1, p.y + sz - 1, sz - 2, 3), Color(0, 0, 0, 0.35))
	match e.k:
		"golem", "pebble", "miniboss":
			draw_rect(Rect2(p, Vector2(sz, sz)), col.darkened(0.4))
			draw_rect(Rect2(p + Vector2(1, 1), Vector2(sz - 2, sz - 3)), col)
			draw_rect(Rect2(p + Vector2(sz * 0.3, sz * 0.5), Vector2(1, sz * 0.4)), col.darkened(0.3))
			draw_rect(Rect2(p + Vector2(2, 1), Vector2(sz - 4, 2)), col.lightened(0.2))
		"imp":
			var fl := roundf(sin(time * 14.0 + e.pos.y) * 1.5)
			draw_rect(Rect2(p.x + sz / 2.0 - 2, p.y - 3 + fl, 4, 4), Color("ffd25a"))
			draw_rect(Rect2(p, Vector2(sz, sz)), col.darkened(0.4))
			draw_rect(Rect2(p + Vector2(1, 1), Vector2(sz - 2, sz - 3)), col)
		"boss":
			var glow := 0.4 + 0.2 * sin(time * 3.0)
			draw_circle(e.pos, sz * 0.8, Color(1, 0.4, 0.15, glow * 0.25))
			draw_rect(Rect2(p, Vector2(sz, sz)), Color("1a0c12"))
			draw_rect(Rect2(p + Vector2(2, 2), Vector2(sz - 4, sz - 5)), col)
			# corona di brace
			for i in 5:
				var hx := p.x + 3 + i * (sz - 6) / 4.0
				draw_rect(Rect2(hx - 1, p.y - 4 - (2 if i % 2 == 0 else 0), 3, 5), HERO if e.phase == 1 else Color("ffe14a"))
			draw_rect(Rect2(p + Vector2(4, sz - 9), Vector2(sz - 8, 3)), HERO.darkened(0.2))
		_:
			draw_rect(Rect2(p, Vector2(sz, sz)), col.darkened(0.45))
			draw_rect(Rect2(p + Vector2(1, 1), Vector2(sz - 2, sz - 3)), col)
			draw_rect(Rect2(p + Vector2(1, 1), Vector2(sz - 2, 2)), col.lightened(0.2))
	# occhi verso l'eroe
	var look: Vector2 = (hero_pos - e.pos).normalized() * (1.5 if sz < 20 else 3.0)
	var eye_col := Color("ffe14a") if e.fam == "golem" or e.k == "boss" else Color("120a0c")
	if e.k == "spitter" or e.k == "imp":
		eye_col = Color("ffd25a")
	var es := 2 if sz < 25 else 3
	var c: Vector2 = e.pos + Vector2(0, roundf(bob) - sz * 0.1) + look
	draw_rect(Rect2(roundf(c.x - es - 1), roundf(c.y - 1), es, es), eye_col)
	draw_rect(Rect2(roundf(c.x + 1), roundf(c.y - 1), es, es), eye_col)
	if e.k == "archer":
		draw_rect(Rect2(p.x + sz, p.y + 2, 1, sz - 4), Color("8a6a40"))
	# stati
	if e.slow > 0.0 or e.freeze > 0.0:
		draw_rect(Rect2(p, Vector2(sz, sz)), Color(0.45, 0.85, 1.0, 0.35 if e.freeze <= 0.0 else 0.65))
	if e.pois > 0:
		for i in mini(e.pois, 5):
			draw_rect(Rect2(p.x + i * 3, p.y + sz + 2, 2, 2), Data.EL_COLOR.poison)
	if e.flash > 0.0:
		draw_rect(Rect2(p, Vector2(sz, sz)), Color(1, 1, 1, e.flash * 0.8))
	if e.inv > 0.0 and fmod(time * 10.0, 2.0) < 1.0:
		draw_rect(Rect2(p, Vector2(sz, sz)), Color(1, 1, 0.6, 0.5))
	# vita e icona della debolezza
	if not e.boss:
		var bw := sz + 2
		var by := p.y - 5
		if e.hp < e.max:
			draw_rect(Rect2(p.x - 1, by, bw, 2), Color("3a1a1a"))
			draw_rect(Rect2(p.x - 1, by, bw * clampf(e.hp / e.max, 0.0, 1.0), 2), Art.HP)
		var weak := _weak_of(e)
		Art.panel(self, Rect2(e.pos.x - 5, by - 11, 9, 9), Color("1a1012"), Data.EL_COLOR[weak].darkened(0.3))
		Art.icon(self, weak, Vector2(e.pos.x - 4, by - 10), 1, Data.EL_COLOR[weak])

func _draw_hero() -> void:
	var half := HERO_SIZE / 2.0
	if hero_inv > 0.0 and fmod(time * 16.0, 2.0) < 1.0:
		return
	var bob := 0.0
	if hero_vel.length() > 5.0:
		bob = -1.0 if fmod(step_t, 2.0) < 1.0 else 0.0
	var p := Vector2(roundf(hero_pos.x - half), roundf(hero_pos.y - half + bob))
	draw_rect(Rect2(roundf(hero_pos.x - half + 1), roundf(hero_pos.y + half - 1), HERO_SIZE - 2, 3), Color(0, 0, 0, 0.4))
	draw_rect(Rect2(p, Vector2(HERO_SIZE, HERO_SIZE)), HERO_DARK)
	draw_rect(Rect2(p + Vector2(1, 1), Vector2(HERO_SIZE - 2, HERO_SIZE - 3)), HERO)
	draw_rect(Rect2(p + Vector2(1, 1), Vector2(HERO_SIZE - 2, 2)), HERO_LIGHT)
	var eye := Vector2(roundf(facing.x * 2.0), roundf(facing.y * 2.0))
	var c := p + Vector2(half, half) + eye
	draw_rect(Rect2(c + Vector2(-3, -1), Vector2(2, 2)), Art.DARK)
	draw_rect(Rect2(c + Vector2(1, -1), Vector2(2, 2)), Art.DARK)
	# arma in mano
	var wc := _shot_color(_w())
	var hand := hero_pos + facing * (half + 2)
	draw_rect(Rect2(floorf(hand.x) - 1, floorf(hand.y) - 1, 3, 3), wc)
	if hero_flash > 0.0:
		draw_rect(Rect2(p, Vector2(HERO_SIZE, HERO_SIZE)), Color(1, 0.2, 0.2, hero_flash * 0.7))

func _draw_shot(s: Dictionary) -> void:
	var col: Color = s.col
	var dir: Vector2 = s.vel.normalized()
	match s.w:
		"sword":
			# fendente a mezzaluna
			var a := dir.angle()
			draw_arc(s.pos - dir * 3, 8, a - 1.1, a + 1.1, 8, col, 3.0)
			draw_arc(s.pos - dir * 3, 8, a - 0.6, a + 0.6, 6, Color.WHITE, 1.0)
		"bow":
			draw_line(s.pos - dir * 7, s.pos, Color("8a6a40"), 1.0)
			draw_rect(Rect2(floorf(s.pos.x) - 1, floorf(s.pos.y) - 1, 3, 3), col)
		"staff":
			draw_circle(s.pos, s.size + 2, Color(col, 0.35))
			draw_circle(s.pos, s.size, col)
			draw_circle(s.pos - Vector2(1, 1), 2, Color.WHITE)

func _draw_bolt(a: Vector2, b: Vector2) -> void:
	var col := Data.EL_COLOR.thunder
	var n := 5
	var prev := a
	for i in range(1, n + 1):
		var t := float(i) / n
		var pt := a.lerp(b, t)
		if i < n:
			pt += (b - a).orthogonal().normalized() * randf_range(-5, 5)
		draw_line(prev, pt, col, 1.0)
		prev = pt

# ---------------------------------------------------------------------
#  Interfaccia
# ---------------------------------------------------------------------
func _draw_hud() -> void:
	var s := _size()
	draw_rect(Rect2(0, 0, s.x, HUD_H), Color("0e0809"))
	# vita
	Art.icon(self, "heart", Vector2(5, 5), 1, Art.HP)
	var bw := 70.0
	draw_rect(Rect2(14, 5, bw + 2, 7), Art.DARK)
	draw_rect(Rect2(15, 6, bw, 5), Color("3a1a1a"))
	draw_rect(Rect2(15, 6, bw * float(hero_hp) / HERO_MAX_HP, 5), Art.HP)
	PixelFont.draw_text(self, str(hero_hp), Vector2(14 + bw + 6, 5), 1, Color.WHITE)
	# monete
	var x := 5.0
	x += Art.counter(self, "spark", sparks, Vector2(x, 17), Art.SPARK)
	x += Art.counter(self, "gold", run_gold, Vector2(x, 17), Art.GOLD)
	Art.counter(self, "gem", run_gems, Vector2(x, 17), Art.GEM)
	# stanza
	var rt := "STANZA %d/%d" % [room_n, Data.ROOMS]
	PixelFont.draw_text(self, rt, Vector2(s.x - PixelFont.text_width(rt, 1) - 28, 5), 1, Color.WHITE)
	var nx := "BOSS" if room_n == Data.BOSS_ROOM else ("MINI-BOSS" if room_n == Data.MINIBOSS_ROOM else ("FUCINA GRANDE" if room_n in Data.BIG_FORGE_ROOMS else ""))
	if nx != "":
		PixelFont.draw_text(self, nx, Vector2(s.x - PixelFont.text_width(nx, 1) - 28, 17), 1, HERO)
	# pausa
	var pr := _pause_rect()
	Art.panel(self, pr, Color("2a1c1e"))
	draw_rect(Rect2(pr.position.x + 6, pr.position.y + 5, 2, 8), Color.WHITE)
	draw_rect(Rect2(pr.position.x + 10, pr.position.y + 5, 2, 8), Color.WHITE)
	# barra del boss
	for e in enemies:
		if e.boss and e.spawn <= 0.0:
			var r := Rect2(20, HUD_H + WALL_SIZE + 4, s.x - 40, 6)
			draw_rect(r.grow(1), Art.DARK)
			draw_rect(r, Color("3a1a1a"))
			draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(e.hp / e.max, 0, 1), r.size.y)), Color("c0303a"))
			PixelFont.draw_centered(self, e.name, s.x / 2.0, r.end.y + 4, 1, Color.WHITE, Art.DARK)
			var weak := _weak_of(e)
			var ip := Vector2(r.end.x - 9, r.end.y + 3)
			if e.weak_known:
				Art.icon(self, weak, ip, 1, Data.EL_COLOR[weak])
			else:
				Art.icon(self, "question", ip, 1, Color.WHITE)
			break

func _draw_bar() -> void:
	var s := _size()
	var y0 := s.y - BAR_H
	draw_rect(Rect2(0, y0, s.x, BAR_H), Color("0e0809"))
	draw_rect(Rect2(0, y0, s.x, 1), Color("3a2a2a"))
	# le due armi con i loro incastri
	for i in weapons.size():
		var w: Dictionary = weapons[i]
		var wd: Dictionary = Data.WEAPONS[w.key]
		var r := Rect2(6 + i * 78, y0 + 6, 74, BAR_H - 12)
		var cur := i == cur_w
		Art.panel(self, r, Color("2e1e20") if cur else Color("1a1214"), HERO if cur else Color("3a2a2a"))
		Art.icon(self, w.key, r.position + Vector2(4, 4), 2, wd.color if cur else Art.TEXT_DIM)
		PixelFont.draw_text(self, wd.name, r.position + Vector2(22, 4), 1, Color.WHITE if cur else Art.TEXT_DIM)
		for si in 2:
			var sr := Rect2(r.position.x + 22 + si * 13, r.position.y + 14, 11, 11)
			draw_rect(sr, Art.DARK)
			var el: String = w.slots[si]
			if el != "":
				Art.el_icon(self, el, sr.position + Vector2(2, 2), 1)
		var info := Data.slots_info(w.slots)
		if w.slots[0] != "" and w.slots[1] != "":
			PixelFont.draw_text(self, info[0].substr(0, 11), r.position + Vector2(4, r.size.y - 9), 1, _shot_color(w))
	# pulsante cambio arma
	var sr := _switch_rect()
	var ready := switch_t <= 0.0
	Art.button(self, sr, "", Color("7a4ad0") if ready else Color("3a2a50"), true)
	var other: Dictionary = weapons[1 - cur_w] if weapons.size() > 1 else weapons[0]
	Art.icon(self, other.key, sr.position + Vector2(8, 9), 3, Color.WHITE)
	PixelFont.draw_text(self, "CAMBIA", sr.position + Vector2(36, 10), 1, Color.WHITE)
	PixelFont.draw_text(self, Data.WEAPONS[other.key].name, sr.position + Vector2(36, 21), 1, Color("d8c8ff"))
	if not ready:
		var k := switch_t / Data.SWITCH_COOLDOWN
		draw_rect(Rect2(sr.position, Vector2(sr.size.x * k, sr.size.y)), Color(0, 0, 0, 0.5))

func _draw_banner() -> void:
	var s := _size()
	if banner_t > 0.0:
		var a := clampf(banner_t * 2.0, 0.0, 1.0)
		var y := HUD_H + 50
		draw_rect(Rect2(0, y - 6, s.x, 20), Color(0, 0, 0, 0.55 * a))
		PixelFont.draw_centered(self, banner, s.x / 2.0, y, 1, Color(HERO_LIGHT, a), Art.DARK)
	var r := _room_rect()
	if room_n == 1 and time < 7.0 and state == St.PLAY and fmod(time, 1.2) < 0.85:
		PixelFont.draw_centered(self, "TRASCINA PER MUOVERTI", s.x / 2.0, r.end.y - 34, 1, Color.WHITE, Art.DARK)
		PixelFont.draw_centered(self, "FERMATI PER ATTACCARE", s.x / 2.0, r.end.y - 22, 1, HERO_LIGHT, Art.DARK)
	if state == St.CLEAR and not anvil.is_empty() and not anvil_lock and room_n <= 2 and fmod(time, 1.2) < 0.85:
		PixelFont.draw_centered(self, "VAI ALL'INCUDINE O ESCI DALLA PORTA", s.x / 2.0, r.end.y - 22, 1, Color.WHITE, Art.DARK)

func _draw_forge() -> void:
	var s := _size()
	draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.6))
	var pr := Rect2(8, 44, s.x - 16, 330)
	Art.panel(self, pr, Color("1e1416"), HERO)
	PixelFont.draw_centered(self, "FUCINA GRANDE" if forge_big else "INCUDINE", s.x / 2.0, pr.position.y + 8, 2, HERO, Art.DARK)
	var pt := "PREZZO: %d" % _price()
	Art.counter(self, "spark", sparks, Vector2(pr.position.x + 8, pr.position.y + 28), Art.SPARK)
	Art.icon(self, "spark", Vector2(pr.end.x - PixelFont.text_width(pt, 1) - 18, pr.position.y + 28), 1, Art.SPARK)
	PixelFont.draw_text(self, pt, Vector2(pr.end.x - PixelFont.text_width(pt, 1) - 8, pr.position.y + 28), 1, Color.WHITE)
	# offerte
	var n := offers.size()
	var gap := 4.0
	var cw := (pr.size.x - 16 - gap * (n - 1)) / n
	var y := pr.position.y + 42
	for i in n:
		var o: Dictionary = offers[i]
		var r := Rect2(pr.position.x + 8 + i * (cw + gap), y, cw, 58)
		ui_rects["offer%d" % i] = r
		var el: String = o.el
		var col: Color = Data.EL_COLOR[el]
		var can: bool = sparks >= _price() and not o.sold
		Art.panel(self, r, col.darkened(0.75) if i != sel_offer else col.darkened(0.45), col if i == sel_offer else col.darkened(0.4))
		if o.sold:
			PixelFont.draw_centered(self, "PRESO", r.get_center().x, r.get_center().y - 3, 1, Art.TEXT_DIM)
			continue
		Art.el_icon(self, el, Vector2(r.get_center().x - 10, r.position.y + 7), 3)
		var name: String = Data.EL_NAME[el]
		var sc := 1
		PixelFont.draw_centered(self, name, r.get_center().x, r.position.y + 34, sc, Color.WHITE if can else Art.TEXT_DIM)
		if not can:
			draw_rect(r, Color(0, 0, 0, 0.35))
	# descrizione dell'elemento scelto
	var dy := y + 66
	if sel_offer != -1:
		var el: String = offers[sel_offer].el
		PixelFont.draw_centered(self, Data.EL_NAME[el] + ": " + Data.EL_DESC[el], s.x / 2.0, dy, 1, Data.EL_COLOR[el])
	else:
		PixelFont.draw_centered(self, "2 UGUALI = EFFETTO PIENO", s.x / 2.0, dy - 4, 1, Art.TEXT_DIM)
		PixelFont.draw_centered(self, "2 DIVERSI = COMBINAZIONE", s.x / 2.0, dy + 5, 1, Art.TEXT_DIM)
	# armi e incastri
	var wy := dy + 14
	for wi in weapons.size():
		var w: Dictionary = weapons[wi]
		var wd: Dictionary = Data.WEAPONS[w.key]
		var r := Rect2(pr.position.x + 8, wy + wi * 62, pr.size.x - 16, 56)
		Art.panel(self, r, Color("281a1c"))
		Art.icon(self, w.key, r.position + Vector2(6, 8), 2, wd.color)
		PixelFont.draw_text(self, wd.name, r.position + Vector2(6, 26), 1, Color.WHITE)
		for si in 2:
			var sr := Rect2(r.position.x + 62 + si * 34, r.position.y + 8, 28, 28)
			ui_rects["slot%d%d" % [wi, si]] = sr
			var highlight := sel_offer != -1 and fmod(time * 3.0, 2.0) < 1.0
			Art.panel(self, sr, Art.DARK, HERO_LIGHT if highlight else Color("5a4040"))
			var el: String = w.slots[si]
			if el != "":
				Art.el_icon(self, el, sr.position + Vector2(4, 4), 3)
			else:
				PixelFont.draw_centered(self, "+", sr.get_center().x, sr.position.y + 10, 1, Art.TEXT_DIM)
		# anteprima: cosa diventerebbe
		var info := Data.slots_info(w.slots)
		var tx := r.position.x + 134
		var ny := _wrap_text(info[0], Vector2(tx, r.position.y + 6), r.end.x - tx - 4, _shot_color(w) if w.slots != ["", ""] else Art.TEXT_DIM)
		var desc: String = info[1]
		_wrap_text(desc, Vector2(tx, ny + 3), r.end.x - tx - 4, Art.TEXT_DIM)
		PixelFont.draw_text(self, _weak_hint(w.slots), Vector2(r.position.x + 6, r.position.y + 44), 1, Color("c9a27a"))
	# messaggio e pulsanti
	var my := wy + 128
	PixelFont.draw_centered(self, forge_msg, s.x / 2.0, my, 1, HERO_LIGHT)
	var by := pr.end.y - 32
	if forge_big:
		var rr := Rect2(pr.position.x + 8, by, 116, 24)
		ui_rects["reroll"] = rr
		Art.button(self, rr, "CAMBIA (%d)" % Data.REROLL_PRICE, Color("7a4ad0"), sparks >= Data.REROLL_PRICE)
		var er := Rect2(pr.end.x - 8 - 100, by, 100, 24)
		ui_rects["exit"] = er
		Art.button(self, er, "ESCI", Color("3a8a4a"))
		PixelFont.draw_centered(self, "TOCCA UN INCASTRO PIENO PER TOGLIERLO", s.x / 2.0, by - 22, 1, Art.TEXT_DIM)
		PixelFont.draw_centered(self, "(TI TORNA META DEL PREZZO)", s.x / 2.0, by - 12, 1, Art.TEXT_DIM)
	else:
		var er := Rect2(s.x / 2.0 - 60, by, 120, 24)
		ui_rects["exit"] = er
		Art.button(self, er, "ESCI", Color("3a8a4a"))

func _weak_hint(slots: Array) -> String:
	var parts_txt: Array = []
	for fam in Data.FAMILIES:
		var m := Data.element_mult(slots, fam)
		if m >= 1.4:
			parts_txt.append("FORTE CONTRO " + Data.FAMILIES[fam].short)
	return parts_txt[0] if not parts_txt.is_empty() else ""

func _wrap_text(t: String, pos: Vector2, max_w: float, col: Color) -> float:
	var words := t.split(" ")
	var line := ""
	var y := pos.y
	for wd in words:
		var test := wd if line == "" else line + " " + wd
		if PixelFont.text_width(test, 1) > max_w and line != "":
			PixelFont.draw_text(self, line, Vector2(pos.x, y), 1, col)
			y += 9
			line = wd
		else:
			line = test
	if line != "":
		PixelFont.draw_text(self, line, Vector2(pos.x, y), 1, col)
		y += 9
	return y

func _draw_pause() -> void:
	var s := _size()
	draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.65))
	PixelFont.draw_centered(self, "PAUSA", s.x / 2.0, s.y * 0.3, 3, Color.WHITE, Art.DARK)
	var r1 := Rect2(s.x / 2.0 - 70, s.y * 0.42, 140, 30)
	var r2 := Rect2(s.x / 2.0 - 70, s.y * 0.42 + 42, 140, 30)
	ui_rects["resume"] = r1
	ui_rects["quit"] = r2
	Art.button(self, r1, "RIPRENDI", Color("3a8a4a"), true, 2)
	Art.button(self, r2, "ABBANDONA", Color("a03030"), true, 1)
	PixelFont.draw_centered(self, "ABBANDONANDO TIENI UNA PARTE DEL BOTTINO", s.x / 2.0, r2.end.y + 10, 1, Art.TEXT_DIM)

func _draw_end() -> void:
	if end_t < 0.8:
		return
	var s := _size()
	var a := clampf((end_t - 0.8) * 3.0, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.7 * a))
	var win := state == St.WIN
	var y := s.y * 0.16
	PixelFont.draw_centered(self, "VITTORIA!" if win else "SEI CADUTA", s.x / 2.0, y, 3, Art.GOLD if win else Art.HP, Art.DARK)
	var sub := "HAI SCONFITTO IL SIGNORE DELLA CENERE" if win else "ARRIVATA ALLA STANZA %d DI %d" % [room_n, Data.ROOMS]
	PixelFont.draw_centered(self, sub, s.x / 2.0, y + 30, 1, Color.WHITE)
	var pr := Rect2(24, y + 50, s.x - 48, 128)
	Art.panel(self, pr, Color("1e1416"))
	var lx := pr.position.x + 10
	var ly := pr.position.y + 10
	var lines := [
		["gold", "ORO RACCOLTO", str(end_info.gold), Art.GOLD],
		["spark", "SCINTILLE NON SPESE: %d" % end_info.sparks, "+%d ORO" % end_info.spark_gold, Art.SPARK],
		["gem", "GEMME RACCOLTE", str(end_info.gems), Art.GEM],
	]
	for l in lines:
		Art.icon(self, l[0], Vector2(lx, ly), 1, l[3])
		PixelFont.draw_text(self, l[1], Vector2(lx + 10, ly), 1, Color.WHITE)
		PixelFont.draw_text(self, l[2], Vector2(pr.end.x - 10 - PixelFont.text_width(l[2], 1), ly), 1, l[3])
		ly += 14
	var pct := "TIENI IL %d%% DEL BOTTINO" % int(round(end_info.frac * 100))
	PixelFont.draw_centered(self, pct, s.x / 2.0, ly + 4, 1, Art.TEXT_DIM if not win else Color("7dff5a"))
	ly += 22
	PixelFont.draw_centered(self, "GUADAGNATO", s.x / 2.0, ly, 1, Color.WHITE)
	ly += 14
	var tot := "+%d ORO   +%d GEMME" % [end_info.gold_kept, end_info.gems_kept]
	PixelFont.draw_centered(self, tot, s.x / 2.0, ly, 2, Art.GOLD, Art.DARK)
	PixelFont.draw_centered(self, "SALVATO: %d ORO, %d GEMME IN TOTALE" % [Save.gold, Save.gems], s.x / 2.0, pr.end.y + 10, 1, Art.TEXT_DIM)
	var r1 := Rect2(s.x / 2.0 - 75, pr.end.y + 30, 150, 30)
	var r2 := Rect2(s.x / 2.0 - 75, pr.end.y + 70, 150, 26)
	ui_rects["again"] = r1
	ui_rects["home"] = r2
	Art.button(self, r1, "RIGIOCA", Color("e0661f"), true, 2)
	Art.button(self, r2, "CAMPO BASE", Color("5a4a6a"), true, 1)

func _autotest_step() -> void:
	if not "--mortal" in OS.get_cmdline_user_args():
		hero_hp = HERO_MAX_HP
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
