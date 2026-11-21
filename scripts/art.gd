class_name Art
## Disegni del gioco nello stile di Braceforte 2: forme tonde con contorno scuro,
## colori pieni, bagliori, pannelli e pulsanti arrotondati.

const DARK := Color("120c24")          # contorno di tutto
const PANEL := Color("231c42")
const PANEL_EDGE := Color("4a3f7a")
const TEXT_DIM := Color("a99cc9")
const GOLD := Color("ffc531")
const GEM := Color("5ab4ff")
const SPARK := Color("ff8a3d")
const HP := Color("ff3d5a")
const GREEN := Color("4fdc8a")

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

static func rbox(canvas: CanvasItem, r: Rect2, fill: Color, edge: Color = Color(0, 0, 0, 0), radius: int = 6, border: int = 2) -> void:
	if edge.a <= 0.0:
		border = 0
	canvas.draw_style_box(box(fill, edge, radius, border), r)

## Pannello scuro arrotondato (stile carte di Braceforte 2)
static func panel(canvas: CanvasItem, r: Rect2, fill: Color = PANEL, edge: Color = PANEL_EDGE) -> void:
	rbox(canvas, Rect2(r.position + Vector2(0, 2), r.size), Color(0, 0, 0, 0.3), Color(0, 0, 0, 0), 8)
	rbox(canvas, r, fill, edge, 8, 2)

## Pulsante con sfumatura e "spessore" sotto, come il COMBATTI! di Braceforte 2
static func button(canvas: CanvasItem, r: Rect2, text: String, color: Color, enabled: bool = true, scale: int = 1) -> void:
	var c := color if enabled else Color("4a4466")
	var rad := int(minf(10.0, r.size.y / 2.5))
	rbox(canvas, Rect2(r.position + Vector2(0, 3), r.size), c.darkened(0.45), Color(0, 0, 0, 0), rad)
	rbox(canvas, r, c, Color(0, 0, 0, 0), rad)
	rbox(canvas, Rect2(r.position + Vector2(2, 1), Vector2(r.size.x - 4, r.size.y * 0.48)), c.lightened(0.18), Color(0, 0, 0, 0), rad - 1)
	if text != "":
		var size := PixelFont.px(scale)
		var ty := r.position.y + (r.size.y - size) / 2.0 - 1
		PixelFont.draw_centered(canvas, text, r.get_center().x, ty, scale, Color.WHITE if enabled else TEXT_DIM, Color(0, 0, 0, 0.35))

## Pillola con icona e numero (barra in alto)
static func counter(canvas: CanvasItem, icon_name: String, value: int, pos: Vector2, color: Color) -> float:
	var t := str(value)
	var w := 22.0 + PixelFont.text_width(t, 1)
	rbox(canvas, Rect2(pos.x - 3, pos.y - 3, w, 15), Color(0, 0, 0, 0.38), Color(1, 1, 1, 0.1), 8, 1)
	icon(canvas, icon_name, pos + Vector2(0, -1), 1.6, color)
	PixelFont.draw_text(canvas, t, pos + Vector2(15, 0), 1, Color.WHITE)
	return w + 4

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

## Riquadro di un pezzo (colore della rarità, icona, livello)
static func item_box(canvas: CanvasItem, item: Dictionary, r: Rect2, selected: bool = false) -> void:
	var rc: Color = Gear.RARITY[item.rar].color
	rbox(canvas, Rect2(r.position + Vector2(0, 2), r.size), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 7)
	rbox(canvas, r, rc.darkened(0.55), Color.WHITE if selected else rc, 7, 2)
	rbox(canvas, Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, r.size.y * 0.45)), Color(rc, 0.25), Color(0, 0, 0, 0), 5)
	if item.rar >= 3:
		glow(canvas, r.get_center(), r.size.x * 0.6, Color(rc, 0.35))
	var k := r.size.x / 11.0
	icon(canvas, item_icon_name(item), r.get_center() - Vector2(3.5, 3.5) * k - Vector2(0, 1), k, Color.WHITE.lerp(rc, 0.3))
	var t := "L%d" % item.lv
	var tw := PixelFont.text_width(t, 1)
	PixelFont.draw_text(canvas, t, Vector2(r.end.x - tw - 3, r.end.y - 11), 1, Color.WHITE, DARK)
