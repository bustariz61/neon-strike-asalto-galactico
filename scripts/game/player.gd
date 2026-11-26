extends Node2D
## Nave del jugador: movimiento ágil, apuntado PC/Móvil con auto-apuntado inteligente,
## 6 armas, dash cuántico, escudo regenerable, bombas EMP y cartas tácticas.

var game: Node2D
var radius := 18.0
var hp := 100.0
var max_hp := 100.0
var shield := 0.0
var max_shield := 0.0
var shield_delay := 0.0
var base_speed := 365.0
var bombs := 2

var weapon_idx := 0
var ammo := {}
var temp_weapons: Array = []

var fire_cd := 0.0
var dash_cd := 0.0
var dash_max_cd := 1.35
var dash_time := 0.0
var dash_dir := Vector2.ZERO
var invuln_time := 0.0
var hit_flash := 0.0

var vel := Vector2.ZERO
var aim_angle := 0.0
var trail: Array = []
var t := 0.0
var _ghost_cd := 0.0
var auto_target: Node2D = null

var timers := {"rapid": 0.0, "damage": 0.0, "speed": 0.0, "invuln": 0.0}
var mods := {
	"dmg": 1.0,
	"rate": 1.0,
	"multishot": 0,
	"pierce": 0,
	"speed": 1.0,
	"crit": 0.05,
	"vamp": 0.0,
	"magnet": 1.0,
	"dashdmg": 0,
	"bulletspeed": 1.0,
	"thorns": 0.0,
	"cooldown": 1.0,
}


func setup(g: Node2D) -> void:
	game = g
	max_hp = 100.0 + Game.upg("hp") * 20.0
	hp = max_hp
	max_shield = Game.upg("shield") * 15.0
	shield = max_shield
	var mobile_boost := 1.08 if Game.is_mobile() else 1.0
	base_speed = 365.0 * mobile_boost * (1.0 + Game.upg("speed") * 0.06)
	bombs = 2 + Game.upg("bomb")
	dash_max_cd = 1.35 * pow(0.88, Game.upg("dash"))
	for w in Game.WEAPONS:
		ammo[w.id] = int(w.ammo)


func has_weapon(idx: int) -> bool:
	if idx < 0 or idx >= Game.WEAPONS.size():
		return false
	return Game.weapon_unlocked(idx) or temp_weapons.has(String(Game.WEAPONS[idx].id))


func get_unlocked_weapon_count() -> int:
	var n := 0
	for i in Game.WEAPONS.size():
		if has_weapon(i):
			n += 1
	return n


func get_magnet_radius() -> float:
	var base := 185.0 if Game.is_mobile() else 165.0
	return base * (1.0 + Game.upg("magnet") * 0.35) * float(mods.magnet)


func step(delta: float) -> void:
	t += delta
	for k in timers.keys():
		if timers[k] > 0.0:
			timers[k] = maxf(0.0, float(timers[k]) - delta)

	if fire_cd > 0.0:
		fire_cd -= delta
	if dash_cd > 0.0:
		dash_cd = maxf(0.0, dash_cd - delta)
	if invuln_time > 0.0:
		invuln_time = maxf(0.0, invuln_time - delta)
	if hit_flash > 0.0:
		hit_flash = maxf(0.0, hit_flash - delta)

	# Regeneración de escudo
	if max_shield > 0.0 and shield < max_shield:
		if shield_delay > 0.0:
			shield_delay -= delta
		else:
			shield = minf(max_shield, shield + (12.0 + max_shield * 0.22) * delta)

	var using_touch: bool = game != null and is_instance_valid(game.touch_controls) and game.touch_controls.visible

	# Entrada de movimiento (teclado/mando + controles táctiles Android)
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if using_touch and game.touch_controls.move_vec.length_squared() > 0.005:
		input_dir = game.touch_controls.move_vec
	var spd := base_speed * float(mods.speed) * (1.35 if timers.speed > 0.0 else 1.0)

	if Input.is_action_just_pressed("dash") and dash_cd <= 0.0 and dash_time <= 0.0:
		_start_dash(input_dir)

	if dash_time > 0.0:
		dash_time -= delta
		vel = dash_dir * spd * 2.8
		_ghost_cd -= delta
		if _ghost_cd <= 0.0:
			_ghost_cd = 0.028
			game.fx.add_ghost(position, aim_angle, Color("4df0ff"))
	else:
		var accel := 20.0 if using_touch else 17.0
		vel = vel.lerp(input_dir * spd, clampf(accel * delta, 0.0, 1.0))

	position += vel * delta
	var bounds: Rect2 = game.arena.grow(-24.0)
	position.x = clampf(position.x, bounds.position.x, bounds.end.x)
	position.y = clampf(position.y, bounds.position.y, bounds.end.y)

	trail.push_front(position)
	if trail.size() > 14:
		trail.pop_back()

	# Apuntado y disparo (aislando ratón en móvil para evitar que el toque emule clic izquierdo)
	var want_shoot := false
	auto_target = null

	if using_touch:
		var tc: Control = game.touch_controls
		if tc.is_shooting:
			want_shoot = true
			if tc.aim_vec.length_squared() > 0.04:
				var desired_ang: float = tc.aim_vec.angle()
				if bool(Game.settings.get("auto_aim", true)):
					var assist := _find_aim_assist_target(desired_ang, 760.0, 0.24)
					if assist:
						auto_target = assist
						desired_ang = lerp_angle(desired_ang, (assist.position - position).angle(), 0.55)
				aim_angle = lerp_angle(aim_angle, desired_ang, clampf(26.0 * delta, 0.0, 1.0))
		elif tc.auto_fire_enabled:
			var target: Node2D = game.find_nearest_hostile(position, 720.0)
			if is_instance_valid(target):
				auto_target = target
				var target_ang := (target.position - position).angle()
				aim_angle = lerp_angle(aim_angle, target_ang, clampf(18.0 * delta, 0.0, 1.0))
				want_shoot = true
			elif input_dir.length_squared() > 0.04:
				aim_angle = lerp_angle(aim_angle, input_dir.angle(), clampf(12.0 * delta, 0.0, 1.0))
		elif input_dir.length_squared() > 0.04:
			aim_angle = lerp_angle(aim_angle, input_dir.angle(), clampf(12.0 * delta, 0.0, 1.0))

		# Compatibilidad con mando Bluetooth en Android (sin leer ratón emulado)
		var joy_aim := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
		if joy_aim.length() > 0.25:
			aim_angle = joy_aim.angle()
		if Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.35:
			want_shoot = true
	else:
		var mpos := get_global_mouse_position()
		if mpos.distance_squared_to(position) > 4.0:
			aim_angle = (mpos - position).angle()
		want_shoot = Input.is_action_pressed("shoot")

	# Cambio de armas
	for i in Game.WEAPONS.size():
		if Input.is_action_just_pressed("weapon_%d" % (i + 1)):
			_select_weapon(i)
	if Input.is_action_just_pressed("next_weapon"):
		_cycle_weapon(1)
	if Input.is_action_just_pressed("prev_weapon"):
		_cycle_weapon(-1)

	# Disparo y bomba EMP
	if want_shoot and fire_cd <= 0.0:
		_shoot()
	if Input.is_action_just_pressed("bomb"):
		_use_bomb()

	queue_redraw()


func _find_aim_assist_target(aim_ang: float, max_dist: float, max_angle_diff: float) -> Node2D:
	var best: Node2D = null
	var best_score := 999999.0
	for e in game.enemies:
		if not is_instance_valid(e) or e.hp <= 0.0:
			continue
		var d := position.distance_to(e.position)
		if d > max_dist:
			continue
		var diff := absf(angle_difference(aim_ang, (e.position - position).angle()))
		if diff <= max_angle_diff:
			var sc := diff * 600.0 + d * 0.35
			if sc < best_score:
				best_score = sc
				best = e
	if is_instance_valid(game.boss) and game.boss.hp > 0.0:
		var d := position.distance_to(game.boss.position)
		if d <= max_dist + 80.0:
			var diff := absf(angle_difference(aim_ang, (game.boss.position - position).angle()))
			if diff <= max_angle_diff + 0.06:
				var sc := diff * 500.0 + d * 0.25
				if sc < best_score:
					best = game.boss
	return best


func select_weapon(idx: int) -> void:
	_select_weapon(idx)


func cycle_weapon(step_dir: int) -> void:
	_cycle_weapon(step_dir)


func _select_weapon(idx: int) -> void:
	if not has_weapon(idx):
		return
	var wid := String(Game.WEAPONS[idx].id)
	if int(ammo.get(wid, 0)) == 0:
		game.fx.add_text(position + Vector2(0, -28), "SIN MUNICIÓN", Color("ff4d6a"), 16)
		Sfx.play("hit")
		return
	if weapon_idx != idx:
		weapon_idx = idx
		Sfx.play("click")
		Game.haptic(12)


func _cycle_weapon(step_dir: int) -> void:
	var n := Game.WEAPONS.size()
	for k in range(1, n + 1):
		var idx := (weapon_idx + step_dir * k + n * 4) % n
		if has_weapon(idx):
			var wid := String(Game.WEAPONS[idx].id)
			if int(ammo.get(wid, 0)) != 0:
				if weapon_idx != idx:
					weapon_idx = idx
					Sfx.play("click")
					Game.haptic(12)
				return


func _start_dash(input_dir: Vector2) -> void:
	dash_dir = input_dir.normalized() if input_dir.length_squared() > 0.05 else Vector2.RIGHT.rotated(aim_angle)
	dash_time = 0.18
	_ghost_cd = 0.0
	dash_cd = dash_max_cd * maxf(0.3, float(mods.cooldown))
	invuln_time = maxf(invuln_time, 0.26)
	Sfx.play("dash")
	Game.haptic(18)
	game.add_shake(2.5)
	game.fx.add_ring(position, Color("4df0ff"), 58.0, 0.25, 3.0)
	game.fx.add_burst(position, Color("4df0ff"), 10, 210.0, 3.0, 0.26)
	var dash_lvl := int(mods.dashdmg)
	if dash_lvl > 0:
		var dmg := (55.0 + 35.0 * float(dash_lvl - 1)) * _damage_mult()
		var rad := 125.0 + 18.0 * float(dash_lvl - 1)
		game.damage_area(position, rad, dmg, Color("4df0ff"))


func _damage_mult() -> float:
	var m := (1.0 + Game.upg("dmg") * 0.10) * float(mods.dmg)
	if timers.damage > 0.0:
		m *= 2.0
	return m


func _rate_mult() -> float:
	var m := (1.0 + Game.upg("rate") * 0.08) * float(mods.rate)
	if timers.rapid > 0.0:
		m *= 1.65
	return m


func _shoot() -> void:
	var w: Dictionary = Game.WEAPONS[weapon_idx]
	var wid := String(w.id)
	if int(w.ammo) > 0:
		if int(ammo.get(wid, 0)) <= 0:
			weapon_idx = 0
			game.fx.add_text(position + Vector2(0, -28), "¡SIN MUNICIÓN!", Color("ff4d6a"), 18)
			return
		ammo[wid] = int(ammo[wid]) - 1

	fire_cd = maxf(0.03, float(w.rate) / _rate_mult())
	Sfx.play(String(w.sound))

	var base_dmg := float(w.dmg) * _damage_mult()
	var is_crit := randf() < clampf(float(mods.crit), 0.0, 1.0)
	if is_crit:
		base_dmg *= 2.0

	var count := int(w.count) + int(mods.multishot)
	var spread := float(w.spread)
	if int(mods.multishot) > 0 and spread < 0.14:
		spread = 0.14

	var muzzle := position + Vector2.RIGHT.rotated(aim_angle) * 22.0
	game.fx.add_burst(muzzle, w.color, 4, 140.0, 2.8, 0.18)

	if bool(w.get("rail", false)):
		for i in count:
			var ang := aim_angle + (0.0 if count == 1 else lerpf(-0.08, 0.08, float(i) / float(count - 1)))
			game.fire_railgun(muzzle, ang, base_dmg, w.color, is_crit)
		game.add_shake(6.0)
		Game.haptic(22)
		if int(w.ammo) > 0 and int(ammo[wid]) <= 0:
			weapon_idx = 0
			game.fx.add_text(position + Vector2(0, -30), "RAILGUN AGOTADO", Color("ffd24d"), 16)
		return

	for i in count:
		var ang := aim_angle
		if count > 1:
			ang += lerpf(-spread * 0.5, spread * 0.5, float(i) / float(count - 1)) + randf_range(-0.02, 0.02)
		else:
			ang += randf_range(-spread, spread)
		var spd := float(w.speed) * float(mods.bulletspeed)
		game.spawn_bullet(
			muzzle,
			Vector2.RIGHT.rotated(ang) * spd,
			base_dmg,
			w.color,
			float(w.size),
			float(w.life),
			false,
			int(w.pierce) + int(mods.pierce),
			float(w.get("explosive", 0.0)),
			float(w.get("homing", 0.0)),
			is_crit
		)

	if wid == "shotgun" or wid == "rocket":
		game.add_shake(4.0)
		Game.haptic(14)

	if int(w.ammo) > 0 and int(ammo[wid]) <= 0:
		weapon_idx = 0
		game.fx.add_text(position + Vector2(0, -30), "%s SIN MUNICIÓN" % String(w.name).to_upper(), Color("ffd24d"), 16)


func _use_bomb() -> void:
	if bombs <= 0:
		game.fx.add_text(position + Vector2(0, -28), "SIN BOMBAS EMP", Color("ff4d6a"), 16)
		return
	bombs -= 1
	invuln_time = maxf(invuln_time, 1.2)
	Game.haptic(75)
	game.trigger_emp_bomb(position)


func refill_ammo(ratio: float = 0.45) -> void:
	for w in Game.WEAPONS:
		var max_a := int(w.ammo)
		if max_a > 0:
			var cur := int(ammo.get(w.id, 0))
			ammo[w.id] = mini(max_a, cur + maxi(1, int(ceil(max_a * ratio))))


func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)


func on_kill() -> void:
	if float(mods.vamp) > 0.0:
		heal(float(mods.vamp))


func take_damage(amount: float, source_enemy: Node2D = null) -> void:
	if invuln_time > 0.0 or dash_time > 0.0 or timers.invuln > 0.0:
		return
	if float(mods.thorns) > 0.0 and is_instance_valid(source_enemy) and source_enemy.has_method("take_damage"):
		source_enemy.take_damage(float(mods.thorns), false)

	shield_delay = 3.5
	var rem := amount
	if shield > 0.0:
		var absorbed := minf(shield, rem)
		shield -= absorbed
		rem -= absorbed
		game.fx.add_ring(position, Color("4d8bff"), 40.0, 0.22, 3.0)

	if rem > 0.0:
		hp -= rem
		game.took_damage_this_sector = true

	invuln_time = 0.55
	hit_flash = 0.22
	Sfx.play("player_hit")
	Game.haptic(40)
	game.add_shake(10.0)
	game.reset_combo()
	game.fx.add_burst(position, Color("ff4d6a"), 14, 240.0, 3.5, 0.4)
	if Game.settings.damage_numbers:
		game.fx.add_text(position + Vector2(0, -20), "-%d" % int(round(amount)), Color("ff4d6a"), 20)

	if hp <= 0.0:
		hp = 0.0
		game.on_player_died()


func apply_card(id: String) -> void:
	match id:
		"dmg":
			mods.dmg = float(mods.dmg) * 1.2
		"rate":
			mods.rate = float(mods.rate) * 1.15
		"multishot":
			mods.multishot = int(mods.multishot) + 1
		"pierce":
			mods.pierce = int(mods.pierce) + 1
		"maxhp":
			max_hp += 25.0
			hp = minf(max_hp, hp + 25.0)
		"heal":
			hp = max_hp
			shield = max_shield
		"speed":
			mods.speed = float(mods.speed) * 1.1
		"shield":
			max_shield += 25.0
			shield += 25.0
		"crit":
			mods.crit = minf(1.0, float(mods.crit) + 0.10)
		"vamp":
			mods.vamp = float(mods.vamp) + 2.0
		"bomb":
			bombs += 1
		"magnet":
			mods.magnet = float(mods.magnet) * 1.5
		"dashdmg":
			mods.dashdmg = int(mods.dashdmg) + 1
		"bulletspeed":
			mods.bulletspeed = float(mods.bulletspeed) * 1.2
		"thorns":
			mods.thorns = float(mods.thorns) + 30.0
		"cooldown":
			mods.cooldown = maxf(0.3, float(mods.cooldown) * 0.75)


func _draw() -> void:
	# Estela de propulsión
	var trail_col := Color(0.45, 0.96, 1.0) if dash_time > 0.0 or timers.speed > 0.0 else Color(0.3, 0.94, 1.0)
	for i in range(1, trail.size()):
		var k := 1.0 - float(i) / float(trail.size())
		var p_local: Vector2 = trail[i] - position
		draw_circle(p_local, (8.5 if dash_time > 0.0 else 7.0) * k, Color(trail_col, 0.28 * k))

	# Mira láser sutil y retícula de objetivo fijado en móvil
	if game and is_instance_valid(game.touch_controls) and game.touch_controls.visible:
		var aim_dir := Vector2.RIGHT.rotated(aim_angle)
		var sight_len := 135.0
		if is_instance_valid(auto_target):
			var rel: Vector2 = auto_target.position - position
			sight_len = minf(rel.length(), 420.0)
			var tr := float(auto_target.radius) + 9.0 + 2.0 * sin(t * 10.0)
			var lcol := Color(Game.WEAPONS[weapon_idx].color, 0.72)
			draw_arc(rel, tr, t * 2.5, t * 2.5 + PI * 0.4, 8, lcol, 2.2)
			draw_arc(rel, tr, t * 2.5 + PI * 0.5, t * 2.5 + PI * 0.9, 8, lcol, 2.2)
			draw_arc(rel, tr, t * 2.5 + PI, t * 2.5 + PI * 1.4, 8, lcol, 2.2)
			draw_arc(rel, tr, t * 2.5 + PI * 1.5, t * 2.5 + PI * 1.9, 8, lcol, 2.2)
		draw_line(aim_dir * 26.0, aim_dir * sight_len, Color(Game.WEAPONS[weapon_idx].color, 0.16), 1.5)

	# Indicador de recarga del dash bajo la nave
	if dash_cd > 0.0:
		var ratio := 1.0 - clampf(dash_cd / maxf(0.1, dash_max_cd * float(mods.cooldown)), 0.0, 1.0)
		draw_arc(Vector2.ZERO, 26.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 24, Color("4df0ff"), 2.0)

	# Escudo o invencibilidad activa
	if timers.invuln > 0.0:
		draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 32, Color(1.0, 0.85, 0.3, 0.75 + 0.2 * sin(t * 14.0)), 3.0)
	elif shield > 0.0:
		var sa := clampf(shield / maxf(1.0, max_shield), 0.2, 1.0)
		draw_arc(Vector2.ZERO, 25.0, 0.0, TAU, 32, Color(0.3, 0.65, 1.0, 0.45 * sa), 2.5)

	if invuln_time > 0.0 and int(invuln_time * 24.0) % 2 == 0:
		return

	var col: Color = Game.WEAPONS[weapon_idx].color
	if hit_flash > 0.0:
		col = Color.WHITE

	draw_set_transform(Vector2.ZERO, aim_angle, Vector2.ONE)
	# Llama del motor (más intensa en Dash o Hipervelocidad)
	var boost_flame := 1.6 if (dash_time > 0.0 or timers.speed > 0.0) else (1.15 if vel.length() > 140.0 else 0.75)
	var flame := (10.0 + 5.0 * sin(t * 28.0)) * boost_flame
	var flame_col := Color("4df0ff") if (dash_time > 0.0 or timers.speed > 0.0) else Color("ff9b3d")
	draw_colored_polygon(PackedVector2Array([Vector2(-12, -5), Vector2(-12 - flame, 0), Vector2(-12, 5)]), flame_col)

	# Alas y fuselaje neón
	var hull := PackedVector2Array([Vector2(22, 0), Vector2(-15, -16), Vector2(-9, 0), Vector2(-15, 16)])
	draw_colored_polygon(hull, Color(col, 0.28))
	var outline := PackedVector2Array([Vector2(22, 0), Vector2(-15, -16), Vector2(-9, 0), Vector2(-15, 16), Vector2(22, 0)])
	draw_polyline(outline, col, 2.4)
	draw_circle(Vector2(3, 0), 4.5, Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
