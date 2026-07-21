extends Control

const WORLD_SIZE := 3200.0
const VIEW_SIZE := 640.0
const MAP_PADDING := 6.0

var main_controller

func _process(_delta: float) -> void:
	queue_redraw()

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

	for node in get_tree().get_nodes_in_group("mineral_block"):
		var mineral := node as Node2D
		if mineral:
			draw_circle(world_to_map(mineral.global_position), 1.15, Color("6ec8d5"))
	for node in get_tree().get_nodes_in_group("machine"):
		var machine := node as Node2D
		if machine:
			draw_circle(world_to_map(machine.global_position), 0.75, Color("d6a638"))
	for node in get_tree().get_nodes_in_group("solid"):
		var solid := node as Node2D
		if solid:
			draw_circle(world_to_map(solid.global_position), 0.75, Color("9a6338"))

	var base_position: Vector2 = main_controller.base.global_position
	draw_circle(world_to_map(base_position), 3.2, Color("efbf4b"))
	var player_position: Vector2 = main_controller.player.global_position
	var player_point := world_to_map(player_position)
	draw_circle(player_point, 2.6, Color("fff6d0"))
	draw_circle(player_point, 1.4, Color("e05b4f"))

	var viewport_size := inner.size * (VIEW_SIZE / WORLD_SIZE)
	var viewport_rect := Rect2(player_point - viewport_size / 2.0, viewport_size)
	viewport_rect = viewport_rect.intersection(inner)
	draw_rect(viewport_rect, Color(0.88, 0.95, 0.84, 0.75), false, 1.0)
