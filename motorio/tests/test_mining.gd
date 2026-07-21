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
	_assert(abs(minerals.size() - 333) <= 1, "mineral density averages one per 30 cells")
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
	_assert((conveyor_scene.collision_mask & 32) != 0, "Machine collides with Fixed blocks")
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
	_assert((main.get_node("UI/MineralCount") as Label).text == "MINERAL  1", "mineral count appears in top-right UI")
	main.collect_action_held = false
	player.facing = Vector2.UP
	main.box_count = 3
	main.get_node("UI/BoxCount").text = "BOX  3"
	main.call("primary_action")
	_assert(main.base_menu_open, "Z facing base opens fabricator menu")
	_assert(player.controls_locked, "fabricator menu locks movement")
	main.call("primary_action")
	await process_frame
	_assert(main.box_count == 0, "cat block crafting consumes three boxes")
	var crafted_cats := get_nodes_in_group("pickup_block").filter(func(node): return node is CatBlock and not node.active_on_ready)
	_assert(crafted_cats.size() == 1, "fabricator outputs one inactive cat block")
	main.call("preview_action")
	_assert(not main.base_menu_open and not player.controls_locked, "X closes fabricator menu")

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
	var machine := load("res://scenes/Conveyor.tscn").instantiate() as ConveyorBlock
	mining_stage.add_child(machine)
	_assert(machine.is_in_group("machine") and machine.collision_layer == 2, "conveyor keeps Machine trait")

	if failures == 0:
		print("MINING_TEST: PASS")
	quit(failures)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("MINING_TEST: FAIL - " + message)
		failures += 1

func _stage_resources(stage: Node2D) -> Array:
	return get_nodes_in_group("mined_resource").filter(func(node): return node.get_parent() == stage)
