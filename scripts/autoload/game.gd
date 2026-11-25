extends Node
## Estado global: datos del juego, guardado, ajustes, tema visual y transiciones.

const SAVE_PATH := "user://neon_strike_save.sec"
const LEGACY_SAVE_PATH := "user://neon_strike_save.cfg"
const _SECURITY_SALT := "NEON_STRIKE_GALACTIC_ASSAULT_V1_HMAC_KEY_9F4A2C"
const TITLE := "NEON STRIKE"
const SUBTITLE := "ASALTO GALÁCTICO"
const VERSION := "v1.0"

const DIFFICULTIES := [
	{"name": "Recluta", "hp": 0.7, "dmg": 0.6, "score": 0.7, "credits": 0.8, "color": Color("4dff88")},
	{"name": "Soldado", "hp": 1.0, "dmg": 1.0, "score": 1.0, "credits": 1.0, "color": Color("4dd2ff")},
	{"name": "Veterano", "hp": 1.4, "dmg": 1.4, "score": 1.5, "credits": 1.3, "color": Color("ffb84d")},
	{"name": "Pesadilla", "hp": 1.9, "dmg": 2.0, "score": 2.2, "credits": 1.8, "color": Color("ff4d6a")},
]

const WEAPONS := [
	{"id": "blaster", "name": "Bláster", "desc": "Arma de energía estándar. Munición infinita.", "rate": 0.15, "dmg": 11.0, "speed": 950.0, "spread": 0.03, "count": 1, "ammo": -1, "pierce": 0, "size": 5.0, "life": 1.2, "color": Color("4df0ff"), "cost": 0, "sound": "shoot"},
	{"id": "shotgun", "name": "Escopeta Iónica", "desc": "7 perdigones devastadores a corta distancia.", "rate": 0.6, "dmg": 9.0, "speed": 820.0, "spread": 0.55, "count": 7, "ammo": 36, "pierce": 0, "size": 4.0, "life": 0.45, "color": Color("ffd24d"), "cost": 350, "sound": "shotgun"},
	{"id": "smg", "name": "Ametralladora", "desc": "Cadencia altísima, ideal contra enjambres.", "rate": 0.055, "dmg": 6.5, "speed": 1050.0, "spread": 0.13, "count": 1, "ammo": 260, "pierce": 0, "size": 3.5, "life": 0.9, "color": Color("7dff6b"), "cost": 600, "sound": "smg"},
	{"id": "plasma", "name": "Cañón de Plasma", "desc": "Esferas lentas que atraviesan a varios enemigos.", "rate": 0.38, "dmg": 30.0, "speed": 620.0, "spread": 0.0, "count": 1, "ammo": 45, "pierce": 6, "size": 11.0, "life": 1.6, "color": Color("c46bff"), "cost": 1000, "sound": "plasma"},
	{"id": "rocket", "name": "Lanzacohetes", "desc": "Cohetes teledirigidos con daño en área.", "rate": 0.75, "dmg": 45.0, "speed": 520.0, "spread": 0.05, "count": 1, "ammo": 18, "pierce": 0, "size": 7.0, "life": 2.5, "color": Color("ff7a3d"), "explosive": 120.0, "homing": 4.0, "cost": 1500, "sound": "rocket"},
	{"id": "rail", "name": "Railgun", "desc": "Rayo instantáneo que perfora todo a su paso.", "rate": 0.9, "dmg": 85.0, "speed": 0.0, "spread": 0.0, "count": 1, "ammo": 20, "pierce": 99, "size": 0.0, "life": 0.0, "color": Color("ff4df0"), "rail": true, "cost": 2200, "sound": "rail"},
]

const UPGRADES := [
	{"id": "hp", "name": "Blindaje Reforzado", "desc": "+20 de vida máxima", "max": 5, "base_cost": 150},
	{"id": "dmg", "name": "Núcleo de Potencia", "desc": "+10% de daño con todas las armas", "max": 5, "base_cost": 200},
	{"id": "rate", "name": "Sistema de Enfriamiento", "desc": "+8% de cadencia de disparo", "max": 5, "base_cost": 200},
	{"id": "speed", "name": "Propulsores", "desc": "+6% de velocidad de movimiento", "max": 5, "base_cost": 150},
	{"id": "shield", "name": "Generador de Escudo", "desc": "+15 de escudo regenerable", "max": 5, "base_cost": 250},
	{"id": "magnet", "name": "Imán de Recolección", "desc": "+35% de radio para recoger objetos", "max": 3, "base_cost": 120},
	{"id": "bomb", "name": "Arsenal de Bombas", "desc": "+1 bomba al iniciar cada misión", "max": 3, "base_cost": 300},
	{"id": "dash", "name": "Impulso Cuántico", "desc": "-12% de enfriamiento del dash", "max": 3, "base_cost": 180},
]

const LEVELS := [
	{"name": "Frontera Neón", "desc": "Patrullas de drones vigilan el borde de la galaxia. Una misión perfecta para calentar motores.", "waves": 4, "pool": ["drone", "shooter"], "budget": 8.0, "growth": 3.0, "boss": "", "color": Color("4df0ff"), "reward": 250, "unlock": "shotgun"},
	{"name": "Cinturón de Asteroides", "desc": "Entre las rocas se esconden escuadrones kamikaze. ¡No dejes de moverte!", "waves": 5, "pool": ["drone", "shooter", "kamikaze"], "budget": 10.0, "growth": 3.0, "boss": "", "color": Color("ffd24d"), "reward": 300, "unlock": ""},
	{"name": "Fortaleza Coloso", "desc": "El Coloso de Hierro, una fortaleza andante, protege la base enemiga.", "waves": 3, "pool": ["drone", "shooter", "kamikaze"], "budget": 12.0, "growth": 3.0, "boss": "coloso", "color": Color("ff7a3d"), "reward": 600, "unlock": "smg"},
	{"name": "Nebulosa Carmesí", "desc": "Los tanques pesados entran en combate dentro de la nebulosa.", "waves": 5, "pool": ["drone", "shooter", "kamikaze", "tank"], "budget": 14.0, "growth": 4.0, "boss": "", "color": Color("ff4d6a"), "reward": 400, "unlock": ""},
	{"name": "Estación Fantasma", "desc": "Una estación abandonada infestada de divisores que se multiplican al morir.", "waves": 5, "pool": ["drone", "shooter", "tank", "splitter"], "budget": 16.0, "growth": 4.0, "boss": "", "color": Color("c46bff"), "reward": 450, "unlock": "plasma"},
	{"name": "Nido del Enjambre", "desc": "La Reina del Enjambre engendra soldados sin descanso. Acaba con ella.", "waves": 3, "pool": ["drone", "kamikaze", "splitter", "shooter"], "budget": 18.0, "growth": 4.0, "boss": "reina", "color": Color("7dff6b"), "reward": 900, "unlock": "rocket"},
	{"name": "Tormenta de Plasma", "desc": "Francotiradores ocultos entre las nubes de plasma. Vigila sus láseres de apuntado.", "waves": 5, "pool": ["shooter", "sniper", "kamikaze", "tank"], "budget": 20.0, "growth": 5.0, "boss": "", "color": Color("4d8bff"), "reward": 550, "unlock": ""},
	{"name": "Puerta Omega", "desc": "La última línea de defensa antes del núcleo. Todo el ejército enemigo te espera.", "waves": 6, "pool": ["drone", "shooter", "kamikaze", "tank", "splitter", "sniper"], "budget": 22.0, "growth": 5.0, "boss": "", "color": Color("ff4df0"), "reward": 650, "unlock": "rail"},
	{"name": "Núcleo Omega", "desc": "Destruye el Núcleo Omega y libera la galaxia de una vez por todas.", "waves": 3, "pool": ["drone", "shooter", "kamikaze", "tank", "splitter", "sniper"], "budget": 24.0, "growth": 5.0, "boss": "omega", "color": Color("ffffff"), "reward": 1500, "unlock": ""},
]

const ENEMY_COST := {"drone": 1.0, "shooter": 2.0, "kamikaze": 1.5, "tank": 4.0, "splitter": 3.0, "sniper": 3.0, "mini": 0.5}
const ENEMY_NAMES := {"drone": "Dron", "shooter": "Artillero", "kamikaze": "Kamikaze", "tank": "Tanque", "splitter": "Divisor", "sniper": "Francotirador", "mini": "Mini-dron"}
const BOSS_NAMES := {"coloso": "COLOSO DE HIERRO", "reina": "REINA DEL ENJAMBRE", "omega": "NÚCLEO OMEGA"}
const POWER_NAMES := {"rapid": "SOBRECARGA", "damage": "DAÑO x2", "shield": "ESCUDO +50", "speed": "HIPERVELOCIDAD", "invuln": "INVENCIBLE"}

const CARDS := [
	{"id": "dmg", "name": "Munición Pesada", "desc": "+20% de daño", "icon": "DMG", "color": Color("ff4d6a")},
	{"id": "rate", "name": "Gatillo Rápido", "desc": "+15% de cadencia", "icon": "RPM", "color": Color("ff9b3d")},
	{"id": "multishot", "name": "Disparo Múltiple", "desc": "+1 proyectil por disparo", "icon": "x+1", "color": Color("ffd24d")},
	{"id": "pierce", "name": "Perforación", "desc": "Los proyectiles atraviesan +1 enemigo", "icon": ">>", "color": Color("c46bff")},
	{"id": "maxhp", "name": "Casco Reforzado", "desc": "+25 de vida máxima y cura 25", "icon": "HP+", "color": Color("4dff88")},
	{"id": "heal", "name": "Nanobots", "desc": "Recupera toda la vida", "icon": "+", "color": Color("4dff88")},
	{"id": "speed", "name": "Turbo", "desc": "+10% de velocidad", "icon": "SPD", "color": Color("7dff6b")},
	{"id": "shield", "name": "Barrera", "desc": "+25 de escudo máximo regenerable", "icon": "SH", "color": Color("4d8bff")},
	{"id": "crit", "name": "Ojo de Halcón", "desc": "+10% de probabilidad de crítico (daño x2)", "icon": "CRT", "color": Color("ffd24d")},
	{"id": "vamp", "name": "Robo Vital", "desc": "Cada baja te cura 2 puntos de vida", "icon": "VMP", "color": Color("ff4d6a")},
	{"id": "bomb", "name": "Bomba Extra", "desc": "+1 bomba", "icon": "B", "color": Color("ff4df0")},
	{"id": "magnet", "name": "Atractor", "desc": "+50% de radio de recogida", "icon": "MAG", "color": Color("4df0ff")},
	{"id": "dashdmg", "name": "Dash Explosivo", "desc": "El dash daña a los enemigos cercanos", "icon": "DSH", "color": Color("4df0ff")},
	{"id": "bulletspeed", "name": "Aceleradores", "desc": "+20% de velocidad y alcance de proyectiles", "icon": "VEL", "color": Color("ff9b3d")},
	{"id": "thorns", "name": "Coraza de Púas", "desc": "Quien te embista recibe 30 de daño", "icon": "SPK", "color": Color("b56bff")},
	{"id": "cooldown", "name": "Reactor Cuántico", "desc": "-25% de enfriamiento del dash", "icon": "CD", "color": Color("4d8bff")},
]

const ACHIEVEMENTS := [
	{"id": "first_blood", "name": "Primera Sangre", "desc": "Destruye tu primer enemigo"},
	{"id": "exterminator", "name": "Exterminador", "desc": "Destruye 1000 enemigos en total"},
	{"id": "boss1", "name": "Rompehierros", "desc": "Derrota al Coloso de Hierro"},
	{"id": "boss2", "name": "Matarreinas", "desc": "Derrota a la Reina del Enjambre"},
	{"id": "boss3", "name": "Salvador de la Galaxia", "desc": "Destruye el Núcleo Omega"},
	{"id": "survivor10", "name": "Superviviente", "desc": "Alcanza la ronda 10 en Supervivencia"},
	{"id": "survivor25", "name": "Inmortal", "desc": "Alcanza la ronda 25 en Supervivencia"},
	{"id": "combo", "name": "Imparable", "desc": "Alcanza el multiplicador x8"},
	{"id": "perfect", "name": "Intocable", "desc": "Completa un sector sin recibir daño"},
	{"id": "rich", "name": "Magnate", "desc": "Acumula 5000 créditos"},
	{"id": "arsenal", "name": "Arsenal Completo", "desc": "Desbloquea todas las armas"},
	{"id": "nightmare", "name": "Pesadilla Viviente", "desc": "Completa un sector en dificultad Pesadilla"},
]

var settings := {
	"master": 0.8, "music": 0.6, "sfx": 0.8,
	"fullscreen": false, "shake": true, "damage_numbers": true, "show_fps": false,
	"pilot": "PILOTO", "difficulty": 1,
}
var data := {}
var mode := "campaign"
var current_level := 0
var title_font: Font
var ui_theme: Theme

var _fade: ColorRect
var _toast_box: VBoxContainer
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	data = _default_data()
	_setup_input()
	load_game()
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Impact", "Arial Black", "Bahnschrift", "Franklin Gothic Heavy", "DejaVu Sans"])
	f.font_weight = 800
	title_font = f
	ui_theme = _build_theme()
	get_tree().root.theme = ui_theme

	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)
	_toast_box = VBoxContainer.new()
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_toast_box.offset_left = -380
	_toast_box.offset_right = -20
	_toast_box.offset_top = 20
	_toast_box.add_theme_constant_override("separation", 8)
	layer.add_child(_toast_box)
	apply_settings()


func _default_data() -> Dictionary:
	return {
		"credits": 0,
		"unlocked_level": 0,
		"campaign_done": false,
		"stars": {},
		"best": {},
		"upgrades": {},
		"weapons": ["blaster"],
		"survival_scores": [],
		"achievements": [],
		"stats": {"kills": 0, "games": 0, "bosses": 0, "playtime": 0.0, "best_round": 0},
	}


# ---------------------------------------------------------------- Guardado Seguro (AES-256 + HMAC-SHA256)
func _get_save_key() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update((_SECURITY_SALT + "::" + TITLE + "::AES256").to_utf8_buffer())
	return ctx.finish().hex_encode()


func _compute_hmac(payload: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update((_SECURITY_SALT + "|HMAC|" + payload + "|" + _SECURITY_SALT).to_utf8_buffer())
	return ctx.finish().hex_encode()


func sanitize_pilot_name(raw: String) -> String:
	var allowed := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_- "
	var up := raw.strip_edges().to_upper()
	var out := ""
	for i in up.length():
		var ch := up.substr(i, 1)
		if allowed.contains(ch):
			out += ch
		if out.length() >= 14:
			break
	out = out.strip_edges()
	return out if out != "" else "PILOTO"


func _sanitize_state() -> void:
	settings.master = clampf(float(settings.get("master", 0.8)), 0.0, 1.0)
	settings.music = clampf(float(settings.get("music", 0.6)), 0.0, 1.0)
	settings.sfx = clampf(float(settings.get("sfx", 0.8)), 0.0, 1.0)
	settings.fullscreen = bool(settings.get("fullscreen", false))
	settings.shake = bool(settings.get("shake", true))
	settings.damage_numbers = bool(settings.get("damage_numbers", true))
	settings.show_fps = bool(settings.get("show_fps", false))
	settings.pilot = sanitize_pilot_name(String(settings.get("pilot", "PILOTO")))
	settings.difficulty = clampi(int(settings.get("difficulty", 1)), 0, DIFFICULTIES.size() - 1)

	data.credits = clampi(int(data.get("credits", 0)), 0, 9999999)
	data.unlocked_level = clampi(int(data.get("unlocked_level", 0)), 0, LEVELS.size() - 1)
	data.campaign_done = bool(data.get("campaign_done", false))

	# Validar mejoras dentro de sus límites máximos
	var clean_upgrades := {}
	var raw_upgs = data.get("upgrades", {})
	if raw_upgs is Dictionary:
		for u in UPGRADES:
			var uid := String(u.id)
			if raw_upgs.has(uid):
				clean_upgrades[uid] = clampi(int(raw_upgs[uid]), 0, int(u.max))
	data.upgrades = clean_upgrades

	# Validar armas desbloqueadas
	var valid_wep_ids := {}
	for w in WEAPONS:
		valid_wep_ids[String(w.id)] = true
	var clean_weapons: Array = ["blaster"]
	var raw_weps = data.get("weapons", ["blaster"])
	if raw_weps is Array:
		for wid in raw_weps:
			var sw := String(wid)
			if valid_wep_ids.has(sw) and not clean_weapons.has(sw):
				clean_weapons.append(sw)
	data.weapons = clean_weapons

	# Validar logros
	var valid_ach_ids := {}
	for a in ACHIEVEMENTS:
		valid_ach_ids[String(a.id)] = true
	var clean_ach: Array = []
	var raw_ach = data.get("achievements", [])
	if raw_ach is Array:
		for aid in raw_ach:
			var sa := String(aid)
			if valid_ach_ids.has(sa) and not clean_ach.has(sa):
				clean_ach.append(sa)
	data.achievements = clean_ach

	# Validar estrellas y puntuaciones de niveles
	var clean_stars := {}
	var raw_stars = data.get("stars", {})
	if raw_stars is Dictionary:
		for i in LEVELS.size():
			var v := int(raw_stars.get(i, raw_stars.get(str(i), 0)))
			if v > 0:
				clean_stars[i] = clampi(v, 0, 3)
	data.stars = clean_stars

	var clean_best := {}
	var raw_best = data.get("best", {})
	if raw_best is Dictionary:
		for i in LEVELS.size():
			var v := int(raw_best.get(i, raw_best.get(str(i), 0)))
			if v > 0:
				clean_best[i] = clampi(v, 0, 99999999)
	data.best = clean_best

	# Validar estadísticas
	var defaults: Dictionary = _default_data().stats
	var raw_stats = data.get("stats", {})
	var clean_stats := {}
	for k in defaults:
		var val = raw_stats.get(k, defaults[k]) if raw_stats is Dictionary else defaults[k]
		if k == "playtime":
			clean_stats[k] = clampf(float(val), 0.0, 99999999.0)
		else:
			clean_stats[k] = clampi(int(val), 0, 99999999)
	data.stats = clean_stats


func load_game() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open_encrypted_with_pass(SAVE_PATH, FileAccess.READ, _get_save_key())
		if f:
			var raw_json := f.get_as_text()
			f.close()
			var parsed = JSON.parse_string(raw_json)
			if parsed is Dictionary and parsed.has("payload") and parsed.has("hmac"):
				var payload_str := String(parsed.payload)
				var expected_hmac := _compute_hmac(payload_str)
				if String(parsed.hmac) == expected_hmac:
					var inner = JSON.parse_string(payload_str)
					if inner is Dictionary:
						var s = inner.get("settings", {})
						if s is Dictionary:
							for k in s:
								settings[k] = s[k]
						var d = inner.get("data", {})
						if d is Dictionary:
							for k in d:
								data[k] = d[k]
						_sanitize_state()
						return
				else:
					push_warning("Seguridad: Firma HMAC inválida en archivo de guardado. Se restauran valores seguros.")
		else:
			push_warning("Seguridad: No se pudo descifrar el archivo de guardado.")

	# Migración única desde formato legado si existe
	if FileAccess.file_exists(LEGACY_SAVE_PATH):
		var cf := ConfigFile.new()
		if cf.load(LEGACY_SAVE_PATH) == OK:
			var s = cf.get_value("game", "settings", {})
			if s is Dictionary:
				for k in s:
					settings[k] = s[k]
			var d = cf.get_value("game", "data", {})
			if d is Dictionary:
				for k in d:
					data[k] = d[k]
			_sanitize_state()
			save_game()
			DirAccess.remove_absolute(LEGACY_SAVE_PATH)


func save_game() -> void:
	_sanitize_state()
	var payload_str := JSON.stringify({"settings": settings, "data": data, "v": 1})
	var envelope := JSON.stringify({
		"payload": payload_str,
		"hmac": _compute_hmac(payload_str),
	})
	var f := FileAccess.open_encrypted_with_pass(SAVE_PATH, FileAccess.WRITE, _get_save_key())
	if f:
		f.store_string(envelope)
		f.close()


func reset_progress() -> void:
	data = _default_data()
	save_game()


# ---------------------------------------------------------------- Ayudantes
func difficulty() -> Dictionary:
	return DIFFICULTIES[clampi(int(settings.difficulty), 0, DIFFICULTIES.size() - 1)]


func upg(id: String) -> int:
	return int(data.upgrades.get(id, 0))


func upgrade_cost(i: int) -> int:
	var u: Dictionary = UPGRADES[i]
	return int(float(u.base_cost) * (1.0 + upg(u.id) * 0.85))


func weapon_unlocked(i: int) -> bool:
	if i == 0:
		return true
	return data.weapons.has(String(WEAPONS[i].id))


func unlock_weapon(id: String) -> void:
	if data.weapons.has(id):
		return
	data.weapons.append(id)
	for w in WEAPONS:
		if w.id == id:
			toast("NUEVA ARMA DESBLOQUEADA", String(w.name), w.color)
	if data.weapons.size() >= WEAPONS.size():
		unlock_achievement("arsenal")
	save_game()


func add_credits(n: int) -> void:
	data.credits = int(data.credits) + n
	if int(data.credits) >= 5000:
		unlock_achievement("rich")


func has_achievement(id: String) -> bool:
	return data.achievements.has(id)


func unlock_achievement(id: String) -> void:
	if data.achievements.has(id):
		return
	data.achievements.append(id)
	for a in ACHIEVEMENTS:
		if a.id == id:
			toast("LOGRO DESBLOQUEADO", String(a.name), Color("ffd24d"))
	Sfx.play("achievement")
	save_game()


func add_survival_score(score: int, round_num: int) -> int:
	var entry := {"name": String(settings.pilot), "score": score, "round": round_num, "diff": int(settings.difficulty)}
	var list: Array = data.survival_scores
	list.append(entry)
	list.sort_custom(func(a, b): return int(a.score) > int(b.score))
	if list.size() > 10:
		list.resize(10)
	data.survival_scores = list
	for i in list.size():
		if is_same(list[i], entry):
			return i
	return -1


# ---------------------------------------------------------------- Ajustes
func apply_settings() -> void:
	_set_bus("Master", float(settings.master))
	_set_bus("Music", float(settings.music))
	_set_bus("SFX", float(settings.sfx))
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.get_name() != "headless" and DisplayServer.window_get_mode() != want:
		if want == DisplayServer.WINDOW_MODE_WINDOWED and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED:
			return
		DisplayServer.window_set_mode(want)


func _set_bus(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(idx, v <= 0.001)


# ---------------------------------------------------------------- Transiciones
func change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.25)
	await t.finished
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var t2 := create_tween()
	t2.tween_property(_fade, "color:a", 0.0, 0.3)
	_busy = false


func toast(title: String, sub: String, color: Color = Color("4df0ff")) -> void:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.12, 0.95)
	sb.border_color = color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	p.add_child(v)
	var l1 := Label.new()
	l1.text = title
	l1.add_theme_font_size_override("font_size", 14)
	l1.add_theme_color_override("font_color", color)
	v.add_child(l1)
	var l2 := Label.new()
	l2.text = sub
	l2.add_theme_font_size_override("font_size", 22)
	v.add_child(l2)
	_toast_box.add_child(p)
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.25)
	tw.tween_interval(3.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)


# ---------------------------------------------------------------- Controles
func _setup_input() -> void:
	_bind("move_up", [KEY_W, KEY_UP], [], [[JOY_AXIS_LEFT_Y, -1.0]])
	_bind("move_down", [KEY_S, KEY_DOWN], [], [[JOY_AXIS_LEFT_Y, 1.0]])
	_bind("move_left", [KEY_A, KEY_LEFT], [], [[JOY_AXIS_LEFT_X, -1.0]])
	_bind("move_right", [KEY_D, KEY_RIGHT], [], [[JOY_AXIS_LEFT_X, 1.0]])
	_bind("shoot", [], [MOUSE_BUTTON_LEFT], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]])
	_bind("dash", [KEY_SPACE, KEY_SHIFT], [], [], [JOY_BUTTON_A])
	_bind("bomb", [KEY_F], [MOUSE_BUTTON_RIGHT], [], [JOY_BUTTON_Y])
	_bind("next_weapon", [KEY_E], [MOUSE_BUTTON_WHEEL_DOWN], [], [JOY_BUTTON_RIGHT_SHOULDER])
	_bind("prev_weapon", [KEY_Q], [MOUSE_BUTTON_WHEEL_UP], [], [JOY_BUTTON_LEFT_SHOULDER])
	_bind("pause", [KEY_ESCAPE, KEY_P], [], [], [JOY_BUTTON_START])
	var nums := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6]
	for i in nums.size():
		_bind("weapon_%d" % (i + 1), [nums[i]])


func _bind(action: String, keys: Array, mouse: Array = [], axes: Array = [], buttons: Array = []) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.3)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	for m in mouse:
		var e := InputEventMouseButton.new()
		e.button_index = m
		InputMap.action_add_event(action, e)
	for a in axes:
		var e := InputEventJoypadMotion.new()
		e.axis = a[0]
		e.axis_value = a[1]
		InputMap.action_add_event(action, e)
	for b in buttons:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		InputMap.action_add_event(action, e)


# ---------------------------------------------------------------- Tema
func _build_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 20
	var accent := Color("4df0ff")
	th.set_stylebox("normal", "Button", _sb(Color(0.04, 0.07, 0.15, 0.9), accent.darkened(0.4), 2))
	th.set_stylebox("hover", "Button", _sb(Color(0.08, 0.2, 0.3, 0.95), accent, 2))
	th.set_stylebox("pressed", "Button", _sb(Color(0.15, 0.4, 0.5, 1.0), Color.WHITE, 2))
	th.set_stylebox("disabled", "Button", _sb(Color(0.05, 0.05, 0.08, 0.7), Color(0.25, 0.25, 0.3), 1))
	var focus := _sb(Color(0, 0, 0, 0), Color("ff4df0"), 2)
	focus.draw_center = false
	th.set_stylebox("focus", "Button", focus)
	th.set_color("font_color", "Button", Color(0.85, 0.97, 1.0))
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_pressed_color", "Button", Color.WHITE)
	th.set_color("font_focus_color", "Button", Color.WHITE)
	th.set_color("font_hover_pressed_color", "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", Color(0.45, 0.45, 0.5))
	th.set_stylebox("panel", "PanelContainer", _sb(Color(0.03, 0.05, 0.12, 0.92), accent.darkened(0.25), 2, 10))
	th.set_stylebox("normal", "LineEdit", _sb(Color(0.02, 0.04, 0.1, 1.0), accent.darkened(0.4), 2))
	th.set_stylebox("focus", "LineEdit", _sb(Color(0.02, 0.04, 0.1, 1.0), accent, 2))
	th.set_color("font_color", "Label", Color(0.85, 0.95, 1.0))
	var slider := _sb(Color(0.1, 0.15, 0.25), Color(0, 0, 0, 0), 0, 4)
	slider.content_margin_top = 3
	slider.content_margin_bottom = 3
	th.set_stylebox("slider", "HSlider", slider)
	th.set_stylebox("grabber_area", "HSlider", _sb(accent.darkened(0.3), Color(0, 0, 0, 0), 0, 4))
	th.set_stylebox("grabber_area_highlight", "HSlider", _sb(accent, Color(0, 0, 0, 0), 0, 4))
	return th


func _sb(bg: Color, border: Color, bw: int, radius: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s
