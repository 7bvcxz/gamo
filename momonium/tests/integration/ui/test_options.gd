extends "res://tests/framework/test_case.gd"

## Settings for comfort and access: bigger text and buttons, a 30 fps
## battery saver, buttons to move the view instead of dragging, tooltips for
## a mouse, and one-time tips that can be turned off or shown again.

const MainScene := preload("res://scenes/main.tscn")

var main: Node
var sim: Simulation


func before_each() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	sim = main.get("sim")
	sim.time_scale = 0.0
	LocaleService.apply("en")


func after_each() -> void:
	var settings: SettingsStore = main.get("settings")
	settings.set_value("ui_scale", 1.0)
	settings.set_value("low_power", false)
	settings.set_value("camera_buttons", false)
	main.call("apply_options")
	main.queue_free()
	await tree.process_frame


func test_bigger_text_and_buttons() -> void:
	var before := main.get_viewport().get_visible_rect().size
	main.get("settings_view").option_changed.emit("ui_scale", 1.2)
	await tree.process_frame
	assert_near(tree.root.content_scale_factor, 1.2, 0.001, "the whole screen scaled")
	var after := main.get_viewport().get_visible_rect().size
	assert_true(after.x < before.x, "so everything is drawn larger (%s -> %s)" % [before, after])
	main.get("settings_view").option_changed.emit("ui_scale", 9.0)
	assert_near(tree.root.content_scale_factor, 1.25, 0.001, "never past 1.25")


func test_battery_saver() -> void:
	main.get("settings_view").option_changed.emit("low_power", true)
	assert_eq(Engine.max_fps, 30, "30 fps")
	main.get("settings_view").option_changed.emit("low_power", false)
	assert_eq(Engine.max_fps, 0, "back to the display's rate")


func test_buttons_instead_of_dragging() -> void:
	var pad: CameraPad = main.get("camera_pad")
	assert_false(pad.visible, "off by default")
	main.get("settings_view").option_changed.emit("camera_buttons", true)
	assert_true(pad.visible, "on when chosen")
	var cams: CameraController = main.get("cameras")
	var p := cams.camera.position
	(pad.buttons["left"] as Button).pressed.emit()
	assert_ne(cams.camera.position, p, "an arrow moves the view")
	var z := cams.camera.zoom
	(pad.buttons["in"] as Button).pressed.emit()
	assert_true(cams.camera.zoom.x > z.x, "plus zooms in")
	var screen := main.get_viewport().get_visible_rect()
	assert_true(screen.encloses(pad.get_global_rect()), "on screen")


func test_tooltips_for_a_mouse() -> void:
	var hud: Hud = main.get("hud")
	assert_eq(hud.buttons[&"research"].tooltip_text, "Research", "a HUD button names itself")
	(main.get("build_strip") as BuildStrip).show_for(Vector2i(1, 1))
	assert_eq((main.get("build_strip") as BuildStrip).buttons["farm"].tooltip_text, "Farm · $10", "a choice says what it costs")


func test_tips_once_and_again() -> void:
	var tips: Tips = main.get("tips")
	tips.allowed = true
	var settings: SettingsStore = main.get("settings")
	settings.set_value("tips_seen", [])
	(sim.system(&"economy") as EconomySystem).earn(100, "test")
	main.call("_check_land_tip", 2.0)
	assert_eq(tips.tip, "land", "money for land: the sea tip")
	assert_true(tips.text.text.contains("$50"), "with the price (%s)" % tips.text.text)
	assert_eq(tips.bubble.mouse_filter, Control.MOUSE_FILTER_IGNORE, "it lets taps through")
	tips.dismiss()
	main.call("_check_land_tip", 2.0)
	assert_eq(tips.tip, "", "once only")
	(main.get("selection") as SelectionController).select_momo(1)
	await tree.process_frame
	await tree.process_frame
	assert_eq(tips.tip, "watch", "a Momo selected: the pencil tip")
	tips.dismiss()
	settings.set_value("tips", false)
	tips.replay()
	main.call("_check_land_tip", 2.0)
	assert_eq(tips.tip, "", "tips off: none")
	settings.set_value("tips", true)
	main.call("_check_land_tip", 2.0)
	assert_eq(tips.tip, "land", "shown again after 'show the tips again'")
	tips.dismiss()
