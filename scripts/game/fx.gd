extends Node2D
## Efectos visuales: partículas de neón, ondas expansivas, rayos láser, estelas y textos flotantes.

var sparks: Array = []
var rings: Array = []
var beams: Array = []
var ghosts: Array = []
var texts: Array = []


func add_burst(pos: Vector2, color: Color, count: int = 16, speed: float = 260.0, size: float = 4.0, life: float = 0.55) -> void:
	for i in count:
		var a := randf() * TAU
		var sp := speed * randf_range(0.25, 1.0)
		sparks.append({
			"p": pos,
			"v": Vector2(cos(a), sin(a)) * sp,
			"c": color.lightened(randf_range(0.0, 0.3)),
			"s": size * randf_range(0.6, 1.35),
			"t": life * randf_range(0.6, 1.1),
			"m": life,
		})


func add_ring(pos: Vector2, color: Color, max_r: float = 95.0, life: float = 0.4, width: float = 4.0) -> void:
	rings.append({"p": pos, "c": color, "r": max_r, "t": life, "m": life, "w": width})


func add_beam(a: Vector2, b: Vector2, color: Color, width: float = 10.0, life: float = 0.28) -> void:
	beams.append({"a": a, "b": b, "c": color, "w": width, "t": life, "m": life})


func add_ghost(pos: Vector2, rot: float, color: Color) -> void:
	ghosts.append({"p": pos, "r": rot, "c": color, "t": 0.22, "m": 0.22})


func add_text(pos: Vector2, text: String, color: Color = Color.WHITE, size: int = 18) -> void:
	if texts.size() > 60:
		texts.pop_front()
	texts.append({
		"p": pos + Vector2(randf_range(-14.0, 14.0), -12.0),
		"v": Vector2(randf_range(-20.0, 20.0), -65.0),
		"txt": text,
		"c": color,
		"s": size,
		"t": 0.85,
		"m": 0.85,
	})


func _process(delta: float) -> void:
	for s in sparks:
		s.p += s.v * delta
		s.v *= pow(0.08, delta)
		s.t -= delta
	sparks = sparks.filter(func(s): return s.t > 0.0)

	for r in rings:
		r.t -= delta
	rings = rings.filter(func(r): return r.t > 0.0)

	for b in beams:
		b.t -= delta
	beams = beams.filter(func(b): return b.t > 0.0)

	for g in ghosts:
		g.t -= delta
	ghosts = ghosts.filter(func(g): return g.t > 0.0)

	for tx in texts:
		tx.p += tx.v * delta
		tx.v.y *= pow(0.25, delta)
		tx.t -= delta
	texts = texts.filter(func(tx): return tx.t > 0.0)

	queue_redraw()


func _draw() -> void:
	for g in ghosts:
		var k: float = clampf(float(g.t) / float(g.m), 0.0, 1.0)
		draw_set_transform(g.p, float(g.r), Vector2.ONE)
		var pts := PackedVector2Array([Vector2(22, 0), Vector2(-16, -15), Vector2(-10, 0), Vector2(-16, 15)])
		draw_colored_polygon(pts, Color(g.c, k * 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	for b in beams:
		var k: float = clampf(float(b.t) / float(b.m), 0.0, 1.0)
		var w: float = float(b.w) * k
		draw_line(b.a, b.b, Color(b.c, 0.3 * k), w * 2.4)
		draw_line(b.a, b.b, Color(b.c, 0.85 * k), w)
		draw_line(b.a, b.b, Color(1, 1, 1, 0.9 * k), maxf(1.5, w * 0.4))

	for r in rings:
		var k: float = 1.0 - clampf(float(r.t) / float(r.m), 0.0, 1.0)
		var rad: float = lerpf(8.0, float(r.r), 1.0 - pow(1.0 - k, 2.0))
		var alpha: float = 1.0 - k
		draw_arc(r.p, rad, 0.0, TAU, 40, Color(r.c, alpha * 0.85), float(r.w) * (1.0 - k * 0.5) + 1.0)

	for s in sparks:
		var k: float = clampf(float(s.t) / float(s.m), 0.0, 1.0)
		var col := Color(s.c, k)
		var vel: Vector2 = s.v
		if vel.length_squared() > 900.0:
			draw_line(s.p, s.p - vel * 0.045, col, float(s.s) * k)
		else:
			draw_circle(s.p, float(s.s) * k, col)

	var font := ThemeDB.fallback_font
	for tx in texts:
		var k: float = clampf(float(tx.t) / float(tx.m), 0.0, 1.0)
		var col := Color(tx.c, k)
		var pos: Vector2 = tx.p
		draw_string_outline(font, pos, String(tx.txt), HORIZONTAL_ALIGNMENT_CENTER, -1, int(tx.s), 4, Color(0, 0, 0, k * 0.85))
		draw_string(font, pos, String(tx.txt), HORIZONTAL_ALIGNMENT_CENTER, -1, int(tx.s), col)
