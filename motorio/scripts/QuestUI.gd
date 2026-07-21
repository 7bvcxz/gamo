extends Control

var main_controller

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if main_controller == null:
		return
	var width := minf(390.0, size.x - 32.0)
	var panel := Rect2(Vector2((size.x - width) / 2.0, 270.0), Vector2(width, 64.0))
	draw_rect(panel, Color(0.035, 0.065, 0.055, 0.9))
	draw_rect(panel, Color("6e8f72"), false, 2.0)
	var font := ThemeDB.fallback_font
	draw_string(font, panel.position + Vector2(14, 22), main_controller.quest_title(), HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 28.0, 13, Color("f1c653"))
	draw_string(font, panel.position + Vector2(14, 47), main_controller.quest_detail(), HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 28.0, 12, Color("e2ece4"))
	if main_controller.celebration_remaining > 0.0:
		var banner := Rect2(Vector2((size.x - 280.0) / 2.0, panel.end.y + 10.0), Vector2(280, 38))
		draw_rect(banner, Color(0.12, 0.24, 0.18, 0.94))
		draw_rect(banner, Color("f1c653"), false, 2.0)
		draw_string(font, banner.position + Vector2(12, 25), main_controller.celebration_text, HORIZONTAL_ALIGNMENT_CENTER, banner.size.x - 24.0, 14, Color.WHITE)
