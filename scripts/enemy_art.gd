class_name EnemyArt
## Nemici disegnati a mano (vettoriale), contorni netti e niente sfocature.
## Ogni nemico è progettato in una griglia di circa 20x20 unità: (0,0) è il
## centro del corpo, y=+10 sono i piedi. "u" converte le unità in pixel.

const OUT := Color("0b0a0e")
const BONE := Color("dcd2b8")
const BONE_D := Color("8e8470")
const LAVA := Color("ff6a1a")
const LAVA_L := Color("ffc060")

static var _fl := 0.0     # lampo bianco quando il nemico viene colpito
static var _c := Vector2.ZERO
static var _u := 1.0

static func _C(col: Color) -> Color:
	if _fl <= 0.0:
		return col
	return Color(col.lerp(Color.WHITE, _fl * 0.85), col.a)

static func _P(v: Vector2) -> Vector2:
	return _c + v * _u

static func _arr(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in pts:
		out.append(_P(v))
	return out

## poligono con sfumatura verticale e contorno
static func _g(cv: CanvasItem, pts: Array, top: Color, bot: Color, w: float = 1.0) -> void:
	var p := _arr(pts)
	if OS.is_debug_build() and Geometry2D.triangulate_polygon(p).is_empty():
		print("BADPOLY ", pts)
	Art.grad_poly(cv, p, _C(top), _C(bot))
	var q := p.duplicate()
	q.append(p[0])
	cv.draw_polyline(q, OUT, maxf(0.6, w * _u * 0.6), true)

## poligono pieno senza contorno (luci, ombre, dettagli)
static func _f(cv: CanvasItem, pts: Array, col: Color) -> void:
	if OS.is_debug_build() and Geometry2D.triangulate_polygon(_arr(pts)).is_empty():
		print("BADFILL ", pts)
	cv.draw_colored_polygon(_arr(pts), _C(col))

static func _l(cv: CanvasItem, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	cv.draw_line(_P(a), _P(b), _C(col), maxf(0.4, w * _u), true)

## linea con contorno scuro (arti, ossa)
static func _lo(cv: CanvasItem, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	cv.draw_line(_P(a), _P(b), OUT, maxf(1.0, (w + 0.8) * _u), true)
	cv.draw_line(_P(a), _P(b), _C(col), maxf(0.5, w * _u), true)

static func _pl(cv: CanvasItem, pts: Array, col: Color, w: float) -> void:
	cv.draw_polyline(_arr(pts), _C(col), maxf(0.4, w * _u), true)

static func _dot(cv: CanvasItem, p: Vector2, r: float, col: Color, outline: bool = false) -> void:
	if outline:
		cv.draw_circle(_P(p), (r + 0.45) * _u, OUT)
	cv.draw_circle(_P(p), r * _u, _C(col))

static func _ell(cv: CanvasItem, p: Vector2, rx: float, ry: float, col: Color) -> void:
	HeroArt.ellipse(cv, _P(p), rx * _u, ry * _u, _C(col))

static func _glint(cv: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	Art.glow(cv, _P(p), r * _u, col)

## e = dati del nemico, bc = centro, r = raggio, t = tempo, look = verso l'eroe
static func draw(cv: CanvasItem, e: Dictionary, bc: Vector2, r: float, t: float, look: Vector2, moving: bool) -> void:
	_fl = clampf(float(e.get("flash", 0.0)), 0.0, 1.0)
	_c = bc
	_u = r / 9.0
	var ph := t * 10.0 + bc.x * 0.3
	match e.k:
		"zombie": _thrall(cv, t, ph, look, moving)
		"archer": _archer(cv, t, ph, look, moving)
		"imp": _imp(cv, t, look)
		"spitter": _toad(cv, t, look)
		"pebble": _shard(cv, t, look)
		"golem": _golem(cv, t, ph, look, moving, false)
		"miniboss": _golem(cv, t, ph, look, moving, true)
		"boss": _lord(cv, t, look, int(e.get("phase", 1)))
	_fl = 0.0

# ---------------------------------------------------------------------
#  Servo di cenere: operaio della fonderia, curvo, con grembiule e gancio
# ---------------------------------------------------------------------
static func _thrall(cv: CanvasItem, t: float, ph: float, look: Vector2, moving: bool) -> void:
	var lx := look.x
	var stp := sin(ph) * 1.6 if moving else 0.0
	var skin := Color("8c857a")
	var skin_d := Color("47423a")
	# gambe trascinate
	for sx in [-1.0, 1.0]:
		var fy: float = 9.0 + stp * sx
		_lo(cv, Vector2(sx * 2.2, 3), Vector2(sx * 2.8, fy - 1), Color("3a3028"), 1.8)
		_g(cv, [Vector2(sx * 2.8 - 1.8, fy - 1.5), Vector2(sx * 2.8 + 1.8, fy - 1.5), Vector2(sx * 2.8 + 2.2, fy + 0.6), Vector2(sx * 2.8 - 2.0, fy + 0.6)], Color("4a3a2c"), Color("1e1610"), 0.9)
	# braccio sinistro lungo, penzolante verso l'eroe
	var sw := sin(ph * 0.5) * 0.8
	var hl := Vector2(-6.8, 3.5 + sw) + look * 2.5
	_lo(cv, Vector2(-5, -4), Vector2(-6.4, -0.5), skin, 1.9)
	_lo(cv, Vector2(-6.4, -0.5), hl, skin, 1.6)
	for f in 3:
		_l(cv, hl, hl + Vector2(-0.6 + f * 0.6, 1.6), BONE, 0.5)
	# busto curvo
	_g(cv, [Vector2(-6, -5), Vector2(-1, -6.8), Vector2(5.5, -5.5), Vector2(6, 1.5), Vector2(4, 5), Vector2(-4, 5), Vector2(-6.2, 1.5)], skin, skin_d)
	# costole e crepe di brace sul petto
	for i in 3:
		_pl(cv, [Vector2(-5, -3 + i * 1.6), Vector2(-3.2, -3.6 + i * 1.6), Vector2(-1.8, -3.2 + i * 1.6)], Color(0, 0, 0, 0.35), 0.5)
	_pl(cv, [Vector2(3.6, -4.6), Vector2(2.4, -2.8), Vector2(3.3, -1.6), Vector2(2.2, 0)], LAVA, 0.6)
	_dot(cv, Vector2(2.4, -2.8), 0.45, LAVA_L)
	# grembiule di cuoio strappato con rivetti
	_g(cv, [Vector2(-4.2, -1.5), Vector2(4.4, -1.5), Vector2(5, 7.5), Vector2(2.6, 6.4), Vector2(1.6, 8), Vector2(-0.6, 6.6), Vector2(-2.6, 7.8), Vector2(-5, 7)], Color("6a4428"), Color("2c1a0e"), 0.9)
	_l(cv, Vector2(-3.6, -0.6), Vector2(3.8, -0.6), Color("8a6038"), 0.5)
	for sx in [-1.0, 1.0]:
		_dot(cv, Vector2(sx * 3.4, -0.6), 0.45, Color("c8a060"))
	_l(cv, Vector2(-1.5, 2), Vector2(-0.6, 5), Color(0, 0, 0, 0.4), 0.5)
	# collare di ferro con catena
	_g(cv, [Vector2(-3.8, -6.6), Vector2(3.8, -6.6), Vector2(3.6, -5), Vector2(-3.6, -5)], Color("6a6672"), Color("2a2830"), 0.8)
	for i in 3:
		var cp := Vector2(4.2 + i * 0.9, -4.5 + i * 1.4)
		cv.draw_arc(_P(cp), 0.7 * _u, 0, TAU, 8, OUT, maxf(1.2, 0.9 * _u), true)
		cv.draw_arc(_P(cp), 0.7 * _u, 0, TAU, 8, _C(Color("7a7682")), maxf(0.7, 0.45 * _u), true)
	# braccio destro con gancio arrugginito
	var hr := Vector2(7, 2.5 - sw) + look * 2.5
	_lo(cv, Vector2(5, -4), Vector2(6.8, -0.8), skin, 1.9)
	_lo(cv, Vector2(6.8, -0.8), hr, skin, 1.6)
	cv.draw_arc(_P(hr + Vector2(0.4, 1.6)), 1.4 * _u, -PI * 0.2, PI * 1.1, 10, OUT, maxf(1.8, 1.4 * _u), true)
	cv.draw_arc(_P(hr + Vector2(0.4, 1.6)), 1.4 * _u, -PI * 0.2, PI * 1.1, 10, _C(Color("9a6a40")), maxf(0.9, 0.7 * _u), true)
	# testa bassa e in avanti: pelle cinerea, arcate pesanti, bocca cucita
	var h := Vector2(lx * 1.6, -8.4)
	_g(cv, [h + Vector2(-3, -2.2), h + Vector2(-1.2, -3.4), h + Vector2(1.4, -3.3), h + Vector2(3.1, -1.8), h + Vector2(3.2, 0.8), h + Vector2(2, 2.8), h + Vector2(0, 3.3), h + Vector2(-2, 2.8), h + Vector2(-3.2, 0.8)], Color("948c7c"), Color("4e483e"))
	# cuoio capelluto bruciato e cicatrice
	_f(cv, [h + Vector2(-2.8, -2), h + Vector2(-1.2, -3.3), h + Vector2(1.4, -3.2), h + Vector2(2.9, -1.8), h + Vector2(1.2, -2.4), h + Vector2(-1, -2.3)], Color("2a2420"))
	_pl(cv, [h + Vector2(1.8, -1.6), h + Vector2(2.4, 0.2), h + Vector2(2.0, 1.4)], Color("6a3a2a"), 0.35)
	# arcata sopraccigliare
	_pl(cv, [h + Vector2(-2.4, -0.9), h + Vector2(-0.4, -0.5), h + Vector2(0.4, -0.5), h + Vector2(2.4, -0.9)], Color("3a342c"), 0.7)
	# occhi incavati con braci
	for sx in [-1.0, 1.0]:
		var ep := h + Vector2(sx * 1.25 + lx * 0.4, 0.0 + look.y * 0.2)
		_ell(cv, ep, 0.95, 0.6, Color("15110e"))
		_dot(cv, ep, 0.36, LAVA_L)
	# naso e bocca cucita
	_f(cv, [h + Vector2(0, 0.2), h + Vector2(-0.5, 1.3), h + Vector2(0.5, 1.3)], Color("5e5648"))
	_l(cv, h + Vector2(-1.3, 2.1), h + Vector2(1.3, 2.1), Color("1a1410"), 0.45)
	for i in 4:
		_l(cv, h + Vector2(-0.9 + i * 0.6, 1.8), h + Vector2(-0.9 + i * 0.6, 2.4), Color("b8a888"), 0.25)

# ---------------------------------------------------------------------
#  Balestriere d'ossa: scheletro incappucciato con balestra d'osso
# ---------------------------------------------------------------------
static func _archer(cv: CanvasItem, t: float, ph: float, look: Vector2, moving: bool) -> void:
	var stp := sin(ph) * 1.3 if moving else 0.0
	var lx := look.x
	# faretra sulle spalle
	_g(cv, [Vector2(3, -8), Vector2(6, -7), Vector2(5, 1), Vector2(2.4, 0.4)], Color("5a3a24"), Color("24160c"), 0.8)
	for i in 3:
		var fp := Vector2(3.6 + i * 0.9, -8.6 + i * 0.3)
		_f(cv, [fp, fp + Vector2(0.5, -1.6), fp + Vector2(1.0, 0)], Color("b83a34"))
	# mantello lacero dietro
	var fl := sin(t * 3.0) * 0.5
	_g(cv, [Vector2(-5.6, -6), Vector2(5.6, -6), Vector2(6.8, 7.5 + fl), Vector2(4.4, 6), Vector2(2.6, 9 - fl), Vector2(0.4, 6.4), Vector2(-1.8, 9.2 + fl), Vector2(-4, 6.4), Vector2(-6.8, 7.8)], Color("3c3038"), Color("120e14"))
	# gambe d'osso
	for sx in [-1.0, 1.0]:
		var fy: float = 9.2 + stp * sx
		_lo(cv, Vector2(sx * 1.6, 3.4), Vector2(sx * 2.2, fy), BONE, 0.9)
		_dot(cv, Vector2(sx * 1.9, 6.2 + stp * sx * 0.5), 0.6, BONE_D)
		_f(cv, [Vector2(sx * 2.2 - 1.2, fy), Vector2(sx * 2.2 + 1.4, fy), Vector2(sx * 2.2 + 1.0, fy + 0.8), Vector2(sx * 2.2 - 1.0, fy + 0.8)], BONE_D)
	# colonna, costole e bacino
	_lo(cv, Vector2(0, -5), Vector2(0, 3.4), BONE, 0.9)
	for i in 3:
		var ry := -3.8 + i * 1.6
		var rw := 3.6 - i * 0.5
		cv.draw_arc(_P(Vector2(0, ry - 1.2)), rw * _u, PI * 0.18, PI * 0.82, 10, OUT, maxf(1.6, 1.5 * _u), true)
		cv.draw_arc(_P(Vector2(0, ry - 1.2)), rw * _u, PI * 0.18, PI * 0.82, 10, _C(BONE), maxf(0.8, 0.7 * _u), true)
	_g(cv, [Vector2(-2.6, 2.6), Vector2(2.6, 2.6), Vector2(1.8, 4.4), Vector2(-1.8, 4.4)], BONE, BONE_D, 0.8)
	# cappuccio
	_g(cv, [Vector2(-4.6, -4.6), Vector2(-4.4, -9.6), Vector2(-1.2, -12.6), Vector2(1.6, -12.2), Vector2(4.4, -9.6), Vector2(4.6, -4.6), Vector2(0, -3.6)], Color("44363e"), Color("181218"))
	_f(cv, [Vector2(-3.2, -5.2), Vector2(-3, -9.2), Vector2(0, -11), Vector2(3, -9.2), Vector2(3.2, -5.2), Vector2(0, -4.6)], Color("0e0a10"))
	# teschio
	var s := Vector2(lx * 0.8, -7.6)
	_g(cv, [s + Vector2(-2.5, -1.4), s + Vector2(-1.2, -2.6), s + Vector2(1.2, -2.6), s + Vector2(2.5, -1.4), s + Vector2(2.3, 1), s + Vector2(1.1, 2.4), s + Vector2(-1.1, 2.4), s + Vector2(-2.3, 1)], Color("eee4cc"), Color("a89c84"), 0.8)
	for sx in [-1.0, 1.0]:
		_ell(cv, s + Vector2(sx * 1.1, -0.2), 0.85, 0.75, Color("0a0808"))
		_dot(cv, s + Vector2(sx * 1.1 + lx * 0.25, -0.2), 0.3, Color("ff3a2a"))
	_f(cv, [s + Vector2(0, 0.6), s + Vector2(-0.4, 1.2), s + Vector2(0.4, 1.2)], Color("2a2420"))
	for i in 4:
		_l(cv, s + Vector2(-0.9 + i * 0.6, 1.7), s + Vector2(-0.9 + i * 0.6, 2.3), Color("3a3028"), 0.3)
	# balestra d'osso puntata verso l'eroe
	var base := Vector2(0, -1.6)
	var tip := base + look * 7.5
	var o := look.orthogonal()
	_lo(cv, base, tip, Color("6a4a2c"), 1.1)
	var a1 := tip - look * 1.2 + o * 4.2
	var a2 := tip - look * 1.2 - o * 4.2
	_pl(cv, [a1, tip, a2], OUT, 2.0)
	_pl(cv, [a1, tip, a2], BONE, 1.0)
	_l(cv, a1, base + look * 2.2, Color("c8c0b0"), 0.35)
	_l(cv, a2, base + look * 2.2, Color("c8c0b0"), 0.35)
	_l(cv, base + look * 2.2, tip + look * 1.4, Color("e8ecf8"), 0.5)
	# mani d'osso sull'arma
	_dot(cv, base + look * 1.0 + o * 0.6, 0.6, BONE)
	_dot(cv, base + look * 4.6 - o * 0.4, 0.6, BONE)

# ---------------------------------------------------------------------
#  Scintilla: diavoletto di carbone con il cuore fuso e la coda di fuoco
# ---------------------------------------------------------------------
static func _imp(cv: CanvasItem, t: float, look: Vector2) -> void:
	var hov := sin(t * 7.0) * 0.8
	_c += Vector2(0, hov) * _u
	var flap := sin(t * 20.0)
	var skin := Color("3e2a26")
	var skin_d := Color("140a08")
	# coda con punta infuocata
	var tail := [Vector2(1, 4), Vector2(4, 6.5), Vector2(7, 6), Vector2(8.2, 3.6)]
	_pl(cv, tail, OUT, 1.6)
	_pl(cv, tail, skin, 0.8)
	var tt := Vector2(8.2, 3.6)
	_f(cv, [tt + Vector2(-1, 0.4), tt + Vector2(0.2, -2.4 - flap * 0.4), tt + Vector2(1.2, 0.2), tt + Vector2(0, 1)], LAVA)
	_f(cv, [tt + Vector2(-0.4, 0.2), tt + Vector2(0.2, -1.2), tt + Vector2(0.6, 0.2)], LAVA_L)
	# ali membranose con dita d'osso
	for sx in [-1.0, 1.0]:
		var wb := Vector2(sx * 2, -2.4)
		var up := flap * 1.6
		var w1 := wb + Vector2(sx * 6.2, -3.2 - up)
		var w2 := wb + Vector2(sx * 9.0, -0.8 - up * 0.6)
		var w3 := wb + Vector2(sx * 7.0, 2.8 - up * 0.3)
		_g(cv, [wb, w1, wb + Vector2(sx * 6.8, -1.2 - up * 0.8), w2, wb + Vector2(sx * 6.4, 1.4 - up * 0.4), w3, wb + Vector2(sx * 2, 2.4)], Color("a8382a"), Color("4a1008"), 0.8)
		_l(cv, wb, w1, Color("a07060"), 0.4)
		_l(cv, wb, w2, Color("a07060"), 0.4)
		_l(cv, wb, w3, Color("a07060"), 0.4)
	# gambe corte con artigli
	for sx in [-1.0, 1.0]:
		_lo(cv, Vector2(sx * 1.4, 3.6), Vector2(sx * 2.2, 6.6), skin, 1.0)
		for f in 2:
			_l(cv, Vector2(sx * 2.2, 6.6), Vector2(sx * (1.6 + f * 1.2), 7.6), BONE, 0.4)
	# busto di carbone con crepe incandescenti
	_g(cv, [Vector2(-3.2, -3.4), Vector2(3.2, -3.4), Vector2(2.8, 2.4), Vector2(1.4, 4.6), Vector2(-1.4, 4.6), Vector2(-2.8, 2.4)], skin, skin_d)
	_pl(cv, [Vector2(-2.2, -2.6), Vector2(-1, -0.6), Vector2(-1.8, 1.6)], LAVA, 0.45)
	_pl(cv, [Vector2(2.2, -2), Vector2(1.2, 0.4), Vector2(2, 2.6)], LAVA, 0.45)
	# cuore fuso
	_glint(cv, Vector2(0, -0.6), 3.2, Color(1, 0.5, 0.15, 0.45))
	_dot(cv, Vector2(0, -0.6), 1.25, LAVA, true)
	_dot(cv, Vector2(0, -0.8), 0.55, Color("fff4d0"))
	# braccia con artigli protese
	for sx in [-1.0, 1.0]:
		var hand := Vector2(sx * 4.6, 0.6) + look * 1.6
		_lo(cv, Vector2(sx * 2.8, -2.6), hand, skin, 0.9)
		for f in 3:
			_l(cv, hand, hand + Vector2(sx * 0.3 + (f - 1) * 0.5, 1.3), BONE, 0.35)
	# testa con corna ricurve
	var h := Vector2(look.x * 0.8, -6.4)
	for sx in [-1.0, 1.0]:
		var hb := h + Vector2(sx * 1.8, -1.8)
		_g(cv, [hb + Vector2(-sx * 1.0, 0.8), hb + Vector2(sx * 0.3, -1.6), hb + Vector2(sx * 1.6, -3.4), hb + Vector2(sx * 2.8, -5.2), hb + Vector2(sx * 1.4, -1.8), hb + Vector2(sx * 1.1, 0.8)], Color("efe4c8"), Color("8a7a60"), 0.7)
	_g(cv, [h + Vector2(-2.8, -1.8), h + Vector2(0, -2.8), h + Vector2(2.8, -1.8), h + Vector2(2.6, 1), h + Vector2(0.8, 2.8), h + Vector2(-0.8, 2.8), h + Vector2(-2.6, 1)], Color("4e3430"), skin_d)
	# occhi a fessura gialli
	for sx in [-1.0, 1.0]:
		var ep := h + Vector2(sx * 1.2 + look.x * 0.3, -0.2)
		_f(cv, [ep + Vector2(-sx * 0.9, -0.4), ep + Vector2(sx * 0.9, 0.2), ep + Vector2(-sx * 0.6, 0.5)], Color("ffe14a"))
	# ghigno
	_pl(cv, [h + Vector2(-1.4, 1.2), h + Vector2(0, 1.8), h + Vector2(1.4, 1.2)], Color("ff9a3a"), 0.4)

# ---------------------------------------------------------------------
#  Rospo di scoria: tozzo, schiena di roccia, pustole di lava, bocca fusa
# ---------------------------------------------------------------------
static func _toad(cv: CanvasItem, t: float, look: Vector2) -> void:
	var br := sin(t * 2.6) * 0.3
	var rock := Color("4e3028")
	var rock_d := Color("1c0e0a")
	# zampe posteriori
	for sx in [-1.0, 1.0]:
		_g(cv, [Vector2(sx * 6, 1), Vector2(sx * 10, 3), Vector2(sx * 10.4, 7), Vector2(sx * 7, 7.4), Vector2(sx * 5, 5)], rock, rock_d, 0.9)
	# corpo
	_g(cv, [Vector2(-8.8, 3), Vector2(-8.2, -2.6), Vector2(-5, -5.8 - br), Vector2(0, -6.6 - br), Vector2(5, -5.8 - br), Vector2(8.2, -2.6), Vector2(8.8, 3), Vector2(6, 6.4), Vector2(-6, 6.4)], rock, rock_d)
	# placche di roccia sulla schiena
	_g(cv, [Vector2(-5, -5), Vector2(-1.6, -6.2), Vector2(-0.8, -3.2), Vector2(-4.4, -2.4)], Color("6a463a"), Color("3a2018"), 0.7)
	_g(cv, [Vector2(1.2, -6.2), Vector2(5, -5), Vector2(4.6, -2.4), Vector2(0.8, -3.2)], Color("6a463a"), Color("3a2018"), 0.7)
	_g(cv, [Vector2(-2.4, -2.8), Vector2(2.4, -2.8), Vector2(1.6, -0.6), Vector2(-1.6, -0.6)], Color("5e3c30"), Color("341c14"), 0.7)
	# pustole di lava che pulsano
	var pu := 0.7 + 0.3 * sin(t * 5.0)
	for p in [Vector2(-6.6, -1), Vector2(6.4, -0.6), Vector2(-3.2, 0.6), Vector2(3.6, 0.8), Vector2(0, -4.6)]:
		_dot(cv, p, 0.95, Color(0.3, 0.08, 0.04), true)
		_dot(cv, p, 0.7, Color(LAVA, pu))
		_dot(cv, p + Vector2(-0.2, -0.2), 0.28, LAVA_L)
	# zampe anteriori con dita
	for sx in [-1.0, 1.0]:
		var fp := Vector2(sx * 5.4, 7.2)
		_lo(cv, Vector2(sx * 4.6, 3.6), fp, rock, 1.3)
		for f in 3:
			_l(cv, fp, fp + Vector2((f - 1) * 0.9, 1.0), Color("6a463a"), 0.5)
	# bocca larga piena di magma
	var m := Vector2(look.x * 0.8, 3.2)
	_f(cv, [m + Vector2(-5, -0.8), m + Vector2(5, -0.8), m + Vector2(3.6, 1.6), m + Vector2(0, 2.4), m + Vector2(-3.6, 1.6)], OUT)
	_f(cv, [m + Vector2(-4, -0.2), m + Vector2(4, -0.2), m + Vector2(2.8, 1.1), m + Vector2(0, 1.7), m + Vector2(-2.8, 1.1)], LAVA)
	_f(cv, [m + Vector2(-2, 0.2), m + Vector2(2, 0.2), m + Vector2(0, 1.0)], LAVA_L)
	var dr := fmod(t * 1.4, 1.0)
	_dot(cv, m + Vector2(2.4, 1.6 + dr * 2.4), 0.5 * (1.0 - dr * 0.5), LAVA)
	_pl(cv, [m + Vector2(-5.2, -1), m + Vector2(0, -1.6), m + Vector2(5.2, -1)], Color("7a5040"), 0.5)
	# occhi sporgenti sopra la testa
	for sx in [-1.0, 1.0]:
		var ep := Vector2(sx * 3.8, -4.6 - br)
		_dot(cv, ep, 1.9, rock, true)
		_dot(cv, ep + Vector2(0, 0.1), 1.35, Color("ffd040"))
		_f(cv, [ep + Vector2(look.x * 0.4, -1.0), ep + Vector2(look.x * 0.4 + 0.35, 0.2), ep + Vector2(look.x * 0.4, 1.1), ep + Vector2(look.x * 0.4 - 0.35, 0.2)], OUT)
		_dot(cv, ep + Vector2(-0.6, -0.6), 0.3, Color(1, 1, 1, 0.9))

# ---------------------------------------------------------------------
#  Frammento runico: pietra d'ossidiana che fluttua, schegge che orbitano
# ---------------------------------------------------------------------
static func _shard(cv: CanvasItem, t: float, look: Vector2) -> void:
	var hov := sin(t * 3.0) * 1.0
	_c += Vector2(0, -2.0 + hov) * _u
	var ob := Color("3a3244")
	var ob_d := Color("0e0a14")
	var rune := Color(1, 0.55, 0.15, 0.75 + 0.25 * sin(t * 4.0))
	# schegge dietro
	for i in 3:
		var a := t * 1.8 + i * TAU / 3.0
		if sin(a) < 0.0:
			_shard_piece(cv, Vector2(cos(a) * 7.2, sin(a) * 2.6), a, ob, ob_d)
	# nucleo esagonale
	var hex: Array = []
	for i in 6:
		var aa := -PI / 2 + i * TAU / 6.0 + sin(t * 0.8) * 0.15
		hex.append(Vector2.from_angle(aa) * Vector2(4.4, 4.8))
	_g(cv, hex, Color("4a4256"), ob_d)
	# sfaccettature
	_f(cv, [hex[5], hex[0], Vector2(0, -0.6)], Color(1, 1, 1, 0.12))
	_f(cv, [hex[2], hex[3], Vector2(0, -0.6)], Color(0, 0, 0, 0.3))
	_l(cv, hex[0], hex[3], Color(1, 1, 1, 0.08), 0.4)
	# runa incisa che brucia
	_pl(cv, [Vector2(0, -3.2), Vector2(0, 2.8)], rune, 0.55)
	_pl(cv, [Vector2(-1.8, -1.6), Vector2(0, -0.2), Vector2(1.8, -1.6)], rune, 0.55)
	_pl(cv, [Vector2(-1.4, 1.2), Vector2(0, 2.2), Vector2(1.4, 1.2)], rune, 0.55)
	_glint(cv, Vector2(0, -0.2), 3.4, Color(1, 0.5, 0.15, 0.3))
	_dot(cv, Vector2(look.x * 0.5, -0.2 + look.y * 0.4), 0.7, Color("fff0c0"))
	# schegge davanti
	for i in 3:
		var a := t * 1.8 + i * TAU / 3.0
		if sin(a) >= 0.0:
			_shard_piece(cv, Vector2(cos(a) * 7.2, sin(a) * 2.6), a, ob, ob_d)

static func _shard_piece(cv: CanvasItem, p: Vector2, a: float, ob: Color, ob_d: Color) -> void:
	var d := Vector2.from_angle(a * 0.7)
	var o := d.orthogonal()
	_g(cv, [p + d * 2.6, p + o * 1.1, p - d * 1.6, p - o * 1.1], Color("5a5068"), ob_d, 0.7)
	_l(cv, p + d * 2.4, p - d * 1.4, Color(1, 1, 1, 0.18), 0.3)

# ---------------------------------------------------------------------
#  Golem di scoria (e Golem antico, più grande, con incudine e catene)
# ---------------------------------------------------------------------
static func _golem(cv: CanvasItem, t: float, ph: float, look: Vector2, moving: bool, big: bool) -> void:
	var stone := Color("6e6672") if not big else Color("5e5a66")
	var stone_d := Color("26222c") if not big else Color("1c1a22")
	var stp := sin(ph * 0.6) * 1.2 if moving else 0.0
	var pulse := 0.75 + 0.25 * sin(t * 3.0)
	# gambe tozze
	for sx in [-1.0, 1.0]:
		var fy: float = 9.6 + stp * sx
		_g(cv, [Vector2(sx * 1.4, 4), Vector2(sx * 5, 4), Vector2(sx * 5.6, fy), Vector2(sx * 0.8, fy)], stone.darkened(0.15), stone_d, 0.9)
		_l(cv, Vector2(sx * 1.6, fy - 2.2), Vector2(sx * 5.2, fy - 2.2), Color(0, 0, 0, 0.35), 0.4)
	# pugni enormi
	for sx in [-1.0, 1.0]:
		var fc := Vector2(sx * 8.2, 2.6) + look * 0.8
		_lo(cv, Vector2(sx * 6, -4), fc + Vector2(0, -2), stone.darkened(0.1), 2.4)
		_g(cv, [fc + Vector2(-2.6, -2.4), fc + Vector2(2.6, -2.4), fc + Vector2(3, 1.6), fc + Vector2(1.6, 3), fc + Vector2(-1.6, 3), fc + Vector2(-3, 1.6)], stone.lightened(0.08), stone_d)
		for k in 3:
			_l(cv, fc + Vector2(-1.6 + k * 1.6, 0.4), fc + Vector2(-1.6 + k * 1.6, 2.2), Color(0, 0, 0, 0.4), 0.4)
		# fascia di ferro al polso
		_g(cv, [fc + Vector2(-2.8, -3.4), fc + Vector2(2.8, -3.4), fc + Vector2(2.7, -2.2), fc + Vector2(-2.7, -2.2)], Color("5a5660"), Color("2a2830"), 0.7)
	# torso massiccio
	_g(cv, [Vector2(-6.6, -5.6), Vector2(-3, -8), Vector2(3, -8), Vector2(6.6, -5.6), Vector2(6.2, 3), Vector2(3.6, 5.4), Vector2(-3.6, 5.4), Vector2(-6.2, 3)], stone, stone_d)
	# spalle di roccia separate
	for sx in [-1.0, 1.0]:
		_g(cv, [Vector2(sx * 4, -8.4), Vector2(sx * 8, -7), Vector2(sx * 8.6, -3.4), Vector2(sx * 5.6, -2.6), Vector2(sx * 3.6, -5)], stone.lightened(0.12), stone.darkened(0.35))
		_f(cv, [Vector2(sx * 4.6, -8), Vector2(sx * 7.4, -6.8), Vector2(sx * 6, -6.2)], Color(1, 1, 1, 0.12))
		if big:
			for k in 2:
				var sp := Vector2(sx * (5.4 + k * 1.8), -8.2 + k * 0.6)
				_g(cv, [sp + Vector2(-0.8, 0.4), sp + Vector2(sx * 0.4, -2.6), sp + Vector2(0.8, 0.4)], Color("8a8494"), Color("3a3640"), 0.6)
	# griglia sul petto con il nucleo fuso dietro
	var gr := [Vector2(-2.6, -5), Vector2(2.6, -5), Vector2(2.6, -0.6), Vector2(-2.6, -0.6)]
	_f(cv, gr, OUT)
	_f(cv, [Vector2(-2, -4.4), Vector2(2, -4.4), Vector2(2, -1.2), Vector2(-2, -1.2)], Color(LAVA, pulse))
	_f(cv, [Vector2(-1, -3.6), Vector2(1, -3.6), Vector2(1, -2), Vector2(-1, -2)], LAVA_L)
	for k in 3:
		_l(cv, Vector2(-1.3 + k * 1.3, -4.8), Vector2(-1.3 + k * 1.3, -0.8), Color("3a3640"), 0.55)
	# fascia di ferro con rivetti
	_g(cv, [Vector2(-6.3, 1), Vector2(6.3, 1), Vector2(6.1, 2.6), Vector2(-6.1, 2.6)], Color("5e5a66"), Color("2a2830"), 0.8)
	for k in 5:
		_dot(cv, Vector2(-4.8 + k * 2.4, 1.8), 0.38, Color("b0a8b8"))
	# crepe sottili di lava
	_pl(cv, [Vector2(-5, -4), Vector2(-4, -2.4), Vector2(-4.8, -0.6)], Color(LAVA, pulse), 0.45)
	_pl(cv, [Vector2(4.6, 3.4), Vector2(3.6, 4.6)], Color(LAVA, pulse), 0.45)
	# testa incassata tra le spalle
	var h := Vector2(look.x * 0.8, -8.6)
	if big:
		# testa a incudine
		_g(cv, [h + Vector2(-4.6, -2.6), h + Vector2(4.6, -2.6), h + Vector2(3.4, -1.4), h + Vector2(2.4, 1.4), h + Vector2(-2.4, 1.4), h + Vector2(-3.4, -1.4)], Color("7a7684"), Color("2e2c34"))
		_l(cv, h + Vector2(-4.2, -2.2), h + Vector2(4.2, -2.2), Color(1, 1, 1, 0.25), 0.4)
	else:
		_g(cv, [h + Vector2(-2.4, -1.8), h + Vector2(2.4, -1.8), h + Vector2(2.6, 1.4), h + Vector2(-2.6, 1.4)], stone.lightened(0.05), stone_d, 0.9)
	# visiera incandescente
	_f(cv, [h + Vector2(-1.8, -0.5), h + Vector2(1.8, -0.5), h + Vector2(1.6, 0.4), h + Vector2(-1.6, 0.4)], OUT)
	_l(cv, h + Vector2(-1.4, 0), h + Vector2(1.4, 0), Color("ffd060"), 0.55)
	if big:
		# catene avvolte sul petto
		for k in 6:
			var cp := Vector2(-6 + k * 2.4, -6.4 + k * 1.3)
			cv.draw_arc(_P(cp), 0.8 * _u, 0, TAU, 8, OUT, maxf(1.4, 1.0 * _u), true)
			cv.draw_arc(_P(cp), 0.8 * _u, 0, TAU, 8, _C(Color("8a8494")), maxf(0.7, 0.5 * _u), true)

# ---------------------------------------------------------------------
#  Signore della Cenere: maschera d'oro, corona di fiamme, scettro fuso
# ---------------------------------------------------------------------
static func _lord(cv: CanvasItem, t: float, look: Vector2, phase: int) -> void:
	var fire := Color("ff7a2a") if phase == 1 else Color("ffd84a")
	var fire_l := Color("ffd080") if phase == 1 else Color("fff4c0")
	var hov := sin(t * 1.8) * 0.6
	_c += Vector2(0, hov) * _u
	var robe := Color("5a1626")
	var robe_d := Color("12040a")
	var gold := Color("e0a840")
	var gold_d := Color("6a4818")
	# mantello che ondeggia
	var w := sin(t * 2.2) * 0.6
	_g(cv, [Vector2(-5, -6), Vector2(5, -6), Vector2(9.4, 8 + w), Vector2(6.6, 6.6), Vector2(4.6, 9.4 - w), Vector2(2, 7.4), Vector2(0, 9.8 + w), Vector2(-2, 7.4), Vector2(-4.6, 9.4 - w), Vector2(-6.6, 6.6), Vector2(-9.4, 8 + w)], robe, robe_d)
	# veste interna con bordo dorato
	_g(cv, [Vector2(-3, -4), Vector2(3, -4), Vector2(4.2, 8), Vector2(0, 8.8), Vector2(-4.2, 8)], Color("2a0a12"), Color("0a0206"), 0.7)
	_pl(cv, [Vector2(-3, -4), Vector2(-4.2, 8), Vector2(0, 8.8), Vector2(4.2, 8), Vector2(3, -4)], gold, 0.5)
	# rune dorate sulla veste
	for k in 3:
		var rp := Vector2(0, -1 + k * 2.8)
		_pl(cv, [rp + Vector2(-0.8, 0), rp + Vector2(0, -0.9), rp + Vector2(0.8, 0), rp + Vector2(0, 0.9), rp + Vector2(-0.8, 0)], Color(gold, 0.8), 0.35)
	# spallacci d'oro e nero
	for sx in [-1.0, 1.0]:
		_g(cv, [Vector2(sx * 2.6, -6.6), Vector2(sx * 6.6, -6.4), Vector2(sx * 7.6, -3.6), Vector2(sx * 5, -2.8), Vector2(sx * 2.6, -4.2)], Color("2e2630"), Color("0e0a10"))
		_pl(cv, [Vector2(sx * 2.8, -6.4), Vector2(sx * 6.6, -6.2), Vector2(sx * 7.4, -3.8)], gold, 0.5)
		_g(cv, [Vector2(sx * 5.4, -6.6), Vector2(sx * 6.4, -9), Vector2(sx * 6.8, -6.4)], gold, gold_d, 0.6)
	# braccio sinistro: fiamma nella mano
	var hl := Vector2(-7.4, 0.6) + look * 1.2
	_lo(cv, Vector2(-5.6, -4), hl, robe, 1.8)
	_dot(cv, hl, 1.0, Color("c8b8a0"), true)
	var fl := sin(t * 12.0) * 0.4
	_glint(cv, hl + Vector2(0, -1.6), 3.4, Color(fire, 0.45))
	_f(cv, [hl + Vector2(-1.2, -0.6), hl + Vector2(-0.2, -3.6 - fl), hl + Vector2(0.4, -2), hl + Vector2(1.2, -3 + fl), hl + Vector2(1.2, -0.6)], fire)
	_f(cv, [hl + Vector2(-0.5, -0.8), hl + Vector2(0, -2.4), hl + Vector2(0.6, -0.8)], fire_l)
	# braccio destro: scettro con sfera fusa
	var hr := Vector2(7.2, 0.4) + look * 1.2
	_lo(cv, Vector2(5.6, -4), hr, robe, 1.8)
	_lo(cv, hr + Vector2(0.4, 7), hr + Vector2(-0.2, -7), Color("3a2a20"), 0.9)
	_pl(cv, [hr + Vector2(-1.6, -7.4), hr + Vector2(-0.2, -6.4), hr + Vector2(1.4, -7.4)], gold, 0.7)
	_glint(cv, hr + Vector2(-0.2, -8.6), 3.6, Color(fire, 0.4))
	_dot(cv, hr + Vector2(-0.2, -8.6), 1.5, fire, true)
	_dot(cv, hr + Vector2(-0.6, -9.0), 0.6, fire_l)
	_dot(cv, hr, 1.0, Color("c8b8a0"), true)
	# cappuccio dietro la maschera
	var h := Vector2(look.x * 0.5, -8.6)
	_g(cv, [h + Vector2(-3.4, 2.6), h + Vector2(-3.4, -0.8), h + Vector2(-1.6, -3.6), h + Vector2(0, -4.6), h + Vector2(1.6, -3.6), h + Vector2(3.4, -0.8), h + Vector2(3.4, 2.6), h + Vector2(0, 3.8)], Color("4a1420"), robe_d)
	# maschera d'oro con crepa incandescente
	_g(cv, [h + Vector2(-2.6, -1.9), h + Vector2(0, -2.7), h + Vector2(2.6, -1.9), h + Vector2(2.5, 1.0), h + Vector2(1.2, 2.6), h + Vector2(0, 3.3), h + Vector2(-1.2, 2.6), h + Vector2(-2.5, 1.0)], Color("f6cc70"), Color("8a5a20"), 0.8)
	_f(cv, [h + Vector2(-2.2, -1.6), h + Vector2(0, -2.3), h + Vector2(0, 2.8), h + Vector2(-1.0, 2.2), h + Vector2(-2.1, 0.8)], Color(1, 1, 1, 0.12))
	_pl(cv, [h + Vector2(0.4, -2.5), h + Vector2(-0.2, -1), h + Vector2(0.5, 0.4), h + Vector2(0, 2.6)], fire, 0.45)
	for sx in [-1.0, 1.0]:
		var ep := h + Vector2(sx * 1.15, -0.4)
		_f(cv, [ep + Vector2(-0.9, -0.2), ep + Vector2(0.9, -0.2), ep + Vector2(sx * 0.5, 0.5)], OUT)
		_l(cv, ep + Vector2(-0.6, 0), ep + Vector2(0.6, 0), fire_l, 0.35)
	_l(cv, h + Vector2(-0.8, 1.8), h + Vector2(0.8, 1.8), gold_d, 0.4)
	# corona: fascia d'oro e fiamme vive
	_g(cv, [h + Vector2(-3, -2.4), h + Vector2(3, -2.4), h + Vector2(2.8, -1.4), h + Vector2(-2.8, -1.4)], gold, gold_d, 0.7)
	for k in 5:
		var x := -2.4 + k * 1.2
		var hh := (2.6 if k % 2 == 0 else 1.6) + sin(t * 9.0 + k * 1.3) * 0.5 + (0.8 if k == 2 else 0.0)
		_f(cv, [h + Vector2(x - 0.6, -2.4), h + Vector2(x, -2.4 - hh), h + Vector2(x + 0.6, -2.4)], fire)
		_f(cv, [h + Vector2(x - 0.25, -2.4), h + Vector2(x, -2.4 - hh * 0.55), h + Vector2(x + 0.25, -2.4)], fire_l)
	# braci che salgono
	for k in 4:
		var ey := fmod(t * 4.0 + k * 2.3, 9.0)
		_dot(cv, Vector2(-6 + k * 4.0 + sin(t + k) * 0.8, 6 - ey * 1.6), 0.35, Color(fire, 1.0 - ey / 9.0))
