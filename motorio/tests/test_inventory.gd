extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await physics_frame
	var player := main.get_node("Player") as CharacterBody2D
	player.facing = Vector2.DOWN
	var target: Vector2 = main.call("_front_cell_center")

	var box := load("res://scenes/PushTile.tscn").instantiate() as RigidBody2D
	box.position = target
	main.add_child(box)
	await process_frame
	main.call("primary_action")
	await process_frame
	_assert(main.inventory.size() == 1, "IN Z picks up one front block")
	_assert(main.inventory[0]["type"] == "box", "picked box keeps its type")
	_assert(not is_instance_valid(box), "picked world block is removed")

	main.call("toggle_interaction_mode")
	_assert(main.interaction_mode == main.MODE_OUT, "C toggles to OUT mode")
	main.call("preview_action")
	_assert(main.preview_visible and main.placement_rotation == 0, "first X shows preview")
	main.call("preview_action")
	_assert(main.placement_rotation == 1, "next X rotates preview 90 degrees")
	main.call("primary_action")
	await physics_frame
	_assert(main.inventory.is_empty(), "OUT Z consumes selected inventory block")
	_assert(_find_block_at(target) != null, "OUT Z installs block in front")

	var placed := _find_block_at(target)
	placed.queue_free()
	await process_frame
	main.interaction_mode = main.MODE_IN
	main.inventory.clear()
	for index in range(5):
		main.inventory.append({"type": "box"})
	var extra := load("res://scenes/PushTile.tscn").instantiate() as RigidBody2D
	extra.position = target
	main.add_child(extra)
	await process_frame
	main.call("primary_action")
	await process_frame
	_assert(main.inventory.size() == 5, "inventory never exceeds five blocks")
	_assert(is_instance_valid(extra), "full inventory leaves front block in world")

	main.call("select_inventory_slot", 3)
	_assert(main.selected_slot == 3, "number selection chooses requested slot")
	_assert((main.get_node("UI/Mode") as Label).text.begins_with("MODE"), "mode appears in UI")

	extra.queue_free()
	await process_frame
	main.inventory.clear()
	main.inventory.append({"type": "conveyor", "direction": Vector2.RIGHT})
	main.selected_slot = 0
	main.interaction_mode = main.MODE_OUT
	main.preview_visible = false
	main.placement_rotation = 0
	main.call("preview_action")
	main.call("preview_action")
	main.call("primary_action")
	await physics_frame
	var rotated := _find_block_at(target) as ConveyorBlock
	_assert(rotated != null, "rotated conveyor is installed")
	_assert(rotated.direction == Vector2.DOWN, "X rotation is applied to conveyor direction")

	if failures == 0:
		print("INVENTORY_TEST: PASS")
	quit(failures)

func _find_block_at(position: Vector2) -> RigidBody2D:
	for node in get_nodes_in_group("pickup_block"):
		var block := node as RigidBody2D
		if block and block.global_position.distance_to(position) < 2.0:
			return block
	return null

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("INVENTORY_TEST: FAIL - " + message)
		failures += 1
