class_name Bar
extends Control

## A thin rounded progress bar (0..1) in the HUD's style.

var value := 0.0:
	set(v):
		value = clampf(v, 0.0, 1.0)
		queue_redraw()
var fill := Color("#9be15d")
var track := Color(1, 1, 1, 0.22)


func _init(p_fill: Color = Color("#9be15d")) -> void:
	fill = p_fill
	custom_minimum_size = Vector2(80, 10)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r := size.y * 0.5
	_rounded(Rect2(Vector2.ZERO, size), track, r)
	if value > 0.0:
		_rounded(Rect2(Vector2.ZERO, Vector2(maxf(size.x * value, size.y), size.y)), fill, r)


func _rounded(rect: Rect2, color: Color, r: float) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(r))
	draw_style_box(box, rect)
