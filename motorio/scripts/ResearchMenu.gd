extends Control

var main_controller

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if main_controller == null or not main_controller.research_menu_open:
		return
	var panel := Rect2(size / 2.0 - Vector2(185, 145), Vector2(370, 290))
	draw_rect(panel, Color(0.045, 0.075, 0.09, 0.97))
	draw_rect(panel, Color("62c6d7"), false, 3.0)
	var font: Font = UIFont.FONT
	draw_string(font, panel.position + Vector2(22, 35), "극지 연구소", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("b9f2f4"))
	for index in main_controller.research_count():
		var y: float = 82.0 + index * 48.0
		var selected: bool = index == main_controller.research_selection
		if selected:
			draw_rect(Rect2(panel.position + Vector2(14, y - 26), Vector2(342, 38)), Color(0.12, 0.25, 0.28, 0.95))
			draw_string(font, panel.position + Vector2(20, y), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("f2d36b"))
		var color := Color.WHITE if selected else Color("9eafb3")
		draw_string(font, panel.position + Vector2(43, y), main_controller.research_label(index), HORIZONTAL_ALIGNMENT_LEFT, 170, 15, color)
		draw_string(font, panel.position + Vector2(215, y), main_controller.research_duration_text(index), HORIZONTAL_ALIGNMENT_LEFT, 125, 12, Color("79dce6"))
	var status: String = main_controller.research_status_text()
	draw_string(font, panel.position + Vector2(22, 238), status, HORIZONTAL_ALIGNMENT_LEFT, 325, 13, Color("f0c96c"))
	draw_string(font, panel.position + Vector2(22, 270), "이동 선택   Z 연구   X 나가기", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("becbce"))
