extends Node2D
## Schermata iniziale: nome del gioco, incudine con braci. Tocca per entrare.

const VERSION_TEXT := "v0.5"

var embers: Array = []
var sparks: Array = []
var time := 0.0
var strike := 0.0
var starting := false

func _ready() -> void:
	randomize()
	var s := get_viewport_rect().size
	for i in 40:
		embers.append({"pos": Vector2(randf() * s.x, randf() * s.y), "vel": Vector2(randf_range(-6, 6), randf_range(-30, -12)), "r": randf_range(0.6, 1.6)})

func _process(delta: float) -> void:
	time += delta
	var s := get_viewport_rect().size
	for e in embers:
		e.pos += e.vel * delta
		e.pos.x += sin(time * 2.0 + e.pos.y * 0.05) * 6.0 * delta
		if e.pos.y < -4:
			e.pos = Vector2(randf() * s.x, s.y + 4)
	for p in sparks:
		p.vel.y += 260.0 * delta
		p.pos += p.vel * delta
		p.life -= delta
	sparks = sparks.filter(func(p): return p.life > 0.0)
	strike = maxf(0.0, strike - delta * 4.0)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and not starting:
		starting = true
		strike = 1.0
		var c := _anvil_pos()
		for i in 30:
			var a := randf_range(PI * 1.05, PI * 1.95)
			sparks.append({"pos": c + Vector2(0, -8), "vel": Vector2.from_angle(a) * randf_range(60, 170), "life": randf_range(0.3, 0.8)})
		get_tree().create_timer(0.45).timeout.connect(func(): get_tree().change_scene_to_file("res://scenes/menu.tscn"))

func _anvil_pos() -> Vector2:
	var s := get_viewport_rect().size
	return Vector2(s.x / 2.0, s.y * 0.6)

func _draw() -> void:
	var s := get_viewport_rect().size
	# sfondo: sfumatura viola scura come Braceforte 2
	var top := Color("2b2350")
	var bottom := Color("0a0816")
	for i in 24:
		var t := i / 23.0
		draw_rect(Rect2(0, s.y * i / 24.0, s.x, s.y / 24.0 + 1), top.lerp(bottom, t))
	var c := _anvil_pos()
	Art.glow(self, c, 120 + 20 * strike, Color(1, 0.5, 0.2, 0.35 + 0.05 * sin(time * 3.0) + strike * 0.3))
	for e in embers:
		var a: float = clampf(e.pos.y / s.y, 0.2, 1.0)
		Art.glow(self, e.pos, e.r * 4, Color(1, 0.6, 0.2, 0.4 * a))
		draw_circle(e.pos, e.r, Color(1, 0.85, 0.5, a))
	_draw_anvil(c)
	for p in sparks:
		Art.glow(self, p.pos, 5, Color(1, 0.7, 0.2, 0.7))
		draw_circle(p.pos, 1.2, Color("fff0b0"))
	# titolo
	var ty := s.y * 0.17
	Art.glow(self, Vector2(s.x / 2.0, ty + 18), 110, Color(1, 0.45, 0.1, 0.25))
	_title_text("ASHSMITH", s.x / 2.0, ty)
	PixelFont.draw_centered(self, "La forgia nella cenere", s.x / 2.0, ty + 44, 2, Color("ffd8a0"), Color(0, 0, 0, 0.5))
	if fmod(time, 1.2) < 0.85:
		PixelFont.draw_centered(self, "Tocca per iniziare", s.x / 2.0, s.y * 0.82, 2, Color.WHITE, Color(0, 0, 0, 0.6))
	PixelFont.draw_text(self, VERSION_TEXT, Vector2(6, s.y - 14), 1, Color(1, 1, 1, 0.35))

func _title_text(t: String, cx: float, y: float) -> void:
	var f := PixelFont.bold()
	var size := 40
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var base := Vector2(cx - w / 2.0, y + f.get_ascent(size))
	draw_string_outline(f, base + Vector2(0, 3), t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 8, Art.DARK)
	draw_string_outline(f, base, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Art.DARK)
	draw_string(f, base, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("ffb03a"))
	draw_string(f, base - Vector2(0, 1), t.substr(0, t.length()), HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 0.85, 0.4, 0.35))

func _draw_anvil(c: Vector2) -> void:
	var o := Art.DARK
	# ceppo
	draw_rect(Rect2(c.x - 26, c.y + 22, 52, 30), o)
	draw_rect(Rect2(c.x - 24, c.y + 24, 48, 26), Color("6b3d22"))
	draw_rect(Rect2(c.x - 24, c.y + 24, 48, 5), Color("8a5a32"))
	# incudine (forma con contorno)
	var pts := PackedVector2Array([
		Vector2(-46, -4), Vector2(-30, -10), Vector2(30, -10), Vector2(34, -4), Vector2(34, 4), Vector2(16, 8),
		Vector2(20, 22), Vector2(-20, 22), Vector2(-16, 8), Vector2(-30, 4), Vector2(-46, 0)])
	for i in pts.size():
		pts[i] += c
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_colored_polygon(pts, Color("5a5f7a"))
	draw_polyline(outline, o, 3.0, true)
	draw_rect(Rect2(c.x - 30, c.y - 9, 62, 4), Color("8a90b0"))
	# lama incandescente
	var hot := Color("ff7a1a").lerp(Color("ffe14a"), 0.4 + 0.3 * sin(time * 4.0) + strike * 0.4)
	Art.glow(self, c + Vector2(-4, -14), 30, Color(hot, 0.6))
	Art.rbox(self, Rect2(c.x - 26, c.y - 16, 44, 6), hot, o, 3, 2)
	# martello
	var lift := 26.0 * (1.0 - strike) if strike > 0.0 else 26.0 + 2.0 * sin(time * 2.0)
	var hp := Vector2(c.x + 8, c.y - 20 - lift)
	Art.rbox(self, Rect2(hp.x, hp.y - 2, 38, 5), Color("8a5a32"), o, 2, 2)
	Art.rbox(self, Rect2(hp.x - 12, hp.y - 9, 16, 18), Color("5a5f7a"), o, 3, 2)
