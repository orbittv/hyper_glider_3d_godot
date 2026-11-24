class_name UiBuilder
extends RefCounted

## Статическая фабрика стилизованных неоновых UI-элементов (HUD, Арсенал, Меню, Ангар, Настройки, Game Over).


static func get_sci_fi_font() -> Font:
	var theme_font: Font = ThemeDB.get_default_theme().default_font
	return theme_font if theme_font != null else ThemeDB.fallback_font


static func create_glass_panel(bg_col: Color, border_col: Color, radius: int = 12, pad_x: float = 12.0, pad_y: float = 8.0) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = border_col
	sb.set_border_width_all(2 if radius >= 14 else 1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	panel.add_theme_stylebox_override("panel", sb)
	return panel


static func set_panel_colors(panel: Control, bg_col: Color, border_col: Color) -> void:
	if panel == null:
		return
	var sb := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if sb != null:
		sb.bg_color = bg_col
		sb.border_color = border_col


static func set_panel_border(panel: Control, border_col: Color) -> void:
	if panel == null:
		return
	var sb := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if sb != null:
		sb.border_color = border_col


static func create_label(text: String, font_size: int, col: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER, outline_size: int = 0) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = align
	var f: Font = get_sci_fi_font()
	if f != null:
		lbl.add_theme_font_override("font", f)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", col)
	if outline_size > 0:
		lbl.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.08, 0.95))
		lbl.add_theme_constant_override("outline_size", outline_size)
	return lbl


static func create_neon_button(text: String, min_size: Vector2, bg_col: Color, border_col: Color, text_col: Color, font_size: int = 16) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	btn.focus_mode = Control.FOCUS_NONE
	var f: Font = get_sci_fi_font()
	if f != null:
		btn.add_theme_font_override("font", f)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color(0.75, 0.96, 1.0))

	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = bg_col
	sb_normal.border_color = border_col
	sb_normal.set_border_width_all(2)
	sb_normal.set_corner_radius_all(12)
	sb_normal.content_margin_left = 14.0
	sb_normal.content_margin_right = 14.0
	sb_normal.content_margin_top = 8.0
	sb_normal.content_margin_bottom = 8.0

	var sb_hover := sb_normal.duplicate() as StyleBoxFlat
	sb_hover.bg_color = bg_col.lightened(0.14)
	sb_hover.border_color = border_col.lightened(0.25)

	var sb_pressed := sb_normal.duplicate() as StyleBoxFlat
	sb_pressed.bg_color = bg_col.lightened(0.24)
	sb_pressed.border_color = Color.WHITE

	btn.add_theme_stylebox_override("normal", sb_normal)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	return btn


static func create_primary_button(text: String, height: float = 60.0, font_size: int = 20) -> Button:
	return create_neon_button(
		text,
		Vector2(0.0, height),
		Color(0.05, 0.45, 0.68, 0.98),
		Color(0.38, 0.95, 1.0, 1.0),
		Color.WHITE,
		font_size
	)


static func create_secondary_button(text: String, height: float = 54.0, font_size: int = 18) -> Button:
	return create_neon_button(
		text,
		Vector2(0.0, height),
		Color(0.04, 0.10, 0.20, 0.90),
		Color(0.22, 0.75, 0.92, 0.58),
		Color(0.84, 0.95, 1.0),
		font_size
	)


static func create_danger_button(text: String, height: float = 52.0, font_size: int = 18) -> Button:
	return create_neon_button(
		text,
		Vector2(0.0, height),
		Color(0.18, 0.06, 0.12, 0.90),
		Color(0.95, 0.35, 0.48, 0.65),
		Color(0.99, 0.82, 0.86),
		font_size
	)


static func apply_button_colors(btn: Button, bg_col: Color, border_col: Color) -> void:
	if btn == null:
		return
	var sb_n := btn.get_theme_stylebox("normal") as StyleBoxFlat
	var sb_h := btn.get_theme_stylebox("hover") as StyleBoxFlat
	var sb_p := btn.get_theme_stylebox("pressed") as StyleBoxFlat
	if sb_n != null:
		sb_n.bg_color = bg_col
		sb_n.border_color = border_col
	if sb_h != null:
		sb_h.bg_color = bg_col.lightened(0.14)
		sb_h.border_color = border_col.lightened(0.25)
	if sb_p != null:
		sb_p.bg_color = bg_col.lightened(0.24)
		sb_p.border_color = Color.WHITE


static func create_modal_overlay(
	parent: Control,
	view_w: float,
	view_h: float,
	margin_x: float,
	card_h: float,
	bg_col: Color,
	border_col: Color,
	dimmer_col: Color = Color(0.01, 0.02, 0.06, 0.80),
	separation: int = 12
) -> Dictionary:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	parent.add_child(root)

	var dimmer := ColorRect.new()
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = dimmer_col
	root.add_child(dimmer)

	var card := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = border_col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	card.add_theme_stylebox_override("panel", sb)
	card.position = Vector2(margin_x, (view_h - card_h) * 0.5)
	card.size = Vector2(view_w - margin_x * 2.0, card_h)
	root.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 20.0
	vbox.offset_top = 20.0
	vbox.offset_right = -20.0
	vbox.offset_bottom = -20.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", separation)
	card.add_child(vbox)

	return {
		"root": root,
		"card": card,
		"vbox": vbox
	}


static var _slider_grabber_tex: Texture2D
static var _slider_grabber_hi_tex: Texture2D


static func clear_static_caches() -> void:
	_slider_grabber_tex = null
	_slider_grabber_hi_tex = null


static func _get_slider_grabber_texture(highlighted: bool) -> Texture2D:
	if not highlighted and _slider_grabber_tex != null:
		return _slider_grabber_tex
	if highlighted and _slider_grabber_hi_tex != null:
		return _slider_grabber_hi_tex

	var sz: int = 26 if highlighted else 24
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var center: float = (float(sz) - 1.0) * 0.5
	var max_r: float = float(sz) * 0.5 - 0.5
	for y: int in range(sz):
		for x: int in range(sz):
			var d: float = Vector2(float(x) - center, float(y) - center).length()
			var col := Color(0.0, 0.0, 0.0, 0.0)
			if d <= max_r:
				var edge_aa: float = clampf(max_r - d + 0.5, 0.0, 1.0)
				if d <= max_r * 0.42:
					col = Color(0.92, 0.99, 1.0, edge_aa)
				elif d <= max_r * 0.72:
					col = Color(0.24, 0.90, 1.0, edge_aa) if not highlighted else Color(0.45, 0.98, 1.0, edge_aa)
				else:
					var glow_t: float = 1.0 - clampf((d - max_r * 0.72) / (max_r * 0.28), 0.0, 1.0)
					col = Color(0.15, 0.82, 0.98, glow_t * (0.72 if highlighted else 0.52) * edge_aa)
			img.set_pixel(x, y, col)

	var tex := ImageTexture.create_from_image(img)
	if highlighted:
		_slider_grabber_hi_tex = tex
	else:
		_slider_grabber_tex = tex
	return tex


static func create_slider_row(
	parent_vbox: VBoxContainer,
	title_text: String,
	val_text: String,
	min_v: float,
	max_v: float,
	step_v: float,
	init_v: float
) -> Dictionary:
	var row := HBoxContainer.new()
	parent_vbox.add_child(row)

	var lbl_title := create_label(title_text, 15, Color(0.82, 0.92, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
	lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl_title)

	var lbl_val := create_label(val_text, 15, Color(0.40, 0.95, 1.0), HORIZONTAL_ALIGNMENT_RIGHT)
	row.add_child(lbl_val)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step_v
	slider.value = init_v
	slider.custom_minimum_size = Vector2(0.0, 26.0)
	slider.focus_mode = Control.FOCUS_NONE

	var sb_track := StyleBoxFlat.new()
	sb_track.bg_color = Color(0.015, 0.045, 0.11, 0.95)
	sb_track.border_color = Color(0.16, 0.58, 0.78, 0.55)
	sb_track.set_border_width_all(1)
	sb_track.set_corner_radius_all(5)
	sb_track.content_margin_top = 5.0
	sb_track.content_margin_bottom = 5.0

	var sb_fill := StyleBoxFlat.new()
	sb_fill.bg_color = Color(0.16, 0.84, 0.96, 0.90)
	sb_fill.border_color = Color(0.55, 0.98, 1.0, 0.85)
	sb_fill.set_border_width_all(1)
	sb_fill.set_corner_radius_all(5)
	sb_fill.content_margin_top = 5.0
	sb_fill.content_margin_bottom = 5.0

	var sb_fill_hi := sb_fill.duplicate() as StyleBoxFlat
	sb_fill_hi.bg_color = Color(0.32, 0.94, 1.0, 1.0)
	sb_fill_hi.border_color = Color.WHITE

	slider.add_theme_stylebox_override("slider", sb_track)
	slider.add_theme_stylebox_override("grabber_area", sb_fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", sb_fill_hi)
	slider.add_theme_icon_override("grabber", _get_slider_grabber_texture(false))
	slider.add_theme_icon_override("grabber_highlight", _get_slider_grabber_texture(true))
	parent_vbox.add_child(slider)

	return {
		"label_val": lbl_val,
		"slider": slider
	}
