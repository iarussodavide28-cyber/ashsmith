class_name Art
## Disegni pixel fatti a mano (icone, pulsanti) usati da tutte le schermate.

const DARK := Color("120a0c")
const PANEL := Color("231719")
const PANEL_EDGE := Color("5a4040")
const TEXT_DIM := Color("9a8580")
const GOLD := Color("ffd25a")
const GEM := Color("6fe3ff")
const SPARK := Color("ff8a2b")
const HP := Color("ff4a5a")

const ICONS := {
	"fire": ["0001000","0011000","0011100","0111110","1111110","1110111","0111110"],
	"ice": ["0001000","1001001","0101010","0011100","0101010","1001001","0001000"],
	"thunder": ["0000110","0001100","0011000","0111110","0001100","0011000","0110000"],
	"poison": ["0001000","0011100","0011100","0111110","0111110","0111110","0011100"],
	"spark": ["0001000","0001000","0011100","1111111","0011100","0001000","0001000"],
	"gold": ["0011100","0111110","1110111","1110111","1110111","0111110","0011100"],
	"gem": ["0111110","1101011","1111111","0111110","0011100","0001000","0000000"],
	"heart": ["0110110","1111111","1111111","1111111","0111110","0011100","0001000"],
	"skull": ["0111110","1111111","1001001","1111111","0110110","0111110","0000000"],
	"question": ["0111110","1100011","0000110","0001100","0001100","0000000","0001100"],
	"sword": ["0000011","0000111","0001110","1011100","0111000","0110000","1001000"],
	"bow": ["0111000","1000100","1000010","1111111","1000010","1000100","0111000"],
	"staff": ["0001110","0001110","0001110","0010000","0100000","1000000","0000000"],
}

static func icon(canvas: CanvasItem, name: String, pos: Vector2, scale: int, color: Color) -> void:
	var g: Array = ICONS.get(name, ICONS["question"])
	for row in g.size():
		var line: String = g[row]
		for col in line.length():
			if line[col] == "1":
				canvas.draw_rect(Rect2(pos.x + col * scale, pos.y + row * scale, scale, scale), color)

static func el_icon(canvas: CanvasItem, el: String, pos: Vector2, scale: int) -> void:
	icon(canvas, el, pos, scale, Data.EL_COLOR[el])

## Riquadro con bordo pixel
static func panel(canvas: CanvasItem, r: Rect2, fill: Color = PANEL, edge: Color = PANEL_EDGE) -> void:
	canvas.draw_rect(r.grow(1), DARK)
	canvas.draw_rect(r, edge)
	canvas.draw_rect(r.grow(-1), fill)

## Pulsante: rettangolo colorato con scritta centrata
static func button(canvas: CanvasItem, r: Rect2, text: String, color: Color, enabled: bool = true, scale: int = 1) -> void:
	var c := color if enabled else Color("4a4044")
	canvas.draw_rect(r.grow(1), DARK)
	canvas.draw_rect(r, c.darkened(0.35))
	canvas.draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y - 2)), c)
	canvas.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), c.lightened(0.3))
	var ty := r.position.y + floorf((r.size.y - 2 - 7 * scale) / 2.0)
	PixelFont.draw_centered(canvas, text, r.get_center().x, ty, scale, Color.WHITE if enabled else TEXT_DIM, DARK)

## Contatore con icona: es. scintille 12
static func counter(canvas: CanvasItem, icon_name: String, value: int, pos: Vector2, color: Color) -> float:
	icon(canvas, icon_name, pos, 1, color)
	var t := str(value)
	PixelFont.draw_text(canvas, t, pos + Vector2(9, 0), 1, Color.WHITE)
	return 9 + PixelFont.text_width(t, 1) + 6
