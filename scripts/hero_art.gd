class_name HeroArt
## Il Fabbro delle Ceneri: proporzioni da guerriero (non tondo), elmo chiuso con
## fessura incandescente, corazza d'acciaio, grembiule di cuoio, mantello lacero.
## Disegnato in coordinate normali: p = punto dei piedi a terra.

const OUT := Color("0b0a0e")
const STEEL_A := Color("9a98a8")
const STEEL_B := Color("4a4858")
const LEATHER := Color("6a4426")
const CAPE_A := Color("7a1c26")
const CAPE_B := Color("3e0c14")

static func _poly(cv: CanvasItem, pts: Array, col: Color, w: float = 1.6) -> void:
	var p := PackedVector2Array(pts)
	cv.draw_colored_polygon(p, col)
	var q := p.duplicate()
	q.append(p[0])
	cv.draw_polyline(q, OUT, w, true)

static func _gpoly(cv: CanvasItem, pts: Array, top: Color, bottom: Color, w: float = 1.6) -> void:
	var p := PackedVector2Array(pts)
	Art.grad_poly(cv, p, top, bottom)
	var q := p.duplicate()
	q.append(p[0])
	cv.draw_polyline(q, OUT, w, true)

static func ellipse(cv: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	cv.draw_colored_polygon(pts, col)

## fx = direzione dello sguardo, ph = fase del passo, k = scala
static func draw(cv: CanvasItem, p: Vector2, fx: Vector2, t: float, ph: float, moving: bool, weapon: String, wc: Color, recoil: float = 0.0, k: float = 1.0, flash: float = 0.0) -> void:
	var back := fx.y < -0.55
	var bob := absf(sin(ph)) * 1.4 if moving else sin(t * 2.4) * 0.4
	var o := p + Vector2(0, -bob) * k
	var S := func(v: Vector2) -> Vector2: return o + v * k
	ellipse(cv, p + Vector2(0, 0.5) * k, 9.5 * k, 3.4 * k, Color(0, 0, 0, 0.42))
	# gambe e stivali
	var stp := sin(ph) * 2.6 if moving else 0.0
	for sx in [-1.0, 1.0]:
		var ly: float = -stp * sx
		_poly(cv, [S.call(Vector2(sx * 1.2, -8)), S.call(Vector2(sx * 4.4, -8)), S.call(Vector2(sx * 4.2, -2 + ly)), S.call(Vector2(sx * 1.4, -2 + ly))], Color("2a2230"), 1.2 * k)
		_poly(cv, [S.call(Vector2(sx * 0.8, -3 + ly)), S.call(Vector2(sx * 4.8, -3 + ly)), S.call(Vector2(sx * 5.2, 0 + ly)), S.call(Vector2(sx * 0.6, 0 + ly))], Color("3a2a1e"), 1.2 * k)
		cv.draw_line(S.call(Vector2(sx * 1.2, -2.6 + ly)), S.call(Vector2(sx * 4.6, -2.6 + ly)), Color("8a8898"), 1.0 * k)
	# mantello lacero
	var sway := sin(t * 4.0) * 1.2 - fx.x * 1.6
	var cape := [S.call(Vector2(-6.5, -20)), S.call(Vector2(6.5, -20)), S.call(Vector2(8 + sway, -3)), S.call(Vector2(5 + sway, -5)), S.call(Vector2(3 + sway, -1.5)), S.call(Vector2(0 + sway, -4)), S.call(Vector2(-3 + sway, -1)), S.call(Vector2(-5 + sway, -4.5)), S.call(Vector2(-8 + sway, -2.5))]
	if not back:
		_gpoly(cv, cape, CAPE_B, CAPE_A, 1.4 * k)
	# busto: corazza d'acciaio
	_gpoly(cv, [S.call(Vector2(-6.5, -20)), S.call(Vector2(6.5, -20)), S.call(Vector2(7, -13)), S.call(Vector2(4.5, -8)), S.call(Vector2(-4.5, -8)), S.call(Vector2(-7, -13))], STEEL_A, STEEL_B, 1.6 * k)
	if not back:
		cv.draw_line(S.call(Vector2(0, -19.5)), S.call(Vector2(0, -9)), Color(1, 1, 1, 0.25), 1.0 * k)
		# grembiule di cuoio, cintura, runa che pulsa
		_poly(cv, [S.call(Vector2(-4.5, -12)), S.call(Vector2(4.5, -12)), S.call(Vector2(4, -3.5)), S.call(Vector2(-4, -3.5))], LEATHER, 1.2 * k)
		for i in 3:
			cv.draw_line(S.call(Vector2(-3.5, -10.5 + i * 2.6)), S.call(Vector2(3.5, -10.5 + i * 2.6)), Color(0, 0, 0, 0.18), 0.8 * k)
		cv.draw_line(S.call(Vector2(-6.5, -12)), S.call(Vector2(6.5, -12)), Color("2a1a10"), 2.2 * k)
		cv.draw_rect(Rect2(S.call(Vector2(-1.4, -13.2)), Vector2(2.8, 2.4) * k), Art.GOLD)
		var rune := 0.6 + 0.4 * sin(t * 3.0)
		Art.glow(cv, S.call(Vector2(0, -7.5)), 4.5 * k, Color(1, 0.5, 0.15, 0.7 * rune))
		cv.draw_line(S.call(Vector2(-1, -9)), S.call(Vector2(1, -6)), Color(1, 0.7, 0.3, rune), 0.9 * k)
		cv.draw_line(S.call(Vector2(1, -9)), S.call(Vector2(-1, -6)), Color(1, 0.7, 0.3, rune), 0.9 * k)
	else:
		_gpoly(cv, cape, CAPE_A, CAPE_B, 1.4 * k)
		cv.draw_line(S.call(Vector2(-2, -18)), S.call(Vector2(-1 + sway, -4)), Color(0, 0, 0, 0.25), 1.0 * k)
		cv.draw_line(S.call(Vector2(2.5, -18)), S.call(Vector2(3 + sway, -5)), Color(0, 0, 0, 0.2), 1.0 * k)
	# spallacci a punta
	for sx in [-1.0, 1.0]:
		_gpoly(cv, [S.call(Vector2(sx * 3.5, -21)), S.call(Vector2(sx * 9.5, -20)), S.call(Vector2(sx * 10.5, -16.5)), S.call(Vector2(sx * 6, -15.5))], STEEL_A.lightened(0.1), STEEL_B, 1.4 * k)
		cv.draw_line(S.call(Vector2(sx * 6, -15.8)), S.call(Vector2(sx * 10.2, -16.8)), Color(1, 0.55, 0.2, 0.8), 0.9 * k)
	# elmo chiuso
	var h := Vector2(0, -25.5)
	_gpoly(cv, [S.call(h + Vector2(-4.6, 4.5)), S.call(h + Vector2(-4.8, -2)), S.call(h + Vector2(-2.5, -5.5)), S.call(h + Vector2(2.5, -5.5)), S.call(h + Vector2(4.8, -2)), S.call(h + Vector2(4.6, 4.5))], STEEL_A.lightened(0.15), STEEL_B, 1.6 * k)
	if not back:
		var vx := fx.x * 1.2
		# fessura a T che brilla
		var glow_c := Color(1, 0.55, 0.15)
		Art.glow(cv, S.call(h + Vector2(vx, -0.5)), 6 * k, Color(glow_c, 0.6))
		cv.draw_line(S.call(h + Vector2(-3.4 + vx, -0.8)), S.call(h + Vector2(3.4 + vx, -0.8)), OUT, 2.2 * k)
		cv.draw_line(S.call(h + Vector2(vx, -0.8)), S.call(h + Vector2(vx, 3)), OUT, 1.8 * k)
		cv.draw_line(S.call(h + Vector2(-3 + vx, -0.8)), S.call(h + Vector2(3 + vx, -0.8)), Color("ffb347"), 1.0 * k)
		cv.draw_line(S.call(h + Vector2(vx, -0.5)), S.call(h + Vector2(vx, 2.4)), Color("ff8a2a"), 0.8 * k)
	else:
		cv.draw_line(S.call(h + Vector2(0, -5)), S.call(h + Vector2(0, 4)), Color(0, 0, 0, 0.3), 1.0 * k)
	cv.draw_line(S.call(h + Vector2(-3.5, -3.5)), S.call(h + Vector2(-1.5, -5)), Color(1, 1, 1, 0.4), 1.0 * k)
	# cresta di fiamma
	var fl := sin(t * 11.0) * 1.2
	var crest := [S.call(h + Vector2(-1.2, -5.5)), S.call(h + Vector2(-2.5 - fx.x, -10 + fl)), S.call(h + Vector2(0, -8)), S.call(h + Vector2(1.5 - fx.x * 2.0, -12.5 - fl)), S.call(h + Vector2(2.2, -7.5)), S.call(h + Vector2(4 - fx.x, -9 + fl)), S.call(h + Vector2(2.4, -5.5))]
	Art.glow(cv, S.call(h + Vector2(0.5, -8)), 7 * k, Color(1, 0.45, 0.1, 0.5))
	_poly(cv, crest, Color("ff5a1a"), minf(1.2 * k, 1.8))
	cv.draw_line(S.call(h + Vector2(0.3, -6)), S.call(h + Vector2(1.2 - fx.x * 1.5, -10)), Color("ffd27a"), 1.0 * k)
	# arma nella mano destra
	var side := Vector2(-fx.y, fx.x)
	if side.x < 0.0:
		side = -side
	var hand := o + (Vector2(0, -12) + fx * (6.0 - recoil * 2.0) + side * 7.0) * k
	var a := fx.angle()
	match weapon:
		"sword":
			var tip := hand + fx * 15.0 * k
			cv.draw_line(hand - fx * 2.0 * k, tip, OUT, 4.2 * k, true)
			cv.draw_line(hand, tip, Color("d8dce8"), 2.2 * k, true)
			cv.draw_line(hand + fx * 2.0 * k, tip - fx * 1.0 * k, Color(1, 1, 1, 0.7), 0.8 * k, true)
			cv.draw_line(hand - side * 3.5 * k, hand + side * 3.5 * k, OUT, 3.2 * k, true)
			cv.draw_line(hand - side * 3.0 * k, hand + side * 3.0 * k, Art.GOLD, 1.8 * k, true)
			if wc != Data.WEAPONS.sword.color:
				Art.glow(cv, hand + fx * 9.0 * k, 9 * k, Color(wc, 0.5))
				cv.draw_line(hand + fx * 3.0 * k, tip, Color(wc, 0.85), 1.2 * k, true)
		"bow":
			cv.draw_arc(hand, 8 * k, a - 1.35, a + 1.35, 14, OUT, 3.8 * k, true)
			cv.draw_arc(hand, 8 * k, a - 1.35, a + 1.35, 14, Color("6a4426"), 2.2 * k, true)
			var pull := hand - fx * (2.0 + 2.5 * recoil) * k
			cv.draw_line(hand + Vector2.from_angle(a - 1.35) * 8 * k, pull, Color(1, 0.95, 0.85, 0.8), 0.9 * k, true)
			cv.draw_line(hand + Vector2.from_angle(a + 1.35) * 8 * k, pull, Color(1, 0.95, 0.85, 0.8), 0.9 * k, true)
			if wc != Data.WEAPONS.bow.color:
				Art.glow(cv, hand, 8 * k, Color(wc, 0.45))
		"staff":
			var top := hand + Vector2(fx.x * 3.0, -13.0) * k
			cv.draw_line(hand + Vector2(0, 7) * k, top, OUT, 3.8 * k, true)
			cv.draw_line(hand + Vector2(0, 7) * k, top, Color("4a3424"), 2.2 * k, true)
			Art.glow(cv, top, (10 + recoil * 5) * k, Color(wc, 0.75))
			_poly(cv, [top + Vector2(0, -4) * k, top + Vector2(2.6, 0) * k, top + Vector2(0, 3) * k, top + Vector2(-2.6, 0) * k], wc.lightened(0.2), 1.2 * k)
	if flash > 0.0:
		ellipse(cv, o + Vector2(0, -14) * k, 11 * k, 15 * k, Color(1, 0.2, 0.2, flash * 0.5))
