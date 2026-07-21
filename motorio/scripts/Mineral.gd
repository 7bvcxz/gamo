extends StaticBody2D
class_name MineralBlock

const TILE_SIZE := 32.0

func _ready() -> void:
	add_to_group("mineral_block")
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ONE * -15.0, Vector2.ONE * 30.0)
	draw_rect(rect, Color("35566b"))
	draw_polygon(PackedVector2Array([Vector2(-11, 7), Vector2(-5, -10), Vector2(1, -2), Vector2(7, -12), Vector2(12, 8)]), PackedColorArray([Color("74c7d5")]))
	draw_polyline(PackedVector2Array([Vector2(-11, 7), Vector2(-5, -10), Vector2(1, -2), Vector2(7, -12), Vector2(12, 8)]), Color("b8edf0"), 2.0)
