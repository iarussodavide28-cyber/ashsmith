extends Node2D
## Menu principale con 3 sezioni: Equipaggiamento, Gioca, Negozio.

const TOP_H := 24.0
const TAB_H := 44.0
const BG := Color("140f2a")
const TABS := [["equip", "EQUIP", "bag"], ["play", "GIOCA", "play"], ["shop", "NEGOZIO", "shop"]]

var tab := "play"
var time := 0.0
var rects := {}          # azione -> Rect2 (ricostruito a ogni disegno)
var scroll := 0.0
var scroll_max := 0.0
var inv_page := 0

var detail_id := -1      # pezzo aperto nel dettaglio
var show_recipes := false
var reveal := {}         # pezzo appena ottenuto da mostrare
var reveal_msg := ""
var toast := ""
var toast_t := 0.0

var press_pos := Vector2.ZERO
var press_scroll := 0.0
var dragging := false
var touching := false

func _ready() -> void:
	if Save.has_meta("menu_tab"):
		tab = Save.get_meta("menu_tab")

func _process(delta: float) -> void:
	time += delta
	toast_t -= delta
	queue_redraw()

func _size() -> Vector2:
	return get_viewport_rect().size

func _content_rect() -> Rect2:
	var s := _size()
	return Rect2(0, TOP_H, s.x, s.y - TOP_H - TAB_H)

func _toast(t: String) -> void:
	toast = t
	toast_t = 2.0

# =====================================================================
#  Input: tocco = azione, trascinamento = scorrere (nel negozio)
# =====================================================================
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touching = true
			dragging = false
			press_pos = event.position
			press_scroll = scroll
		else:
			touching = false
			if not dragging:
				_tap(event.position)
			dragging = false
	elif event is InputEventScreenDrag and touching:
		var dy: float = event.position.y - press_pos.y
		if absf(dy) > 6.0:
			dragging = true
		if dragging and tab == "shop" and _overlay_open() == false:
			scroll = clampf(press_scroll - dy, 0.0, scroll_max)

func _overlay_open() -> bool:
	return detail_id != -1 or show_recipes or not reveal.is_empty()

func _tap(p: Vector2) -> void:
	# il primo rettangolo trovato in ordine inverso (gli ultimi disegnati stanno sopra)
	var keys := rects.keys()
	keys.reverse()
	for k in keys:
		if rects[k].has_point(p):
			_action(k)
			return
	if _overlay_open():
		# tocco fuori dalla finestra: chiude
		detail_id = -1
		show_recipes = false
		reveal = {}

func _action(a: String) -> void:
	if a.begins_with("tab_"):
		tab = a.substr(4)
		Save.set_meta("menu_tab", tab)
		scroll = 0.0
		return
	match a:
		"block":
			return
		"play":
			get_tree().change_scene_to_file("res://scenes/game.tscn")
		"recipes":
			show_recipes = true
		"close":
			detail_id = -1
			show_recipes = false
			reveal = {}
		"inv_prev":
			inv_page = maxi(0, inv_page - 1)
		"inv_next":
			inv_page += 1
		"equip", "equip1", "equip2":
			Save.equip(detail_id, "weapon2" if a == "equip2" else "weapon1")
			detail_id = -1
		"unequip":
			var it := Save.get_item(detail_id)
			Save.unequip(Save.slot_of(it.id))
			detail_id = -1
		"upgrade":
			var it := Save.get_item(detail_id)
			if Save.upgrade(it):
				_toast("LIVELLO %d!" % it.lv)
			else:
				_toast("ORO O MATERIALI INSUFFICIENTI")
		"merge":
			var it := Save.get_item(detail_id)
			var r := Save.merge(it)
			_toast("ORA E %s!" % Gear.RARITY[it.rar].name)
			if r != "":
				_toast("NUOVA RICETTA: %s!" % Data.COMBOS[r][0])
		"sell":
			var it := Save.get_item(detail_id)
			var v := Save.sell_value(it)
			Save.sell(it)
			_toast("VENDUTO: +%d ORO" % v)
			detail_id = -1
		"gift":
			if Save.gift_day != Save.today():
				Save.gift_day = Save.today()
				Save.gold += 50
				_give(Gear.random_base(), Gear.roll_rarity([70.0, 25.0, 5.0, 0.0, 0.0]), "REGALO DEL GIORNO (+50 ORO)")
		"chest":
			if Save.gold >= SHOP_CHEST:
				Save.gold -= SHOP_CHEST
				_give(Gear.random_base(), Gear.roll_rarity(Gear.CHEST_ODDS), "CASSA DEL FABBRO")
			else:
				_toast("ORO INSUFFICIENTE")
		_:
			if a.begins_with("slot_"):
				var it := Save.equipped_item(a.substr(5))
				if not it.is_empty():
					detail_id = it.id
				else:
					_toast("NESSUN PEZZO: PRENDILO NEL NEGOZIO")
			elif a.begins_with("inv_"):
				detail_id = int(a.substr(4))
			elif a.begins_with("offer_"):
				_buy_offer(int(a.substr(6)))
			elif a.begins_with("mat_"):
				var m := a.substr(4)
				if Save.gold >= SHOP_MAT_PRICE:
					Save.gold -= SHOP_MAT_PRICE
					Save.materials[m] += 10
					Save.save_game()
					_toast("+10 %s" % Gear.MATERIALS[m].name)
				else:
					_toast("ORO INSUFFICIENTE")
	Save.save_game()

func _give(base: String, rar: int, why: String) -> void:
	var before: Array = Save.recipes.duplicate()
	var it := Save.add_item(base, rar)
	reveal = it
	reveal_msg = why
	for r in Save.recipes:
		if not r in before:
			reveal_msg = "NUOVA RICETTA: %s!" % Data.COMBOS[r][0]
	Save.save_game()

# =====================================================================
#  Negozio: dati
# =====================================================================
const SHOP_CHEST := 200
const SHOP_MAT_PRICE := 120

## 3 offerte del giorno, uguali per tutto il giorno (si vedono prima di comprare)
func _daily_offers() -> Array:
	if Save.shop_day != Save.today():
		Save.shop_day = Save.today()
		Save.shop_bought = []
		Save.save_game()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Save.today())
	var keys := Gear.BASES.keys()
	var l: Array = []
	var plan := [[1, "gold", 450], [2, "gems", 60], [3, "gems", 220]]
	for i in plan.size():
		var base: String = keys[rng.randi() % keys.size()]
		l.append({"base": base, "rar": plan[i][0], "cur": plan[i][1], "price": plan[i][2]})
	return l

func _buy_offer(i: int) -> void:
	if i in Save.shop_bought:
		return
	var o: Dictionary = _daily_offers()[i]
	var have: int = Save.gold if o.cur == "gold" else Save.gems
	if have < o.price:
		_toast("ORO INSUFFICIENTE" if o.cur == "gold" else "GEMME INSUFFICIENTI")
		return
	if o.cur == "gold":
		Save.gold -= o.price
	else:
		Save.gems -= o.price
	Save.shop_bought.append(i)
	_give(o.base, o.rar, "OFFERTA DEL GIORNO")

# =====================================================================
#  Disegno
# =====================================================================
func _draw() -> void:
	var s := _size()
	rects.clear()
	for i in 24:
		draw_rect(Rect2(0, s.y * i / 24.0, s.x, s.y / 24.0 + 1), Color("2b2350").lerp(Color("0a0816"), i / 23.0))
	for i in 18:
		var x := fmod(i * 53.0 + sin(i) * 30.0, s.x)
		var y := s.y - fmod(time * (8.0 + i % 5 * 3) + i * 71.0, s.y)
		Art.glow(self, Vector2(x, y), 4, Color(1, 0.6, 0.25, 0.4))
	match tab:
		"play": _draw_play()
		"equip": _draw_equip()
		"shop": _draw_shop()
	_draw_top()
	_draw_tabs()
	if detail_id != -1:
		_draw_detail()
	elif show_recipes:
		_draw_recipes()
	elif not reveal.is_empty():
		_draw_reveal()
	if toast_t > 0.0:
		var a := clampf(toast_t * 2.0, 0.0, 1.0)
		var y := s.y - TAB_H - 30
		draw_rect(Rect2(10, y - 5, s.x - 20, 17), Color(0, 0, 0, 0.8 * a))
		PixelFont.draw_centered(self, toast, s.x / 2.0, y, 1, Color(Art.GOLD, a))

func _draw_top() -> void:
	var s := _size()
	draw_rect(Rect2(0, 0, s.x, TOP_H), Color("1a1438"))
	draw_rect(Rect2(0, TOP_H - 1, s.x, 1), Color(1, 1, 1, 0.06))
	var x := 8.0
	x += Art.counter(self, "gold", Save.gold, Vector2(x, 7), Art.GOLD)
	x += Art.counter(self, "gem", Save.gems, Vector2(x, 7), Art.GEM)
	# materiali
	x += 2
	for m in ["bone", "stone", "ember"]:
		var md: Dictionary = Gear.MATERIALS[m]
		Art.icon(self, md.icon, Vector2(x, 6), 1.4, md.color)
		var t := str(Save.materials[m])
		PixelFont.draw_text(self, t, Vector2(x + 12, 7), 1, Color.WHITE)
		x += 16 + PixelFont.text_width(t, 1)
	# potere
	var pt := "Potere %d" % Save.gear_power()
	var pw := PixelFont.text_width(pt, 1) + 14
	var pr := Rect2(s.x - pw - 6, 4, pw, 16)
	Art.rbox(self, pr, Color("ff6a4a"), Color(0, 0, 0, 0), 8)
	PixelFont.draw_centered(self, pt, pr.get_center().x, pr.position.y + 3, 1, Color.WHITE)

func _draw_tabs() -> void:
	var s := _size()
	var y0 := s.y - TAB_H
	draw_rect(Rect2(0, y0, s.x, TAB_H), Color("120d26"))
	draw_rect(Rect2(0, y0, s.x, 1), Color(1, 1, 1, 0.1))
	var w := s.x / TABS.size()
	for i in TABS.size():
		var t: Array = TABS[i]
		var r := Rect2(i * w + 4, y0 + 4, w - 8, TAB_H - 8)
		rects["tab_" + t[0]] = r
		var on: bool = tab == t[0]
		if on:
			Art.rbox(self, r, Color("3d2d78"), Color(1, 0.83, 0.42, 0.35), 10, 1)
		var col := Color("ffd36b") if on else Color("a99cc9")
		Art.icon(self, t[2], Vector2(r.get_center().x - 7, r.position.y + 4), 2.0, col)
		PixelFont.draw_centered(self, PixelFont.nice(t[1]) if t[1] != "EQUIP" else "Eroe", r.get_center().x, r.position.y + 21, 1, col)

func _draw_play() -> void:
	var s := _size()
	var c := _content_rect()
	# anteprima della stanza (come la schermata di Braceforte 2)
	var room := Rect2(10, c.position.y + 8, s.x - 20, c.size.y - 16)
	Art.rbox(self, room, Color("2a201f"), Art.DARK, 6, 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var ts := 19.0
	var top := 24.0
	for y in int((room.size.y - top) / ts) + 1:
		for x in int(room.size.x / ts) + 1:
			var t := Rect2(room.position + Vector2(x * ts + 3, top + y * ts + 1), Vector2(ts - 2, ts - 2)).intersection(room.grow(-3))
			if t.size.x <= 0 or t.size.y <= 0:
				continue
			var base := Color("4a3c3a").lerp(Color("54443f"), rng.randf())
			draw_rect(t, base)
			draw_rect(Rect2(t.position, Vector2(t.size.x, 1.5)), base.lightened(0.12))
	var wall := Rect2(room.position.x + 2, room.position.y + 2, room.size.x - 4, top)
	draw_rect(wall, Color("4e3b38"))
	for row in 3:
		for k in 14:
			var bx := wall.position.x + k * 22 - (0 if row % 2 == 0 else 11)
			draw_rect(Rect2(bx, wall.position.y + row * 8, 1, 8).intersection(wall), Color(0, 0, 0, 0.3))
		draw_rect(Rect2(wall.position.x, wall.position.y + row * 8, wall.size.x, 1), Color(0, 0, 0, 0.3))
	for f in [0.15, 0.35, 0.65, 0.85]:
		var tp := Vector2(wall.position.x + wall.size.x * f, wall.position.y + 11)
		Art.glow(self, tp, 18, Color(1, 0.6, 0.25, 0.5))
		draw_circle(tp, 2.5, Color("ffb03a"))
	var gc := Vector2(s.x / 2.0, wall.position.y + 12)
	draw_circle(gc, 18, Art.DARK)
	draw_circle(gc, 15, Color("120a0a"))
	draw_rect(Rect2(gc.x - 15, gc.y, 30, wall.end.y - gc.y), Color("120a0a"))
	for i in 5:
		draw_line(Vector2(gc.x - 12 + i * 6, gc.y - 10), Vector2(gc.x - 12 + i * 6, wall.end.y), Color("6a6070"), 2.0, true)
	# eroe al centro
	var hp := Vector2(s.x / 2.0, room.position.y + room.size.y * 0.45)
	_mini_hero(hp, 1.6)
	# testo e pulsante in basso, su una sfumatura scura
	var fy := room.end.y - 150
	for i in 10:
		draw_rect(Rect2(room.position.x + 2, fy + i * 15, room.size.x - 4, 15), Color(0.04, 0.03, 0.09, 0.08 * i))
	PixelFont.draw_centered(self, "Capitolo 1", s.x / 2.0, fy + 20, 3, Color.WHITE, Art.DARK)
	PixelFont.draw_centered(self, "La Fonderia caduta", s.x / 2.0, fy + 48, 1, Color("c9b8ff"))
	var rec := "Record: stanza %d/12 · vittorie %d" % [Save.best_room, Save.wins]
	PixelFont.draw_centered(self, rec, s.x / 2.0, fy + 64, 1, Color("ffd36b"))
	var pr := Rect2(s.x / 2.0 - 100, fy + 84, 200, 46)
	rects["play"] = pr
	Art.glow(self, pr.get_center(), 110, Color(1, 0.5, 0.1, 0.25))
	Art.button(self, pr, "", Color("ff8a1a"), true)
	PixelFont.draw_centered(self, "COMBATTI!", pr.get_center().x, pr.position.y + 6, 3, Color.WHITE, Color(0.5, 0.2, 0, 0.5))
	var w := Save.run_weapons()
	PixelFont.draw_centered(self, "12 stanze + boss · %s e %s" % [PixelFont.nice(Data.WEAPONS[w[0]].name), PixelFont.nice(Data.WEAPONS[w[1]].name).to_lower()], pr.get_center().x, pr.position.y + 30, 1, Color(1, 1, 1, 0.9))

func _mini_hero(c: Vector2, k: float) -> void:
	var r := 8.5 * k
	draw_set_transform(c + Vector2(0, r * 0.9), 0, Vector2(1, 0.38))
	draw_circle(Vector2.ZERO, r, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)
	draw_circle(c + Vector2(0, 2 * k), r + 1.6 * k, Art.DARK)
	draw_circle(c + Vector2(0, 2 * k), r, Color("3d3a5c"))
	draw_circle(c + Vector2(0, (r * 0.5 + 2) * 1.0), 1.6 * k, Art.GOLD)
	var hc := c + Vector2(0, -r * 0.35)
	draw_circle(hc, r * 0.82 + 1.6 * k, Art.DARK)
	draw_circle(hc, r * 0.82, Color("5a5f7a"))
	draw_circle(hc + Vector2(-r * 0.25, -r * 0.3), r * 0.25, Color(1, 1, 1, 0.35))
	Art.rbox(self, Rect2(hc.x - r * 0.6, hc.y + 2 * k, r * 1.2, 4 * k), Art.DARK, Color(0, 0, 0, 0), 3)
	draw_circle(hc + Vector2(-2.2, 3) * k, 0.9 * k, Color("ffd36b"))
	draw_circle(hc + Vector2(2.2, 3) * k, 0.9 * k, Color("ffd36b"))
	var fl := sin(time * 10.0)
	var pts := PackedVector2Array([hc + Vector2(-1.5 * k, -r * 0.75), hc + Vector2(1 * k, -r * 1.55 + fl), hc + Vector2(4.5 * k, -r * 1.1 - fl), hc + Vector2(2.5 * k, -r * 0.7)])
	var q := pts.duplicate()
	q.append(pts[0])
	draw_polyline(q, Art.DARK, 2.0, true)
	draw_colored_polygon(pts, Color("ff5a2a"))

func _slot_rects() -> Dictionary:
	var s := _size()
	var y0 := TOP_H + 26
	var bs := 30.0
	var step := 44.0
	var left := ["weapon1", "helmet", "armor", "gloves"]
	var right := ["weapon2", "boots", "ring"]
	var d := {}
	for i in left.size():
		d[left[i]] = Rect2(12, y0 + i * step, bs, bs)
	for i in right.size():
		d[right[i]] = Rect2(s.x - 12 - bs, y0 + i * step, bs, bs)
	return d

func _draw_equip() -> void:
	var s := _size()
	var c := _content_rect()
	PixelFont.draw_text(self, "EQUIPAGGIAMENTO", Vector2(12, TOP_H + 8), 1, Art.SPARK)
	var rr := Rect2(s.x - 80, TOP_H + 4, 70, 15)
	rects["recipes"] = rr
	Art.button(self, rr, "RICETTE", Color("7a4ad0"))
	# eroe al centro
	var hc := Vector2(s.x / 2.0, TOP_H + 70)
	Art.glow(self, hc, 46, Color(1, 0.5, 0.2, 0.25))
	_mini_hero(hc + Vector2(0, 2), 1.7)
	PixelFont.draw_centered(self, "LA FABBRA", hc.x, hc.y + 24, 1, Color.WHITE)
	# statistiche
	var b := Save.bonuses()
	var st := [
		["VITA", str(120 + int(b.hp))],
		["CRITICO", "%d%%" % int(round(b.crit * 100))],
		["VEL. ATTACCO", "+%d%%" % int(round(b.aspd_pct * 100))],
		["VELOCITA", "+%d%%" % int(round(b.speed_pct * 100))],
	]
	var sy := hc.y + 38
	for i in st.size():
		PixelFont.draw_text(self, st[i][0], Vector2(hc.x - 54, sy + i * 10), 1, Art.TEXT_DIM)
		PixelFont.draw_text(self, st[i][1], Vector2(hc.x + 54 - PixelFont.text_width(st[i][1], 1), sy + i * 10), 1, Color.WHITE)
	# posti
	var sr := _slot_rects()
	for slot in sr:
		var r: Rect2 = sr[slot]
		rects["slot_" + slot] = r
		var it := Save.equipped_item(slot)
		if it.is_empty():
			Art.panel(self, r, Color("1a1214"), Color("3a2a2a"))
			var icon_name: String = "sword" if slot.begins_with("weapon") else slot
			Art.icon(self, icon_name, r.get_center() - Vector2(7, 7), 2, Color("3a2a2a"))
		else:
			Art.item_box(self, it, r)
		var label: String = Gear.SLOT_NAME[slot]
		var lx := r.position.x if r.position.x < s.x / 2.0 else r.end.x - PixelFont.text_width(label, 1)
		PixelFont.draw_text(self, label, Vector2(lx, r.end.y + 3), 1, Art.TEXT_DIM)
	# inventario
	var inv := Save.inventory()
	var iy := TOP_H + 26 + 4 * 44 + 6
	draw_rect(Rect2(0, iy - 4, s.x, 1), Color("3a2a2a"))
	PixelFont.draw_text(self, "INVENTARIO (%d)" % inv.size(), Vector2(12, iy + 2), 1, Color.WHITE)
	var cols := 6
	var box := 34.0
	var gap := (s.x - 24 - cols * box) / (cols - 1)
	var rows := maxi(1, int((c.end.y - (iy + 16) - 4) / (box + gap)))
	var per := cols * rows
	var pages := maxi(1, int(ceil(inv.size() / float(per))))
	inv_page = clampi(inv_page, 0, pages - 1)
	if pages > 1:
		var pt := "%d/%d" % [inv_page + 1, pages]
		PixelFont.draw_text(self, pt, Vector2(s.x - 58 - PixelFont.text_width(pt, 1) / 2.0, iy + 2), 1, Art.TEXT_DIM)
		var r1 := Rect2(s.x - 90, iy - 2, 18, 15)
		var r2 := Rect2(s.x - 30, iy - 2, 18, 15)
		rects["inv_prev"] = r1
		rects["inv_next"] = r2
		Art.button(self, r1, "(", Color("5a4a6a"), inv_page > 0)
		Art.button(self, r2, ")", Color("5a4a6a"), inv_page < pages - 1)
	if inv.is_empty():
		PixelFont.draw_centered(self, "VUOTO: I PEZZI SI TROVANO NEL NEGOZIO", s.x / 2.0, iy + 30, 1, Art.TEXT_DIM)
		PixelFont.draw_centered(self, "E BATTENDO MINI-BOSS E BOSS", s.x / 2.0, iy + 42, 1, Art.TEXT_DIM)
	for i in range(inv_page * per, mini(inv.size(), (inv_page + 1) * per)):
		var k := i - inv_page * per
		var r := Rect2(12 + (k % cols) * (box + gap), iy + 16 + int(k / cols) * (box + gap), box, box)
		var it: Dictionary = inv[i]
		rects["inv_%d" % it.id] = r
		Art.item_box(self, it, r)
		if Save.can_merge(it):
			draw_rect(Rect2(r.position.x + 1, r.position.y + 1, 5, 5), Art.GOLD)

func _draw_detail() -> void:
	var s := _size()
	var it := Save.get_item(detail_id)
	if it.is_empty():
		detail_id = -1
		return
	draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.65))
	var rar: Dictionary = Gear.RARITY[it.rar]
	var pr := Rect2(12, 50, s.x - 24, 330)
	rects["block"] = pr
	Art.panel(self, pr, Color("1e1416"), rar.color)
	Art.item_box(self, it, Rect2(pr.position.x + 10, pr.position.y + 10, 44, 44))
	var tx := pr.position.x + 62
	PixelFont.draw_text(self, Gear.item_name(it), Vector2(tx, pr.position.y + 12), 1, Color.WHITE)
	PixelFont.draw_text(self, rar.name, Vector2(tx, pr.position.y + 24), 1, rar.color)
	PixelFont.draw_text(self, "LIVELLO %d/%d" % [it.lv, rar.max_lv], Vector2(tx, pr.position.y + 36), 1, Art.TEXT_DIM)
	var slot := Save.slot_of(it.id)
	if slot != "":
		PixelFont.draw_text(self, "INDOSSATO: " + Gear.SLOT_NAME[slot], Vector2(tx, pr.position.y + 48), 1, Color("7dff5a"))
	var y := pr.position.y + 66
	var t := Gear.type_of(it)
	if t == "weapon":
		var wd: Dictionary = Data.WEAPONS[Gear.BASES[it.base].weapon]
		PixelFont.draw_text(self, wd.desc[0] + ", " + wd.desc[1], Vector2(pr.position.x + 10, y), 1, Art.TEXT_DIM)
		y += 12
		if wd.desc.size() > 2:
			PixelFont.draw_text(self, wd.desc[2], Vector2(pr.position.x + 10, y), 1, Art.GOLD)
			y += 12
		y += 2
	PixelFont.draw_text(self, Gear.stat_text(it), Vector2(pr.position.x + 10, y), 2, Color.WHITE)
	y += 22
	# bonus per rarità (quelli non ancora raggiunti in grigio)
	var lines := []
	var rb: Array = Gear.RARE_BONUS[t]
	lines.append([2, "RARO: " + rb[0]])
	var recipe: String = Gear.BASES[it.base].get("recipe", "")
	if recipe != "":
		lines.append([3, "EPICO: RICETTA " + Data.COMBOS[recipe][0]])
	lines.append([4, "LEGG.: " + Gear.LEGEND[t][0]])
	for l in lines:
		var ok: bool = it.rar >= l[0]
		var col: Color = Gear.RARITY[l[0]].color if ok else Color("5a4a4a")
		y = _wrap(l[1], Vector2(pr.position.x + 10, y), pr.size.x - 20, col) + 3
	y += 4
	# costi
	var cost := Gear.upgrade_cost(it)
	var maxed: bool = it.lv >= rar.max_lv
	var bw := (pr.size.x - 30) / 2.0
	var by := pr.end.y - 104
	var up := Rect2(pr.position.x + 10, by, bw, 26)
	rects["upgrade"] = up
	Art.button(self, up, "MASSIMO" if maxed else "MIGLIORA", Color("3a8a4a"), Save.can_upgrade(it))
	if not maxed:
		var md: Dictionary = Gear.MATERIALS[cost[1]]
		var ct := "%d  %d" % [cost[0], cost[2]]
		var cx := up.get_center().x - PixelFont.text_width(ct, 1) / 2.0
		Art.icon(self, "gold", Vector2(cx - 10, up.end.y + 4), 1, Art.GOLD)
		PixelFont.draw_text(self, str(cost[0]), Vector2(cx, up.end.y + 4), 1, Color.WHITE if Save.gold >= cost[0] else Art.HP)
		var mx := cx + PixelFont.text_width(str(cost[0]) + "  ", 1)
		Art.icon(self, md.icon, Vector2(mx, up.end.y + 4), 1, md.color)
		PixelFont.draw_text(self, str(cost[2]), Vector2(mx + 10, up.end.y + 4), 1, Color.WHITE if Save.materials[cost[1]] >= cost[2] else Art.HP)
	var mg := Rect2(up.end.x + 10, by, bw, 26)
	rects["merge"] = mg
	var partners := Save.merge_partners(it).size()
	var can_m := Save.can_merge(it)
	Art.button(self, mg, "UNISCI %d/3" % (partners + 1) if it.rar < 4 else "MASSIMA", Color("b866ff"), can_m)
	if it.rar < 4:
		PixelFont.draw_centered(self, "3 UGUALI = " + Gear.RARITY[it.rar + 1].name, mg.get_center().x, mg.end.y + 4, 1, Art.TEXT_DIM)
	by += 44
	if t == "weapon":
		var e1 := Rect2(pr.position.x + 10, by, bw, 24)
		var e2 := Rect2(e1.end.x + 10, by, bw, 24)
		rects["equip1"] = e1
		rects["equip2"] = e2
		Art.button(self, e1, "IN ARMA 1", Color("e0661f"), slot != "weapon1")
		Art.button(self, e2, "IN ARMA 2", Color("e0661f"), slot != "weapon2")
	elif slot == "":
		var e := Rect2(pr.position.x + 10, by, bw, 24)
		rects["equip"] = e
		Art.button(self, e, "INDOSSA", Color("e0661f"))
		var sl := Rect2(e.end.x + 10, by, bw, 24)
		rects["sell"] = sl
		Art.button(self, sl, "VENDI %d" % Save.sell_value(it), Color("8a6a30"))
	else:
		var u := Rect2(pr.position.x + 10, by, bw, 24)
		rects["unequip"] = u
		Art.button(self, u, "TOGLI", Color("8a3030"))
	if t == "weapon" and slot == "":
		pass
	var cr := Rect2(pr.get_center().x - 40, pr.end.y - 30, 80, 22)
	rects["close"] = cr
	Art.button(self, cr, "CHIUDI", Color("5a4a6a"))

func _draw_recipes() -> void:
	var s := _size()
	draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.65))
	var pr := Rect2(12, 50, s.x - 24, 300)
	rects["block"] = pr
	Art.panel(self, pr, Color("1e1416"), Color("b866ff"))
	PixelFont.draw_centered(self, "RICETTE DELLA FORGIA", s.x / 2.0, pr.position.y + 10, 1, Color("d8b0ff"))
	PixelFont.draw_centered(self, "2 ELEMENTI DIVERSI NELLA STESSA ARMA", s.x / 2.0, pr.position.y + 22, 1, Art.TEXT_DIM)
	var y := pr.position.y + 40
	for key in Data.COMBOS:
		var known: bool = key in Save.recipes
		var els: PackedStringArray = key.split("+")
		Art.el_icon(self, els[0], Vector2(pr.position.x + 10, y), 1)
		PixelFont.draw_text(self, "+", Vector2(pr.position.x + 20, y), 1, Art.TEXT_DIM)
		Art.el_icon(self, els[1], Vector2(pr.position.x + 28, y), 1)
		if known:
			PixelFont.draw_text(self, Data.COMBOS[key][0], Vector2(pr.position.x + 42, y), 1, Color.WHITE)
			PixelFont.draw_text(self, Data.COMBOS[key][1], Vector2(pr.position.x + 42, y + 10), 1, Art.TEXT_DIM)
		else:
			PixelFont.draw_text(self, "???", Vector2(pr.position.x + 42, y), 1, Art.TEXT_DIM)
			var src := ""
			for b in Gear.BASES:
				if Gear.BASES[b].get("recipe", "") == key:
					src = Gear.BASES[b].name
			PixelFont.draw_text(self, "DA: " + src + " EPICO", Vector2(pr.position.x + 42, y + 10), 1, Color("8a6aa0"))
		y += 34
	var cr := Rect2(pr.get_center().x - 40, pr.end.y - 30, 80, 22)
	rects["close"] = cr
	Art.button(self, cr, "CHIUDI", Color("5a4a6a"))

func _draw_reveal() -> void:
	var s := _size()
	draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.75))
	var rar: Dictionary = Gear.RARITY[reveal.rar]
	var c := Vector2(s.x / 2.0, s.y * 0.38)
	for i in 3:
		draw_circle(c, 60 - i * 15, Color(rar.color, 0.08 + 0.04 * sin(time * 3.0)))
	for i in 12:
		var a := time * 0.6 + TAU * i / 12.0
		draw_line(c + Vector2.from_angle(a) * 30, c + Vector2.from_angle(a) * 70, Color(rar.color, 0.25), 1.0)
	PixelFont.draw_centered(self, reveal_msg, c.x, c.y - 90, 1, Art.GOLD)
	Art.item_box(self, reveal, Rect2(c - Vector2(26, 26), Vector2(52, 52)))
	PixelFont.draw_centered(self, rar.name, c.x, c.y + 40, 2, rar.color, Art.DARK)
	PixelFont.draw_centered(self, Gear.item_name(reveal), c.x, c.y + 62, 1, Color.WHITE)
	PixelFont.draw_centered(self, Gear.stat_text(reveal), c.x, c.y + 76, 1, Art.TEXT_DIM)
	var cr := Rect2(c.x - 50, c.y + 100, 100, 24)
	rects["close"] = cr
	Art.button(self, cr, "OK", Color("e0661f"))

# ---------------------------------------------------------------------
#  NEGOZIO
# ---------------------------------------------------------------------
func _draw_shop() -> void:
	var s := _size()
	var c := _content_rect()
	var y := c.position.y + 8 - scroll
	var x0 := 12.0
	var w := s.x - 24
	# regalo del giorno
	var g := Rect2(x0, y, w, 46)
	var gift_ok := Save.gift_day != Save.today()
	Art.panel(self, g, Color("1e2a1c") if gift_ok else Art.PANEL, Color("5ad06a") if gift_ok else Art.PANEL_EDGE)
	Art.icon(self, "chest", g.position + Vector2(8, 12), 3, Color("5ad06a") if gift_ok else Art.TEXT_DIM)
	PixelFont.draw_text(self, "REGALO DEL GIORNO", g.position + Vector2(38, 10), 1, Color.WHITE)
	PixelFont.draw_text(self, "UN PEZZO + 50 ORO, GRATIS", g.position + Vector2(38, 22), 1, Art.TEXT_DIM)
	var gb := Rect2(g.end.x - 66, g.position.y + 12, 58, 22)
	_btn("gift", gb, "RITIRA" if gift_ok else "DOMANI", Color("3a8a4a"), gift_ok, c)
	y += 54
	# cassa
	var ch := Rect2(x0, y, w, 62)
	Art.panel(self, ch)
	Art.icon(self, "chest", ch.position + Vector2(8, 12), 3, Color("c9a27a"))
	PixelFont.draw_text(self, "CASSA DEL FABBRO", ch.position + Vector2(38, 8), 1, Color.WHITE)
	PixelFont.draw_text(self, "UN PEZZO A CASO", ch.position + Vector2(38, 20), 1, Art.TEXT_DIM)
	var ox := ch.position.x + 38
	for i in 4:
		var t := "%d%%" % int(Gear.CHEST_ODDS[i])
		PixelFont.draw_text(self, t, Vector2(ox, ch.position.y + 34), 1, Gear.RARITY[i].color)
		ox += PixelFont.text_width(t, 1) + 8
	PixelFont.draw_text(self, "PROBABILITA PER RARITA", Vector2(ch.position.x + 38, ch.position.y + 46), 1, Color("6e5a55"))
	var cb := Rect2(ch.end.x - 66, ch.position.y + 12, 58, 22)
	_btn("chest", cb, "%d ORO" % SHOP_CHEST, Color("e0661f"), Save.gold >= SHOP_CHEST, c)
	y += 70
	# offerte del giorno
	PixelFont.draw_text(self, "OFFERTE DEL GIORNO", Vector2(x0, y), 1, Art.SPARK)
	PixelFont.draw_text(self, "CAMBIANO OGNI GIORNO", Vector2(s.x - 12 - PixelFont.text_width("CAMBIANO OGNI GIORNO", 1), y), 1, Art.TEXT_DIM)
	y += 12
	var offers := _daily_offers()
	var ow := (w - 8) / 3.0
	for i in offers.size():
		var o: Dictionary = offers[i]
		var r := Rect2(x0 + i * (ow + 4), y, ow, 92)
		var it := {"base": o.base, "rar": o.rar, "lv": 1}
		var sold: bool = i in Save.shop_bought
		Art.panel(self, r, Art.PANEL, Gear.RARITY[o.rar].color.darkened(0.3))
		Art.item_box(self, it, Rect2(r.get_center().x - 16, r.position.y + 6, 32, 32))
		PixelFont.draw_centered(self, Gear.RARITY[o.rar].name, r.get_center().x, r.position.y + 42, 1, Gear.RARITY[o.rar].color)
		var nm: String = Gear.item_name(it)
		var words := nm.split(" ")
		PixelFont.draw_centered(self, words[0], r.get_center().x, r.position.y + 53, 1, Color.WHITE)
		if words.size() > 1:
			PixelFont.draw_centered(self, " ".join(words.slice(1)).substr(0, 12), r.get_center().x, r.position.y + 62, 1, Color.WHITE)
		var br := Rect2(r.position.x + 4, r.end.y - 20, r.size.x - 8, 16)
		var label := "PRESO" if sold else "%d %s" % [o.price, "ORO" if o.cur == "gold" else "GEMME"]
		var have: int = Save.gold if o.cur == "gold" else Save.gems
		_btn("offer_%d" % i, br, label, Color("e0661f") if o.cur == "gold" else Color("2a8ab0"), not sold and have >= o.price, c)
	y += 100
	# materiali
	PixelFont.draw_text(self, "MATERIALI (PER MIGLIORARE I PEZZI)", Vector2(x0, y), 1, Art.SPARK)
	y += 12
	var mw := (w - 8) / 3.0
	var mi := 0
	for m in ["bone", "stone", "ember"]:
		var md: Dictionary = Gear.MATERIALS[m]
		var r := Rect2(x0 + mi * (mw + 4), y, mw, 50)
		Art.panel(self, r)
		Art.icon(self, md.icon, Vector2(r.position.x + 6, r.position.y + 6), 2, md.color)
		PixelFont.draw_text(self, "10 " + md.name, Vector2(r.position.x + 24, r.position.y + 10), 1, Color.WHITE)
		_btn("mat_" + m, Rect2(r.position.x + 4, r.end.y - 20, r.size.x - 8, 16), "%d ORO" % SHOP_MAT_PRICE, Color("e0661f"), Save.gold >= SHOP_MAT_PRICE, c)
		mi += 1
	y += 58
	# segnaposto
	for t in [["PASS STAGIONALE", "PREMI EXTRA OGNI STAGIONE"], ["GEMME E COSTUMI", "ACQUISTI CON SOLDI VERI"]]:
		var r := Rect2(x0, y, w, 34)
		Art.panel(self, r, Color("1a1214"), Color("3a2a2a"))
		Art.icon(self, "lock", r.position + Vector2(8, 10), 2, Art.TEXT_DIM)
		PixelFont.draw_text(self, t[0] + " - IN ARRIVO", r.position + Vector2(30, 8), 1, Art.TEXT_DIM)
		PixelFont.draw_text(self, t[1], r.position + Vector2(30, 20), 1, Color("6e5a55"))
		y += 40
	scroll_max = maxf(0.0, (y + scroll) - c.end.y + 8)

## Pulsante che funziona solo se è visibile nell'area del contenuto
func _btn(action: String, r: Rect2, text: String, col: Color, enabled: bool, area: Rect2) -> void:
	if r.end.y < area.position.y or r.position.y > area.end.y:
		return
	if enabled and area.encloses(r):
		rects[action] = r
	Art.button(self, r, text, col, enabled)

func _wrap(t: String, pos: Vector2, max_w: float, col: Color) -> float:
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
