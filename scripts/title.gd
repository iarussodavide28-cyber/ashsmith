extends Node2D
## Schermata iniziale: la fonderia in rovina, il Fabbro davanti all'incudine,
## un fiume di metallo fuso. Tocca per entrare.

const VERSION_TEXT := "v2.0"

var embers: Array = []
var sparks: Array = []
var time := 0.0
var strike := 0.0
var starting := false

func _ready() -> void:
	randomize()
	var s := get_viewport_rect().size
	for i in 60:
		embers.append({"pos": Vector2(randf() * s.x, randf() * s.y), "vel": Vector2(randf_range(-6, 6), randf_range(-34, -10)), "r": randf_range(0.5, 1.7)})

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
	strike = maxf(0.0, strike - delta * 3.0)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and not starting:
		starting = true
		strike = 1.0
		Sfx.play("clang", 0.0, 3.0)
		Sfx.music_on()
		var c := _anvil_pos() + Vector2(0, -14)
		for i in 40:
			var a := randf_range(PI * 1.05, PI * 1.95)
			sparks.append({"pos": c, "vel": Vector2.from_angle(a) * randf_range(60, 200), "life": randf_range(0.3, 0.9)})
		get_tree().create_timer(0.55).timeout.connect(func(): get_tree().change_scene_to_file("res://scenes/menu.tscn"))

func _anvil_pos() -> Vector2:
	var s := get_viewport_rect().size
	return Vector2(s.x / 2.0, s.y * 0.69)

func _rect(r: Rect2, top: Color, bottom: Color) -> void:
	Art.grad_poly(self, PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), top, bottom)

func _draw() -> void:
	var s := get_viewport_rect().size
	# cielo: dal nero al rosso brace
	_rect(Rect2(0, 0, s.x, s.y * 0.55), Color("07060a"), Color("3a120a"))
	_rect(Rect2(0, s.y * 0.55, s.x, s.y * 0.45), Color("3a120a"), Color("0a0608"))
	Art.glow(self, Vector2(s.x / 2.0, s.y * 0.56), s.x * 0.9, Color(1, 0.35, 0.08, 0.35))
	# fonderia in rovina sullo sfondo: ciminiere e archi
	var far := Color("140c10")
	for c in [[0.08, 0.2, 0.14], [0.26, 0.14, 0.1], [0.74, 0.12, 0.11], [0.9, 0.22, 0.15]]:
		var x: float = s.x * c[0]
		var top: float = s.y * c[1]
		var w: float = s.x * 0.06
		draw_colored_polygon(PackedVector2Array([Vector2(x - w, s.y * 0.58), Vector2(x - w * 0.7, top), Vector2(x + w * 0.7, top), Vector2(x + w, s.y * 0.58)]), far)
		draw_rect(Rect2(x - w * 0.9, top - 4, w * 1.8, 5), far)
		# fumo
		for i in 4:
			var sp := Vector2(x + sin(time * 0.5 + i + x) * 6, top - 10 - i * 16 - fmod(time * 6.0, 16.0))
			draw_circle(sp, 7 + i * 3, Color(0.12, 0.08, 0.09, 0.35 - i * 0.07))
	var hall := PackedVector2Array([Vector2(0, s.y * 0.6), Vector2(0, s.y * 0.4), Vector2(s.x * 0.18, s.y * 0.36), Vector2(s.x * 0.35, s.y * 0.42), Vector2(s.x * 0.5, s.y * 0.33), Vector2(s.x * 0.65, s.y * 0.42), Vector2(s.x * 0.82, s.y * 0.35), Vector2(s.x, s.y * 0.4), Vector2(s.x, s.y * 0.6)])
	draw_colored_polygon(hall, Color("0e090c"))
	for i in 5:
		var ax := s.x * (0.1 + i * 0.2)
		var ay := s.y * 0.5
		draw_circle(Vector2(ax, ay), 13, Color(1, 0.4, 0.1, 0.18 + 0.05 * sin(time * 2.0 + i)))
		draw_rect(Rect2(ax - 13, ay, 26, s.y * 0.1), Color(1, 0.4, 0.1, 0.16 + 0.05 * sin(time * 2.0 + i)))
	# fiume di metallo fuso
	var ry := s.y * 0.8
	_rect(Rect2(0, ry, s.x, s.y * 0.07), Color("ff9a2a"), Color("b0300a"))
	Art.glow(self, Vector2(s.x / 2.0, ry + 10), s.x * 0.8, Color(1, 0.5, 0.1, 0.35))
	for i in 14:
		var fx := fmod(i * 41.0 + time * 18.0, s.x + 40) - 20
		draw_line(Vector2(fx, ry + 4 + (i % 4) * 5), Vector2(fx + 16, ry + 4 + (i % 4) * 5), Color(1, 0.9, 0.5, 0.5), 1.5)
	_rect(Rect2(0, ry + s.y * 0.07, s.x, s.y * 0.2), Color("1a0c0a"), Color("050304"))
	# roccia, incudine, eroe
	var a := _anvil_pos()
	draw_colored_polygon(PackedVector2Array([a + Vector2(-90, 40), a + Vector2(-70, 6), a + Vector2(-20, -2), a + Vector2(40, 0), a + Vector2(85, 12), a + Vector2(100, 40)]), Color("120c10"))
	Art.glow(self, a + Vector2(0, -10), 90 + strike * 40, Color(1, 0.5, 0.15, 0.35 + strike * 0.4))
	_draw_anvil(a + Vector2(34, -2))
	HeroArt.draw(self, a + Vector2(-26, 4), Vector2(0.35, 0.94).normalized(), time, 0.0, false, "sword", Data.WEAPONS.sword.color, 0.0, 2.6)
	for e in embers:
		Art.glow(self, e.pos, e.r * 4, Color(1, 0.5, 0.15, 0.35))
		draw_circle(e.pos, e.r, Color(1, 0.75, 0.35, 0.9))
	for p in sparks:
		draw_line(p.pos, p.pos - p.vel * 0.03, Color(1, 0.85, 0.4, clampf(p.life * 2.0, 0.0, 1.0)), 1.5)
	# logo
	var ly := s.y * 0.12
	Art.glow(self, Vector2(s.x / 2.0, ly + 24), 150, Color(1, 0.5, 0.15, 0.25))
	PixelFont.draw_custom(self, "cinzel", "ASHSMITH", s.x / 2.0, ly + 3, 44, Color("3a1a08"), Art.INK, 7)
	PixelFont.draw_custom(self, "cinzel", "ASHSMITH", s.x / 2.0, ly, 44, Color("c8862a"))
	PixelFont.draw_custom(self, "cinzel", "ASHSMITH", s.x / 2.0, ly - 1.2, 44, Color(1, 0.88, 0.6, 0.55))
	var sub := "L A   F O R G I A   N E L L A   C E N E R E"
	PixelFont.draw_custom(self, "oswald_m", sub, s.x / 2.0, ly + 52, 10, Color("e8c49a"), Color(0, 0, 0, 0.6), 3)
	for side in [-1.0, 1.0]:
		var x0: float = s.x / 2.0 + side * 30
		var x1: float = s.x / 2.0 + side * 110
		draw_line(Vector2(x0, ly + 70), Vector2(x1, ly + 70), Color(Art.GOLD, 0.6), 1.0)
	var d := Vector2(s.x / 2.0, ly + 70)
	draw_colored_polygon(PackedVector2Array([d + Vector2(0, -4), d + Vector2(4, 0), d + Vector2(0, 4), d + Vector2(-4, 0)]), Art.GOLD)
	# invito
	var pa := 0.45 + 0.55 * absf(sin(time * 2.2))
	PixelFont.draw_custom(self, "oswald", "TOCCA PER ENTRARE NELLA FORGIA", s.x / 2.0, s.y * 0.92, 13, Color(1, 0.92, 0.8, pa), Color(0, 0, 0, 0.7 * pa), 3)
	PixelFont.draw_text(self, VERSION_TEXT, Vector2(6, s.y - 14), 1, Color(1, 1, 1, 0.3))
	if strike > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(1, 0.8, 0.5, strike * 0.35))

func _draw_anvil(p: Vector2) -> void:
	var k := 1.5
	var S := func(v: Vector2) -> Vector2: return p + v * k
	HeroArt.ellipse(self, p + Vector2(0, 2), 30, 6, Color(0, 0, 0, 0.5))
	HeroArt._gpoly(self, [S.call(Vector2(-12, -14)), S.call(Vector2(12, -14)), S.call(Vector2(16, 0)), S.call(Vector2(-16, 0))], Color("3a3440"), Color("16131a"), 2.0)
	HeroArt._gpoly(self, [S.call(Vector2(-28, -28)), S.call(Vector2(18, -28)), S.call(Vector2(24, -24)), S.call(Vector2(18, -20)), S.call(Vector2(8, -18)), S.call(Vector2(10, -14)), S.call(Vector2(-10, -14)), S.call(Vector2(-8, -18)), S.call(Vector2(-18, -20)), S.call(Vector2(-28, -24))], Color("7a7488"), Color("2a2630"), 2.0)
	draw_line(S.call(Vector2(-26, -27)), S.call(Vector2(17, -27)), Color(1, 1, 1, 0.35), 1.2)
	var hot := Color("ff7a1a").lerp(Color("ffe08a"), 0.5 + 0.5 * sin(time * 3.0))
	Art.glow(self, S.call(Vector2(-4, -31)), 22, Color(1, 0.5, 0.1, 0.6))
	HeroArt._poly(self, [S.call(Vector2(-14, -33)), S.call(Vector2(6, -33)), S.call(Vector2(8, -29)), S.call(Vector2(-12, -29))], hot, 1.4)
