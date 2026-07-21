extends Control

var main_controller

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if main_controller == null or not main_controller.base_menu_open:
		return
	var panel: Rect2 = Rect2(size / 2.0 - Vector2(170, 150), Vector2(340, 300))
	draw_rect(panel, Color(0.055, 0.08, 0.075, 0.96))
	draw_rect(panel, Color("d7a33f"), false, 3.0)
	var font: Font = ThemeDB.fallback_font
	var page: int = main_controller.fabricator_selection / 4
	var page_count: int = ceili(float(main_controller.fabricator_recipe_count()) / 4.0)
	draw_string(font, panel.position + Vector2(22, 34), "BASE FABRICATOR   %d/%d" % [page + 1, page_count], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("f2d38a"))
	for row in range(4):
		var recipe_index := page * 4 + row
		if recipe_index >= main_controller.fabricator_recipe_count():
			continue
		_draw_recipe(font, panel, recipe_index, 72.0 + row * 36.0)
	var status: String = main_controller.fabricator_status
	draw_string(font, panel.position + Vector2(22, 230), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("8dd9cb"))
	draw_string(font, panel.position + Vector2(22, 272), "Z CRAFT   X SELECT   RUN CLOSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("b9c5be"))

func _draw_recipe(font: Font, panel: Rect2, index: int, y: float) -> void:
	var selected: bool = main_controller.fabricator_selection == index
	if selected:
		draw_rect(Rect2(panel.position + Vector2(14, y - 24), Vector2(312, 31)), Color(0.16, 0.25, 0.21, 0.9))
		draw_string(font, panel.position + Vector2(20, y), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("f2d38a"))
	var color := Color.WHITE if selected else Color("9eaaa4")
	draw_string(font, panel.position + Vector2(42, y), main_controller.recipe_label(index), HORIZONTAL_ALIGNMENT_LEFT, 190, 15, color)
	var cost: String = main_controller.recipe_cost_text(index)
	var cost_color := Color("73d7df") if index >= 4 else Color("e7aa45")
	if index == 3 and main_controller.base_level < 2:
		cost = "LOCKED"
		cost_color = Color("8a9290")
	draw_string(font, panel.position + Vector2(240, y), cost, HORIZONTAL_ALIGNMENT_LEFT, 90, 11, cost_color)
