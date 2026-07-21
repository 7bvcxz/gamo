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
	draw_circle(Vector2(3, 4), 12.0, Color(0.03, 0.04, 0.04, 0.4))
	draw_rect(Rect2(-11, -13, 22, 26), Color("777f82"))
	draw_rect(Rect2(-8, -10, 16, 20), Color("aeb6b5"))
	draw_rect(Rect2(-12, -15, 24, 5), Color("d4d9d5"))
	draw_rect(Rect2(-12, 10, 24, 5), Color("596365"))
	draw_line(Vector2(-5, -9), Vector2(-5, 9), Color(1, 1, 1, 0.22), 2.0)
