extends Node2D
## 3 Jefes multifase: Coloso de Hierro (Sector 3), Reina del Enjambre (Sector 6) y Núcleo Omega (Sector 9).

var game: Node2D
var kind := "coloso"
var boss_name := "COLOSO DE HIERRO"
var hp := 1200.0
var max_hp := 1200.0
var radius := 58.0
var color := Color("ff7a3d")
var phase := 1

var t := 0.0
var pattern := 0
var pattern_t := 0.0
var fire_cd := 0.8
var hit_flash := 0.0
var dash_vel := Vector2.ZERO
var laser_angle := 0.0
var laser_charging := 0.0
var laser_active := 0.0
var _reina_spawned := false


func setup(g: Node2D, k: String, scale_mult: float = 1.0) -> void:
	game = g
	kind = k
	boss_name = String(Game.BOSS_NAMES.get(k, "JEFE"))
	var hp_m := float(Game.difficulty().hp) * scale_mult
	match kind:
		"coloso":
			max_hp = 1350.0 * hp_m
			radius = 56.0
			color = Color("ff7a3d")
		"reina":
			max_hp = 1950.0 * hp_m
			radius = 60.0
			color = Color("7dff6b")
		"omega":
			max_hp = 2700.0 * hp_m
			radius = 66.0
			color = Color("ff4df0")
	hp = max_hp


func step(delta: float) -> bool:
	if hp <= 0.0:
		return false
	t += delta
	pattern_t += delta
	if hit_flash > 0.0:
		hit_flash = maxf(0.0, hit_flash - delta)

	if phase == 1 and hp <= max_hp * 0.5:
		phase = 2
		Sfx.play("boss_warn")
		Game.haptic(60)
		game.add_shake(12.0)
		game.fx.add_ring(position, color, 220.0, 0.55, 6.0)
		game.fx.add_text(position + Vector2(0, -radius - 20), "¡FASE 2 ACTIVADA!", color, 24)

	var p: Node2D = game.player
	if not is_instance_valid(p):
		return true

	var to_p := p.position - position
	var dir := to_p.normalized()
	var dmg_m := float(Game.difficulty().dmg)
	var rate_m := 1.35 if phase == 2 else 1.0

	if pattern_t >= 5.5:
		pattern_t = 0.0
		pattern = (pattern + 1) % 3
		_reina_spawned = false
		laser_charging = 0.0
		laser_active = 0.0
		if kind == "omega" and pattern == 2:
			laser_charging = 1.2
			laser_angle = dir.angle()
			Sfx.play("charge")

	match kind:
		"coloso":
			_step_coloso(delta, dir, dmg_m, rate_m)
		"reina":
			_step_reina(delta, dir, dmg_m, rate_m)
		"omega":
			_step_omega(delta, dir, dmg_m, rate_m)

	var bounds: Rect2 = game.arena.grow(-radius - 10.0)
	position.x = clampf(position.x, bounds.position.x, bounds.end.x)
	position.y = clampf(position.y, bounds.position.y, bounds.end.y)

	if position.distance_to(p.position) <= radius + p.radius:
		p.take_damage(26.0 * dmg_m, self)

	queue_redraw()
	return hp > 0.0


func _step_coloso(delta: float, dir: Vector2, dmg_m: float, rate_m: float) -> void:
	if pattern == 0:
		# Avance con doble ametralladora pesada
		position += dir * 105.0 * rate_m * delta
		fire_cd -= delta * rate_m
		if fire_cd <= 0.0:
			fire_cd = 0.22
			Sfx.play("enemy_shoot", -5.0)
			for side in [-1.0, 1.0]:
				var offset: Vector2 = dir.orthogonal() * float(side) * 28.0
				var bdir: Vector2 = dir.rotated(sin(t * 5.0) * 0.22)
				game.spawn_bullet(position + offset, bdir * 450.0, 16.0 * dmg_m, color, 6.5, 2.8, true)
	elif pattern == 1:
		# Anillos de metralla radial
		position += dir * 65.0 * delta
		fire_cd -= delta * rate_m
		if fire_cd <= 0.0:
			fire_cd = 0.95
			Sfx.play("shotgun", -3.0)
			var n := 14 if phase == 1 else 18
			for i in n:
				var a := t + i * TAU / float(n)
				var bdir := Vector2(cos(a), sin(a))
				game.spawn_bullet(position + bdir * 38.0, bdir * 360.0, 18.0 * dmg_m, Color("ffd24d"), 7.0, 3.2, true)
	else:
		# Embestida con ondas de choque
		fire_cd -= delta * rate_m
		if fire_cd <= 0.0:
			fire_cd = 1.4
			dash_vel = dir * 560.0
			Sfx.play("rocket", -2.0)
			game.fx.add_ring(position, color, 110.0, 0.3, 4.0)
		position += dash_vel * delta
		dash_vel = dash_vel.move_toward(Vector2.ZERO, 650.0 * delta)


func _step_reina(delta: float, dir: Vector2, dmg_m: float, rate_m: float) -> void:
	var orbit := dir.orthogonal() * sin(t * 2.0) * 0.7
	position += (dir * 0.65 + orbit).normalized() * 145.0 * rate_m * delta
	if pattern == 0:
		# Espiral bio-plasma + invocación de crías
		fire_cd -= delta * rate_m
		if fire_cd <= 0.0:
			fire_cd = 0.16
			Sfx.play("enemy_shoot", -6.0)
			for k in 3:
				var a := t * 3.8 + k * TAU / 3.0
				var bdir := Vector2(cos(a), sin(a))
				game.spawn_bullet(position + bdir * 35.0, bdir * 380.0, 15.0 * dmg_m, color, 6.0, 3.0, true)
		if not _reina_spawned and pattern_t >= 1.5 and game.enemies.size() < 14:
			_reina_spawned = true
			for i in (2 if phase == 1 else 3):
				var off := Vector2.RIGHT.rotated(randf() * TAU) * 85.0
				game.spawn_enemy("mini" if i % 2 == 0 else "kamikaze", position + off)
	elif pattern == 1:
		# Abanico ácido dirigido
		fire_cd -= delta * rate_m
		if fire_cd <= 0.0:
			fire_cd = 0.65
			Sfx.play("plasma", -4.0)
			for i in range(-3, 4):
				var bdir := dir.rotated(i * 0.16)
				game.spawn_bullet(position + bdir * 35.0, bdir * 470.0, 17.0 * dmg_m, Color("c46bff"), 7.0, 2.6, true)
	else:
		# Enjambre circular
		fire_cd -= delta * rate_m
		if fire_cd <= 0.0:
			fire_cd = 1.15
			Sfx.play("wave", -4.0)
			for i in 12:
				var a := i * TAU / 12.0 + t
				var bdir := Vector2(cos(a), sin(a))
				game.spawn_bullet(position + bdir * 35.0, bdir * 340.0, 16.0 * dmg_m, Color("ffd24d"), 6.5, 3.0, true)


func _step_omega(delta: float, dir: Vector2, dmg_m: float, rate_m: float) -> void:
	if pattern == 0:
		# Doble hélice + lanzas dirigidas
		position += dir * 95.0 * delta
		fire_cd -= delta * rate_m
		if fire_cd <= 0.0:
			fire_cd = 0.14
			Sfx.play("enemy_shoot", -6.0)
			for k in 4:
				var a := t * 4.2 + k * PI * 0.5
				var bdir := Vector2(cos(a), sin(a))
				game.spawn_bullet(position + bdir * 40.0, bdir * 420.0, 17.0 * dmg_m, color, 6.5, 3.2, true)
	elif pattern == 1:
		# Pulsos concéntricos + ráfaga al jugador
		var center: Vector2 = game.arena.get_center()
		position = position.move_toward(center, 180.0 * delta)
		fire_cd -= delta * rate_m
		if fire_cd <= 0.0:
			fire_cd = 0.7
			Sfx.play("plasma", -4.0)
			for i in 16:
				var a := i * TAU / 16.0 + pattern_t
				var bdir := Vector2(cos(a), sin(a))
				game.spawn_bullet(position + bdir * 44.0, bdir * 390.0, 18.0 * dmg_m, Color("4df0ff"), 7.0, 3.4, true)
			for s in [-0.12, 0.0, 0.12]:
				var sdir := dir.rotated(s)
				game.spawn_bullet(position + sdir * 44.0, sdir * 620.0, 20.0 * dmg_m, Color("ffd24d"), 6.0, 2.4, true)
	else:
		# Rayo Omega giratorio
		if laser_charging > 0.0:
			laser_charging -= delta
			laser_angle = lerp_angle(laser_angle, dir.angle(), 2.5 * delta)
			if laser_charging <= 0.0:
				laser_active = 2.6
				Sfx.play("rail")
				game.add_shake(10.0)
		elif laser_active > 0.0:
			laser_active -= delta
			laser_angle += (1.15 if phase == 1 else 1.55) * delta
			var beam_dir := Vector2.RIGHT.rotated(laser_angle)
			var p: Node2D = game.player
			if is_instance_valid(p):
				var rel := p.position - position
				var proj := rel.dot(beam_dir)
				if proj > 0.0 and proj < 1100.0:
					var perp := absf(rel.cross(beam_dir))
					if perp <= p.radius + 16.0:
						p.take_damage(28.0 * dmg_m, self)


func take_damage(amount: float, is_crit: bool = false) -> void:
	if hp <= 0.0:
		return
	hp -= amount
	hit_flash = 0.08
	Sfx.play("hit", -6.0)
	if Game.settings.damage_numbers:
		var col := Color("ffd24d") if is_crit else Color.WHITE
		game.fx.add_text(position + Vector2(randf_range(-24, 24), -radius), "%d" % int(round(amount)), col, 19 if is_crit else 15)
	if hp <= 0.0:
		game.on_boss_killed(self)


func _draw() -> void:
	# Rayo Omega
	if kind == "omega" and pattern == 2:
		var bdir := Vector2.RIGHT.rotated(laser_angle)
		if laser_charging > 0.0:
			draw_line(Vector2.ZERO, bdir * 1100.0, Color(1.0, 0.3, 0.9, 0.55), 3.0)
		elif laser_active > 0.0:
			draw_line(Vector2.ZERO, bdir * 1100.0, Color(color, 0.35), 34.0)
			draw_line(Vector2.ZERO, bdir * 1100.0, color, 16.0)
			draw_line(Vector2.ZERO, bdir * 1100.0, Color.WHITE, 6.0)

	var col := Color.WHITE if hit_flash > 0.0 else color
	draw_circle(Vector2.ZERO, radius * 1.35, Color(col, 0.12))

	# Anillo exterior giratorio
	var sides := 8 if kind == "coloso" else (10 if kind == "reina" else 12)
	var outer := PackedVector2Array()
	for i in sides:
		var a := t * 0.9 + i * TAU / float(sides)
		var r := radius if i % 2 == 0 else radius * (0.85 if kind == "coloso" else 0.72)
		outer.append(Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(outer, Color(col, 0.26))
	outer.append(outer[0])
	draw_polyline(outer, col, 3.2)

	# Anillo interior contra-rotatorio
	var inner := PackedVector2Array()
	for i in 6:
		var a := -t * 1.6 + i * TAU / 6.0
		inner.append(Vector2(cos(a), sin(a)) * radius * 0.52)
	draw_colored_polygon(inner, Color(col, 0.45))
	inner.append(inner[0])
	draw_polyline(inner, Color.WHITE, 2.0)

	draw_circle(Vector2.ZERO, radius * 0.22, Color.WHITE)
	if phase == 2:
		draw_arc(Vector2.ZERO, radius * 1.15, 0.0, TAU, 40, Color("ff4d6a"), 2.5)
