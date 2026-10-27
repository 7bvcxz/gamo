extends "res://tests/framework/test_case.gd"

## Status > Momo (Step 60): with the Momo card gone, every Momo has a row --
## what it is doing, its tiles, its route (tapped to the next way, the island
## showing the stops) and whether the manager may move it; its name finds it
## on the island. Built once per Momo set: refreshing never frees a button.

const MainScene := preload("res://scenes/main.tscn")

var main: Node
var sim: Simulation
var momos: MomoSystem
var frame: PanelFrame
var list: MomoListView
var vp: Viewport


func before_each() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	sim = main.get("sim")
	sim.time_scale = 0.0
	momos = sim.system(&"momo")
	frame = main.get("status_frame")
	list = main.get("momo_list")
	vp = main.get_viewport()
	LocaleService.apply("en")
	await tree.process_frame


func after_each() -> void:
	main.queue_free()
	await tree.process_frame


func _open() -> void:
	main.call("_on_hud_action", &"status")
	frame.show_tab(frame.tabs.size() - 1)
	await tree.process_frame


func _click(c: Control) -> void:
	var p := c.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var m := InputEventMouseButton.new()
		m.button_index = MOUSE_BUTTON_LEFT
		m.position = p
		m.pressed = pressed
		vp.push_input(m, true)


func test_no_momo_yet_says_how_to_get_one() -> void:
	await _open()
	assert_eq(frame.current_view(), list, "the Momo tab")
	assert_eq(frame.tabs[-1]["button"].text, "Momo", "named Momo")
	assert_true(list.empty_label.visible, "no Momo yet")
	assert_eq(list.empty_label.text, "No Momo yet. Hire one with Hire, on the right.", "where to get one")
	assert_true(list.rows.is_empty(), "")


func test_a_row_per_momo_with_what_it_does() -> void:
	with_starter_momo(sim)
	var second := momos.add_momo(Vector2(0.5, 0.5))
	var bs: BuildingSystem = sim.system(&"buildings")
	var farm := bs.place_instant("farm", Vector2i(1, 0))
	sim.execute({"type": "momo.assign", "momo": 1, "building": farm})
	await _open()
	assert_eq(list.rows.keys(), [1, second], "one row each")
	assert_false(list.empty_label.visible, "")
	assert_eq((list.rows[1]["tiles"] as Label).text, "1 / 4 tiles", "its tiles")
	assert_true((list.rows[1]["status"] as Label).text.contains("Farm"), "working or heading to the farm (%s)" % (list.rows[1]["status"] as Label).text)
	assert_eq((list.rows[second]["status"] as Label).text, "Free time", "the other is free")
	assert_false((list.rows[second]["route"] as Button).visible, "no tiles, no route")
	assert_false((list.rows[second]["pin"] as Button).visible, "not placed, nothing to keep")
	var button: Button = list.rows[1]["route"]
	for i in 5:
		frame.refresh()
	assert_true(is_instance_valid(button) and button == list.rows[1]["route"], "refreshing keeps the same buttons")


func test_the_route_button_and_its_preview() -> void:
	with_starter_momo(sim)
	var bs: BuildingSystem = sim.system(&"buildings")
	var a := bs.place_instant("lumberyard", Vector2i(0, 0))
	var b := bs.place_instant("lumberyard", Vector2i(1, 1))
	sim.execute({"type": "momo.watch", "momo": 1, "cells": [[0, 0], [1, 1]], "op": "add"})
	(main.get("selection") as SelectionController).select_momo(1)
	var overlay: WatchOverlay = main.get("watch_overlay")
	assert_eq(overlay.route().size(), 2, "the island shows its route: two stops")
	assert_true(overlay.route().has(a) and overlay.route().has(b), "")
	await _open()
	var route: Button = list.rows[1]["route"]
	assert_eq(route.text, "Route: Nearest first", "the row names its route")
	_click(route)
	assert_eq(momos.route_of(1), "rows", "a tap: the next way")
	assert_eq(route.text, "Route: Row by row", "")
	assert_false((list.rows[1]["compare"] as Label).visible, "nothing to compare yet: no line (Step 50)")
	for i in 3:
		list.next_route(1)
	assert_eq(momos.route_of(1), "order", "zigzag, zone, then the player's own order (Step 61)")
	list.refresh()
	assert_eq(route.text, "Route: In your order", "")
	list.next_route(1)
	assert_eq(momos.route_of(1), "nearest", "and round again (smart needs its research)")


func test_its_name_finds_it_on_the_island() -> void:
	with_starter_momo(sim)
	await _open()
	_click(list.rows[1]["name"])
	await tree.process_frame
	assert_false(frame.visible, "the panel goes")
	var sel: SelectionController = main.get("selection")
	assert_eq(sel.kind, "momo", "the Momo is selected")
	assert_eq(sel.selected_id, 1, "")
	var editor: WatchEditor = main.get("watch_editor")
	assert_true(editor.schedule.is_visible_in_tree(), "its Schedule button under it")
	var a := (main.get("momo_views") as MomoViews).actor(1)
	var cams: CameraController = main.get("cameras")
	var at := cams.world_to_screen(a.global_position - Vector2(0, a.depth_lift))
	var screen := editor.get_viewport_rect().size
	assert_true(Rect2(Vector2.ZERO, screen).has_point(at), "and on screen")
