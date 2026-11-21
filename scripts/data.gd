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
static func slots_info(slots: Array) -> Array:
	var a: String = slots[0]
	var b: String = slots[1]
	if a == "" and b == "":
		return ["NESSUN ELEMENTO", ""]
	if a == "" or b == "":
		var e := a if a != "" else b
		return [EL_NAME[e], EL_DESC[e]]
	if a == b:
		return FULL[a]
	return COMBOS[combo_key(a, b)]

# ---------------- Armi ----------------
const WEAPONS := {
	"sword": {
		"name": "SPADA", "desc": ["FENDENTI VICINI", "DISTRUGGONO I COLPI"],
		"dmg": 16.0, "rate": 0.42, "speed": 220.0, "range": 95.0, "size": 7.0, "area": 0.0,
		"color": Color("d8dce8"),
	},
	"bow": {
		"name": "ARCO", "desc": ["FRECCE VELOCI", "DA LONTANO"],
		"dmg": 11.0, "rate": 0.48, "speed": 330.0, "range": 400.0, "size": 3.0, "area": 0.0,
		"color": Color("c8a070"),
	},
	"staff": {
		"name": "BASTONE", "desc": ["SFERE LENTE", "ESPLODONO AD AREA"],
		"dmg": 9.0, "rate": 0.8, "speed": 120.0, "range": 400.0, "size": 5.0, "area": 26.0,
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
	"zombie":   {"fam": "undead", "hp": 34.0, "speed": 26.0, "size": 12, "dmg": 10, "sparks": 3, "kind": "melee"},
	"archer":   {"fam": "undead", "hp": 26.0, "speed": 18.0, "size": 12, "dmg": 9, "sparks": 4, "kind": "shooter"},
	"golem":    {"fam": "golem", "hp": 130.0, "speed": 20.0, "size": 20, "dmg": 22, "sparks": 8, "kind": "slammer"},
	"pebble":   {"fam": "golem", "hp": 55.0, "speed": 30.0, "size": 13, "dmg": 9, "sparks": 4, "kind": "shooter"},
	"imp":      {"fam": "ember", "hp": 24.0, "speed": 52.0, "size": 11, "dmg": 8, "sparks": 3, "kind": "melee"},
	"spitter":  {"fam": "ember", "hp": 30.0, "speed": 16.0, "size": 13, "dmg": 9, "sparks": 4, "kind": "spread"},
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

const SPARK_TO_GOLD := 3   # 3 scintille = 1 oro
const BASE_PRICE := 18
const PRICE_STEP := 5
const REROLL_PRICE := 8
