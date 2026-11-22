class_name PixelFont
## Tipografia del gioco (direzione "Forgia oscura"):
##  scala 1 = Inter (testi piccoli, leggibili)
##  scala 2-3 = Oswald Bold maiuscolo (titoli, pulsanti, numeri)
##  scala 4 = Cinzel Black (titoli epici)
## Il nome della classe è rimasto dalle prime versioni: le funzioni sono le stesse.

static var _fonts := {}

static func _load(key: String) -> Font:
	if not _fonts.has(key):
		var path: String = {
			"inter": "res://fonts/Inter-SemiBold.otf",
			"inter_b": "res://fonts/Inter-ExtraBold.otf",
			"oswald": "res://fonts/Oswald-Bold.ttf",
			"oswald_m": "res://fonts/Oswald-Medium.ttf",
			"cinzel": "res://fonts/Cinzel-Black.ttf",
			"cinzel_b": "res://fonts/Cinzel-Bold.ttf",
		}[key]
		_fonts[key] = load(path)
	return _fonts[key]

static func bold() -> Font:
	return _load("oswald")

static func semi() -> Font:
	return _load("inter")

static func cinzel() -> Font:
	return _load("cinzel")

static func px(scale: int) -> int:
	match scale:
		1: return 9
		2: return 15
		3: return 22
		_: return 28

static func _font(scale: int) -> Font:
	match scale:
		1: return _load("inter")
		2, 3: return _load("oswald")
		_: return _load("cinzel")

## Testi piccoli: da "STANZA LIBERA" a "Stanza libera". Titoli: tutto maiuscolo.
static func fmt(text: String, scale: int) -> String:
	if scale >= 2:
		return text.to_upper()
	return nice(text)

static func nice(text: String) -> String:
	var letters := 0
	for ch in text:
		if ch >= "A" and ch <= "Z":
			letters += 1
	if letters < 4 or text != text.to_upper():
		return text
	var low := text.to_lower()
	var out := ""
	var cap := true
	for i in low.length():
		var ch := low[i]
		if cap and ch.to_upper() != ch:
			out += ch.to_upper()
			cap = false
		else:
			out += ch
			if ch >= "0" and ch <= "9":
				cap = false
		if ch == "." or ch == "!" or ch == "?" or ch == ":":
			cap = true
	return out

static func text_width(text: String, scale: int) -> int:
	return int(_font(scale).get_string_size(fmt(text, scale), HORIZONTAL_ALIGNMENT_LEFT, -1, px(scale)).x)

static func _baseline(f: Font, size: int, scale: int) -> float:
	if scale == 1:
		return f.get_ascent(size) - 1
	# Oswald e Cinzel: allineati sull'altezza delle maiuscole
	return size * (0.86 if scale < 4 else 0.82)

## Testo con l'angolo in alto a sinistra in "pos"
static func draw_text(canvas: CanvasItem, text: String, pos: Vector2, scale: int, color: Color, shadow: Color = Color(0, 0, 0, 0)) -> void:
	var f := _font(scale)
	var size := px(scale)
	var t := fmt(text, scale)
	var base := pos + Vector2(0, _baseline(f, size, scale))
	if shadow.a > 0.0:
		canvas.draw_string_outline(f, base, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(2, size / 5), shadow)
	canvas.draw_string(f, base, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

static func draw_centered(canvas: CanvasItem, text: String, center_x: float, y: float, scale: int, color: Color, shadow: Color = Color(0, 0, 0, 0)) -> void:
	var w := text_width(text, scale)
	draw_text(canvas, text, Vector2(center_x - w / 2.0, y), scale, color, shadow)

## Testo libero con un font e una dimensione a scelta (centrato su cx)
static func draw_custom(canvas: CanvasItem, key: String, text: String, cx: float, y: float, size: int, color: Color, outline: Color = Color(0, 0, 0, 0), outline_w: int = 0) -> void:
	var f := _load(key)
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var base := Vector2(cx - w / 2.0, y + size * 0.84)
	if outline.a > 0.0:
		canvas.draw_string_outline(f, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline_w if outline_w > 0 else maxi(2, size / 5), outline)
	canvas.draw_string(f, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

static func custom_width(key: String, text: String, size: int) -> float:
	return _load(key).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
