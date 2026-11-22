class_name Skills
## Abilità della partita: salendo di livello se ne sceglie 1 su 3.
## Valgono solo per la partita in corso (l'equipaggiamento invece resta).

const LIST := {
	"multi": {"name": "Colpo doppio", "desc": "Ogni attacco parte due volte", "max": 2, "cat": "atk"},
	"front": {"name": "Colpo in più", "desc": "Un proiettile in più davanti", "max": 2, "cat": "atk"},
	"diag": {"name": "Diagonali", "desc": "Due colpi in diagonale", "max": 2, "cat": "atk"},
	"side": {"name": "Laterali", "desc": "Un colpo per lato", "max": 1, "cat": "atk"},
	"back": {"name": "Alle spalle", "desc": "Un colpo all'indietro", "max": 1, "cat": "atk"},
	"pierce": {"name": "Perforante", "desc": "I colpi passano attraverso i nemici", "max": 1, "cat": "atk"},
	"bounce": {"name": "Rimbalzo", "desc": "I colpi rimbalzano su muri e rocce", "max": 1, "cat": "atk"},
	"chain": {"name": "Colpo a catena", "desc": "Il colpo salta su un altro nemico", "max": 2, "cat": "atk"},
	"aspd": {"name": "Furia", "desc": "+20% velocità d'attacco", "max": 5, "cat": "atk"},
	"atk": {"name": "Braccio forte", "desc": "+18% danni", "max": 5, "cat": "atk"},
	"crit": {"name": "Occhio di brace", "desc": "+10% colpi critici", "max": 4, "cat": "atk"},
	"orbit": {"name": "Martelli rotanti", "desc": "Martelli che ti girano attorno", "max": 3, "cat": "atk"},
	"spirit": {"name": "Fuocherello", "desc": "Uno spirito di brace spara con te", "max": 2, "cat": "atk"},
	"hp": {"name": "Cuore di ferro", "desc": "+25 vita massima e cura", "max": 5, "cat": "def"},
	"heal": {"name": "Ristoro", "desc": "Recuperi il 40% della vita", "max": 99, "cat": "def"},
	"drain": {"name": "Sete di cenere", "desc": "+3 vita a ogni nemico sconfitto", "max": 3, "cat": "def"},
	"speed": {"name": "Passo leggero", "desc": "+12% velocità di movimento", "max": 3, "cat": "util"},
	"spark": {"name": "Mantice", "desc": "Più scintille per la forgia", "max": 2, "cat": "util"},
}

## Doni dell'Altare delle braci
const ALTAR := {
	"altar_heal": {"name": "Fiamma che cura", "desc": "Recuperi il 60% della vita", "cat": "def", "icon": "heal"},
	"altar_skill": {"name": "Dono della brace", "desc": "Un'abilità a caso, subito", "cat": "atk", "icon": "spark"},
}

const CAT_COLOR := {"atk": Color("ff7a2a"), "def": Color("3fcf7a"), "util": Color("4aa8ff")}
const OUT := Color("120c24")

## Esperienza per passare al livello successivo
static func xp_need(lvl: int) -> int:
	return 6 + lvl * 5

## 3 abilità diverse fra quelle non ancora al massimo
static func roll(owned: Dictionary, hp_ratio: float) -> Array:
	var pool: Array = []
	for k in LIST:
		if int(owned.get(k, 0)) >= int(LIST[k].max):
			continue
		if k == "heal" and hp_ratio > 0.75:
			continue
		pool.append(k)
	pool.shuffle()
	return pool.slice(0, 3)

static func _arrow(cv: CanvasItem, from: Vector2, dir: Vector2, length: float, col: Color, w: float = 2.0) -> void:
	var tip := from + dir * length
	cv.draw_line(from, tip - dir * 2.0, col, w, true)
	var o := dir.orthogonal()
	cv.draw_colored_polygon(PackedVector2Array([tip + dir * 1.5, tip - dir * 3.0 + o * 3.0, tip - dir * 3.0 - o * 3.0]), col)

## Icona tonda dell'abilità, centrata in c, raggio r
static func icon(cv: CanvasItem, key: String, c: Vector2, r: float) -> void:
	var cat: String = LIST[key].cat if LIST.has(key) else "atk"
	var col: Color = CAT_COLOR[cat]
	cv.draw_circle(c, r + 1.8, OUT)
	cv.draw_circle(c, r, col.darkened(0.35))
	cv.draw_circle(c + Vector2(0, -r * 0.12), r * 0.86, col)
	cv.draw_circle(c + Vector2(-r * 0.4, -r * 0.45), r * 0.2, Color(1, 1, 1, 0.35))
	var k := r / 14.0
	var wc := Color.WHITE
	var w := maxf(1.4, 2.2 * k)
	var up := Vector2.UP
	match key:
		"multi":
			_arrow(cv, c + Vector2(-4, 7) * k, up, 12 * k, wc, w)
			_arrow(cv, c + Vector2(4, 3) * k, up, 12 * k, wc, w)
		"front":
			_arrow(cv, c + Vector2(-4, 7) * k, up, 14 * k, wc, w)
			_arrow(cv, c + Vector2(4, 7) * k, up, 14 * k, wc, w)
		"diag":
			_arrow(cv, c + Vector2(0, 6) * k, up, 13 * k, wc, w)
			_arrow(cv, c + Vector2(0, 6) * k, up.rotated(-0.75), 12 * k, wc, w)
			_arrow(cv, c + Vector2(0, 6) * k, up.rotated(0.75), 12 * k, wc, w)
		"side":
			_arrow(cv, c, Vector2.LEFT, 10 * k, wc, w)
			_arrow(cv, c, Vector2.RIGHT, 10 * k, wc, w)
			cv.draw_circle(c, 2.5 * k, wc)
		"back":
			_arrow(cv, c + Vector2(-4, -2) * k, up, 8 * k, wc, w)
			_arrow(cv, c + Vector2(4, 2) * k, Vector2.DOWN, 8 * k, wc, w)
		"pierce":
			cv.draw_arc(c + Vector2(0, -1) * k, 5 * k, 0, TAU, 16, Color(wc, 0.7), 1.5, true)
			_arrow(cv, c + Vector2(0, 9) * k, up, 17 * k, wc, w)
		"bounce":
			var pts := PackedVector2Array([c + Vector2(-8, 6) * k, c + Vector2(-3, -6) * k, c + Vector2(2, 4) * k])
			cv.draw_polyline(pts, wc, w, true)
			_arrow(cv, c + Vector2(2, 4) * k, (Vector2(7, -7)).normalized(), 9 * k, wc, w)
			cv.draw_line(c + Vector2(-9, -8) * k, c + Vector2(3, -8) * k, Color(wc, 0.6), 1.2, true)
		"chain":
			cv.draw_circle(c + Vector2(-6, 5) * k, 3 * k, wc)
			cv.draw_circle(c + Vector2(6, -5) * k, 3 * k, wc)
			cv.draw_polyline(PackedVector2Array([c + Vector2(-4, 3) * k, c + Vector2(1, 1) * k, c + Vector2(-1, -1) * k, c + Vector2(4, -3) * k]), Color("fff3a0"), w, true)
		"aspd":
			for i in 2:
				var y := (2 - i * 7) * k
				cv.draw_polyline(PackedVector2Array([c + Vector2(-7 * k, y + 4 * k), c + Vector2(0, y - 3 * k), c + Vector2(7 * k, y + 4 * k)]), wc, w + 0.5, true)
		"atk":
			Art.icon(cv, "sword", c - Vector2(3.5, 3.5) * 2.4 * k, 2.4 * k, wc)
		"crit":
			var pts := PackedVector2Array()
			for i in 8:
				var rr := (10.0 if i % 2 == 0 else 3.5) * k
				pts.append(c + Vector2.from_angle(-PI / 2 + i * TAU / 8.0) * rr)
			cv.draw_colored_polygon(pts, Color("fff3a0"))
		"orbit":
			cv.draw_arc(c, 8 * k, 0, TAU, 24, Color(wc, 0.6), 1.2, true)
			cv.draw_circle(c, 2.5 * k, wc)
			for i in 2:
				var p := c + Vector2.from_angle(-0.6 + i * PI) * 8 * k
				cv.draw_rect(Rect2(p - Vector2(3, 2) * k, Vector2(6, 4) * k), Color("e8ecf8"))
		"spirit":
			Art.icon(cv, "fire", c - Vector2(3.5, 3.5) * 2.4 * k, 2.4 * k, Color("ffe14a"))
		"hp":
			Art.icon(cv, "heart", c - Vector2(3.5, 3.5) * 2.4 * k, 2.4 * k, wc)
		"heal":
			Art.icon(cv, "heart", c - Vector2(3.5, 3.5) * 2.4 * k, 2.4 * k, wc)
			cv.draw_line(c + Vector2(-3, 0) * k, c + Vector2(3, 0) * k, col, 2.0, true)
			cv.draw_line(c + Vector2(0, -3) * k, c + Vector2(0, 3) * k, col, 2.0, true)
		"drain":
			Art.icon(cv, "skull", c - Vector2(3.5, 3.5) * 2.2 * k, 2.2 * k, wc)
		"speed":
			Art.icon(cv, "boots", c - Vector2(3.5, 3.5) * 2.4 * k, 2.4 * k, wc)
		"spark":
			Art.icon(cv, "spark", c - Vector2(3.5, 3.5) * 2.4 * k, 2.4 * k, Color("fff3a0"))
