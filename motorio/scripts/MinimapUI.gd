extends Control

const WORLD_SIZE := 3200.0
const VIEW_SIZE := 640.0
const MAP_PADDING := 6.0
const REFRESH_INTERVAL := 1.0
const MINERAL_BUCKET_SIZE := 160.0
const BLOCK_BUCKET_SIZE := 256.0

var main_controller
var refresh_elapsed := 0.0
var refresh_count := 0
var mineral_points: Array[Vector2] = []
var water_points: Array[Vector2] = []
var block_points: Array[Vector2] = []
var cached_player_position := Vector2.ZERO

func _process(delta: float) -> void:
	refresh_elapsed += delta
	if refresh_elapsed < REFRESH_INTERVAL:
		return
	refresh_elapsed = fmod(refresh_elapsed, REFRESH_INTERVAL)
	refresh_snapshot()

func refresh_snapshot() -> void:
	if main_controller == null:
		return
	mineral_points = _collect_coarse_points(["mineral_block", "resource_deposit"], MINERAL_BUCKET_SIZE)
	water_points = _collect_coarse_points(["water_tile"], 64.0)
	block_points = _collect_coarse_points(["solid", "machine", "transport_floor"], BLOCK_BUCKET_SIZE)
	cached_player_position = main_controller.player.global_position
	refresh_count += 1
	queue_redraw()

func _collect_coarse_points(groups: Array[String], bucket_size: float) -> Array[Vector2]:
	var occupied_buckets: Dictionary[Vector2i, bool] = {}
	for group_name in groups:
		for node in get_tree().get_nodes_in_group(group_name):
			var block := node as Node2D
			if block:
				occupied_buckets[Vector2i(block.global_position / bucket_size)] = true
	var points: Array[Vector2] = []
	for bucket in occupied_buckets:
		points.append((Vector2(bucket) + Vector2.ONE * 0.5) * bucket_size)
	return points

func world_to_map(world_position: Vector2) -> Vector2:
	var inner := Rect2(Vector2.ONE * MAP_PADDING, size - Vector2.ONE * MAP_PADDING * 2.0)
	return inner.position + world_position / WORLD_SIZE * inner.size

func _draw() -> void:
	if main_controller == null:
		return
	var panel := Rect2(Vector2.ZERO, size)
	var inner := panel.grow(-MAP_PADDING)
	draw_rect(panel, Color(0.035, 0.055, 0.05, 0.9))
	draw_rect(panel, Color("9caf9f"), false, 2.0)
	draw_rect(inner, Color("1a3028"))
	for point in water_points:
		draw_circle(world_to_map(point), 1.2, Color("397f94"))

	for point in mineral_points:
		draw_circle(world_to_map(point), 1.5, Color("6ec8d5"))
	for point in block_points:
		draw_circle(world_to_map(point), 1.0, Color("c18b3e"))

	var base_position: Vector2 = main_controller.base.global_position
	draw_circle(world_to_map(base_position), 3.2, Color("efbf4b"))
	var player_point := world_to_map(cached_player_position)
	draw_circle(player_point, 2.6, Color("fff6d0"))
	draw_circle(player_point, 1.4, Color("e05b4f"))

	var viewport_size := inner.size * (VIEW_SIZE / WORLD_SIZE)
	var viewport_rect := Rect2(player_point - viewport_size / 2.0, viewport_size)
	viewport_rect = viewport_rect.intersection(inner)
	draw_rect(viewport_rect, Color(0.88, 0.95, 0.84, 0.75), false, 1.0)
