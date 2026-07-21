extends Control

var main_controller

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if main_controller == null or not main_controller.base_menu_open:
		return
	var panel: Rect2 = Rect2(size / 2.0 - Vector2(170, 132), Vector2(340, 264))
	draw_rect(panel, Color(0.055, 0.08, 0.075, 0.96))
	draw_rect(panel, Color("d7a33f"), false, 3.0)
	var font: Font = ThemeDB.fallback_font
	draw_string(font, panel.position + Vector2(22, 34), "BASE FABRICATOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("f2d38a"))
	_draw_recipe(font, panel, 0, 72, "CAT BLOCK")
	_draw_recipe(font, panel, 1, 108, "PILLAR BLOCK")
	_draw_recipe(font, panel, 2, 144, "BOX GENERATOR")
	var status: String = main_controller.fabricator_status
	draw_string(font, panel.position + Vector2(22, 194), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("8dd9cb"))
	draw_string(font, panel.position + Vector2(22, 236), "Z CRAFT   X SELECT   RUN CLOSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("b9c5be"))

func _draw_recipe(font: Font, panel: Rect2, index: int, y: float, label: String) -> void:
	var selected: bool = main_controller.fabricator_selection == index
	if selected:
		draw_rect(Rect2(panel.position + Vector2(14, y - 24), Vector2(312, 31)), Color(0.16, 0.25, 0.21, 0.9))
		draw_string(font, panel.position + Vector2(20, y), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("f2d38a"))
	var color := Color.WHITE if selected else Color("9eaaa4")
	draw_string(font, panel.position + Vector2(42, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, color)
	var cost := "10 MIN" if index == 2 else "3 BOX"
	var cost_color := Color("73d7df") if index == 2 else Color("e7aa45")
	draw_string(font, panel.position + Vector2(250, y), cost, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, cost_color)
