extends Node2D
## 7 arquetipos de enemigos: Dron, Artillero, Kamikaze, Tanque, Divisor, Francotirador y Mini-dron.

var game: Node2D
var kind := "drone"
var hp := 25.0
var max_hp := 25.0
var speed := 180.0
var contact_dmg := 18.0
var radius := 16.0
var score_val := 50
var credit_val := 10
var color := Color("ff4d6a")

var fire_cd := 1.2
var state_t := 0.0
var hit_flash := 0.0
var sniper_aim := 0.0
var locked_dir := Vector2.RIGHT
var orbit_sign := 1.0
var wobble := 0.0
var knockback := Vector2.ZERO


func setup(g: Node2D, k: String, scale_mult: float = 1.0) -> void:
	game = g
	kind = k
	orbit_sign = -1.0 if randf() < 0.5 else 1.0
	wobble = randf() * TAU
	var d := Game.difficulty()
	var hp_m := float(d.hp) * scale_mult
	var dmg_m := float(d.dmg) * (1.0 + (scale_mult - 1.0) * 0.5)

	match kind:
		"drone":
			max_hp = 24.0 * hp_m
			speed = 215.0
			contact_dmg = 16.0 * dmg_m
			radius = 15.0
			score_val = 60
			credit_val = 10
			color = Color("4df0ff")
		"shooter":
			max_hp = 38.0 * hp_m
			speed = 165.0
			contact_dmg = 16.0 * dmg_m
			radius = 17.0
			score_val = 110
			credit_val = 16
			color = Color("ff9b3d")
			fire_cd = randf_range(0.6, 1.5)
		"kamikaze":
			max_hp = 22.0 * hp_m
			speed = 310.0
			contact_dmg = 28.0 * dmg_m
			radius = 14.0
			score_val = 90
			credit_val = 14
			color = Color("ffd24d")
		"tank":
			max_hp = 125.0 * hp_m
			speed = 95.0
			contact_dmg = 26.0 * dmg_m
			radius = 25.0
			score_val = 240
			credit_val = 30
			color = Color("ff4d6a")
			fire_cd = 1.6
		"splitter":
			max_hp = 68.0 * hp_m
			speed = 145.0
			contact_dmg = 20.0 * dmg_m
			radius = 21.0
			score_val = 170
			credit_val = 22
			color = Color("c46bff")
			fire_cd = 1.5
		"sniper":
			max_hp = 44.0 * hp_m
			speed = 140.0
			contact_dmg = 15.0 * dmg_m
			radius = 17.0
			score_val = 190
			credit_val = 24
			color = Color("4d8bff")
			fire_cd = 1.8
		"mini":
			max_hp = 13.0 * hp_m
			speed = 275.0
			contact_dmg = 12.0 * dmg_m
			radius = 11.0
			score_val = 35
			credit_val = 6
			color = Color("ff4df0")
	hp = max_hp


func step(delta: float) -> bool:
	if hp <= 0.0:
		return false
	state_t += delta
	if hit_flash > 0.0:
		hit_flash = maxf(0.0, hit_flash - delta)

	var p: Node2D = game.player
	if not is_instance_valid(p):
		return true

	var to_p := p.position - position
	var dist := to_p.length()
	var dir := to_p / maxf(dist, 0.001)
	var dmg_m := float(Game.difficulty().dmg)

	match kind:
		"drone", "mini":
			var side := dir.orthogonal() * sin(state_t * 5.0 + wobble) * 0.35
			position += (dir + side).normalized() * speed * delta
			rotation = dir.angle()
		"kamikaze":
			var boost := 1.38 if dist < 320.0 else 1.0
			position += dir * speed * boost * delta
			rotation = dir.angle()
		"shooter":
			var move := Vector2.ZERO
			if dist > 340.0:
				move = dir
			elif dist < 210.0:
				move = -dir
			move += dir.orthogonal() * orbit_sign * 0.75
			position += move.normalized() * speed * delta
			rotation = dir.angle()
			fire_cd -= delta
			if fire_cd <= 0.0 and dist < 680.0:
				fire_cd = 1.45
				Sfx.play("enemy_shoot", -5.0)
				game.spawn_bullet(position + dir * 18.0, dir * 430.0, 14.0 * dmg_m, color, 5.0, 2.2, true)
		"tank":
			position += dir * speed * delta
			rotation = dir.angle()
			fire_cd -= delta
			if fire_cd <= 0.0 and dist < 740.0:
				fire_cd = 2.1
				Sfx.play("enemy_shoot", -3.0)
				for i in range(-2, 3):
					var bdir := dir.rotated(i * 0.22)
					game.spawn_bullet(position + bdir * 24.0, bdir * 340.0, 17.0 * dmg_m, color, 6.5, 2.6, true)
		"splitter":
			var move := dir + dir.orthogonal() * sin(state_t * 3.2 + wobble) * 0.5
			position += move.normalized() * speed * delta
			rotation += 1.6 * delta
			fire_cd -= delta
			if fire_cd <= 0.0 and dist < 650.0:
				fire_cd = 1.75
				Sfx.play("enemy_shoot", -5.0)
				for s in [-0.14, 0.14]:
					var bdir := dir.rotated(s)
					game.spawn_bullet(position + bdir * 18.0, bdir * 390.0, 14.0 * dmg_m, color, 5.5, 2.3, true)
		"sniper":
			if sniper_aim > 0.0:
				sniper_aim -= delta
				if sniper_aim > 0.25:
					locked_dir = dir
				rotation = locked_dir.angle()
				if sniper_aim <= 0.0:
					Sfx.play("rail", -5.0)
					game.spawn_bullet(position + locked_dir * 20.0, locked_dir * 860.0, 24.0 * dmg_m, Color("ff4d6a"), 5.5, 1.8, true)
					fire_cd = 2.1
			else:
				var move := Vector2.ZERO
				if dist > 540.0:
					move = dir
				elif dist < 380.0:
					move = -dir
				else:
					move = dir.orthogonal() * orbit_sign
				position += move.normalized() * speed * delta
				rotation = dir.angle()
				fire_cd -= delta
				if fire_cd <= 0.0 and dist < 850.0:
					sniper_aim = 1.05
					locked_dir = dir
					Sfx.play("charge", -6.0)

	if knockback.length_squared() > 1.0:
		position += knockback * delta
		knockback = knockback.move_toward(Vector2.ZERO, 950.0 * delta)

	var bounds: Rect2 = game.arena.grow(-radius)
	position.x = clampf(position.x, bounds.position.x, bounds.end.x)
	position.y = clampf(position.y, bounds.position.y, bounds.end.y)

	if position.distance_to(p.position) <= radius + p.radius:
		if p.dash_time <= 0.0:
			p.take_damage(contact_dmg, self)
			if kind == "kamikaze":
				Sfx.play("explosion", -3.0)
				game.add_shake(5.0)
				game.fx.add_ring(position, color, 85.0, 0.3, 4.0)
				game.fx.add_burst(position, color, 16, 260.0, 3.6, 0.45)
				hp = 0.0
				return false
			else:
				position -= dir * 24.0

	queue_redraw()
	return hp > 0.0


func take_damage(amount: float, is_crit: bool = false, impulse: Vector2 = Vector2.ZERO) -> void:
	if hp <= 0.0:
		return
	hp -= amount
	hit_flash = 0.1
	if impulse.length_squared() > 0.0:
		var mass := 2.4 if kind == "tank" else (1.4 if kind == "splitter" else 1.0)
		knockback += impulse / mass
		if knockback.length() > 360.0:
			knockback = knockback.normalized() * 360.0
	Sfx.play("hit", -7.0)
	if Game.settings.damage_numbers:
		var col := Color("ffd24d") if is_crit else Color.WHITE
		var txt := "%d!" % int(round(amount)) if is_crit else "%d" % int(round(amount))
		game.fx.add_text(position + Vector2(0, -radius), txt, col, 19 if is_crit else 15)
	if hp <= 0.0:
		game.on_enemy_killed(self)


func _draw() -> void:
	if kind == "sniper" and sniper_aim > 0.0:
		var a := 0.35 + 0.55 * absf(sin(sniper_aim * 18.0))
		var w := 3.0 if sniper_aim < 0.25 else 1.5
		var aim_col := Color("ff4d6a") if sniper_aim < 0.25 else Color(1.0, 0.3, 0.4, a)
		draw_line(Vector2.ZERO, locked_dir.rotated(-rotation) * 900.0, aim_col, w)

	var col := Color.WHITE if hit_flash > 0.0 else color
	var pts := PackedVector2Array()
	match kind:
		"drone", "mini":
			pts = PackedVector2Array([Vector2(radius, 0), Vector2(0, -radius * 0.75), Vector2(-radius, 0), Vector2(0, radius * 0.75)])
		"kamikaze":
			pts = PackedVector2Array([Vector2(radius * 1.2, 0), Vector2(-radius, -radius * 0.8), Vector2(-radius * 0.45, 0), Vector2(-radius, radius * 0.8)])
		"shooter":
			pts = PackedVector2Array([Vector2(radius, 0), Vector2(-radius * 0.6, -radius), Vector2(-radius, -radius * 0.4), Vector2(-radius, radius * 0.4), Vector2(-radius * 0.6, radius)])
		"tank":
			for i in 6:
				var a := i * TAU / 6.0
				pts.append(Vector2(cos(a), sin(a)) * radius)
		"splitter":
			for i in 8:
				var a := i * TAU / 8.0
				var r := radius if i % 2 == 0 else radius * 0.65
				pts.append(Vector2(cos(a), sin(a)) * r)
		"sniper":
			pts = PackedVector2Array([Vector2(radius * 1.3, 0), Vector2(-radius * 0.8, -radius * 0.7), Vector2(-radius * 0.5, 0), Vector2(-radius * 0.8, radius * 0.7)])

	draw_colored_polygon(pts, Color(col, 0.28))
	pts.append(pts[0])
	draw_polyline(pts, col, 2.2)
	draw_circle(Vector2.ZERO, radius * 0.25, Color.WHITE)

	if hp < max_hp:
		draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
		var w := radius * 1.8
		var r := Rect2(-w * 0.5, -radius - 11.0, w, 4.0)
		draw_rect(r, Color(0, 0, 0, 0.7))
		draw_rect(Rect2(r.position, Vector2(w * clampf(hp / max_hp, 0.0, 1.0), 4.0)), color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
