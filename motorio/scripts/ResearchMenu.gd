extends Control

var main_controller

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if main_controller == null or not main_controller.research_menu_open:
		return
	var panel := Rect2(size / 2.0 - Vector2(185, 145), Vector2(370, 290))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.04, 0.05, 0.34))
	UIVisuals.draw_panel(self, panel, Color(0.035, 0.10, 0.12, 0.98), Color("62c6d7"), 18, 2)
	UIVisuals.draw_panel(self, Rect2(panel.position + Vector2(14, 12), Vector2(342, 42)), Color(0.06, 0.19, 0.22, 0.96), Color(0.45, 0.78, 0.82, 0.4), 12, 1)
	var font: Font = UIFont.FONT
	draw_string(font, panel.position + Vector2(28, 41), "극지 연구소", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("c9f5f2"))
	for index in main_controller.research_count():
		var y: float = 82.0 + index * 48.0
		var selected: bool = index == main_controller.research_selection
		if selected:
			UIVisuals.draw_panel(self, Rect2(panel.position + Vector2(14, y - 26), Vector2(342, 38)), Color(0.11, 0.28, 0.30, 0.96), Color(0.45, 0.80, 0.82, 0.5), 9, 1)
			draw_circle(panel.position + Vector2(27, y - 7), 4.0, Color("f2d36b"))
		var color := Color.WHITE if selected else Color("9eafb3")
		draw_string(font, panel.position + Vector2(40, y), main_controller.research_label(index), HORIZONTAL_ALIGNMENT_LEFT, 170, 15, color)
		draw_string(font, panel.position + Vector2(215, y), main_controller.research_duration_text(index), HORIZONTAL_ALIGNMENT_LEFT, 125, 12, Color("79dce6"))
	var status: String = main_controller.research_status_text()
	draw_string(font, panel.position + Vector2(22, 238), status, HORIZONTAL_ALIGNMENT_LEFT, 325, 13, Color("f0c96c"))
	draw_string(font, panel.position + Vector2(22, 270), "이동 선택   Z 연구   X 나가기", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("becbce"))
