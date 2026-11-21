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
	"helmet": ["0011100","0111110","1111111","1101011","1101011","1100011","0000000"],
	"armor": ["1100011","1111111","1111111","0111110","0111110","0111110","0011100"],
	"gloves": ["0101010","0101010","0111110","1111110","0111110","0111100","0011100"],
	"boots": ["0011100","0011100","0011100","0011100","0011110","1111111","1111111"],
	"ring": ["0001000","0011100","0001000","0110110","1000001","1000001","0111110"],
	"rock": ["0000000","0011100","0111110","1111011","1110111","1111111","0111110"],
	"lock": ["0011100","0100010","0100010","1111111","1110111","1110111","1111111"],
	"chest": ["0111110","1000001","1111111","1110111","1111111","1000001","1111111"],
	"book": ["1111110","1000011","1011011","1000011","1011011","1000011","1111110"],
	"play": ["1000000","1100000","1110000","1111000","1110000","1100000","1000000"],
	"bag": ["0011100","0100010","1111111","1111111","1101011","1111111","0111110"],
	"shop": ["1111111","1010101","1111111","0000000","1011101","1011101","1111111"],
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

## Icona di un pezzo di equipaggiamento
static func item_icon_name(item: Dictionary) -> String:
	var t: String = Gear.BASES[item.base].type
	if t == "weapon":
		return Gear.BASES[item.base].weapon
	return t

## Riquadro di un pezzo (colore della rarità, icona, livello)
static func item_box(canvas: CanvasItem, item: Dictionary, r: Rect2, selected: bool = false) -> void:
	var rc: Color = Gear.RARITY[item.rar].color
	canvas.draw_rect(r.grow(1), DARK)
	canvas.draw_rect(r, rc if not selected else Color.WHITE)
	canvas.draw_rect(r.grow(-1), rc.darkened(0.7))
	canvas.draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 3)), rc.darkened(0.45))
	var sc := 3 if r.size.x >= 28 else 2
	var isz := 7 * sc
	icon(canvas, item_icon_name(item), r.get_center() - Vector2(isz, isz) / 2.0 - Vector2(0, 2), sc, Color.WHITE.lerp(rc, 0.35))
	var t := "L%d" % item.lv
	PixelFont.draw_text(canvas, t, Vector2(r.end.x - PixelFont.text_width(t, 1) - 2, r.end.y - 8), 1, Color.WHITE)
