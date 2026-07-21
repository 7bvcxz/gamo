extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await physics_frame
	var minerals := get_nodes_in_group("mineral_block")
	var clustered := 0
	for mineral in minerals:
		if mineral.get_meta("clustered_spawn", false):
			clustered += 1
	_assert(abs(minerals.size() - 42) <= 1, "mineral density is halved for a calmer world")
	_assert(minerals.filter(func(node): return node.get_meta("starter_mineral", false)).size() == 1, "the starting view has one mineral deposit")
	var clustered_ratio := float(clustered) / float(minerals.size())
	_assert(abs(clustered_ratio - 0.8) < 0.02, "about 80 percent of minerals spawn attached")
	var fixed_mineral := minerals[0] as MineralBlock
	_assert(fixed_mineral.is_in_group("fixed"), "mineral block has Fixed trait")
	_assert(not fixed_mineral.is_in_group("pickup_block"), "Fixed mineral cannot be picked up in IN mode")
	_assert(fixed_mineral.collision_layer == 32 and fixed_mineral.collision_mask == 63, "Fixed mineral collides with every block category")
	_assert(not main.call("_can_place_at", fixed_mineral.global_position), "Fixed mineral blocks OUT placement")
	var world_player := main.get_node("Player") as CharacterBody2D
	_assert((world_player.collision_mask & 32) != 0, "player collides with Fixed blocks")
	var conveyor_scene := load("res://scenes/Conveyor.tscn").instantiate() as ConveyorBlock
	_assert(conveyor_scene.collision_layer == 0 and conveyor_scene.collision_mask == 0, "TransportFloor can overlap Fixed blocks")
	var box_scene := load("res://scenes/PushTile.tscn").instantiate() as RigidBody2D
	_assert((box_scene.collision_mask & 32) != 0, "Solid collides with Fixed blocks")
	conveyor_scene.free()
	box_scene.free()

	var player := world_player
	var nearby_resource := load("res://scenes/MinedResource.tscn").instantiate() as RigidBody2D
	nearby_resource.position = player.position + Vector2(40, 0)
	main.add_child(nearby_resource)
	var far_resource := load("res://scenes/MinedResource.tscn").instantiate() as RigidBody2D
	far_resource.position = player.position + Vector2(49, 0)
	main.add_child(far_resource)
	main.collect_action_held = true
	main.call("_collect_nearby_mineral_resources")
	await process_frame
	_assert(main.mineral_count == 1, "Z hold collects resources within 1.5 tiles")
	_assert(not is_instance_valid(nearby_resource), "collected mineral resource is removed")
	_assert(is_instance_valid(far_resource), "resource outside 1.5 tiles remains")
	_assert((main.get_node("UI/MineralCount") as Label).text == "MINERAL  1", "mineral count appears in top-left UI")
	main.collect_action_held = false
	player.facing = Vector2.UP
	main.box_count = 6
	main.get_node("UI/BoxCount").text = "BOX  6"
	main.call("primary_action")
	_assert(main.base_menu_open, "Z facing base opens fabricator menu")
	_assert(player.controls_locked, "fabricator menu locks movement")
	var blocked_output := load("res://scenes/PushTile.tscn").instantiate() as RigidBody2D
	blocked_output.position = main.base.position + Vector2.DOWN * 160.0
	main.add_child(blocked_output)
	await physics_frame
	main.call("primary_action")
	await physics_frame
	_assert(main.box_count == 3, "cat block crafting consumes three boxes")
	var crafted_cats := get_nodes_in_group("pickup_block").filter(func(node): return node is CatBlock and not node.active_on_ready)
	_assert(crafted_cats.size() == 1, "fabricator outputs one inactive cat block")
	_assert((crafted_cats[0] as CatBlock).position.y > blocked_output.position.y, "blocked exit ejects a crafted block farther downward")
	main.call("begin_placement_action")
	main.call("end_placement_action")
	_assert(main.base_menu_open and main.fabricator_selection == 1, "X selects the pillar recipe without closing the menu")
	main.call("primary_action")
	await physics_frame
	_assert(main.box_count == 0, "pillar crafting consumes three boxes")
	var crafted_pillars := get_nodes_in_group("pillar_block")
	_assert(crafted_pillars.size() == 1, "fabricator outputs one pillar")
	var crafted_pillar := crafted_pillars[0] as PillarBlock
	_assert(crafted_pillar.freeze and crafted_pillar.is_in_group("solid"), "crafted pillar is an immovable Solid")
	_assert(crafted_pillar.is_in_group("pickup_block") and not crafted_pillar.is_in_group("fixed"), "pillar remains Z-pickable rather than Fixed")
	_assert(crafted_pillar.position.y > (crafted_cats[0] as CatBlock).position.y, "successive blocked outputs continue downward")
	main.mineral_count = 10
	main.get_node("UI/MineralCount").text = "MINERAL  10"
	main.call("begin_placement_action")
	main.call("end_placement_action")
	_assert(main.fabricator_selection == 2, "X selects the box generator recipe")
	main.call("primary_action")
	await physics_frame
	_assert(main.mineral_count == 0, "box generator crafting consumes ten minerals")
	var crafted_generators := get_nodes_in_group("box_generator")
	_assert(crafted_generators.size() == 1, "fabricator outputs one box generator")
	var crafted_generator := crafted_generators[0] as BoxGenerator
	_assert(crafted_generator.freeze and crafted_generator.direction == Vector2.DOWN, "crafted generator is immovable and faces the base exit")
	main.call("close_base_menu_action")
	_assert(not main.base_menu_open and not player.controls_locked, "fabricator can be closed explicitly")

	var mining_stage := Node2D.new()
	root.add_child(mining_stage)
	var mineral := load("res://scenes/Mineral.tscn").instantiate() as MineralBlock
	mineral.position = Vector2(232, 200)
	mining_stage.add_child(mineral)
	var cat := load("res://scenes/CatBlock.tscn").instantiate() as CatBlock
	cat.position = Vector2(200, 200)
	cat.direction = Vector2.RIGHT
	cat.active_on_ready = true
	mining_stage.add_child(cat)
	cat._physics_process(2.9)
	_assert(_stage_resources(mining_stage).is_empty(), "cat waits for three-second mining interval")
	cat._physics_process(0.2)
	await process_frame
	_assert(is_instance_valid(mineral), "mineral deposit remains after mining")
	_assert(cat.spark_remaining > 0.0, "cat shows a sparkle on the front cell")
	var resources := mining_stage.get_tree().get_nodes_in_group("mined_resource")
	var dropped: RigidBody2D = null
	for resource in resources:
		if resource.get_parent() == mining_stage:
			dropped = resource
	_assert(dropped != null, "mining creates a small resource")
	if dropped:
		_assert(dropped.position.distance_to(Vector2(176, 200)) < 0.1, "resource drops behind cat block")
		var shape := dropped.get_node("CollisionShape2D").shape as CircleShape2D
		_assert(shape.radius <= 8.0, "resource fits within half a tile")
		_assert(dropped.is_in_group("solid"), "mined resource has Solid trait")
		_assert(dropped.collision_layer == 4 and dropped.collision_mask == 125, "mined resource collides as Solid")
	cat._physics_process(3.0)
	await process_frame
	_assert(_stage_resources(mining_stage).size() == 2, "cat produces another resource every three seconds")
	_assert(cat.is_in_group("solid") and cat.collision_layer == 4, "cat block has Solid trait")
	var transport_floor := load("res://scenes/Conveyor.tscn").instantiate() as ConveyorBlock
	mining_stage.add_child(transport_floor)
	_assert(transport_floor.is_in_group("transport_floor") and transport_floor.collision_layer == 0, "conveyor has TransportFloor trait")

	if failures == 0:
		print("MINING_TEST: PASS")
	quit(failures)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("MINING_TEST: FAIL - " + message)
		failures += 1

func _stage_resources(stage: Node2D) -> Array:
	return get_nodes_in_group("mined_resource").filter(func(node): return node.get_parent() == stage)
