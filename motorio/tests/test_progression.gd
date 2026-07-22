extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await physics_frame
	_assert(main.quest_step == 0 and main.quest_title() == "1  첫 상자 납품", "onboarding starts with one clear delivery goal")
	_assert(get_nodes_in_group("mineral_block").filter(func(node): return node.get_meta("starter_mineral", false)).size() == 1, "starter zone introduces one clear mineral")
	var base_position: Vector2 = main.base.position
	var in_start_view := func(node): return abs(node.position.x - base_position.x) <= 20.0 * main.TILE_SIZE and abs(node.position.y - base_position.y) <= 20.0 * main.TILE_SIZE
	_assert(get_nodes_in_group("box_block").filter(in_start_view).size() == 3, "start view contains only three teaching boxes")
	_assert(get_nodes_in_group("transport_floor").filter(in_start_view).is_empty(), "start view has no unexplained conveyor clutter")
	_assert(get_nodes_in_group("resource_deposit").filter(in_start_view).is_empty(), "tier resources begin beyond the first view")
	_assert(get_nodes_in_group("water_tile").filter(in_start_view).is_empty(), "water begins beyond the first view")

	var first_delivery := RigidBody2D.new()
	main.call("_on_base_box_received", first_delivery)
	first_delivery.free()
	_assert(main.quest_step == 1, "first base delivery advances onboarding")
	main.box_count = 3
	main.fabricator_selection = 0
	main.call("_craft_selected_block")
	_assert(main.quest_step == 2, "crafting the cat advances to mineral gathering")
	main.mineral_count = 10
	main.call("_check_mineral_quest")
	_assert(main.quest_step == 3, "ten minerals advance to generator crafting")
	main.fabricator_selection = 2
	main.call("_craft_selected_block")
	_assert(main.quest_step == 4, "crafting a box generator starts automation goal")
	main.box_count = 5
	main.fabricator_selection = 3
	main.call("_craft_selected_block")
	_assert(main.box_count == 5 and get_nodes_in_group("splitter_block").is_empty(), "splitter stays locked before automation is complete")

	for index in range(3):
		var automated_box := RigidBody2D.new()
		automated_box.set_meta("automated_box", true)
		main.elapsed_time = float(index + 1)
		main.call("_on_base_box_received", automated_box)
		automated_box.free()
	_assert(main.quest_step == 5 and main.base_level == 1, "three generated deliveries unlock the manual base upgrade")
	_assert(main.automated_delivery_times.size() == 3, "generated deliveries feed the rolling throughput counter")
	main.call("_process", 0.0)
	_assert((main.get_node("UI/Throughput") as Label).text.contains("분당 상자  3"), "BOX per minute is visible")

	main.box_count = 5
	main.fabricator_selection = 15
	main.call("_craft_selected_block")
	_assert(main.base_level == 2 and main.box_count == 0, "five boxes upgrade the base to level two")
	_assert(get_nodes_in_group("mineral_block").filter(func(node): return node.get_meta("starter_mineral", false)).size() == 3, "level two base guarantees three nearby minerals")
	main.box_count = 25
	main.fabricator_selection = 15
	main.call("_craft_selected_block")
	_assert(main.base_level == 3 and get_nodes_in_group("deposit_copper").any(func(node): return node.get_meta("base_level_component", 0) == 3), "level three base guarantees one nearby copper deposit")
	main.base_level = 2
	main.box_count = 5
	main.fabricator_selection = 3
	main.call("_craft_selected_block")
	await process_frame
	_assert(main.box_count == 0, "unlocked splitter costs five boxes")
	_assert(get_nodes_in_group("splitter_block").size() == 1, "base level two can craft a splitter")
	_assert(main.recipe_unlock_level(4) == 3 and main.recipe_unlock_level(9) == 4 and main.recipe_unlock_level(6) == 5 and main.recipe_unlock_level(8) == 7, "rarer production recipes unlock at higher base levels")
	main.base_level = 2
	_assert(main.base_upgrade_cost() == {"box": 25}, "level three requires twenty-five boxes")
	main.base_level = 3
	_assert(main.base_upgrade_cost() == {"mineral": 100}, "level four requires one hundred minerals")
	main.base_level = 4
	_assert(main.base_upgrade_cost() == {"copper": 5}, "level five introduces copper")
	main.base_level = 5
	_assert(main.base_upgrade_cost() == {"copper": 25}, "level six raises the copper requirement")
	main.base_level = 6
	_assert(main.base_upgrade_cost() == {"fish": 25}, "level seven requires the mature fishing loop")
	main.elapsed_time = 70.0
	main.call("_process", 0.0)
	_assert(main.automated_delivery_times.is_empty(), "throughput discards deliveries older than sixty seconds")

	await _test_splitter()
	if failures == 0:
		print("PROGRESSION_TEST: PASS")
	quit(failures)

func _test_splitter() -> void:
	var splitter := load("res://scenes/Splitter.tscn").instantiate() as SplitterBlock
	splitter.direction = Vector2.RIGHT
	root.add_child(splitter)
	await process_frame
	var first := RigidBody2D.new()
	var second := RigidBody2D.new()
	root.add_child(first)
	root.add_child(second)
	splitter.call("_on_body_entered", first)
	splitter.call("_on_body_entered", second)
	_assert(first.linear_velocity.y < 0.0 and second.linear_velocity.y > 0.0, "splitter alternates items between its two side outputs")
	_assert(splitter.is_in_group("transport_floor") and splitter.collision_layer == 0, "splitter behaves as an overlapping transport floor")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("PROGRESSION_TEST: FAIL - " + message)
		failures += 1
