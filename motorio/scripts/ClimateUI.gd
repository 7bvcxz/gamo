extends Control

var main_controller
var snow_time := 0.0

func _process(delta: float) -> void:
	snow_time += delta
	queue_redraw()

func _draw() -> void:
	if main_controller == null or main_controller.shelter_open:
		return
	var dusk: float = clampf((main_controller.day_time - 540.0) / 180.0, 0.0, 1.0)
	if dusk > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.07, 0.16, dusk * 0.42))
	var cold: float = clampf((55.0 - main_controller.temperature) / 55.0, 0.0, 1.0)
	var distance_tiles: float = main_controller.player.global_position.distance_to(main_controller.base.global_position) / main_controller.TILE_SIZE
	var exposure: float = clampf((distance_tiles - main_controller.safe_radius_tiles()) / 10.0, 0.0, 1.0)
	if distance_tiles > main_controller.safe_radius_tiles():
		var immediate_exposure: float = clampf((distance_tiles - main_controller.safe_radius_tiles()) / 6.0, 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.78, 0.87, 0.92, 0.58 + immediate_exposure * 0.34))
		exposure = maxf(exposure, 0.7 + immediate_exposure * 0.3)
	var snow_strength: float = maxf(cold, exposure * 0.65)
	if snow_strength > 0.0:
		var flake_count := int(12.0 + snow_strength * 34.0)
		for index in flake_count:
			var seed := float(index * 79 + 17)
			var x := fmod(seed * 13.7 + snow_time * (22.0 + fmod(seed, 15.0)), size.x + 24.0) - 12.0
			var y := fmod(seed * 7.3 + snow_time * (38.0 + fmod(seed, 21.0)), size.y + 24.0) - 12.0
			draw_circle(Vector2(x, y), 1.2 + fmod(seed, 3.0) * 0.45, Color(0.92, 0.98, 1.0, 0.32 + snow_strength * 0.48))
	if cold <= 0.0:
		return
	var thickness := 10.0 + cold * 22.0
	var frost := Color(0.55, 0.9, 1.0, 0.12 + cold * 0.32)
	draw_rect(Rect2(0, 0, size.x, thickness), frost)
	draw_rect(Rect2(0, size.y - thickness, size.x, thickness), frost)
	draw_rect(Rect2(0, thickness, thickness, size.y - thickness * 2.0), frost)
	draw_rect(Rect2(size.x - thickness, thickness, thickness, size.y - thickness * 2.0), frost)
	if main_controller.temperature <= 12.0:
		var ice := Color(0.7, 0.91, 1.0, 0.24)
		for corner in [Vector2.ZERO, Vector2(size.x, 0), Vector2(0, size.y), size]:
			draw_circle(corner, 52.0, ice)
