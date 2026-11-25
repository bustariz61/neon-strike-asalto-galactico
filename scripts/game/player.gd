extends Node2D
## Nave del jugador: movimiento, apuntado, 6 armas, dash cuántico, escudo, bombas EMP y mejoras.

var game: Node2D
var radius := 18.0
var hp := 100.0
var max_hp := 100.0
var shield := 0.0
var max_shield := 0.0
var shield_delay := 0.0
var base_speed := 360.0
var bombs := 2

var weapon_idx := 0
var ammo := {}
var temp_weapons: Array = []

var fire_cd := 0.0
var dash_cd := 0.0
var dash_max_cd := 1.4
var dash_time := 0.0
var dash_dir := Vector2.ZERO
var invuln_time := 0.0
var hit_flash := 0.0

var vel := Vector2.ZERO
var aim_angle := 0.0
var trail: Array = []
var t := 0.0

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
	"dashdmg": false,
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
	base_speed = 365.0 * (1.0 + Game.upg("speed") * 0.06)
	bombs = 2 + Game.upg("bomb")
	dash_max_cd = 1.35 * pow(0.88, Game.upg("dash"))
	for w in Game.WEAPONS:
		ammo[w.id] = int(w.ammo)


func has_weapon(idx: int) -> bool:
	if idx < 0 or idx >= Game.WEAPONS.size():
		return false
	return Game.weapon_unlocked(idx) or temp_weapons.has(String(Game.WEAPONS[idx].id))


func get_magnet_radius() -> float:
	return 165.0 * (1.0 + Game.upg("magnet") * 0.35) * float(mods.magnet)


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

	# Entrada de movimiento (teclado/mando + controles táctiles Android)
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if game and is_instance_valid(game.touch_controls) and game.touch_controls.move_vec.length_squared() > 0.01:
		input_dir = game.touch_controls.move_vec
	var spd := base_speed * float(mods.speed) * (1.35 if timers.speed > 0.0 else 1.0)

	if Input.is_action_just_pressed("dash") and dash_cd <= 0.0 and dash_time <= 0.0:
		_start_dash(input_dir)

	if dash_time > 0.0:
		dash_time -= delta
		vel = dash_dir * spd * 2.75
		if int(dash_time * 60.0) % 2 == 0:
			game.fx.add_ghost(position, aim_angle, Color("4df0ff"))
	else:
		vel = vel.lerp(input_dir * spd, clampf(16.0 * delta, 0.0, 1.0))

	position += vel * delta
	var bounds: Rect2 = game.arena.grow(-24.0)
	position.x = clampf(position.x, bounds.position.x, bounds.end.x)
	position.y = clampf(position.y, bounds.position.y, bounds.end.y)

	trail.push_front(position)
	if trail.size() > 12:
		trail.pop_back()

	# Apuntado hacia el ratón o joystick táctil derecho
	if game and is_instance_valid(game.touch_controls) and game.touch_controls.is_shooting:
		if game.touch_controls.aim_vec.length_squared() > 0.04:
			aim_angle = game.touch_controls.aim_vec.angle()
	else:
		var mpos := get_global_mouse_position()
		if mpos.distance_squared_to(position) > 4.0:
			aim_angle = (mpos - position).angle()

	# Cambio de armas
	for i in Game.WEAPONS.size():
		if Input.is_action_just_pressed("weapon_%d" % (i + 1)):
			_select_weapon(i)
	if Input.is_action_just_pressed("next_weapon"):
		_cycle_weapon(1)
	if Input.is_action_just_pressed("prev_weapon"):
		_cycle_weapon(-1)

	# Disparo y bomba EMP
	var touch_shooting: bool = game != null and is_instance_valid(game.touch_controls) and game.touch_controls.is_shooting
	if (Input.is_action_pressed("shoot") or touch_shooting) and fire_cd <= 0.0:
		_shoot()
	if Input.is_action_just_pressed("bomb"):
		_use_bomb()

	queue_redraw()


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


func _cycle_weapon(step_dir: int) -> void:
	var n := Game.WEAPONS.size()
	for k in range(1, n + 1):
		var idx := (weapon_idx + step_dir * k + n * 4) % n
		if has_weapon(idx):
			var wid := String(Game.WEAPONS[idx].id)
			if int(ammo.get(wid, 0)) != 0:
				weapon_idx = idx
				Sfx.play("click")
				return


func _start_dash(input_dir: Vector2) -> void:
	dash_dir = input_dir.normalized() if input_dir.length_squared() > 0.05 else Vector2.RIGHT.rotated(aim_angle)
	dash_time = 0.18
	dash_cd = dash_max_cd * float(mods.cooldown)
	invuln_time = maxf(invuln_time, 0.24)
	Sfx.play("dash")
	game.fx.add_ring(position, Color("4df0ff"), 55.0, 0.25, 3.0)
	if bool(mods.dashdmg):
		game.damage_area(position, 125.0, 55.0 * _damage_mult(), Color("4df0ff"))


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

	fire_cd = float(w.rate) / _rate_mult()
	Sfx.play(String(w.sound))

	var base_dmg := float(w.dmg) * _damage_mult()
	var is_crit := randf() < float(mods.crit)
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

	if int(w.ammo) > 0 and int(ammo[wid]) <= 0:
		weapon_idx = 0
		game.fx.add_text(position + Vector2(0, -30), "%s SIN MUNICIÓN" % String(w.name).to_upper(), Color("ffd24d"), 16)


func _use_bomb() -> void:
	if bombs <= 0:
		game.fx.add_text(position + Vector2(0, -28), "SIN BOMBAS EMP", Color("ff4d6a"), 16)
		return
	bombs -= 1
	invuln_time = maxf(invuln_time, 1.2)
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
			mods.crit = float(mods.crit) + 0.10
		"vamp":
			mods.vamp = float(mods.vamp) + 2.0
		"bomb":
			bombs += 1
		"magnet":
			mods.magnet = float(mods.magnet) * 1.5
		"dashdmg":
			mods.dashdmg = true
		"bulletspeed":
			mods.bulletspeed = float(mods.bulletspeed) * 1.2
		"thorns":
			mods.thorns = float(mods.thorns) + 30.0
		"cooldown":
			mods.cooldown = float(mods.cooldown) * 0.75


func _draw() -> void:
	# Estela de propulsión
	for i in range(1, trail.size()):
		var k := 1.0 - float(i) / float(trail.size())
		var p_local: Vector2 = trail[i] - position
		draw_circle(p_local, 7.0 * k, Color(0.3, 0.94, 1.0, 0.25 * k))

	# Indicador de recarga del dash bajo la nave
	if dash_cd > 0.0:
		var ratio := 1.0 - clampf(dash_cd / (dash_max_cd * float(mods.cooldown)), 0.0, 1.0)
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
	# Llama del motor
	var flame := 10.0 + 5.0 * sin(t * 28.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-12, -5), Vector2(-12 - flame, 0), Vector2(-12, 5)]), Color("ff9b3d"))

	# Alas y fuselaje neón
	var hull := PackedVector2Array([Vector2(22, 0), Vector2(-15, -16), Vector2(-9, 0), Vector2(-15, 16)])
	draw_colored_polygon(hull, Color(col, 0.28))
	var outline := PackedVector2Array([Vector2(22, 0), Vector2(-15, -16), Vector2(-9, 0), Vector2(-15, 16), Vector2(22, 0)])
	draw_polyline(outline, col, 2.4)
	draw_circle(Vector2(3, 0), 4.5, Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
