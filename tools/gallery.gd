extends Node2D
## Solo per le prove: vetrina dei nemici in grande.
var t := 0.0
func _process(d: float) -> void:
	t += d
	queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(0, 0, 270, 480), Color("2a2630"))
	var ks := ["zombie", "archer", "imp", "spitter", "pebble", "golem", "miniboss", "boss"]
	for i in ks.size():
		var c := Vector2(70 + (i % 2) * 130, 60 + (i / 2) * 112)
		var sz := {"golem": 28, "miniboss": 40, "boss": 46}.get(ks[i], 17) as int
		var r := (sz / 2.0 + 1.0) * 1.25
		var k := 2.6 * minf(1.0, 16.0 / r)
		draw_set_transform(c, 0, Vector2(k, k))
		HeroArt.ellipse(self, Vector2(0, r * 0.85), r * 0.95, r * 0.36, Color(0, 0, 0, 0.35))
		var e := {"k": ks[i], "flash": 0.0, "phase": 1}
		EnemyArt.draw(self, e, Vector2.ZERO, r, t, Vector2(0.3, 1).normalized(), true)
		draw_set_transform(Vector2.ZERO)
