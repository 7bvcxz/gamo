class_name LabStyle
extends RefCounted

## The Lab's few looks: soft rounded cards and buttons in the game's palette
## (cream, ink, leaf green, coin gold), big type, and icon buttons drawn as
## shapes -- no glyph the font might not have.

const INK := Color("#2b3a4a")
const CREAM := Color("#fff8e7")
const LEAF := Color("#4fb36b")
const LEAF_DARK := Color("#2f8a4c")
const GOLD := Color("#f6c344")
const MUTED := Color("#a7b0b8")
const SKY := Color("#e8f6ff")


static func box(color: Color, radius: int = 28, border: Color = Color(0, 0, 0, 0), border_w: int = 0, shadow: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	if border_w > 0:
		s.border_color = border
		s.set_border_width_all(border_w)
	if shadow > 0:
		s.shadow_color = Color(0.05, 0.12, 0.2, 0.22)
		s.shadow_size = shadow
		s.shadow_offset = Vector2(0, shadow * 0.5)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.anti_aliasing = true
	return s


static func button(b: Button, color: Color, font_size: int = 36, text_color: Color = Color.WHITE) -> Button:
	b.add_theme_stylebox_override("normal", box(color))
	b.add_theme_stylebox_override("hover", box(color.lightened(0.08)))
	b.add_theme_stylebox_override("pressed", box(color.darkened(0.12), 28, Color(0, 0, 0, 0), 0, 2))
	b.add_theme_stylebox_override("disabled", box(MUTED))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", font_size)
	for k: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, text_color)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.85))
	b.focus_mode = Control.FOCUS_NONE
	return b


static func label(text: String, size: int = 32, color: Color = INK, outline: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", Color(0.1, 0.16, 0.24, 0.85))
		l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
