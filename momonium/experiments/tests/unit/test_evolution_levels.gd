extends "res://tests/framework/test_case.gd"

## Experiment B's one Momo, level by level (EvolutionLevels): every level
## changes something on the Momo, the money comes only from finished passes
## of its work, and the pace -- first upgrade in 10-30 s, several in three
## minutes, a new tool every ~35 s, the Scholar's crown just after.

const LOOK := 16


func test_every_level_changes_the_momo() -> void:
	for n in range(1, LOOK):
		var a := EvolutionLevels.row(n - 1)
		var b := EvolutionLevels.row(n)
		var changed := String(a["pose"]) != String(b["pose"]) \
			or EvolutionLevels.wearing(n) != EvolutionLevels.wearing(n - 1) \
			or int(b.get("sparkle", 0)) != int(a.get("sparkle", 0))
		assert_true(changed, "level %d changes what the Momo looks like or does" % n)
		assert_true(EvolutionLevels.rate(n) > EvolutionLevels.rate(n - 1), "level %d earns more" % n)
		assert_true(EvolutionLevels.cost(n + 1) > EvolutionLevels.cost(n), "level %d costs more" % (n + 1))


func test_tools_and_wear_alternate() -> void:
	var tools := 0
	for n in range(1, EvolutionLevels.LEVELS.size()):
		if EvolutionLevels.new_tool(n):
			tools += 1
			assert_true(LabMomo.work()["animations"].has(String(EvolutionLevels.row(n)["pose"])), "level %d's motion is one of the game's" % n)
			var tool := String(EvolutionLevels.row(n)["tool"])
			assert_true((LabGlove.tool(tool)["region"] as Rect2).size.x > 0.0, "its tool %s is drawn" % tool)
	assert_eq(tools, 6, "six new tools and motions after the first")
	assert_eq(EvolutionLevels.wearing(12), ["side", "head", "body", "neck", "chest"].map(func(p: String) -> String:
		for w: String in EvolutionLevels.wearing(12):
			if String(EvolutionLevels.PLACE[w]) == p:
				return w
		return ""), "one thing per place")
	assert_eq(EvolutionLevels.wearing(12).filter(func(w: String) -> bool: return EvolutionLevels.PLACE[w] == "head"), ["crown"], "the crown replaced the helmet, which replaced the hat")


func test_money_is_finished_work() -> void:
	for n in 13:
		var pose := String(EvolutionLevels.row(n)["pose"])
		assert_near(EvolutionLevels.cycle(n), LabMomo.loop_seconds(pose) / float(EvolutionLevels.row(n)["speed"]), 0.0001, "level %d's pass" % n)
		assert_near(EvolutionLevels.rate(n), float(EvolutionLevels.row(n)["pay"]) / EvolutionLevels.cycle(n), 0.0001, "pay over a pass")


func test_the_pace() -> void:
	var ups := EvolutionLevels.simulate(180.0)
	assert_between(ups[0], 10.0, 30.0, "the first upgrade")
	assert_true(ups.size() >= 8, "several upgrades in three minutes (%d)" % ups.size())
	for i in range(1, ups.size()):
		assert_true(ups[i] - ups[i - 1] <= 30.0, "never a long wait (%.1f s before %d)" % [ups[i] - ups[i - 1], i + 1])
	var longer := EvolutionLevels.simulate(300.0)
	assert_true(longer.size() >= 12, "the Scholar comes within five minutes")
	assert_true(longer[11] > 180.0, "and after three (%.1f s)" % longer[11])


func test_hats_sit_on_the_measured_head() -> void:
	var heads: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://lab/art/work_heads.json")) as Dictionary)["heads"]
	var measured: Variant = load("res://tools/work_heads.gd").call("measure")
	assert_eq(JSON.stringify(JSON.parse_string(JSON.stringify(measured))), JSON.stringify(heads), "work_heads.json is current (run tools/work_heads.gd)")
	for f: Dictionary in LabMomo.work()["frames"]:
		var head: Array = f["head"]
		var torso: Array = f["torso"]
		assert_true(float(head[1]) < float(torso[1]) - 40.0, "%s: the head is well above the torso" % f["name"])
		assert_true(f.has("eyes"), "%s has eyes, measured or put under the head" % f["name"])
