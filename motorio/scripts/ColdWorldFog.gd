extends Node2D
class_name ColdWorldFog

var main_controller
var last_radius := -1

func _process(_delta: float) -> void:
	if main_controller == null:
		return
	var radius: int = main_controller.safe_radius_tiles()
	if radius != last_radius:
		last_radius = radius
		queue_redraw()

func fog_alpha_for_cell(cell: Vector2i) -> float:
	if main_controller == null:
		return 0.0
	var center := Vector2(main_controller.WORLD_TILES / 2, main_controller.WORLD_TILES / 2)
	var distance_tiles := (Vector2(cell) + Vector2(0.5, 0.5)).distance_to(center + Vector2(0.5, 0.5))
	if distance_tiles <= float(main_controller.safe_radius_tiles()):
		return 0.0
	return 0.88 + clampf((distance_tiles - float(main_controller.safe_radius_tiles())) / 12.0, 0.0, 1.0) * 0.08

func _draw() -> void:
	if main_controller == null:
		return
	var center_cell: Vector2 = Vector2(main_controller.WORLD_TILES, main_controller.WORLD_TILES) * 0.5
	var radius: float = float(main_controller.safe_radius_tiles())
	for y in range(main_controller.WORLD_TILES):
		var row_center: float = float(y) + 0.5
		var dy: float = absf(row_center - center_cell.y)
		var warm_half_width: float = sqrt(maxf(0.0, radius * radius - dy * dy)) if dy < radius else 0.0
		var warm_left: float = clampf(center_cell.x - warm_half_width, 0.0, float(main_controller.WORLD_TILES))
		var warm_right: float = clampf(center_cell.x + warm_half_width, 0.0, float(main_controller.WORLD_TILES))
		var row_y: float = float(y * main_controller.TILE_SIZE)
		var color: Color = Color(0.97, 0.985, 1.0, 0.92)
		if warm_left > 0.0:
			draw_rect(Rect2(0.0, row_y, warm_left * main_controller.TILE_SIZE, main_controller.TILE_SIZE + 1), color)
		if warm_right < main_controller.WORLD_TILES:
			draw_rect(Rect2(warm_right * main_controller.TILE_SIZE, row_y, (main_controller.WORLD_TILES - warm_right) * main_controller.TILE_SIZE + 1, main_controller.TILE_SIZE + 1), color)
