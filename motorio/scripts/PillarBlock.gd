extends RigidBody2D
class_name PillarBlock

const TILE_SIZE := 32.0

func _ready() -> void:
	add_to_group("pickup_block")
	add_to_group("solid")
	add_to_group("pillar_block")
	freeze = true
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2(3, 5), 13.0, Color(0.03, 0.08, 0.09, 0.28))
	UIVisuals.draw_panel(self, Rect2(-12, -14, 24, 28), Color("547078"), Color("263f45"), 5, 2)
	draw_rect(Rect2(-8, -10, 16, 20), Color("8fa7aa"))
	draw_rect(Rect2(-13, -15, 26, 5), Color("d5e0de"))
	draw_rect(Rect2(-13, 10, 26, 5), Color("324e52"))
	draw_line(Vector2(-5, -9), Vector2(-5, 9), Color(1, 1, 1, 0.32), 2.0)
	draw_circle(Vector2(7, -7), 2.0, Color("e6b858"))
