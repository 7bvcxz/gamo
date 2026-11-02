extends "res://tests/framework/test_case.gd"

## Experiment D in the Lab's frame with real input: the field grows through
## its stages and waits ripe; a press before then is refused (and counted);
## Harvest All pays exactly once and the field starts over from seeds; two
## fingers or a double tap never pay twice; Bigger Field grows the field;
## time ripe and unharvested is counted.

const MainScene := preload("res://lab/main.tscn")
const H := preload("res://tests/integration/lab_helpers.gd")

var app: LabApp
var host: LabHost
var field: LabExperiment


func before_each() -> void:
	tree.root.size = Vector2i(720, 1280)
	app = MainScene.instantiate() as LabApp
	tree.root.add_child(app)
	await tree.process_frame
	app.open("harvest")
	await tree.process_frame
	await tree.process_frame
	host = app.host
	host.set_process(false)
	host.restart()
	field = host.experiment


func after_each() -> void:
	app.queue_free()
	tree.paused = false
	await tree.process_frame


func _s() -> Dictionary:
	return field.state()


func test_it_grows_through_its_stages_and_waits() -> void:
	assert_true(LabRegistry.playable("harvest"), "the tile says PLAY")
	var stages: Array[int] = []
	for i in 30:
		host.step(0.5)
		var st := int(_s()["stage"])
		if stages.is_empty() or stages[stages.size() - 1] != st:
			stages.append(st)
	assert_eq(stages, [0, 1, 2, 3] as Array[int], "seeds, sprouts, leaves, ripe")
	assert_true(bool(_s()["ripe"]), "ripe after 14 s")
	host.step(30.0)
	assert_true(bool(_s()["ripe"]), "and still waiting 30 s later: nothing harvests itself")
	assert_eq(int(_s()["coins"]), 0, "no coins without the harvest")
	assert_between(float(_s()["ready_wait_s"]), 30.9, 31.1, "the time it waited ripe is counted")


func test_a_press_before_ripe_is_refused() -> void:
	host.step(7.0)
	assert_eq(String(_s()["button"]), "growing", "the button shows the growth")
	await H.touch(tree, H.centre(host.action_button))
	assert_eq(int(_s()["coins"]), 0, "nothing paid")
	assert_eq(int(host.session.counts.get("button_refused", 0)), 1, "the early press is recorded")
	assert_false(bool(_s()["ripe"]), "the field keeps growing")


func test_harvest_all_pays_once_and_starts_over() -> void:
	host.step(14.1)
	assert_eq(String(_s()["button"]), "harvest", "Harvest All")
	await H.touch(tree, H.centre(host.action_button))
	var s := _s()
	assert_eq(int(s["coins"]), 16, "sixteen coins, once")
	assert_eq(int(s["harvests"]), 1, "one harvest")
	assert_false(bool(s["ripe"]), "not ripe any more")
	assert_eq(int(s["stage"]), 0, "seeds again")
	assert_near(float(s["progress"]), 0.0, 0.0001, "growing from the start")
	# A second finger, a double tap: never a second payout.
	await H.touch(tree, H.centre(host.action_button))
	await H.click(tree, H.centre(host.action_button))
	assert_eq(int(_s()["harvests"]), 1, "still one harvest")
	var names: Array = host.session.milestones.map(func(m: Dictionary) -> String: return String(m["name"]))
	assert_eq(names, ["harvest"], "one harvest recorded")
	assert_eq(int(host.session.milestones[0]["coins"]), 16, "with its coins")


func test_bigger_field() -> void:
	host.step(14.1)
	host.press_action()
	assert_eq(String(_s()["button"]), "rest", "the button rests a moment after the burst")
	host.press_action()
	assert_eq(int(_s()["level"]), 0, "a quick second tap buys nothing")
	host.step(0.7)
	assert_eq(String(_s()["button"]), "upgrade", "then Bigger Field when it can pay")
	await H.touch(tree, H.centre(host.action_button))
	var s := _s()
	assert_eq(int(s["level"]), 1, "a bigger field")
	assert_eq(int(s["plants"]), 12, "twelve plants")
	assert_eq(int(s["payout"]), 24, "the next harvest pays 24")
	assert_eq(int(s["coins"]), 0, "16 - 16")
	host.step(14.1)
	host.press_action()
	assert_eq(int(_s()["coins"]), 24, "and it does")
	assert_eq(int(host.session.counts.get("tap_after_harvest", 0)), 1, "the quick tap was recorded, not obeyed")


func test_three_minutes() -> void:
	var t := 0.0
	var ripe_since := -1.0
	while t < 180.0:
		host.step(0.1)
		t += 0.1
		var s := _s()
		if bool(s["ripe"]):
			if ripe_since < 0.0:
				ripe_since = t
			if t - ripe_since >= 1.0:
				host.press_action()
				ripe_since = -1.0
		elif String(s["button"]) == "upgrade":
			host.press_action()
	var sim := HarvestLevels.simulate(180.0, 1.0)
	# The bot looks every 0.1 s, so each cycle may run a step longer.
	assert_between(float(_s()["harvests"]), float((sim["harvests"] as Array).size() - 1), float((sim["harvests"] as Array).size()), "as many harvests as the table says")
	assert_between(float(_s()["level"]), float(int(sim["level"]) - 1), float(sim["level"]), "about the same field")
	var pays: Array = host.session.milestones.map(func(m: Dictionary) -> int: return int(m["coins"]))
	for i in pays.size():
		assert_eq(pays[i], int((sim["harvests"] as Array)[i][1]), "harvest %d pays what the table says" % (i + 1))
