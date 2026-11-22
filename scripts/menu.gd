extends Node2D
## Home del gioco: barra in basso con 5 sezioni (Negozio, Armeria, Battaglia,
## Talenti, Codice), barra in alto con profilo e valute. Stile "Forgia oscura".

const TOP_H := 40.0
const NAV_H := 58.0
const TABS := [
	["shop", "Negozio", "shop"],
	["armory", "Armeria", "helmet"],
	["battle", "Battaglia", "sword"],
	["talents", "Talenti", "anvil"],
	["codex", "Codice", "book"],
]
const SHOP_CHEST := 200
const SHOP_GEM_CHEST := 120
const GEM_CHEST_ODDS := [0.0, 50.0, 35.0, 13.0, 2.0]
const SHOP_MAT_PRICE := 120
const CHAPTERS := [
	["La Fonderia caduta", true],
	["Le Miniere di Scoria", false],
	["Il Trono di Cenere", false],
]

var tab := "battle"
var time := 0.0
var rects := {}
var scroll := 0.0
var scroll_max := 0.0
var inv_page := 0
var chapter := 0
var tab_anim := 0.0

var detail_id := -1
var reveal := {}
var reveal_msg := ""
var reveal_t := 0.0
var toast := ""
var toast_t := 0.0

var press_pos := Vector2.ZERO
var press_scroll := 0.0
var dragging := false
var touching := false
var mtip := {}                # consiglio del tutorial nel menu
var mtip_t := 0.0
var swallow := false

const MENU_TIPS := {
	"battle": ["Benvenuto, Fabbro", "Questa è la tua base. Tocca COMBATTI per entrare nella Fonderia caduta: 12 stanze, un mini-boss e il Signore della Cenere."],
	"armory": ["Armeria", "Tocca un pezzo dell'inventario per equipaggiarlo o potenziarlo con oro e materiali. L'equipaggiamento resta per sempre."],
	"shop": ["Mercato", "Ritira il regalo ogni giorno e apri le casse per trovare equipaggiamento nuovo e più raro."],
	"talents": ["Talenti", "Spendi oro per potenziamenti permanenti: valgono in ogni partita."],
	"codex": ["Codice della forgia", "Due elementi diversi nella stessa arma creano un effetto speciale: qui trovi le ricette. Sotto, la debolezza di ogni famiglia di nemici."],
}

func _ready() -> void:
	Sfx.music_on()
	if Save.has_meta("menu_tab"):
		tab = Save.get_meta("menu_tab")
		if not tab in ["shop", "armory", "battle", "talents", "codex"]:
			tab = "battle"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("q=tab="):
			tab = a.substr(6)

func _process(delta: float) -> void:
	time += delta
	toast_t -= delta
	reveal_t += delta
	tab_anim = minf(1.0, tab_anim + delta * 5.0)
	mtip_t += delta
	if mtip.is_empty() and not _overlay_open() and tab_anim >= 1.0 and not Coach.seen("m_" + tab) and MENU_TIPS.has(tab):
		mtip = {"id": "m_" + tab, "title": MENU_TIPS[tab][0], "text": MENU_TIPS[tab][1], "block": true}
		if tab == "battle" and rects.has("play"):
			mtip.target = (rects["play"] as Rect2).get_center()
		mtip_t = 0.0
	queue_redraw()

func _size() -> Vector2:
	return get_viewport_rect().size

func _content() -> Rect2:
	var s := _size()
	return Rect2(0, TOP_H, s.x, s.y - TOP_H - NAV_H)

func _toast(t: String) -> void:
	toast = t
	toast_t = 2.2

# =====================================================================
#  Input
# =====================================================================
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if not mtip.is_empty():
			if event.pressed and mtip_t > 0.4:
				Coach.mark(str(mtip.id))
				mtip = {}
				swallow = true
			return
		if swallow:
			if not event.pressed:
				swallow = false
			return
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
		if dragging and (tab == "shop" or tab == "codex") and not _overlay_open():
			scroll = clampf(press_scroll - dy, 0.0, scroll_max)

func _overlay_open() -> bool:
	return detail_id != -1 or not reveal.is_empty()

func _tap(p: Vector2) -> void:
	var keys := rects.keys()
	keys.reverse()
	for k in keys:
		if rects[k].has_point(p):
			Sfx.play("click", 0.0)
			_action(k)
			return
	if _overlay_open():
		detail_id = -1
		reveal = {}

func _action(a: String) -> void:
	if a.begins_with("tab_"):
		var nt := a.substr(4)
		if nt != tab:
			tab = nt
			tab_anim = 0.0
			Save.set_meta("menu_tab", tab)
			scroll = 0.0
		return
	match a:
		"block":
			return
		"play":
			if CHAPTERS[chapter][1]:
				Sfx.play("clang", 0.0)
				get_tree().change_scene_to_file("res://scenes/game.tscn")
			else:
				_toast("CAPITOLO IN ARRIVO")
		"ch_prev":
			chapter = maxi(0, chapter - 1)
		"ch_next":
			chapter = mini(CHAPTERS.size() - 1, chapter + 1)
		"close":
			detail_id = -1
			reveal = {}
		"inv_prev":
			inv_page = maxi(0, inv_page - 1)
		"inv_next":
			inv_page += 1
		"equip", "equip1", "equip2":
			Save.equip(detail_id, "weapon2" if a == "equip2" else "weapon1")
			Sfx.play("clang", 0.05)
			detail_id = -1
		"unequip":
			var it := Save.get_item(detail_id)
			Save.unequip(Save.slot_of(it.id))
			detail_id = -1
		"upgrade":
			var it := Save.get_item(detail_id)
			if Save.upgrade(it):
				Sfx.play("clang", 0.05)
				_toast("LIVELLO %d!" % it.lv)
			else:
				_toast("ORO O MATERIALI INSUFFICIENTI")
		"merge":
			var it := Save.get_item(detail_id)
			var r := Save.merge(it)
			Sfx.play("level", 0.0)
			_toast("ORA E %s!" % Gear.RARITY[it.rar].name)
			if r != "":
				_toast("NUOVA RICETTA: %s!" % Data.COMBOS[r][0])
		"sell":
			var it := Save.get_item(detail_id)
			var v := Save.sell_value(it)
			Save.sell(it)
			Sfx.play("coin", 0.0)
			_toast("VENDUTO: +%d ORO" % v)
			detail_id = -1
		"gift":
			if Save.gift_day != Save.today():
				Save.gift_day = Save.today()
				Save.gold += 50
				_give(Gear.random_base(), Gear.roll_rarity([70.0, 25.0, 5.0, 0.0, 0.0]), "REGALO DEL GIORNO")
		"chest":
			if Save.gold >= SHOP_CHEST:
				Save.gold -= SHOP_CHEST
				_give(Gear.random_base(), Gear.roll_rarity(Gear.CHEST_ODDS), "CASSA DI FERRO")
			else:
				_toast("ORO INSUFFICIENTE")
		"gemchest":
			if Save.gems >= SHOP_GEM_CHEST:
				Save.gems -= SHOP_GEM_CHEST
				_give(Gear.random_base(), Gear.roll_rarity(GEM_CHEST_ODDS), "CASSA DEL RE")
			else:
				_toast("GEMME INSUFFICIENTI")
		_:
			if a.begins_with("slot_"):
				var it := Save.equipped_item(a.substr(5))
				if not it.is_empty():
					detail_id = it.id
				else:
					_toast("POSTO VUOTO: TROVA PEZZI NEL NEGOZIO")
			elif a.begins_with("inv_"):
				detail_id = int(a.substr(4))
			elif a.begins_with("offer_"):
				_buy_offer(int(a.substr(6)))
			elif a.begins_with("mat_"):
				var m := a.substr(4)
				if Save.gold >= SHOP_MAT_PRICE:
					Save.gold -= SHOP_MAT_PRICE
					Save.materials[m] += 10
					Sfx.play("coin", 0.0)
					_toast("+10 %s" % Gear.MATERIALS[m].name)
				else:
					_toast("ORO INSUFFICIENTE")
			elif a.begins_with("tal_"):
				var tk := a.substr(4)
				var lv := int(Save.talents.get(tk, 0))
				var cost := Data.talent_cost(lv)
				if lv >= int(Data.TALENTS[tk].max):
					_toast("TALENTO AL MASSIMO")
				elif Save.gold < cost:
					_toast("ORO INSUFFICIENTE")
				else:
					Save.gold -= cost
					Save.talents[tk] = lv + 1
					Sfx.play("level", 0.0)
					_toast("%s: LIVELLO %d" % [Data.TALENTS[tk].name.to_upper(), lv + 1])
	Save.save_game()

func _give(base: String, rar: int, why: String) -> void:
	var before: Array = Save.recipes.duplicate()
	var it := Save.add_item(base, rar)
	reveal = it
	reveal_msg = why
	reveal_t = 0.0
	Sfx.play("level" if rar >= 2 else "clang", 0.0)
	for r in Save.recipes:
		if not r in before:
			reveal_msg = "NUOVA RICETTA: %s!" % Data.COMBOS[r][0]
	Save.save_game()

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
#  Disegno: base
# =====================================================================
func _rect(r: Rect2, top: Color, bottom: Color) -> void:
	Art.grad_poly(self, PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), top, bottom)

func _draw() -> void:
	var s := _size()
	rects.clear()
	_rect(Rect2(0, 0, s.x, s.y), Color("15121a"), Color("060508"))
	# trama di fondo: lastre e braci che salgono
	for i in 9:
		draw_line(Vector2(0, TOP_H + i * 60), Vector2(s.x, TOP_H + i * 60 + 20), Color(1, 1, 1, 0.015), 1.0)
	for i in 22:
		var x := fmod(i * 53.0 + sin(i) * 30.0, s.x)
		var y := s.y - fmod(time * (7.0 + i % 5 * 3) + i * 71.0, s.y)
		Art.glow(self, Vector2(x, y), 4, Color(1, 0.5, 0.15, 0.35))
	var slide := (1.0 - tab_anim) * 16.0
	draw_set_transform(Vector2(0, slide))
	match tab:
		"battle": _draw_battle()
		"armory": _draw_armory()
		"shop": _draw_shop()
		"talents": _draw_talents()
		"codex": _draw_codex()
	draw_set_transform(Vector2.ZERO)
	_draw_top()
	_draw_nav()
	if detail_id != -1:
		_draw_detail()
	elif not reveal.is_empty():
		_draw_reveal()
	if toast_t > 0.0:
		var a := clampf(toast_t * 2.0, 0.0, 1.0)
		var y := s.y - NAV_H - 34
		var tw := PixelFont.text_width(toast, 1) + 30
		var r := Rect2(s.x / 2.0 - tw / 2.0, y - 6, tw, 22)
		var pts := Art.cut_pts(r, 6)
		draw_colored_polygon(pts, Color(0.05, 0.04, 0.06, 0.92 * a))
		Art.outline(self, pts, Color(Art.GOLD, a), 1.0)
		PixelFont.draw_centered(self, toast, s.x / 2.0, y, 1, Color(Art.GOLD_L, a))
	if not mtip.is_empty():
		Coach.draw(self, s, mtip, mtip_t, TOP_H, s.y - NAV_H)

func _draw_top() -> void:
	var s := _size()
	_rect(Rect2(0, 0, s.x, TOP_H), Color("24202a"), Color("0e0c12"))
	draw_line(Vector2(0, TOP_H - 1), Vector2(s.x, TOP_H - 1), Color("57525f"), 1.0)
	draw_line(Vector2(0, TOP_H), Vector2(s.x, TOP_H), Art.INK, 1.0)
	# profilo: medaglione con l'elmo del Fabbro
	var c := Vector2(21, 20)
	var hex := PackedVector2Array()
	for i in 6:
		hex.append(c + Vector2.from_angle(-PI / 2 + i * TAU / 6.0) * 16)
	Art.grad_poly(self, hex, Color("3a3442"), Color("16131a"))
	Art.outline(self, hex, Art.INK, 2.5)
	Art.outline(self, hex, Art.GOLD, 1.0)
	HeroArt.draw(self, c + Vector2(0, 27), Vector2.DOWN, time, 0.0, false, "", Color.WHITE, 0.0, 1.05)
	PixelFont.draw_text(self, "Il Fabbro", Vector2(42, 5), 2, Art.TEXT, Color(0, 0, 0, 0.5))
	Art.icon(self, "sword", Vector2(42, 24), 1.3, Art.MOLTEN_L)
	PixelFont.draw_text(self, "Potere %d" % Save.gear_power(), Vector2(53, 24), 1, Art.GOLD_L)
	var x := s.x - 8
	for item in [["gem", Save.gems, Art.GEM], ["gold", Save.gold, Art.GOLD]]:
		var t := str(item[1])
		var w := 30.0 + PixelFont.text_width(t, 1)
		x -= w
		var r := Rect2(x, 11, w, 18)
		var pts := Art.cut_pts(r, 5)
		draw_colored_polygon(pts, Color(0, 0, 0, 0.6))
		Art.outline(self, pts, Color("4a4450"), 1.0)
		Art.icon(self, item[0], Vector2(x + 4, 13.5), 1.8, item[2])
		PixelFont.draw_text(self, t, Vector2(x + 20, 15), 1, Art.TEXT)
		x -= 5

func _draw_nav() -> void:
	var s := _size()
	var y0 := s.y - NAV_H
	_rect(Rect2(0, y0, s.x, NAV_H), Color("201c26"), Color("08070a"))
	draw_line(Vector2(0, y0), Vector2(s.x, y0), Art.INK, 2.0)
	draw_line(Vector2(0, y0 + 2), Vector2(s.x, y0 + 2), Color("57525f"), 1.0)
	var w := s.x / TABS.size()
	for i in TABS.size():
		var t: Array = TABS[i]
		var on: bool = tab == t[0]
		var center: bool = t[0] == "battle"
		var r := Rect2(i * w + 2, y0 + 5, w - 4, NAV_H - 8)
		rects["tab_" + t[0]] = r
		var cx := r.get_center().x
		if center:
			# pulsante centrale rialzato
			var hr := Rect2(cx - 26, y0 - 12, 52, 52)
			Art.glow(self, hr.get_center(), 50, Color(1, 0.45, 0.1, 0.35 if on else 0.15))
			var hex := PackedVector2Array()
			for k in 6:
				hex.append(hr.get_center() + Vector2.from_angle(-PI / 2 + k * TAU / 6.0) * 27)
			Art.grad_poly(self, hex, Art.MOLTEN_L if on else Color("5a4a40"), Color("8a2a0a") if on else Color("1c1618"))
			Art.outline(self, hex, Art.INK, 3.0)
			Art.outline(self, hex, Art.GOLD_L if on else Color("8a7a60"), 1.2)
			Art.icon(self, "sword", hr.get_center() - Vector2(3.5, 3.5) * 3.0 + Vector2(-3, 0), 3.0, Art.TEXT)
			Art.icon(self, "sword", hr.get_center() - Vector2(3.5, 3.5) * 3.0 + Vector2(3, 0), 3.0, Color(Art.TEXT, 0.6))
			PixelFont.draw_centered(self, t[1], cx, y0 + 41, 1, Art.GOLD_L if on else Art.TEXT_DIM)
			continue
		if on:
			var pr := Rect2(r.position.x + 2, r.position.y, r.size.x - 4, r.size.y)
			Art.plate(self, pr, Color("3a3442"), Color("17141b"), Art.GOLD, 6.0)
			Art.glow(self, Vector2(cx, r.position.y + 14), 22, Color(1, 0.55, 0.2, 0.3))
		var col := Art.GOLD_L if on else Color("8a8490")
		var k := 2.4 if on else 2.1
		Art.icon(self, t[2], Vector2(cx - 3.5 * k, r.position.y + 7 - (2 if on else 0)), k, col)
		PixelFont.draw_centered(self, t[1], cx, r.position.y + 30, 1, col)

## Pulsante attivo solo se visibile nell'area dei contenuti (per le pagine che scorrono)
func _btn(action: String, r: Rect2, text: String, col: Color, enabled: bool) -> void:
	var c := _content()
	if r.end.y < c.position.y or r.position.y > c.end.y:
		return
	if enabled and c.encloses(r):
		rects[action] = r
	Art.button(self, r, text, col, enabled)

func _title(text: String, sub: String, y: float) -> float:
	var s := _size()
	PixelFont.draw_custom(self, "cinzel", text, s.x / 2.0, y, 20, Art.GOLD, Art.INK, 4)
	if sub != "":
		PixelFont.draw_centered(self, sub, s.x / 2.0, y + 26, 1, Art.TEXT_DIM)
		return y + 42
	return y + 30

# =====================================================================
#  Battaglia
# =====================================================================
func _draw_battle() -> void:
	var s := _size()
	var card := Rect2(12, TOP_H + 10, s.x - 24, clampf(s.y - NAV_H - TOP_H - 146, 200, 300))
	var unlocked: bool = CHAPTERS[chapter][1]
	Art.plate(self, card.grow(3), Color("3a3442"), Color("17141b"), Art.GOLD, 10.0, true)
	_draw_chapter_art(card.grow(-4), unlocked)
	# nastro col nome del capitolo
	var by := card.end.y - 62
	var rib := Rect2(card.position.x - 8, by, card.size.x + 16, 46)
	var rp := PackedVector2Array([rib.position, Vector2(rib.end.x, rib.position.y), Vector2(rib.end.x - 10, rib.get_center().y), rib.end, Vector2(rib.position.x, rib.end.y), Vector2(rib.position.x + 10, rib.get_center().y)])
	Art.grad_poly(self, rp, Color("6a1822"), Color("2a080c"))
	Art.outline(self, rp, Art.INK, 2.5)
	draw_line(Vector2(rib.position.x + 14, rib.position.y + 3), Vector2(rib.end.x - 14, rib.position.y + 3), Color(Art.GOLD, 0.6), 1.0)
	draw_line(Vector2(rib.position.x + 14, rib.end.y - 3), Vector2(rib.end.x - 14, rib.end.y - 3), Color(Art.GOLD, 0.6), 1.0)
	PixelFont.draw_centered(self, "Capitolo %d" % (chapter + 1), s.x / 2.0, by + 5, 1, Art.GOLD_L)
	PixelFont.draw_custom(self, "cinzel", CHAPTERS[chapter][0].to_upper(), s.x / 2.0, by + 18, 17, Art.TEXT, Art.INK, 4)
	# frecce dei capitoli
	for side in [-1, 1]:
		var ar := Rect2(s.x / 2.0 + side * 112 - 13, card.position.y + card.size.y * 0.38, 26, 34)
		var ok: bool = (side < 0 and chapter > 0) or (side > 0 and chapter < CHAPTERS.size() - 1)
		if ok:
			rects["ch_prev" if side < 0 else "ch_next"] = ar
		var c := ar.get_center()
		var tri := PackedVector2Array([c + Vector2(side * 8, 0), c + Vector2(-side * 6, -11), c + Vector2(-side * 6, 11)])
		draw_colored_polygon(tri, Color(Art.GOLD, 0.9 if ok else 0.15))
		Art.outline(self, tri, Art.INK, 2.0)
	# avanzamento
	var py := card.end.y + 12
	PixelFont.draw_text(self, "Record", Vector2(16, py), 1, Art.TEXT_DIM)
	var rec := "Stanza %d/12" % Save.best_room if unlocked else "Bloccato"
	PixelFont.draw_text(self, rec, Vector2(s.x - 16 - PixelFont.text_width(rec, 1), py), 1, Art.GOLD_L)
	var seg := (s.x - 32 - 11 * 3) / 12.0
	for i in 12:
		var sr := Rect2(16 + i * (seg + 3), py + 14, seg, 6)
		var done := unlocked and i < Save.best_room
		draw_colored_polygon(Art.cut_pts(sr, 2), Art.MOLTEN if done else Color("2a2630"))
		if i == 6 or i == 11:
			draw_circle(sr.get_center(), 2, Art.INK)
	# pulsante principale
	var pr := Rect2(s.x / 2.0 - 98, py + 34, 196, 52)
	rects["play"] = pr
	if unlocked:
		Art.glow(self, pr.get_center(), 120, Color(1, 0.45, 0.1, 0.25 + 0.08 * sin(time * 3.0)))
	Art.button(self, pr, "", Art.MOLTEN if unlocked else Color("3a3440"), true)
	PixelFont.draw_custom(self, "oswald", "COMBATTI" if unlocked else "IN ARRIVO", pr.get_center().x, pr.position.y + 9, 24, Art.TEXT, Color(0.3, 0.08, 0, 0.8), 4)
	var w := Save.run_weapons()
	var wl := "%s + %s" % [PixelFont.nice(Data.WEAPONS[w[0]].name), PixelFont.nice(Data.WEAPONS[w[1]].name)]
	PixelFont.draw_centered(self, wl, pr.get_center().x, pr.position.y + 36, 1, Color(1, 0.9, 0.8, 0.85))

## Illustrazione del capitolo: interno della fonderia, cascate di lava, il boss nell'ombra
func _draw_chapter_art(r: Rect2, unlocked: bool) -> void:
	var tint := Color(1, 1, 1) if chapter == 0 else (Color(0.7, 0.85, 1.1) if chapter == 1 else Color(1.1, 0.75, 0.9))
	_rect(r, Color("0a0608") * tint, Color("3a1208") * tint)
	var cx := r.get_center().x
	# boss gigante sullo sfondo
	var bc := Vector2(cx, r.position.y + 96)
	Art.glow(self, bc, 110, Color(1, 0.35, 0.1, 0.35) * tint)
	var robe := PackedVector2Array([bc + Vector2(-40, -18), bc + Vector2(40, -18), bc + Vector2(72, 110), bc + Vector2(-72, 110)])
	draw_colored_polygon(robe, Color("140608"))
	var mask := PackedVector2Array([bc + Vector2(-16, -46), bc + Vector2(16, -46), bc + Vector2(14, -22), bc + Vector2(0, -8), bc + Vector2(-14, -22)])
	draw_colored_polygon(mask, Color("2a1a14"))
	for sx in [-1.0, 1.0]:
		var ep := bc + Vector2(sx * 7, -32)
		Art.glow(self, ep, 12, Color(1, 0.5, 0.1, 0.9))
		draw_line(ep - Vector2(4, sx * -1), ep + Vector2(4, sx * 1), Color("ffd060"), 2.0)
	var crown := PackedVector2Array([bc + Vector2(-20, -44)])
	for i in 5:
		crown.append(bc + Vector2(-16 + i * 8, -66 - (8 if i % 2 == 0 else 0) - sin(time * 6.0 + i) * 2))
		crown.append(bc + Vector2(-12 + i * 8, -48))
	crown.append(bc + Vector2(20, -44))
	Art.glow(self, bc + Vector2(0, -58), 30, Color(1, 0.5, 0.1, 0.5))
	draw_colored_polygon(crown, Color("ff7a2a") * tint)
	# colonne e cascate di lava ai lati
	for side in [-1.0, 1.0]:
		var lx: float = cx + side * 80
		draw_rect(Rect2(lx - 14, r.position.y, 28, r.size.y), Color("120c10"))
		var fx: float = cx + side * 52
		var fall := Rect2(fx - 5, r.position.y, 10, r.size.y - 70)
		_rect(fall, Color("ffb040"), Color("c03a0a"))
		Art.glow(self, Vector2(fx, r.end.y - 80), 40, Color(1, 0.45, 0.1, 0.4))
		for i in 4:
			var yy := r.position.y + fmod(time * 60.0 + i * 37.0, fall.size.y)
			draw_line(Vector2(fx - 3, yy), Vector2(fx - 3, yy + 8), Color(1, 0.95, 0.6, 0.7), 1.0)
	# pavimento e piccolo eroe che guarda il boss
	_rect(Rect2(r.position.x, r.end.y - 74, r.size.x, 74), Color("1a0e0c"), Color("060405"))
	draw_line(Vector2(r.position.x, r.end.y - 74), Vector2(r.end.x, r.end.y - 74), Color(1, 0.5, 0.2, 0.35), 1.0)
	HeroArt.draw(self, Vector2(cx, r.end.y - 66), Vector2.UP, time, 0.0, false, "sword", Data.WEAPONS.sword.color, 0.0, 1.5)
	for i in 10:
		var ex := r.position.x + fmod(i * 37.0 + sin(i) * 20.0, r.size.x)
		var ey := r.end.y - fmod(time * (10.0 + i % 3 * 6) + i * 30.0, r.size.y)
		draw_circle(Vector2(ex, ey), 1.0, Color(1, 0.7, 0.3, 0.8))
	if not unlocked:
		draw_colored_polygon(Art.cut_pts(r, 8), Color(0, 0, 0, 0.65))
		Art.icon(self, "lock", r.get_center() - Vector2(3.5, 3.5) * 5 - Vector2(0, 30), 5.0, Art.TEXT_DIM)
		PixelFont.draw_centered(self, "In arrivo", r.get_center().x, r.get_center().y + 4, 3, Art.TEXT_DIM, Art.INK)

# =====================================================================
#  Armeria
# =====================================================================
func _slot_rects() -> Dictionary:
	var s := _size()
	var y0 := TOP_H + 14
	var bs := 36.0
	var step := 44.0
	var left := ["weapon1", "helmet", "armor", "gloves"]
	var right := ["weapon2", "boots", "ring"]
	var d := {}
	for i in left.size():
		d[left[i]] = Rect2(12, y0 + i * step, bs, bs)
	for i in right.size():
		d[right[i]] = Rect2(s.x - 12 - bs, y0 + i * step, bs, bs)
	return d

func _draw_armory() -> void:
	var s := _size()
	var c := _content()
	# eroe su un piedistallo con un cerchio di rune
	var hc := Vector2(s.x / 2.0, TOP_H + 132)
	Art.glow(self, hc + Vector2(0, -40), 80, Color(1, 0.45, 0.15, 0.22))
	HeroArt.ellipse(self, hc + Vector2(0, 6), 46, 13, Color("0e0c12"))
	HeroArt.ellipse(self, hc + Vector2(0, 3), 44, 12, Color("2a2630"))
	draw_set_transform(hc + Vector2(0, 3), 0, Vector2(1, 0.27))
	draw_arc(Vector2.ZERO, 38, 0, TAU, 48, Color(1, 0.5, 0.2, 0.5), 2.0, true)
	for i in 8:
		var a := time * 0.5 + i * TAU / 8.0
		draw_line(Vector2.from_angle(a) * 30, Vector2.from_angle(a) * 36, Color(1, 0.6, 0.25, 0.7), 2.0)
	draw_set_transform(Vector2.ZERO)
	var w := Save.run_weapons()
	HeroArt.draw(self, hc + Vector2(0, 2), Vector2(0.25, 0.97).normalized(), time, 0.0, false, w[0], Data.WEAPONS[w[0]].color, 0.0, 2.7)
	# posti
	var sr := _slot_rects()
	for slot in sr:
		var r: Rect2 = sr[slot]
		rects["slot_" + slot] = r
		var it := Save.equipped_item(slot)
		if it.is_empty():
			var pts := Art.cut_pts(r, 6)
			draw_colored_polygon(pts, Color(0, 0, 0, 0.55))
			Art.outline(self, pts, Color("3a3640"), 1.2)
			var icon_name: String = "sword" if slot.begins_with("weapon") else slot
			Art.icon(self, icon_name, r.get_center() - Vector2(3.5, 3.5) * 2.4, 2.4, Color("3a3640"))
		else:
			Art.item_box(self, it, r)
	PixelFont.draw_centered(self, "Arma 1", sr.weapon1.get_center().x, sr.weapon1.position.y - 10, 1, Art.TEXT_DIM)
	PixelFont.draw_centered(self, "Arma 2", sr.weapon2.get_center().x, sr.weapon2.position.y - 10, 1, Art.TEXT_DIM)
	# statistiche
	var b := Save.bonuses()
	var st := [
		["hp", "Vita", str(120 + int(b.hp))],
		["atk", "Attacco", "+%d%%" % int(round((b.weapon_atk[0] + b.weapon_atk[1]) * 50))],
		["crit", "Critico", "%d%%" % int(round(b.crit * 100))],
		["speed", "Velocità", "+%d%%" % int(round(b.speed_pct * 100))],
	]
	var py := TOP_H + 196
	var pw := (s.x - 30) / 2.0
	for i in st.size():
		var r := Rect2(12 + (i % 2) * (pw + 6), py + int(i / 2) * 26, pw, 22)
		var pts := Art.cut_pts(r, 5)
		draw_colored_polygon(pts, Color(0, 0, 0, 0.45))
		Art.outline(self, pts, Color("3a3640"), 1.0)
		Skills.icon(self, st[i][0], r.position + Vector2(11, 11), 7)
		PixelFont.draw_text(self, st[i][1], r.position + Vector2(23, 6), 1, Art.TEXT_DIM)
		PixelFont.draw_text(self, st[i][2], Vector2(r.end.x - 6 - PixelFont.text_width(st[i][2], 1), r.position.y + 6), 1, Art.TEXT)
	# materiali
	var my := py + 56
	var mx := 14.0
	for m in ["bone", "stone", "ember"]:
		var md: Dictionary = Gear.MATERIALS[m]
		Art.icon(self, md.icon, Vector2(mx, my), 1.6, md.color)
		var t := "%d %s" % [Save.materials[m], PixelFont.nice(md.name)]
		PixelFont.draw_text(self, t, Vector2(mx + 15, my + 1), 1, Art.TEXT)
		mx += 30 + PixelFont.text_width(t, 1)
	# inventario
	var inv := Save.inventory()
	var ir := Rect2(8, my + 18, s.x - 16, c.end.y - (my + 18) - 6)
	Art.plate(self, ir, Color("1e1b24"), Color("0e0c12"), Color("3a3640"), 8.0)
	PixelFont.draw_text(self, "Inventario · %d" % inv.size(), Vector2(ir.position.x + 10, ir.position.y + 6), 2, Art.GOLD)
	var cols := 6
	var box := 34.0
	var gap := (ir.size.x - 20 - cols * box) / (cols - 1)
	var top := ir.position.y + 28
	var rows := maxi(1, int((ir.end.y - top - 4) / (box + gap)))
	var per := cols * rows
	var pages := maxi(1, int(ceil(inv.size() / float(per))))
	inv_page = clampi(inv_page, 0, pages - 1)
	if pages > 1:
		var pt := "%d/%d" % [inv_page + 1, pages]
		PixelFont.draw_text(self, pt, Vector2(ir.end.x - 52 - PixelFont.text_width(pt, 1) / 2.0, ir.position.y + 8), 1, Art.TEXT_DIM)
		var r1 := Rect2(ir.end.x - 84, ir.position.y + 5, 20, 17)
		var r2 := Rect2(ir.end.x - 28, ir.position.y + 5, 20, 17)
		rects["inv_prev"] = r1
		rects["inv_next"] = r2
		Art.button(self, r1, "<", Art.STEEL, inv_page > 0)
		Art.button(self, r2, ">", Art.STEEL, inv_page < pages - 1)
	if inv.is_empty():
		PixelFont.draw_centered(self, "Vuoto: i pezzi si trovano nel Negozio", s.x / 2.0, top + 16, 1, Art.TEXT_DIM)
		PixelFont.draw_centered(self, "e sconfiggendo mini-boss e boss", s.x / 2.0, top + 28, 1, Art.TEXT_DIM)
	for i in range(inv_page * per, mini(inv.size(), (inv_page + 1) * per)):
		var k := i - inv_page * per
		var r := Rect2(ir.position.x + 10 + (k % cols) * (box + gap), top + int(k / cols) * (box + gap), box, box)
		var it: Dictionary = inv[i]
		rects["inv_%d" % it.id] = r
		Art.item_box(self, it, r)
		if Save.can_merge(it):
			var d := r.position + Vector2(5, 5)
			draw_colored_polygon(PackedVector2Array([d + Vector2(0, -4), d + Vector2(4, 0), d + Vector2(0, 4), d + Vector2(-4, 0)]), Art.GOLD_L)

func _draw_detail() -> void:
	var s := _size()
	var it := Save.get_item(detail_id)
	if it.is_empty():
		detail_id = -1
		return
	draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.72))
	var rar: Dictionary = Gear.RARITY[it.rar]
	var pr := Rect2(12, 52, s.x - 24, 340)
	rects["block"] = pr
	Art.plate(self, pr, Color("26222c"), Color("100e13"), rar.color, 10.0, true)
	_rect(Rect2(pr.position.x + 3, pr.position.y + 3, pr.size.x - 6, 60), Color(rar.color, 0.25), Color(rar.color, 0.0))
	Art.item_box(self, it, Rect2(pr.position.x + 12, pr.position.y + 12, 48, 48))
	var tx := pr.position.x + 70
	PixelFont.draw_text(self, Gear.item_name(it), Vector2(tx, pr.position.y + 12), 2, Art.TEXT, Art.INK)
	PixelFont.draw_text(self, PixelFont.nice(rar.name), Vector2(tx, pr.position.y + 32), 1, rar.color)
	PixelFont.draw_text(self, "Livello %d/%d" % [it.lv, rar.max_lv], Vector2(tx, pr.position.y + 44), 1, Art.TEXT_DIM)
	var slot := Save.slot_of(it.id)
	if slot != "":
		PixelFont.draw_text(self, "Indossato: " + PixelFont.nice(Gear.SLOT_NAME[slot]), Vector2(tx + 70, pr.position.y + 44), 1, Art.GREEN)
	var y := pr.position.y + 72
	var t := Gear.type_of(it)
	if t == "weapon":
		var wd: Dictionary = Data.WEAPONS[Gear.BASES[it.base].weapon]
		PixelFont.draw_text(self, wd.desc[0] + ", " + wd.desc[1], Vector2(pr.position.x + 12, y), 1, Art.TEXT_DIM)
		y += 12
		if wd.desc.size() > 2:
			PixelFont.draw_text(self, wd.desc[2], Vector2(pr.position.x + 12, y), 1, Art.GOLD)
			y += 12
		y += 2
	PixelFont.draw_text(self, Gear.stat_text(it), Vector2(pr.position.x + 12, y), 2, Art.TEXT)
	y += 24
	draw_line(Vector2(pr.position.x + 12, y - 4), Vector2(pr.end.x - 12, y - 4), Color("3a3640"), 1.0)
	var lines := []
	var rb: Array = Gear.RARE_BONUS[t]
	lines.append([2, "RARO: " + rb[0]])
	var recipe: String = Gear.BASES[it.base].get("recipe", "")
	if recipe != "":
		lines.append([3, "EPICO: RICETTA " + Data.COMBOS[recipe][0]])
	lines.append([4, "LEGG.: " + Gear.LEGEND[t][0]])
	for l in lines:
		var ok: bool = it.rar >= l[0]
		var col: Color = Gear.RARITY[l[0]].color if ok else Color("4a4450")
		y = _wrap(l[1], Vector2(pr.position.x + 12, y), pr.size.x - 24, col) + 3
	var cost := Gear.upgrade_cost(it)
	var maxed: bool = it.lv >= rar.max_lv
	var bw := (pr.size.x - 34) / 2.0
	var by := pr.end.y - 112
	var up := Rect2(pr.position.x + 12, by, bw, 28)
	rects["upgrade"] = up
	Art.button(self, up, "Massimo" if maxed else "Migliora", Color("3f8a4a"), Save.can_upgrade(it))
	if not maxed:
		var md: Dictionary = Gear.MATERIALS[cost[1]]
		var ct := "%d  %d" % [cost[0], cost[2]]
		var cx := up.get_center().x - PixelFont.text_width(ct, 1) / 2.0
		Art.icon(self, "gold", Vector2(cx - 10, up.end.y + 5), 1, Art.GOLD)
		PixelFont.draw_text(self, str(cost[0]), Vector2(cx, up.end.y + 5), 1, Art.TEXT if Save.gold >= cost[0] else Art.HP)
		var mx := cx + PixelFont.text_width(str(cost[0]) + "  ", 1)
		Art.icon(self, md.icon, Vector2(mx, up.end.y + 5), 1, md.color)
		PixelFont.draw_text(self, str(cost[2]), Vector2(mx + 10, up.end.y + 5), 1, Art.TEXT if Save.materials[cost[1]] >= cost[2] else Art.HP)
	var mg := Rect2(up.end.x + 10, by, bw, 28)
	rects["merge"] = mg
	var partners := Save.merge_partners(it).size()
	Art.button(self, mg, "Unisci %d/3" % (partners + 1) if it.rar < 4 else "Massima", Color("8a4ad0"), Save.can_merge(it))
	if it.rar < 4:
		PixelFont.draw_centered(self, "3 uguali = " + PixelFont.nice(Gear.RARITY[it.rar + 1].name), mg.get_center().x, mg.end.y + 5, 1, Art.TEXT_DIM)
	by += 46
	if t == "weapon":
		var e1 := Rect2(pr.position.x + 12, by, bw, 26)
		var e2 := Rect2(e1.end.x + 10, by, bw, 26)
		rects["equip1"] = e1
		rects["equip2"] = e2
		Art.button(self, e1, "In arma 1", Art.MOLTEN, slot != "weapon1")
		Art.button(self, e2, "In arma 2", Art.MOLTEN, slot != "weapon2")
	elif slot == "":
		var e := Rect2(pr.position.x + 12, by, bw, 26)
		rects["equip"] = e
		Art.button(self, e, "Indossa", Art.MOLTEN)
		var sl := Rect2(e.end.x + 10, by, bw, 26)
		rects["sell"] = sl
		Art.button(self, sl, "Vendi %d" % Save.sell_value(it), Color("8a6a30"))
	else:
		var u := Rect2(pr.position.x + 12, by, bw, 26)
		rects["unequip"] = u
		Art.button(self, u, "Togli", Color("8a3030"))
	var cr := Rect2(pr.get_center().x - 45, pr.end.y - 32, 90, 24)
	rects["close"] = cr
	Art.button(self, cr, "Chiudi", Art.STEEL)

func _draw_reveal() -> void:
	var s := _size()
	draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.82))
	var rar: Dictionary = Gear.RARITY[reveal.rar]
	var c := Vector2(s.x / 2.0, s.y * 0.4)
	var k := clampf(reveal_t * 3.0, 0.0, 1.0)
	Art.glow(self, c, 120 * k, Color(rar.color, 0.45))
	for i in 16:
		var a := time * 0.5 + TAU * i / 16.0
		var tri := PackedVector2Array([c, c + Vector2.from_angle(a - 0.08) * 150 * k, c + Vector2.from_angle(a + 0.08) * 150 * k])
		draw_colored_polygon(tri, Color(rar.color, 0.12))
	PixelFont.draw_custom(self, "cinzel", reveal_msg, c.x, c.y - 110, 15, Art.GOLD_L, Art.INK, 4)
	var bs := 64.0 * (0.6 + 0.4 * k)
	Art.item_box(self, reveal, Rect2(c - Vector2(bs, bs) / 2.0, Vector2(bs, bs)))
	PixelFont.draw_text(self, rar.name, Vector2(c.x - PixelFont.text_width(rar.name, 3) / 2.0, c.y + 46), 3, rar.color, Art.INK)
	PixelFont.draw_centered(self, Gear.item_name(reveal), c.x, c.y + 76, 2, Art.TEXT, Art.INK)
	PixelFont.draw_centered(self, Gear.stat_text(reveal), c.x, c.y + 98, 1, Art.TEXT_DIM)
	var cr := Rect2(c.x - 60, c.y + 124, 120, 32)
	rects["close"] = cr
	Art.button(self, cr, "Raccogli", Art.MOLTEN, true, 2)

# =====================================================================
#  Negozio
# =====================================================================
func _section(text: String, y: float) -> void:
	Art.header(self, text, _size().x / 2.0, y, _size().x - 30)

func _draw_shop() -> void:
	var s := _size()
	var c := _content()
	var y := c.position.y + 10 - scroll
	var x0 := 10.0
	var w := s.x - 20
	PixelFont.draw_custom(self, "cinzel", "MERCATO DEL FABBRO", s.x / 2.0, y, 18, Art.GOLD, Art.INK, 4)
	y += 32
	# regalo del giorno
	var g := Rect2(x0, y, w, 50)
	var gift_ok := Save.gift_day != Save.today()
	Art.plate(self, g, Color("1e3020") if gift_ok else Color("1e1b24"), Color("0c140c") if gift_ok else Color("0e0c12"), Art.GREEN if gift_ok else Color("3a3640"), 8.0)
	_chest_art(g.position + Vector2(24, 30), 0.7, Color("5a8a4a"), gift_ok)
	PixelFont.draw_text(self, "Regalo del giorno", g.position + Vector2(50, 9), 2, Art.TEXT, Art.INK)
	PixelFont.draw_text(self, "Un pezzo + 50 oro, gratis", g.position + Vector2(50, 29), 1, Art.TEXT_DIM)
	_btn("gift", Rect2(g.end.x - 74, g.position.y + 12, 64, 26), "Ritira" if gift_ok else "Domani", Color("3f8a4a"), gift_ok)
	y += 62
	# casse
	_section("Casse", y)
	y += 24
	var cw := (w - 8) / 2.0
	var chests := [
		["chest", "Cassa di ferro", Color("8a8494"), "%d" % SHOP_CHEST, "gold", Gear.CHEST_ODDS, Save.gold >= SHOP_CHEST],
		["gemchest", "Cassa del Re", Color("d8a040"), "%d" % SHOP_GEM_CHEST, "gem", GEM_CHEST_ODDS, Save.gems >= SHOP_GEM_CHEST],
	]
	for i in 2:
		var ch: Array = chests[i]
		var r := Rect2(x0 + i * (cw + 8), y, cw, 150)
		Art.plate(self, r, Color("2a2630"), Color("0e0c12"), ch[2], 8.0, true)
		Art.glow(self, r.position + Vector2(cw / 2.0, 52), 50, Color(ch[2], 0.25))
		_chest_art(r.position + Vector2(cw / 2.0, 62), 1.25, ch[2], true)
		PixelFont.draw_centered(self, ch[1], r.get_center().x, r.position.y + 76, 2, Art.TEXT, Art.INK)
		var ox := r.position.x + 8
		for k in 5:
			if ch[5][k] <= 0.0:
				continue
			var t := "%d%%" % int(ch[5][k])
			PixelFont.draw_text(self, t, Vector2(ox, r.position.y + 98), 1, Gear.RARITY[k].color)
			ox += PixelFont.text_width(t, 1) + 5
		var br := Rect2(r.position.x + 8, r.end.y - 34, cw - 16, 26)
		_btn(ch[0], br, "", Art.MOLTEN if ch[4] == "gold" else Color("2a7ab0"), ch[6])
		if br.end.y > c.position.y and br.position.y < c.end.y:
			Art.icon(self, ch[4], Vector2(br.get_center().x - 22, br.position.y + 8), 1.5, Art.GOLD if ch[4] == "gold" else Art.GEM)
			PixelFont.draw_text(self, ch[3], Vector2(br.get_center().x - 8, br.position.y + 5), 2, Art.TEXT if ch[6] else Color("6e6874"), Color(0, 0, 0, 0.5))
	y += 162
	# offerte del giorno
	_section("Offerte del giorno", y)
	y += 24
	var offers := _daily_offers()
	var ow := (w - 8) / 3.0
	for i in offers.size():
		var o: Dictionary = offers[i]
		var r := Rect2(x0 + i * (ow + 4), y, ow, 104)
		var it := {"base": o.base, "rar": o.rar, "lv": 1}
		var sold: bool = i in Save.shop_bought
		var rc: Color = Gear.RARITY[o.rar].color
		Art.plate(self, r, rc.darkened(0.6), Color("0e0c12"), rc.darkened(0.1), 7.0)
		Art.item_box(self, it, Rect2(r.get_center().x - 18, r.position.y + 8, 36, 36))
		PixelFont.draw_centered(self, PixelFont.nice(Gear.RARITY[o.rar].name), r.get_center().x, r.position.y + 48, 1, rc)
		var nm: String = Gear.item_name(it)
		var words := nm.split(" ")
		PixelFont.draw_centered(self, words[0], r.get_center().x, r.position.y + 59, 1, Art.TEXT)
		if words.size() > 1:
			PixelFont.draw_centered(self, " ".join(words.slice(1)).substr(0, 12), r.get_center().x, r.position.y + 69, 1, Art.TEXT)
		var br := Rect2(r.position.x + 5, r.end.y - 24, r.size.x - 10, 19)
		var label := "Preso" if sold else "%d %s" % [o.price, "oro" if o.cur == "gold" else "gemme"]
		var have: int = Save.gold if o.cur == "gold" else Save.gems
		_btn("offer_%d" % i, br, label, Art.MOLTEN if o.cur == "gold" else Color("2a7ab0"), not sold and have >= o.price)
	y += 116
	# materiali
	_section("Materiali", y)
	y += 24
	var mi := 0
	for m in ["bone", "stone", "ember"]:
		var md: Dictionary = Gear.MATERIALS[m]
		var r := Rect2(x0 + mi * (ow + 4), y, ow, 66)
		Art.plate(self, r, Color("26222c"), Color("0e0c12"), Color("3a3640"), 7.0)
		Art.glow(self, r.position + Vector2(ow / 2.0, 16), 16, Color(md.color, 0.3))
		Art.icon(self, md.icon, r.position + Vector2(ow / 2.0 - 8.75, 6), 2.5, md.color)
		PixelFont.draw_centered(self, "10 " + PixelFont.nice(md.name), r.get_center().x, r.position.y + 27, 1, Art.TEXT)
		_btn("mat_" + m, Rect2(r.position.x + 5, r.end.y - 23, r.size.x - 10, 18), "%d oro" % SHOP_MAT_PRICE, Art.MOLTEN, Save.gold >= SHOP_MAT_PRICE)
		mi += 1
	y += 78
	var r2 := Rect2(x0, y, w, 36)
	Art.plate(self, r2, Color("1a181e"), Color("0e0c12"), Color("2e2a34"), 7.0)
	Art.icon(self, "lock", r2.position + Vector2(10, 11), 2, Art.TEXT_DIM)
	PixelFont.draw_text(self, "Pacchetti di gemme · in arrivo", r2.position + Vector2(32, 12), 1, Art.TEXT_DIM)
	y += 46
	scroll_max = maxf(0.0, (y + scroll) - c.end.y + 8)

## Cassa disegnata: legno scuro, fasce di metallo, serratura che brilla
func _chest_art(c: Vector2, k: float, metal: Color, glow_on: bool) -> void:
	var S := func(v: Vector2) -> Vector2: return c + v * k
	HeroArt.ellipse(self, c + Vector2(0, 2) * k, 26 * k, 5 * k, Color(0, 0, 0, 0.5))
	HeroArt._gpoly(self, [S.call(Vector2(-22, -18)), S.call(Vector2(22, -18)), S.call(Vector2(22, 0)), S.call(Vector2(-22, 0))], Color("5a3420"), Color("2a160c"), 2.0)
	HeroArt._gpoly(self, [S.call(Vector2(-22, -18)), S.call(Vector2(-18, -32)), S.call(Vector2(18, -32)), S.call(Vector2(22, -18))], Color("6a4028"), Color("3a2010"), 2.0)
	for x in [-14.0, 14.0]:
		draw_line(S.call(Vector2(x, -31)), S.call(Vector2(x, 0)), metal, 3.0 * k)
	draw_line(S.call(Vector2(-22, -18)), S.call(Vector2(22, -18)), metal, 2.5 * k)
	if glow_on:
		Art.glow(self, S.call(Vector2(0, -16)), 14 * k, Color(1, 0.7, 0.3, 0.6 + 0.2 * sin(time * 3.0)))
	HeroArt._poly(self, [S.call(Vector2(-4, -22)), S.call(Vector2(4, -22)), S.call(Vector2(4, -12)), S.call(Vector2(-4, -12))], metal.lightened(0.2), 1.4)
	draw_circle(S.call(Vector2(0, -17)), 1.3 * k, Art.INK)

# =====================================================================
#  Talenti
# =====================================================================
func _draw_talents() -> void:
	var s := _size()
	var c := _content()
	var y := _title("TALENTI", "Potenziamenti permanenti, validi in ogni partita", c.position.y + 10)
	var cw := (s.x - 28) / 2.0
	var ch := 106.0
	for i in Data.TALENT_ORDER.size():
		var tk: String = Data.TALENT_ORDER[i]
		var td: Dictionary = Data.TALENTS[tk]
		var lv := int(Save.talents.get(tk, 0))
		var mx := int(td.max)
		var r := Rect2(10 + (i % 2) * (cw + 8), y + int(i / 2) * (ch + 8), cw, ch)
		var full := lv >= mx
		Art.plate(self, r, Color("2a2630"), Color("0e0c12"), Art.GOLD if lv > 0 else Color("3a3640"), 8.0)
		Skills.icon(self, td.icon, r.position + Vector2(22, 24), 14)
		PixelFont.draw_text(self, td.name, r.position + Vector2(42, 8), 2, Art.TEXT, Art.INK)
		PixelFont.draw_text(self, "Lv %d/%d" % [lv, mx], r.position + Vector2(42, 28), 1, Art.GOLD_L)
		_wrap(td.desc, r.position + Vector2(10, 46), cw - 20, Art.TEXT_DIM)
		# pallini del livello
		var pw := (cw - 20) / mx
		for k in mx:
			var pr := Rect2(r.position.x + 10 + k * pw, r.position.y + 64, pw - 2, 4)
			draw_rect(pr, Art.MOLTEN if k < lv else Color("2a2630"))
		var br := Rect2(r.position.x + 8, r.end.y - 30, cw - 16, 24)
		var cost := Data.talent_cost(lv)
		if full:
			Art.button(self, br, "Massimo", Art.STEEL, false)
		else:
			rects["tal_" + tk] = br
			Art.button(self, br, "", Art.MOLTEN, Save.gold >= cost)
			Art.icon(self, "gold", Vector2(br.get_center().x - 22, br.position.y + 7), 1.4, Art.GOLD)
			PixelFont.draw_text(self, str(cost), Vector2(br.get_center().x - 9, br.position.y + 5), 2, Art.TEXT if Save.gold >= cost else Color("8a8490"), Color(0, 0, 0, 0.5))

# =====================================================================
#  Codice: ricette della forgia e debolezze dei nemici
# =====================================================================
func _draw_codex() -> void:
	var s := _size()
	var c := _content()
	var y := _title("CODICE DELLA FORGIA", "Due elementi diversi nella stessa arma", c.position.y + 10 - scroll)
	for key in Data.COMBOS:
		var known: bool = key in Save.recipes
		var els: PackedStringArray = key.split("+")
		var r := Rect2(10, y, s.x - 20, 44)
		Art.plate(self, r, Color("26222c") if known else Color("17141b"), Color("0e0c12"), Art.GOLD if known else Color("2e2a34"), 6.0)
		Art.el_badge(self, els[0], r.position + Vector2(16, 22), 8)
		Art.el_badge(self, els[1], r.position + Vector2(38, 22), 8)
		if known:
			PixelFont.draw_text(self, Data.COMBOS[key][0], r.position + Vector2(56, 7), 2, Art.TEXT, Art.INK)
			PixelFont.draw_text(self, Data.COMBOS[key][1], r.position + Vector2(56, 27), 1, Art.TEXT_DIM)
		else:
			PixelFont.draw_text(self, "Ricetta segreta", r.position + Vector2(56, 7), 2, Color("6e6874"))
			var src := ""
			for b in Gear.BASES:
				if Gear.BASES[b].get("recipe", "") == key:
					src = Gear.BASES[b].name
			PixelFont.draw_text(self, "Si impara da: " + PixelFont.nice(src) + " epico", r.position + Vector2(56, 27), 1, Color("8a6aa0"))
		y += 50
	y += 8
	Art.header(self, "Debolezze", s.x / 2.0, y, s.x - 30)
	y += 26
	for fam in Data.FAMILIES:
		var f: Dictionary = Data.FAMILIES[fam]
		var r := Rect2(10, y, s.x - 20, 36)
		Art.plate(self, r, Color("221e28"), Color("0e0c12"), Color("3a3640"), 6.0)
		PixelFont.draw_text(self, f.name, r.position + Vector2(10, 9), 2, Art.TEXT, Art.INK)
		var x := r.end.x - 10
		for part in [["immune", "Immune"], ["resist", "Resiste"], ["weak", "Debole"]]:
			var el: String = f.get(part[0], "")
			if el == "":
				continue
			x -= 22
			Art.el_badge(self, el, Vector2(x + 8, r.position.y + 14), 7)
			var lw := PixelFont.text_width(part[1], 1)
			PixelFont.draw_text(self, part[1], Vector2(x + 8 - lw / 2.0, r.position.y + 24), 1, Art.GREEN if part[0] == "weak" else Art.TEXT_DIM)
			x -= maxf(lw - 14.0, 8.0)
		y += 42
	scroll_max = maxf(0.0, (y + scroll) - c.end.y + 8)

func _wrap(t: String, pos: Vector2, max_w: float, col: Color) -> float:
	var words := t.split(" ")
	var line := ""
	var y := pos.y
	for wd in words:
		var test := wd if line == "" else line + " " + wd
		if PixelFont.text_width(test, 1) > max_w and line != "":
			PixelFont.draw_text(self, line, Vector2(pos.x, y), 1, col)
			y += 10
			line = wd
		else:
			line = test
	if line != "":
		PixelFont.draw_text(self, line, Vector2(pos.x, y), 1, col)
		y += 10
	return y
