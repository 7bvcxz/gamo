extends "res://tests/framework/test_case.gd"

## The 15-minute test (Step 99, `?t15=1`) in the Lab's frame: a play-time bar
## along the top with 3- and 15-minute notches and a short note at each; the
## run's checkpoints (0, 3, 7, 10, 15 minutes) kept as a record -- with what
## each variant is (C: pickaxe, breaks, taps; E: level, deliveries, what is on
## the belt) -- written as each is reached and when the run ends. Without the
## option the frame is as it was: no bar, nothing kept.

const MainScene := preload("res://lab/main.tscn")

var app: LabApp


func before_each() -> void:
	tree.root.size = Vector2i(720, 1280)
	app = MainScene.instantiate() as LabApp
	tree.root.add_child(app)
	await tree.process_frame


func after_each() -> void:
	app.route["t15"] = false
	app.queue_free()
	tree.root.size = Vector2i(720, 1280)
	tree.paused = false
	await tree.process_frame


func _open(id: String, t15: bool) -> LabHost:
	app.route["t15"] = t15
	app.open(id)
	app.host.set_process(false)
	await tree.process_frame
	return app.host


func test_off_by_default_nothing_shown_or_kept() -> void:
	var host := await _open("rock-plus", false)
	assert_false(host.t15_bar.visible, "no bar")
	host.step(200.0)
	assert_eq(host.t15_saves, 0, "nothing kept")
	assert_eq(String(host.state()["t15"]["note"]), "", "no note")


func test_the_bar_the_notes_and_the_checkpoints() -> void:
	var host := await _open("tycoon-plus", true)
	assert_true(host.t15_bar.visible, "the bar along the top")
	assert_true(host.t15_bar.get_global_rect().end.y <= host.back_button.get_global_rect().position.y, "above the frame's buttons")
	host.step(0.1)
	var saves := host.t15_saves
	assert_true(saves >= 1, "the start kept")
	host.step(179.0)
	assert_eq(String(host.state()["t15"]["note"]), "", "no note before 3:00")
	host.step(1.5)
	assert_true(String(host.state()["t15"]["note"]).begins_with("3 minutes"), "a note at 3:00")
	assert_true(host.t15_saves > saves, "3:00 kept")
	host.step(720.0)
	assert_true(String(host.state()["t15"]["note"]).begins_with("15 minutes"), "a note at 15:00")
	var r := host.t15_record()
	assert_eq((r["at"] as Dictionary).keys(), ["0", "3", "7", "10", "15"], "all five checkpoints")
	assert_eq(String(r["id"]), "tycoon-plus", "which")
	assert_eq(String(r["base"]), "tycoon", "and its track")
	assert_true(String(r["key"]).begins_with("tycoon-plus|"), "a key of its own")
	var at15: Dictionary = r["at"]["15"]
	for k: String in ["active_s", "actions", "actions_per_minute", "upgrades", "visible_upgrades", "rewards", "idle_count", "longest_idle_s", "fps", "probe"]:
		assert_true(at15.has(k), "15:00 has %s" % k)
	assert_near(float(at15["active_s"]), 900.0, 0.3, "taken at 15:00")
	for k: String in ["level", "delivered", "on_belt", "deliveries_per_min", "earned"]:
		assert_true((at15["probe"] as Dictionary).has(k), "E+ at 15:00 says %s" % k)
	assert_true(int(at15["probe"]["delivered"]) > 0, "the line ran")


func test_each_variant_says_what_it_is() -> void:
	var wants := {"rock": ["pick", "breaks", "taps", "damage", "earned"], "rock-plus": ["pick", "breaks", "taps", "damage", "earned"],
		"tycoon": ["level", "delivered", "on_belt", "deliveries_per_min", "earned"], "tycoon-plus": ["level", "delivered", "on_belt", "deliveries_per_min", "earned"]}
	for id: String in wants:
		var host := await _open(id, true)
		host.step(200.0)
		var p: Dictionary = host.t15_record()["at"]["3"]["probe"]
		for k: String in wants[id]:
			assert_true(p.has(k), "%s's probe has %s" % [id, k])
		app.back()
		await tree.process_frame


func test_kept_when_the_run_ends() -> void:
	var host := await _open("rock", true)
	host.step(30.0)
	var saves := host.t15_saves
	host.restart()
	assert_eq(host.t15_saves, saves + 1, "a restart keeps the run that ends")
	assert_eq(host.session.run, 2, "and a new run begins")
	saves = host.t15_saves
	host.step(10.0)
	assert_true(host.t15_saves > saves, "its start kept too")
