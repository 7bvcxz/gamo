extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://scenes/Conveyor.tscn")
	var conveyor := scene.instantiate() as ConveyorBlock
	root.add_child(conveyor)
	await process_frame

	_assert(conveyor.contains_effect_point(Vector2.ZERO), "center is inside")
	_assert(conveyor.contains_effect_point(Vector2(12.9, 0)), "inner point is inside")
	_assert(not conveyor.contains_effect_point(Vector2(13.0, 0)), "outline inner boundary is excluded")
	_assert(not conveyor.contains_effect_point(Vector2(16.0, 0)), "block outline is excluded")
	var box_half_extent := Vector2(15.5, 15.5)
	_assert(conveyor.overlaps_effect_rect(Vector2(28.4, 0), box_half_extent), "tiny box overlap with interior is included")
	_assert(not conveyor.overlaps_effect_rect(Vector2(28.5, 0), box_half_extent), "box touching interior boundary is excluded")
	_assert(not conveyor.overlaps_effect_rect(Vector2(30.0, 0), box_half_extent), "box overlapping outline only is excluded")

	for offset_step in range(20):
		conveyor.animation_offset = float(offset_step)
		for arrow_index in range(2):
			for point in conveyor.get_arrow_points(arrow_index):
				_assert(abs(point.x) <= 14.0 and abs(point.y) <= 14.0, "arrow stays inside block")
	conveyor.animation_offset = 0.0
	conveyor._process(0.5)
	_assert(is_equal_approx(conveyor.animation_offset, 18.0), "arrow animation runs at half belt speed")
	_assert(conveyor.BELT_SPEED == 72.0, "slower animation does not change transport speed")
	var visual_box := load("res://scenes/PushTile.tscn").instantiate() as RigidBody2D
	var visual_cat := load("res://scenes/CatBlock.tscn").instantiate() as CatBlock
	_assert(visual_cat.get_node_or_null("Sprite2D") != null, "worker cats use the illustrated character sprite")
	_assert(conveyor.z_index < visual_box.z_index and conveyor.z_index < visual_cat.z_index, "conveyor renders below every solid block")
	visual_box.free()
	visual_cat.free()

	await _test_box_transport(conveyor)
	await _test_player_overlap()

	print("CONVEYOR_TEST: PASS")
	quit(0)

func _test_box_transport(conveyor: ConveyorBlock) -> void:
	conveyor.position = Vector2(200, 200)
	conveyor.direction = Vector2.RIGHT
	var box_scene: PackedScene = load("res://scenes/PushTile.tscn")
	var box := box_scene.instantiate() as RigidBody2D
	box.position = conveyor.position
	root.add_child(box)

	for _frame in range(30):
		await physics_frame

	_assert(box.position.x > 202.0, "box slides in conveyor direction")
	_assert(abs(box.position.y - conveyor.position.y) < 2.0, "box remains aligned while sliding")
	_assert(conveyor.position.distance_to(Vector2(200, 200)) < 1.0, "box does not push conveyor")
	box.free()

	var edge_box := box_scene.instantiate() as RigidBody2D
	edge_box.position = conveyor.position + Vector2(28.4, 0)
	root.add_child(edge_box)
	for _frame in range(3):
		await physics_frame
	_assert(edge_box.linear_velocity.x > 0.1, "tiny interior overlap receives conveyor force")
	edge_box.free()

	var outline_box := box_scene.instantiate() as RigidBody2D
	outline_box.position = conveyor.position + Vector2(28.5, 0)
	root.add_child(outline_box)
	for _frame in range(3):
		await physics_frame
	_assert(outline_box.linear_velocity.length() < 0.1, "outline-only overlap receives no force")
	outline_box.free()

func _test_player_overlap() -> void:
	var conveyor_scene: PackedScene = load("res://scenes/Conveyor.tscn")
	var solid_conveyor := conveyor_scene.instantiate() as ConveyorBlock
	solid_conveyor.position = Vector2(400, 400)
	root.add_child(solid_conveyor)

	var player_scene: PackedScene = load("res://scenes/Player.tscn")
	var player := player_scene.instantiate() as CharacterBody2D
	player.set("world_bounds", Rect2(0, 0, 1000, 1000))
	player.position = Vector2(370, 400)
	root.add_child(player)
	await physics_frame

	var collision := player.move_and_collide(Vector2(20, 0), true)
	_assert(collision == null, "player can walk over conveyor")
	_assert(solid_conveyor.collision_layer == 0 and solid_conveyor.collision_mask == 0, "conveyor has no solid body collision")
	_assert(solid_conveyor.is_in_group("transport_floor") and not solid_conveyor.is_in_group("machine"), "conveyor uses TransportFloor instead of Machine")
	player.queue_free()
	solid_conveyor.queue_free()

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("CONVEYOR_TEST: FAIL - " + message)
		quit(1)
