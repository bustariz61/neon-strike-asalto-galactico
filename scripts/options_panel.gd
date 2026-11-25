extends VBoxContainer
## Panel de opciones reutilizable (menú principal y menú de pausa).

signal closed

const UI = preload("res://scripts/ui.gd")


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(UI.title("OPCIONES", 46, Color("4df0ff")))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 12)
	add_child(grid)

	grid.add_child(UI.label("Nombre del piloto", 20, Color(0.8, 0.9, 1.0), HORIZONTAL_ALIGNMENT_LEFT))
	var le := LineEdit.new()
	le.text = String(Game.settings.pilot)
	le.max_length = 14
	le.custom_minimum_size = Vector2(300, 40)
	le.text_changed.connect(func(txt: String):
		Game.settings.pilot = Game.sanitize_pilot_name(txt)
	)
	grid.add_child(le)

	_slider(grid, "Volumen general", "master")
	_slider(grid, "Música", "music")
	_slider(grid, "Efectos de sonido", "sfx")
	_check(grid, "Pantalla completa", "fullscreen")
	_check(grid, "Vibración de pantalla", "shake")
	_check(grid, "Números de daño", "damage_numbers")
	_check(grid, "Mostrar FPS", "show_fps")

	add_child(UI.spacer(6))
	var back := UI.button("GUARDAR Y VOLVER", _close, 300)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(back)
	back.grab_focus.call_deferred()


func _slider(grid: GridContainer, text: String, key: String) -> void:
	grid.add_child(UI.label(text, 20, Color(0.8, 0.9, 1.0), HORIZONTAL_ALIGNMENT_LEFT))
	var h := UI.hbox(10)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = float(Game.settings[key])
	s.custom_minimum_size = Vector2(230, 30)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pct := UI.label("%d%%" % int(round(s.value * 100.0)), 18)
	pct.custom_minimum_size.x = 60
	s.value_changed.connect(func(v: float):
		Game.settings[key] = v
		pct.text = "%d%%" % int(round(v * 100.0))
		Game.apply_settings()
		if key != "music":
			Sfx.play("coin")
	)
	h.add_child(s)
	h.add_child(pct)
	grid.add_child(h)


func _check(grid: GridContainer, text: String, key: String) -> void:
	grid.add_child(UI.label(text, 20, Color(0.8, 0.9, 1.0), HORIZONTAL_ALIGNMENT_LEFT))
	var c := CheckButton.new()
	c.button_pressed = bool(Game.settings[key])
	c.toggled.connect(func(on: bool):
		Game.settings[key] = on
		Game.apply_settings()
		Sfx.play("click")
	)
	grid.add_child(c)


func _close() -> void:
	Game.save_game()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
