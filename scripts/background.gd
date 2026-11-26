extends Node2D
## Fondo animado: estrellas, nebulosas, rejilla de la arena o paisaje synthwave del menú.

var menu_mode := false
var area := Rect2(0, 0, 1280, 720)
var theme_color := Color("4df0ff")
var stars: Array = []
var nebulas: Array = []
var shooting: Array = []
var t := 0.0


func _ready() -> void:
	z_index = -10
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var bounds := area.grow(700)
	if menu_mode:
		var vp := get_viewport_rect().size
		bounds = Rect2(Vector2.ZERO, Vector2(maxf(vp.x, 1920.0), maxf(vp.y, 1080.0)))
	var count := 220 if menu_mode else 700
	for i in count:
		stars.append({
			"p": Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y)),
			"s": rng.randf_range(0.8, 2.4), "l": rng.randf_range(0.2, 1.0), "ph": rng.randf() * TAU,
		})
	var nebula_count := 3 if menu_mode else 9
	for i in nebula_count:
		var c := theme_color if not menu_mode else (Color("ff4df0") if i % 2 == 0 else Color("4df0ff"))
		c.h = fmod(c.h + rng.randf_range(-0.12, 0.12) + 1.0, 1.0)
		nebulas.append({
			"p": Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y * (0.6 if menu_mode else 1.0))),
			"r": rng.randf_range(220.0, 520.0), "c": c,
		})


func _process(delta: float) -> void:
	t += delta
	if menu_mode:
		var sz := get_viewport_rect().size
		for s in stars:
			var p: Vector2 = s.p
			p.x -= 18.0 * float(s.l) * delta
			if p.x < 0.0:
				p.x += sz.x
				p.y = randf() * sz.y
			s.p = p
		if randf() < 0.01:
			shooting.append({"p": Vector2(randf() * sz.x, randf() * sz.y * 0.4), "v": Vector2(-520, 220).rotated(randf_range(-0.2, 0.2)), "l": 0.8})
		for m in shooting:
			m.p += m.v * delta
			m.l -= delta
		shooting = shooting.filter(func(m): return m.l > 0.0)
	queue_redraw()


func _draw() -> void:
	if menu_mode:
		_draw_menu()
	else:
		_draw_game()


func _draw_stars() -> void:
	for s in stars:
		var a: float = 0.25 + 0.75 * absf(sin(t * 1.3 * float(s.l) + float(s.ph)))
		var sz: float = s.s
		draw_rect(Rect2(s.p, Vector2(sz, sz)), Color(0.8, 0.9, 1.0, a * float(s.l)))


func _draw_game() -> void:
	for n in nebulas:
		var c: Color = n.c
		for k in 4:
			draw_circle(n.p, float(n.r) * (1.0 - k * 0.22), Color(c, 0.022))
	_draw_stars()
	draw_rect(area, Color(0.015, 0.02, 0.06, 0.65))
	var step := 80.0
	var gc := Color(theme_color, 0.07)
	var x := area.position.x
	while x <= area.end.x:
		draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), gc, 1.0)
		x += step
	var y := area.position.y
	while y <= area.end.y:
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), gc, 1.0)
		y += step
	# línea de escaneo
	var scan := area.position.y + fmod(t * 160.0, area.size.y)
	draw_line(Vector2(area.position.x, scan), Vector2(area.end.x, scan), Color(theme_color, 0.12), 3.0)
	# bordes de neón
	draw_rect(area.grow(8), Color(theme_color, 0.12), false, 14.0)
	draw_rect(area.grow(2), Color(theme_color, 0.35), false, 5.0)
	draw_rect(area, theme_color, false, 2.0)
	for corner in [area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)]:
		draw_circle(corner, 10.0, Color(theme_color, 0.6))
		draw_circle(corner, 4.0, Color.WHITE)


func _draw_menu() -> void:
	var sz := get_viewport_rect().size
	var horizon := sz.y * 0.64
	# cielo degradado
	var strips := 24
	for i in strips:
		var k := float(i) / strips
		var c := Color(0.02, 0.02, 0.07).lerp(Color(0.18, 0.03, 0.22), k * k)
		draw_rect(Rect2(0, horizon * k, sz.x, horizon / strips + 1.0), c)
	for n in nebulas:
		var nc: Color = n.c
		for k in 4:
			draw_circle(n.p, float(n.r) * (1.0 - k * 0.22), Color(nc, 0.025))
	_draw_stars()
	for m in shooting:
		var a: float = clampf(float(m.l) / 0.8, 0.0, 1.0)
		var mv: Vector2 = m.v
		draw_line(m.p, m.p - mv.normalized() * 90.0, Color(1, 1, 1, a * 0.8), 2.0)
	# sol retro
	var sun_c := Vector2(sz.x * 0.5, horizon - 20.0)
	var r := 150.0
	var yy := -r
	while yy < r * 0.85:
		var w := sqrt(maxf(0.0, r * r - yy * yy))
		var k := (yy + r) / (2.0 * r)
		var gap := yy > 0.0 and int((yy + 400.0) / 6.0) % 3 == 0
		if not gap:
			draw_line(sun_c + Vector2(-w, yy), sun_c + Vector2(w, yy), Color(1.0, 0.85, 0.3).lerp(Color(1.0, 0.2, 0.6), k), 2.0)
		yy += 2.0
	draw_circle(sun_c, r * 1.25, Color(1.0, 0.3, 0.6, 0.06))
	# suelo con rejilla en perspectiva
	draw_rect(Rect2(0, horizon, sz.x, sz.y - horizon), Color(0.03, 0.0, 0.08))
	var grid_c := Color("ff4df0")
	for i in range(-14, 15):
		var x0 := sz.x * 0.5 + i * 30.0
		var x1 := sz.x * 0.5 + i * 220.0
		draw_line(Vector2(x0, horizon), Vector2(x1, sz.y), Color(grid_c, 0.45), 1.5)
	for k in 12:
		var z := fmod(float(k) + t * 0.9, 12.0) / 12.0
		var yl := horizon + (sz.y - horizon) * z * z
		draw_line(Vector2(0, yl), Vector2(sz.x, yl), Color(grid_c, 0.15 + 0.6 * z), 1.5)
	draw_line(Vector2(0, horizon), Vector2(sz.x, horizon), Color("4df0ff"), 2.0)
