extends Control

var main_controller

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if main_controller == null or not main_controller.base_menu_open:
		return
	var panel: Rect2 = Rect2(size / 2.0 - Vector2(170, 150), Vector2(340, 300))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.04, 0.05, 0.34))
	UIVisuals.draw_panel(self, panel, Color(0.035, 0.10, 0.105, 0.98), Color("d7a84c"), 18, 2)
	UIVisuals.draw_panel(self, Rect2(panel.position + Vector2(14, 12), Vector2(312, 42)), Color(0.08, 0.18, 0.18, 0.95), Color(0.42, 0.63, 0.60, 0.5), 12, 1)
	var font: Font = UIFont.FONT
	var page: int = main_controller.fabricator_selection / 4
	var page_count: int = ceili(float(main_controller.fabricator_recipe_count()) / 4.0)
	draw_string(font, panel.position + Vector2(28, 41), "기지 제작소", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("f5d88f"))
	draw_string(font, panel.position + Vector2(260, 39), "%d / %d" % [page + 1, page_count], HORIZONTAL_ALIGNMENT_CENTER, 52, 12, Color("9fc8c3"))
	for row in range(4):
		var recipe_index := page * 4 + row
		if recipe_index >= main_controller.fabricator_recipe_count():
			continue
		_draw_recipe(font, panel, recipe_index, 72.0 + row * 36.0)
	var status: String = main_controller.fabricator_status
	draw_string(font, panel.position + Vector2(22, 230), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("8dd9cb"))
	draw_string(font, panel.position + Vector2(22, 272), "이동 선택   Z 제작   X 나가기", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("b9c5be"))

func _draw_recipe(font: Font, panel: Rect2, index: int, y: float) -> void:
	var selected: bool = main_controller.fabricator_selection == index
	if selected:
		UIVisuals.draw_panel(self, Rect2(panel.position + Vector2(14, y - 24), Vector2(312, 31)), Color(0.15, 0.28, 0.25, 0.96), Color(0.83, 0.65, 0.29, 0.55), 8, 1)
		draw_circle(panel.position + Vector2(26, y - 6), 4.0, Color("f2d38a"))
	var color := Color.WHITE if selected else Color("9eaaa4")
	draw_string(font, panel.position + Vector2(38, y), main_controller.recipe_label(index), HORIZONTAL_ALIGNMENT_LEFT, 190, 15, color)
	var cost: String = main_controller.recipe_cost_text(index)
	var cost_color := Color("73d7df") if index >= 4 else Color("e7aa45")
	if not main_controller.recipe_unlocked(index):
		cost = "%d단계" % main_controller.recipe_unlock_level(index)
		cost_color = Color("8a9290")
	draw_string(font, panel.position + Vector2(240, y), cost, HORIZONTAL_ALIGNMENT_LEFT, 90, 11, cost_color)
