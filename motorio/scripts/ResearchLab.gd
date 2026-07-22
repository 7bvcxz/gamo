extends RigidBody2D
class_name ResearchLab

@export var installed := false

func _ready() -> void:
	add_to_group("pickup_block")
	add_to_group("solid")
	add_to_group("research_lab")
	freeze = true
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-47, -47, 94, 94), Color("263b45"))
	draw_rect(Rect2(-44, -44, 88, 88), Color("6f8790"), false, 4.0)
	draw_circle(Vector2.ZERO, 27.0, Color("142a32"))
	draw_circle(Vector2.ZERO, 20.0, Color("62d8e7"), false, 5.0)
	draw_line(Vector2(-18, 18), Vector2(18, -18), Color("f0c85a"), 4.0)
	draw_circle(Vector2(18, -18), 7.0, Color("fff0a3"))
	var font: Font = UIFont.FONT
	draw_string(font, Vector2(-31, 38), "연구소", HORIZONTAL_ALIGNMENT_CENTER, 62, 13, Color.WHITE)
