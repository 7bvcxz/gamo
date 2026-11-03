extends "res://tests/framework/test_case.gd"

## Each variant through the real scene: its own save, its build id, and
## a minute of play without errors.

const MainScene := preload("res://scenes/main.tscn")


func _start(variant: String) -> WindupMain:
	var m: WindupMain = MainScene.instantiate()
	m.config = RunConfig.from_pairs({"fresh": "1", "variant": variant})
	tree.root.add_child(m)
	return m


func test_each_variant_plays_a_minute() -> void:
	for v: String in ["base", "a", "b", "c"]:
		var m := _start(v)
		await tree.process_frame
		m.set_process(false)
		assert_eq(m.build_id(), "%s+%s" % [m.version(), v], "build id names the variant")
		assert_eq(m.telemetry.first("session_start")["variant"], v, "telemetry names the variant")
		if v == "base":
			assert_eq(m.store.path, SaveStore.PATH, "base keeps the original save")
		else:
			assert_true(m.store.path.contains("_" + v), "%s has its own save" % v)
		for i in 300:
			m.press("click")
			m.advance(0.1)
			if i % 25 == 24:
				m.release("click")
				m.advance(0.3)
		m.release("click")
		m.advance(5.0)
		assert_true(m.atelier.awake >= 1, "%s: a doll woke in a minute of play (%d)" % [v, m.atelier.awake])
		assert_near(m.atelier.accounted_energy(), m.atelier.energy, 1e-6, "%s: accounting" % v)
		if v == "b":
			assert_false(m.view.dolls[m.atelier.doll_count() - 1].visible, "B: the last sleeper is under its sheet")
			assert_true(m.view.dolls[0].visible, "B: the first is revealed")
		if v == "c":
			assert_true(m.telemetry.count("kick") >= 1, "C: a kick")
		if v == "a":
			assert_true(m.telemetry.count("release") >= 1, "A: a release")
		m.queue_free()
		await tree.process_frame
