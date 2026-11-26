extends Control
## Controles táctiles dinámicos para Android/móvil:
## - Joysticks flotantes con seguimiento suave que se atenúan en reposo para no estorbar.
## - Botones circulares translúcidos de DASH y EMP pegados al borde derecho con arco de recarga.
## - Exclusión exacta de zonas UI para que ningún botón active los joysticks por error.

var game: Node2D
var move_vec := Vector2.ZERO
var aim_vec := Vector2.ZERO
var is_shooting := false
var auto_fire_enabled := true
var blocked_controls: Array = []

var _left_touch_id := -1
var _left_origin := Vector2.ZERO
var _left_pos := Vector2.ZERO
var _left_alpha := 0.22

var _right_touch_id := -1
var _right_origin := Vector2.ZERO
var _right_pos := Vector2.ZERO
var _right_alpha := 0.16

var _dash_touch_id := -1
var _bomb_touch_id := -1
var _dash_flash := 0.0
var _bomb_flash := 0.0
var _pulse_t := 0.0

const STICK_RADIUS := 60.0
const KNOB_RADIUS := 24.0
const DASH_RADIUS := 34.0
const BOMB_RADIUS := 29.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = Game.is_mobile()
	auto_fire_enabled = bool(Game.settings.get("auto_aim", true))
	set_process(visible)


func reset_touches() -> void:
	_left_touch_id = -1
	_right_touch_id = -1
	_dash_touch_id = -1
	_bomb_touch_id = -1
	move_vec = Vector2.ZERO
	is_shooting = false
	queue_redraw()


func toggle_auto_fire() -> bool:
	auto_fire_enabled = not auto_fire_enabled
	Game.settings.auto_aim = auto_fire_enabled
	Game.save_game()
	Sfx.play("click")
	Game.haptic(12)
	queue_redraw()
	return auto_fire_enabled


func _process(delta: float) -> void:
	if not visible:
		return
	_pulse_t += delta
	var target_l := 1.0 if _left_touch_id != -1 else 0.20
	var target_r := 1.0 if _right_touch_id != -1 else (0.14 if auto_fire_enabled else 0.24)
	_left_alpha = lerpf(_left_alpha, target_l, clampf(12.0 * delta, 0.0, 1.0))
	_right_alpha = lerpf(_right_alpha, target_r, clampf(12.0 * delta, 0.0, 1.0))
	if _dash_flash > 0.0:
		_dash_flash = maxf(0.0, _dash_flash - delta * 4.5)
	if _bomb_flash > 0.0:
		_bomb_flash = maxf(0.0, _bomb_flash - delta * 4.5)
	queue_redraw()


func _dash_center() -> Vector2:
	var vp := get_viewport_rect().size
	var ins := Game.get_safe_insets()
	return Vector2(vp.x - float(ins.right) - 54.0, vp.y - float(ins.bottom) - 216.0)


func _bomb_center() -> Vector2:
	var vp := get_viewport_rect().size
	var ins := Game.get_safe_insets()
	return Vector2(vp.x - float(ins.right) - 54.0, vp.y - float(ins.bottom) - 296.0)


func _left_idle_center() -> Vector2:
	var vp := get_viewport_rect().size
	var ins := Game.get_safe_insets()
	return Vector2(float(ins.left) + 98.0, vp.y - float(ins.bottom) - 96.0)


func _right_idle_center() -> Vector2:
	var vp := get_viewport_rect().size
	var ins := Game.get_safe_insets()
	return Vector2(vp.x - float(ins.right) - 98.0, vp.y - float(ins.bottom) - 96.0)


func _is_over_blocked_ui(pos: Vector2) -> bool:
	for c in blocked_controls:
		if is_instance_valid(c) and c is Control and (c as Control).is_visible_in_tree():
			if (c as Control).get_global_rect().grow(10.0).has_point(pos):
				return true
	var ins := Game.get_safe_insets()
	if pos.y < float(ins.top) + 64.0:
		return true
	return false


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if get_tree().paused or (is_instance_valid(game) and (game.match_ended or game.choosing_card)):
		if _left_touch_id != -1 or _right_touch_id != -1 or is_shooting:
			reset_touches()
		return

	var vp := get_viewport_rect().size
	var ins := Game.get_safe_insets()

	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		var pos := st.position
		if st.pressed:
			# 1. Botón circular DASH (respuesta instantánea al tocar, sin interferir con joysticks)
			if pos.distance_to(_dash_center()) <= DASH_RADIUS + 14.0:
				_dash_touch_id = st.index
				_dash_flash = 1.0
				if is_instance_valid(game) and is_instance_valid(game.player):
					var p: Node2D = game.player
					if p.dash_cd <= 0.0 and p.dash_time <= 0.0:
						p._start_dash(move_vec)
				get_viewport().set_input_as_handled()
				queue_redraw()
				return

			# 2. Botón circular BOMBA EMP
			if pos.distance_to(_bomb_center()) <= BOMB_RADIUS + 14.0:
				_bomb_touch_id = st.index
				_bomb_flash = 1.0
				if is_instance_valid(game) and is_instance_valid(game.player):
					game.player._use_bomb()
				get_viewport().set_input_as_handled()
				queue_redraw()
				return

			# 3. No interceptar botones del HUD (Pausa, Cambio de Arma, Auto-Aim)
			if _is_over_blocked_ui(pos):
				return

			# 4. Joysticks flotantes (izquierdo = movimiento, derecho = apuntado + disparo manual)
			if pos.x < vp.x * 0.5 and _left_touch_id == -1:
				_left_touch_id = st.index
				_left_origin = Vector2(
					clampf(pos.x, float(ins.left) + STICK_RADIUS + 12.0, vp.x * 0.46),
					clampf(pos.y, float(ins.top) + 96.0, vp.y - float(ins.bottom) - STICK_RADIUS - 10.0)
				)
				_left_pos = _left_origin
				move_vec = Vector2.ZERO
				queue_redraw()
			elif pos.x >= vp.x * 0.5 and _right_touch_id == -1:
				_right_touch_id = st.index
				_right_origin = Vector2(
					clampf(pos.x, vp.x * 0.54, vp.x - float(ins.right) - STICK_RADIUS - 12.0),
					clampf(pos.y, float(ins.top) + 96.0, vp.y - float(ins.bottom) - STICK_RADIUS - 10.0)
				)
				_right_pos = _right_origin
				is_shooting = true
				queue_redraw()
		else:
			if st.index == _left_touch_id:
				_left_touch_id = -1
				move_vec = Vector2.ZERO
				queue_redraw()
			elif st.index == _right_touch_id:
				_right_touch_id = -1
				is_shooting = false
				queue_redraw()
			elif st.index == _dash_touch_id:
				_dash_touch_id = -1
			elif st.index == _bomb_touch_id:
				_bomb_touch_id = -1

	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _left_touch_id:
			var delta := sd.position - _left_origin
			var dist := delta.length()
			# Seguimiento dinámico suave: evita deriva del pulgar y permite cambios bruscos al instante
			if dist > STICK_RADIUS * 1.18:
				var follow := delta.normalized() * (dist - STICK_RADIUS * 1.18)
				_left_origin += follow * 0.72
				_left_origin.x = clampf(_left_origin.x, float(ins.left) + STICK_RADIUS + 8.0, vp.x * 0.48)
				_left_origin.y = clampf(_left_origin.y, float(ins.top) + 92.0, vp.y - float(ins.bottom) - STICK_RADIUS - 8.0)
				delta = sd.position - _left_origin
				dist = delta.length()
			if dist > STICK_RADIUS:
				delta = delta.normalized() * STICK_RADIUS
			_left_pos = _left_origin + delta
			var norm_v := delta / STICK_RADIUS
			move_vec = norm_v if norm_v.length() > 0.08 else Vector2.ZERO
			queue_redraw()

		elif sd.index == _right_touch_id:
			var delta := sd.position - _right_origin
			var dist := delta.length()
			if dist > STICK_RADIUS * 1.18:
				var follow := delta.normalized() * (dist - STICK_RADIUS * 1.18)
				_right_origin += follow * 0.72
				_right_origin.x = clampf(_right_origin.x, vp.x * 0.52, vp.x - float(ins.right) - STICK_RADIUS - 8.0)
				_right_origin.y = clampf(_right_origin.y, float(ins.top) + 92.0, vp.y - float(ins.bottom) - STICK_RADIUS - 8.0)
				delta = sd.position - _right_origin
				dist = delta.length()
			if dist > STICK_RADIUS:
				delta = delta.normalized() * STICK_RADIUS
			_right_pos = _right_origin + delta
			if delta.length() > 7.0:
				aim_vec = delta.normalized()
			is_shooting = true
			queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var op := clampf(float(Game.settings.get("touch_opacity", 0.78)), 0.35, 1.0)
	var font := ThemeDB.fallback_font

	# --- Joystick Izquierdo (Movimiento) ---
	var l_active := _left_touch_id != -1
	var l_base := _left_origin if l_active else _left_idle_center()
	var l_knob := _left_pos if l_active else l_base
	var l_rad := STICK_RADIUS if l_active else STICK_RADIUS * 0.80
	var la := _left_alpha * op
	draw_circle(l_base, l_rad, Color(0.03, 0.09, 0.18, 0.28 * la))
	draw_arc(l_base, l_rad, 0.0, TAU, 36, Color(0.3, 0.94, 1.0, 0.70 * la), 2.2)
	if l_active and move_vec.length_squared() > 0.04:
		var ang := move_vec.angle()
		draw_arc(l_base, l_rad + 4.0, ang - 0.55, ang + 0.55, 16, Color(0.45, 0.98, 1.0, 0.95 * la), 3.0)
	draw_circle(l_knob, KNOB_RADIUS * (1.0 if l_active else 0.75), Color(0.3, 0.94, 1.0, 0.65 * la))
	draw_circle(l_knob, KNOB_RADIUS * (0.42 if l_active else 0.30), Color(1.0, 1.0, 1.0, 0.75 * la))

	# --- Joystick Derecho (Apuntado y Disparo Manual) ---
	var r_active := _right_touch_id != -1
	var r_base := _right_origin if r_active else _right_idle_center()
	var r_knob := _right_pos if r_active else r_base
	var r_rad := STICK_RADIUS if r_active else STICK_RADIUS * 0.78
	var ra := _right_alpha * op
	draw_circle(r_base, r_rad, Color(0.16, 0.03, 0.18, 0.26 * ra))
	draw_arc(r_base, r_rad, 0.0, TAU, 36, Color(1.0, 0.3, 0.94, 0.70 * ra), 2.2)
	if r_active and aim_vec.length_squared() > 0.04:
		var ang := aim_vec.angle()
		draw_arc(r_base, r_rad + 5.0, ang - 0.45, ang + 0.45, 16, Color(1.0, 0.5, 0.98, 0.95 * ra), 3.2)
	draw_circle(r_knob, KNOB_RADIUS * (1.0 if r_active else 0.72), Color(1.0, 0.3, 0.94, 0.65 * ra))
	draw_circle(r_knob, KNOB_RADIUS * (0.40 if r_active else 0.28), Color(1.0, 1.0, 1.0, 0.75 * ra))
	if not r_active:
		var hint := "AUTO" if auto_fire_enabled else "FUEGO"
		draw_string(font, r_base + Vector2(-22, 4), hint, HORIZONTAL_ALIGNMENT_CENTER, 44, 11, Color(1.0, 0.8, 1.0, 0.75 * ra))

	# --- Botón Circular DASH (borde derecho inferior-medio) ---
	var p: Node2D = game.player if is_instance_valid(game) and is_instance_valid(game.player) else null
	var dc := _dash_center()
	var dash_ready: bool = p == null or float(p.dash_cd) <= 0.05
	var dash_ratio := 1.0
	if p != null and float(p.dash_cd) > 0.0:
		var max_cd := maxf(0.1, float(p.dash_max_cd) * float(p.mods.cooldown))
		dash_ratio = 1.0 - clampf(float(p.dash_cd) / max_cd, 0.0, 1.0)
	var d_col := Color("4df0ff")
	var d_op := op * (0.95 if dash_ready else 0.52)
	if dash_ready:
		var glow := 0.14 + 0.08 * sin(_pulse_t * 5.0)
		draw_circle(dc, DASH_RADIUS + 5.0, Color(d_col, glow * d_op))
	draw_circle(dc, DASH_RADIUS, Color(0.03, 0.08, 0.16, (0.58 + 0.3 * _dash_flash) * d_op))
	if dash_ready:
		draw_arc(dc, DASH_RADIUS, 0.0, TAU, 32, Color(d_col, 0.9 * d_op), 2.8)
	else:
		draw_arc(dc, DASH_RADIUS, 0.0, TAU, 32, Color(d_col, 0.22 * op), 2.0)
		draw_arc(dc, DASH_RADIUS, -PI * 0.5, -PI * 0.5 + TAU * dash_ratio, 32, Color(d_col, 0.9 * op), 3.2)
	var dash_txt := "DASH" if dash_ready else "%.1f" % p.dash_cd
	draw_string(font, dc + Vector2(-28, 5), dash_txt, HORIZONTAL_ALIGNMENT_CENTER, 56, 13 if dash_ready else 14, Color(1, 1, 1, 0.95 * d_op))

	# --- Botón Circular BOMBA EMP (encima de DASH en el borde derecho) ---
	var bc := _bomb_center()
	var bombs_cnt := int(p.bombs) if p != null else 0
	var b_col := Color("ff4df0")
	var b_op := op * (0.92 if bombs_cnt > 0 else 0.26)
	if bombs_cnt > 0:
		var bglow := 0.12 + 0.07 * sin(_pulse_t * 4.2 + 1.2)
		draw_circle(bc, BOMB_RADIUS + 4.0, Color(b_col, bglow * b_op))
	draw_circle(bc, BOMB_RADIUS, Color(0.14, 0.03, 0.16, (0.58 + 0.3 * _bomb_flash) * b_op))
	draw_arc(bc, BOMB_RADIUS, 0.0, TAU, 28, Color(b_col, 0.9 * b_op), 2.5)
	draw_string(font, bc + Vector2(-24, -1), "EMP", HORIZONTAL_ALIGNMENT_CENTER, 48, 11, Color(1.0, 0.8, 1.0, 0.95 * b_op))
	draw_string(font, bc + Vector2(-24, 14), "x%d" % bombs_cnt, HORIZONTAL_ALIGNMENT_CENTER, 48, 13, Color(1, 1, 1, 0.95 * b_op))
