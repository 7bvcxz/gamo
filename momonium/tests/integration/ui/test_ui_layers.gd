extends "res://tests/framework/test_case.gd"

## Step 82 (design/LAYERS82.md): one layer table for what draws over what
## and what a finger reaches -- the world under every piece of UI; the
## world's controls (the Schedule button, the building card, the build strip)
## under every panel; the HUD over the panels' scrim; Reset All Data above
## all. An open panel hides the world's controls, the passing news and the
## guide, and the island takes no input until it closes; the selection and
## the Schedule are kept.

const MainScene := preload("res://scenes/main.tscn")
## What opens from the HUD and is a panel.
const OPENERS: Array[StringName] = [&"settings", &"research", &"status", &"shop", &"mailbox"]

var main: Node
var sim: Simulation
var vp: Viewport
var editor: WatchEditor
var hud: Hud
var router: InputRouter


func before_each() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	sim = main.get("sim")
	sim.time_scale = 0.0
	with_starter_momo(sim)
	await tree.process_frame
	vp = main.get_viewport()
	editor = main.get("watch_editor")
	hud = main.get("hud")
	router = main.get("router")
	var world: WorldSystem = sim.system(&"world")
	for x in 3:
		for y in 3:
			world.add_land(Vector2i(x, y))
	LocaleService.apply("en")
	(main.get("selection") as SelectionController).select_momo(1)
	await tree.process_frame


func after_each() -> void:
	main.queue_free()
	await tree.process_frame


## A finger: the touch and the mouse press the browser makes of it (Buttons
## answer the mouse; the island ignores a mouse right after a touch).
func _tap(p: Vector2) -> void:
	for pressed: bool in [true, false]:
		var t := InputEventScreenTouch.new()
		t.position = p
		t.pressed = pressed
		vp.push_input(t, true)
		var m := InputEventMouseButton.new()
		m.button_index = MOUSE_BUTTON_LEFT
		m.position = p
		m.pressed = pressed
		vp.push_input(m, true)


## Where a control is, for push_input(..., true): canvas coordinates.
func _screen(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


func _tier(n: Node) -> String:
	var p := n.get_parent()
	while p != null and not String(p.name) in UiLayers.TIERS:
		p = p.get_parent()
	return String(p.name) if p != null else ""


func _frames() -> Array[PanelFrame]:
	return main.call("_frames")


func test_the_tiers_draw_in_the_table_order() -> void:
	var tiers: Dictionary = main.get("tiers")
	var root: Control = (tiers["Context"] as Control).get_parent()
	assert_eq(root.get_children().map(func(n: Node) -> String: return String(n.name)), Array(UiLayers.TIERS), "the UI root holds the tiers, bottom to top")
	var where := {
		"Context": [editor, main.get("panel"), main.get("build_strip"), main.get("camera_pad")],
		"Announce": [main.get("celebration"), hud.level_fx],
		"Hud": [hud, main.get("hire_menu")],
		"Guide": [main.get("tutorial"), main.get("tips")],
	}
	for t: String in where:
		for n: Node in where[t]:
			assert_eq(_tier(n), t, "%s in %s" % [n.name, t])
	for f: PanelFrame in _frames():
		assert_eq(_tier(f), "Panels", "%s in Panels" % f.name)
		# One CanvasLayer: tree order is draw order and touch order.
		assert_true(f.card.is_greater_than(editor.schedule), "%s's card over the Schedule button" % f.name)
		assert_true(hud.is_greater_than(f), "the HUD over %s" % f.name)
	var reset: ResetDialog = main.get("reset_dialog")
	var ui_layer: CanvasLayer = main.get_node("UI")
	assert_eq(ui_layer.layer, UiLayers.UI, "the UI's CanvasLayer")
	assert_eq(reset.layer, UiLayers.MODAL, "the confirmation's own CanvasLayer")
	assert_true(reset.layer > ui_layer.layer, "the confirmation above every piece of UI")
	assert_true((main.get_node("Background") as CanvasLayer).layer < 0, "the ocean under the world")
	var fx: FeedbackFx = main.get("feedback_fx")
	assert_eq(fx.z_index, UiLayers.Z_FX, "world effects by the table's z")
	assert_true(fx.get_canvas_layer_node() == null, "world effects on the world's canvas, under the UI's CanvasLayer")


func test_an_open_panel_hides_the_world_controls_and_keeps_the_selection() -> void:
	for action: StringName in OPENERS:
		assert_true(editor.schedule.is_visible_in_tree(), "%s: the Schedule button shows before" % action)
		var at := _screen(editor.schedule)
		main.call("_on_hud_action", action)
		await tree.process_frame
		var layers: Dictionary = main.call("_layers_info")
		assert_true(bool(layers["busy"]), "%s: busy" % action)
		assert_false(editor.schedule.is_visible_in_tree(), "%s: the Schedule button gives way" % action)
		assert_false((main.get("panel") as Control).is_visible_in_tree(), "%s: the building card too" % action)
		assert_false((main.get("tutorial") as Control).is_visible_in_tree() and (main.get("tutorial") as Tutorial).running, "%s: and the guide" % action)
		assert_eq(editor.momo, 1, "%s: the Momo stays selected" % action)
		# A finger where the Schedule button was: the panel or its scrim takes it.
		_tap(at)
		await tree.process_frame
		assert_false(editor.active, "%s: no Schedule through the panel" % action)
		assert_eq(editor.momo, 1, "%s: still selected" % action)
		main.call("_close_frames")
		await tree.process_frame
		assert_false(bool((main.call("_layers_info") as Dictionary)["busy"]), "%s: closed, not busy" % action)
		assert_true(editor.schedule.is_visible_in_tree(), "%s: closed, the Schedule button is back" % action)
	_tap(_screen(editor.schedule))
	await tree.process_frame
	assert_true(editor.active, "and it works again")


func test_the_island_takes_no_input_while_busy() -> void:
	var taps := [0]
	router.tapped.connect(func(_s: Vector2, _w: Vector2) -> void: taps[0] += 1)
	var cams: CameraController = main.get("cameras")
	var p := vp.get_visible_rect().size * Vector2(0.5, 0.85)
	# Whatever reaches past the UI while a panel is open is dropped by the
	# router itself: a tap, a pinch, a wheel.
	main.call("_on_hud_action", &"settings")
	await tree.process_frame
	var zoom := cams.camera.zoom
	for pressed: bool in [true, false]:
		var t := InputEventScreenTouch.new()
		t.position = p
		t.pressed = pressed
		router._unhandled_input(t)
	var g := InputEventMagnifyGesture.new()
	g.factor = 1.5
	g.position = p
	router._unhandled_input(g)
	assert_eq(taps[0], 0, "no tap on the island while a panel is open")
	assert_eq(cams.camera.zoom, zoom, "no pinch zoom either")
	main.call("_close_frames")
	await tree.process_frame
	for pressed: bool in [true, false]:
		var t := InputEventScreenTouch.new()
		t.position = p
		t.pressed = pressed
		router._unhandled_input(t)
	assert_eq(taps[0], 1, "closed: the island takes taps again")


func test_a_panel_opening_mid_stroke_puts_the_stroke_back() -> void:
	var cams: CameraController = main.get("cameras")
	var proj: IsoProjection = main.get("projection")
	editor.begin_edit()
	var before: Array = (sim.system(&"momo") as MomoSystem).get_momo(1).get("watch", []).duplicate()
	var a := cams.world_to_screen(proj.cell_center(Vector2i(0, 0)))
	var b := cams.world_to_screen(proj.cell_center(Vector2i(2, 2)))
	var t := InputEventScreenTouch.new()
	t.position = a
	t.pressed = true
	router._unhandled_input(t)
	for i in 6:
		var d := InputEventScreenDrag.new()
		d.position = a.lerp(b, (i + 1) / 6.0)
		router._unhandled_input(d)
	assert_eq(router.mode, InputRouter.Mode.DRAGGING, "a Schedule stroke in progress")
	# Something opens a panel (a promotion, a letter) under the finger.
	(main.get("settings_frame") as PanelFrame).open()
	await tree.process_frame
	assert_eq(router.mode, InputRouter.Mode.IDLE, "the finger is let go")
	assert_eq((sim.system(&"momo") as MomoSystem).get_momo(1).get("watch", []), before, "the half-drawn stroke is put back")


func test_a_wheel_on_the_scrim_neither_closes_nor_zooms() -> void:
	var cams: CameraController = main.get("cameras")
	main.call("_on_hud_action", &"status")
	await tree.process_frame
	var frame: PanelFrame = main.get("status_frame")
	var card := frame.card_rect()
	var outside := Vector2(card.get_center().x, minf(card.end.y + 40.0, frame.size.y - 4.0))
	var zoom := cams.camera.zoom
	for pressed: bool in [true, false]:
		var w := InputEventMouseButton.new()
		w.button_index = MOUSE_BUTTON_WHEEL_UP
		w.position = outside
		w.pressed = pressed
		vp.push_input(w, true)
	await tree.process_frame
	assert_true(frame.visible, "a wheel on the scrim leaves the panel open")
	assert_eq(cams.camera.zoom, zoom, "and the island where it was")
	_tap(outside)
	await tree.process_frame
	assert_false(frame.visible, "a tap on the scrim closes it")


func test_reset_confirmation_is_above_everything() -> void:
	main.call("_on_hud_action", &"settings")
	await tree.process_frame
	var reset: ResetDialog = main.get("reset_dialog")
	reset.open()
	await tree.process_frame
	assert_true(bool((main.call("_layers_info") as Dictionary)["busy"]), "busy under the confirmation")
	# A finger on the HUD's Research button: the confirmation's dim is on top.
	_tap(_screen(hud.buttons[&"research"]))
	await tree.process_frame
	assert_false((main.get("research_frame") as PanelFrame).visible, "the HUD under the confirmation cannot be pressed")
	assert_false(reset.visible, "the dim cancels it")
	assert_true((main.get("settings_frame") as PanelFrame).visible, "Settings stays")
	# Escape closes the top thing only.
	reset.open()
	await tree.process_frame
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	vp.push_input(esc)
	await tree.process_frame
	assert_false(reset.visible, "Escape: the confirmation goes")
	assert_true((main.get("settings_frame") as PanelFrame).visible, "Settings under it stays")
	vp.push_input(esc)
	await tree.process_frame
	assert_false((main.get("settings_frame") as PanelFrame).visible, "Escape again: Settings goes")


func test_a_level_banner_waits_for_the_panel() -> void:
	var prog: ProgressionSystem = sim.system(&"progression")
	while prog.level < 20:
		prog.add_exp(prog.next_level_exp() - prog.experience, "test")
	var banner: TierCelebration = main.get("celebration")
	banner.set("_t", -1.0)
	banner.visible = false
	var level := 0
	for lv in range(2, 21):
		if not (sim.system(&"buildings") as BuildingSystem).opened_at(lv).is_empty():
			level = lv
			break
	assert_true(level > 0, "a level that opens a building")
	main.call("_on_hud_action", &"research")
	await tree.process_frame
	main.call("_celebrate_level", level)
	assert_false(banner.playing(), "not over the open panel")
	main.call("_close_frames")
	await tree.process_frame
	assert_true(banner.playing(), "shown when it closes")
	assert_true(banner.is_visible_in_tree(), "and seen")


func test_the_guide_gives_way_and_comes_back() -> void:
	var tutorial: Tutorial = main.get("tutorial")
	tutorial.start()
	await tree.process_frame
	assert_true(tutorial.is_visible_in_tree(), "the tutorial shows")
	main.call("_on_hud_action", &"status")
	await tree.process_frame
	assert_false(tutorial.is_visible_in_tree(), "not over the panel")
	assert_true(tutorial.running, "still running")
	main.call("_close_frames")
	await tree.process_frame
	assert_true(tutorial.is_visible_in_tree(), "back when it closes")
