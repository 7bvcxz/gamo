extends Node2D

## Entry scene. For now it only paints the portrait backdrop the game is built
## around -- sky in the top two fifths, open sea below -- and the build version
## in the corner, so a deploy can be identified at a glance.

const SKY_FRACTION := 0.4
const SKY_TOP := Color(0.243, 0.553, 0.910)
const SKY_HORIZON := Color(0.733, 0.890, 0.992)
const SEA_HORIZON := Color(0.408, 0.765, 0.969)
const SEA_DEEP := Color(0.106, 0.459, 0.788)

var _version_label: Label


func _ready() -> void:
	_version_label = Label.new()
	_version_label.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0")
	_version_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	_version_label.add_theme_font_size_override("font_size", 14)
	add_child(_version_label)
	get_viewport().size_changed.connect(_layout)
	_layout()
	WebBridge.publish_ready(_version_label.text.trim_prefix("v"))


func _layout() -> void:
	var size: Vector2 = get_viewport_rect().size
	_version_label.position = size - Vector2(84, 28)
	queue_redraw()


func _draw() -> void:
	var size: Vector2 = get_viewport_rect().size
	var horizon: float = size.y * SKY_FRACTION
	_vertical_gradient(Rect2(0, 0, size.x, horizon), SKY_TOP, SKY_HORIZON)
	_vertical_gradient(Rect2(0, horizon, size.x, size.y - horizon), SEA_HORIZON, SEA_DEEP)


func _vertical_gradient(rect: Rect2, top: Color, bottom: Color) -> void:
	var points := PackedVector2Array([
		rect.position, rect.position + Vector2(rect.size.x, 0),
		rect.end, rect.position + Vector2(0, rect.size.y)])
	var colors := PackedColorArray([top, top, bottom, bottom])
	draw_polygon(points, colors)
