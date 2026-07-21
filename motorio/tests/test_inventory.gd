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

	_assert(main.preview_visible, "picked inventory block always shows placement preview")
	var box_preview := main.get("placement_preview") as RigidBody2D
	_assert(box_preview != null and box_preview.get_script() == load("res://scripts/PushTile.gd"), "preview uses the actual selected block")
	_assert(is_equal_approx(box_preview.modulate.a, 0.5), "actual block preview is 50 percent transparent")
	main.call("begin_placement_action")
	main.call("_process", 0.69)
	_assert(main.placement_rotation == 0, "X hold does not rotate before 0.7 seconds")
	main.call("_process", 0.01)
	_assert(main.placement_rotation == 1, "X hold rotates preview 90 degrees at 0.7 seconds")
	main.call("end_placement_action")
	_assert(main.inventory.size() == 1, "long X rotates without placing a block")
	main.call("begin_placement_action")
	main.call("end_placement_action")
	await physics_frame
	_assert(main.inventory.is_empty(), "short X consumes selected inventory block")
	_assert(_find_block_at(target) != null, "short X installs block in front")
	_assert(main.placement_rotation == 1, "placing a block preserves the remembered rotation")

	var placed := _find_block_at(target)
	placed.queue_free()
	await process_frame
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
	_assert(main.placement_rotation == 1, "slot selection preserves remembered rotation")
	_assert(main.get_node_or_null("UI/Mode") == null, "mode UI is removed")

	extra.queue_free()
	await process_frame
	main.inventory.clear()
	main.inventory.append({"type": "conveyor", "direction": Vector2.RIGHT})
	main.inventory.append({"type": "conveyor", "direction": Vector2.RIGHT})
	main.selected_slot = 0
	main.preview_visible = false
	main.call("_sync_placement_preview")
	main.call("begin_placement_action")
	main.call("end_placement_action")
	await physics_frame
	var rotated := _find_block_at(target) as ConveyorBlock
	_assert(rotated != null, "rotated conveyor is installed")
	_assert(rotated.direction == Vector2.DOWN, "remembered rotation is applied to conveyor direction")
	_assert(rotated.freeze and rotated.get_meta("installed", false), "X-placed block cannot be pushed")
	_assert(main.placement_rotation == 1, "rotation remains after conveyor placement")
	player.position += Vector2.RIGHT * 32.0
	var next_target: Vector2 = main.call("_front_cell_center")
	main.call("_sync_placement_preview")
	main.call("begin_placement_action")
	main.call("end_placement_action")
	await physics_frame
	var next_rotated := _find_block_at(next_target) as ConveyorBlock
	_assert(next_rotated != null and next_rotated.direction == Vector2.DOWN, "next block defaults to the remembered rotation")
	_assert(next_rotated.freeze, "every X-placed block stays immovable")

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
