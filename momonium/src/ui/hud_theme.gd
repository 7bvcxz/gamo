class_name HudTheme
extends RefCounted

## The look shared by every piece of UI: translucent navy panels with soft
## round corners, white text, a warm yellow accent. Built in code from the
## palette so a colour lives in one place (data/art.json).

const RADIUS := 18
const BODY_SIZE := 20


static func build(data: GameData, font: Font) -> Theme:
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = BODY_SIZE
	var panel_color := data.color("ui_panel")
	panel_color.a = data.get_float("art", "palette.ui_panel_alpha", 0.62)
	var text := data.color("ui_text")

	t.set_stylebox("panel", "PanelContainer", _box(panel_color, RADIUS, 12))
	t.set_color("font_color", "Label", text)
	t.set_color("font_shadow_color", "Label", Color(0, 0.07, 0.2, 0.35))
	t.set_constant("shadow_offset_y", "Label", 1)

	var normal := _box(panel_color, 16, 6)
	var hover := _box(panel_color.lightened(0.12), 16, 6)
	var pressed := _box(panel_color.darkened(0.2), 16, 6)
	for style: Array in [["normal", normal], ["hover", hover], ["pressed", pressed], ["focus", StyleBoxEmpty.new()], ["disabled", normal]]:
		t.set_stylebox(style[0], "Button", style[1])
	t.set_color("font_color", "Button", text)
	t.set_color("font_hover_color", "Button", text)
	t.set_color("font_pressed_color", "Button", text)
	return t


static func _box(color: Color, radius: int, pad: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(pad)
	box.anti_aliasing = true
	return box
