extends "res://tests/framework/test_case.gd"

## Editing a Momo's watched tiles with a real finger and a mouse: tap the
## Momo (its tiles light up, a pencil appears), pencil, then strokes decided by
## their first tile -- never flipping a tile twice -- within the Momo's
## capacity; two fingers still zoom and undo the stroke; the sea or the check
## ends editing; outside editing a drag pans as always.

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


func test_selecting_a_momo_shows_its_tiles_and_a_pencil() -> void:
	var farm := (sim.system(&"buildings") as BuildingSystem).place_instant("farm", Vector2i(1, 0))
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	await _select_momo()
	assert_eq(overlay.tinted(), [Vector2i(1, 0)] as Array[Vector2i], "its farm's tile is tinted")
	assert_true(editor.pencil.is_visible_in_tree(), "a pencil")
	# Step 45 (blind playtest): the pencil waits by the Momo's card, still,
	# not above a head that walks away from the finger.
	var card := (main.get("momo_panel") as MomoPanel).get_global_rect()
	await tree.process_frame
	var at := editor.pencil.get_global_rect()
	assert_true(at.end.y <= card.position.y + 1.0 and absf(at.position.x - card.position.x) < 40.0, "just above the Momo's card (%s, card %s)" % [at, card])
	var actor := (main.get("momo_views") as MomoViews).actor(1)
	var before := at.position
	actor.position += Vector2(120, 40)
	editor._place()
	assert_eq(editor.pencil.get_global_rect().position, before, "and it holds still when the Momo moves")
	assert_false(editor.active, "not editing yet")
	(main.get("selection") as SelectionController).deselect()
	assert_eq(overlay.tinted(), [] as Array[Vector2i], "deselected: no tint")
	assert_false(editor.visible, "no pencil")


func test_a_stroke_adds_what_its_first_tile_lacked() -> void:
	await _select_momo()
	editor.pencil.pressed.emit()
	assert_true(editor.active, "editing")
	var cam_before := cams.camera.position
	_stroke([_cell(Vector2i(0, 0)), _cell(Vector2i(1, 0)), _cell(Vector2i(2, 0))])
	assert_eq(momos.watched(1), [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)] as Array[Vector2i], "three tiles added")
	assert_eq(cams.camera.position, cam_before, "the stroke did not pan")
	assert_eq(editor.count_label.text, "3 / 4 tiles", "the count says so")


func test_back_and_forth_never_flips_a_tile_twice() -> void:
	sim.execute({"type": "momo.watch", "momo": 1, "cells": [[0, 0], [1, 0], [2, 0]], "op": "add"})
	await _select_momo()
	editor.pencil.pressed.emit()
	_stroke([_cell(Vector2i(0, 0)), _cell(Vector2i(1, 0)), _cell(Vector2i(0, 0)), _cell(Vector2i(1, 0))])
	assert_eq(momos.watched(1), [Vector2i(2, 0)] as Array[Vector2i], "started on a watched tile: the stroke removes, and only removes")


func test_capacity_stops_the_stroke_politely() -> void:
	await _select_momo()
	editor.pencil.pressed.emit()
	_stroke([_cell(Vector2i(0, 0)), _cell(Vector2i(2, 0)), _cell(Vector2i(2, 2))])
	assert_eq(momos.watched(1).size(), 4, "four, the most it may watch")
	assert_eq((editor.last_result["refused"] as Dictionary).values(), ["err.watch_full"], "the rest are refused")
	assert_true(overlay._flash.size() > 0, "and flash red")


func test_a_second_finger_undoes_the_stroke_and_zooms() -> void:
	await _select_momo()
	editor.pencil.pressed.emit()
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


func test_taps_edit_one_tile_and_the_sea_or_check_ends() -> void:
	await _select_momo()
	editor.pencil.pressed.emit()
	_tap(_cell(Vector2i(1, 1)))
	assert_eq(momos.watched(1), [Vector2i(1, 1)] as Array[Vector2i], "a tap adds a tile")
	_tap(_cell(Vector2i(1, 1)))
	assert_eq(momos.watched(1), [] as Array[Vector2i], "and again takes it away")
	_tap(_cell(Vector2i(6, 6)))
	assert_false(editor.active, "the sea ends editing")
	editor.pencil.pressed.emit()
	editor.pencil.pressed.emit()
	assert_false(editor.active, "and so does the check")
	assert_eq(int(momos.get_momo(1)["assigned"]), 0, "no buildings watched: nothing assigned")


func test_outside_editing_a_drag_pans() -> void:
	await _select_momo()
	var cam_before := cams.camera.position
	# Over the sea beyond the island's far edge, clear of the pencil (which
	# waits by the Momo card at the bottom since Step 45).
	_stroke([_cell(Vector2i(0, -1)), _cell(Vector2i(2, -1))])
	assert_ne(cams.camera.position, cam_before, "not editing: the camera pans")
	assert_eq(momos.watched(1), [] as Array[Vector2i], "and no tile changes")


func test_right_mouse_pans_while_editing() -> void:
	await _select_momo()
	editor.pencil.pressed.emit()
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
	editor.pencil.pressed.emit()
	_tap(_cell(Vector2i(2, 2)))
	assert_eq(int(momos.get_momo(1)["assigned"]), farm, "the farm on the new tile: it heads there now")
	sim.advance_ms(40000)
	assert_true(int(bs.get_building(farm)["completed"]) > 0, "and works it")


func test_the_route_button_and_its_preview() -> void:
	var bs: BuildingSystem = sim.system(&"buildings")
	var a := bs.place_instant("lumberyard", Vector2i(0, 0))
	var b := bs.place_instant("lumberyard", Vector2i(2, 2))
	sim.execute({"type": "momo.watch", "momo": 1, "cells": [[0, 0], [2, 2]], "op": "add"})
	await _select_momo()
	var panel: MomoPanel = main.get("momo_panel")
	panel.refresh()
	assert_eq(panel.route_button.text, "Route: Nearest first", "the panel names its route")
	assert_eq(overlay.route().size(), 2, "and the island shows it: two stops")
	assert_true(overlay.route().has(a) and overlay.route().has(b), "")
	var p := panel.route_button.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var m := InputEventMouseButton.new()
		m.button_index = MOUSE_BUTTON_LEFT
		m.position = p
		m.pressed = pressed
		vp.push_input(m, true)
	panel.refresh()
	assert_eq(momos.route_of(1), "rows", "a tap: the next way")
	assert_eq(panel.route_button.text, "Route: Row by row", "")
	assert_eq(panel.compare_label.text, "Comparing: a few days are needed on each side", "and it will compare before and after")
	for i in 3:
		panel.next_route()
	assert_eq(momos.route_of(1), "nearest", "zigzag, zone, and round again (smart needs its research)")
