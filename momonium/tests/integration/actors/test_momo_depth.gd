extends "res://tests/framework/test_case.gd"

## Step 55: Momo in front of buildings more often, still behind one they are
## clearly behind. The entity layer y-sorts by each node's position; a Momo's
## node sits `art.momo_depth.bias_tiles` of depth nearer than its feet and its
## drawing is lifted back by as much -- so only the order changes. These cases
## read the order the layer will use (node y) against where the Momo really
## stands, for every kind of building.

const MainScene := preload("res://scenes/main.tscn")

var main: Node
var sim: Simulation
var momos: MomoSystem
var bs: BuildingSystem
var views: MomoViews
var bviews: BuildingViews
var layer: EntityLayer
var bias := 0.0


func before_each() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	sim = main.get("sim")
	sim.time_scale = 0.0
	momos = sim.system(&"momo")
	bs = sim.system(&"buildings")
	views = main.get("momo_views")
	bviews = main.get("building_views")
	layer = main.get("entities")
	bias = sim.data.get_float("art", "momo_depth.bias_tiles", 0.0)
	var world: WorldSystem = sim.system(&"world")
	for x in 4:
		for y in 4:
			world.add_land(Vector2i(x, y))
	for id: int in bs.ids().duplicate():
		bs.demolish(id)


func after_each() -> void:
	main.queue_free()
	await tree.process_frame


## The test's Momo standing at `at`, placed by the views as in play (one
## Momo, moved from spot to spot; `fresh` adds another).
var _id := 0


func _momo_at(at: Vector2, fresh: bool = false) -> MomoActor:
	if _id == 0 or fresh:
		_id = momos.add_momo(at)
		views.sync()
	var m := momos.get_momo(_id)
	m["from"] = [at.x, at.y]
	m["to"] = [at.x, at.y]
	views._process(0.0)
	return views.actor(_id)


func _in_front(a: MomoActor, building: int) -> bool:
	return a.position.y > bviews.view(building).position.y


func test_the_bias_is_data_and_moderate() -> void:
	assert_between(bias, 0.3, 0.8, "a nudge, not 'always on top' (%.2f)" % bias)
	assert_true(views.depth_lift > 0.0, "turned into screen pixels through the projection")


func test_beside_or_in_front_draws_in_front_clearly_behind_stays_behind() -> void:
	var c := Vector2(1.5, 1.5)
	for type: String in ["farm", "mine", "lumberyard", "research", "clock_tower", "school", "momo_monument", "apartment", "wind_turbine"]:
		for id: int in bs.ids().duplicate():
			bs.demolish(id)
		var b := bs.place_instant(type, Vector2i(1, 1))
		await tree.process_frame
		assert_true(b != 0, "%s placed" % type)
		# In front, at each side, on the tile's own front half: in front.
		for d: Vector2 in [Vector2(0.62, 0.62), Vector2(-0.55, 0.62), Vector2(0.62, -0.55), Vector2(-0.1, -0.1)]:
			var a := _momo_at(c + d)
			assert_true(_in_front(a, b), "%s: a Momo at %s draws in front" % [type, d])
		# On the tiles behind it: hidden by it, as it should be.
		for d: Vector2 in [Vector2(-0.85, -0.85), Vector2(-1.0, -0.2), Vector2(-0.2, -1.0)]:
			var a := _momo_at(c + d)
			assert_false(_in_front(a, b), "%s: a Momo clearly behind (%s) stays behind" % [type, d])


func test_it_is_drawn_and_tapped_where_it_stands() -> void:
	var at := Vector2(2.3, 1.8)
	var a := _momo_at(at)
	var feet := layer.ground_point(at)
	assert_eq(a.ground(), feet, "its feet where the simulation says")
	assert_near(a.position.y - feet.y, views.depth_lift, 0.001, "the node lower by the lift, for the sort only")
	a._process(0.0)
	assert_near(a.position.y + a.rig.position.y, feet.y, 0.5, "the drawing lifted back to the feet")
	assert_true(a.hit_rect().has_point(feet + Vector2(0, -35)), "its body is where a tap finds it")
	assert_false(a.hit_rect().has_point(feet + Vector2(0, 30)), "and not below it")
	assert_eq(views.hit(feet + Vector2(0, -35)), int(a.name.trim_prefix("Momo_")), "the views find it there")


func test_one_flip_along_a_walk_no_flicker() -> void:
	var b := bs.place_instant("research", Vector2i(1, 1))
	await tree.process_frame
	var flips := 0
	var was := false
	var first := true
	# From well behind to well in front, straight through its depth.
	for i in 41:
		var k := i / 40.0
		var a := _momo_at(Vector2(0.4, 0.4).lerp(Vector2(2.6, 2.6), k))
		var now := _in_front(a, b)
		if not first and now != was:
			flips += 1
		was = now
		first = false
	assert_eq(flips, 1, "behind, then in front -- once")


func test_momo_keep_their_order_among_themselves() -> void:
	var back := _momo_at(Vector2(1.2, 1.2), true)
	var front := _momo_at(Vector2(1.6, 1.7), true)
	assert_true(front.position.y > back.position.y, "the nearer Momo is still drawn over the farther")
	assert_near(front.position.y - back.position.y, layer.ground_point(Vector2(1.6, 1.7)).y - layer.ground_point(Vector2(1.2, 1.2)).y, 0.001, "by exactly their own distance")


func test_a_tap_on_a_momo_in_front_of_a_building_takes_the_momo() -> void:
	var b := bs.place_instant("research", Vector2i(1, 1))
	await tree.process_frame
	var a := _momo_at(Vector2(1.5, 1.5) + Vector2(-0.1, -0.1))
	assert_true(_in_front(a, b), "drawn over the lab")
	var sel: SelectionController = main.get("selection")
	var world := a.ground() + Vector2(0, -35)
	assert_eq(views.hit(world), int(a.name.trim_prefix("Momo_")), "the Momo is what the finger touches")
	sel.on_tap(Vector2.ZERO, world)
	assert_eq(sel.kind, "momo", "a tap there selects it, not the lab behind it")
	assert_eq(sel.selected_id, int(a.name.trim_prefix("Momo_")), "")
