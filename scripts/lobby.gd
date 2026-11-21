extends Node2D
## Campo base: vedi oro e gemme, scegli le 2 armi e parti.

var chosen: Array = []
var time := 0.0
var card_rects: Array = []
var start_rect := Rect2()

func _ready() -> void:
	chosen = Save.weapons.duplicate()

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch and event.pressed):
		return
	var p: Vector2 = event.position
	for i in card_rects.size():
		if card_rects[i].has_point(p):
			var w: String = Data.WEAPON_ORDER[i]
			if w in chosen:
				chosen.erase(w)
			else:
				chosen.append(w)
				if chosen.size() > 2:
					chosen.pop_front()
			return
	if start_rect.has_point(p) and chosen.size() == 2:
		Save.weapons = chosen.duplicate()
		Save.save_game()
		get_tree().change_scene_to_file("res://scenes/game.tscn")

func _draw() -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color("1a0f12"))
	# braci di sfondo
	for i in 24:
		var x := fmod(i * 47.0 + sin(i) * 30.0, size.x)
		var y := size.y - fmod(time * (10.0 + i % 5 * 4) + i * 71.0, size.y)
		draw_rect(Rect2(floorf(x), floorf(y), 1, 1), Color(Art.SPARK, 0.5))

	# barra in alto: oro e gemme
	draw_rect(Rect2(0, 0, size.x, 22), Color("0e0809"))
	var x0 := 6.0
	x0 += Art.counter(self, "gold", Save.gold, Vector2(x0, 8), Art.GOLD)
	Art.counter(self, "gem", Save.gems, Vector2(x0, 8), Art.GEM)
	var rec := "RECORD: STANZA %d" % Save.best_room
	PixelFont.draw_text(self, rec, Vector2(size.x - PixelFont.text_width(rec, 1) - 6, 8), 1, Art.TEXT_DIM)

	PixelFont.draw_centered(self, "CAMPO BASE", size.x / 2.0, 40, 3, Art.SPARK, Art.DARK)
	PixelFont.draw_centered(self, "CAPITOLO 1: LA FONDERIA CADUTA", size.x / 2.0, 70, 1, Color("c9a27a"))
	PixelFont.draw_centered(self, "SCEGLI 2 ARMI", size.x / 2.0, 96, 2, Color.WHITE, Art.DARK)

	card_rects.clear()
	var cw := size.x - 32
	var ch := 62.0
	var y := 120.0
	for i in Data.WEAPON_ORDER.size():
		var key: String = Data.WEAPON_ORDER[i]
		var w: Dictionary = Data.WEAPONS[key]
		var r := Rect2(16, y, cw, ch)
		card_rects.append(r)
		var sel: bool = key in chosen
		Art.panel(self, r, Color("2e1e20") if sel else Art.PANEL, Art.SPARK if sel else Art.PANEL_EDGE)
		Art.panel(self, Rect2(r.position + Vector2(8, 10), Vector2(40, 40)), Color("1a1012"))
		Art.icon(self, key, r.position + Vector2(14, 16), 4, w.color)
		PixelFont.draw_text(self, w.name, r.position + Vector2(58, 12), 2, Color.WHITE)
		PixelFont.draw_text(self, w.desc[0], r.position + Vector2(58, 32), 1, Art.TEXT_DIM)
		PixelFont.draw_text(self, w.desc[1], r.position + Vector2(58, 42), 1, Art.TEXT_DIM)
		if sel:
			var n := "ARMA %d" % (chosen.find(key) + 1)
			PixelFont.draw_text(self, n, Vector2(r.end.x - PixelFont.text_width(n, 1) - 6, r.position.y + 6), 1, Art.SPARK)
		y += ch + 8

	var hint_y := y + 4
	PixelFont.draw_centered(self, "IN PARTITA CAMBI ARMA COL PULSANTE IN BASSO", size.x / 2.0, hint_y, 1, Art.TEXT_DIM)

	start_rect = Rect2(40, size.y - 70, size.x - 80, 34)
	var ready_ok := chosen.size() == 2
	Art.button(self, start_rect, "PARTI!" if ready_ok else "SCEGLI 2 ARMI", Color("e0661f"), ready_ok, 2)
	PixelFont.draw_text(self, "V0.3", Vector2(4, size.y - 11), 1, Color("6e5a55"))
