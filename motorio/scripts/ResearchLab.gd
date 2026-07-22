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
	draw_circle(Vector2(5, 8), 48.0, Color(0.03, 0.09, 0.11, 0.3))
	UIVisuals.draw_panel(self, Rect2(-47, -47, 94, 94), Color("274a52"), Color("88a7a8"), 12, 3)
	draw_rect(Rect2(-39, -39, 78, 78), Color(0.08, 0.20, 0.23, 0.62), false, 2.0)
	draw_circle(Vector2.ZERO, 27.0, Color("142a32"))
	draw_circle(Vector2.ZERO, 20.0, Color("62d8e7"), false, 4.0)
	draw_circle(Vector2(-6, -7), 9.0, Color(0.53, 0.95, 0.98, 0.16))
	draw_line(Vector2(-18, 18), Vector2(18, -18), Color("f0c85a"), 4.0)
	draw_circle(Vector2(18, -18), 7.0, Color("fff0a3"))
	var font: Font = UIFont.FONT
	draw_string(font, Vector2(-31, 40), "연구소", HORIZONTAL_ALIGNMENT_CENTER, 62, 12, Color(0.84, 0.95, 0.94, 0.9))
