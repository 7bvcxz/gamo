class_name HudButton
extends Button

## A small square corner button: an icon over a one-word label. Compact on
## purpose -- the island is the picture, the buttons are the frame.

const SIZE := Vector2(68, 68)

var action: StringName
var label_key: String
var badge := false:
	set(value):
		badge = value
		queue_redraw()

var _icon_rect: TextureRect
var _label: Label


func _init(p_action: StringName, p_label_key: String, icon_texture: Texture2D) -> void:
	action = p_action
	label_key = p_label_key
	name = "Button_" + String(p_action)
	custom_minimum_size = SIZE
	size = SIZE
	focus_mode = Control.FOCUS_NONE
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_icon_rect = TextureRect.new()
	_icon_rect.texture = icon_texture
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.custom_minimum_size = Vector2(30, 30)
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	box.add_child(_icon_rect)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 15)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_label)
	refresh_text()


func refresh_text() -> void:
	_label.text = tr(label_key)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _label != null:
		refresh_text()


func _draw() -> void:
	if badge:
		draw_circle(Vector2(size.x - 8, 8), 6.5, Color("#ff5a4f"))
		draw_arc(Vector2(size.x - 8, 8), 6.5, 0, TAU, 16, Color.WHITE, 1.6, true)
