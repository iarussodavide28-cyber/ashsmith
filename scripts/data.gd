class_name Data
## Tutti i numeri del gioco in un posto solo, così si bilancia facilmente.

const ELEMENTS := ["fire", "ice", "thunder", "poison"]

const EL_NAME := {"fire": "FUOCO", "ice": "GHIACCIO", "thunder": "TUONO", "poison": "VELENO"}
const EL_COLOR := {
	"fire": Color("ff7a2b"), "ice": Color("6fd6ff"),
	"thunder": Color("ffe14a"), "poison": Color("7dff5a"),
}
const EL_DESC := {
	"fire": "BRUCIA NEL TEMPO",
	"ice": "RALLENTA I NEMICI",
	"thunder": "SALTA A UN VICINO",
	"poison": "SI ACCUMULA A OGNI COLPO",
}
## Nome ed effetto con 2 elementi uguali (effetto pieno)
const FULL := {
	"fire": ["INFERNO", "BRUCIA MOLTO DI PIU"],
	"ice": ["LAMA GELIDA", "RALLENTA MOLTO E CONGELA"],
	"thunder": ["TEMPESTA", "SALTA A 3 NEMICI"],
	"poison": ["PESTILENZA", "ACCUMULO DOPPIO"],
}
## Combinazioni di 2 elementi diversi: chiave in ordine alfabetico
const COMBOS := {
	"fire+thunder": ["ESPLOSIONE", "IL COLPO ESPLODE AD AREA"],
	"ice+poison": ["CONGELAMENTO TOSSICO", "VELENO ETERNO SUI RALLENTATI"],
	"fire+ice": ["VAPORE", "NUBE: I NEMICI SBAGLIANO MIRA"],
	"fire+poison": ["FUMO TOSSICO", "NUBE CHE FA DANNO A TERRA"],
	"ice+thunder": ["FRANTUMARE", "I RALLENTATI VANNO IN PEZZI"],
	"poison+thunder": ["CONTAGIO", "IL FULMINE PORTA IL VELENO"],
}

static func combo_key(a: String, b: String) -> String:
	var l := [a, b]
	l.sort()
	return "%s+%s" % [l[0], l[1]]

## Nome e descrizione di quello che c'è negli incastri di un'arma
static func slots_info(slots: Array, recipes: Array = []) -> Array:
	var a: String = slots[0]
	var b: String = slots[1]
	if a == "" and b == "":
		return ["NESSUN ELEMENTO", ""]
	if a == "" or b == "":
		var e := a if a != "" else b
		return [EL_NAME[e], EL_DESC[e]]
	if a == b:
		return FULL[a]
	var k := combo_key(a, b)
	if not recipes.is_empty() and not k in recipes:
		return ["%s + %s" % [EL_NAME[a], EL_NAME[b]], "RICETTA SCONOSCIUTA: SOLO EFFETTI LEGGERI"]
	return COMBOS[k]

# ---------------- Armi ----------------
const WEAPONS := {
	"sword": {
		"name": "SPADA", "desc": ["FENDENTI VICINI", "DISTRUGGONO I COLPI", "-15% DANNI SUBITI"],
		"dmg": 21.0, "rate": 0.5, "speed": 230.0, "range": 80.0, "size": 10.0, "area": 0.0, "crit": 0.0, "guard": 0.15,
		"color": Color("d8dce8"),
	},
	"bow": {
		"name": "ARCO", "desc": ["FRECCE VELOCI", "DA LONTANO", "+12% CRITICI"],
		"dmg": 13.0, "rate": 0.42, "speed": 360.0, "range": 400.0, "size": 3.0, "area": 0.0, "crit": 0.12, "guard": 0.0,
		"color": Color("c8a070"),
	},
	"staff": {
		"name": "BASTONE", "desc": ["SFERE LENTE", "ESPLODONO AD AREA", "COLPISCE I GRUPPI"],
		"dmg": 14.0, "rate": 0.75, "speed": 145.0, "range": 400.0, "size": 5.0, "area": 30.0, "crit": 0.0, "guard": 0.0,
		"color": Color("c78cff"),
	},
}
const WEAPON_ORDER := ["sword", "bow", "staff"]
const SWITCH_COOLDOWN := 1.2

# ---------------- Famiglie di nemici ----------------
## weak = debole a, resist = resiste a, immune = nessun effetto
const FAMILIES := {
	"undead": {"name": "NON-MORTI", "short": "NON-MORTI", "weak": "fire", "resist": "", "immune": "poison"},
	"golem": {"name": "GOLEM", "short": "GOLEM", "weak": "thunder", "resist": "fire", "immune": ""},
	"ember": {"name": "CREATURE DI BRACE", "short": "BRACE", "weak": "ice", "resist": "", "immune": "fire"},
}

const ENEMIES := {
	"zombie":   {"fam": "undead", "hp": 34.0, "speed": 26.0, "size": 17, "dmg": 10, "sparks": 3, "kind": "melee"},
	"archer":   {"fam": "undead", "hp": 26.0, "speed": 18.0, "size": 17, "dmg": 9, "sparks": 4, "kind": "shooter"},
	"golem":    {"fam": "golem", "hp": 130.0, "speed": 20.0, "size": 28, "dmg": 22, "sparks": 8, "kind": "slammer"},
	"pebble":   {"fam": "golem", "hp": 55.0, "speed": 30.0, "size": 18, "dmg": 9, "sparks": 4, "kind": "shooter"},
	"imp":      {"fam": "ember", "hp": 24.0, "speed": 52.0, "size": 16, "dmg": 8, "sparks": 3, "kind": "melee"},
	"spitter":  {"fam": "ember", "hp": 30.0, "speed": 16.0, "size": 18, "dmg": 9, "sparks": 4, "kind": "spread"},
}

## Danno moltiplicato in base agli elementi dell'arma e alla famiglia
static func element_mult(slots: Array, fam: String, boss_weak: String = "") -> float:
	var f: Dictionary = FAMILIES.get(fam, {})
	var m := 1.0
	for e in slots:
		if e == "":
			continue
		if boss_weak != "":
			m += 0.6 if e == boss_weak else -0.15
		elif e == f.get("weak", ""):
			m += 0.6
		elif e == f.get("resist", ""):
			m -= 0.35
		elif e == f.get("immune", ""):
			m -= 0.45
	return clampf(m, 0.15, 2.2)

# ---------------- Capitolo ----------------
const ROOMS := 12
const BIG_FORGE_ROOMS := [4, 8]
const MINIBOSS_ROOM := 7
const BOSS_ROOM := 12

## Ondate di ogni stanza (1-11). Ogni ondata è una lista di nemici.
const WAVES := {
	1: [["zombie", "zombie", "zombie"], ["zombie", "archer"]],
	2: [["imp", "imp", "imp"], ["spitter", "imp", "imp"]],
	3: [["zombie", "zombie", "archer", "archer"], ["pebble", "zombie", "zombie"]],
	4: [["imp", "imp", "spitter", "spitter"], ["golem"]],
	5: [["zombie", "zombie", "zombie", "archer"], ["imp", "imp", "imp", "spitter"]],
	6: [["golem", "pebble"], ["archer", "archer", "zombie", "zombie"]],
	8: [["spitter", "spitter", "imp", "imp"], ["golem", "zombie", "zombie"]],
	9: [["golem", "golem"], ["pebble", "pebble", "archer"]],
	10: [["imp", "imp", "imp", "imp", "spitter"], ["golem", "spitter", "spitter"]],
	11: [["zombie", "zombie", "zombie", "archer", "archer"], ["golem", "imp", "imp", "spitter"]],
}

## Talenti: potenziamenti permanenti comprati con l'oro
const TALENTS := {
	"vigore": {"name": "Vigore", "desc": "+12 vita massima", "max": 10, "icon": "hp", "stat": "hp", "val": 12.0},
	"forza": {"name": "Forza", "desc": "+4% danni con le armi", "max": 10, "icon": "atk", "stat": "atk", "val": 0.04},
	"tempra": {"name": "Tempra", "desc": "-2% danni subiti", "max": 10, "icon": "drain", "stat": "dmg_taken", "val": 0.02},
	"ristoro": {"name": "Ristoro", "desc": "+3 cura tra le stanze", "max": 10, "icon": "heal", "stat": "room_heal", "val": 3.0},
	"avidita": {"name": "Avidità", "desc": "+6% oro a fine partita", "max": 10, "icon": "spark", "stat": "gold_pct", "val": 0.06},
	"mantice": {"name": "Mantice", "desc": "+1 scintilla a ogni stanza", "max": 5, "icon": "aspd", "stat": "first_spark", "val": 1.0},
}
const TALENT_ORDER := ["vigore", "forza", "tempra", "ristoro", "avidita", "mantice"]

static func talent_cost(lv: int) -> int:
	return 120 + lv * 140

const SPARK_TO_GOLD := 3   # 3 scintille = 1 oro
const BASE_PRICE := 18
const PRICE_STEP := 5
const REROLL_PRICE := 8
