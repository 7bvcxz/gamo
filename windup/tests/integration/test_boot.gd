extends "res://tests/framework/test_case.gd"

## The real main scene: boots, logs a session, winds, resets the same way
## every time, and stops its clock while paused.

const MainScene := preload("res://scenes/main.tscn")

var main: WindupMain


func before_each() -> void:
	main = MainScene.instantiate()
	main.config = RunConfig.from_pairs({"seed": "5", "fresh": "1"})
	tree.root.add_child(main)
	await tree.process_frame


func after_each() -> void:
	main.queue_free()
	await tree.process_frame


func test_boot_logs_one_session() -> void:
	assert_eq(main.telemetry.count("session_start"), 1, "session_start")
	var e := main.telemetry.first("session_start")
	assert_eq(e["seed"], 5, "seed")
	assert_eq(e["variant"], "base", "variant")
	assert_eq(e["build"], main.version(), "build")
	assert_true(main.view.is_inside_tree(), "view in tree")


func test_wind_from_space_and_click() -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	Input.parse_input_event(key)
	var up := key.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await tree.process_frame
	assert_eq(main.winds, 1, "space winds once")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = main.view._layout_offset() + AtelierView.KEY_CENTER
	# Canvas coordinates: the headless window is 64x64 and stretched, so a
	# window-pixel position would land elsewhere (AGENTS.md, 2026-11-01).
	tree.root.push_input(click, true)
	var release := click.duplicate()
	release.pressed = false
	tree.root.push_input(release, true)
	await tree.process_frame
	assert_eq(main.winds, 2, "click on the key winds once")
	var miss := click.duplicate()
	miss.position = Vector2(5, 5)
	tree.root.push_input(miss, true)
	await tree.process_frame
	assert_eq(main.winds, 2, "a click off the key does nothing")
	assert_eq(main.telemetry.count("wind"), 2, "wind events")


func test_new_game_is_the_same_game() -> void:
	main.wind("dev")
	main.advance(3.0)
	main.new_game(5)
	var a := main.state()
	main.wind("dev")
	main.advance(1.0)
	main.new_game(5)
	var b := main.state()
	assert_eq(a["t"], 0.0, "clock reset")
	assert_eq(a["winds"], 0, "winds reset")
	assert_eq(a["events"], 1, "only session_start")
	a.erase("session")
	b.erase("session")
	assert_eq(JSON.stringify(a), JSON.stringify(b), "two resets give the same state")


func test_pause_stops_the_game_and_is_logged() -> void:
	main.advance(1.0)
	main.set_pause("focus", true)
	var t := main.clock.time
	main.advance(5.0)
	assert_eq(main.clock.time, t, "no time while paused")
	main.set_pause("focus", false)
	assert_eq(main.telemetry.count("pause"), 1, "pause logged")
	assert_eq(main.telemetry.count("resume"), 1, "resume logged")


func test_bridge_dev_queries() -> void:
	var bridge := WindupBridge.new()
	bridge.attach(main)
	var r: Dictionary = bridge.query("dev_wind", 3)
	assert_true(r["ok"], "dev_wind ok off the web")
	assert_eq(r["state"]["winds"], 3, "three winds")
	var lines: String = bridge.query("events", null)
	assert_eq(lines.split("\n").size(), 4, "session_start + 3 winds")
	assert_false(bridge.query("nope", null)["ok"], "unknown query refused")
	var k: Dictionary = bridge.query("key_point", null)
	assert_between(k["x"], 0.3, 0.7, "key point x is a fraction of the window")
	assert_between(k["y"], 0.2, 0.8, "key point y is a fraction of the window")
