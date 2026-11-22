extends Node
## Salvataggio automatico: oro, gemme, materiali, equipaggiamento, ricette, negozio.

const PATH := "user://ashsmith_save.json"
const VERSION := 2

var gold := 0
var gems := 0
var best_room := 0
var runs := 0
var wins := 0
var materials := {"bone": 0, "stone": 0, "ember": 0}
var items: Array = []          # tutti i pezzi posseduti: {id, base, rar, lv}
var equipped := {}             # posto -> id del pezzo
var recipes: Array = []        # combinazioni conosciute
var uid := 1
var shop_day := ""             # giorno delle offerte del giorno
var shop_bought: Array = []    # offerte del giorno già comprate
var gift_day := ""             # giorno dell'ultimo regalo gratis
var sound := true              # suoni e musica
var talents := {}              # talento -> livello
var tips: Array = []           # consigli del tutorial già visti

func _ready() -> void:
	load_game()
	if items.is_empty():
		_new_game()

func _new_game() -> void:
	for b in ["sword", "bow", "staff"]:
		add_item(b, 0)
	equipped = {"weapon1": items[0].id, "weapon2": items[1].id}
	recipes = Gear.START_RECIPES.duplicate()
	# un piccolo capitale iniziale per provare negozio e miglioramenti
	gold += 300
	gems += 20
	for m in materials:
		materials[m] += 10
	save_game()

func load_game() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return
	gold = int(d.get("gold", 0))
	gems = int(d.get("gems", 0))
	best_room = int(d.get("best_room", 0))
	runs = int(d.get("runs", 0))
	wins = int(d.get("wins", 0))
	sound = bool(d.get("sound", true))
	talents = {}
	tips = []
	for x in d.get("tips", []):
		tips.append(str(x))
	var tl = d.get("talents", {})
	if typeof(tl) == TYPE_DICTIONARY:
		for k in tl:
			talents[str(k)] = int(tl[k])
	if int(d.get("version", 1)) < VERSION:
		return   # salvataggio vecchio: si tengono solo oro, gemme e record
	var m = d.get("materials", {})
	for k in materials:
		materials[k] = int(m.get(k, 0))
	items.clear()
	for it in d.get("items", []):
		if Gear.BASES.has(str(it.get("base", ""))):
			items.append({"id": int(it.id), "base": str(it.base), "rar": int(it.rar), "lv": int(it.lv)})
	equipped.clear()
	var eq = d.get("equipped", {})
	for k in eq:
		equipped[str(k)] = int(eq[k])
	recipes = []
	for r in d.get("recipes", Gear.START_RECIPES):
		recipes.append(str(r))
	uid = int(d.get("uid", 1))
	shop_day = str(d.get("shop_day", ""))
	shop_bought = []
	for x in d.get("shop_bought", []):
		shop_bought.append(int(x))
	gift_day = str(d.get("gift_day", ""))

func save_game() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"version": VERSION, "sound": sound, "talents": talents, "tips": tips, "gold": gold, "gems": gems, "best_room": best_room,
		"runs": runs, "wins": wins, "materials": materials, "items": items,
		"equipped": equipped, "recipes": recipes, "uid": uid,
		"shop_day": shop_day, "shop_bought": shop_bought, "gift_day": gift_day,
	}))

static func today() -> String:
	return Time.get_date_string_from_system()

# ---------------- Pezzi ----------------
func add_item(base: String, rar: int, lv: int = 1) -> Dictionary:
	var it := {"id": uid, "base": base, "rar": rar, "lv": lv}
	uid += 1
	items.append(it)
	_learn(it)
	return it

## Un pezzo Epico o migliore insegna la sua ricetta (per sempre)
func _learn(it: Dictionary) -> String:
	var r: String = Gear.BASES[it.base].get("recipe", "")
	if r != "" and it.rar >= 3 and not r in recipes:
		recipes.append(r)
		return r
	return ""

func get_item(id: int) -> Dictionary:
	for it in items:
		if it.id == id:
			return it
	return {}

func slot_of(id: int) -> String:
	for k in equipped:
		if equipped[k] == id:
			return k
	return ""

func equipped_item(slot: String) -> Dictionary:
	if not equipped.has(slot):
		return {}
	return get_item(equipped[slot])

func inventory() -> Array:
	var l := items.filter(func(it): return slot_of(it.id) == "")
	l.sort_custom(func(a, b): return a.rar > b.rar or (a.rar == b.rar and Gear.power(a) > Gear.power(b)))
	return l

## Indossa un pezzo nel posto giusto. Per le armi: nel posto scelto (weapon1/weapon2).
func equip(id: int, weapon_slot: String = "") -> void:
	var it := get_item(id)
	if it.is_empty():
		return
	var t := Gear.type_of(it)
	var slot := t
	var old_slot := slot_of(id)
	if t == "weapon":
		slot = weapon_slot if weapon_slot != "" else "weapon1"
		if old_slot == slot:
			return
		var other := "weapon2" if slot == "weapon1" else "weapon1"
		if old_slot == other:
			# scambio tra arma 1 e arma 2
			equipped[other] = equipped[slot]
			equipped[slot] = id
			save_game()
			return
		# la stessa arma non può stare in entrambi i posti: quella nel posto scelto passa nell'altro
		var other_it := equipped_item(other)
		if not other_it.is_empty() and Gear.BASES[other_it.base].weapon == Gear.BASES[it.base].weapon:
			equipped[other] = equipped[slot]
	equipped[slot] = id
	save_game()

func unequip(slot: String) -> void:
	if slot.begins_with("weapon"):
		return   # servono sempre 2 armi
	equipped.erase(slot)
	save_game()

func can_upgrade(it: Dictionary) -> bool:
	var c := Gear.upgrade_cost(it)
	return it.lv < Gear.RARITY[it.rar].max_lv and gold >= c[0] and materials[c[1]] >= c[2]

func upgrade(it: Dictionary) -> bool:
	if not can_upgrade(it):
		return false
	var c := Gear.upgrade_cost(it)
	gold -= c[0]
	materials[c[1]] -= c[2]
	it.lv += 1
	save_game()
	return true

## Altri 2 pezzi uguali (stesso pezzo e stessa rarità) non indossati
func merge_partners(it: Dictionary) -> Array:
	var l: Array = []
	for o in items:
		if o.id != it.id and o.base == it.base and o.rar == it.rar and slot_of(o.id) == "":
			l.append(o)
	return l.slice(0, 2)

func can_merge(it: Dictionary) -> bool:
	return it.rar < Gear.RARITY.size() - 1 and merge_partners(it).size() == 2

## Unisce 3 pezzi uguali: il pezzo sale di rarità e tiene il livello più alto
## Restituisce la ricetta imparata, se c'è.
func merge(it: Dictionary) -> String:
	if not can_merge(it):
		return ""
	var partners := merge_partners(it)
	var lv: int = it.lv
	for p in partners:
		lv = maxi(lv, p.lv)
		items.erase(p)
	it.rar += 1
	it.lv = lv
	var r := _learn(it)
	save_game()
	return r

func sell_value(it: Dictionary) -> int:
	return 10 * (it.rar + 1) * it.lv

func sell(it: Dictionary) -> void:
	if slot_of(it.id) != "":
		return
	gold += sell_value(it)
	items.erase(it)
	save_game()

# ---------------- Bonus per la partita ----------------
func run_weapons() -> Array:
	var l: Array = []
	for s in ["weapon1", "weapon2"]:
		var it := equipped_item(s)
		l.append(Gear.BASES[it.base].weapon if not it.is_empty() else "sword")
	return l

## Tutti i bonus dell'equipaggiamento indossato, pronti per la partita
func bonuses() -> Dictionary:
	var b := {
		"hp": 0.0, "atk_pct": 0.0, "aspd_pct": 0.0, "speed_pct": 0.0, "crit": 0.05,
		"room_heal": 8.0, "dmg_taken": 0.0, "first_spark": 0, "dmg_pct": 0.0,
		"double_shot": [false, false], "revive": false, "cheap_forge": false,
		"extra_spark": false, "crit_burn": false, "weapon_atk": [0.0, 0.0], "gold_pct": 0.0,
	}
	for tk in talents:
		if not Data.TALENTS.has(tk):
			continue
		var td: Dictionary = Data.TALENTS[tk]
		var v: float = td.val * int(talents[tk])
		if td.stat == "atk":
			b.weapon_atk[0] += v
			b.weapon_atk[1] += v
		elif td.stat == "first_spark":
			b.first_spark += int(v)
		else:
			b[td.stat] += v
	for s in Gear.SLOTS:
		var it := equipped_item(s)
		if it.is_empty():
			continue
		var t := Gear.type_of(it)
		var ms := Gear.main_stat(it)
		if t == "weapon":
			var wi := 0 if s == "weapon1" else 1
			b.weapon_atk[wi] += ms[2]
			if it.rar >= 2:
				b.weapon_atk[wi] += Gear.RARE_BONUS.weapon[2]
			if it.rar >= 4:
				b.double_shot[wi] = true
			continue
		b[ms[1]] += ms[2]
		if it.rar >= 2:
			var rb: Array = Gear.RARE_BONUS[t]
			b[rb[1]] += rb[2]
		if it.rar >= 4:
			var lg: String = Gear.LEGEND[t][1]
			if lg == "big_heal":
				b.room_heal += 15.0
			else:
				b[lg] = true
	return b

func gear_power() -> int:
	var p := 0
	for s in Gear.SLOTS:
		var it := equipped_item(s)
		if not it.is_empty():
			p += Gear.power(it)
	return p
