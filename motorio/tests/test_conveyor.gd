extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://scenes/Conveyor.tscn")
	var conveyor := scene.instantiate() as ConveyorBlock
	root.add_child(conveyor)
	await process_frame

	_assert(conveyor.contains_effect_point(Vector2.ZERO), "center is inside")
	_assert(conveyor.contains_effect_point(Vector2(11.9, 0)), "inner point is inside")
	_assert(not conveyor.contains_effect_point(Vector2(12.0, 0)), "effect boundary is excluded")
	_assert(not conveyor.contains_effect_point(Vector2(16.0, 0)), "block outline is excluded")

	for offset_step in range(20):
		conveyor.animation_offset = float(offset_step)
		for arrow_index in range(2):
			for point in conveyor.get_arrow_points(arrow_index):
				_assert(abs(point.x) <= 14.0 and abs(point.y) <= 14.0, "arrow stays inside block")

	print("CONVEYOR_TEST: PASS")
	quit(0)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("CONVEYOR_TEST: FAIL - " + message)
		quit(1)
