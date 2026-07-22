extends Control

var main_controller

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if main_controller == null or not main_controller.tutorial_complete():
		return
	var width := minf(390.0, size.x - 32.0)
	var panel := Rect2(Vector2(size.x - width - 16.0, 326.0), Vector2(width, 126.0))
	UIVisuals.draw_panel(self, panel, Color(0.035, 0.10, 0.105, 0.9), Color(0.36, 0.61, 0.58, 0.78), 14, 2)
	var font := UIFont.FONT
	draw_string(font, panel.position + Vector2(16, 25), "현재 목표", HORIZONTAL_ALIGNMENT_LEFT, 80, 10, Color(0.55, 0.76, 0.73, 0.9))
	draw_string(font, panel.position + Vector2(16, 49), main_controller.quest_title(), HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 32.0, 15, Color("f3c65d"))
	draw_multiline_string(font, panel.position + Vector2(16, 72), main_controller.quest_detail(), HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 32.0, 12, 2, Color("e2ece4"))
	draw_multiline_string(font, panel.position + Vector2(16, 102), main_controller.quest_unlock_help(), HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 32.0, 10, 2, Color("9fd9dc"))
	if main_controller.celebration_remaining > 0.0:
		var banner := Rect2(Vector2((size.x - 280.0) / 2.0, panel.end.y + 10.0), Vector2(280, 38))
		UIVisuals.draw_panel(self, banner, Color(0.12, 0.27, 0.22, 0.95), Color("f1c653"), 12, 2)
		draw_string(font, banner.position + Vector2(12, 25), main_controller.celebration_text, HORIZONTAL_ALIGNMENT_CENTER, banner.size.x - 24.0, 14, Color.WHITE)
