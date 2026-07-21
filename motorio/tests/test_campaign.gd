extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await physics_frame
	var expected := {"copper": 14, "coal": 10, "crystal": 8, "oil": 5, "uranium": 3}
	var last_radius := 0
	for resource_type in expected:
		var deposits := get_nodes_in_group("deposit_%s" % resource_type)
		_assert(deposits.size() == expected[resource_type], "%s rarity matches its campaign tier" % resource_type)
		var radius: int = deposits[0].get_meta("tier_radius")
		_assert(radius > last_radius, "%s appears farther from the base than the prior resource" % resource_type)
		last_radius = radius

	var copper := get_nodes_in_group("deposit_copper")[0] as ResourceDeposit
	var coal := get_nodes_in_group("deposit_coal")[0] as ResourceDeposit
	var crystal := get_nodes_in_group("deposit_crystal")[0] as ResourceDeposit
	var oil := get_nodes_in_group("deposit_oil")[0] as ResourceDeposit
	var uranium := get_nodes_in_group("deposit_uranium")[0] as ResourceDeposit
	_assert(main.try_mine_deposit(copper, "miner", 100.0), "copper needs only a miner cat")
	_assert(not main.try_mine_deposit(coal, "miner", 20.0), "hungry cats cannot mine coal")
	_assert(main.try_mine_deposit(coal, "miner", 100.0), "fed miner cats can mine coal")
	_assert(not main.try_mine_deposit(crystal, "miner", 100.0), "crystal cannot be mined without electricity")
	main.electricity = 2
	_assert(main.try_mine_deposit(crystal, "miner", 100.0) and main.electricity == 0, "crystal consumes electricity")
	_assert(not main.try_mine_deposit(oil, "miner", 100.0) and main.try_mine_deposit(oil, "pressure", 100.0), "oil requires a pressure cat")
	main.electricity = 8
	main.resource_counts["oil"] = 2
	_assert(main.try_mine_deposit(uranium, "miner", 100.0), "uranium accepts a powered and oiled miner")
	_assert(main.electricity == 0 and main.resource_counts["oil"] == 0, "uranium consumes both late-game inputs")

	var water := get_nodes_in_group("water_tile")[0] as WaterTile
	_assert(not (water.get_node("CollisionShape2D") as CollisionShape2D).disabled, "water starts impassable")
	var bridge := load("res://scenes/Bridge.tscn").instantiate() as BridgeBlock
	bridge.position = water.position
	main.add_child(bridge)
	await physics_frame
	_assert((water.get_node("CollisionShape2D") as CollisionShape2D).disabled, "bridge opens one water tile")
	bridge.queue_free()
	await process_frame
	_assert(not (water.get_node("CollisionShape2D") as CollisionShape2D).disabled, "removing a bridge restores water collision")

	main.resource_counts["copper"] = 1
	main.fabricator_selection = 5
	var conveyor_count := get_nodes_in_group("transport_floor").size()
	main.call("_craft_selected_block")
	await process_frame
	_assert(main.resource_counts["copper"] == 0, "copper crafts a new conveyor without relocating an old one")
	_assert(get_nodes_in_group("transport_floor").size() == conveyor_count + 1, "field expansion creates an additional conveyor")

	await _test_cat_support_loop(main)
	if failures == 0:
		print("CAMPAIGN_TEST: PASS")
	quit(failures)

func _test_cat_support_loop(main: Node2D) -> void:
	var field := load("res://scenes/FacilityBlock.tscn").instantiate() as FacilityBlock
	field.facility_type = "cheese_field"
	field.position = Vector2(300, 300)
	main.add_child(field)
	var cook := load("res://scenes/CatBlock.tscn").instantiate() as CatBlock
	cook.worker_type = "cook"
	cook.position = Vector2(332, 300)
	main.add_child(cook)
	await process_frame
	cook._physics_process(3.1)
	_assert(main.cheese == 2 and cook.hunger < 100.0, "cook cat turns farm access into cheese and gets hungry")
	var hungry_cat := load("res://scenes/CatBlock.tscn").instantiate() as CatBlock
	hungry_cat.hunger = 10.0
	hungry_cat.position = Vector2(360, 300)
	main.add_child(hungry_cat)
	var server := load("res://scenes/CatBlock.tscn").instantiate() as CatBlock
	server.worker_type = "server"
	server.position = Vector2(350, 300)
	main.add_child(server)
	await process_frame
	server._physics_process(3.1)
	_assert(hungry_cat.hunger > 10.0 and main.cheese == 1, "server cat spends cheese to restore nearby workers")
	var power := load("res://scenes/FacilityBlock.tscn").instantiate() as FacilityBlock
	power.facility_type = "power_generator"
	power.position = Vector2(500, 300)
	main.add_child(power)
	var electric := load("res://scenes/CatBlock.tscn").instantiate() as CatBlock
	electric.worker_type = "electric"
	electric.position = Vector2(532, 300)
	main.add_child(electric)
	main.resource_counts["coal"] = 1
	await process_frame
	electric._physics_process(3.1)
	_assert(main.electricity == 5 and main.resource_counts["coal"] == 0, "electric cat and generator convert coal into electricity")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("CAMPAIGN_TEST: FAIL - " + message)
		failures += 1
