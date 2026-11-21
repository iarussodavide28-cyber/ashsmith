extends Node2D
## Schermata iniziale (passo 1): nome del gioco, incudine, braci che salgono.
## Toccando lo schermo il martello colpisce l'incudine (prova che il tocco funziona).

const BG_TOP := Color("1a0f12")
const BG_BOTTOM := Color("3a1a12")
const ORANGE := Color("ff8a2b")
const YELLOW := Color("ffd25a")
const DARK := Color("120a0c")
const STEEL := Color("5b5f6e")
const STEEL_LIGHT := Color("8a90a3")
const STEEL_DARK := Color("33353f")
const WOOD := Color("6b3d22")

const VERSION_TEXT := "V0.2 - PASSO 2"

var embers: Array = []        # braci che salgono lente
var sparks: Array = []        # scintille del colpo di martello
var time := 0.0
var strike := 0.0             # 1 appena colpito, scende a 0
var shake := 0.0
var hits := 0
var starting := false

func _ready() -> void:
	randomize()
	var size := get_viewport_rect().size
	for i in 40:
		embers.append(_new_ember(size, true))

func _new_ember(size: Vector2, anywhere: bool) -> Dictionary:
	return {
		"pos": Vector2(randf() * size.x, (randf() * size.y) if anywhere else size.y + 4.0),
		"vel": Vector2(randf_range(-6, 6), randf_range(-28, -12)),
		"life": randf_range(0.5, 1.0),
		"size": 1.0 if randf() < 0.7 else 2.0,
	}

func _process(delta: float) -> void:
	time += delta
	var size := get_viewport_rect().size
	for e in embers:
		e.pos += e.vel * delta
		e.pos.x += sin(time * 2.0 + e.pos.y * 0.05) * 6.0 * delta
		if e.pos.y < -4.0:
			e.merge(_new_ember(size, false), true)
	for s in sparks:
		s.vel.y += 260.0 * delta
		s.pos += s.vel * delta
		s.life -= delta
	sparks = sparks.filter(func(s): return s.life > 0.0)
	strike = maxf(0.0, strike - delta * 4.0)
	shake = maxf(0.0, shake - delta * 6.0)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = event is InputEventScreenTouch and event.pressed
	if pressed and not starting:
		_hit_anvil()
		starting = true
		# un attimo per vedere le scintille, poi si entra nella stanza
		get_tree().create_timer(0.45).timeout.connect(func(): get_tree().change_scene_to_file("res://scenes/game.tscn"))

func _hit_anvil() -> void:
	hits += 1
	strike = 1.0
	shake = 1.0
	var c := _anvil_top_center()
	for i in 28:
		var a := randf_range(PI * 1.05, PI * 1.95)
		var sp := randf_range(60, 170)
		sparks.append({
			"pos": c,
			"vel": Vector2(cos(a), sin(a)) * sp,
			"life": randf_range(0.35, 0.8),
			"col": YELLOW if randf() < 0.5 else ORANGE,
		})

func _anvil_top_center() -> Vector2:
	var size := get_viewport_rect().size
	return Vector2(floorf(size.x / 2.0), floorf(size.y * 0.62))

func _draw() -> void:
	var size := get_viewport_rect().size
	var off := Vector2.ZERO
	if shake > 0.0:
		off = Vector2(randi_range(-2, 2), randi_range(-2, 2)) * shake
	draw_set_transform(off)

	# Sfondo a bande (sfumatura "a pixel")
	var bands := 12
	for i in bands:
		var t := float(i) / (bands - 1)
		var y0 := floorf(size.y * i / bands)
		var y1 := floorf(size.y * (i + 1) / bands)
		draw_rect(Rect2(-4, y0, size.x + 8, y1 - y0 + 1), BG_TOP.lerp(BG_BOTTOM, t))

	# Bagliore della forgia dietro l'incudine
	var c := _anvil_top_center()
	var glow := 0.25 + 0.05 * sin(time * 3.0) + strike * 0.35
	for r in [70, 52, 36]:
		draw_circle(c + Vector2(0, 10), r, Color(ORANGE, glow * (36.0 / r) * 0.5))

	# Braci
	for e in embers:
		var col := ORANGE.lerp(YELLOW, e.life)
		col.a = clampf(e.pos.y / size.y, 0.15, 1.0)
		draw_rect(Rect2(floorf(e.pos.x), floorf(e.pos.y), e.size, e.size), col)

	_draw_anvil(c)
	_draw_hammer(c)

	# Scintille
	for s in sparks:
		draw_rect(Rect2(floorf(s.pos.x), floorf(s.pos.y), 2, 2), s.col)

	# Titolo
	var title_y := floorf(size.y * 0.20)
	var flicker := 0.9 + 0.1 * sin(time * 7.0) + strike * 0.2
	PixelFont.draw_centered(self, "ASHSMITH", size.x / 2.0, title_y, 4, ORANGE.lerp(YELLOW, clampf(flicker - 0.9, 0.0, 1.0) * 3.0), DARK)
	PixelFont.draw_centered(self, "LA FORGIA NELLA CENERE", size.x / 2.0, title_y + 40, 1, Color("c9a27a"))

	# Invito a toccare (lampeggia)
	if fmod(time, 1.2) < 0.8:
		PixelFont.draw_centered(self, "TOCCA PER INIZIARE", size.x / 2.0, floorf(size.y * 0.80), 2, Color.WHITE, DARK)
	if hits > 0:
		PixelFont.draw_centered(self, "COLPI: %d" % hits, size.x / 2.0, floorf(size.y * 0.80) + 24, 1, YELLOW)

	draw_set_transform(Vector2.ZERO)
	PixelFont.draw_text(self, VERSION_TEXT, Vector2(4, size.y - 11), 1, Color("6e5a55"))

func _draw_anvil(c: Vector2) -> void:
	# c = centro della faccia superiore
	var x := c.x
	var y := c.y
	# faccia superiore + corno a sinistra
	draw_rect(Rect2(x - 30, y, 52, 8), STEEL)
	draw_rect(Rect2(x - 30, y, 52, 2), STEEL_LIGHT)
	draw_rect(Rect2(x - 44, y + 2, 14, 4), STEEL)
	draw_rect(Rect2(x - 50, y + 3, 6, 2), STEEL)
	draw_rect(Rect2(x + 22, y, 6, 6), STEEL_DARK)
	# collo
	draw_rect(Rect2(x - 14, y + 8, 28, 10), STEEL_DARK)
	# base
	draw_rect(Rect2(x - 24, y + 18, 48, 8), STEEL)
	draw_rect(Rect2(x - 24, y + 18, 48, 2), STEEL_LIGHT)
	# ceppo di legno
	draw_rect(Rect2(x - 20, y + 26, 40, 20), WOOD)
	draw_rect(Rect2(x - 20, y + 26, 40, 2), WOOD.lightened(0.2))
	draw_rect(Rect2(x - 8, y + 30, 2, 14), WOOD.darkened(0.3))
	draw_rect(Rect2(x + 8, y + 32, 2, 12), WOOD.darkened(0.3))
	# lama incandescente sulla faccia
	var hot := ORANGE.lerp(YELLOW, 0.3 + 0.3 * sin(time * 4.0) + strike * 0.5)
	draw_rect(Rect2(x - 22, y - 3, 34, 3), hot)
	draw_rect(Rect2(x + 12, y - 2, 8, 2), STEEL_DARK)

func _draw_hammer(c: Vector2) -> void:
	# il martello sta alzato e scende quando si tocca
	var lift := 26.0 * (1.0 - strike) if strike > 0.0 else 26.0 + 2.0 * sin(time * 2.0)
	var hx := c.x + 4
	var hy := c.y - 8 - lift
	draw_rect(Rect2(hx, hy - 2, 30, 4), WOOD)                 # manico
	draw_rect(Rect2(hx - 10, hy - 8, 12, 14), STEEL)          # testa
	draw_rect(Rect2(hx - 10, hy - 8, 12, 2), STEEL_LIGHT)
