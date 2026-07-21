extends RigidBody2D
class_name BridgeBlock

var water_tile: WaterTile

func _ready() -> void:
	add_to_group("pickup_block")
	add_to_group("transport_floor")
	for node in get_tree().get_nodes_in_group("water_tile"):
		var water := node as WaterTile
		if water and water.global_position.distance_to(global_position) < 2.0:
			water_tile = water
			water.set_bridged(true)
			break
	queue_redraw()

func _exit_tree() -> void:
	if is_instance_valid(water_tile):
		water_tile.set_bridged(false)

func _draw() -> void:
	draw_rect(Rect2(-16, -16, 32, 32), Color("5f4329"))
	for y in [-11.0, 0.0, 11.0]:
		draw_rect(Rect2(-15, y - 4, 30, 8), Color("b6854d"))
		draw_line(Vector2(-15, y + 4), Vector2(15, y + 4), Color("402b1d"), 1.0)
