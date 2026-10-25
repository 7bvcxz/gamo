class_name Backdrop
extends Node2D

## Placeholder sky and sea behind everything: sky in the top two fifths of the
## screen, open water below. Replaced by the ocean (Step 08) and the sky
## (Step 09); kept here so the screen is never an engine-grey void.

const SKY_FRACTION := 0.4
const SKY_TOP := Color(0.243, 0.553, 0.910)
const SKY_HORIZON := Color(0.733, 0.890, 0.992)
const SEA_HORIZON := Color(0.408, 0.765, 0.969)
const SEA_DEEP := Color(0.106, 0.459, 0.788)


func _ready() -> void:
	get_viewport().size_changed.connect(queue_redraw)


func _draw() -> void:
	var size: Vector2 = get_viewport_rect().size
	var horizon: float = size.y * SKY_FRACTION
	_vertical_gradient(Rect2(0, 0, size.x, horizon), SKY_TOP, SKY_HORIZON)
	_vertical_gradient(Rect2(0, horizon, size.x, size.y - horizon), SEA_HORIZON, SEA_DEEP)


func _vertical_gradient(rect: Rect2, top: Color, bottom: Color) -> void:
	var points := PackedVector2Array([
		rect.position, rect.position + Vector2(rect.size.x, 0),
		rect.end, rect.position + Vector2(0, rect.size.y)])
	draw_polygon(points, PackedColorArray([top, top, bottom, bottom]))
