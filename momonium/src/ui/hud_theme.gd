class_name HudTheme
extends RefCounted

## The look shared by every piece of UI: translucent navy panels with soft
## round corners, white text, a warm yellow accent. Built in code from the
## palette so a colour lives in one place (data/art.json).
##
## Step 52: two themes, as in the concept art. The HUD (corner pills, the build
## strip, the cards on the island) keeps the navy glass; a panel you read --
## Status, Research, a building's page, the mailbox -- is a card of frosted
## white glass with navy ink (`build_card`). Views never pick a colour for a
## meaning themselves: they name it (`GoodLabel`, `Bar.track`, `Ink.glyph`...)
## and each theme answers in its own colours, so the same view reads on both.

const RADIUS := 18
const BODY_SIZE := 20
const RIM_ALPHA := 0.2
const CARD_RADIUS := 22

## Meanings -> colour on navy glass, and on white glass.
const ON_NAVY := {
	"GoodLabel": "#b7f08a", "BadLabel": "#ffb3a8", "GoldLabel": "#ffe27a", "InfoLabel": "#cfe9ff",
	"track": Color(1, 1, 1, 0.22), "glyph": Color(1, 1, 1, 0.95), "line": Color(1, 1, 1, 0.75),
}
const ON_WHITE := {
	"GoodLabel": "#2f8a3a", "BadLabel": "#c4453a", "GoldLabel": "#b5730f", "InfoLabel": "#2f6aa8",
	"track": Color(0.11, 0.23, 0.39, 0.13), "glyph": Color("#26466f"), "line": Color(0.11, 0.23, 0.39, 0.55),
}
const INK := Color("#1f3b62")


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
	_meanings(t, ON_NAVY)
	var sel := _box(data.color("ui_accent").darkened(0.05), 16, 6)
	_selected(t, sel, Color("#1f3b62"))
	return t


## The reading card (Step 52): frosted white glass, navy ink, pale-blue
## buttons -- the concept's Status panel.
static func build_card(data: GameData, font: Font) -> Theme:
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = BODY_SIZE
	var glass := Color(1, 1, 1, 0.62)
	var box := _box(glass, 16, 12)
	box.border_color = Color(1, 1, 1, 0.95)
	box.shadow_color = Color(0.1, 0.22, 0.4, 0.08)
	box.shadow_size = 4
	t.set_stylebox("panel", "PanelContainer", box)
	t.set_color("font_color", "Label", INK)
	t.set_color("font_shadow_color", "Label", Color(1, 1, 1, 0))
	var face := Color("#dcebfb")
	var normal := _box(face, 16, 6)
	normal.border_color = Color(1, 1, 1, 0.95)
	normal.shadow_color = Color(0.1, 0.22, 0.4, 0.12)
	normal.shadow_size = 3
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = face.lightened(0.35)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = face.darkened(0.12)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(face, 0.5)
	for style: Array in [["normal", normal], ["hover", hover], ["pressed", pressed], ["focus", StyleBoxEmpty.new()], ["disabled", disabled]]:
		t.set_stylebox(style[0], "Button", style[1])
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(INK, 0.45))
	_meanings(t, ON_WHITE)
	var sel := _box(Color("#2f5f9e"), 16, 6)
	sel.border_color = Color(1, 1, 1, 0.95)
	_selected(t, sel, Color.WHITE)
	return t


## The card a panel sits on: the theme's own glass, denser.
static func card_box(t: Theme, alpha: float) -> StyleBoxFlat:
	var box := (t.get_stylebox("panel", "PanelContainer") as StyleBoxFlat).duplicate() as StyleBoxFlat
	box.bg_color.a = alpha
	box.set_corner_radius_all(CARD_RADIUS)
	return box


## Named label colours and the colours drawn by hand (bar tracks, glyph
## icons, chart lines), so a view asks for a meaning, not a colour.
static func _meanings(t: Theme, m: Dictionary) -> void:
	for variation: String in ["GoodLabel", "BadLabel", "GoldLabel", "InfoLabel"]:
		t.set_type_variation(variation, "Label")
		t.set_color("font_color", variation, Color(m[variation]))
	for key: String in ["track", "glyph", "line"]:
		t.set_color(key, "Ink", m[key])


## The current tab or choice: a filled button that says "this one".
static func _selected(t: Theme, box: StyleBoxFlat, text: Color) -> void:
	t.set_type_variation("SelectedButton", "Button")
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(state, "SelectedButton", box)
	for c: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		t.set_color(c, "SelectedButton", text)


## Glass, not slabs (Step 46): a hairline of light around the edge and a
## soft shadow under it lift a panel off the world without making it heavier.
static func _box(color: Color, radius: int, pad: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(pad)
	box.border_color = Color(1, 1, 1, RIM_ALPHA)
	box.set_border_width_all(1)
	box.border_blend = true
	box.shadow_color = Color(0.0, 0.04, 0.14, 0.22)
	box.shadow_size = 6
	box.shadow_offset = Vector2(0, 2)
	box.anti_aliasing = true
	return box
