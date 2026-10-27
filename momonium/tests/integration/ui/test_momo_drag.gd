extends "res://tests/framework/test_case.gd"

## Dragging Momo with a real finger (and a mouse), and the no-drag way
## (Schedule, Step 60).

const MainScene := preload("res://scenes/main.tscn")

var main: Node
var sim: Simulation
var momos: MomoSystem
var buildings: BuildingSystem
var cams: CameraController
var proj: IsoProjection
var vp: Viewport
var farm := 0


func before_each() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	sim = main.get("sim")
	sim.time_scale = 0.0
	# The Momo these cases are about (Step 53: a new island has none).
	with_starter_momo(sim)
	await tree.process_frame
	momos = sim.system(&"momo")
	buildings = sim.system(&"buildings")
	cams = main.get("cameras")
	proj = main.get("projection")
	vp = main.get_viewport()
	farm = buildings.place_instant("farm", Vector2i(1, 0))
	await tree.process_frame
	await tree.process_frame


func after_each() -> void:
	main.queue_free()
	await tree.process_frame


func _momo_screen() -> Vector2:
	var a: MomoActor = (main.get("momo_views") as MomoViews).actor(1)
	return cams.world_to_screen(a.position + Vector2(0, -35))


func _drag(from: Vector2, to: Vector2, mouse: bool = false) -> void:
	if mouse:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.position = from
		b.pressed = true
		vp.push_input(b, true)
		for i in range(1, 9):
			var m := InputEventMouseMotion.new()
			m.position = from.lerp(to, i / 8.0)
			vp.push_input(m, true)
		b = b.duplicate()
		b.pressed = false
		b.position = to
		vp.push_input(b, true)
		return
	var t := InputEventScreenTouch.new()
	t.position = from
	t.pressed = true
	vp.push_input(t, true)
	for i in range(1, 9):
		var d := InputEventScreenDrag.new()
		d.position = from.lerp(to, i / 8.0)
		vp.push_input(d, true)
	t = t.duplicate()
	t.pressed = false
	t.position = to
	vp.push_input(t, true)


func test_drag_onto_the_farm_assigns() -> void:
	var cam_before: Vector2 = (main.get("camera") as Camera2D).position
	_drag(_momo_screen(), cams.world_to_screen(proj.cell_center(Vector2i(1, 0))))
	assert_eq(momos.get_momo(1)["assigned"], farm, "dropped on the farm: working there")
	assert_eq((main.get("camera") as Camera2D).position, cam_before, "the camera did not pan")


func test_drag_with_a_mouse_too() -> void:
	_drag(_momo_screen(), cams.world_to_screen(proj.cell_center(Vector2i(1, 0))), true)
	assert_eq(momos.get_momo(1)["assigned"], farm, "mouse drag assigns as well")


func test_drop_on_land_moves_and_in_the_sea_refuses() -> void:
	_drag(_momo_screen(), cams.world_to_screen(proj.cell_center(Vector2i(0, 0))))
	var p := momos.position_of(1)
	assert_true(Vector2i(floori(p.x), floori(p.y)) == Vector2i(0, 0), "put down on the tile it was dropped on (%s)" % p)
	await tree.process_frame
	var before := momos.position_of(1)
	_drag(_momo_screen(), cams.world_to_screen(proj.cell_center(Vector2i(5, 5))))
	assert_eq((main.get("momo_drag") as MomoDrag).last_result["reason"], "err.not_owned", "the sea refuses")
	assert_eq(momos.position_of(1), before, "and Momo goes back")


func test_drop_hint_shows_while_carrying() -> void:
	var start := _momo_screen()
	var over := cams.world_to_screen(proj.cell_center(Vector2i(1, 0)))
	var t := InputEventScreenTouch.new()
	t.position = start
	t.pressed = true
	vp.push_input(t, true)
	for i in range(1, 9):
		var d := InputEventScreenDrag.new()
		d.position = start.lerp(over, i / 8.0)
		vp.push_input(d, true)
	var view: BuildingView = (main.get("building_views") as BuildingViews).view(farm)
	assert_eq(view.drop_hint, 1, "the farm lights green under a carried Momo")
	(main.get("momo_drag") as MomoDrag).cancel_drag()
	assert_eq(view.drop_hint, 0, "and clears when the carry ends")


func test_tap_selects_and_schedule_assigns_without_dragging() -> void:
	# Step 60: the no-drag way is Schedule -- the Momo card's Assign and
	# Release are gone.
	var tap := func(p: Vector2) -> void:
		for pressed: bool in [true, false]:
			var t := InputEventScreenTouch.new()
			t.position = p
			t.pressed = pressed
			vp.push_input(t, true)
	tap.call(_momo_screen())
	var sel: SelectionController = main.get("selection")
	assert_eq(sel.kind, "momo", "a tap selects the Momo")
	var editor: WatchEditor = main.get("watch_editor")
	assert_true(editor.schedule.is_visible_in_tree(), "its Schedule button shows")
	await tree.process_frame
	tap.call(editor.schedule.get_global_rect().get_center())
	assert_true(editor.active, "Schedule mode")
	var f := cams.world_to_screen(proj.cell_center(Vector2i(1, 0)))
	tap.call(f)
	assert_eq(momos.get_momo(1)["assigned"], farm, "tapping the farm's tile assigned it")
	assert_eq(buildings.get_building(farm)["state"], BuildingSystem.IDLE, "and did not start the farm's work")
	tap.call(f)
	assert_eq(momos.get_momo(1)["assigned"], 0, "tapping it again lets it go")
	assert_eq(momos.watched(1), [] as Array[Vector2i], "with nothing left to look after")
