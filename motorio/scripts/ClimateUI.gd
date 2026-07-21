extends Control

var main_controller

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if main_controller == null or main_controller.shelter_open:
		return
	var dusk: float = clampf((main_controller.day_time - 540.0) / 180.0, 0.0, 1.0)
	if dusk > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.07, 0.16, dusk * 0.42))
	var cold: float = clampf((55.0 - main_controller.temperature) / 55.0, 0.0, 1.0)
	if cold <= 0.0:
		return
	var thickness := 10.0 + cold * 22.0
	var frost := Color(0.55, 0.9, 1.0, 0.12 + cold * 0.32)
	draw_rect(Rect2(0, 0, size.x, thickness), frost)
	draw_rect(Rect2(0, size.y - thickness, size.x, thickness), frost)
	draw_rect(Rect2(0, thickness, thickness, size.y - thickness * 2.0), frost)
	draw_rect(Rect2(size.x - thickness, thickness, thickness, size.y - thickness * 2.0), frost)
