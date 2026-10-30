class_name UIKit
## Code-built UI primitives with one consistent look: dark glass panels, cyan/violet accents.
## Every HUD, the phone and the store use these so the prototype feels like one product.

const ACCENT := Color(0.5, 0.68, 0.95)
const ACCENT2 := Color(0.55, 0.85, 0.75)
const GOLD := Color(1.0, 0.8, 0.3)
const GREEN := Color(0.35, 1.0, 0.55)
const RED := Color(1.0, 0.33, 0.38)
const AMBER := Color(1.0, 0.72, 0.25)
const TEXT := Color(0.95, 0.95, 0.96)
const TEXT_DIM := Color(0.62, 0.64, 0.68)
const PANEL_BG := Color(0.1, 0.1, 0.115, 0.96)
const PANEL_BG_SOLID := Color(0.12, 0.12, 0.135, 1.0)
const CARD_BG := Color(0.16, 0.16, 0.18, 1.0)


static func fmt_int(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out


static func panel_style(bg: Color = PANEL_BG, radius := 12, border: Color = Color(1, 1, 1, 0.08), border_w := 1, margin := 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	# Flat look: small radii are clamped, large ones (avatars, badges) stay round, and the
	# coloured outlines are dropped - a border only shows when a caller asks for 2 px or more.
	if radius < 20:
		radius = mini(radius, 3)
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border_w if border_w >= 2 else 0)
	sb.border_color = border
	sb.set_content_margin_all(margin)
	return sb


static func panel(bg: Color = PANEL_BG, radius := 12, border: Color = Color(1, 1, 1, 0.08), margin := 14) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(bg, radius, border, 1, margin))
	return p


static func label(text: String, size := 16, color: Color = TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	return l


static func wrapped(text: String, size := 14, color: Color = TEXT_DIM) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func button(text: String, accent: Color = ACCENT, size := 15, min_height := 38) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_height)
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_NONE
	# Solid filled buttons, no outline.
	var normal := panel_style(accent.darkened(0.45), 3, Color.TRANSPARENT, 0, 8)
	var hover := panel_style(accent.darkened(0.25), 3, Color.TRANSPARENT, 0, 8)
	var pressed := panel_style(accent.darkened(0.6), 3, Color.TRANSPARENT, 0, 8)
	var disabled := panel_style(Color(0.22, 0.22, 0.25, 1.0), 3, Color.TRANSPARENT, 0, 8)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.54))
	return b


static func progress(value: float, color: Color = ACCENT, height := 10) -> ProgressBar:
	var p := ProgressBar.new()
	p.min_value = 0.0
	p.max_value = 1.0
	p.value = value
	p.show_percentage = false
	p.custom_minimum_size = Vector2(0, height)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.08)
	bg.set_corner_radius_all(height / 2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(height / 2)
	p.add_theme_stylebox_override("background", bg)
	p.add_theme_stylebox_override("fill", fill)
	return p


static func vbox(separation := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	return v


static func hbox(separation := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	return h


static func spacer(vertical := false) -> Control:
	var c := Control.new()
	if vertical:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func separator() -> HSeparator:
	var s := HSeparator.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.08)
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	s.add_theme_stylebox_override("separator", sb)
	return s


## Small coloured pill, e.g. a tier or rank tag.
static func tag(text: String, color: Color, size := 12) -> PanelContainer:
	var p := panel(Color(color.r, color.g, color.b, 0.18), 6, Color(color.r, color.g, color.b, 0.7), 5)
	var l := label(text, size, color, HORIZONTAL_ALIGNMENT_CENTER)
	p.add_child(l)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return p


static func full_rect(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


static func tier_color(tier: String) -> Color:
	match tier:
		"Mythic": return Color(0.95, 0.4, 1.0)
		"Legendary": return GOLD
		"Rare": return ACCENT
	return TEXT_DIM
