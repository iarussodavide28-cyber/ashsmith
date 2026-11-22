class_name Coach
## Tutorial: riquadro con consiglio, freccia e luce sul punto da guardare.
## tip = {title, text, target (Vector2 o null), block (bool), top (bool)}

static func seen(id: String) -> bool:
	return id in Save.tips

static func mark(id: String) -> void:
	if not id in Save.tips:
		Save.tips.append(id)
		Save.save_game()

static func _lines(t: String, max_w: float) -> Array:
	var out: Array = []
	for para in t.split("\n"):
		var cur := ""
		for word in para.split(" "):
			var tryl: String = word if cur == "" else cur + " " + word
			if PixelFont.text_width(tryl, 1) > max_w and cur != "":
				out.append(cur)
				cur = word
			else:
				cur = tryl
		out.append(cur)
	return out

static func draw(cv: CanvasItem, s: Vector2, tip: Dictionary, t: float, top_y: float, bottom_y: float) -> void:
	var a := clampf(t * 5.0, 0.0, 1.0)
	var target = tip.get("target", null)
	var block: bool = tip.get("block", false)
	if block:
		var dim := Color(0, 0, 0, 0.55 * a)
		if target != null:
			# buio tutto attorno, ma il punto da guardare resta illuminato
			var hole := Rect2((target as Vector2) - Vector2(72, 30), Vector2(144, 60))
			cv.draw_rect(Rect2(0, 0, s.x, hole.position.y), dim)
			cv.draw_rect(Rect2(0, hole.end.y, s.x, s.y - hole.end.y), dim)
			cv.draw_rect(Rect2(0, hole.position.y, hole.position.x, hole.size.y), dim)
			cv.draw_rect(Rect2(hole.end.x, hole.position.y, s.x - hole.end.x, hole.size.y), dim)
		else:
			cv.draw_rect(Rect2(Vector2.ZERO, s), dim)
	if target != null:
		var tp: Vector2 = target
		var pr := 16.0 + 3.0 * sin(t * 6.0)
		Art.glow(cv, tp, pr * 2.6, Color(1, 0.75, 0.3, 0.35 * a))
		cv.draw_arc(tp, pr, 0, TAU, 32, Color(Art.GOLD_L, a), 2.0, true)
		cv.draw_arc(tp, pr + 5.0, t * 2.0, t * 2.0 + 2.0, 16, Color(Art.GOLD, 0.7 * a), 1.5, true)
	var w := s.x - 28.0
	var lines := _lines(str(tip.text), w - 24)
	var h := 34.0 + lines.size() * 12.0 + (16.0 if block else 4.0)
	var on_top: bool = tip.get("top", target == null)
	if target != null and not tip.has("top"):
		on_top = (target as Vector2).y > s.y * 0.55
	var y := top_y + 8.0 if on_top else bottom_y - h - 8.0
	var r := Rect2(14, y + (1.0 - a) * (12.0 if on_top else -12.0) * -1.0, w, h)
	# freccia verso il punto
	if target != null:
		var tp: Vector2 = target
		var from := Vector2(clampf(tp.x, r.position.x + 20, r.end.x - 20), r.end.y if not on_top or tp.y > r.end.y else r.position.y)
		if (tp - from).length() > 30.0:
			var d := (tp - from).normalized()
			var bob := sin(t * 7.0) * 3.0
			var tip_p := tp - d * (26.0 + bob)
			var base := from + d * 4.0
			cv.draw_line(base, tip_p - d * 6.0, Color(Art.INK, a), 5.0, true)
			cv.draw_line(base, tip_p - d * 6.0, Color(Art.GOLD, a), 2.5, true)
			var o := d.orthogonal()
			cv.draw_colored_polygon(PackedVector2Array([tip_p + d * 2.0, tip_p - d * 8.0 + o * 6.0, tip_p - d * 8.0 - o * 6.0]), Color(Art.GOLD_L, a))
	Art.plate(cv, r, Color(0.16, 0.13, 0.17, 0.97 * a), Color(0.06, 0.05, 0.07, 0.97 * a), Color(Art.GOLD, a), 7.0, true)
	# piccola incudine come icona del maestro fabbro
	Art.icon(cv, "anvil", r.position + Vector2(10, 9), 2.0, Color(Art.GOLD, a))
	PixelFont.draw_text(cv, str(tip.title), r.position + Vector2(30, 7), 2, Color(Art.GOLD_L, a))
	var ly := r.position.y + 30.0
	for l in lines:
		PixelFont.draw_text(cv, l, Vector2(r.position.x + 12, ly), 1, Color(Art.TEXT, a))
		ly += 12.0
	if block:
		var pa := (0.55 + 0.45 * sin(t * 5.0)) * a
		PixelFont.draw_centered(cv, "Tocca per continuare", r.get_center().x, r.end.y - 14, 1, Color(Art.GOLD, pa))
