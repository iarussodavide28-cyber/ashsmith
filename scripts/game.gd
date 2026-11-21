extends Node2D
## Passo 2: una stanza e l'eroe (un quadrato) che si muove col dito.
## Controllo a "joystick invisibile": appoggi il dito dove vuoi e trascini
## nella direzione in cui vuoi andare. Più trascini, più va veloce (fino a un massimo).

const FLOOR_A := Color("2b2024")
const FLOOR_B := Color("30242a")
const WALL := Color("4a3838")
const WALL_TOP := Color("6b5050")
const WALL_DARK := Color("1c1316")
const HERO := Color("ff8a2b")
const HERO_DARK := Color("b8541a")
const HERO_LIGHT := Color("ffd25a")
const JOY_COLOR := Color(1, 1, 1, 0.18)

const TILE := 15
const WALL_SIZE := 12             # spessore dei muri in pixel
const HERO_SIZE := 16
const MAX_SPEED := 95.0           # pixel al secondo
const ACCEL := 900.0              # quanto in fretta raggiunge la velocità
const FRICTION := 1100.0          # quanto in fretta si ferma quando alzi il dito
const JOY_RADIUS := 28.0          # trascinamento che dà la velocità massima
const JOY_DEADZONE := 3.0

var hero_pos := Vector2.ZERO
var hero_vel := Vector2.ZERO
var facing := Vector2.DOWN

var touch_index := -1             # quale dito comanda (-1 = nessuno)
var joy_origin := Vector2.ZERO
var joy_current := Vector2.ZERO

var time := 0.0
var step_t := 0.0                 # per l'animazione dei passi

func _ready() -> void:
	hero_pos = _room_rect().get_center()

func _room_rect() -> Rect2:
	# area calpestabile: tutto lo schermo meno muri e una fascia in alto per l'interfaccia
	var size := get_viewport_rect().size
	var top := 28.0
	return Rect2(WALL_SIZE, top + WALL_SIZE, size.x - WALL_SIZE * 2, size.y - top - WALL_SIZE * 2)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and touch_index == -1:
			touch_index = t.index
			joy_origin = t.position
			joy_current = t.position
		elif not t.pressed and t.index == touch_index:
			touch_index = -1
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == touch_index:
			joy_current = d.position
			# se il dito va oltre il raggio, il centro del joystick lo segue
			var off := joy_current - joy_origin
			if off.length() > JOY_RADIUS:
				joy_origin = joy_current - off.normalized() * JOY_RADIUS

func _process(delta: float) -> void:
	time += delta
	var target := Vector2.ZERO
	if touch_index != -1:
		var off := joy_current - joy_origin
		if off.length() > JOY_DEADZONE:
			var strength := clampf((off.length() - JOY_DEADZONE) / (JOY_RADIUS - JOY_DEADZONE), 0.0, 1.0)
			target = off.normalized() * MAX_SPEED * maxf(strength, 0.35)
			facing = off.normalized()
	if target != Vector2.ZERO:
		hero_vel = hero_vel.move_toward(target, ACCEL * delta)
	else:
		hero_vel = hero_vel.move_toward(Vector2.ZERO, FRICTION * delta)

	hero_pos += hero_vel * delta
	# niente uscite: l'eroe resta dentro la stanza
	var r := _room_rect()
	var half := HERO_SIZE / 2.0
	hero_pos.x = clampf(hero_pos.x, r.position.x + half, r.end.x - half)
	hero_pos.y = clampf(hero_pos.y, r.position.y + half, r.end.y - half)

	if hero_vel.length() > 5.0:
		step_t += delta * hero_vel.length() / 10.0
	queue_redraw()

func _draw() -> void:
	var size := get_viewport_rect().size
	var r := _room_rect()

	# sfondo e pavimento a scacchi
	draw_rect(Rect2(Vector2.ZERO, size), WALL_DARK)
	var cols := int(ceil(r.size.x / TILE))
	var rows := int(ceil(r.size.y / TILE))
	for y in rows:
		for x in cols:
			var tile := Rect2(r.position + Vector2(x * TILE, y * TILE), Vector2(TILE, TILE)).intersection(r)
			draw_rect(tile, FLOOR_A if (x + y) % 2 == 0 else FLOOR_B)

	# muri
	draw_rect(Rect2(r.position.x - WALL_SIZE, r.position.y - WALL_SIZE, r.size.x + WALL_SIZE * 2, WALL_SIZE), WALL)
	draw_rect(Rect2(r.position.x - WALL_SIZE, r.position.y - WALL_SIZE, r.size.x + WALL_SIZE * 2, 3), WALL_TOP)
	draw_rect(Rect2(r.position.x - WALL_SIZE, r.end.y, r.size.x + WALL_SIZE * 2, WALL_SIZE), WALL)
	draw_rect(Rect2(r.position.x - WALL_SIZE, r.position.y, WALL_SIZE, r.size.y), WALL)
	draw_rect(Rect2(r.end.x, r.position.y, WALL_SIZE, r.size.y), WALL)
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 2), Color(0, 0, 0, 0.35))

	# ombra + eroe
	var half := HERO_SIZE / 2.0
	var bob := 0.0
	if hero_vel.length() > 5.0:
		bob = -1.0 if fmod(step_t, 2.0) < 1.0 else 0.0
	var p := Vector2(roundf(hero_pos.x - half), roundf(hero_pos.y - half + bob))
	draw_rect(Rect2(roundf(hero_pos.x - half + 1), roundf(hero_pos.y + half - 1), HERO_SIZE - 2, 3), Color(0, 0, 0, 0.4))
	draw_rect(Rect2(p, Vector2(HERO_SIZE, HERO_SIZE)), HERO_DARK)
	draw_rect(Rect2(p + Vector2(1, 1), Vector2(HERO_SIZE - 2, HERO_SIZE - 3)), HERO)
	draw_rect(Rect2(p + Vector2(1, 1), Vector2(HERO_SIZE - 2, 2)), HERO_LIGHT)
	# occhi che guardano nella direzione di marcia
	var eye := Vector2(roundf(facing.x * 2.0), roundf(facing.y * 2.0))
	var c := p + Vector2(half, half) + eye
	draw_rect(Rect2(c + Vector2(-3, -1), Vector2(2, 2)), Color("120a0c"))
	draw_rect(Rect2(c + Vector2(1, -1), Vector2(2, 2)), Color("120a0c"))

	# joystick (solo mentre tieni il dito giù)
	if touch_index != -1:
		draw_arc(joy_origin, JOY_RADIUS, 0, TAU, 32, JOY_COLOR, 1.0)
		var knob := joy_origin + (joy_current - joy_origin).limit_length(JOY_RADIUS)
		draw_circle(knob, 7, Color(1, 1, 1, 0.3))

	# interfaccia in alto
	PixelFont.draw_text(self, "ASHSMITH", Vector2(6, 10), 1, HERO)
	PixelFont.draw_text(self, "PASSO 2", Vector2(size.x - PixelFont.text_width("PASSO 2", 1) - 6, 10), 1, Color("6e5a55"))
	if touch_index == -1 and time < 6.0 and fmod(time, 1.2) < 0.8:
		PixelFont.draw_centered(self, "TRASCINA IL DITO PER MUOVERTI", size.x / 2.0, r.end.y - 30, 1, Color.WHITE, Color("120a0c"))
