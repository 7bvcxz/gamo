extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	var minimap := main.get_node("UI/Minimap") as Control
	_assert(minimap.size == Vector2(140, 140), "minimap has expected top-right size")
	_assert(minimap.position.x >= 480.0 and minimap.position.y == 16.0, "minimap is positioned at top-right")
	var world_origin: Vector2 = minimap.call("world_to_map", Vector2.ZERO)
	var world_end: Vector2 = minimap.call("world_to_map", Vector2.ONE * 3200.0)
	_assert(world_origin.distance_to(Vector2.ONE * 6.0) < 0.01, "world origin maps inside minimap border")
	_assert(world_end.distance_to(Vector2.ONE * 134.0) < 0.01, "world end maps inside minimap border")
	var center: Vector2 = minimap.call("world_to_map", Vector2.ONE * 1600.0)
	_assert(center.distance_to(Vector2.ONE * 70.0) < 0.01, "world center maps to minimap center")
	_assert(get_nodes_in_group("mineral_block").size() > 300, "minimap has mineral data to render")
	if failures == 0:
		print("MINIMAP_TEST: PASS")
	quit(failures)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("MINIMAP_TEST: FAIL - " + message)
		failures += 1
