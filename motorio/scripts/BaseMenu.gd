extends Control

var main_controller

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if main_controller == null or not main_controller.base_menu_open:
		return
	var panel: Rect2 = Rect2(size / 2.0 - Vector2(150, 92), Vector2(300, 184))
	draw_rect(panel, Color(0.055, 0.08, 0.075, 0.96))
	draw_rect(panel, Color("d7a33f"), false, 3.0)
	var font: Font = ThemeDB.fallback_font
	draw_string(font, panel.position + Vector2(22, 34), "BASE FABRICATOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("f2d38a"))
	draw_string(font, panel.position + Vector2(22, 72), "CAT BLOCK", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
	draw_string(font, panel.position + Vector2(190, 72), "3 BOX", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("e7aa45"))
	var status: String = main_controller.fabricator_status
	draw_string(font, panel.position + Vector2(22, 112), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("8dd9cb"))
	draw_string(font, panel.position + Vector2(22, 151), "Z  CRAFT     X  CLOSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("b9c5be"))
