extends Control

const RESOURCE_ORDER := ["box", "mineral", "copper", "coal", "crystal", "oil", "uranium", "electricity", "fish"]
const RESOURCE_COLORS := [Color("d69b4b"), Color("67c2d1"), Color("e58b4f"), Color("879198"), Color("c4a2ff"), Color("61769e"), Color("9bef67"), Color("f3d650"), Color("72cfe5")]
const RESOURCE_NAMES := ["상자", "미네랄", "구리", "석탄", "수정", "석유", "우라늄", "전력", "물고기"]
var main_controller

func _process(_delta: float) -> void:
	queue_redraw()

func resource_values() -> Array[int]:
	var values: Array[int] = [main_controller.box_count, main_controller.mineral_count]
	for resource_type in ["copper", "coal", "crystal", "oil", "uranium"]:
		values.append(main_controller.resource_counts[resource_type])
	values.append(main_controller.electricity)
	values.append(main_controller.fish)
	return values

func visible_resource_indices() -> Array[int]:
	var shown: Array[int] = []
	var values := resource_values()
	for index in RESOURCE_ORDER.size():
		if values[index] > 0:
			shown.append(index)
	return shown

func _draw() -> void:
	if main_controller == null:
		return
	var values := resource_values()
	var shown := visible_resource_indices()
	if shown.is_empty():
		return
	var panel := Rect2(10, 12, 142, 16 + shown.size() * 23)
	UIVisuals.draw_panel(self, panel, Color(0.04, 0.11, 0.115, 0.58), Color(0.45, 0.67, 0.63, 0.48), 12, 1)
	var font := UIFont.FONT
	for row in shown.size():
		var index: int = shown[row]
		var position := Vector2(18, 34 + row * 23)
		var resource_color: Color = RESOURCE_COLORS[index]
		resource_color.a = 0.78
		draw_circle(position + Vector2(5, -5), 6.0, Color(0.02, 0.08, 0.09, 0.6))
		draw_circle(position + Vector2(5, -5), 4.2, resource_color)
		draw_circle(position + Vector2(4, -6), 1.5, Color(1.0, 1.0, 1.0, 0.48))
		draw_string(font, position + Vector2(16, 0), "%s  %d" % [RESOURCE_NAMES[index], values[index]], HORIZONTAL_ALIGNMENT_LEFT, 102, 12, Color(0.93, 0.97, 0.94, 0.78))
