extends "res://tests/framework/test_case.gd"

## Step 46: fifty cargo journeys asked for at once (the issue's "50 concurrent queued animated
## cargo"). Natural play reaches 7-9 in the air (perf46), so this is the view's dev storm
## (`dev_cargo`): every frame it asks again for the missing lot lifts, through the model's own
## event. The view draws at most CARGO_MAX (40); the asks over it are refused and counted, the
## lots and bags come from the pool (a second storm makes no new nodes), every journey ends,
## and the model is not touched (the clock is paused: its save is the same text before and after).

const Main := preload("res://app/main.tscn")
## Like test_factory, this file keeps actor.gd loaded. A factory test in a file that sorts
## before test_cast reported leaked scripts at the runner's exit (atlas, economy, save_store and
## the sprite sheet) -- on 0.46.1 too, with test_redraw46's own content under this name. A file
## that loads actor.gd (or test_cast's classes) before the factory opens is clean. Cause not found.
const Actor := preload("res://variants/factory/actor.gd")
const PLAN := [["M07", "kitchen"], ["bagger", "packing"], ["S03", "shop"], ["M01", "kitchen"], ["M07", "kitchen"],
	["S05", "shop"], ["M07", "kitchen"], ["P07", "packing"], ["M13", "kitchen"], ["M07", "kitchen"], ["bagger", "packing"], ["S08", "shop"]]
var app: PopApp


func before_each() -> void:
	app = Main.instantiate()
	app.save_prefix = "test."
	tree.root.add_child(app)
	await tree.process_frame


func after_each() -> void:
	app.clock.set_pause("test", false)
	app.queue_free()
	await tree.process_frame


func _storm(v: Node, n: int, frames: int) -> Dictionary:
	v.dev_cargo(n, 600.0)
	var worst := 0
	for i in frames:
		await tree.process_frame
		worst = maxi(worst, (v.cargo as Dictionary).size())
	var s: Dictionary = v.dev_cargo(0, 0.0)
	s["worst"] = worst
	return s


func _settle(v: Node) -> int:
	# Every storm journey lands (0.9 s up the tube; headless frames are short, so wait by the clock).
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 8000:
		await tree.process_frame
		if (v._storm_ids as Dictionary).is_empty():
			break
	return (v._storm_ids as Dictionary).size()


func test_fifty_journeys_at_once_draw_at_most_the_cap_reuse_their_nodes_and_leave_the_model_alone() -> void:
	app.open("factory")
	await tree.process_frame
	app.dev_money(1000000000)
	assert_true(bool(app.dev_build(PLAN, 6, 3)["ok"]), "a twelve-machine factory")
	for i in 10:
		app.dev_advance(250)
		await tree.process_frame
	var v: Node = app.frame.play
	var cap := int(v.CARGO_MAX)
	app.clock.set_pause("test", true)   # the model stands still; the view keeps drawing
	for i in 3:
		await tree.process_frame
	var before := JSON.stringify(app.rules.to_save())
	var nodes0 := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	v.dev_cargo(50, 600.0)
	await tree.process_frame
	var kinds := {}
	for id: int in (v._storm_ids as Dictionary).keys():
		kinds[String((v.cargo as Dictionary)[id].kind)] = true
	assert_eq(kinds.keys(), [Actor.LOT], "the storm's journeys are lots up the tube")
	v.dev_cargo(0, 0.0)
	await _settle(v)
	var a := await _storm(v, 50, 90)
	var left_a := await _settle(v)
	var nodes1 := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var b := await _storm(v, 50, 90)
	var left_b := await _settle(v)
	var nodes2 := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var after := JSON.stringify(app.rules.to_save())
	print("  storm 1: ", a, " left ", left_a, "; storm 2: ", b, " left ", left_b, "; nodes ", nodes0, " -> ", nodes1, " -> ", nodes2, "; cap ", cap)
	for s: Dictionary in [a, b]:
		# The model stands still, so no bag is being sealed: the cap holds exactly.
		assert_true(int(s["worst"]) <= cap, "never more than %d journeys drawn (%d)" % [cap, int(s["worst"])])
		assert_eq(int(s["peak"]), cap, "fifty asked reach the cap")
		assert_true(int(s["refused"]) > 0, "the asks over the cap are refused and counted (%d)" % int(s["refused"]))
		assert_true(int(s["drawn"]) >= cap, "and the ones under it fly (%d)" % int(s["drawn"]))
	assert_eq(left_a, 0, "every journey of the first storm landed")
	assert_eq(left_b, 0, "and of the second")
	assert_true(nodes1 - nodes0 <= 4 * cap, "the first storm's nodes are bounded by the pool (%d more)" % (nodes1 - nodes0))
	assert_true(nodes2 <= nodes1 + 2, "a second storm reuses them (%d -> %d)" % [nodes1, nodes2])
	assert_eq(after, before, "the storm is a picture: the model's save is the same text")
