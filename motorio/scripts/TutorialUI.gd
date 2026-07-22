extends Control

var main_controller

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if main_controller == null or main_controller.tutorial_complete():
		return
	var width := minf(390.0, size.x - 24.0)
	var panel := Rect2(Vector2(size.x - width - 16.0, 204.0), Vector2(width, 112.0))
	UIVisuals.draw_panel(self, panel, Color(0.035, 0.10, 0.105, 0.92), Color(0.84, 0.68, 0.34, 0.9), 14, 2)
	UIVisuals.draw_panel(self, Rect2(panel.position + Vector2(12, 10), Vector2(116, 25)), Color(0.82, 0.55, 0.20, 0.92), Color(1.0, 0.83, 0.48, 0.8), 9, 1)
	var font := UIFont.FONT
	draw_string(font, panel.position + Vector2(22, 28), "빠른 시작  %d/8" % (main_controller.tutorial_step + 1), HORIZONTAL_ALIGNMENT_LEFT, 102, 12, Color("fff4d3"))
	draw_string(font, panel.position + Vector2(16, 58), main_controller.tutorial_title(), HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 32.0, 17, Color("f9fbf6"))
	draw_string(font, panel.position + Vector2(16, 84), main_controller.tutorial_detail(), HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 32.0, 12, Color(0.79, 0.89, 0.87, 0.92))
	var progress_back := Rect2(panel.position + Vector2(16, 98), Vector2(panel.size.x - 32.0, 4.0))
	draw_rect(progress_back, Color(0.08, 0.18, 0.18, 0.8))
	draw_rect(Rect2(progress_back.position, Vector2(progress_back.size.x * float(main_controller.tutorial_step + 1) / 8.0, 4.0)), Color("e8b653"))
	if main_controller.tutorial_step == 4:
		draw_circle(panel.position + Vector2(panel.size.x - 90, 24), 5.0, Color("d69b35"))
		draw_string(font, panel.position + Vector2(panel.size.x - 80, 28), "IN", HORIZONTAL_ALIGNMENT_LEFT, 24, 9, Color("f0d18b"))
		draw_circle(panel.position + Vector2(panel.size.x - 48, 24), 5.0, Color("6ed0b0"))
		draw_string(font, panel.position + Vector2(panel.size.x - 38, 28), "OUT", HORIZONTAL_ALIGNMENT_LEFT, 30, 9, Color("b8f0cf"))
