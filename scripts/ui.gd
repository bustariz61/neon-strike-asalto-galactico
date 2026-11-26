extends RefCounted
## Utilidades estáticas y componentes vectoriales neón para construir la interfaz por código.


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


static func action_button(text: String, cb: Callable, width: float, height: float, border: Color, font_size: int = 13, fill_tint: Color = Color(0.05, 0.09, 0.18, 0.92)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, height)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", font_size)

	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = fill_tint
	sb_n.border_color = border
	sb_n.set_border_width_all(2)
	sb_n.set_corner_radius_all(8)
	sb_n.content_margin_left = 8
	sb_n.content_margin_right = 8
	sb_n.content_margin_top = 4
	sb_n.content_margin_bottom = 4

	var sb_h := sb_n.duplicate()
	sb_h.bg_color = fill_tint.lerp(border, 0.25)
	sb_h.border_color = border.lightened(0.25)

	var sb_p := sb_n.duplicate()
	sb_p.bg_color = fill_tint.lerp(border, 0.45)
	sb_p.border_color = Color.WHITE

	var sb_d := sb_n.duplicate()
	sb_d.bg_color = Color(0.04, 0.05, 0.09, 0.72)
	sb_d.border_color = Color(0.22, 0.25, 0.34, 0.85)
	sb_d.set_border_width_all(1)

	b.add_theme_stylebox_override("normal", sb_n)
	b.add_theme_stylebox_override("hover", sb_h)
	b.add_theme_stylebox_override("pressed", sb_p)
	b.add_theme_stylebox_override("disabled", sb_d)
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


static func wrap_label(text: String, size: int, width: float = 0.0, color: Color = Color(0.8, 0.88, 0.95), align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := label(text, size, color, align)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if width > 0.0:
		l.custom_minimum_size.x = width
	else:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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


static func item_card(accent: Color, active: bool = true, pad_h: int = 10, pad_v: int = 8) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.17, 0.88) if active else Color(0.03, 0.05, 0.11, 0.72)
	sb.border_color = Color(accent, 0.75 if active else 0.25)
	sb.border_width_left = 4
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.set_corner_radius_all(8)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	p.add_theme_stylebox_override("panel", sb)
	return p


static func pill(text: String, color: Color, font_size: int = 12) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color.r * 0.22, color.g * 0.22, color.b * 0.22, 0.9)
	sb.border_color = Color(color, 0.85)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(label(text, font_size, color.lightened(0.15)))
	return p


static func progress_bar(ratio: float, color: Color, height: float = 16.0, text: String = "") -> Control:
	var r := clampf(ratio, 0.0, 1.0)
	var box := PanelContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(0, height)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.07, 0.14, 0.95)
	sb.border_color = Color(color, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	box.add_theme_stylebox_override("panel", sb)

	var inner := Control.new()
	inner.custom_minimum_size = Vector2(0, height - 2.0)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.draw.connect(func():
		var sz := inner.size
		if r > 0.0:
			var fw := sz.x * r
			inner.draw_rect(Rect2(2, 2, maxf(4.0, fw - 4.0), sz.y - 4.0), Color(color, 0.85))
			inner.draw_rect(Rect2(2, 2, maxf(4.0, fw - 4.0), (sz.y - 4.0) * 0.42), Color(1, 1, 1, 0.25))
	)
	box.add_child(inner)
	if text != "":
		var lbl := label(text, maxi(10, int(height) - 5), Color.WHITE)
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(lbl)
	return box


static func icon_badge(kind: String, color: Color, sz: float = 36.0, active: bool = true) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(sz, sz)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var center := Vector2(sz, sz) * 0.5
		var rad := sz * 0.46
		var col := color if active else Color(0.38, 0.43, 0.54)
		c.draw_circle(center, rad, Color(col.r * 0.22, col.g * 0.22, col.b * 0.22, 0.92))
		c.draw_arc(center, rad, 0.0, TAU, 28, Color(col, 0.9 if active else 0.45), 2.0)

		var r := rad * 0.56
		match kind:
			"trophy":
				# Copa + estrella de logro
				var cup := PackedVector2Array([
					center + Vector2(-r * 0.72, -r * 0.65),
					center + Vector2(r * 0.72, -r * 0.65),
					center + Vector2(r * 0.45, r * 0.15),
					center + Vector2(-r * 0.45, r * 0.15),
				])
				c.draw_colored_polygon(cup, col)
				c.draw_line(center + Vector2(0, r * 0.15), center + Vector2(0, r * 0.62), col, 2.5)
				c.draw_line(center + Vector2(-r * 0.55, r * 0.68), center + Vector2(r * 0.55, r * 0.68), col, 2.8)
				c.draw_colored_polygon(star_points(center + Vector2(0, -r * 0.25), r * 0.32, r * 0.15), Color.WHITE)
			"lock":
				c.draw_arc(center + Vector2(0, -r * 0.2), r * 0.42, PI, TAU, 16, col, 2.2)
				c.draw_rect(Rect2(center.x - r * 0.55, center.y - r * 0.12, r * 1.1, r * 0.85), Color(col, 0.75))
				c.draw_circle(center + Vector2(0, r * 0.26), r * 0.16, Color(0.05, 0.07, 0.14))
			"upgrade", "rate", "speed":
				# Doble flecha ascendente
				for dy in [-r * 0.22, r * 0.34]:
					var pts := PackedVector2Array([
						center + Vector2(-r * 0.65, dy + r * 0.28),
						center + Vector2(0, dy - r * 0.36),
						center + Vector2(r * 0.65, dy + r * 0.28),
					])
					c.draw_polyline(pts, col, 2.6)
			"hp":
				c.draw_rect(Rect2(center.x - r * 0.22, center.y - r * 0.68, r * 0.44, r * 1.36), col)
				c.draw_rect(Rect2(center.x - r * 0.68, center.y - r * 0.22, r * 1.36, r * 0.44), col)
			"dmg", "weapon":
				c.draw_arc(center, r * 0.58, 0.0, TAU, 20, col, 2.0)
				c.draw_line(center + Vector2(-r * 0.9, 0), center + Vector2(-r * 0.28, 0), col, 2.2)
				c.draw_line(center + Vector2(r * 0.28, 0), center + Vector2(r * 0.9, 0), col, 2.2)
				c.draw_line(center + Vector2(0, -r * 0.9), center + Vector2(0, -r * 0.28), col, 2.2)
				c.draw_line(center + Vector2(0, r * 0.28), center + Vector2(0, r * 0.9), col, 2.2)
				c.draw_circle(center, r * 0.18, Color.WHITE)
			"shield":
				var sh := PackedVector2Array([
					center + Vector2(0, -r * 0.78),
					center + Vector2(r * 0.72, -r * 0.42),
					center + Vector2(r * 0.56, r * 0.32),
					center + Vector2(0, r * 0.82),
					center + Vector2(-r * 0.56, r * 0.32),
					center + Vector2(-r * 0.72, -r * 0.42),
				])
				c.draw_colored_polygon(sh, Color(col, 0.38))
				sh.append(sh[0])
				c.draw_polyline(sh, col, 2.2)
			"magnet":
				c.draw_arc(center + Vector2(0, -r * 0.08), r * 0.52, PI, TAU, 16, col, 3.2)
				c.draw_line(center + Vector2(-r * 0.52, -r * 0.08), center + Vector2(-r * 0.52, r * 0.58), col, 3.2)
				c.draw_line(center + Vector2(r * 0.52, -r * 0.08), center + Vector2(r * 0.52, r * 0.58), col, 3.2)
				c.draw_line(center + Vector2(-r * 0.52, r * 0.42), center + Vector2(-r * 0.52, r * 0.64), Color.WHITE, 3.4)
				c.draw_line(center + Vector2(r * 0.52, r * 0.42), center + Vector2(r * 0.52, r * 0.64), Color.WHITE, 3.4)
			"bomb":
				c.draw_circle(center, r * 0.48, col)
				c.draw_arc(center, r * 0.78, 0.0, TAU, 20, Color(col, 0.75), 1.8)
				c.draw_circle(center, r * 0.2, Color.WHITE)
			"dash":
				var bolt := PackedVector2Array([
					center + Vector2(r * 0.12, -r * 0.78),
					center + Vector2(-r * 0.52, r * 0.08),
					center + Vector2(0.0, r * 0.08),
					center + Vector2(-r * 0.14, r * 0.78),
					center + Vector2(r * 0.54, -r * 0.08),
					center + Vector2(0.0, -r * 0.08),
				])
				c.draw_colored_polygon(bolt, col)
			"coin":
				var dia := PackedVector2Array([
					center + Vector2(0, -r * 0.75),
					center + Vector2(r * 0.68, 0),
					center + Vector2(0, r * 0.75),
					center + Vector2(-r * 0.68, 0),
				])
				c.draw_colored_polygon(dia, col)
				c.draw_circle(center, r * 0.22, Color.WHITE)
			"warn":
				var tri := PackedVector2Array([
					center + Vector2(0, -r * 0.72),
					center + Vector2(r * 0.75, r * 0.62),
					center + Vector2(-r * 0.75, r * 0.62),
				])
				c.draw_colored_polygon(tri, Color(col, 0.35))
				tri.append(tri[0])
				c.draw_polyline(tri, col, 2.2)
				c.draw_line(center + Vector2(0, -r * 0.24), center + Vector2(0, r * 0.18), Color.WHITE, 2.4)
				c.draw_circle(center + Vector2(0, r * 0.4), 1.8, Color.WHITE)
			_:
				c.draw_colored_polygon(star_points(center, r * 0.72, r * 0.34), col)
	)
	return c


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
	c.custom_minimum_size = Vector2(total * 24, 10)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		for i in total:
			var r := Rect2(i * 24, 0, 20, 8)
			if i < level:
				c.draw_rect(r, color)
				c.draw_rect(Rect2(i * 24, 0, 20, 3), Color(1, 1, 1, 0.35))
			else:
				c.draw_rect(r, Color(1, 1, 1, 0.12))
				c.draw_rect(r, Color(color, 0.3), false, 1.0)
	)
	return c
