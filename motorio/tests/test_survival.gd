extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await physics_frame
	_test_ui_stages(main)
	_test_cold_and_sleep(main)
	await _test_scaling_and_technology(main)
	if failures == 0:
		print("SURVIVAL_TEST: PASS")
	quit(failures)

func _test_ui_stages(main: Node2D) -> void:
	main.call("_update_staged_ui")
	main.call("_update_survival", 0.0)
	_assert(main.ui_stage() == 0, "quick start is the minimal UI stage")
	_assert(not main.get_node("UI/BoxCount").visible and not main.get_node("UI/Minimap").visible, "new players are not shown resource statistics or minimap")
	_assert(not (main.get_node("UI/SurvivalStatus") as Label).text.contains("PWR"), "advanced production rates stay hidden during quick start")
	main.tutorial_moved = true
	main.tutorial_picked = true
	main.tutorial_rotated = true
	main.tutorial_placed = true
	main.tutorial_delivered = true
	main.tutorial_menu_opened = true
	main.tutorial_base_two = true
	main.tutorial_base_three = true
	main.call("_refresh_tutorial")
	main.call("_update_staged_ui")
	_assert(main.ui_stage() == 1 and not main.get_node("UI/BoxCount").visible and main.get_node("UI/Economy").visible, "basic automation keeps all resources in the unified economy list")
	_assert(main.economy_ui.visible_resource_indices().is_empty(), "uncollected zero-value resources remain hidden")
	main.quest_step = 5
	main.call("_update_staged_ui")
	_assert(main.ui_stage() == 2 and main.get_node("UI/Minimap").visible and main.get_node("UI/Economy").visible, "outer exploration reveals map and early resources")
	main.quest_step = 8
	_assert(main.ui_stage() == 3, "power era reveals energy and food information")
	main.quest_step = 10
	_assert(main.ui_stage() == 4, "oil era reveals the full late-game economy")

func _test_cold_and_sleep(main: Node2D) -> void:
	var base := main.get_node("Base") as StaticBody2D
	var player := main.get_node("Player") as CharacterBody2D
	player.position = base.position + Vector2.RIGHT * main.TILE_SIZE * 15.0
	main.temperature = 100.0
	main.call("_update_survival", 1.0)
	_assert(main.temperature < 90.0, "temperature falls beyond the warm radius")
	player.position = base.position
	var frozen_temperature: float = main.temperature
	main.call("_update_survival", 2.0)
	_assert(main.temperature > frozen_temperature, "temperature recovers near the base")
	player.position = base.position + Vector2.RIGHT * main.TILE_SIZE * 20.0
	main.temperature = 0.1
	main.call("_update_survival", 1.0)
	_assert(main.temperature == 0.0 and player.controls_locked and main.freeze_countdown == 3.0, "zero temperature starts a three-second frozen countdown")
	main.call("primary_action")
	main.call("begin_placement_action")
	_assert(not main.collect_action_held and not main.placement_action_held, "Z and X interactions stay disabled while frozen")
	main.call("_update_survival", 3.1)
	_assert(main.freeze_countdown < 0.0 and not player.controls_locked and player.position.distance_to(base.position) <= main.TILE_SIZE * 4.1 and main.temperature == 60.0, "countdown respawns the player warm near base")
	main.day_time = 659.5
	main.call("_update_survival", 1.0)
	_assert(main.night_warning_shown and main.cats_should_rest(), "cats stop work and the return warning starts at minute eleven")
	player.position = base.position + base.SHELTER_DIRECTION * base.SHELTER_DISTANCE
	main.call("primary_action")
	_assert(main.shelter_open and not main.developer_money_button.visible and not main.save_game_button.visible, "southwest HOME entrance opens an uncluttered night shelter")
	main.call("primary_action")
	_assert(not main.shelter_open and main.day_time == 0.0 and main.developer_money_button.visible and main.save_game_button.visible, "sleep begins the next day and restores top controls")

func _test_scaling_and_technology(main: Node2D) -> void:
	for index in range(2):
		var generator := load("res://scenes/FacilityBlock.tscn").instantiate() as FacilityBlock
		generator.facility_type = "power_generator"
		generator.position = Vector2(300 + index * 96, 300)
		main.add_child(generator)
		var electric := load("res://scenes/CatBlock.tscn").instantiate() as CatBlock
		electric.worker_type = "electric"
		electric.position = generator.position + Vector2.RIGHT * 32.0
		main.add_child(electric)
		var field := load("res://scenes/FacilityBlock.tscn").instantiate() as FacilityBlock
		field.facility_type = "fishing_spot"
		field.position = Vector2(300 + index * 96, 500)
		main.add_child(field)
		var fisher := load("res://scenes/CatBlock.tscn").instantiate() as CatBlock
		fisher.worker_type = "fisher"
		fisher.position = field.position + Vector2.RIGHT * 32.0
		main.add_child(fisher)
	await process_frame
	_assert(main.power_per_minute() == 200 and main.food_per_minute() == 80, "each additional cat-equipment pair raises power and food throughput")
	_assert(main.safe_radius_tiles() == 15, "base level and electric equipment pairs expand the warm frontier")
	var extra_electric := load("res://scenes/CatBlock.tscn").instantiate() as CatBlock
	extra_electric.worker_type = "electric"
	extra_electric.position = Vector2(332, 300)
	main.add_child(extra_electric)
	await process_frame
	_assert(not main.worker_has_equipment_slot(extra_electric, "electric", "power_generator"), "a cat without additional equipment cannot add production")
	main.resource_counts["copper"] = 20
	main.resource_counts["crystal"] = 20
	main.base_level = 5
	var radius_before: int = main.safe_radius_tiles()
	main.research_selection = 0
	main.call("_start_selected_research")
	_assert(main.active_research == 0 and main.heat_tech == 0 and main.research_remaining == 600.0, "HEAT research takes ten minutes and does not finish immediately")
	main.call("_update_research", 599.0)
	_assert(main.heat_tech == 0, "research remains pending until its full duration")
	main.call("_update_research", 1.0)
	_assert(main.heat_tech == 1 and main.safe_radius_tiles() == radius_before + 4, "HEAT TECH expands exploration radius")
	_assert(main.research_cost(0)["copper"] == 7 and main.research_duration(0) == 1200.0, "repeat research becomes more expensive and ten minutes longer")
	main.research_selection = 1
	main.call("_start_selected_research")
	_assert(main.research_remaining == 1200.0, "POWER research starts at twenty minutes")
	main.call("_update_research", 1200.0)
	_assert(main.power_tech == 1 and main.power_output_amount() == 7, "POWER TECH increases each equipment pair output")
	main.fish = 20
	main.research_selection = 2
	main.call("_start_selected_research")
	_assert(main.research_remaining == 1800.0, "FOOD research starts at thirty minutes")
	main.call("_update_research", 1800.0)
	_assert(main.food_tech == 1 and main.food_output_amount() == 3, "FOOD TECH increases fishing output")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("SURVIVAL_TEST: FAIL - " + message)
		failures += 1
