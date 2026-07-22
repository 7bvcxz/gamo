extends Control

const RESOURCE_ORDER := ["copper", "coal", "crystal", "oil", "uranium"]
const RESOURCE_COLORS := [Color("e58b4f"), Color("879198"), Color("c4a2ff"), Color("61769e"), Color("9bef67")]
const RESOURCE_NAMES := ["구리", "석탄", "수정", "석유", "우라늄"]
var main_controller

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if main_controller == null:
		return
	var stage: int = main_controller.ui_stage()
	var visible_count := 2 if stage == 2 else (3 if stage == 3 else 5)
	var panel_height := 58.0 if stage == 2 else (78.0 if stage == 3 else 94.0)
	draw_rect(Rect2(10, 158, 212, panel_height), Color(0.025, 0.05, 0.042, 0.78))
	draw_rect(Rect2(10, 158, 212, panel_height), Color("5f7967"), false, 1.0)
	var font := UIFont.FONT
	for index in visible_count:
		var column := index % 2
		var row := index / 2
		var position := Vector2(16 + column * 104, 174 + row * 20)
		draw_circle(position + Vector2(5, -4), 4.0, RESOURCE_COLORS[index])
		draw_string(font, position + Vector2(14, 0), "%s %d" % [RESOURCE_NAMES[index], main_controller.resource_counts[RESOURCE_ORDER[index]]], HORIZONTAL_ALIGNMENT_LEFT, 86, 11, Color("e2ebe4"))
	if stage >= 3:
		draw_string(font, Vector2(16, 224 if stage == 3 else 242), "전력 %d   물고기 %d" % [main_controller.electricity, main_controller.fish], HORIZONTAL_ALIGNMENT_LEFT, 210, 11, Color("f1d86a"))
