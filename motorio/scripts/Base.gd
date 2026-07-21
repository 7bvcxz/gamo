extends StaticBody2D

const RADIUS := 72.0

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	# Compact circular hub with a raised industrial center.
	draw_circle(Vector2(4, 7), RADIUS, Color(0.02, 0.03, 0.025, 0.42))
	draw_circle(Vector2.ZERO, RADIUS, Color("53605b"))
	draw_circle(Vector2.ZERO, 63.0, Color("283b35"))
	draw_arc(Vector2.ZERO, 63.0, 0.0, TAU, 64, Color("d69b35"), 4.0)

	for angle_index in range(8):
		var angle := angle_index * TAU / 8.0
		var bolt_position := Vector2.from_angle(angle) * 54.0
		draw_circle(bolt_position, 4.0, Color("d9c99d"))

	draw_circle(Vector2.ZERO, 34.0, Color("192722"))
	draw_circle(Vector2.ZERO, 24.0, Color("be7e2c"))
	draw_polygon(
		PackedVector2Array([Vector2(0, -17), Vector2(15, 10), Vector2(-15, 10)]),
		PackedColorArray([Color("f0c04f")])
	)
