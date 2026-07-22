extends RefCounted
class_name UIVisuals

static func panel(fill: Color, border: Color, radius: int = 12, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	return style

static func draw_panel(canvas: CanvasItem, rect: Rect2, fill: Color, border: Color, radius: int = 12, border_width: int = 1) -> void:
	canvas.draw_style_box(panel(fill, border, radius, border_width), rect)
