extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await physics_frame

	# Main publishes the camera rectangle so machines can skip off-screen redraws.
	main.call("_process", 0.0)
	_assert(WorldView.visible_rect.size.x > 0.0, "the world view rect is published every frame")
	_assert(WorldView.is_on_screen(main.player.global_position), "the player's own tile counts as on screen")
	var far_point: Vector2 = main.player.global_position + Vector2.RIGHT * main.TILE_SIZE * 200.0
	_assert(not WorldView.is_on_screen(far_point), "a distant machine is correctly treated as off screen")

	# An unset rect must not hide the world, so headless tools still render.
	var saved_rect: Rect2 = WorldView.visible_rect
	WorldView.visible_rect = Rect2()
	_assert(WorldView.is_on_screen(far_point), "an unpublished view rect falls back to drawing everything")
	WorldView.visible_rect = saved_rect

	# A large factory keeps simulating while off screen; only drawing is skipped.
	var conveyors: Array[ConveyorBlock] = []
	for index in range(300):
		var belt := load("res://scenes/Conveyor.tscn").instantiate() as ConveyorBlock
		belt.direction = Vector2.RIGHT
		belt.position = far_point + Vector2(float(index % 30) * 32.0, float(index / 30) * 32.0)
		main.add_child(belt)
		conveyors.append(belt)
	await physics_frame
	var offset_before: float = conveyors[0].animation_offset
	for belt in conveyors:
		belt.call("_process", 0.25)
	_assert(conveyors[0].animation_offset != offset_before, "off-screen belts still advance their simulation state")

	var smelter := load("res://scenes/Smelter.tscn").instantiate() as Smelter
	smelter.position = far_point
	main.add_child(smelter)
	await physics_frame
	smelter.stored_minerals = Smelter.MINERAL_COST
	smelter.stored_coal = Smelter.COAL_COST
	smelter.call("_physics_process", 0.1)
	_assert(smelter.is_smelting(), "an off-screen smelter still starts and runs its batch")

	_assert(get_nodes_in_group("transport_floor").size() >= 300, "the scene carries a few hundred machines without erroring")

	if failures == 0:
		print("SCALE_TEST: PASS")
	quit(failures)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("SCALE_TEST: FAIL - " + message)
		failures += 1
