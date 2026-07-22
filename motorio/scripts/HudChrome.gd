extends Control

var main_controller

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if main_controller == null or main_controller.shelter_open:
		return
	var center_x := size.x * 0.5
	UIVisuals.draw_panel(self, Rect2(center_x - 164.0, 47.0, 328.0, 84.0), Color(0.025, 0.08, 0.085, 0.36), Color(0.42, 0.62, 0.59, 0.22), 12, 1)
	UIVisuals.draw_panel(self, Rect2(center_x - 158.0, 128.0, 316.0, 42.0), Color(0.02, 0.09, 0.10, 0.82), Color(0.50, 0.72, 0.68, 0.48), 12, 1)
