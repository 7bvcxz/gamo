extends Control

const RESOURCE_ORDER := ["copper", "coal", "crystal", "oil", "uranium"]
const RESOURCE_COLORS := [Color("e58b4f"), Color("879198"), Color("c4a2ff"), Color("61769e"), Color("9bef67")]
var main_controller

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if main_controller == null:
		return
	draw_rect(Rect2(10, 158, 212, 94), Color(0.025, 0.05, 0.042, 0.78))
	draw_rect(Rect2(10, 158, 212, 94), Color("5f7967"), false, 1.0)
	var font := ThemeDB.fallback_font
	for index in RESOURCE_ORDER.size():
		var column := index % 2
		var row := index / 2
		var position := Vector2(16 + column * 104, 174 + row * 20)
		draw_circle(position + Vector2(5, -4), 4.0, RESOURCE_COLORS[index])
		draw_string(font, position + Vector2(14, 0), "%s %d" % [RESOURCE_ORDER[index].to_upper().substr(0, 3), main_controller.resource_counts[RESOURCE_ORDER[index]]], HORIZONTAL_ALIGNMENT_LEFT, 86, 11, Color("e2ebe4"))
	draw_string(font, Vector2(16, 242), "POWER %d   CHEESE %d" % [main_controller.electricity, main_controller.cheese], HORIZONTAL_ALIGNMENT_LEFT, 210, 11, Color("f1d86a"))
