extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	var minimap := main.get_node("UI/UIRoot/Minimap") as Control
	_assert(minimap.size == Vector2(140, 140), "minimap has expected top-right size")
	_assert(minimap.position.x >= 480.0 and minimap.position.y == 16.0, "minimap is positioned at top-right")
	var box_label := main.get_node("UI/UIRoot/BoxCount") as Label
	var version_label := main.get_node("UI/UIRoot/Version") as Label
	_assert(box_label.position.x == 16.0 and box_label.position.y == 100.0, "collected box resource stays at top-left")
	_assert(version_label.anchor_left == 1.0 and version_label.anchor_top == 1.0, "version stays anchored to the bottom-right")
	var world_origin: Vector2 = minimap.call("world_to_map", Vector2.ZERO)
	var world_end: Vector2 = minimap.call("world_to_map", Vector2.ONE * 3200.0)
	_assert(world_origin.distance_to(Vector2.ONE * 6.0) < 0.01, "world origin maps inside minimap border")
	_assert(world_end.distance_to(Vector2.ONE * 134.0) < 0.01, "world end maps inside minimap border")
	var center: Vector2 = minimap.call("world_to_map", Vector2.ONE * 1600.0)
	_assert(center.distance_to(Vector2.ONE * 70.0) < 0.01, "world center maps to minimap center")
	_assert(get_nodes_in_group("mineral_block").size() >= 40, "minimap has sparse mineral data to render")
	_assert(minimap.get("mineral_points").size() < 160, "mineral markers are coarsely aggregated")
	_assert(minimap.get("block_points").size() < 200, "block markers are coarsely aggregated")
	var initial_refreshes: int = minimap.get("refresh_count")
	minimap.set("refresh_elapsed", 0.0)
	for frame in range(59):
		minimap.call("_process", 1.0 / 60.0)
	_assert(minimap.get("refresh_count") == initial_refreshes, "minimap does not redraw every frame")
	minimap.call("_process", 1.0 / 60.0)
	_assert(minimap.get("refresh_count") == initial_refreshes + 1, "minimap refreshes once per second")
	if failures == 0:
		print("MINIMAP_TEST: PASS")
	quit(failures)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("MINIMAP_TEST: FAIL - " + message)
		failures += 1
