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
	var tile_size: float = float(main_controller.TILE_SIZE)
	var center: Vector2 = Vector2(main_controller.WORLD_TILES, main_controller.WORLD_TILES) * tile_size * 0.5
	var warm_radius: float = float(main_controller.safe_radius_tiles()) * tile_size
	var spacing := tile_size * 2.6
	var cloud_radius := tile_size * 2.5
	# Overlapping puffs fill the frozen world without exposing rectangular row edges.
	for grid_y in range(-1, int(ceil(main_controller.WORLD_TILES / 2.6)) + 2):
		for grid_x in range(-1, int(ceil(main_controller.WORLD_TILES / 2.6)) + 2):
			var wobble := Vector2(sin(float(grid_y * 7 + grid_x)) * 18.0, cos(float(grid_x * 5 - grid_y)) * 14.0)
			var puff_center := Vector2(float(grid_x) * spacing, float(grid_y) * spacing) + wobble
			if puff_center.distance_to(center) <= warm_radius + cloud_radius * 0.42:
				continue
			draw_circle(puff_center, cloud_radius, Color(0.94, 0.975, 1.0, 0.66))
	# A soft, scalloped cloud bank marks the warm frontier.
	var puff_count := maxi(28, int(TAU * warm_radius / (tile_size * 1.35)))
	for index in range(puff_count):
		var angle := TAU * float(index) / float(puff_count)
		var irregular := sin(float(index) * 2.17) * 10.0 + cos(float(index) * 0.73) * 7.0
		var puff_center := center + Vector2.from_angle(angle) * (warm_radius + tile_size * 1.15 + irregular)
		var radius := tile_size * (1.25 + 0.2 * sin(float(index) * 1.91))
		draw_circle(puff_center, radius * 1.35, Color(0.94, 0.975, 1.0, 0.20))
		draw_circle(puff_center, radius, Color(0.97, 0.99, 1.0, 0.68))
