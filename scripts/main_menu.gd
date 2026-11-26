extends Control
## Menú principal completo: Inicio, Selección de Sector (Campaña), Supervivencia,
## Hangar y Arsenal, Récords y Logros, Manual de Controles y Opciones.

const UI = preload("res://scripts/ui.gd")
const Background = preload("res://scripts/background.gd")
const OptionsPanel = preload("res://scripts/options_panel.gd")

const UPGRADE_COLORS := {
	"hp": Color("4dff88"),
	"dmg": Color("ff4d6a"),
	"rate": Color("ff9b3d"),
	"speed": Color("7dff6b"),
	"shield": Color("4d8bff"),
	"magnet": Color("4df0ff"),
	"bomb": Color("ff4df0"),
	"dash": Color("4df0ff"),
}

var _top_pilot: Label
var _top_diff: Button
var _top_credits: Label
var _top_ach: Label
var _content: CenterContainer
var _selected_level := 0
var _current_view := "home"
var _hangar_upg_scroll := 0
var _hangar_wep_scroll := 0
var _confirm_reset := false
var _reset_btn: Button = null


func _ready() -> void:
	Sfx.play_music("menu")
	_selected_level = clampi(int(Game.data.unlocked_level), 0, Game.LEVELS.size() - 1)

	var bg := Background.new()
	bg.menu_mode = true
	add_child(bg)

	var safe_wrap := MarginContainer.new()
	safe_wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ins := Game.get_safe_insets()
	safe_wrap.add_theme_constant_override("margin_left", int(ins.left))
	safe_wrap.add_theme_constant_override("margin_right", int(ins.right))
	safe_wrap.add_theme_constant_override("margin_top", int(ins.top))
	safe_wrap.add_theme_constant_override("margin_bottom", int(ins.bottom))
	add_child(safe_wrap)

	var root := UI.vbox(0)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	safe_wrap.add_child(root)

	root.add_child(_build_top_bar())

	_content = CenterContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_content)

	root.add_child(_build_footer())
	_open_home()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _current_view != "home":
			Sfx.play("click")
			_open_home()


func _build_top_bar() -> Control:
	var bar := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.04, 0.1, 0.88)
	sb.border_color = Color("4df0ff").darkened(0.35)
	sb.border_width_bottom = 2
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	bar.add_theme_stylebox_override("panel", sb)

	var h := UI.hbox(18)
	bar.add_child(h)

	_top_pilot = UI.label("", 17, Color("4df0ff"), HORIZONTAL_ALIGNMENT_LEFT)
	h.add_child(_top_pilot)

	_top_diff = UI.button("", func():
		Game.settings.difficulty = (int(Game.settings.difficulty) + 1) % Game.DIFFICULTIES.size()
		Game.save_game()
		_refresh_top_bar()
	, 210, 32)
	_top_diff.add_theme_font_size_override("font_size", 15)
	h.add_child(_top_diff)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(spacer)

	_top_ach = UI.label("", 16, Color(0.8, 0.9, 1.0), HORIZONTAL_ALIGNMENT_RIGHT)
	h.add_child(_top_ach)

	_top_credits = UI.label("", 18, Color("ffd24d"), HORIZONTAL_ALIGNMENT_RIGHT)
	h.add_child(_top_credits)

	_refresh_top_bar()
	return bar


func _build_footer() -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 20)
	m.add_theme_constant_override("margin_right", 20)
	m.add_theme_constant_override("margin_bottom", 6)
	var h := UI.hbox(16)
	m.add_child(h)
	var hint_txt := "Joystick Izq: Mover  |  Joystick Der / Auto: Apuntar y Disparar  |  Borde Der: Dash y EMP  |  Inferior: Armas" if Game.is_mobile() else "WASD: Mover  |  Ratón: Apuntar y Disparar  |  Espacio: Dash  |  F / Clic Der: Bomba EMP"
	var left := UI.label(hint_txt, 13 if Game.is_mobile() else 14, Color(0.65, 0.78, 0.9), HORIZONTAL_ALIGNMENT_LEFT)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(left)
	h.add_child(UI.label("%s %s — %s" % [Game.TITLE, Game.SUBTITLE, Game.VERSION], 13, Color(0.55, 0.68, 0.82), HORIZONTAL_ALIGNMENT_RIGHT))
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


func _pulse_credits() -> void:
	if not _top_credits:
		return
	var tw := _top_credits.create_tween()
	_top_credits.modulate = Color("ff9b3d")
	tw.tween_property(_top_credits, "modulate", Color.WHITE, 0.45)


func _show_view(node: Control, instant: bool = false) -> void:
	for c in _content.get_children():
		c.queue_free()
	_refresh_top_bar()
	_content.add_child(node)
	if not instant:
		node.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(node, "modulate:a", 1.0, 0.16)


func _format_dmg(val: float) -> String:
	if absf(val - round(val)) < 0.05:
		return str(int(round(val)))
	return "%.1f" % val


# ---------------------------------------------------------------- Inicio
func _open_home() -> void:
	_current_view = "home"
	_confirm_reset = false
	var v := UI.vbox(10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER

	v.add_child(UI.title(Game.TITLE, 64, Color("4df0ff")))
	v.add_child(UI.title(Game.SUBTITLE, 26, Color("ff4df0")))
	v.add_child(UI.spacer(4))

	var cols := UI.hbox(26)
	cols.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(cols)

	# Panel de navegación principal
	var nav_panel := UI.panel(Vector2(380, 0), Color("4df0ff"), 18)
	var nav := UI.vbox(9)
	nav_panel.add_child(nav)

	var btn_camp := UI.button("CAMPAÑA GALÁCTICA", _open_campaign, 340, 44)
	nav.add_child(btn_camp)
	nav.add_child(UI.button("SUPERVIVENCIA (RONDAS)", _start_survival, 340, 44))
	nav.add_child(UI.button("HANGAR Y ARSENAL", func(): _open_hangar(false), 340, 42))
	nav.add_child(UI.button("RÉCORDS Y LOGROS", _open_records, 340, 42))
	nav.add_child(UI.button("MANUAL Y CONTROLES", _open_help, 340, 42))
	nav.add_child(UI.button("OPCIONES", _open_options, 340, 42))
	if DisplayServer.get_name() != "web":
		nav.add_child(UI.button("SALIR DEL JUEGO", func(): get_tree().quit(), 340, 40))
	cols.add_child(nav_panel)

	# Panel de resumen de estado del piloto
	var info_panel := UI.panel(Vector2(420, 0), Color("ff4df0"), 18)
	var info := UI.vbox(9)
	info_panel.add_child(info)
	info.add_child(UI.title("ESTADO DE LA FLOTA", 24, Color("ff4df0")))

	var unlocked_sectors := mini(int(Game.data.unlocked_level) + 1, Game.LEVELS.size())
	var total_stars := 0
	for k in Game.data.stars:
		total_stars += int(Game.data.stars[k])

	info.add_child(_stat_row("Sectores desbloqueados", "%d / %d" % [unlocked_sectors, Game.LEVELS.size()], Color("4df0ff")))
	info.add_child(_stat_row("Estrellas de campaña", "%d / %d" % [total_stars, Game.LEVELS.size() * 3], Color("ffd24d")))
	info.add_child(_stat_row("Armas en arsenal", "%d / %d" % [Game.data.weapons.size(), Game.WEAPONS.size()], Color("7dff6b")))
	info.add_child(_stat_row("Mejor ronda Supervivencia", "Ronda %d" % int(Game.data.stats.best_round), Color("ff9b3d")))
	info.add_child(_stat_row("Enemigos eliminados", "%d" % int(Game.data.stats.kills), Color(0.85, 0.95, 1.0)))

	info.add_child(UI.spacer(4))
	var d := Game.difficulty()
	info.add_child(UI.label("MODO DE DIFICULTAD: %s" % String(d.name).to_upper(), 17, d.color, HORIZONTAL_ALIGNMENT_LEFT))
	info.add_child(UI.wrap_label(
		"Vida enemiga x%.1f  |  Daño enemigo x%.1f\nPuntos x%.1f  |  Créditos x%.1f" % [float(d.hp), float(d.dmg), float(d.score), float(d.credits)],
		14, 370, Color(0.75, 0.85, 0.95)
	))
	var diff_btn := UI.button("CAMBIAR DIFICULTAD", func():
		Game.settings.difficulty = (int(Game.settings.difficulty) + 1) % Game.DIFFICULTIES.size()
		Game.save_game()
		_open_home()
	, 370, 40)
	info.add_child(diff_btn)
	cols.add_child(info_panel)

	_show_view(v)
	btn_camp.grab_focus.call_deferred()


func _stat_row(k: String, val: String, col: Color, font_size: int = 16) -> Control:
	var h := UI.hbox(8)
	var l1 := UI.label(k, font_size, Color(0.78, 0.88, 0.96), HORIZONTAL_ALIGNMENT_LEFT)
	l1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l1)
	h.add_child(UI.label(val, font_size + 1, col, HORIZONTAL_ALIGNMENT_RIGHT))
	return h


# ---------------------------------------------------------------- Campaña
func _open_campaign() -> void:
	_current_view = "campaign"
	var v := UI.vbox(10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(UI.title("CAMPAÑA GALÁCTICA — SECTORES", 34, Color("4df0ff")))

	var cols := UI.hbox(20)
	cols.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(cols)

	# Cuadrícula de 9 sectores
	var grid_panel := UI.panel(Vector2(660, 404), Color("4df0ff"), 14)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid_panel.add_child(grid)

	for i in Game.LEVELS.size():
		var lvl: Dictionary = Game.LEVELS[i]
		var unlocked := i <= int(Game.data.unlocked_level)
		var is_sel := i == _selected_level
		var card := UI.panel(Vector2(202, 118), lvl.color if is_sel else (lvl.color.darkened(0.45) if unlocked else Color(0.25, 0.25, 0.3)), 9)
		var cv := UI.vbox(4)
		card.add_child(cv)

		var head := UI.hbox(6)
		var num_lbl := UI.label("SECTOR 0%d" % (i + 1), 13, lvl.color if unlocked else Color(0.5, 0.5, 0.55), HORIZONTAL_ALIGNMENT_LEFT)
		num_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(num_lbl)
		if String(lvl.boss) != "":
			head.add_child(UI.label("[JEFE]", 12, Color("ff4d6a"), HORIZONTAL_ALIGNMENT_RIGHT))
		cv.add_child(head)

		var name_txt := String(lvl.name) if unlocked else "BLOQUEADO"
		cv.add_child(UI.label(name_txt, 16, Color.WHITE if unlocked else Color(0.45, 0.45, 0.5), HORIZONTAL_ALIGNMENT_LEFT))

		var stars := int(Game.data.stars.get(i, Game.data.stars.get(str(i), 0)))
		var st_row := UI.hbox(6)
		st_row.add_child(UI.stars_widget(stars, 3, 15.0))
		cv.add_child(st_row)

		var select_btn := UI.action_button(
			"SELECCIONADO" if is_sel else ("VER SECTOR" if unlocked else "CERRADO"),
			func():
				_selected_level = i
				_open_campaign(),
			178, 30, lvl.color if is_sel else Color("4df0ff").darkened(0.3), 13
		)
		select_btn.disabled = not unlocked
		cv.add_child(select_btn)
		grid.add_child(card)

	cols.add_child(grid_panel)

	# Panel de informe de misión
	var lvl_sel: Dictionary = Game.LEVELS[_selected_level]
	var brief_panel := UI.panel(Vector2(430, 404), lvl_sel.color, 16)
	var bv := UI.vbox(7)
	brief_panel.add_child(bv)

	bv.add_child(UI.label("INFORME DE MISIÓN — SECTOR 0%d" % (_selected_level + 1), 14, lvl_sel.color, HORIZONTAL_ALIGNMENT_LEFT))
	bv.add_child(UI.title(String(lvl_sel.name).to_upper(), 26, lvl_sel.color))
	bv.add_child(UI.wrap_label(String(lvl_sel.desc), 15, 390, Color(0.85, 0.92, 1.0)))
	bv.add_child(UI.spacer(2))

	var enemy_names: Array = []
	for e_id in lvl_sel.pool:
		enemy_names.append(String(Game.ENEMY_NAMES.get(e_id, e_id)))
	bv.add_child(_stat_row("Oleadas de asalto", "%d oleadas" % int(lvl_sel.waves), Color("4df0ff"), 15))
	bv.add_child(_stat_row("Hostiles", ", ".join(enemy_names), Color(0.85, 0.9, 1.0), 14))
	if String(lvl_sel.boss) != "":
		bv.add_child(_stat_row("Amenaza principal", String(Game.BOSS_NAMES.get(lvl_sel.boss, "JEFE")), Color("ff4d6a"), 15))
	bv.add_child(_stat_row("Recompensa base", "+%d CR" % int(lvl_sel.reward), Color("ffd24d"), 15))

	if String(lvl_sel.unlock) != "":
		var w_name := ""
		for w in Game.WEAPONS:
			if w.id == lvl_sel.unlock:
				w_name = w.name
		bv.add_child(_stat_row("Desbloquea arma", w_name, Color("7dff6b"), 15))

	var best_score := int(Game.data.best.get(_selected_level, Game.data.best.get(str(_selected_level), 0)))
	bv.add_child(_stat_row("Mejor puntuación", "%d pts" % best_score, Color("4df0ff"), 15))

	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bv.add_child(sp)

	var launch := UI.button("DESPLEGAR EN SECTOR 0%d" % (_selected_level + 1), func():
		Game.mode = "campaign"
		Game.current_level = _selected_level
		Game.change_scene("res://scenes/game.tscn")
	, 390, 46)
	bv.add_child(launch)
	cols.add_child(brief_panel)

	var bottom := UI.hbox(16)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_child(UI.button("VOLVER AL MENÚ", _open_home, 250, 40))
	bottom.add_child(UI.button("IR AL HANGAR", func(): _open_hangar(false), 250, 40))
	v.add_child(bottom)

	_show_view(v)
	launch.grab_focus.call_deferred()


func _start_survival() -> void:
	Game.mode = "survival"
	Game.current_level = 0
	Game.change_scene("res://scenes/game.tscn")


# ---------------------------------------------------------------- Hangar y Arsenal
func _open_hangar(preserve_scroll: bool = false) -> void:
	_current_view = "hangar"
	if not preserve_scroll:
		_hangar_upg_scroll = 0
		_hangar_wep_scroll = 0

	var v := UI.vbox(10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER

	# Cabecera con título, saldo en vivo y progreso total del Hangar
	var total_upg := 0
	var max_upg := 0
	for u in Game.UPGRADES:
		total_upg += Game.upg(u.id)
		max_upg += int(u.max)

	var head := UI.hbox(18)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(UI.title("HANGAR Y ARSENAL", 34, Color("ffd24d")))
	head.add_child(UI.pill("SALDO: %d CR" % int(Game.data.credits), Color("ffd24d"), 15))
	head.add_child(UI.pill("MEJORAS %d/%d  •  ARMAS %d/%d" % [total_upg, max_upg, Game.data.weapons.size(), Game.WEAPONS.size()], Color("4df0ff"), 13))
	v.add_child(head)

	var cols := UI.hbox(18)
	cols.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(cols)

	# --- Columna izquierda: Mejoras permanentes ---
	var upg_panel := UI.panel(Vector2(560, 412), Color("4df0ff"), 12)
	var uv := UI.vbox(8)
	upg_panel.add_child(uv)

	var uh := UI.hbox(8)
	var utitle := UI.title("MEJORAS DE LA NAVE", 22, Color("4df0ff"))
	utitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	uh.add_child(utitle)
	uh.add_child(UI.pill("%d / %d" % [total_upg, max_upg], Color("4df0ff"), 12))
	uv.add_child(uh)

	var upg_scroll := ScrollContainer.new()
	upg_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	upg_scroll.custom_minimum_size = Vector2(530, 344)
	upg_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	upg_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	uv.add_child(upg_scroll)

	var upg_margin := MarginContainer.new()
	upg_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upg_margin.add_theme_constant_override("margin_right", 12)
	upg_margin.add_theme_constant_override("margin_top", 2)
	upg_margin.add_theme_constant_override("margin_bottom", 4)
	upg_scroll.add_child(upg_margin)

	var upg_list := UI.vbox(8)
	upg_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upg_margin.add_child(upg_list)

	# --- Columna derecha: Arsenal de armas ---
	var wep_panel := UI.panel(Vector2(560, 412), Color("ff4df0"), 12)
	var wv := UI.vbox(8)
	wep_panel.add_child(wv)

	var wh := UI.hbox(8)
	var wtitle := UI.title("ARSENAL DE ARMAS", 22, Color("ff4df0"))
	wtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wh.add_child(wtitle)
	wh.add_child(UI.pill("%d / %d" % [Game.data.weapons.size(), Game.WEAPONS.size()], Color("ff4df0"), 12))
	wv.add_child(wh)

	var wep_scroll := ScrollContainer.new()
	wep_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wep_scroll.custom_minimum_size = Vector2(530, 344)
	wep_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	wep_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	wv.add_child(wep_scroll)

	var wep_margin := MarginContainer.new()
	wep_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wep_margin.add_theme_constant_override("margin_right", 12)
	wep_margin.add_theme_constant_override("margin_top", 2)
	wep_margin.add_theme_constant_override("margin_bottom", 4)
	wep_scroll.add_child(wep_margin)

	var wep_list := UI.vbox(8)
	wep_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wep_margin.add_child(wep_list)

	# Poblar tarjetas de mejoras
	for i in Game.UPGRADES.size():
		var u: Dictionary = Game.UPGRADES[i]
		var uid := String(u.id)
		var cur := Game.upg(uid)
		var max_lvl := int(u.max)
		var cost := Game.upgrade_cost(i)
		var maxed := cur >= max_lvl
		var can_buy := not maxed and int(Game.data.credits) >= cost
		var accent: Color = UPGRADE_COLORS.get(uid, Color("4df0ff"))

		var card := UI.item_card(Color("ffd24d") if maxed else accent, maxed or can_buy, 10, 7)
		var row := UI.hbox(10)
		card.add_child(row)

		row.add_child(UI.icon_badge(uid, Color("ffd24d") if maxed else accent, 36.0, true))

		var mid := UI.vbox(3)
		mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title_row := UI.hbox(6)
		var name_lbl := UI.label(String(u.name), 15, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_row.add_child(name_lbl)
		title_row.add_child(UI.pill("MÁX" if maxed else "Nv. %d/%d" % [cur, max_lvl], Color("ffd24d") if maxed else accent, 11))
		mid.add_child(title_row)

		mid.add_child(UI.wrap_label(String(u.desc), 12, 0.0, Color(0.75, 0.86, 0.96)))
		mid.add_child(UI.pips_widget(cur, max_lvl, Color("ffd24d") if maxed else accent))
		row.add_child(mid)

		var btn_txt := "★ MÁXIMO" if maxed else "MEJORAR\n%d CR" % cost
		var btn_border := Color("ffd24d") if maxed else (accent if can_buy else Color(0.35, 0.38, 0.48))
		var btn_fill := Color(0.05, 0.14, 0.22, 0.95) if can_buy else Color(0.04, 0.06, 0.11, 0.85)
		var buy_btn := UI.action_button(btn_txt, func():
			if Game.upg(uid) < max_lvl and int(Game.data.credits) >= cost:
				_hangar_upg_scroll = upg_scroll.scroll_vertical
				_hangar_wep_scroll = wep_scroll.scroll_vertical
				Game.data.credits = int(Game.data.credits) - cost
				var new_lvl := Game.upg(uid) + 1
				Game.data.upgrades[uid] = new_lvl
				Sfx.play("buy")
				Game.haptic(22)
				Game.save_game()
				_pulse_credits()
				Game.toast(
					"MEJORA INSTALADA",
					"%s  →  Nv. %d/%d" % [String(u.name), new_lvl, max_lvl],
					Color("ffd24d") if new_lvl >= max_lvl else accent,
					"-%d CR  •  Saldo: %d CR" % [cost, int(Game.data.credits)],
					uid
				)
				_open_hangar(true)
		, 122, 42, btn_border, 12, btn_fill)
		buy_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		buy_btn.disabled = not can_buy
		if maxed:
			buy_btn.add_theme_color_override("font_disabled_color", Color("ffd24d"))
		elif not can_buy:
			buy_btn.add_theme_color_override("font_disabled_color", Color(0.68, 0.45, 0.5))
		row.add_child(buy_btn)
		upg_list.add_child(card)

	# Poblar tarjetas de armas (cero desbordamiento horizontal)
	for i in Game.WEAPONS.size():
		var w: Dictionary = Game.WEAPONS[i]
		var wid := String(w.id)
		var owned := Game.weapon_unlocked(i)
		var cost := int(w.cost)
		var can_buy := not owned and int(Game.data.credits) >= cost
		var wcol: Color = w.color

		var card := UI.item_card(wcol, owned or can_buy, 10, 7)
		var row := UI.hbox(10)
		card.add_child(row)

		# Insignia numérica del arma
		var slot_badge := PanelContainer.new()
		slot_badge.custom_minimum_size = Vector2(34, 34)
		slot_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var sbs := StyleBoxFlat.new()
		sbs.bg_color = Color(wcol.r * 0.22, wcol.g * 0.22, wcol.b * 0.22, 0.95)
		sbs.border_color = wcol if owned else Color(wcol, 0.45)
		sbs.set_border_width_all(2)
		sbs.set_corner_radius_all(8)
		slot_badge.add_theme_stylebox_override("panel", sbs)
		var num_l := UI.label(str(i + 1), 16, wcol.lightened(0.2))
		num_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot_badge.add_child(num_l)
		row.add_child(slot_badge)

		var mid := UI.vbox(2)
		mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_l := UI.label(String(w.name), 15, wcol.lightened(0.1), HORIZONTAL_ALIGNMENT_LEFT)
		mid.add_child(name_l)
		mid.add_child(UI.wrap_label(String(w.desc), 12, 0.0, Color(0.78, 0.88, 0.96)))

		var dmg_str := _format_dmg(float(w.dmg))
		if int(w.count) > 1:
			dmg_str += "x%d" % int(w.count)
		var ammo_txt := "∞" if int(w.ammo) < 0 else str(int(w.ammo))
		mid.add_child(UI.wrap_label(
			"Daño %s  •  %.1f/s  •  Mun. %s" % [dmg_str, 1.0 / float(w.rate), ammo_txt],
			12, 0.0, Color(0.62, 0.76, 0.9)
		))
		row.add_child(mid)

		var btn_txt := "✓ EQUIPADA" if owned else "COMPRAR\n%d CR" % cost
		var btn_border := Color("4dff88") if owned else (wcol if can_buy else Color(0.35, 0.38, 0.48))
		var btn_fill := Color(0.14, 0.06, 0.2, 0.95) if can_buy else Color(0.04, 0.06, 0.11, 0.85)
		var w_btn := UI.action_button(btn_txt, func():
			if not owned and int(Game.data.credits) >= cost:
				_hangar_upg_scroll = upg_scroll.scroll_vertical
				_hangar_wep_scroll = wep_scroll.scroll_vertical
				Game.data.credits = int(Game.data.credits) - cost
				Sfx.play("buy")
				Game.haptic(28)
				Game.unlock_weapon(wid, false)
				_pulse_credits()
				Game.toast(
					"ARMA ADQUIRIDA",
					"%s lista en tu arsenal" % String(w.name),
					wcol,
					"-%d CR  •  Saldo: %d CR" % [cost, int(Game.data.credits)],
					"weapon"
				)
				_open_hangar(true)
		, 122, 42, btn_border, 12, btn_fill)
		w_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		w_btn.disabled = owned or not can_buy
		if owned:
			w_btn.add_theme_color_override("font_disabled_color", Color("4dff88"))
		elif not can_buy:
			w_btn.add_theme_color_override("font_disabled_color", Color(0.68, 0.45, 0.5))
		row.add_child(w_btn)
		wep_list.add_child(card)

	cols.add_child(upg_panel)
	cols.add_child(wep_panel)

	var bottom := UI.hbox(16)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	var back := UI.button("VOLVER AL MENÚ", _open_home, 250, 40)
	bottom.add_child(back)
	bottom.add_child(UI.button("IR A CAMPAÑA", _open_campaign, 250, 40))
	v.add_child(bottom)

	_show_view(v, preserve_scroll)
	if preserve_scroll:
		upg_scroll.set_deferred("scroll_vertical", _hangar_upg_scroll)
		wep_scroll.set_deferred("scroll_vertical", _hangar_wep_scroll)
	else:
		back.grab_focus.call_deferred()


# ---------------------------------------------------------------- Récords y Logros
func _open_records() -> void:
	_current_view = "records"
	_confirm_reset = false

	var v := UI.vbox(10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(UI.title("RÉCORDS, ESTADÍSTICAS Y LOGROS", 32, Color("4df0ff")))

	var cols := UI.hbox(18)
	cols.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(cols)

	# --- Panel izquierdo: Top Supervivencia y Estadísticas Globales ---
	var rec_panel := UI.panel(Vector2(548, 412), Color("4df0ff"), 14)
	var rv := UI.vbox(8)
	rec_panel.add_child(rv)

	var top_h := UI.hbox(8)
	var top_t := UI.title("TOP SUPERVIVENCIA", 21, Color("4df0ff"))
	top_t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_h.add_child(top_t)
	var scores: Array = Game.data.survival_scores
	top_h.add_child(UI.pill("TOP %d" % scores.size(), Color("4df0ff"), 11))
	rv.add_child(top_h)

	var top_scroll := ScrollContainer.new()
	top_scroll.custom_minimum_size = Vector2(516, 148)
	top_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	top_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	rv.add_child(top_scroll)

	var top_margin := MarginContainer.new()
	top_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_margin.add_theme_constant_override("margin_right", 10)
	top_scroll.add_child(top_margin)

	var top_list := UI.vbox(6)
	top_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_margin.add_child(top_list)

	if scores.is_empty():
		var empty_card := UI.item_card(Color("4df0ff"), false, 12, 10)
		var ev := UI.vbox(4)
		ev.add_child(UI.wrap_label("Aún no hay registros guardados en el ranking de Supervivencia.", 14, 0.0, Color(0.75, 0.85, 0.95)))
		var br := int(Game.data.stats.best_round)
		if br > 0:
			ev.add_child(UI.wrap_label("Mejor ronda alcanzada hasta ahora: Ronda %d — ¡juega otra partida para fijar tu récord!" % br, 13, 0.0, Color("ffd24d")))
		else:
			ev.add_child(UI.wrap_label("¡Sobrevive oleadas infinitas para inscribir tu nombre en el Top 10!", 13, 0.0, Color(0.58, 0.72, 0.86)))
		empty_card.add_child(ev)
		top_list.add_child(empty_card)
	else:
		for i in scores.size():
			var s: Dictionary = scores[i]
			var d_idx := clampi(int(s.get("diff", 1)), 0, Game.DIFFICULTIES.size() - 1)
			var d_info: Dictionary = Game.DIFFICULTIES[d_idx]
			var medal_col := Color("ffd24d") if i == 0 else (Color(0.82, 0.88, 0.96) if i == 1 else (Color("ff9b3d") if i == 2 else Color("4df0ff")))
			var scard := UI.item_card(medal_col, i < 3, 10, 5)
			var sr := UI.hbox(8)
			sr.add_child(UI.pill("#%d" % (i + 1), medal_col, 12))
			var pname := UI.label(String(s.get("name", "PILOTO")), 14, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
			pname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sr.add_child(pname)
			sr.add_child(UI.pill(String(d_info.name).to_upper(), d_info.color, 10))
			sr.add_child(UI.label("R%d" % int(s.get("round", 1)), 14, Color("ff4df0"), HORIZONTAL_ALIGNMENT_RIGHT))
			sr.add_child(UI.label("%d pts" % int(s.get("score", 0)), 14, medal_col, HORIZONTAL_ALIGNMENT_RIGHT))
			scard.add_child(sr)
			top_list.add_child(scard)

	rv.add_child(UI.title("ESTADÍSTICAS GLOBALES", 20, Color("ff4df0")))
	var st: Dictionary = Game.data.stats
	var mins := int(float(st.playtime) / 60.0)
	var stat_grid := GridContainer.new()
	stat_grid.columns = 2
	stat_grid.add_theme_constant_override("h_separation", 8)
	stat_grid.add_theme_constant_override("v_separation", 7)
	rv.add_child(stat_grid)

	var stat_items := [
		["Hostiles destruidos", "%d" % int(st.kills), Color("4df0ff")],
		["Jefes derrotados", "%d" % int(st.bosses), Color("ff4d6a")],
		["Misiones jugadas", "%d" % int(st.games), Color("7dff6b")],
		["Mejor Supervivencia", "Ronda %d" % int(st.best_round), Color("ffd24d")],
		["Tiempo de combate", "%d min" % mins, Color("c46bff")],
		["Créditos totales", "%d CR" % int(Game.data.credits), Color("ffd24d")],
	]
	for item in stat_items:
		var st_card := UI.item_card(item[2], true, 10, 6)
		var sh := UI.hbox(6)
		var sk := UI.label(String(item[0]), 13, Color(0.78, 0.88, 0.96), HORIZONTAL_ALIGNMENT_LEFT)
		sk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sh.add_child(sk)
		sh.add_child(UI.label(String(item[1]), 15, item[2], HORIZONTAL_ALIGNMENT_RIGHT))
		st_card.add_child(sh)
		stat_grid.add_child(st_card)

	cols.add_child(rec_panel)

	# --- Panel derecho: 12 Logros con barra de progreso y medallas vectoriales ---
	var ach_panel := UI.panel(Vector2(572, 412), Color("ffd24d"), 14)
	var av := UI.vbox(8)
	ach_panel.add_child(av)

	var done_cnt: int = (Game.data.achievements as Array).size()
	var total_ach: int = Game.ACHIEVEMENTS.size()
	var pct: int = int(round(float(done_cnt) / maxf(1.0, float(total_ach)) * 100.0))

	var ah := UI.hbox(8)
	var atitle := UI.title("LOGROS", 21, Color("ffd24d"))
	atitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ah.add_child(atitle)
	ah.add_child(UI.pill("%d / %d" % [done_cnt, total_ach], Color("ffd24d"), 12))
	av.add_child(ah)

	av.add_child(UI.progress_bar(float(done_cnt) / maxf(1.0, float(total_ach)), Color("ffd24d"), 17.0, "%d%% COMPLETADO" % pct))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(540, 310)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	av.add_child(scroll)

	var ach_margin := MarginContainer.new()
	ach_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ach_margin.add_theme_constant_override("margin_right", 12)
	ach_margin.add_theme_constant_override("margin_top", 2)
	ach_margin.add_theme_constant_override("margin_bottom", 4)
	scroll.add_child(ach_margin)

	var alist := UI.vbox(7)
	alist.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ach_margin.add_child(alist)

	for a in Game.ACHIEVEMENTS:
		var done := Game.has_achievement(a.id)
		var acard := UI.item_card(Color("ffd24d") if done else Color(0.35, 0.42, 0.56), done, 10, 7)
		var row := UI.hbox(10)
		acard.add_child(row)

		row.add_child(UI.icon_badge("trophy" if done else "lock", Color("ffd24d"), 36.0, done))

		var vb := UI.vbox(2)
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_child(UI.label(String(a.name), 15, Color("ffd24d") if done else Color(0.68, 0.74, 0.84), HORIZONTAL_ALIGNMENT_LEFT))
		vb.add_child(UI.wrap_label(String(a.desc), 12, 0.0, Color(0.84, 0.92, 0.98) if done else Color(0.5, 0.56, 0.66)))
		row.add_child(vb)

		row.add_child(UI.pill("✓ LOGRO" if done else "BLOQ.", Color("4dff88") if done else Color(0.45, 0.5, 0.62), 11))
		alist.add_child(acard)

	cols.add_child(ach_panel)

	var bottom := UI.hbox(16)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	var back := UI.button("VOLVER AL MENÚ", _open_home, 250, 40)
	bottom.add_child(back)

	_reset_btn = UI.action_button("REINICIAR PROGRESO", func():
		if not _confirm_reset:
			_confirm_reset = true
			if is_instance_valid(_reset_btn):
				_reset_btn.text = "¿CONFIRMAR REINICIO?"
				_reset_btn.modulate = Color("ff4d6a")
			Game.toast("CONFIRMACIÓN REQUERIDA", "Pulsa de nuevo para reiniciar todo", Color("ff4d6a"), "Se borrarán créditos, armas y logros", "warn")
			return
		Game.reset_progress()
		_selected_level = 0
		_confirm_reset = false
		Game.toast("PROGRESO REINICIADO", "Datos restaurados de fábrica", Color("ff4d6a"), "Tu historial ha sido restablecido", "warn")
		_open_records()
	, 250, 40, Color("ff4d6a").darkened(0.25), 15)
	bottom.add_child(_reset_btn)
	v.add_child(bottom)
	_show_view(v)
	back.grab_focus.call_deferred()


# ---------------------------------------------------------------- Manual y Controles
func _open_help() -> void:
	_current_view = "help"
	var p := UI.panel(Vector2(1020, 430), Color("4df0ff"), 20)
	var v := UI.vbox(10)
	p.add_child(v)
	v.add_child(UI.title("MANUAL DE COMBATE Y CONTROLES", 32, Color("4df0ff")))

	var cols := UI.hbox(24)
	v.add_child(cols)

	var c1 := UI.vbox(7)
	c1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if Game.is_mobile():
		c1.add_child(UI.title("CONTROLES TÁCTILES", 21, Color("ff4df0")))
		c1.add_child(_stat_row("Mover la nave", "Zona Izquierda (Joystick flotante)", Color("4df0ff"), 15))
		c1.add_child(_stat_row("Apuntar y Disparar", "Zona Derecha o modo AUTO", Color("4df0ff"), 15))
		c1.add_child(_stat_row("Dash Cuántico", "Botón circular DASH (borde der.)", Color("7dff6b"), 15))
		c1.add_child(_stat_row("Detonar Bomba EMP", "Botón circular EMP (borde der.)", Color("ffd24d"), 15))
		c1.add_child(_stat_row("Cambiar de arma", "Selector inferior ◀ / ▶ o tocar arma", Color("c46bff"), 15))
		c1.add_child(_stat_row("Auto-Disparo", "Botón AUTO junto al selector de arma", Color("4dff88"), 15))
		c1.add_child(_stat_row("Pausar partida", "Botón || superior der. o Atrás", Color(0.85, 0.95, 1.0), 15))
	else:
		c1.add_child(UI.title("CONTROLES", 21, Color("ff4df0")))
		c1.add_child(_stat_row("Mover la nave", "W, A, S, D / Flechas / Stick Izq.", Color("4df0ff"), 15))
		c1.add_child(_stat_row("Apuntar", "Cursor del Ratón", Color("4df0ff"), 15))
		c1.add_child(_stat_row("Disparar arma activa", "Clic Izquierdo / Gatillo RT", Color("4df0ff"), 15))
		c1.add_child(_stat_row("Dash Cuántico (Invulnerable)", "Espacio / Shift / Botón A", Color("7dff6b"), 15))
		c1.add_child(_stat_row("Detonar Bomba EMP", "F / Clic Derecho / Botón Y", Color("ffd24d"), 15))
		c1.add_child(_stat_row("Cambiar de arma", "Teclas 1-6 / Q y E / Rueda ratón", Color("c46bff"), 15))
		c1.add_child(_stat_row("Pausar partida", "ESC / P / Start", Color(0.85, 0.95, 1.0), 15))
	cols.add_child(c1)

	var c2 := UI.vbox(7)
	c2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c2.add_child(UI.title("SISTEMAS TÁCTICOS", 21, Color("ffd24d")))
	c2.add_child(UI.wrap_label(
		"• CAMPAÑA: Supera 9 sectores galácticos y derrota a 3 grandes jefes (Coloso de Hierro, Reina del Enjambre y Núcleo Omega) para desbloquear nuevas armas.\n" +
		"• SUPERVIVENCIA: Rondas infinitas con dificultad creciente, suministros cada 3 rondas y jefes cada 5 rondas.\n" +
		"• CARTAS TÁCTICAS: Al superar oleadas o rondas podrás elegir 1 de 3 mejoras roguelite (disparo múltiple, perforación, robo de vida, críticos y más).\n" +
		"• MULTIPLICADOR: Destruye enemigos rápidamente sin recibir daño para subir el combo hasta x8 y multiplicar tus puntos y créditos.",
		14, 470, Color(0.82, 0.92, 1.0)
	))
	cols.add_child(c2)

	var back := UI.button("VOLVER AL MENÚ", _open_home, 260, 40)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(back)
	_show_view(p)
	back.grab_focus.call_deferred()


# ---------------------------------------------------------------- Opciones
func _open_options() -> void:
	_current_view = "options"
	var p := UI.panel(Vector2(680, 0), Color("4df0ff"), 22)
	var opt := OptionsPanel.new()
	opt.closed.connect(_open_home)
	p.add_child(opt)
	_show_view(p)
