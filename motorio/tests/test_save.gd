extends SceneTree

var failures := 0
const TEST_SAVE_PATH := "user://motorio_test_save.cfg"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await physics_frame
	main.box_count = 17
	main.mineral_count = 23
	main.resource_counts["copper"] = 9
	main.electricity = 31
	main.fish = 14
	main.base_level = 4
	main.quest_step = 6
	main.day_number = 3
	main.day_time = 245.0
	main.temperature = 72.0
	main.heat_tech = 2
	main.active_research = 1
	main.research_remaining = 321.0
	main.research_total = 1200.0
	main.player.position += Vector2(96, -64)
	main.inventory.append({"type": "pillar"})
	var saved_player_position: Vector2 = main.player.position
	var box := load("res://scenes/PushTile.tscn").instantiate() as RigidBody2D
	box.position = main.base.position + Vector2(320, 96)
	main.add_child(box)
	await physics_frame
	var saved_box_position: Vector2 = box.position
	_assert(main.save_game(false, TEST_SAVE_PATH), "manual save writes a ConfigFile")
	main.box_count = 0
	main.mineral_count = 0
	main.resource_counts["copper"] = 0
	main.day_time = 0.0
	main.player.position = Vector2.ZERO
	main.inventory.clear()
	box.queue_free()
	await physics_frame
	_assert(main.load_game(TEST_SAVE_PATH), "saved state loads successfully")
	await physics_frame
	_assert(main.box_count == 17 and main.mineral_count == 23 and main.resource_counts["copper"] == 9, "collected resources restore")
	_assert(main.electricity == 31 and main.fish == 14 and main.base_level == 4 and main.quest_step == 6, "economy and progression restore")
	_assert(main.day_number == 3 and main.day_time == 245.0 and main.temperature == 72.0, "day and survival state restore")
	_assert(main.heat_tech == 2 and main.active_research == 1 and main.research_remaining == 321.0, "technology and active research restore")
	_assert(main.player.position == saved_player_position and main.inventory == [{"type": "pillar"}], "player position and inventory restore")
	var restored_boxes := get_nodes_in_group("box_block").filter(func(node): return node.position.distance_to(saved_box_position) < 2.0)
	_assert(restored_boxes.size() == 1, "world block positions restore without duplicates")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
	if failures == 0:
		print("SAVE_TEST: PASS")
	quit(failures)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("SAVE_TEST: FAIL - " + message)
		failures += 1
