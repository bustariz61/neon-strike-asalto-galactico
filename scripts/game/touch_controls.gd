extends Control
## Controles táctiles virtuales (Twin-Stick + Dash + Bomba EMP) para Android y pantallas táctiles.

var game: Node2D
var move_vec := Vector2.ZERO
var aim_vec := Vector2.ZERO
var is_shooting := false

var _left_touch_id := -1
var _left_origin := Vector2.ZERO
var _left_pos := Vector2.ZERO

var _right_touch_id := -1
var _right_origin := Vector2.ZERO
var _right_pos := Vector2.ZERO

const STICK_RADIUS := 70.0
const KNOB_RADIUS := 28.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = OS.get_name() == "Android"
	if not visible:
		return

	# Botones táctiles de acción rápida (Dash y Bomba EMP)
	var btn_box := HBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 14)
	btn_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	btn_box.offset_left = -310
	btn_box.offset_right = -30
	btn_box.offset_top = -215
	btn_box.offset_bottom = -155
	add_child(btn_box)

	var dash_btn := Button.new()
	dash_btn.text = "DASH"
	dash_btn.custom_minimum_size = Vector2(125, 56)
	dash_btn.pressed.connect(func():
		if is_instance_valid(game) and is_instance_valid(game.player):
			var p: Node2D = game.player
			if p.dash_cd <= 0.0 and p.dash_time <= 0.0:
				p._start_dash(move_vec)
	)
	btn_box.add_child(dash_btn)

	var bomb_btn := Button.new()
	bomb_btn.text = "BOMBA EMP"
	bomb_btn.custom_minimum_size = Vector2(145, 56)
	bomb_btn.pressed.connect(func():
		if is_instance_valid(game) and is_instance_valid(game.player):
			game.player._use_bomb()
	)
	btn_box.add_child(bomb_btn)


func _input(event: InputEvent) -> void:
	if not visible or get_tree().paused:
		move_vec = Vector2.ZERO
		is_shooting = false
		return

	var vp_size := get_viewport_rect().size
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			# Ignorar zona de botones inferiores/superiores
			if st.position.y > vp_size.y - 82.0 or st.position.y < 70.0:
				return
			if st.position.x < vp_size.x * 0.5 and _left_touch_id == -1:
				_left_touch_id = st.index
				_left_origin = st.position
				_left_pos = st.position
				move_vec = Vector2.ZERO
			elif st.position.x >= vp_size.x * 0.5 and _right_touch_id == -1:
				_right_touch_id = st.index
				_right_origin = st.position
				_right_pos = st.position
				is_shooting = true
		else:
			if st.index == _left_touch_id:
				_left_touch_id = -1
				move_vec = Vector2.ZERO
			elif st.index == _right_touch_id:
				_right_touch_id = -1
				is_shooting = false
		queue_redraw()

	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _left_touch_id:
			var delta := sd.position - _left_origin
			if delta.length() > STICK_RADIUS:
				delta = delta.normalized() * STICK_RADIUS
			_left_pos = _left_origin + delta
			move_vec = delta / STICK_RADIUS
			queue_redraw()
		elif sd.index == _right_touch_id:
			var delta := sd.position - _right_origin
			if delta.length() > STICK_RADIUS:
				delta = delta.normalized() * STICK_RADIUS
			_right_pos = _right_origin + delta
			if delta.length() > 8.0:
				aim_vec = delta.normalized()
			is_shooting = true
			queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var vp := get_viewport_rect().size
	var l_base := _left_origin if _left_touch_id != -1 else Vector2(140.0, vp.y - 165.0)
	var l_knob := _left_pos if _left_touch_id != -1 else l_base
	draw_circle(l_base, STICK_RADIUS, Color(0.05, 0.12, 0.22, 0.35))
	draw_arc(l_base, STICK_RADIUS, 0.0, TAU, 32, Color(0.3, 0.94, 1.0, 0.55), 2.5)
	draw_circle(l_knob, KNOB_RADIUS, Color(0.3, 0.94, 1.0, 0.75))

	var r_base := _right_origin if _right_touch_id != -1 else Vector2(vp.x - 140.0, vp.y - 295.0)
	var r_knob := _right_pos if _right_touch_id != -1 else r_base
	draw_circle(r_base, STICK_RADIUS, Color(0.18, 0.05, 0.22, 0.35))
	draw_arc(r_base, STICK_RADIUS, 0.0, TAU, 32, Color(1.0, 0.3, 0.94, 0.55), 2.5)
	draw_circle(r_knob, KNOB_RADIUS, Color(1.0, 0.3, 0.94, 0.75))
