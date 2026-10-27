extends "res://tests/framework/test_case.gd"

## A Momo's schedule with a real finger and a mouse (Step 60): tap the Momo
## -- its tiles light up and one Schedule button appears under its feet,
## nothing else -- Schedule, then strokes decided by their first tile (never
## flipping a tile twice) within the Momo's capacity; two fingers still zoom
## and undo the stroke; Schedule again, the sea or another Momo ends it;
## outside Schedule mode a drag pans as always.

const MainScene := preload("res://scenes/main.tscn")

var main: Node
var sim: Simulation
var momos: MomoSystem
var cams: CameraController
var proj: IsoProjection
var vp: Viewport
var editor: WatchEditor
var overlay: WatchOverlay


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
	cams = main.get("cameras")
	proj = main.get("projection")
	vp = main.get_viewport()
	editor = main.get("watch_editor")
	overlay = main.get("watch_overlay")
	var world: WorldSystem = sim.system(&"world")
	for x in 3:
		for y in 3:
			world.add_land(Vector2i(x, y))
	LocaleService.apply("en")
	await tree.process_frame


func after_each() -> void:
	main.queue_free()
	await tree.process_frame


func _cell(c: Vector2i) -> Vector2:
	return cams.world_to_screen(proj.cell_center(c))


func _touch(p: Vector2, pressed: bool, index: int = 0) -> void:
	var t := InputEventScreenTouch.new()
	t.index = index
	t.position = p
	t.pressed = pressed
	vp.push_input(t, true)


func _move(p: Vector2, index: int = 0) -> void:
	var d := InputEventScreenDrag.new()
	d.index = index
	d.position = p
	vp.push_input(d, true)


## A one-finger stroke through these screen points (with steps between).
func _stroke(points: Array[Vector2]) -> void:
	_touch(points[0], true)
	for i in range(1, points.size()):
		for k in range(1, 5):
			_move(points[i - 1].lerp(points[i], k / 4.0))
	_touch(points[-1], false)


func _tap(p: Vector2) -> void:
	_touch(p, true)
	_touch(p, false)


func _select_momo() -> void:
	(main.get("selection") as SelectionController).select_momo(1)
	await tree.process_frame


## A finger on the Schedule button.
func _schedule() -> void:
	_tap(editor.schedule.get_global_rect().get_center())


func test_selecting_a_momo_shows_its_tiles_and_only_schedule() -> void:
	var farm := (sim.system(&"buildings") as BuildingSystem).place_instant("farm", Vector2i(1, 0))
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	await _select_momo()
	assert_eq(overlay.tinted(), [Vector2i(1, 0)] as Array[Vector2i], "its farm's tile is tinted")
	assert_true(editor.schedule.is_visible_in_tree(), "the Schedule button")
	assert_eq(editor.schedule.accessibility_name, "Schedule", "named Schedule")
	assert_false(editor.active, "not in Schedule mode yet")
	# Step 60: no Momo card, no Assign / Release / Info / Edit, no pencil.
	for n: String in ["MomoPanel", "Assign", "Release", "Pencil"]:
		assert_true(main.find_child(n, true, false) == null, "no %s" % n)
	assert_eq(main.get("momo_panel"), null, "the Momo card is gone")
	(main.get("selection") as SelectionController).deselect()
	assert_eq(overlay.tinted(), [] as Array[Vector2i], "deselected: no tint")
	assert_false(editor.visible, "no Schedule button")


func _feet() -> Vector2:
	var a := (main.get("momo_views") as MomoViews).actor(1)
	return cams.world_to_screen(a.global_position - Vector2(0, a.depth_lift))


func test_schedule_sits_under_the_feet_and_follows() -> void:
	await _select_momo()
	var feet := _feet()
	var r := editor.schedule.get_global_rect()
	var z := cams.camera.zoom.y
	assert_eq(editor.side, "below", "below the Momo")
	assert_near(r.get_center().x, feet.x, 1.0, "centred under it")
	assert_between(r.position.y - feet.y, 0.0, 4.0 * z + WatchEditor.GAP + 1.0, "just under its feet (%.1f)" % (r.position.y - feet.y))
	var body := Rect2(feet + Vector2(-26.0, -76.0) * z, Vector2(52.0, 80.0) * z)
	assert_false(r.intersects(body), "never over the Momo")
	# The Momo walks (in the simulation: the actor follows it each frame).
	momos.get_momo(1)["from"] = [1.2, 1.5]
	momos.get_momo(1)["to"] = [1.2, 1.5]
	await tree.process_frame
	await tree.process_frame
	var walked := _feet() - feet
	assert_true(walked.length() > 5.0, "it did move (%s)" % walked)
	var moved := editor.schedule.get_global_rect().position - r.position
	assert_near(moved.x, walked.x, 1.01, "the button walks with it")
	assert_near(moved.y, walked.y, 1.01, "")
	assert_eq(editor.schedule.position, editor.schedule.position.round(), "on whole pixels: no shimmer")
	var before := _feet()
	var at := editor.schedule.get_global_rect().position
	cams.pan_screen(Vector2(30, -20))
	await tree.process_frame
	assert_near((editor.schedule.get_global_rect().position - at).x, (_feet() - before).x, 1.01, "and with the view")


func test_near_an_edge_or_a_button_it_moves_close_by() -> void:
	var safe := Rect2(16, 16, 688, 1248)
	var z := 1.5
	var got := WatchEditor.spot(Vector2(360, 700), z, safe, [] as Array[Rect2], "below")
	assert_eq(got[1], "below", "room under the feet: there")
	got = WatchEditor.spot(Vector2(360, 1250), z, safe, [] as Array[Rect2], "below")
	assert_eq(got[1], "above", "no room under it: above its head")
	var r := Rect2(got[0], WatchEditor.BUTTON)
	assert_true(safe.encloses(r), "on screen")
	assert_true(r.end.y <= 1250.0 - 76.0 * z, "clear of the Momo")
	var hire := Rect2(636, 670, 68, 68)
	got = WatchEditor.spot(Vector2(670, 640), z, safe, [hire] as Array[Rect2], "below")
	r = Rect2(got[0], WatchEditor.BUTTON)
	assert_ne(got[1], "below", "the Hire button is under it: somewhere else")
	assert_false(r.intersects(hire), "never on a HUD button")
	assert_true(safe.encloses(r), "and on screen")
	# Along the edge it does not flap: just enough room under the feet keeps
	# it above; clear room brings it back under.
	var edge := safe.end.y - WatchEditor.GAP - 4.0 * z - WatchEditor.BUTTON.y - 10.0
	got = WatchEditor.spot(Vector2(360, edge), z, safe, [] as Array[Rect2], "above")
	assert_eq(got[1], "above", "barely room under it: it stays above")
	got = WatchEditor.spot(Vector2(360, edge), z, safe, [] as Array[Rect2], "below")
	assert_eq(got[1], "below", "(the same room is enough to stay under)")
	got = WatchEditor.spot(Vector2(360, 900), z, safe, [] as Array[Rect2], "above")
	assert_eq(got[1], "below", "clear room: back under the feet")
	# The real button, for the real Momo: where spot() says.
	await _select_momo()
	var hud: Hud = main.get("hud")
	var want := WatchEditor.spot(_feet(), cams.camera.zoom.y, editor.safe_rect(), hud.occupied_rects(), editor.side)
	assert_eq(editor.schedule.position, want[0], "the button is where the rule puts it")


func test_schedule_mode_shows_what_it_works_and_what_it_could() -> void:
	var bs: BuildingSystem = sim.system(&"buildings")
	bs.place_instant("farm", Vector2i(2, 2))
	sim.execute({"type": "momo.watch", "momo": 1, "cells": [[0, 0]], "op": "add"})
	await _select_momo()
	_schedule()
	assert_true(editor.active, "Schedule mode")
	assert_true(editor.schedule.button_pressed, "the button says it is on")
	assert_eq(editor.count_label.text, "1 / 4 tiles", "how many of how many")
	var eligible := overlay.eligible().map(func(e: Array) -> Vector2i: return e[0])
	assert_false(eligible.has(Vector2i(0, 0)), "a watched tile is not outlined as a choice")
	assert_true(eligible.has(Vector2i(1, 1)) and eligible.has(Vector2i(2, 2)), "the island's other tiles are")
	for e: Array in overlay.eligible():
		if e[0] == Vector2i(2, 2):
			assert_true(e[1], "the farm is marked as a workplace")
	_tap(_cell(Vector2i(1, 1)))
	assert_true(overlay._pulse.has(Vector2i(1, 1)) and overlay._pulse[Vector2i(1, 1)][1], "added: a calm swell")
	_tap(_cell(Vector2i(1, 1)))
	assert_false(overlay._pulse[Vector2i(1, 1)][1], "taken away: it fades")
	_schedule()
	assert_false(editor.active, "Schedule again: done")
	assert_false(editor.schedule.button_pressed, "")


func test_a_new_hire_scheduled_on_a_farm_really_works_and_keeps_it() -> void:
	var bs: BuildingSystem = sim.system(&"buildings")
	var farm := bs.place_instant("farm", Vector2i(2, 2))
	(sim.system(&"economy") as EconomySystem).earn(500, "test")
	var r := sim.execute({"type": "momo.hire"})
	assert_true(r["ok"], "hired")
	var id := int(r["id"])
	await tree.process_frame
	assert_eq(int(momos.get_momo(id)["assigned"]), 0, "a new hire: no work")
	(main.get("selection") as SelectionController).select_momo(id)
	await tree.process_frame
	_schedule()
	_tap(_cell(Vector2i(2, 2)))
	assert_eq(momos.watched(id), [Vector2i(2, 2)] as Array[Vector2i], "the farm's tile is its schedule")
	sim.time_scale = 1.0
	sim.advance_ms(60000)
	assert_true(int(bs.get_building(farm)["completed"]) > 0, "and it really works the farm")
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(sim.save_state())))
	assert_eq((copy.system(&"momo") as MomoSystem).watched(id), [Vector2i(2, 2)] as Array[Vector2i], "saved")
	var before := int((copy.system(&"buildings") as BuildingSystem).get_building(farm)["completed"])
	copy.advance_ms(60000)
	assert_true(int((copy.system(&"buildings") as BuildingSystem).get_building(farm)["completed"]) > before, "and after loading it goes on")


func test_another_momo_tapped_in_schedule_mode_is_chosen() -> void:
	var other := (sim.system(&"momo") as MomoSystem).add_momo(Vector2(2.5, 2.5))
	await tree.process_frame
	await _select_momo()
	_schedule()
	assert_true(editor.active, "")
	var a := (main.get("momo_views") as MomoViews).actor(other)
	var body := cams.world_to_screen(a.global_position - Vector2(0, a.depth_lift) + Vector2(0, -35))
	_tap(body)
	var sel: SelectionController = main.get("selection")
	assert_eq(sel.selected_id, other, "the other Momo is selected")
	assert_false(editor.active, "Schedule mode ended safely")
	assert_eq(momos.watched(1), [] as Array[Vector2i], "nothing painted on the way")
	assert_eq(momos.watched(other), [] as Array[Vector2i], "")


func test_a_stroke_adds_what_its_first_tile_lacked() -> void:
	await _select_momo()
	_schedule()
	assert_true(editor.active, "editing")
	var cam_before := cams.camera.position
	_stroke([_cell(Vector2i(0, 0)), _cell(Vector2i(1, 0)), _cell(Vector2i(2, 0))])
	assert_eq(momos.watched(1), [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)] as Array[Vector2i], "three tiles added")
	assert_eq(cams.camera.position, cam_before, "the stroke did not pan")
	assert_eq(editor.count_label.text, "3 / 4 tiles", "the count says so")


func test_back_and_forth_never_flips_a_tile_twice() -> void:
	sim.execute({"type": "momo.watch", "momo": 1, "cells": [[0, 0], [1, 0], [2, 0]], "op": "add"})
	await _select_momo()
	_schedule()
	_stroke([_cell(Vector2i(0, 0)), _cell(Vector2i(1, 0)), _cell(Vector2i(0, 0)), _cell(Vector2i(1, 0))])
	assert_eq(momos.watched(1), [Vector2i(2, 0)] as Array[Vector2i], "started on a watched tile: the stroke removes, and only removes")


func test_capacity_stops_the_stroke_politely() -> void:
	await _select_momo()
	_schedule()
	_stroke([_cell(Vector2i(0, 0)), _cell(Vector2i(2, 0)), _cell(Vector2i(2, 2))])
	assert_eq(momos.watched(1).size(), 4, "four, the most it may watch")
	assert_eq((editor.last_result["refused"] as Dictionary).values(), ["err.watch_full"], "the rest are refused")
	assert_true(overlay._flash.size() > 0, "and flash red")


func test_a_second_finger_undoes_the_stroke_and_zooms() -> void:
	await _select_momo()
	_schedule()
	var zoom := cams.camera.zoom
	_touch(_cell(Vector2i(0, 0)), true, 0)
	for k in range(1, 5):
		_move(_cell(Vector2i(0, 0)).lerp(_cell(Vector2i(1, 0)), k / 4.0), 0)
	assert_eq(momos.watched(1).size(), 2, "mid-stroke: two tiles")
	_touch(_cell(Vector2i(2, 2)), true, 1)
	for k in range(1, 5):
		_move(_cell(Vector2i(2, 2)) + Vector2(30 * k, 30 * k), 1)
	_touch(_cell(Vector2i(1, 0)), false, 0)
	_touch(_cell(Vector2i(2, 2)) + Vector2(120, 120), false, 1)
	assert_eq(momos.watched(1).size(), 0, "a pinch began: the stroke is undone")
	assert_ne(cams.camera.zoom, zoom, "and the pinch zoomed")
	assert_true(editor.active, "still editing")


func test_taps_edit_one_tile_and_the_sea_or_schedule_ends() -> void:
	await _select_momo()
	_schedule()
	_tap(_cell(Vector2i(1, 1)))
	assert_eq(momos.watched(1), [Vector2i(1, 1)] as Array[Vector2i], "a tap adds a tile")
	_tap(_cell(Vector2i(1, 1)))
	assert_eq(momos.watched(1), [] as Array[Vector2i], "and again takes it away")
	_tap(_cell(Vector2i(6, 6)))
	assert_false(editor.active, "the sea ends Schedule mode")
	_schedule()
	_schedule()
	assert_false(editor.active, "and so does Schedule again")
	assert_eq(int(momos.get_momo(1)["assigned"]), 0, "no buildings watched: nothing assigned")


func test_outside_schedule_mode_a_drag_pans() -> void:
	await _select_momo()
	var cam_before := cams.camera.position
	# Over the sea beyond the island's far edge, clear of the Schedule button
	# (under the Momo).
	_stroke([_cell(Vector2i(0, -1)), _cell(Vector2i(2, -1))])
	assert_ne(cams.camera.position, cam_before, "not editing: the camera pans")
	assert_eq(momos.watched(1), [] as Array[Vector2i], "and no tile changes")


func test_right_mouse_pans_in_schedule_mode() -> void:
	await _select_momo()
	_schedule()
	var cam_before := cams.camera.position
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_RIGHT
	b.position = _cell(Vector2i(0, 0))
	b.pressed = true
	vp.push_input(b, true)
	for i in range(1, 6):
		var m := InputEventMouseMotion.new()
		m.position = b.position + Vector2(20 * i, 0)
		vp.push_input(m, true)
	b = b.duplicate()
	b.pressed = false
	vp.push_input(b, true)
	assert_ne(cams.camera.position, cam_before, "the right button pans")
	assert_eq(momos.watched(1), [] as Array[Vector2i], "without painting")


func test_the_momo_starts_on_new_tiles_at_once() -> void:
	var bs: BuildingSystem = sim.system(&"buildings")
	var farm := bs.place_instant("farm", Vector2i(2, 2))
	sim.time_scale = 1.0
	await _select_momo()
	_schedule()
	_tap(_cell(Vector2i(2, 2)))
	assert_eq(int(momos.get_momo(1)["assigned"]), farm, "the farm on the new tile: it heads there now")
	sim.advance_ms(40000)
	assert_true(int(bs.get_building(farm)["completed"]) > 0, "and works it")
