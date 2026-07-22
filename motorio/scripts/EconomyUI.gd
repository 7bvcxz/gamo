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
	var panel := Rect2(10, 12, 138, 14 + shown.size() * 22)
	draw_rect(panel, Color(0.025, 0.05, 0.042, 0.84))
	draw_rect(panel, Color("658374"), false, 1.0)
	var font := UIFont.FONT
	for row in shown.size():
		var index: int = shown[row]
		var position := Vector2(18, 32 + row * 22)
		draw_circle(position + Vector2(5, -5), 5.0, RESOURCE_COLORS[index])
		draw_circle(position + Vector2(4, -6), 1.5, RESOURCE_COLORS[index].lightened(0.45))
		draw_string(font, position + Vector2(16, 0), "%s  %d" % [RESOURCE_NAMES[index], values[index]], HORIZONTAL_ALIGNMENT_LEFT, 102, 12, Color("edf5ef"))
