extends StaticBody2D
class_name MineralBlock

const TILE_SIZE := 32.0

func _ready() -> void:
	add_to_group("mineral_block")
	add_to_group("fixed")
	queue_redraw()

func _draw() -> void:
	draw_ellipse_shadow()
	var back := PackedVector2Array([Vector2(-12, 9), Vector2(-9, -4), Vector2(-3, -12), Vector2(2, -2), Vector2(8, -14), Vector2(13, 8)])
	draw_polygon(back, PackedColorArray([Color("32758a")]))
	draw_polygon(PackedVector2Array([Vector2(-9, 7), Vector2(-7, -3), Vector2(-3, -9), Vector2(0, 0), Vector2(5, -10), Vector2(10, 7)]), PackedColorArray([Color("65c9d7")]))
	draw_polygon(PackedVector2Array([Vector2(-6, 3), Vector2(-4, -4), Vector2(-2, -7), Vector2(-1, 1)]), PackedColorArray([Color(0.84, 0.98, 1.0, 0.8)]))
	draw_polygon(PackedVector2Array([Vector2(4, 1), Vector2(7, -8), Vector2(8, 5)]), PackedColorArray([Color(0.76, 0.95, 0.98, 0.72)]))
	draw_polyline(PackedVector2Array([Vector2(-12, 9), Vector2(-9, -4), Vector2(-3, -12), Vector2(2, -2), Vector2(8, -14), Vector2(13, 8)]), Color("d4f8fa"), 1.4)

func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2(2, 10), 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, 13.0, Color(0.08, 0.17, 0.20, 0.22))
	draw_set_transform(Vector2.ZERO)
