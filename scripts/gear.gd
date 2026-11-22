class_name Gear
## Equipaggiamento permanente: 7 posti, 5 rarità, livelli, unione di pezzi e ricette.

const SLOTS := ["weapon1", "weapon2", "helmet", "armor", "gloves", "boots", "ring"]
const SLOT_NAME := {
	"weapon1": "ARMA 1", "weapon2": "ARMA 2", "helmet": "ELMO", "armor": "ARMATURA",
	"gloves": "GUANTI", "boots": "STIVALI", "ring": "ANELLO",
}
## Tipo di pezzo: le armi vanno in "weapon1" o "weapon2"
const TYPES := ["weapon", "helmet", "armor", "gloves", "boots", "ring"]

const RARITY := [
	{"name": "COMUNE", "color": Color("9c9a96"), "mult": 1.0, "max_lv": 10},
	{"name": "NON COMUNE", "color": Color("62b85a"), "mult": 1.4, "max_lv": 15},
	{"name": "RARO", "color": Color("3f8fe0"), "mult": 1.9, "max_lv": 20},
	{"name": "EPICO", "color": Color("a35ae0"), "mult": 2.6, "max_lv": 25},
	{"name": "LEGGENDARIO", "color": Color("f0a02a"), "mult": 3.5, "max_lv": 30},
]
const RARITY_INFO := [
	"SOLO STATISTICHE BASE",
	"STATISTICHE MIGLIORI",
	"+ UN PICCOLO BONUS",
	"+ SBLOCCA UNA RICETTA",
	"+ UN EFFETTO SPECIALE",
]

const MATERIALS := {
	"bone": {"name": "OSSA", "color": Color("e8e0c8"), "icon": "skull"},
	"stone": {"name": "PIETRA", "color": Color("a0a0b0"), "icon": "rock"},
	"ember": {"name": "BRACE", "color": Color("ff7a2b"), "icon": "fire"},
}
## Materiale lasciato da ogni famiglia di nemici
const FAMILY_MATERIAL := {"undead": "bone", "golem": "stone", "ember": "ember"}

## Pezzi base. "recipe" = combinazione insegnata dal pezzo quando diventa Epico.
const BASES := {
	"sword": {"type": "weapon", "name": "SPADA", "weapon": "sword", "mat": "stone"},
	"bow": {"type": "weapon", "name": "ARCO", "weapon": "bow", "mat": "stone"},
	"staff": {"type": "weapon", "name": "BASTONE", "weapon": "staff", "mat": "stone"},
	"helm_forge": {"type": "helmet", "name": "ELMO DI FONDERIA", "mat": "bone", "recipe": "fire+ice"},
	"helm_ash": {"type": "helmet", "name": "CAPPUCCIO DI CENERE", "mat": "bone"},
	"armor_ember": {"type": "armor", "name": "CORAZZA DI BRACE", "mat": "bone", "recipe": "fire+poison"},
	"armor_plate": {"type": "armor", "name": "PIASTRE ANNERITE", "mat": "bone"},
	"gloves_spark": {"type": "gloves", "name": "GUANTI DELLA SCINTILLA", "mat": "ember"},
	"gloves_smith": {"type": "gloves", "name": "MANOPOLE DEL FABBRO", "mat": "ember"},
	"boots_frost": {"type": "boots", "name": "STIVALI DEL GELO", "mat": "ember", "recipe": "ice+poison"},
	"boots_road": {"type": "boots", "name": "STIVALI DA VIANDANTE", "mat": "ember"},
	"ring_storm": {"type": "ring", "name": "ANELLO DEL TEMPORALE", "mat": "ember", "recipe": "poison+thunder"},
	"ring_coal": {"type": "ring", "name": "ANELLO DI CARBONE", "mat": "ember"},
}

## Ricette conosciute dall'inizio
const START_RECIPES := ["fire+thunder", "ice+thunder"]

## Bonus del Raro e effetto del Leggendario per tipo di pezzo
const RARE_BONUS := {
	"weapon": ["+10% DANNO", "dmg_pct", 0.10],
	"helmet": ["+5 CURA TRA LE STANZE", "room_heal", 5],
	"armor": ["-10% DANNI SUBITI", "dmg_taken", 0.10],
	"gloves": ["+3 SCINTILLE A INIZIO STANZA", "first_spark", 3],
	"boots": ["+5% VELOCITA", "speed_pct", 0.05],
	"ring": ["+5% CRITICO", "crit", 0.05],
}
const LEGEND := {
	"weapon": ["COLPO DOPPIO: SPARA 2 COLPI", "double_shot"],
	"helmet": ["SPIRITO DI FORGIA: +15 CURA TRA LE STANZE", "big_heal"],
	"armor": ["SECONDA VITA: RINASCI UNA VOLTA", "revive"],
	"gloves": ["MANI D'ORO: INCUDINE -25% PREZZO", "cheap_forge"],
	"boots": ["PASSO DI BRACE: +1 SCINTILLA A NEMICO", "extra_spark"],
	"ring": ["CRITICI ARDENTI: I CRITICI BRUCIANO", "crit_burn"],
}

static func type_of(item: Dictionary) -> String:
	return BASES[item.base].type

static func item_name(item: Dictionary) -> String:
	return BASES[item.base].name

static func rarity(item: Dictionary) -> Dictionary:
	return RARITY[item.rar]

static func lv_factor(item: Dictionary) -> float:
	return RARITY[item.rar].mult * (1.0 + 0.12 * (item.lv - 1))

## Statistica principale: [testo, chiave, valore]
static func main_stat(item: Dictionary) -> Array:
	var f := lv_factor(item)
	match type_of(item):
		"weapon": return ["DANNO", "atk_pct", 0.06 * f]
		"helmet": return ["VITA", "hp", roundf(10.0 * f)]
		"armor": return ["VITA", "hp", roundf(16.0 * f)]
		"gloves": return ["VELOCITA D'ATTACCO", "aspd_pct", 0.03 * f]
		"boots": return ["VELOCITA", "speed_pct", 0.025 * f]
		"ring": return ["CRITICO", "crit", 0.025 * f]
	return ["", "", 0]

static func stat_text(item: Dictionary) -> String:
	var s := main_stat(item)
	if s[1] == "hp":
		return "+%d %s" % [int(s[2]), s[0]]
	return "+%d%% %s" % [int(round(s[2] * 100.0)), s[0]]

static func upgrade_cost(item: Dictionary) -> Array:
	# [oro, materiale, quantità]
	return [15 * item.lv * (item.rar + 1), BASES[item.base].mat, 2 + int(item.lv / 2)]

static func power(item: Dictionary) -> int:
	return int(round(10.0 * lv_factor(item)))

## Rarità a caso per le casse: [comune, non comune, raro, epico, leggendario]
const CHEST_ODDS := [60.0, 28.0, 10.0, 2.0, 0.0]

static func roll_rarity(odds: Array) -> int:
	var tot := 0.0
	for o in odds:
		tot += o
	var x := randf() * tot
	for i in odds.size():
		x -= odds[i]
		if x <= 0.0:
			return i
	return 0

static func random_base() -> String:
	var keys := BASES.keys()
	return keys[randi() % keys.size()]
