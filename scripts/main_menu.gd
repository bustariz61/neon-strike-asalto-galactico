extends Control
## Menú principal completo: Inicio, Selección de Sector (Campaña), Supervivencia,
## Hangar y Arsenal, Récords y Logros, Manual de Controles y Opciones.

const UI = preload("res://scripts/ui.gd")
const Background = preload("res://scripts/background.gd")
const OptionsPanel = preload("res://scripts/options_panel.gd")

var _top_pilot: Label
var _top_diff: Button
var _top_credits: Label
var _top_ach: Label
var _content: CenterContainer
var _selected_level := 0


func _ready() -> void:
	Sfx.play_music("menu")
	_selected_level = clampi(int(Game.data.unlocked_level), 0, Game.LEVELS.size() - 1)

	var bg := Background.new()
	bg.menu_mode = true
	add_child(bg)

	var root := UI.vbox(0)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	root.add_child(_build_top_bar())

	_content = CenterContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_content)

	root.add_child(_build_footer())
	_open_home()


func _build_top_bar() -> Control:
	var bar := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.04, 0.1, 0.88)
	sb.border_color = Color("4df0ff").darkened(0.35)
	sb.border_width_bottom = 2
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	bar.add_theme_stylebox_override("panel", sb)

	var h := UI.hbox(20)
	bar.add_child(h)

	_top_pilot = UI.label("", 18, Color("4df0ff"), HORIZONTAL_ALIGNMENT_LEFT)
	h.add_child(_top_pilot)

	_top_diff = UI.button("", func():
		Game.settings.difficulty = (int(Game.settings.difficulty) + 1) % Game.DIFFICULTIES.size()
		Game.save_game()
		_refresh_top_bar()
	, 220, 36)
	h.add_child(_top_diff)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(spacer)

	_top_ach = UI.label("", 18, Color(0.8, 0.9, 1.0), HORIZONTAL_ALIGNMENT_RIGHT)
	h.add_child(_top_ach)

	_top_credits = UI.label("", 20, Color("ffd24d"), HORIZONTAL_ALIGNMENT_RIGHT)
	h.add_child(_top_credits)

	_refresh_top_bar()
	return bar


func _build_footer() -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 24)
	m.add_theme_constant_override("margin_right", 24)
	m.add_theme_constant_override("margin_bottom", 10)
	var h := UI.hbox(16)
	m.add_child(h)
	var left := UI.label("WASD: Mover  |  Ratón: Apuntar y Disparar  |  Espacio: Dash  |  F / Clic Der: Bomba EMP", 15, Color(0.65, 0.78, 0.9), HORIZONTAL_ALIGNMENT_LEFT)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(left)
	h.add_child(UI.label("%s %s — %s" % [Game.TITLE, Game.SUBTITLE, Game.VERSION], 15, Color(0.55, 0.68, 0.82), HORIZONTAL_ALIGNMENT_RIGHT))
	return m


func _refresh_top_bar() -> void:
	if not _top_pilot:
		return
	var d := Game.difficulty()
	_top_pilot.text = "PILOTO: %s" % String(Game.settings.pilot)
	_top_diff.text = "DIFICULTAD: %s" % String(d.name).to_upper()
	_top_diff.modulate = d.color
	_top_credits.text = "CRÉDITOS: %d CR" % int(Game.data.credits)
	_top_ach.text = "LOGROS: %d / %d" % [Game.data.achievements.size(), Game.ACHIEVEMENTS.size()]


func _show_view(node: Control) -> void:
	for c in _content.get_children():
		c.queue_free()
	_refresh_top_bar()
	node.modulate.a = 0.0
	_content.add_child(node)
	var tw := create_tween()
	tw.tween_property(node, "modulate:a", 1.0, 0.18)


# ---------------------------------------------------------------- Inicio
func _open_home() -> void:
	var v := UI.vbox(12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER

	v.add_child(UI.title(Game.TITLE, 72, Color("4df0ff")))
	v.add_child(UI.title(Game.SUBTITLE, 30, Color("ff4df0")))
	v.add_child(UI.spacer(8))

	var cols := UI.hbox(28)
	cols.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(cols)

	# Panel de navegación principal
	var nav_panel := UI.panel(Vector2(380, 0), Color("4df0ff"), 20)
	var nav := UI.vbox(10)
	nav_panel.add_child(nav)

	var btn_camp := UI.button("CAMPAÑA GALÁCTICA", _open_campaign, 340, 48)
	nav.add_child(btn_camp)
	nav.add_child(UI.button("SUPERVIVENCIA (RONDAS)", _start_survival, 340, 48))
	nav.add_child(UI.button("HANGAR Y ARSENAL", _open_hangar, 340, 46))
	nav.add_child(UI.button("RÉCORDS Y LOGROS", _open_records, 340, 46))
	nav.add_child(UI.button("MANUAL Y CONTROLES", _open_help, 340, 46))
	nav.add_child(UI.button("OPCIONES", _open_options, 340, 46))
	if DisplayServer.get_name() != "web":
		nav.add_child(UI.button("SALIR DEL JUEGO", func(): get_tree().quit(), 340, 44))
	cols.add_child(nav_panel)

	# Panel de resumen de estado del piloto
	var info_panel := UI.panel(Vector2(420, 0), Color("ff4df0"), 20)
	var info := UI.vbox(10)
	info_panel.add_child(info)
	info.add_child(UI.title("ESTADO DE LA FLOTA", 26, Color("ff4df0")))

	var unlocked_sectors := mini(int(Game.data.unlocked_level) + 1, Game.LEVELS.size())
	var total_stars := 0
	for k in Game.data.stars:
		total_stars += int(Game.data.stars[k])

	info.add_child(_stat_row("Sectores desbloqueados", "%d / %d" % [unlocked_sectors, Game.LEVELS.size()], Color("4df0ff")))
	info.add_child(_stat_row("Estrellas de campaña", "%d / %d" % [total_stars, Game.LEVELS.size() * 3], Color("ffd24d")))
	info.add_child(_stat_row("Armas en arsenal", "%d / %d" % [Game.data.weapons.size(), Game.WEAPONS.size()], Color("7dff6b")))
	info.add_child(_stat_row("Mejor ronda Supervivencia", "Ronda %d" % int(Game.data.stats.best_round), Color("ff9b3d")))
	info.add_child(_stat_row("Enemigos eliminados", "%d" % int(Game.data.stats.kills), Color(0.85, 0.95, 1.0)))

	info.add_child(UI.spacer(6))
	var d := Game.difficulty()
	info.add_child(UI.label("MODO DE DIFICULTAD: %s" % String(d.name).to_upper(), 18, d.color, HORIZONTAL_ALIGNMENT_LEFT))
	info.add_child(UI.wrap_label(
		"Vida enemiga x%.1f  |  Daño enemigo x%.1f\nPuntos x%.1f  |  Créditos x%.1f" % [float(d.hp), float(d.dmg), float(d.score), float(d.credits)],
		15, 370, Color(0.75, 0.85, 0.95)
	))
	var diff_btn := UI.button("CAMBIAR DIFICULTAD", func():
		Game.settings.difficulty = (int(Game.settings.difficulty) + 1) % Game.DIFFICULTIES.size()
		Game.save_game()
		_open_home()
	, 370, 42)
	info.add_child(diff_btn)
	cols.add_child(info_panel)

	_show_view(v)
	btn_camp.grab_focus.call_deferred()


func _stat_row(k: String, val: String, col: Color) -> Control:
	var h := UI.hbox(8)
	var l1 := UI.label(k, 17, Color(0.78, 0.88, 0.96), HORIZONTAL_ALIGNMENT_LEFT)
	l1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l1)
	h.add_child(UI.label(val, 18, col, HORIZONTAL_ALIGNMENT_RIGHT))
	return h


# ---------------------------------------------------------------- Campaña
func _open_campaign() -> void:
	var v := UI.vbox(14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(UI.title("CAMPAÑA GALÁCTICA — SECTORES", 38, Color("4df0ff")))

	var cols := UI.hbox(22)
	cols.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(cols)

	# Cuadrícula de 9 sectores
	var grid_panel := UI.panel(Vector2(660, 420), Color("4df0ff"), 16)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid_panel.add_child(grid)

	for i in Game.LEVELS.size():
		var lvl: Dictionary = Game.LEVELS[i]
		var unlocked := i <= int(Game.data.unlocked_level)
		var is_sel := i == _selected_level
		var card := UI.panel(Vector2(200, 120), lvl.color if is_sel else (lvl.color.darkened(0.45) if unlocked else Color(0.25, 0.25, 0.3)), 10)
		var cv := UI.vbox(4)
		card.add_child(cv)

		var head := UI.hbox(6)
		var num_lbl := UI.label("SECTOR 0%d" % (i + 1), 14, lvl.color if unlocked else Color(0.5, 0.5, 0.55), HORIZONTAL_ALIGNMENT_LEFT)
		num_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(num_lbl)
		if String(lvl.boss) != "":
			head.add_child(UI.label("[JEFE]", 13, Color("ff4d6a"), HORIZONTAL_ALIGNMENT_RIGHT))
		cv.add_child(head)

		var name_txt := String(lvl.name) if unlocked else "BLOQUEADO"
		cv.add_child(UI.label(name_txt, 17, Color.WHITE if unlocked else Color(0.45, 0.45, 0.5), HORIZONTAL_ALIGNMENT_LEFT))

		var stars := int(Game.data.stars.get(i, Game.data.stars.get(str(i), 0)))
		var st_row := UI.hbox(6)
		st_row.add_child(UI.stars_widget(stars, 3, 16.0))
		cv.add_child(st_row)

		var select_btn := UI.button("SELECCIONADO" if is_sel else ("VER SECTOR" if unlocked else "CERRADO"), func():
			_selected_level = i
			_open_campaign()
		, 176, 32)
		select_btn.disabled = not unlocked
		cv.add_child(select_btn)
		grid.add_child(card)

	cols.add_child(grid_panel)

	# Panel de informe de misión
	var lvl_sel: Dictionary = Game.LEVELS[_selected_level]
	var brief_panel := UI.panel(Vector2(430, 420), lvl_sel.color, 18)
	var bv := UI.vbox(8)
	brief_panel.add_child(bv)

	bv.add_child(UI.label("INFORME DE MISIÓN — SECTOR 0%d" % (_selected_level + 1), 15, lvl_sel.color, HORIZONTAL_ALIGNMENT_LEFT))
	bv.add_child(UI.title(String(lvl_sel.name).to_upper(), 28, lvl_sel.color))
	bv.add_child(UI.wrap_label(String(lvl_sel.desc), 16, 385, Color(0.85, 0.92, 1.0)))
	bv.add_child(UI.spacer(4))

	var enemy_names: Array = []
	for e_id in lvl_sel.pool:
		enemy_names.append(String(Game.ENEMY_NAMES.get(e_id, e_id)))
	bv.add_child(_stat_row("Oleadas de asalto", "%d oleadas" % int(lvl_sel.waves), Color("4df0ff")))
	bv.add_child(_stat_row("Hostiles detectados", ", ".join(enemy_names), Color(0.85, 0.9, 1.0)))
	if String(lvl_sel.boss) != "":
		bv.add_child(_stat_row("Amenaza principal", String(Game.BOSS_NAMES.get(lvl_sel.boss, "JEFE")), Color("ff4d6a")))
	bv.add_child(_stat_row("Recompensa base", "+%d CR" % int(lvl_sel.reward), Color("ffd24d")))

	if String(lvl_sel.unlock) != "":
		var w_name := ""
		for w in Game.WEAPONS:
			if w.id == lvl_sel.unlock:
				w_name = w.name
		bv.add_child(_stat_row("Desbloquea arma", w_name, Color("7dff6b")))

	var best_score := int(Game.data.best.get(_selected_level, Game.data.best.get(str(_selected_level), 0)))
	bv.add_child(_stat_row("Mejor puntuación", "%d pts" % best_score, Color("4df0ff")))

	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bv.add_child(sp)

	var launch := UI.button("DESPLEGAR EN SECTOR 0%d" % (_selected_level + 1), func():
		Game.mode = "campaign"
		Game.current_level = _selected_level
		Game.change_scene("res://scenes/game.tscn")
	, 385, 50)
	bv.add_child(launch)
	cols.add_child(brief_panel)

	var bottom := UI.hbox(16)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_child(UI.button("VOLVER AL MENÚ", _open_home, 260, 44))
	bottom.add_child(UI.button("IR AL HANGAR", _open_hangar, 260, 44))
	v.add_child(bottom)

	_show_view(v)
	launch.grab_focus.call_deferred()


func _start_survival() -> void:
	Game.mode = "survival"
	Game.current_level = 0
	Game.change_scene("res://scenes/game.tscn")


# ---------------------------------------------------------------- Hangar y Arsenal
func _open_hangar() -> void:
	var v := UI.vbox(12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(UI.title("HANGAR Y ARSENAL", 38, Color("ffd24d")))

	var cols := UI.hbox(20)
	cols.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(cols)

	# Columna izquierda: Mejoras permanentes
	var upg_panel := UI.panel(Vector2(550, 430), Color("4df0ff"), 16)
	var uv := UI.vbox(8)
	upg_panel.add_child(uv)
	uv.add_child(UI.title("MEJORAS DE LA NAVE", 24, Color("4df0ff")))

	var upg_scroll := ScrollContainer.new()
	upg_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	upg_scroll.custom_minimum_size = Vector2(510, 350)
	uv.add_child(upg_scroll)

	var upg_list := UI.vbox(8)
	upg_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upg_scroll.add_child(upg_list)

	for i in Game.UPGRADES.size():
		var u: Dictionary = Game.UPGRADES[i]
		var cur := Game.upg(u.id)
		var max_lvl := int(u.max)
		var cost := Game.upgrade_cost(i)

		var row := UI.hbox(10)
		var left := UI.vbox(2)
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.add_child(UI.label("%s (%d/%d)" % [String(u.name), cur, max_lvl], 17, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT))
		left.add_child(UI.label(String(u.desc), 14, Color(0.7, 0.82, 0.95), HORIZONTAL_ALIGNMENT_LEFT))
		left.add_child(UI.pips_widget(cur, max_lvl, Color("4df0ff")))
		row.add_child(left)

		var can_buy := cur < max_lvl and int(Game.data.credits) >= cost
		var btn_txt := "MÁXIMO" if cur >= max_lvl else "MEJORAR (%d CR)" % cost
		var buy_btn := UI.button(btn_txt, func():
			if Game.upg(u.id) < max_lvl and int(Game.data.credits) >= cost:
				Game.data.credits = int(Game.data.credits) - cost
				Game.data.upgrades[u.id] = Game.upg(u.id) + 1
				Sfx.play("buy")
				Game.save_game()
				_open_hangar()
		, 175, 42)
		buy_btn.disabled = not can_buy
		row.add_child(buy_btn)
		upg_list.add_child(row)

	cols.add_child(upg_panel)

	# Columna derecha: Arsenal de armas
	var wep_panel := UI.panel(Vector2(550, 430), Color("ff4df0"), 16)
	var wv := UI.vbox(8)
	wep_panel.add_child(wv)
	wv.add_child(UI.title("ARSENAL DE ARMAS", 24, Color("ff4df0")))

	var wep_scroll := ScrollContainer.new()
	wep_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wep_scroll.custom_minimum_size = Vector2(510, 350)
	wv.add_child(wep_scroll)

	var wep_list := UI.vbox(8)
	wep_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wep_scroll.add_child(wep_list)

	for i in Game.WEAPONS.size():
		var w: Dictionary = Game.WEAPONS[i]
		var owned := Game.weapon_unlocked(i)
		var cost := int(w.cost)
		var row := UI.hbox(10)
		var left := UI.vbox(2)
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.add_child(UI.label("[%d] %s" % [i + 1, String(w.name)], 18, w.color, HORIZONTAL_ALIGNMENT_LEFT))
		left.add_child(UI.label(String(w.desc), 14, Color(0.75, 0.85, 0.95), HORIZONTAL_ALIGNMENT_LEFT))
		var ammo_txt := "Infinita" if int(w.ammo) < 0 else str(int(w.ammo))
		left.add_child(UI.label("Daño: %dx%d  |  Cadencia: %.1f/s  |  Munición: %s" % [int(w.dmg), int(w.count), 1.0 / float(w.rate), ammo_txt], 13, Color(0.6, 0.72, 0.85), HORIZONTAL_ALIGNMENT_LEFT))
		row.add_child(left)

		var btn_txt := "EQUIPADA" if owned else "COMPRAR (%d CR)" % cost
		var w_btn := UI.button(btn_txt, func():
			if not owned and int(Game.data.credits) >= cost:
				Game.data.credits = int(Game.data.credits) - cost
				Sfx.play("buy")
				Game.unlock_weapon(String(w.id))
				_open_hangar()
		, 175, 42)
		w_btn.disabled = owned or int(Game.data.credits) < cost
		row.add_child(w_btn)
		wep_list.add_child(row)

	cols.add_child(wep_panel)

	var back := UI.button("VOLVER AL MENÚ", _open_home, 280, 44)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(back)
	_show_view(v)
	back.grab_focus.call_deferred()


# ---------------------------------------------------------------- Récords y Logros
func _open_records() -> void:
	var v := UI.vbox(12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(UI.title("RÉCORDS, ESTADÍSTICAS Y LOGROS", 36, Color("4df0ff")))

	var cols := UI.hbox(20)
	cols.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(cols)

	# Panel izquierdo: Récords de supervivencia y estadísticas
	var rec_panel := UI.panel(Vector2(540, 420), Color("4df0ff"), 16)
	var rv := UI.vbox(8)
	rec_panel.add_child(rv)
	rv.add_child(UI.title("TOP SUPERVIVENCIA", 22, Color("4df0ff")))

	var scores: Array = Game.data.survival_scores
	if scores.is_empty():
		rv.add_child(UI.label("Aún no hay registros en Supervivencia.", 16, Color(0.65, 0.75, 0.85), HORIZONTAL_ALIGNMENT_LEFT))
	else:
		for i in mini(scores.size(), 6):
			var s: Dictionary = scores[i]
			var d_idx := clampi(int(s.get("diff", 1)), 0, Game.DIFFICULTIES.size() - 1)
			var d_name := String(Game.DIFFICULTIES[d_idx].name)
			rv.add_child(_stat_row(
				"#%d  %s (%s)" % [i + 1, String(s.get("name", "PILOTO")), d_name],
				"Ronda %d — %d pts" % [int(s.get("round", 1)), int(s.get("score", 0))],
				Color("ffd24d") if i == 0 else Color(0.85, 0.92, 1.0)
			))

	rv.add_child(UI.spacer(6))
	rv.add_child(UI.title("ESTADÍSTICAS GLOBALES", 22, Color("ff4df0")))
	var st: Dictionary = Game.data.stats
	rv.add_child(_stat_row("Hostiles destruidos", "%d" % int(st.kills), Color("4df0ff")))
	rv.add_child(_stat_row("Jefes derrotados", "%d" % int(st.bosses), Color("ff4d6a")))
	rv.add_child(_stat_row("Misiones jugadas", "%d" % int(st.games), Color("7dff6b")))
	rv.add_child(_stat_row("Mejor ronda en Supervivencia", "Ronda %d" % int(st.best_round), Color("ffd24d")))
	var mins := int(float(st.playtime) / 60.0)
	rv.add_child(_stat_row("Tiempo de combate", "%d min" % mins, Color(0.85, 0.95, 1.0)))
	cols.add_child(rec_panel)

	# Panel derecho: 12 Logros
	var ach_panel := UI.panel(Vector2(560, 420), Color("ffd24d"), 16)
	var av := UI.vbox(8)
	ach_panel.add_child(av)
	av.add_child(UI.title("LOGROS (%d / %d)" % [Game.data.achievements.size(), Game.ACHIEVEMENTS.size()], 22, Color("ffd24d")))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(520, 340)
	av.add_child(scroll)

	var alist := UI.vbox(8)
	alist.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(alist)

	for a in Game.ACHIEVEMENTS:
		var done := Game.has_achievement(a.id)
		var row := UI.hbox(10)
		var badge := UI.label("[OK]" if done else "[  ]", 17, Color("4dff88") if done else Color(0.45, 0.5, 0.58), HORIZONTAL_ALIGNMENT_LEFT)
		row.add_child(badge)
		var vb := UI.vbox(1)
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_child(UI.label(String(a.name), 17, Color("ffd24d") if done else Color(0.6, 0.65, 0.72), HORIZONTAL_ALIGNMENT_LEFT))
		vb.add_child(UI.label(String(a.desc), 14, Color(0.8, 0.88, 0.95) if done else Color(0.45, 0.5, 0.58), HORIZONTAL_ALIGNMENT_LEFT))
		row.add_child(vb)
		alist.add_child(row)

	cols.add_child(ach_panel)

	var bottom := UI.hbox(16)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	var back := UI.button("VOLVER AL MENÚ", _open_home, 260, 44)
	bottom.add_child(back)
	var reset_btn := UI.button("REINICIAR PROGRESO", func():
		Game.reset_progress()
		_selected_level = 0
		Game.toast("PROGRESO REINICIADO", "Datos restaurados de fábrica", Color("ff4d6a"))
		_open_records()
	, 260, 44)
	bottom.add_child(reset_btn)
	v.add_child(bottom)
	_show_view(v)
	back.grab_focus.call_deferred()


# ---------------------------------------------------------------- Manual y Controles
func _open_help() -> void:
	var p := UI.panel(Vector2(1020, 470), Color("4df0ff"), 22)
	var v := UI.vbox(12)
	p.add_child(v)
	v.add_child(UI.title("MANUAL DE COMBATE Y CONTROLES", 34, Color("4df0ff")))

	var cols := UI.hbox(24)
	v.add_child(cols)

	var c1 := UI.vbox(8)
	c1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c1.add_child(UI.title("CONTROLES", 22, Color("ff4df0")))
	c1.add_child(_stat_row("Mover la nave", "W, A, S, D / Flechas / Stick Izq.", Color("4df0ff")))
	c1.add_child(_stat_row("Apuntar", "Cursor del Ratón", Color("4df0ff")))
	c1.add_child(_stat_row("Disparar arma activa", "Clic Izquierdo / Gatillo RT", Color("4df0ff")))
	c1.add_child(_stat_row("Dash Cuántico (Invulnerable)", "Espacio / Shift / Botón A", Color("7dff6b")))
	c1.add_child(_stat_row("Detonar Bomba EMP", "F / Clic Derecho / Botón Y", Color("ffd24d")))
	c1.add_child(_stat_row("Cambiar de arma", "Teclas 1-6 / Q y E / Rueda ratón", Color("c46bff")))
	c1.add_child(_stat_row("Pausar partida", "ESC / P / Start", Color(0.85, 0.95, 1.0)))
	cols.add_child(c1)

	var c2 := UI.vbox(8)
	c2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c2.add_child(UI.title("SISTEMAS TÁCTICOS", 22, Color("ffd24d")))
	c2.add_child(UI.wrap_label(
		"• CAMPAÑA: Supera 9 sectores galácticos y derrota a 3 grandes jefes (Coloso de Hierro, Reina del Enjambre y Núcleo Omega) para desbloquear nuevas armas.\n" +
		"• SUPERVIVENCIA: Rondas infinitas con dificultad creciente, suministros cada 3 rondas y jefes cada 5 rondas.\n" +
		"• CARTAS TÁCTICAS: Al superar oleadas o rondas podrás elegir 1 de 3 mejoras roguelite (disparo múltiple, perforación, robo de vida, críticos y más).\n" +
		"• MULTIPLICADOR: Destruye enemigos rápidamente sin recibir daño para subir el combo hasta x8 y multiplicar tus puntos y créditos.",
		15, 470, Color(0.82, 0.92, 1.0)
	))
	cols.add_child(c2)

	var back := UI.button("VOLVER AL MENÚ", _open_home, 280, 44)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(back)
	_show_view(p)
	back.grab_focus.call_deferred()


# ---------------------------------------------------------------- Opciones
func _open_options() -> void:
	var p := UI.panel(Vector2(680, 0), Color("4df0ff"), 24)
	var opt := OptionsPanel.new()
	opt.closed.connect(_open_home)
	p.add_child(opt)
	_show_view(p)
