extends RefCounted
## Utilidades estáticas para construir la interfaz por código.


static func button(text: String, cb: Callable, width: float = 340.0, height: float = 50.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, height)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call()
	)
	b.mouse_entered.connect(func():
		if not b.disabled:
			Sfx.play("hover", -8.0, 0.0)
	)
	return b


static func label(text: String, size: int = 20, color: Color = Color(0.85, 0.95, 1.0), align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	return l


static func wrap_label(text: String, size: int, width: float, color: Color = Color(0.8, 0.88, 0.95), align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := label(text, size, color, align)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	return l


static func title(text: String, size: int, color: Color) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", Game.title_font)
	l.add_theme_constant_override("outline_size", maxi(4, size / 9))
	l.add_theme_color_override("font_outline_color", Color(color.r * 0.2, color.g * 0.2, color.b * 0.3, 1.0))
	l.add_theme_color_override("font_shadow_color", Color(color, 0.45))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 4)
	l.add_theme_constant_override("shadow_outline_size", 14)
	return l


static func panel(min_size: Vector2 = Vector2.ZERO, border: Color = Color("4df0ff"), margin: int = 22) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.12, 0.92)
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(margin)
	sb.shadow_color = Color(border, 0.2)
	sb.shadow_size = 14
	p.add_theme_stylebox_override("panel", sb)
	return p


static func vbox(sep: int = 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


static func star_points(c: Vector2, r1: float, r2: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		var r := r1 if i % 2 == 0 else r2
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


static func stars_widget(count: int, total: int = 3, size: float = 22.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(total * size * 1.2, size)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.draw.connect(func():
		for i in total:
			var center := Vector2(size * 0.6 + i * size * 1.2, size * 0.5)
			var col := Color("ffd24d") if i < count else Color(0.25, 0.25, 0.32)
			c.draw_colored_polygon(star_points(center, size * 0.5, size * 0.22), col)
	)
	return c


static func pips_widget(level: int, total: int, color: Color = Color("4df0ff")) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(total * 22, 12)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		for i in total:
			var r := Rect2(i * 22, 0, 18, 10)
			if i < level:
				c.draw_rect(r, color)
			else:
				c.draw_rect(r, Color(1, 1, 1, 0.15))
				c.draw_rect(r, Color(1, 1, 1, 0.3), false, 1.0)
	)
	return c
