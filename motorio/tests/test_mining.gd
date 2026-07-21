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

	var player := main.get_node("Player") as CharacterBody2D
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
	await process_frame
	await process_frame
	_assert(not is_instance_valid(mineral), "installed cat mines mineral one cell ahead")
	var resources := mining_stage.get_tree().get_nodes_in_group("mined_resource")
	var dropped: StaticBody2D = null
	for resource in resources:
		if resource.get_parent() == mining_stage:
			dropped = resource
	_assert(dropped != null, "mining creates a small resource")
	if dropped:
		_assert(dropped.position.distance_to(Vector2(176, 200)) < 0.1, "resource drops behind cat block")
		var shape := dropped.get_node("CollisionShape2D").shape as CircleShape2D
		_assert(shape.radius <= 8.0, "resource fits within half a tile")
		_assert(dropped.collision_layer == 64 and dropped.collision_mask == 4, "resource overlaps everything except boxes")

	if failures == 0:
		print("MINING_TEST: PASS")
	quit(failures)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("MINING_TEST: FAIL - " + message)
		failures += 1
