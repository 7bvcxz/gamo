extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await physics_frame
	_test_placement(main)
	_test_base_levels(main)
	_test_developer_tutorial_button(main)
	_test_guidance_and_cold(main)
	if failures == 0:
		print("EXPANSION_TEST: PASS")
	quit(failures)

func _test_placement(main: Node2D) -> void:
	var entrance: Vector2 = main.base.global_position + Vector2.UP * main.base.ENTRANCE_DISTANCE
	_assert(main._is_base_entrance_cell(entrance), "base entrance grid is recognized")
	_assert(main._can_place_item_at(entrance, "box", Vector2.RIGHT), "ordinary blocks can be placed at a base entrance")
	var mineral := get_nodes_in_group("mineral_block")[0] as MineralBlock
	_assert(main._can_place_item_at(mineral.global_position, "conveyor", Vector2.RIGHT), "TransportFloor can be placed under a fixed resource")
	_assert(not main._can_place_item_at(mineral.global_position, "box", Vector2.RIGHT), "ordinary Solid still cannot overlap a fixed resource")

func _test_base_levels(main: Node2D) -> void:
	var radius_level_one: int = main.safe_radius_tiles()
	main.box_count = 5
	main.fabricator_selection = 15
	main._craft_selected_block()
	_assert(main.base_level == 2 and main.safe_radius_tiles() == radius_level_one + 3, "base upgrade expands warmth by three tiles")
	_assert(main.recipe_unlocked(3) and not main.recipe_unlocked(4), "level two unlocks splitter but keeps bridge locked")
	var expected := [{"box": 25}, {"mineral": 100}, {"copper": 5}, {"copper": 25}, {"fish": 25}]
	for level in range(2, 7):
		main.base_level = level
		_assert(main.base_upgrade_cost() == expected[level - 2], "base level %d uses its planned rarity cost" % level)

func _test_guidance_and_cold(main: Node2D) -> void:
	for step in range(13):
		main.quest_step = step
		_assert(main.quest_unlock_help().length() >= 18, "quest %d explains the required feature" % (step + 1))
	main.quest_step = 0
	_assert(main.quest_unlock_help().contains("채굴 고양이"), "first goal explains what the miner cat does")
	main.quest_step = 5
	_assert(main.quest_unlock_help().contains("구리 원석"), "copper goal explains how copper is mined")
	main.quest_step = 7
	_assert(main.quest_unlock_help().contains("낚시장") and main.quest_unlock_help().contains("낚시 고양이"), "food goal explains the fishing pair")
	main.tutorial_step = 6
	main.base_level = 1
	main.player.position = main.base.position + Vector2.RIGHT * (main.safe_radius_tiles() + 0.25) * main.TILE_SIZE
	main.temperature = 100.0
	main._update_survival(1.0)
	_assert(main.cold_exposure() > 0.0 and main.temperature < 92.0, "crossing the warmth edge immediately starts severe cold")
	var distance_tiles: float = main.safe_radius_tiles() + 0.01
	_assert(main.climate_ui.cold_fog_alpha(distance_tiles) >= 0.72, "cold frontier immediately applies dense white fog")

func _test_developer_tutorial_button(main: Node2D) -> void:
	main.tutorial_step = 0
	main.tutorial_moved = false
	main.tutorial_next_button.emit_signal("pressed")
	_assert(main.tutorial_step == 1 and main.tutorial_next_button.visible, "developer button advances one tutorial step")
	for step in range(5):
		main.tutorial_next_button.emit_signal("pressed")
	_assert(main.tutorial_complete() and not main.tutorial_next_button.visible, "developer button completes and then hides")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("EXPANSION_TEST: FAIL - " + message)
		failures += 1
