extends Node2D
## Objetos recolectables: créditos, botiquines, munición, bombas EMP y potenciadores temporales.

var game: Node2D
var kind := "credit"
var subkind := "rapid"
var value := 15
var life := 14.0
var t := 0.0
var radius := 14.0
var force_pull := false


func _ready() -> void:
	t = randf() * TAU


func step(delta: float) -> bool:
	t += delta * 4.5
	life -= delta
	if life <= 0.0:
		return false
	if game and is_instance_valid(game.player):
		var p: Node2D = game.player
		var mag_r: float = p.get_magnet_radius()
		if kind == "credit":
			mag_r *= 1.35
		var d := position.distance_to(p.position)
		if force_pull:
			position = position.move_toward(p.position, 960.0 * delta)
		elif d < mag_r:
			var pull := lerpf(720.0, 260.0, clampf(d / mag_r, 0.0, 1.0))
			position = position.move_toward(p.position, pull * delta)
		if d <= p.radius + radius + 6.0:
			game.collect_pickup(self)
			return false
	queue_redraw()
	return true


func get_color() -> Color:
	match kind:
		"credit":
			return Color("ffd24d")
		"hp":
			return Color("4dff88")
		"ammo":
			return Color("4df0ff")
		"bomb":
			return Color("ff4df0")
		"power":
			return Color("ff9b3d")
	return Color.WHITE


func _draw() -> void:
	if life < 3.0 and int(life * 10.0) % 2 == 0:
		return
	var col := get_color()
	var pulse := 1.0 + 0.15 * sin(t)
	var r := radius * pulse
	draw_circle(Vector2.ZERO, r * 1.45, Color(col, 0.18))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, col, 2.2)

	if kind == "credit":
		var pts := PackedVector2Array([Vector2(0, -r * 0.7), Vector2(r * 0.7, 0), Vector2(0, r * 0.7), Vector2(-r * 0.7, 0)])
		draw_colored_polygon(pts, col)
		draw_circle(Vector2.ZERO, r * 0.25, Color.WHITE)
	elif kind == "hp":
		draw_rect(Rect2(-r * 0.22, -r * 0.6, r * 0.44, r * 1.2), col)
		draw_rect(Rect2(-r * 0.6, -r * 0.22, r * 1.2, r * 0.44), col)
	elif kind == "ammo":
		draw_rect(Rect2(-r * 0.5, -r * 0.45, r, r * 0.9), Color(col, 0.85))
		draw_rect(Rect2(-r * 0.3, -r * 0.25, r * 0.6, r * 0.5), Color.WHITE)
	elif kind == "bomb":
		draw_circle(Vector2.ZERO, r * 0.55, col)
		draw_circle(Vector2.ZERO, r * 0.25, Color.WHITE)
	elif kind == "power":
		var pts := PackedVector2Array()
		for i in 6:
			var a := t * 0.4 + i * TAU / 6.0
			pts.append(Vector2(cos(a), sin(a)) * r * 0.75)
		draw_colored_polygon(pts, col)
		draw_circle(Vector2.ZERO, r * 0.3, Color.WHITE)
