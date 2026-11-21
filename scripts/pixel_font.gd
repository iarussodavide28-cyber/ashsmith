class_name PixelFont
## Testo del gioco (font Inter, come Braceforte 2).
## Il nome è rimasto da quando il gioco era in pixel art: le funzioni sono le stesse.

static var _bold: Font
static var _semi: Font

static func bold() -> Font:
	if _bold == null:
		_bold = load("res://fonts/Inter-ExtraBold.otf")
	return _bold

static func semi() -> Font:
	if _semi == null:
		_semi = load("res://fonts/Inter-SemiBold.otf")
	return _semi

## "scale" come prima: 1 = testo piccolo, 2 = medio, 3 = grande, 4 = titolo
static func px(scale: int) -> int:
	match scale:
		1: return 9
		2: return 14
		3: return 22
		_: return 30

static func _font(scale: int) -> Font:
	return semi() if scale == 1 else bold()

## Da "STANZA LIBERA" a "Stanza libera" (più leggibile, come Braceforte 2)
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
	return int(_font(scale).get_string_size(nice(text), HORIZONTAL_ALIGNMENT_LEFT, -1, px(scale)).x)

## Testo con l'angolo in alto a sinistra in "pos"
static func draw_text(canvas: CanvasItem, text: String, pos: Vector2, scale: int, color: Color, shadow: Color = Color(0, 0, 0, 0)) -> void:
	var f := _font(scale)
	var size := px(scale)
	var t := nice(text)
	var base := pos + Vector2(0, f.get_ascent(size) - 1)
	if shadow.a > 0.0:
		canvas.draw_string_outline(f, base, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(2, size / 5), shadow)
	canvas.draw_string(f, base, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

static func draw_centered(canvas: CanvasItem, text: String, center_x: float, y: float, scale: int, color: Color, shadow: Color = Color(0, 0, 0, 0)) -> void:
	var w := text_width(text, scale)
	draw_text(canvas, text, Vector2(center_x - w / 2.0, y), scale, color, shadow)
