extends "res://tests/framework/test_case.gd"

const MainScene := preload("res://scenes/main.tscn")

var main: Node
var sim: Simulation
var world: WorldSystem
var island: IslandRenderer


func before_each() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	sim = main.get("sim")
	world = sim.system(&"world")
	island = main.get("island")


func after_each() -> void:
	main.queue_free()
	await tree.process_frame


func test_start_island_shows_four_cliff_faces() -> void:
	# 2x2: the two cells on the +x side and the two on the +y side are open to the sea.
	assert_eq(island.visible_face_count(), 4, "four near faces")
	assert_true(island.is_face_visible(Vector2i(1, 0), Vector2i(1, 0)), "east cell's east face")
	assert_false(island.is_face_visible(Vector2i(0, 0), Vector2i(1, 0)), "inner edge has no face")
	assert_false(island.is_face_visible(Vector2i(0, 0), Vector2i(-1, 0)), "far edges never show a face")


func test_paint_order_is_far_to_near() -> void:
	for cell: Vector2i in [Vector2i(2, 0), Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(-1, 1)]:
		world.add_land(cell)
	await tree.process_frame
	var order := island.paint_order()
	assert_eq(order.size(), world.owned_count(), "every owned cell is painted")
	for i in range(1, order.size()):
		var a := order[i - 1]
		var b := order[i]
		assert_true(IsoProjection.depth(a) < IsoProjection.depth(b) or (IsoProjection.depth(a) == IsoProjection.depth(b) and a.x < b.x), "%s before %s" % [a, b])


func test_irregular_island_faces_follow_the_coast() -> void:
	# A two-cell peninsula east of the start island, faces counted by hand.
	world.add_land(Vector2i(2, 0))
	world.add_land(Vector2i(3, 0))
	await tree.process_frame
	# +x faces: (1,1) and (3,0). +y faces: (0,1), (1,1), (2,0), (3,0).
	assert_eq(island.visible_face_count(), 6, "faces follow the new coastline")


func test_decorations_are_visual_only_and_stable() -> void:
	var before: Dictionary = world.save_state()
	for cell: Vector2i in world.owned_cells():
		assert_eq(IslandRenderer.decals_for(cell), IslandRenderer.decals_for(cell), "decals of %s are deterministic" % cell)
	island.queue_redraw()
	await tree.process_frame
	assert_eq(world.save_state(), before, "drawing decorations changes nothing in the world")
	var kinds := {}
	for x in 30:
		for y in 30:
			for d: Array in IslandRenderer.decals_for(Vector2i(x, y)):
				kinds[d[0]] = true
	assert_eq(kinds.size(), 3, "a large island gets all three decoration kinds")


func test_entities_sort_by_depth() -> void:
	var layer: EntityLayer = main.get("entities")
	assert_true(layer.y_sort_enabled, "entity layer is y-sorted")
	var back := Node2D.new()
	var front := Node2D.new()
	var left := Node2D.new()
	var right := Node2D.new()
	layer.add_entity(back, Vector2(0.5, 0.5))
	layer.add_entity(front, Vector2(1.5, 1.5))
	layer.add_entity(left, Vector2(0.5, 1.5))
	layer.add_entity(right, Vector2(1.5, 0.5))
	assert_true(front.position.y > back.position.y, "nearer cell draws later")
	assert_true(right.position.y > left.position.y, "same depth: larger x draws later (stable tie-break)")
	assert_true(absf(right.position.y - left.position.y) < 0.1, "tie-break is too small to see")
