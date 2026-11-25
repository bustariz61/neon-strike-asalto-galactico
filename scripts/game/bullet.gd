extends Node2D
## Proyectil (del jugador o enemigo) con soporte para perforación, explosión en área y guiado.

var game: Node2D
var is_enemy := false
var vel := Vector2.ZERO
var dmg := 10.0
var color := Color("4df0ff")
var radius := 5.0
var life := 1.2
var pierce := 0
var explosive := 0.0
var homing := 0.0
var crit := false
var hit_list: Array = []
var prev_pos := Vector2.ZERO


func _ready() -> void:
	prev_pos = position


func step(delta: float) -> bool:
	prev_pos = position
	if homing > 0.0 and not is_enemy and game:
		var target: Node2D = game.find_nearest_hostile(position, 650.0)
		if target:
			var desired: Vector2 = (target.position - position).normalized() * vel.length()
			vel = vel.lerp(desired, clampf(homing * delta, 0.0, 1.0)).normalized() * vel.length()
	position += vel * delta
	rotation = vel.angle()
	life -= delta
	if life <= 0.0:
		return false
	if game and not game.arena.grow(40.0).has_point(position):
		game.fx.add_burst(position, color, 5, 120.0, 2.5, 0.25)
		return false
	queue_redraw()
	return true


func _draw() -> void:
	var tail := -Vector2(clampf(vel.length() * 0.025, 10.0, 28.0), 0.0)
	draw_line(tail, Vector2.ZERO, Color(color, 0.35), radius * 2.2)
	draw_line(tail * 0.6, Vector2.ZERO, color, radius * 1.1)
	draw_circle(Vector2.ZERO, radius * 1.35, Color(color, 0.35))
	draw_circle(Vector2.ZERO, radius * 0.75, Color.WHITE)
