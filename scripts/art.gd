class_name Art
## Kit grafico "Forgia oscura": ferro scuro, metallo fuso, oro.
## Pannelli e pulsanti con angoli tagliati, bordi metallici, rivetti dorati.

const DARK := Color("0b0a0e")          # contorno di tutto
const INK := Color("0b0a0e")
const IRON_D := Color("141218")
const IRON := Color("1f1c25")
const IRON_L := Color("2e2a36")
const STEEL := Color("57525f")
const STEEL_L := Color("8e8898")
const PANEL := Color("1c1a22")
const PANEL_EDGE := Color("4a4552")
const TEXT := Color("efe6d6")
const TEXT_DIM := Color("a39a8e")
const GOLD := Color("e8b04a")
const GOLD_L := Color("ffe0a0")
const BRONZE := Color("9a6a34")
const MOLTEN := Color("ff6a1a")
const MOLTEN_L := Color("ffb347")
const GEM := Color("4fb8e8")
const SPARK := Color("ff7a2a")
const HP := Color("d8343e")
const GREEN := Color("5fd08a")

static var _boxes := {}
static var _glow: Texture2D

# ---------------------------------------------------------------------
#  Base
# ---------------------------------------------------------------------
static func glow_tex() -> Texture2D:
	if _glow == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.45))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_glow = t
	return _glow

## Bagliore morbido (luce attorno a fuochi, colpi, torce)
static func glow(canvas: CanvasItem, pos: Vector2, radius: float, color: Color) -> void:
	canvas.draw_texture_rect(glow_tex(), Rect2(pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, color)

static func box(fill: Color, edge: Color, radius: int, border: int = 2) -> StyleBoxFlat:
	var key := "%s|%s|%d|%d" % [fill.to_html(), edge.to_html(), radius, border]
	if _boxes.has(key):
		return _boxes[key]
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = edge
	b.set_border_width_all(border)
	b.set_corner_radius_all(radius)
	b.anti_aliasing = true
	b.corner_detail = 6
	_boxes[key] = b
	return b

## Riquadro con angoli leggermente arrotondati (usato per barre e dettagli)
static func rbox(canvas: CanvasItem, r: Rect2, fill: Color, edge: Color = Color(0, 0, 0, 0), radius: int = 6, border: int = 2) -> void:
	if edge.a <= 0.0:
		border = 0
	canvas.draw_style_box(box(fill, edge, mini(radius, 3), border), r)

## Punti di un rettangolo con gli angoli tagliati
static func cut_pts(r: Rect2, c: float) -> PackedVector2Array:
	c = minf(c, minf(r.size.x, r.size.y) * 0.45)
	return PackedVector2Array([
		r.position + Vector2(c, 0), Vector2(r.end.x - c, r.position.y), Vector2(r.end.x, r.position.y + c),
		Vector2(r.end.x, r.end.y - c), Vector2(r.end.x - c, r.end.y), Vector2(r.position.x + c, r.end.y),
		Vector2(r.position.x, r.end.y - c), Vector2(r.position.x, r.position.y + c),
	])

## Poligono con sfumatura verticale
static func grad_poly(canvas: CanvasItem, pts: PackedVector2Array, top: Color, bottom: Color) -> void:
	var y0 := 1e9
	var y1 := -1e9
	for p in pts:
		y0 = minf(y0, p.y)
		y1 = maxf(y1, p.y)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bottom, (p.y - y0) / maxf(1.0, y1 - y0)))
	canvas.draw_polygon(pts, cols)

static func outline(canvas: CanvasItem, pts: PackedVector2Array, col: Color, w: float) -> void:
	var q := pts.duplicate()
	q.append(pts[0])
	canvas.draw_polyline(q, col, w, true)

## Lastra di ferro con angoli tagliati, bordo d'acciaio e luce in alto
static func plate(canvas: CanvasItem, r: Rect2, top: Color = IRON_L, bottom: Color = IRON_D, edge: Color = STEEL, cut: float = 6.0, rivets: bool = false) -> void:
	var sh := cut_pts(Rect2(r.position + Vector2(0, 3), r.size), cut)
	canvas.draw_colored_polygon(sh, Color(0, 0, 0, 0.45))
	var pts := cut_pts(r, cut)
	grad_poly(canvas, pts, top, bottom)
	outline(canvas, pts, INK, 3.0)
	outline(canvas, cut_pts(r.grow(-1.5), maxf(1.0, cut - 1.0)), edge, 1.0)
	canvas.draw_line(Vector2(r.position.x + cut, r.position.y + 2.5), Vector2(r.end.x - cut, r.position.y + 2.5), Color(1, 1, 1, 0.12), 1.0)
	if rivets:
		for p in [r.position + Vector2(5, 5), Vector2(r.end.x - 5, r.position.y + 5), Vector2(r.position.x + 5, r.end.y - 5), r.end - Vector2(5, 5)]:
			canvas.draw_circle(p, 1.8, INK)
			canvas.draw_circle(p, 1.2, BRONZE)
			canvas.draw_circle(p - Vector2(0.4, 0.4), 0.5, GOLD_L)

## Pannello scuro (compatibile con le chiamate vecchie)
static func panel(canvas: CanvasItem, r: Rect2, fill: Color = PANEL, edge: Color = PANEL_EDGE) -> void:
	plate(canvas, r, fill.lightened(0.06), fill.darkened(0.25), edge, 6.0)

## Pulsante in metallo: arancio fuso per le azioni principali, altri colori per il resto
static func button(canvas: CanvasItem, r: Rect2, text: String, color: Color, enabled: bool = true, scale: int = 1) -> void:
	var c := color if enabled else Color("2c2a31")
	var cut := minf(7.0, r.size.y * 0.3)
	var sh := cut_pts(Rect2(r.position + Vector2(0, 3), r.size), cut)
	canvas.draw_colored_polygon(sh, c.darkened(0.65) if enabled else Color(0, 0, 0, 0.4))
	var pts := cut_pts(r, cut)
	grad_poly(canvas, pts, c.lightened(0.22), c.darkened(0.28))
	outline(canvas, pts, INK, 2.5)
	if enabled:
		outline(canvas, cut_pts(r.grow(-1.5), cut - 1.0), Color(c.lightened(0.5), 0.55), 1.0)
		canvas.draw_line(Vector2(r.position.x + cut, r.position.y + 2.5), Vector2(r.end.x - cut, r.position.y + 2.5), Color(1, 1, 1, 0.35), 1.0)
	if text != "":
		var sc := scale if scale > 1 else (2 if r.size.y >= 22 else 1)
		var size := PixelFont.px(sc)
		var ty := r.position.y + (r.size.y - size) / 2.0 - (0.0 if sc == 1 else 1.0)
		if sc >= 2 and PixelFont.text_width(text, sc) > r.size.x - 8:
			sc = 1
			size = PixelFont.px(1)
			ty = r.position.y + (r.size.y - size) / 2.0
		PixelFont.draw_centered(canvas, text, r.get_center().x, ty, sc, TEXT if enabled else Color("6e6874"), Color(0, 0, 0, 0.55) if enabled else Color(0, 0, 0, 0))

## Pillola con icona e numero (barra in alto)
static func counter(canvas: CanvasItem, icon_name: String, value: int, pos: Vector2, color: Color) -> float:
	var t := str(value)
	var w := 24.0 + PixelFont.text_width(t, 1)
	var r := Rect2(pos.x - 3, pos.y - 3, w, 15)
	var pts := cut_pts(r, 4.0)
	canvas.draw_colored_polygon(pts, Color(0, 0, 0, 0.55))
	outline(canvas, pts, Color(1, 1, 1, 0.12), 1.0)
	icon(canvas, icon_name, pos + Vector2(0, -1), 1.6, color)
	PixelFont.draw_text(canvas, t, pos + Vector2(15, 0), 1, TEXT)
	return w + 4

## Intestazione decorata: testo con linee e rombi ai lati
static func header(canvas: CanvasItem, text: String, cx: float, y: float, w: float, color: Color = GOLD) -> void:
	var tw := PixelFont.text_width(text, 2)
	PixelFont.draw_centered(canvas, text, cx, y, 2, color, Color(0, 0, 0, 0.6))
	var ly := y + 8
	for side in [-1.0, 1.0]:
		var a: float = cx + side * (tw / 2.0 + 8)
		var b: float = cx + side * (w / 2.0)
		canvas.draw_line(Vector2(a, ly), Vector2(b, ly), Color(color, 0.55), 1.0)
		var d := Vector2(a + side * 1.0, ly)
		canvas.draw_colored_polygon(PackedVector2Array([d + Vector2(0, -3), d + Vector2(3 * side, 0), d + Vector2(0, 3), d + Vector2(-3 * side, 0)]), color)

## Barra di avanzamento metallica
static func bar(canvas: CanvasItem, r: Rect2, k: float, col: Color) -> void:
	canvas.draw_rect(r.grow(1.5), INK)
	canvas.draw_rect(r, Color("0e0c12"))
	if k > 0.0:
		var f := Rect2(r.position, Vector2(r.size.x * clampf(k, 0.0, 1.0), r.size.y))
		grad_poly(canvas, PackedVector2Array([f.position, Vector2(f.end.x, f.position.y), f.end, Vector2(f.position.x, f.end.y)]), col.lightened(0.3), col.darkened(0.25))
		canvas.draw_line(f.position + Vector2(0, 1), Vector2(f.end.x, f.position.y + 1), Color(1, 1, 1, 0.3), 1.0)

# ---------------------------------------------------------------------
#  Icone disegnate (scala 1 = circa 7 pixel)
# ---------------------------------------------------------------------
static func _poly(canvas: CanvasItem, pts: Array, o: Vector2, k: float, col: Color, outline: bool = true) -> void:
	var p := PackedVector2Array()
	for v in pts:
		p.append(o + v * k)
	if outline:
		var q := p.duplicate()
		q.append(p[0])
		canvas.draw_polyline(q, DARK, maxf(1.2, k * 0.9), true)
	canvas.draw_colored_polygon(p, col)

static func icon(canvas: CanvasItem, name: String, pos: Vector2, scale: float, color: Color) -> void:
	var k := scale            # 1 unità = 1 "pixel" della vecchia icona 7x7
	var o := pos
	var c := pos + Vector2(3.5, 3.5) * k
	var lw := maxf(1.0, k * 0.8)
	match name:
		"fire":
			_poly(canvas, [Vector2(3.5, 0), Vector2(5.2, 2.4), Vector2(6.4, 4.4), Vector2(5.6, 6.4), Vector2(3.5, 7), Vector2(1.4, 6.4), Vector2(0.6, 4.4), Vector2(1.8, 2.8), Vector2(2.6, 3.8)], o, k, color)
			_poly(canvas, [Vector2(3.5, 3.4), Vector2(4.6, 5.0), Vector2(3.5, 6.4), Vector2(2.4, 5.0)], o, k, Color("ffe14a"), false)
		"ice":
			for i in 3:
				var a := PI / 3.0 * i
				var d := Vector2.from_angle(a) * 3.3 * k
				canvas.draw_line(c - d, c + d, DARK, lw + 1.6, true)
			for i in 3:
				var a := PI / 3.0 * i
				var d := Vector2.from_angle(a) * 3.3 * k
				canvas.draw_line(c - d, c + d, color, lw, true)
			canvas.draw_circle(c, 1.0 * k, Color.WHITE)
		"thunder":
			_poly(canvas, [Vector2(4.4, 0), Vector2(1.2, 4.0), Vector2(3.2, 4.0), Vector2(2.2, 7), Vector2(5.8, 2.8), Vector2(3.8, 2.8)], o, k, color)
		"poison":
			_poly(canvas, [Vector2(3.5, 0), Vector2(5.6, 3.4), Vector2(6, 4.8), Vector2(5, 6.5), Vector2(3.5, 7), Vector2(2, 6.5), Vector2(1, 4.8), Vector2(1.4, 3.4)], o, k, color)
			canvas.draw_circle(o + Vector2(2.6, 4.6) * k, 0.8 * k, Color(1, 1, 1, 0.7))
		"spark":
			_poly(canvas, [Vector2(3.5, 0), Vector2(4.4, 2.6), Vector2(7, 3.5), Vector2(4.4, 4.4), Vector2(3.5, 7), Vector2(2.6, 4.4), Vector2(0, 3.5), Vector2(2.6, 2.6)], o, k, color)
		"gold":
			canvas.draw_circle(c, 3.5 * k, DARK)
			canvas.draw_circle(c, 2.9 * k, Color("c27a00"))
			canvas.draw_circle(c - Vector2(0.3, 0.3) * k, 2.3 * k, color)
			canvas.draw_circle(c - Vector2(1, 1) * k, 0.9 * k, Color("fff6b0"))
		"gem":
			_poly(canvas, [Vector2(3.5, 0.2), Vector2(7, 2.6), Vector2(3.5, 7), Vector2(0, 2.6)], o, k, color)
			_poly(canvas, [Vector2(3.5, 0.6), Vector2(5.6, 2.6), Vector2(3.5, 3.4), Vector2(1.4, 2.6)], o, k, Color("a6f4ff"), false)
		"heart":
			canvas.draw_circle(o + Vector2(2.1, 2.3) * k, 2.0 * k, color)
			canvas.draw_circle(o + Vector2(4.9, 2.3) * k, 2.0 * k, color)
			_poly(canvas, [Vector2(0.2, 2.8), Vector2(6.8, 2.8), Vector2(3.5, 6.8)], o, k, color, false)
		"skull":
			canvas.draw_circle(c - Vector2(0, 0.6) * k, 3.3 * k, DARK)
			canvas.draw_circle(c - Vector2(0, 0.6) * k, 2.8 * k, color)
			canvas.draw_rect(Rect2(o + Vector2(2, 4.6) * k, Vector2(3, 2) * k), color)
			canvas.draw_circle(o + Vector2(2.4, 3) * k, 0.8 * k, DARK)
			canvas.draw_circle(o + Vector2(4.6, 3) * k, 0.8 * k, DARK)
		"rock":
			_poly(canvas, [Vector2(1, 2.4), Vector2(3, 0.8), Vector2(5.6, 1.4), Vector2(6.8, 4), Vector2(5.4, 6.4), Vector2(2, 6.6), Vector2(0.2, 4.6)], o, k, color)
			canvas.draw_line(o + Vector2(3, 2.4) * k, o + Vector2(4, 4) * k, color.darkened(0.4), lw * 0.7, true)
		"question":
			canvas.draw_circle(c, 3.5 * k, DARK)
			canvas.draw_circle(c, 2.9 * k, color.darkened(0.5))
			PixelFont.draw_centered(canvas, "?", c.x, c.y - 4.5 * k / 1.0, 1, color)
		"sword":
			canvas.draw_line(o + Vector2(6.5, 0.5) * k, o + Vector2(1.8, 5.2) * k, DARK, lw + 2.0, true)
			canvas.draw_line(o + Vector2(6.5, 0.5) * k, o + Vector2(1.8, 5.2) * k, color, lw + 0.6, true)
			canvas.draw_line(o + Vector2(0.8, 3.6) * k, o + Vector2(3.4, 6.2) * k, Color("8a6a40"), lw + 0.6, true)
			canvas.draw_line(o + Vector2(1.8, 5.2) * k, o + Vector2(0.4, 6.6) * k, Color("6b3d22"), lw + 0.6, true)
		"bow":
			var bc := o + Vector2(1.6, 3.5) * k
			canvas.draw_arc(bc, 3.3 * k, -1.25, 1.25, 12, DARK, lw + 2.0, true)
			canvas.draw_arc(bc, 3.3 * k, -1.25, 1.25, 12, color, lw + 0.6, true)
			var e1 := bc + Vector2.from_angle(-1.25) * 3.3 * k
			var e2 := bc + Vector2.from_angle(1.25) * 3.3 * k
			canvas.draw_line(e1, e2, Color(1, 1, 1, 0.85), maxf(1.0, k * 0.35), true)
		"staff":
			canvas.draw_line(o + Vector2(5.4, 1.6) * k, o + Vector2(0.8, 6.6) * k, DARK, lw + 2.0, true)
			canvas.draw_line(o + Vector2(5.4, 1.6) * k, o + Vector2(0.8, 6.6) * k, Color("8a6a40"), lw + 0.6, true)
			canvas.draw_circle(o + Vector2(5.4, 1.6) * k, 1.9 * k, DARK)
			canvas.draw_circle(o + Vector2(5.4, 1.6) * k, 1.4 * k, color)
		"helmet":
			_poly(canvas, [Vector2(0.6, 6.4), Vector2(0.6, 3.4), Vector2(1.8, 1.2), Vector2(3.5, 0.4), Vector2(5.2, 1.2), Vector2(6.4, 3.4), Vector2(6.4, 6.4)], o, k, color)
			canvas.draw_rect(Rect2(o + Vector2(1.6, 3.4) * k, Vector2(3.8, 1.0) * k), DARK)
		"armor":
			_poly(canvas, [Vector2(0.4, 1), Vector2(2.4, 0.4), Vector2(3.5, 1.4), Vector2(4.6, 0.4), Vector2(6.6, 1), Vector2(5.8, 3.6), Vector2(5.6, 6.6), Vector2(1.4, 6.6), Vector2(1.2, 3.6)], o, k, color)
			canvas.draw_line(o + Vector2(3.5, 1.6) * k, o + Vector2(3.5, 6.2) * k, color.darkened(0.35), lw * 0.7, true)
		"gloves":
			_poly(canvas, [Vector2(1.4, 6.8), Vector2(1, 3.4), Vector2(1.6, 1), Vector2(2.6, 1), Vector2(3, 0.2), Vector2(4.2, 0.4), Vector2(4.6, 1), Vector2(5.6, 1.4), Vector2(6, 3.6), Vector2(5.4, 6.8)], o, k, color)
		"boots":
			_poly(canvas, [Vector2(1.6, 0.4), Vector2(4.4, 0.4), Vector2(4.4, 4.2), Vector2(6.8, 5.2), Vector2(6.8, 6.8), Vector2(1.6, 6.8)], o, k, color)
		"ring":
			canvas.draw_arc(o + Vector2(3.5, 4.4) * k, 2.4 * k, 0, TAU, 16, DARK, lw + 2.0, true)
			canvas.draw_arc(o + Vector2(3.5, 4.4) * k, 2.4 * k, 0, TAU, 16, color, lw + 0.4, true)
			_poly(canvas, [Vector2(3.5, 0), Vector2(5, 1.4), Vector2(3.5, 2.6), Vector2(2, 1.4)], o, k, Color("a6f4ff"))
		"lock":
			canvas.draw_arc(o + Vector2(3.5, 3) * k, 2.0 * k, PI, TAU, 10, color, lw + 0.6, true)
			_poly(canvas, [Vector2(0.8, 3), Vector2(6.2, 3), Vector2(6.2, 6.8), Vector2(0.8, 6.8)], o, k, color)
		"chest":
			_poly(canvas, [Vector2(0.2, 3), Vector2(6.8, 3), Vector2(6.8, 6.8), Vector2(0.2, 6.8)], o, k, color)
			_poly(canvas, [Vector2(0.2, 3), Vector2(1, 1), Vector2(6, 1), Vector2(6.8, 3)], o, k, color.lightened(0.2))
			canvas.draw_rect(Rect2(o + Vector2(2.9, 2.6) * k, Vector2(1.2, 1.8) * k), GOLD)
		"book":
			_poly(canvas, [Vector2(0.4, 0.6), Vector2(6.4, 0.6), Vector2(6.4, 6.6), Vector2(0.4, 6.6)], o, k, color)
		"play":
			_poly(canvas, [Vector2(1, 0.4), Vector2(6.6, 3.5), Vector2(1, 6.6)], o, k, color)
		"bag":
			# icona "eroe" (testa e spalle)
			canvas.draw_circle(o + Vector2(3.5, 2.2) * k, 1.9 * k, color)
			canvas.draw_arc(o + Vector2(3.5, 7.2) * k, 3.2 * k, PI + 0.3, TAU - 0.3, 12, color, lw + 0.8, true)
		"shop":
			canvas.draw_arc(o + Vector2(3.5, 2.4) * k, 1.8 * k, PI, TAU, 10, color, lw * 0.8, true)
			_poly(canvas, [Vector2(0.6, 2.4), Vector2(6.4, 2.4), Vector2(5.8, 6.8), Vector2(1.2, 6.8)], o, k, color)
		"anvil":
			_poly(canvas, [Vector2(0, 1.6), Vector2(6.4, 1.6), Vector2(6.4, 3), Vector2(4.6, 3.6), Vector2(5.4, 6.4), Vector2(1.6, 6.4), Vector2(2.4, 3.6), Vector2(0.8, 2.8)], o, k, color)
		_:
			canvas.draw_circle(c, 3.0 * k, color)

static func el_icon(canvas: CanvasItem, el: String, pos: Vector2, scale: float) -> void:
	icon(canvas, el, pos, scale, Data.EL_COLOR[el])

## Distintivo rotondo con l'elemento (debolezza sopra i nemici)
static func el_badge(canvas: CanvasItem, el: String, center: Vector2, r: float) -> void:
	var col: Color = Data.EL_COLOR[el] if el != "?" else Color.WHITE
	canvas.draw_circle(center, r + 1.2, DARK)
	canvas.draw_circle(center, r, col.darkened(0.6))
	canvas.draw_arc(center, r, 0, TAU, 16, col, 1.0, true)
	var k := r * 1.5 / 7.0
	if el == "?":
		PixelFont.draw_centered(canvas, "?", center.x, center.y - 5, 1, Color.WHITE)
	else:
		icon(canvas, el, center - Vector2(3.5, 3.5) * k, k, col)

## Icona di un pezzo di equipaggiamento
static func item_icon_name(item: Dictionary) -> String:
	var t: String = Gear.BASES[item.base].type
	if t == "weapon":
		return Gear.BASES[item.base].weapon
	return t

## Riquadro di un pezzo: cornice tagliata del colore della rarità
static func item_box(canvas: CanvasItem, item: Dictionary, r: Rect2, selected: bool = false) -> void:
	var rc: Color = Gear.RARITY[item.rar].color
	var cut := r.size.x * 0.16
	canvas.draw_colored_polygon(cut_pts(Rect2(r.position + Vector2(0, 2), r.size), cut), Color(0, 0, 0, 0.5))
	var pts := cut_pts(r, cut)
	grad_poly(canvas, pts, rc.darkened(0.35), rc.darkened(0.78))
	if item.rar >= 3:
		glow(canvas, r.get_center(), r.size.x * 0.55, Color(rc, 0.4))
	outline(canvas, pts, INK, 2.5)
	outline(canvas, cut_pts(r.grow(-1.5), cut - 1.0), Color.WHITE if selected else rc.lightened(0.15), 1.2)
	canvas.draw_colored_polygon(PackedVector2Array([r.position + Vector2(cut, 2), Vector2(r.end.x - cut, r.position.y + 2), Vector2(r.end.x - 2, r.position.y + cut), Vector2(r.position.x + 2, r.position.y + r.size.y * 0.45)]), Color(1, 1, 1, 0.07))
	var k := r.size.x / 11.0
	icon(canvas, item_icon_name(item), r.get_center() - Vector2(3.5, 3.5) * k - Vector2(0, 1), k, Color("e8e2d8").lerp(rc, 0.25))
	var t := "%d" % item.lv
	var tw := PixelFont.text_width(t, 1)
	canvas.draw_colored_polygon(cut_pts(Rect2(r.end.x - tw - 7, r.end.y - 11, tw + 5, 10), 2.0), Color(0, 0, 0, 0.7))
	PixelFont.draw_text(canvas, t, Vector2(r.end.x - tw - 4.5, r.end.y - 11), 1, TEXT)
