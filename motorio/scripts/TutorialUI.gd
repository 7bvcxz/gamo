extends Control

var main_controller

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if main_controller == null or main_controller.tutorial_complete():
		return
	var width := minf(390.0, size.x - 24.0)
	var panel := Rect2(Vector2((size.x - width) / 2.0, 170.0), Vector2(width, 104.0))
	draw_rect(panel, Color(0.025, 0.05, 0.043, 0.96))
	draw_rect(panel, Color("f0bd4f"), false, 3.0)
	var font := ThemeDB.fallback_font
	draw_string(font, panel.position + Vector2(16, 25), "QUICK START  %d/6" % (main_controller.tutorial_step + 1), HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 32.0, 15, Color("f0bd4f"))
	draw_string(font, panel.position + Vector2(16, 52), main_controller.tutorial_title(), HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 32.0, 16, Color.WHITE)
	draw_string(font, panel.position + Vector2(16, 78), main_controller.tutorial_detail(), HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 32.0, 12, Color("cbd9cf"))
	if main_controller.tutorial_step == 4:
		draw_rect(Rect2(panel.position + Vector2(16, 86), Vector2(12, 8)), Color("d69b35"))
		draw_string(font, panel.position + Vector2(34, 95), "IN", HORIZONTAL_ALIGNMENT_LEFT, 30, 10, Color("f0d18b"))
		draw_rect(Rect2(panel.position + Vector2(72, 86), Vector2(12, 8)), Color("6ed0b0"))
		draw_string(font, panel.position + Vector2(90, 95), "OUT", HORIZONTAL_ALIGNMENT_LEFT, 36, 10, Color("b8f0cf"))
