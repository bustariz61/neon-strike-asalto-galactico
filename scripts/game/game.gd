extends Node2D
## Controlador principal de partida: Campaña por sectores y Supervivencia por rondas,
## oleadas dinámicas, colisiones, cartas tácticas roguelite, HUD adaptativo PC/Móvil,
## indicadores de amenaza fuera de pantalla, radar, pausa, victoria y derrota.

const UI = preload("res://scripts/ui.gd")
const Background = preload("res://scripts/background.gd")
const OptionsPanel = preload("res://scripts/options_panel.gd")
const PlayerScript = preload("res://scripts/game/player.gd")
const BulletScript = preload("res://scripts/game/bullet.gd")
const EnemyScript = preload("res://scripts/game/enemy.gd")
const BossScript = preload("res://scripts/game/boss.gd")
const PickupScript = preload("res://scripts/game/pickup.gd")
const FXScript = preload("res://scripts/game/fx.gd")
const TouchControlsScript = preload("res://scripts/game/touch_controls.gd")

var arena := Rect2(0, 0, 2200, 1400)
var theme_color := Color("4df0ff")

var cam: Camera2D
var bg: Node2D
var player: Node2D
var fx: Node2D
var touch_controls: Control
var bullet_root: Node2D
var enemy_root: Node2D
var pickup_root: Node2D

var bullets: Array = []
var enemies: Array = []
var pickups: Array = []
var portals: Array = []
var boss: Node2D = null

var score := 0
var credits_earned := 0
var kills := 0
var combo := 1
var combo_timer := 0.0
var shake := 0.0
var match_ended := false
var choosing_card := false
var took_damage_this_sector := false

var wave := 0
var max_waves := 4
var wave_pause := 0.0
var wave_active := false
var spawn_queue: Array = []
var spawn_cd := 0.0
var wave_total_enemies := 1
var wave_killed_enemies := 0
var boss_spawned := false
var _card_offered_for_wave := false
var _survival_recorded := false

var _base_zoom := 1.0
var _zoom_punch := 0.0
var _hitstop_end_msec := 0
var _low_hp_t := 0.0
var _banner_tween: Tween
var _flash_tween: Tween
var _hp_bar_w := 258.0
var _boss_bar_w := 440.0
var _combo_bar_w := 220.0

# HUD
var hud_layer: CanvasLayer
var hp_bar: ColorRect
var hp_lbl: Label
var sh_bar: ColorRect
var sh_lbl: Label
var bomb_lbl: Label
var dash_lbl: Label
var power_lbl: Label
var sector_lbl: Label
var wave_lbl: Label
var boss_box: Control
var boss_name_lbl: Label
var boss_bar: ColorRect
var score_lbl: Label
var combo_lbl: Label
var combo_bar: ColorRect
var credits_lbl: Label
var fps_lbl: Label
var banner_lbl: Label
var hotbar_btns: Array = []
var radar_ctrl: Control
var indicator_ctrl: Control
var vignette_ctrl: Control
var pause_btn: Button
var mobile_wep_dock: Control
var mobile_wep_btn: Button
var mobile_auto_btn: Button
var flash_rect: ColorRect
var overlay_root: CenterContainer


func _ready() -> void:
	Game.data.stats.games = int(Game.data.stats.games) + 1
	if Game.mode == "campaign":
		var lvl: Dictionary = Game.LEVELS[Game.current_level]
		theme_color = lvl.color
		max_waves = int(lvl.waves)
	else:
		theme_color = Color("ff4df0")
		max_waves = 9999

	Sfx.play_music("battle")

	bg = Background.new()
	bg.menu_mode = false
	bg.area = arena
	bg.theme_color = theme_color
	add_child(bg)

	pickup_root = Node2D.new()
	add_child(pickup_root)
	enemy_root = Node2D.new()
	add_child(enemy_root)
	bullet_root = Node2D.new()
	add_child(bullet_root)

	player = PlayerScript.new()
	player.position = arena.get_center()
	player.setup(self)
	add_child(player)

	fx = FXScript.new()
	fx.z_index = 10
	add_child(fx)

	_base_zoom = 0.84 if Game.is_mobile() else 1.0
	cam = Camera2D.new()
	cam.position = player.position
	cam.zoom = Vector2(_base_zoom, _base_zoom)
	add_child(cam)
	cam.make_current()

	_build_hud()

	if Game.mode == "campaign":
		var lvl: Dictionary = Game.LEVELS[Game.current_level]
		_show_banner("SECTOR 0%d: %s" % [Game.current_level + 1, String(lvl.name).to_upper()], theme_color)
	else:
		_show_banner("MODO SUPERVIVENCIA — ¡RESISTE!", theme_color)

	wave_pause = 1.1


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if not match_ended and not choosing_card:
			_toggle_pause()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		if not match_ended and not choosing_card and not get_tree().paused:
			_toggle_pause()


func trigger_hitstop(duration_ms: int) -> void:
	if get_tree().paused or match_ended:
		return
	Engine.time_scale = 0.25
	_hitstop_end_msec = maxi(_hitstop_end_msec, Time.get_ticks_msec() + duration_ms)


func _process(delta: float) -> void:
	if _hitstop_end_msec > 0 and (get_tree().paused or Time.get_ticks_msec() >= _hitstop_end_msec):
		_hitstop_end_msec = 0
		Engine.time_scale = 1.0

	if fps_lbl:
		fps_lbl.visible = bool(Game.settings.show_fps)
		if fps_lbl.visible:
			fps_lbl.text = "%d FPS" % Engine.get_frames_per_second()

	if get_tree().paused or match_ended:
		return

	_low_hp_t += delta
	Game.data.stats.playtime = float(Game.data.stats.playtime) + delta

	if combo > 1:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo = 1
			combo_timer = 0.0

	if is_instance_valid(player):
		player.step(delta)

	_step_portals(delta)
	_step_spawner(delta)
	_step_bullets(delta)
	_step_enemies(delta)
	_step_pickups(delta)
	_step_camera(delta)
	_update_hud()
	if radar_ctrl:
		radar_ctrl.queue_redraw()
	if indicator_ctrl:
		indicator_ctrl.queue_redraw()
	if vignette_ctrl:
		vignette_ctrl.queue_redraw()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not match_ended and not choosing_card:
		get_viewport().set_input_as_handled()
		_toggle_pause()


# ---------------------------------------------------------------- Gestión de oleadas
func _step_spawner(delta: float) -> void:
	if not spawn_queue.is_empty():
		spawn_cd -= delta
		if spawn_cd <= 0.0 and enemies.size() + portals.size() < 26:
			var next_kind: String = spawn_queue.pop_front()
			_queue_portal(next_kind)
			spawn_cd = randf_range(0.18, 0.44)
		return

	if not portals.is_empty() or not enemies.is_empty() or is_instance_valid(boss):
		return

	if wave_pause > 0.0:
		wave_pause -= delta
		if wave_pause > 0.0:
			return

	# Comprobar si toca jefe o victoria en campaña
	if Game.mode == "campaign":
		var lvl: Dictionary = Game.LEVELS[Game.current_level]
		if wave >= max_waves:
			if String(lvl.boss) != "" and not boss_spawned:
				_spawn_boss(String(lvl.boss), 1.0)
				return
			_on_campaign_victory()
			return

	# Ofrecer carta táctica entre oleadas/rondas
	if wave > 0 and (Game.mode == "survival" or wave % 2 == 0):
		if not _card_offered_for_wave:
			_card_offered_for_wave = true
			_open_card_selection()
			return

	_start_next_wave()


func _start_next_wave() -> void:
	_card_offered_for_wave = false
	wave_active = true
	wave += 1
	Sfx.play("wave")

	if Game.mode == "survival":
		if wave > int(Game.data.stats.best_round):
			Game.data.stats.best_round = wave
		if wave >= 10:
			Game.unlock_achievement("survivor10")
		if wave >= 25:
			Game.unlock_achievement("survivor25")
		if wave % 3 == 0:
			spawn_pickup(player.position + Vector2(0, -90), "ammo")

		if wave % 5 == 0:
			var bosses := ["coloso", "reina", "omega"]
			var bkind: String = bosses[((wave / 5) - 1) % bosses.size()]
			var bscale := 1.0 + (wave - 5) * 0.14
			_spawn_boss(bkind, bscale)
			return

	var pool: Array
	var budget: float
	if Game.mode == "campaign":
		var lvl: Dictionary = Game.LEVELS[Game.current_level]
		pool = lvl.pool
		budget = float(lvl.budget) + (wave - 1) * float(lvl.growth)
		_show_banner("OLEADA %d / %d" % [wave, max_waves], theme_color)
	else:
		pool = ["drone", "shooter"]
		if wave >= 2:
			pool.append("kamikaze")
		if wave >= 3:
			pool.append("tank")
		if wave >= 4:
			pool.append("splitter")
		if wave >= 6:
			pool.append("sniper")
		budget = 8.0 + wave * 3.8
		_show_banner("RONDA %d" % wave, theme_color)

	spawn_queue.clear()
	while budget > 0.0:
		var k: String = pool[randi() % pool.size()]
		spawn_queue.append(k)
		budget -= float(Game.ENEMY_COST.get(k, 1.5))

	wave_total_enemies = maxi(1, spawn_queue.size())
	wave_killed_enemies = 0
	spawn_cd = 0.2


func _queue_portal(kind: String) -> void:
	var pos := arena.get_center()
	var margin := arena.grow(-90.0)
	var found := false
	# Priorizar aparición dinámica cerca del rango táctico del jugador (acción continua)
	if is_instance_valid(player):
		for attempt in 10:
			var ang := randf() * TAU
			var dist := randf_range(340.0, 760.0)
			var candidate := player.position + Vector2(cos(ang), sin(ang)) * dist
			if margin.has_point(candidate):
				pos = candidate
				found = true
				break
	if not found:
		for attempt in 12:
			var candidate := Vector2(
				randf_range(margin.position.x, margin.end.x),
				randf_range(margin.position.y, margin.end.y)
			)
			if not is_instance_valid(player) or candidate.distance_to(player.position) > 290.0:
				pos = candidate
				break
	portals.append({"p": pos, "k": kind, "t": 0.68, "m": 0.68})


func _step_portals(delta: float) -> void:
	for pt in portals:
		pt.t -= delta
		if pt.t <= 0.0:
			var sc := 1.0 if Game.mode == "campaign" else (1.0 + (wave - 1) * 0.09)
			spawn_enemy(String(pt.k), pt.p, sc)
	portals = portals.filter(func(pt): return pt.t > 0.0)


func spawn_enemy(kind: String, pos: Vector2, scale_mult: float = 1.0) -> Node2D:
	var e := EnemyScript.new()
	e.position = pos
	e.setup(self, kind, scale_mult)
	enemy_root.add_child(e)
	enemies.append(e)
	fx.add_ring(pos, e.color, 36.0, 0.25, 2.5)
	return e


func _spawn_boss(kind: String, scale_mult: float) -> void:
	boss_spawned = true
	wave_active = true
	Sfx.play("boss_warn")
	Sfx.play_music("boss")
	Game.haptic(65)
	_zoom_punch = -0.05

	var center := arena.get_center()
	var anchors := [
		center + Vector2(0, -300),
		center + Vector2(0, 300),
		center + Vector2(-420, 0),
		center + Vector2(420, 0),
	]
	var best_pos: Vector2 = anchors[0]
	if is_instance_valid(player):
		var best_d := -1.0
		for a in anchors:
			var d := (a as Vector2).distance_to(player.position)
			if d > best_d:
				best_d = d
				best_pos = a

	var b := BossScript.new()
	b.position = best_pos
	b.setup(self, kind, scale_mult)
	enemy_root.add_child(b)
	boss = b
	fx.add_ring(b.position, b.color, 180.0, 0.6, 5.0)
	add_shake(12.0)
	_show_banner("¡ALERTA: %s!" % b.boss_name, b.color)


# ---------------------------------------------------------------- Proyectiles y colisiones
func spawn_bullet(pos: Vector2, vel: Vector2, dmg: float, color: Color, radius: float, life: float, is_enemy: bool, pierce: int = 0, explosive: float = 0.0, homing: float = 0.0, crit: bool = false) -> void:
	var b := BulletScript.new()
	b.game = self
	b.position = pos
	b.prev_pos = pos
	b.vel = vel
	b.dmg = dmg
	b.color = color
	b.radius = radius
	b.life = life
	b.is_enemy = is_enemy
	b.pierce = pierce
	b.explosive = explosive
	b.homing = homing
	b.crit = crit
	bullet_root.add_child(b)
	bullets.append(b)


func fire_railgun(origin: Vector2, angle: float, dmg: float, color: Color, is_crit: bool) -> void:
	var dir := Vector2.RIGHT.rotated(angle)
	var end_pt := origin + dir * 1350.0
	fx.add_beam(origin, end_pt, color, 11.0, 0.3)
	for e in enemies.duplicate():
		if is_instance_valid(e) and _segment_circle(origin, end_pt, e.position, e.radius + 10.0):
			e.take_damage(dmg, is_crit, dir * 180.0)
			fx.add_burst(e.position, color, 10, 220.0, 3.5, 0.35)
	if is_instance_valid(boss) and _segment_circle(origin, end_pt, boss.position, boss.radius + 12.0):
		boss.take_damage(dmg, is_crit)
		fx.add_burst(boss.position, color, 14, 240.0, 4.0, 0.35)


func _segment_circle(a: Vector2, b: Vector2, c: Vector2, r: float) -> bool:
	var ab := b - a
	var t := clampf((c - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	var closest := a + ab * t
	return closest.distance_squared_to(c) <= r * r


func _step_bullets(delta: float) -> void:
	var alive: Array = []
	for b in bullets:
		if not is_instance_valid(b):
			continue
		if not b.step(delta):
			b.queue_free()
			continue

		var remove := false
		if b.is_enemy:
			if is_instance_valid(player) and _segment_circle(b.prev_pos, b.position, player.position, player.radius + b.radius * 0.7):
				player.take_damage(b.dmg)
				remove = true
		else:
			for e in enemies.duplicate():
				if not is_instance_valid(e) or e.hp <= 0.0 or b.hit_list.has(e):
					continue
				if _segment_circle(b.prev_pos, b.position, e.position, e.radius + b.radius):
					b.hit_list.append(e)
					if b.explosive > 0.0:
						damage_area(b.position, b.explosive, b.dmg, b.color, b.crit)
						remove = true
						break
					else:
						var imp: Vector2 = b.vel.normalized() * clampf(b.dmg * 4.2, 42.0, 200.0)
						e.take_damage(b.dmg, b.crit, imp)
						fx.add_burst(b.position, b.color, 6, 170.0, 2.8, 0.22)
						if b.pierce > 0:
							b.pierce -= 1
						else:
							remove = true
							break

			if not remove and is_instance_valid(boss) and boss.hp > 0.0 and not b.hit_list.has(boss):
				if _segment_circle(b.prev_pos, b.position, boss.position, boss.radius + b.radius):
					b.hit_list.append(boss)
					if b.explosive > 0.0:
						damage_area(b.position, b.explosive, b.dmg, b.color, b.crit)
						remove = true
					else:
						boss.take_damage(b.dmg, b.crit)
						fx.add_burst(b.position, b.color, 7, 180.0, 3.0, 0.25)
						if b.pierce > 0:
							b.pierce -= 1
						else:
							remove = true

		if remove:
			b.queue_free()
		else:
			alive.append(b)
	bullets = alive


func damage_area(pos: Vector2, rad: float, dmg: float, color: Color, is_crit: bool = false) -> void:
	Sfx.play("explosion")
	add_shake(7.0)
	fx.add_ring(pos, color, rad, 0.35, 4.5)
	fx.add_burst(pos, color, 22, 320.0, 4.2, 0.5)
	for e in enemies.duplicate():
		if is_instance_valid(e) and e.position.distance_to(pos) <= rad + e.radius:
			var push: Vector2 = (e.position - pos).normalized() * 220.0
			e.take_damage(dmg, is_crit, push)
	if is_instance_valid(boss) and boss.position.distance_to(pos) <= rad + boss.radius:
		boss.take_damage(dmg, is_crit)


func trigger_emp_bomb(pos: Vector2) -> void:
	Sfx.play("bomb")
	add_shake(18.0)
	_zoom_punch = -0.06
	trigger_hitstop(50)
	_flash_screen(Color(0.3, 0.94, 1.0, 0.45))
	fx.add_ring(pos, Color("4df0ff"), 850.0, 0.65, 8.0)
	fx.add_ring(pos, Color("ff4df0"), 600.0, 0.5, 5.0)
	for b in bullets:
		if is_instance_valid(b) and b.is_enemy:
			fx.add_burst(b.position, b.color, 4, 120.0, 2.5, 0.25)
			b.queue_free()
	bullets = bullets.filter(func(b): return is_instance_valid(b) and not b.is_enemy)

	for e in enemies.duplicate():
		if is_instance_valid(e):
			e.take_damage(220.0, true, (e.position - pos).normalized() * 260.0)
	if is_instance_valid(boss):
		boss.take_damage(260.0, true)


func find_nearest_hostile(pos: Vector2, max_dist: float) -> Node2D:
	var best: Node2D = null
	var best_d := max_dist
	for e in enemies:
		if is_instance_valid(e) and e.hp > 0.0:
			var d := pos.distance_to(e.position)
			if d < best_d:
				best_d = d
				best = e
	if is_instance_valid(boss) and boss.hp > 0.0:
		var d := pos.distance_to(boss.position)
		if d < best_d:
			best = boss
	return best


func pull_all_credits() -> void:
	for pk in pickups:
		if is_instance_valid(pk) and pk.kind == "credit":
			pk.force_pull = true


# ---------------------------------------------------------------- Enemigos, bajas y botín
func _step_enemies(delta: float) -> void:
	var alive: Array = []
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if e.step(delta):
			alive.append(e)
		else:
			e.queue_free()
	enemies = alive

	if is_instance_valid(boss):
		if not boss.step(delta):
			boss.queue_free()
			boss = null

	if wave_active and spawn_queue.is_empty() and portals.is_empty() and enemies.is_empty() and not is_instance_valid(boss):
		wave_active = false
		Sfx.play("wave_clear")
		pull_all_credits()
		if Game.mode == "campaign" and boss_spawned:
			_show_banner("¡JEFE DERROTADO!", Color("ffd24d"))
			wave_pause = maxf(wave_pause, 2.2)
		elif Game.mode == "survival":
			_show_banner("¡RONDA %d SUPERADA!" % wave, Color("4dff88"))
			wave_pause = 0.95
		else:
			_show_banner("¡OLEADA %d COMPLETADA!" % wave, Color("4dff88"))
			wave_pause = 0.95


func on_enemy_killed(e: Node2D) -> void:
	Sfx.play("explosion", -4.0)
	fx.add_burst(e.position, e.color, 18, 280.0, 3.8, 0.5)
	fx.add_ring(e.position, e.color, e.radius * 2.2, 0.28, 3.0)
	add_shake(3.0)

	kills += 1
	wave_killed_enemies += 1
	Game.data.stats.kills = int(Game.data.stats.kills) + 1
	if int(Game.data.stats.kills) >= 1:
		Game.unlock_achievement("first_blood")
	if int(Game.data.stats.kills) >= 1000:
		Game.unlock_achievement("exterminator")

	if is_instance_valid(player):
		player.on_kill()

	var prev_combo := combo
	combo = mini(8, combo + 1)
	combo_timer = 4.2
	if prev_combo < 4 and combo >= 4 and is_instance_valid(player):
		fx.add_text(player.position + Vector2(0, -34), "¡RACHA x4!", Color("ffd24d"), 20)
	elif prev_combo < 8 and combo >= 8 and is_instance_valid(player):
		fx.add_text(player.position + Vector2(0, -36), "¡IMPARABLE x8!", Color("ff4df0"), 22)
	if combo >= 8:
		Game.unlock_achievement("combo")

	var d := Game.difficulty()
	var pts := int(round(float(e.score_val) * combo * float(d.score)))
	score += pts

	if e.kind == "splitter":
		for i in 2:
			var off := Vector2(randf_range(-24, 24), randf_range(-24, 24))
			spawn_enemy("mini", e.position + off)
			wave_total_enemies += 1

	# Botín (con bonificación por multiplicador de combo)
	if randf() < 0.72:
		var combo_cr := 1.0 + float(combo - 1) * 0.08
		var cr := int(round(float(e.credit_val) * float(d.credits) * combo_cr))
		spawn_pickup(e.position, "credit", cr)
	var roll := randf()
	if roll < 0.07:
		spawn_pickup(e.position + Vector2(12, 0), "hp")
	elif roll < 0.14:
		spawn_pickup(e.position + Vector2(12, 0), "ammo")
	elif roll < 0.18:
		spawn_pickup(e.position + Vector2(12, 0), "power")
	elif roll < 0.195:
		spawn_pickup(e.position + Vector2(12, 0), "bomb")


func on_boss_killed(b: Node2D) -> void:
	Sfx.play("big_explosion")
	Sfx.play_music("battle")
	Game.haptic(90)
	add_shake(22.0)
	_zoom_punch = -0.07
	trigger_hitstop(65)
	_flash_screen(Color(1, 1, 1, 0.55))
	fx.add_ring(b.position, b.color, 360.0, 0.8, 8.0)
	fx.add_burst(b.position, b.color, 65, 460.0, 5.5, 0.95)

	Game.data.stats.bosses = int(Game.data.stats.bosses) + 1
	if b.kind == "coloso":
		Game.unlock_achievement("boss1")
	elif b.kind == "reina":
		Game.unlock_achievement("boss2")
	elif b.kind == "omega":
		Game.unlock_achievement("boss3")

	var d := Game.difficulty()
	score += int(round(2500.0 * float(d.score)))
	for i in 12:
		var off := Vector2.RIGHT.rotated(i * TAU / 12.0) * randf_range(25.0, 85.0)
		spawn_pickup(b.position + off, "credit", int(round(35.0 * float(d.credits))))
	spawn_pickup(b.position, "hp")
	spawn_pickup(b.position + Vector2(30, 0), "ammo")
	pull_all_credits()
	wave_pause = 2.4


func spawn_pickup(pos: Vector2, kind: String, val: int = 15) -> void:
	var pk := PickupScript.new()
	pk.game = self
	pk.position = pos
	pk.kind = kind
	pk.value = val
	if kind == "power":
		var types := ["rapid", "damage", "shield", "speed", "invuln"]
		pk.subkind = types[randi() % types.size()]
	pickup_root.add_child(pk)
	pickups.append(pk)


func _step_pickups(delta: float) -> void:
	var alive: Array = []
	for pk in pickups:
		if not is_instance_valid(pk):
			continue
		if pk.step(delta):
			alive.append(pk)
		else:
			pk.queue_free()
	pickups = alive


func collect_pickup(pk: Node2D) -> void:
	match pk.kind:
		"credit":
			Sfx.play("coin")
			credits_earned += pk.value
			Game.add_credits(pk.value)
			fx.add_text(pk.position, "+%d CR" % pk.value, Color("ffd24d"), 16)
		"hp":
			Sfx.play("pickup")
			player.heal(30.0)
			fx.add_text(pk.position, "+30 VIDA", Color("4dff88"), 18)
		"ammo":
			Sfx.play("pickup")
			if Game.mode == "survival" and player.temp_weapons.size() < Game.WEAPONS.size() - 1:
				for w in Game.WEAPONS:
					if not Game.data.weapons.has(w.id) and not player.temp_weapons.has(w.id):
						player.temp_weapons.append(w.id)
						fx.add_text(pk.position + Vector2(0, -22), "¡ARMA: %s!" % String(w.name).to_upper(), w.color, 20)
						break
			player.refill_ammo(0.45)
			fx.add_text(pk.position, "+MUNICIÓN", Color("4df0ff"), 18)
		"bomb":
			Sfx.play("powerup")
			player.bombs += 1
			fx.add_text(pk.position, "+1 BOMBA EMP", Color("ff4df0"), 19)
		"power":
			Sfx.play("powerup")
			var sk: String = pk.subkind
			if sk == "shield":
				player.max_shield = maxf(player.max_shield, 50.0)
				player.shield = minf(player.max_shield, player.shield + 50.0)
			else:
				player.timers[sk] = 10.0
			var p_title := String(Game.POWER_NAMES.get(sk, "POTENCIADOR"))
			fx.add_text(pk.position, p_title, Color("ff9b3d"), 20)


func reset_combo() -> void:
	combo = 1
	combo_timer = 0.0


# ---------------------------------------------------------------- Cámara y efectos
func add_shake(amount: float) -> void:
	if bool(Game.settings.shake):
		shake = minf(26.0, shake + amount)


func _step_camera(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var look := Vector2.ZERO
	if is_instance_valid(touch_controls) and touch_controls.visible:
		# Cámara dinámica en móvil: adelanta según dirección de apuntado y velocidad (nunca hacia el pulgar)
		look = Vector2.RIGHT.rotated(player.aim_angle) * 58.0 + player.vel * 0.16
		if look.length() > 115.0:
			look = look.normalized() * 115.0
	else:
		look = (get_global_mouse_position() - player.position) * 0.12
		if look.length() > 95.0:
			look = look.normalized() * 95.0

	var target := player.position + look
	cam.position = cam.position.lerp(target, clampf(10.0 * delta, 0.0, 1.0))

	_zoom_punch = lerpf(_zoom_punch, 0.0, clampf(6.5 * delta, 0.0, 1.0))
	var z := clampf(_base_zoom + _zoom_punch, 0.65, 1.2)
	cam.zoom = Vector2(z, z)

	if shake > 0.0:
		cam.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
		shake = maxf(0.0, shake - 42.0 * delta)
	else:
		cam.offset = Vector2.ZERO


func _flash_screen(col: Color) -> void:
	if not flash_rect:
		return
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	flash_rect.color = col
	_flash_tween = create_tween()
	_flash_tween.tween_property(flash_rect, "color:a", 0.0, 0.35)


func _draw() -> void:
	# Portales de aparición de enemigos
	for pt in portals:
		var k := 1.0 - clampf(float(pt.t) / float(pt.m), 0.0, 1.0)
		var r := lerpf(34.0, 14.0, k)
		draw_arc(pt.p, r, k * TAU, k * TAU + PI * 1.5, 24, Color(theme_color, 0.8), 3.0)
		draw_circle(pt.p, 6.0 * k, Color(1, 1, 1, 0.7))


# ---------------------------------------------------------------- HUD adaptativo PC / Móvil
func _make_glass_panel(min_size: Vector2, border: Color, margin: int = 8, bg_alpha: float = 0.58) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.04, 0.11, bg_alpha)
	sb.border_color = Color(border, 0.65)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(margin)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _make_compact_btn(text: String, cb: Callable, w: float, h: float, border: Color = Color("4df0ff"), font_size: int = 14) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, h)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = Color(0.03, 0.06, 0.14, 0.68)
	sb_n.border_color = Color(border, 0.75)
	sb_n.set_border_width_all(2)
	sb_n.set_corner_radius_all(8)
	sb_n.set_content_margin_all(4)
	var sb_p := sb_n.duplicate()
	sb_p.bg_color = Color(border.r * 0.35, border.g * 0.35, border.b * 0.35, 0.9)
	sb_p.border_color = Color.WHITE
	b.add_theme_stylebox_override("normal", sb_n)
	b.add_theme_stylebox_override("hover", sb_n)
	b.add_theme_stylebox_override("pressed", sb_p)
	b.pressed.connect(func():
		cb.call()
	)
	return b


func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)

	# Controles táctiles debajo del HUD interactivo y de los overlays
	touch_controls = TouchControlsScript.new()
	touch_controls.game = self
	hud_layer.add_child(touch_controls)

	# Viñeta pulsante de vida baja
	vignette_ctrl = Control.new()
	vignette_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette_ctrl.draw.connect(_draw_low_hp_vignette)
	hud_layer.add_child(vignette_ctrl)

	# Indicadores de amenazas / jefes / rezagados fuera de pantalla
	indicator_ctrl = Control.new()
	indicator_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	indicator_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indicator_ctrl.draw.connect(_draw_offscreen_indicators)
	hud_layer.add_child(indicator_ctrl)

	flash_rect = ColorRect.new()
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(flash_rect)

	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(root)

	if Game.is_mobile():
		_build_mobile_hud(root)
	else:
		_build_desktop_hud(root)

	# Centro: Banner de anuncios (sin bloquear la visión de la nave)
	banner_lbl = UI.title("", 34 if Game.is_mobile() else 42, theme_color)
	banner_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	banner_lbl.offset_left = -450
	banner_lbl.offset_right = 450
	banner_lbl.offset_top = -195 if Game.is_mobile() else -170
	banner_lbl.offset_bottom = -130 if Game.is_mobile() else -100
	banner_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_lbl.modulate.a = 0.0
	root.add_child(banner_lbl)

	# Contenedor para cartas tácticas, pausa, victoria y derrota
	overlay_root = CenterContainer.new()
	overlay_root.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(overlay_root)


func _build_mobile_hud(root: Control) -> void:
	var ins := Game.get_safe_insets()
	var sl := float(ins.left) + 12.0
	var sr := float(ins.right) + 12.0
	var st := float(ins.top) + 8.0
	var sb := float(ins.bottom) + 8.0

	_hp_bar_w = 184.0
	_boss_bar_w = 340.0
	_combo_bar_w = 132.0

	# --- Superior izquierda: Barras compactas y translúcidas de Vida y Escudo ---
	var tl := _make_glass_panel(Vector2(202, 0), Color("4df0ff"), 7, 0.56)
	tl.position = Vector2(sl, st)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tl)
	var tlv := UI.vbox(4)
	tlv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl.add_child(tlv)

	var hp_info := _make_bar(Color("4dff88"), "VIDA 100/100", _hp_bar_w, 16.0, 12)
	hp_bar = hp_info.fill
	hp_lbl = hp_info.label
	tlv.add_child(hp_info.box)

	var sh_info := _make_bar(Color("4d8bff"), "ESCUDO 0/0", _hp_bar_w, 13.0, 11)
	sh_bar = sh_info.fill
	sh_lbl = sh_info.label
	tlv.add_child(sh_info.box)

	power_lbl = UI.label("", 12, Color("ffd24d"), HORIZONTAL_ALIGNMENT_LEFT)
	power_lbl.visible = false
	tlv.add_child(power_lbl)

	# --- Superior centro: Texto flotante limpio (sin caja opaca) + barra de jefe ---
	var tc := UI.vbox(3)
	tc.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	tc.offset_left = sl + 216.0
	tc.offset_right = -(sr + 224.0)
	tc.offset_top = st
	tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tc)

	sector_lbl = UI.title("", 18, theme_color)
	sector_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tc.add_child(sector_lbl)
	wave_lbl = UI.label("", 13, Color(0.88, 0.96, 1.0))
	wave_lbl.add_theme_constant_override("outline_size", 3)
	wave_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.06, 0.9))
	wave_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tc.add_child(wave_lbl)

	var boss_wrap := CenterContainer.new()
	boss_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tc.add_child(boss_wrap)
	boss_box = _make_glass_panel(Vector2(360, 0), Color("ff4d6a"), 6, 0.68)
	boss_box.visible = false
	boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bbv := UI.vbox(3)
	bbv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_box.add_child(bbv)
	boss_name_lbl = UI.label("JEFE", 13, Color("ff4d6a"))
	bbv.add_child(boss_name_lbl)
	var b_bar := _make_bar(Color("ff4d6a"), "", _boss_bar_w, 14.0, 11)
	boss_bar = b_bar.fill
	bbv.add_child(b_bar.box)
	boss_wrap.add_child(boss_box)

	# --- Superior derecha: Puntuación compacta + Botón Pausa + Mini-radar arriba (fuera de zona de pulgares) ---
	var tr_col := UI.vbox(6)
	tr_col.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tr_col.offset_left = -(sr + 206.0)
	tr_col.offset_right = -sr
	tr_col.offset_top = st
	tr_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tr_col)

	var top_right_row := UI.hbox(6)
	top_right_row.alignment = BoxContainer.ALIGNMENT_END
	top_right_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr_col.add_child(top_right_row)

	var score_pill := _make_glass_panel(Vector2(148, 0), Color("ffd24d"), 6, 0.56)
	score_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sv := UI.vbox(1)
	sv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_pill.add_child(sv)
	score_lbl = UI.label("0 PTS", 14, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	sv.add_child(score_lbl)
	var sub_row := UI.hbox(8)
	sub_row.alignment = BoxContainer.ALIGNMENT_END
	combo_lbl = UI.label("x1", 13, Color("4df0ff"), HORIZONTAL_ALIGNMENT_RIGHT)
	sub_row.add_child(combo_lbl)
	credits_lbl = UI.label("+0 CR", 13, Color("ffd24d"), HORIZONTAL_ALIGNMENT_RIGHT)
	sub_row.add_child(credits_lbl)
	sv.add_child(sub_row)

	var cb_bg := ColorRect.new()
	cb_bg.custom_minimum_size = Vector2(_combo_bar_w, 3)
	cb_bg.color = Color(0.1, 0.14, 0.24, 0.7)
	cb_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combo_bar = ColorRect.new()
	combo_bar.color = Color("4df0ff")
	combo_bar.size = Vector2(0, 3)
	combo_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cb_bg.add_child(combo_bar)
	sv.add_child(cb_bg)

	fps_lbl = UI.label("60 FPS", 11, Color(0.65, 0.8, 0.9), HORIZONTAL_ALIGNMENT_RIGHT)
	fps_lbl.visible = false
	sv.add_child(fps_lbl)
	top_right_row.add_child(score_pill)

	pause_btn = _make_compact_btn("||", func():
		if not match_ended and not choosing_card:
			Sfx.play("click")
			_toggle_pause()
	, 44, 44, Color("4df0ff"), 16)
	top_right_row.add_child(pause_btn)

	# Mini-radar compacto y translúcido debajo de puntuación/pausa (esquina superior derecha)
	var radar_wrap := UI.hbox(0)
	radar_wrap.alignment = BoxContainer.ALIGNMENT_END
	radar_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr_col.add_child(radar_wrap)
	var radar_panel := _make_glass_panel(Vector2(114, 72), Color("4df0ff"), 4, 0.48)
	radar_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radar_wrap.add_child(radar_panel)
	radar_ctrl = Control.new()
	radar_ctrl.custom_minimum_size = Vector2(104, 62)
	radar_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radar_ctrl.draw.connect(_draw_radar)
	radar_panel.add_child(radar_ctrl)

	# --- Inferior centro: Selector compacto de arma + interruptor AUTO (cero invasión lateral) ---
	var dock_wrap := CenterContainer.new()
	dock_wrap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	dock_wrap.offset_top = -(sb + 48.0)
	dock_wrap.offset_bottom = -sb
	dock_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dock_wrap)

	var dock_panel := _make_glass_panel(Vector2(0, 44), Color("4df0ff"), 4, 0.58)
	mobile_wep_dock = dock_panel
	dock_wrap.add_child(dock_panel)

	var dh := UI.hbox(6)
	dock_panel.add_child(dh)

	var prev_btn := _make_compact_btn("◀", func():
		if is_instance_valid(player):
			player.cycle_weapon(-1)
	, 38, 36, Color("4df0ff"), 14)
	dh.add_child(prev_btn)

	mobile_wep_btn = _make_compact_btn("BLÁSTER · INF", func():
		if is_instance_valid(player):
			player.cycle_weapon(1)
	, 158, 36, Color("4df0ff"), 13)
	dh.add_child(mobile_wep_btn)

	var next_btn := _make_compact_btn("▶", func():
		if is_instance_valid(player):
			player.cycle_weapon(1)
	, 38, 36, Color("4df0ff"), 14)
	dh.add_child(next_btn)

	mobile_auto_btn = _make_compact_btn("AUTO", func():
		if is_instance_valid(touch_controls):
			touch_controls.toggle_auto_fire()
	, 66, 36, Color("4dff88"), 12)
	dh.add_child(mobile_auto_btn)

	# Registrar controles del HUD para que tocarlos nunca active los joysticks
	touch_controls.blocked_controls = [pause_btn, mobile_wep_dock]


func _build_desktop_hud(root: Control) -> void:
	_hp_bar_w = 258.0
	_boss_bar_w = 440.0
	_combo_bar_w = 220.0

	# Esquina superior izquierda: Vida, Escudo, Bombas, Dash
	var tl := UI.panel(Vector2(290, 0), Color("4df0ff"), 12)
	tl.position = Vector2(16, 14)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tl)
	var tlv := UI.vbox(6)
	tlv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl.add_child(tlv)

	var hp_info := _make_bar(Color("4dff88"), "VIDA 100/100", _hp_bar_w)
	hp_bar = hp_info.fill
	hp_lbl = hp_info.label
	tlv.add_child(hp_info.box)

	var sh_info := _make_bar(Color("4d8bff"), "ESCUDO 0/0", _hp_bar_w)
	sh_bar = sh_info.fill
	sh_lbl = sh_info.label
	tlv.add_child(sh_info.box)

	var status_row := UI.hbox(14)
	bomb_lbl = UI.label("BOMBAS: 2", 16, Color("ff4df0"), HORIZONTAL_ALIGNMENT_LEFT)
	bomb_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(bomb_lbl)
	dash_lbl = UI.label("DASH: LISTO", 16, Color("4df0ff"), HORIZONTAL_ALIGNMENT_RIGHT)
	status_row.add_child(dash_lbl)
	tlv.add_child(status_row)

	power_lbl = UI.label("", 15, Color("ffd24d"), HORIZONTAL_ALIGNMENT_LEFT)
	tlv.add_child(power_lbl)

	# Parte superior central: Sector / Ronda y barra de jefe
	var tc := UI.vbox(6)
	tc.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	tc.offset_left = 340
	tc.offset_right = -340
	tc.offset_top = 14
	tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tc)

	sector_lbl = UI.title("", 24, theme_color)
	tc.add_child(sector_lbl)
	wave_lbl = UI.label("", 17, Color(0.85, 0.95, 1.0))
	tc.add_child(wave_lbl)

	var boss_wrap := CenterContainer.new()
	boss_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tc.add_child(boss_wrap)
	boss_box = UI.panel(Vector2(480, 0), Color("ff4d6a"), 10)
	boss_box.visible = false
	var bbv := UI.vbox(4)
	boss_box.add_child(bbv)
	boss_name_lbl = UI.label("JEFE", 17, Color("ff4d6a"))
	bbv.add_child(boss_name_lbl)
	var b_bar := _make_bar(Color("ff4d6a"), "", _boss_bar_w)
	boss_bar = b_bar.fill
	bbv.add_child(b_bar.box)
	boss_wrap.add_child(boss_box)

	# Esquina superior derecha: Puntuación, Multiplicador, Créditos, FPS + Pausa
	var tr_row := UI.hbox(8)
	tr_row.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tr_row.offset_left = -316
	tr_row.offset_right = -16
	tr_row.offset_top = 14
	tr_row.alignment = BoxContainer.ALIGNMENT_END
	tr_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tr_row)

	var tr := UI.panel(Vector2(246, 0), Color("ffd24d"), 12)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr_row.add_child(tr)
	var trv := UI.vbox(4)
	tr.add_child(trv)
	score_lbl = UI.label("PUNTOS: 0", 20, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	trv.add_child(score_lbl)
	combo_lbl = UI.label("COMBO x1", 18, Color("4df0ff"), HORIZONTAL_ALIGNMENT_RIGHT)
	trv.add_child(combo_lbl)

	var cb_bg := ColorRect.new()
	cb_bg.custom_minimum_size = Vector2(_combo_bar_w, 4)
	cb_bg.color = Color(0.08, 0.12, 0.22, 0.8)
	combo_bar = ColorRect.new()
	combo_bar.color = Color("4df0ff")
	combo_bar.size = Vector2(0, 4)
	cb_bg.add_child(combo_bar)
	trv.add_child(cb_bg)

	credits_lbl = UI.label("CRÉDITOS: +0 CR", 17, Color("ffd24d"), HORIZONTAL_ALIGNMENT_RIGHT)
	trv.add_child(credits_lbl)
	fps_lbl = UI.label("60 FPS", 14, Color(0.65, 0.8, 0.9), HORIZONTAL_ALIGNMENT_RIGHT)
	trv.add_child(fps_lbl)

	pause_btn = _make_compact_btn("||", func():
		if not match_ended and not choosing_card:
			Sfx.play("click")
			_toggle_pause()
	, 40, 40, Color("4df0ff"), 16)
	pause_btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tr_row.add_child(pause_btn)

	# Parte inferior central: Barra de armas 1-6
	var hb_wrap := CenterContainer.new()
	hb_wrap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hb_wrap.offset_top = -74
	hb_wrap.offset_bottom = -12
	hb_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hb_wrap)

	var hb := UI.hbox(8)
	hb_wrap.add_child(hb)
	hotbar_btns.clear()
	for i in Game.WEAPONS.size():
		var b := UI.button("", func():
			if is_instance_valid(player):
				player.select_weapon(i)
		, 132, 50)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 14)
		hb.add_child(b)
		hotbar_btns.append(b)

	# Esquina inferior derecha: Mini-radar táctico
	var radar_panel := UI.panel(Vector2(150, 104), Color("4df0ff"), 6)
	radar_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	radar_panel.offset_left = -166
	radar_panel.offset_right = -16
	radar_panel.offset_top = -120
	radar_panel.offset_bottom = -16
	radar_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(radar_panel)

	radar_ctrl = Control.new()
	radar_ctrl.custom_minimum_size = Vector2(134, 88)
	radar_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radar_ctrl.draw.connect(_draw_radar)
	radar_panel.add_child(radar_ctrl)


func _make_bar(color: Color, txt: String, width: float = 258.0, height: float = 22.0, font_size: int = 14) -> Dictionary:
	var box := Control.new()
	box.custom_minimum_size = Vector2(width, height)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_rect := ColorRect.new()
	bg_rect.color = Color(0.06, 0.08, 0.14, 0.92)
	bg_rect.size = Vector2(width, height)
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bg_rect)
	var fill := ColorRect.new()
	fill.color = color
	fill.size = Vector2(width, height)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(fill)
	var lbl := UI.label(txt, font_size, Color.WHITE)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lbl)
	return {"box": box, "fill": fill, "label": lbl}


func _update_hud() -> void:
	if not is_instance_valid(player):
		return
	var hp_ratio := clampf(player.hp / maxf(1.0, player.max_hp), 0.0, 1.0)
	hp_bar.size.x = _hp_bar_w * hp_ratio
	hp_bar.color = Color("ff4d6a") if hp_ratio < 0.30 else (Color("ffd24d") if hp_ratio < 0.55 else Color("4dff88"))
	hp_lbl.text = "VIDA %d/%d" % [int(ceil(player.hp)), int(player.max_hp)]

	var sh_ratio := clampf(player.shield / maxf(1.0, player.max_shield), 0.0, 1.0) if player.max_shield > 0.0 else 0.0
	sh_bar.size.x = _hp_bar_w * sh_ratio
	sh_lbl.text = "ESCUDO %d/%d" % [int(ceil(player.shield)), int(player.max_shield)]

	if bomb_lbl:
		bomb_lbl.text = "BOMBAS EMP: %d" % player.bombs
	if dash_lbl:
		dash_lbl.text = "DASH: LISTO" if player.dash_cd <= 0.05 else "DASH: %.1fs" % player.dash_cd

	var active_powers: Array = []
	for k in player.timers:
		if float(player.timers[k]) > 0.0:
			active_powers.append("%s (%.0fs)" % [String(Game.POWER_NAMES.get(k, k)), float(player.timers[k])])
	power_lbl.text = "  ".join(active_powers)
	if Game.is_mobile():
		power_lbl.visible = not active_powers.is_empty()

	var has_boss: bool = is_instance_valid(boss) and float(boss.hp) > 0.0
	var hostiles := enemies.size() + portals.size() + spawn_queue.size() + (1 if has_boss else 0)
	if Game.mode == "campaign":
		var lvl: Dictionary = Game.LEVELS[Game.current_level]
		if Game.is_mobile():
			sector_lbl.text = "S0%d · %s" % [Game.current_level + 1, String(lvl.name).to_upper()]
			wave_lbl.text = "¡JEFE EN COMBATE!" if has_boss else "Oleada %d/%d · Hostiles: %d" % [maxi(1, wave), max_waves, hostiles]
		else:
			sector_lbl.text = "SECTOR 0%d: %s" % [Game.current_level + 1, String(lvl.name).to_upper()]
			wave_lbl.text = "¡COMBATE CONTRA JEFE!  —  Hostiles: %d" % hostiles if has_boss else "Oleada %d / %d  —  Hostiles: %d" % [maxi(1, wave), max_waves, hostiles]
	else:
		sector_lbl.text = "RONDA %d" % maxi(1, wave) if Game.is_mobile() else "SUPERVIVENCIA — RONDA %d" % maxi(1, wave)
		wave_lbl.text = "¡JEFE EN COMBATE!" if has_boss else "Hostiles: %d" % hostiles

	if has_boss:
		boss_box.visible = true
		boss_name_lbl.text = "%s — %d / %d" % [boss.boss_name, int(ceil(boss.hp)), int(boss.max_hp)]
		boss_bar.size.x = _boss_bar_w * clampf(boss.hp / maxf(1.0, boss.max_hp), 0.0, 1.0)
	else:
		boss_box.visible = false

	if Game.is_mobile():
		score_lbl.text = "%d PTS" % score
		combo_lbl.text = "x%d" % combo
		credits_lbl.text = "+%d CR" % credits_earned
	else:
		score_lbl.text = "PUNTOS: %d" % score
		combo_lbl.text = "MULTIPLICADOR x%d" % combo
		credits_lbl.text = "CRÉDITOS: +%d CR" % credits_earned

	var combo_col := Color("ff4df0") if combo >= 8 else (Color("ffd24d") if combo >= 4 else Color("4df0ff"))
	combo_lbl.modulate = combo_col
	if combo_bar:
		combo_bar.color = combo_col
		combo_bar.size.x = _combo_bar_w * (clampf(combo_timer / 4.2, 0.0, 1.0) if combo > 1 else 0.0)

	# Actualizar selector de armas (Móvil vs Escritorio)
	if Game.is_mobile() and mobile_wep_btn:
		var w: Dictionary = Game.WEAPONS[player.weapon_idx]
		var am := int(player.ammo.get(w.id, 0))
		var am_txt := "∞" if int(w.ammo) < 0 else str(am)
		var unlocked_cnt: int = player.get_unlocked_weapon_count()
		mobile_wep_btn.text = "%s · %s (%d/%d)" % [String(w.name).substr(0, 9).to_upper(), am_txt, player.weapon_idx + 1, unlocked_cnt]
		mobile_wep_btn.modulate = w.color.lightened(0.25)
		if mobile_auto_btn and is_instance_valid(touch_controls):
			var on: bool = touch_controls.auto_fire_enabled
			mobile_auto_btn.text = "AUTO" if on else "MANUAL"
			mobile_auto_btn.modulate = Color("4dff88") if on else Color(0.65, 0.72, 0.85)
	else:
		for i in hotbar_btns.size():
			var b: Button = hotbar_btns[i]
			var wep: Dictionary = Game.WEAPONS[i]
			var unlocked: bool = player.has_weapon(i)
			var am := int(player.ammo.get(wep.id, 0))
			var am_txt := "INF" if int(wep.ammo) < 0 else str(am)
			b.disabled = not unlocked
			if unlocked:
				b.text = "[%d] %s (%s)" % [i + 1, String(wep.name).substr(0, 9), am_txt]
				b.modulate = wep.color.lightened(0.25) if player.weapon_idx == i else Color(0.8, 0.88, 0.95)
			else:
				b.text = "[%d] BLOQ." % (i + 1)
				b.modulate = Color(0.45, 0.45, 0.5)


func _draw_low_hp_vignette() -> void:
	if not is_instance_valid(player) or float(player.max_hp) <= 0.0:
		return
	var ratio: float = float(player.hp) / maxf(1.0, float(player.max_hp))
	if ratio >= 0.30 or match_ended:
		return
	var sz := vignette_ctrl.size
	var pulse: float = (0.14 + 0.12 * absf(sin(_low_hp_t * 6.5))) * (1.0 - ratio / 0.30)
	var col := Color(1.0, 0.12, 0.25, pulse)
	var t := 22.0
	vignette_ctrl.draw_rect(Rect2(0, 0, sz.x, t), col)
	vignette_ctrl.draw_rect(Rect2(0, sz.y - t, sz.x, t), col)
	vignette_ctrl.draw_rect(Rect2(0, t, t, sz.y - t * 2.0), col)
	vignette_ctrl.draw_rect(Rect2(sz.x - t, t, t, sz.y - t * 2.0), col)


func _draw_offscreen_indicators() -> void:
	if not is_instance_valid(cam) or not is_instance_valid(player):
		return
	var vp := indicator_ctrl.size
	var center_world := cam.get_screen_center_position()
	var z := cam.zoom
	var ins := Game.get_safe_insets()
	var margin_l := float(ins.left) + 28.0
	var margin_r := float(ins.right) + 28.0
	var margin_t := float(ins.top) + 64.0
	var margin_b := float(ins.bottom) + 58.0
	var screen_rect := Rect2(Vector2(margin_l, margin_t), Vector2(vp.x - margin_l - margin_r, vp.y - margin_t - margin_b))

	var targets: Array = []
	if is_instance_valid(boss) and boss.hp > 0.0:
		targets.append({"pos": boss.position, "col": boss.color, "size": 14.0})
	var show_all := enemies.size() <= 5
	for e in enemies:
		if not is_instance_valid(e) or e.hp <= 0.0:
			continue
		if e.kind == "sniper" and e.sniper_aim > 0.0:
			targets.append({"pos": e.position, "col": Color("ff4d6a"), "size": 11.0})
		elif show_all:
			targets.append({"pos": e.position, "col": e.color, "size": 9.0})

	for tg in targets:
		var sp: Vector2 = (Vector2(tg.pos) - center_world) * z + vp * 0.5
		if screen_rect.has_point(sp):
			continue
		var dir := (sp - vp * 0.5).normalized()
		var edge := Vector2(
			clampf(sp.x, screen_rect.position.x, screen_rect.end.x),
			clampf(sp.y, screen_rect.position.y, screen_rect.end.y)
		)
		var sz_t: float = float(tg.size)
		var perp := dir.orthogonal()
		var tip := edge + dir * sz_t
		var b1 := edge - dir * (sz_t * 0.65) + perp * (sz_t * 0.65)
		var b2 := edge - dir * (sz_t * 0.65) - perp * (sz_t * 0.65)
		var col: Color = tg.col
		var alpha := 0.65 + 0.3 * absf(sin(_low_hp_t * 8.0))
		indicator_ctrl.draw_colored_polygon(PackedVector2Array([tip, b1, b2]), Color(col, alpha))


func _draw_radar() -> void:
	var sz := radar_ctrl.size
	radar_ctrl.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.02, 0.04, 0.1, 0.8))
	var scale_v := Vector2(sz.x / arena.size.x, sz.y / arena.size.y)
	for pk in pickups:
		if is_instance_valid(pk):
			radar_ctrl.draw_circle(pk.position * scale_v, 1.6, pk.get_color())
	for e in enemies:
		if is_instance_valid(e):
			radar_ctrl.draw_circle(e.position * scale_v, 2.2, Color("ff4d6a"))
	if is_instance_valid(boss):
		radar_ctrl.draw_circle(boss.position * scale_v, 4.0, boss.color)
	if is_instance_valid(player):
		radar_ctrl.draw_circle(player.position * scale_v, 3.0, Color("4df0ff"))


func _show_banner(txt: String, col: Color) -> void:
	if not banner_lbl:
		return
	if _banner_tween and _banner_tween.is_valid():
		_banner_tween.kill()
	banner_lbl.text = txt
	banner_lbl.add_theme_color_override("font_color", col)
	banner_lbl.modulate.a = 0.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(banner_lbl, "modulate:a", 1.0, 0.22)
	_banner_tween.tween_interval(1.35)
	_banner_tween.tween_property(banner_lbl, "modulate:a", 0.0, 0.4)


func _set_touch_active(active: bool) -> void:
	if not is_instance_valid(touch_controls) or not Game.is_mobile():
		return
	if not active:
		touch_controls.reset_touches()
	touch_controls.visible = active


func _clear_overlay() -> void:
	for c in overlay_root.get_children():
		c.queue_free()
	overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE


# ---------------------------------------------------------------- Cartas tácticas Roguelite
func _open_card_selection() -> void:
	choosing_card = true
	Engine.time_scale = 1.0
	_hitstop_end_msec = 0
	_set_touch_active(false)
	get_tree().paused = true
	_clear_overlay()
	overlay_root.mouse_filter = Control.MOUSE_FILTER_STOP

	var p := UI.panel(Vector2(860, 0), Color("4df0ff"), 22)
	var v := UI.vbox(14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)

	v.add_child(UI.title("MEJORA TÁCTICA DE COMBATE", 32, Color("4df0ff")))
	v.add_child(UI.label("Elige 1 módulo de mejora para tu nave", 17, Color(0.8, 0.9, 1.0)))

	var pool := Game.CARDS.duplicate()
	pool.shuffle()
	var row := UI.hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)

	var first_btn: Button = null
	for i in 3:
		var c: Dictionary = pool[i]
		var card_panel := UI.panel(Vector2(250, 224), c.color, 14)
		var cv := UI.vbox(8)
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		card_panel.add_child(cv)

		cv.add_child(UI.title("[%s]" % String(c.icon), 28, c.color))
		cv.add_child(UI.label(String(c.name), 19, Color.WHITE))
		cv.add_child(UI.wrap_label(String(c.desc), 15, 215, Color(0.82, 0.9, 0.98), HORIZONTAL_ALIGNMENT_CENTER))
		var sp := Control.new()
		sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cv.add_child(sp)

		var pick_btn := UI.button("INSTALAR", func():
			Sfx.play("powerup")
			Game.haptic(24)
			player.apply_card(String(c.id))
			choosing_card = false
			_clear_overlay()
			get_tree().paused = false
			_set_touch_active(true)
			_start_next_wave()
		, 210, 44)
		if first_btn == null:
			first_btn = pick_btn
		cv.add_child(pick_btn)
		row.add_child(card_panel)

	overlay_root.add_child(p)
	if first_btn:
		first_btn.grab_focus.call_deferred()


# ---------------------------------------------------------------- Menú de Pausa
func _toggle_pause() -> void:
	if get_tree().paused:
		_clear_overlay()
		get_tree().paused = false
		_set_touch_active(true)
		return

	Engine.time_scale = 1.0
	_hitstop_end_msec = 0
	_set_touch_active(false)
	get_tree().paused = true
	_show_pause_main()


func _record_survival_if_needed() -> int:
	if _survival_recorded or Game.mode != "survival" or score <= 0:
		return -1
	_survival_recorded = true
	return Game.add_survival_score(score, maxi(1, wave))


func _show_pause_main() -> void:
	_clear_overlay()
	overlay_root.mouse_filter = Control.MOUSE_FILTER_STOP
	var p := UI.panel(Vector2(420, 0), Color("4df0ff"), 24)
	var v := UI.vbox(12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)

	v.add_child(UI.title("JUEGO EN PAUSA", 38, Color("4df0ff")))
	var resume := UI.button("CONTINUAR MISIÓN", _toggle_pause, 340, 46)
	v.add_child(resume)
	v.add_child(UI.button("REINICIAR MISIÓN", func():
		_record_survival_if_needed()
		Game.save_game()
		Game.change_scene("res://scenes/game.tscn")
	, 340, 46))
	v.add_child(UI.button("OPCIONES", _show_pause_options, 340, 46))
	v.add_child(UI.button("VOLVER AL MENÚ PRINCIPAL", func():
		_record_survival_if_needed()
		Game.save_game()
		Game.change_scene("res://scenes/main_menu.tscn")
	, 340, 46))

	overlay_root.add_child(p)
	resume.grab_focus.call_deferred()


func _show_pause_options() -> void:
	_clear_overlay()
	overlay_root.mouse_filter = Control.MOUSE_FILTER_STOP
	var p := UI.panel(Vector2(660, 0), Color("4df0ff"), 24)
	var opt := OptionsPanel.new()
	opt.closed.connect(func():
		if is_instance_valid(touch_controls):
			touch_controls.auto_fire_enabled = bool(Game.settings.get("auto_aim", true))
		_show_pause_main()
	)
	p.add_child(opt)
	overlay_root.add_child(p)


# ---------------------------------------------------------------- Victoria y Derrota
func _on_campaign_victory() -> void:
	if match_ended:
		return
	match_ended = true
	Engine.time_scale = 1.0
	_hitstop_end_msec = 0
	_set_touch_active(false)
	get_tree().paused = true
	Sfx.play("victory")
	Game.haptic(65)

	var lvl: Dictionary = Game.LEVELS[Game.current_level]
	var reward := int(round(float(lvl.reward) * float(Game.difficulty().credits)))
	credits_earned += reward
	Game.add_credits(reward)

	var stars := 1
	if is_instance_valid(player) and player.hp >= player.max_hp * 0.5:
		stars = 2
	if not took_damage_this_sector or (is_instance_valid(player) and player.hp >= player.max_hp * 0.85):
		stars = 3

	if not took_damage_this_sector:
		Game.unlock_achievement("perfect")
	if int(Game.settings.difficulty) == 3:
		Game.unlock_achievement("nightmare")

	var prev_stars := int(Game.data.stars.get(Game.current_level, 0))
	Game.data.stars[Game.current_level] = maxi(prev_stars, stars)

	var prev_best := int(Game.data.best.get(Game.current_level, 0))
	Game.data.best[Game.current_level] = maxi(prev_best, score)

	if Game.current_level >= int(Game.data.unlocked_level) and Game.current_level < Game.LEVELS.size() - 1:
		Game.data.unlocked_level = Game.current_level + 1
	if Game.current_level == Game.LEVELS.size() - 1:
		Game.data.campaign_done = true

	var unlocked_wep_name := ""
	if String(lvl.unlock) != "" and not Game.data.weapons.has(String(lvl.unlock)):
		Game.unlock_weapon(String(lvl.unlock))
		for w in Game.WEAPONS:
			if w.id == lvl.unlock:
				unlocked_wep_name = String(w.name)

	Game.save_game()

	_clear_overlay()
	overlay_root.mouse_filter = Control.MOUSE_FILTER_STOP
	var p := UI.panel(Vector2(540, 0), Color("4dff88"), 26)
	var v := UI.vbox(12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)

	v.add_child(UI.title("¡SECTOR COMPLETADO!", 42, Color("4dff88")))
	v.add_child(UI.label("Sector 0%d — %s" % [Game.current_level + 1, String(lvl.name)], 20, theme_color))

	var st_wrap := CenterContainer.new()
	st_wrap.add_child(UI.stars_widget(stars, 3, 34.0))
	v.add_child(st_wrap)

	v.add_child(UI.label("Puntuación final: %d pts" % score, 22, Color.WHITE))
	v.add_child(UI.label("Hostiles eliminados: %d" % kills, 18, Color(0.8, 0.9, 1.0)))
	v.add_child(UI.label("Créditos obtenidos: +%d CR (Total: %d CR)" % [credits_earned, int(Game.data.credits)], 20, Color("ffd24d")))

	if unlocked_wep_name != "":
		v.add_child(UI.label("¡NUEVA ARMA DESBLOQUEADA: %s!" % unlocked_wep_name.to_upper(), 20, Color("7dff6b")))

	v.add_child(UI.spacer(6))
	var first_btn: Button = null
	if Game.current_level < Game.LEVELS.size() - 1:
		first_btn = UI.button("SIGUIENTE SECTOR", func():
			Game.current_level += 1
			Game.change_scene("res://scenes/game.tscn")
		, 360, 48)
		v.add_child(first_btn)

	var retry := UI.button("REPETIR SECTOR", func():
		Game.change_scene("res://scenes/game.tscn")
	, 360, 44)
	if first_btn == null:
		first_btn = retry
	v.add_child(retry)

	v.add_child(UI.button("VOLVER AL MENÚ PRINCIPAL", func():
		Game.change_scene("res://scenes/main_menu.tscn")
	, 360, 44))

	overlay_root.add_child(p)
	first_btn.grab_focus.call_deferred()


func on_player_died() -> void:
	if match_ended:
		return
	match_ended = true
	Engine.time_scale = 1.0
	_hitstop_end_msec = 0
	_set_touch_active(false)
	Sfx.play("big_explosion")
	Sfx.play("gameover")
	Game.haptic(110)
	fx.add_burst(player.position, Color("4df0ff"), 50, 400.0, 5.0, 0.9)
	fx.add_ring(player.position, Color("ff4d6a"), 240.0, 0.65, 6.0)
	player.visible = false

	var rank := _record_survival_if_needed()
	Game.save_game()

	get_tree().paused = true
	_clear_overlay()
	overlay_root.mouse_filter = Control.MOUSE_FILTER_STOP

	var p := UI.panel(Vector2(520, 0), Color("ff4d6a"), 26)
	var v := UI.vbox(12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)

	v.add_child(UI.title("NAVE DESTRUIDA", 44, Color("ff4d6a")))
	if Game.mode == "survival":
		v.add_child(UI.label("Alcanzaste la Ronda %d en Supervivencia" % maxi(1, wave), 20, Color("ff4df0")))
		if rank >= 0 and rank < 5:
			v.add_child(UI.label("¡NUEVO RÉCORD PERSONAL (#%d)!" % (rank + 1), 20, Color("ffd24d")))
	else:
		var lvl: Dictionary = Game.LEVELS[Game.current_level]
		v.add_child(UI.label("Sector 0%d: %s — Oleada %d / %d" % [Game.current_level + 1, String(lvl.name), maxi(1, wave), max_waves], 19, theme_color))

	v.add_child(UI.label("Puntuación: %d pts" % score, 22, Color.WHITE))
	v.add_child(UI.label("Hostiles eliminados: %d" % kills, 18, Color(0.8, 0.9, 1.0)))
	v.add_child(UI.label("Créditos asegurados: +%d CR" % credits_earned, 20, Color("ffd24d")))
	v.add_child(UI.spacer(6))

	var retry := UI.button("REINTENTAR MISIÓN", func():
		Game.change_scene("res://scenes/game.tscn")
	, 360, 48)
	v.add_child(retry)

	v.add_child(UI.button("VOLVER AL MENÚ / HANGAR", func():
		Game.change_scene("res://scenes/main_menu.tscn")
	, 360, 46))

	overlay_root.add_child(p)
	retry.grab_focus.call_deferred()
