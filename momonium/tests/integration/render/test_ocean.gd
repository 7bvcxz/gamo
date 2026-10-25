extends "res://tests/framework/test_case.gd"

const MainScene := preload("res://scenes/main.tscn")

var main: Node


func before_each() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame


func after_each() -> void:
	main.queue_free()
	await tree.process_frame


func test_ocean_covers_the_screen_behind_the_world() -> void:
	var ocean: OceanRenderer = main.get("ocean")
	assert_eq(ocean.size, ocean.get_viewport_rect().size, "one full-screen quad, whatever the zoom")
	assert_true(ocean.get_parent() is CanvasLayer and (ocean.get_parent() as CanvasLayer).layer < 0, "drawn behind the island")
	assert_eq(ocean.mouse_filter, Control.MOUSE_FILTER_IGNORE, "never eats a tap meant for the world")


func test_shader_follows_the_camera() -> void:
	var ocean: OceanRenderer = main.get("ocean")
	var cams: CameraController = main.get("cameras")
	cams.pan_screen(Vector2(-120, 40))
	await tree.process_frame
	var inv: Transform2D = (main.get("camera") as Camera2D).get_canvas_transform().affine_inverse()
	var mat := ocean.material as ShaderMaterial
	assert_true((mat.get_shader_parameter("inv_o") as Vector2).distance_to(inv.origin) < 0.01, "waves stay anchored to the world while panning")
	assert_true((mat.get_shader_parameter("inv_x") as Vector2).distance_to(inv.x) < 0.0001, "and while zooming")


func test_coastline_updates_when_land_is_added() -> void:
	var ocean: OceanRenderer = main.get("ocean")
	var world: WorldSystem = main.get("sim").system(&"world")
	var rect_before := ocean.shore.rect
	world.add_land(Vector2i(2, 0))
	world.add_land(Vector2i(3, 0))
	await tree.process_frame
	assert_true(ocean.shore.rect.size.x > rect_before.size.x, "the shore field grew with the island")
	assert_true(ocean.shore.sample(Vector2(3.5, 0.5)) > 0.9, "new land is land to the sea")


func test_no_other_land_exists() -> void:
	# The sea is endless and empty: nothing but the player's island is land.
	var ocean: OceanRenderer = main.get("ocean")
	var world: WorldSystem = main.get("sim").system(&"world")
	var r := ocean.shore.rect
	var stray := 0
	for y in int(r.size.y):
		for x in int(r.size.x):
			var p := r.position + Vector2(x + 0.5, y + 0.5)
			if ocean.shore.sample(p) > 0.9 and not world.is_owned(Vector2i(floori(p.x), floori(p.y))):
				stray += 1
	assert_eq(stray, 0, "no land outside the island")


func test_many_changes_in_one_frame_rebuild_once() -> void:
	var island: IslandRenderer = main.get("island")
	var world: WorldSystem = main.get("sim").system(&"world")
	for x in range(2, 10):
		world.add_land(Vector2i(x, 0))
	await tree.process_frame
	assert_eq(island.paint_order().size(), world.owned_count(), "the island caught up with all eight new cells")
	assert_true(island.last_build_ms < 100.0, "one rebuild of a small island is cheap (%.1f ms)" % island.last_build_ms)
