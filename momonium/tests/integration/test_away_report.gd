extends "res://tests/framework/test_case.gd"

## Step 49: the welcome-back card tells only what the catch-up ran -- money,
## EXP, what was made, the jobs and how many Momo did them -- with the wall
## clock and the counted time apart when they differ; a long quiet absence
## gets a gentle word, a short switch nothing.
##
## Step 79: play catches nothing up any more -- a launch, a relaunch, a
## refresh or a tab coming back finds the island as it was left, and says
## nothing about time away. The catch-up and its card remain only for the
## test tool that runs them on purpose (the browser bridge's `dev_away`,
## the same call as `_away` here).

const MainScene := preload("res://scenes/main.tscn")
const PATH := "user://test_away_save.json"

var main: Node


func before_each() -> void:
	FxPrefs.reset()
	Engine.remove_meta("momonium_no_save")
	Engine.set_meta("momonium_save_path", PATH)
	LocaleService.apply("en")


func after_each() -> void:
	if main != null:
		main.queue_free()
		await tree.process_frame
		main = null
	Engine.set_meta("momonium_no_save", true)
	Engine.remove_meta("momonium_save_path")
	for p: String in [PATH, PATH + ".tmp", PATH + ".bak", PATH + ".corrupt"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _open() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	(main.get("sim") as Simulation).time_scale = 0.0
	LocaleService.apply("en")


## An island with a farm and a lumberyard worked by two Momo.
func _working_island() -> Simulation:
	var sim := with_starter_momo(Simulation.new_game())
	(sim.system(&"economy") as EconomySystem).earn(200, "test")
	sim.execute({"type": "momo.hire"})
	var bs: BuildingSystem = sim.system(&"buildings")
	var f := bs.place_instant("farm", Vector2i(1, 0))
	var l := bs.place_instant("lumberyard", Vector2i(0, 1))
	sim.execute({"type": "momo.assign", "momo": 1, "building": f})
	sim.execute({"type": "momo.assign", "momo": 2, "building": l})
	return sim


func _write(sim: Simulation, seconds_ago: int) -> void:
	SaveService.write(sim, PATH, int(Time.get_unix_time_from_system()) - seconds_ago)


## The test tool's catch-up of `ms` on the open island, and its card (what
## the bridge's `dev_away` does).
func _away(ms: int) -> Dictionary:
	var r := OfflineProgress.catch_up(main.get("sim"), ms)
	main.call("_tell_about_return", r)
	return r


func test_the_report_counts_the_events_themselves() -> void:
	var sim := _working_island()
	var exp_sum := [0]
	var made := {}
	var workers := {}
	sim.bus.emitted.connect(func(t: StringName, p: Dictionary) -> void:
		if t == &"exp_gained":
			exp_sum[0] += int(p["amount"])
		elif t == &"produced":
			for k: String in p["items"]:
				made[k] = int(made.get(k, 0)) + int(p["items"][k])
		elif t == &"task_completed" and int(p.get("worker", 0)) > 0:
			workers[int(p["worker"])] = true)
	var r := OfflineProgress.catch_up(sim, 3600000)
	assert_eq(int(r["exp"]), exp_sum[0], "EXP: the sum of exp_gained (%d)" % exp_sum[0])
	assert_eq(r["items"], made, "items: the sum of what buildings produced")
	assert_eq(int(r["workers"]), workers.size(), "Momo at work: those who finished a stage")
	assert_eq(int(r["workers"]), 2, "both Momo worked")
	assert_true(int(r["items"].get("wood", 0)) > 0 and int(r["crops"]) > 0, "wood made and crops grown")
	assert_false(sim.replaying, "replaying is over")


func test_the_card_says_both_times_and_short_numbers() -> void:
	var sim := _working_island()
	_write(sim, 0)
	await _open()
	_away(10 * 3600000)
	var view: AwayView = main.get("away_view")
	assert_true((main.get("away_frame") as PanelFrame).visible, "the card opens")
	assert_true(view.partly_counted(), "10 h away, 8 h counted")
	assert_eq(view.counted_label.text, "Away 10 h 0 min. The island counts 8 h 0 min of it.", "both times, in words")
	var labels: Array = view.lines().map(func(l: Array) -> String: return l[0])
	assert_true(labels.has("Earned") and labels.has("EXP earned") and labels.has("Jobs done"), "money, EXP and jobs (%s)" % [labels])
	var jobs: Array = view.lines().filter(func(l: Array) -> bool: return l[0] == "Jobs done")
	assert_true(String(jobs[0][1]).ends_with("by 2 Momo"), "by how many Momo (%s)" % jobs[0][1])
	view.show_report({"away_ms": 3600000, "counted_ms": 3600000, "income": 12345678, "exp": 1500000, "crops": 25000, "jobs": 9, "workers": 1, "research": [], "letters": 0, "items": {}}, "")
	var money: Array = view.lines().filter(func(l: Array) -> bool: return l[0] == "Earned")
	assert_eq(money[0][1], "+$12.3M", "huge numbers stay short")
	assert_eq(view.counted_label.text, "Away 1 h 0 min. Momo kept the island going the whole time.")


func test_opening_a_window_puts_the_card_away() -> void:
	var sim := _working_island()
	_write(sim, 0)
	await _open()
	_away(3 * 3600000)
	assert_true((main.get("away_frame") as PanelFrame).visible, "the card")
	(main.get("hud") as Hud).action.emit(&"status")
	await tree.process_frame
	assert_false((main.get("away_frame") as PanelFrame).visible, "Status opened: the card is put away (Step 50: it covered Status's tabs)")
	assert_true((main.get("status_frame") as PanelFrame).visible, "and Status is in front")


func test_rounding_and_the_threshold() -> void:
	assert_eq(AwayView.long_duration(59999), "59 s", "under a minute: seconds, rounded down")
	assert_eq(AwayView.long_duration(3600000 + 65000), "1 h 1 min", "an hour and a minute")
	var r := {"counted_ms": 59999, "jobs": 3, "income": 0, "exp": 0, "research": [], "letters": 0}
	assert_false(OfflineProgress.worth_telling(r, 60.0, 1800.0), "59.999 s is a switch, not an absence")
	r["counted_ms"] = 60000
	assert_true(OfflineProgress.worth_telling(r, 60.0, 1800.0), "a minute with work done is worth a word")


func test_a_quiet_absence_gets_a_gentle_word_a_short_one_nothing() -> void:
	_write(with_starter_momo(Simulation.new_game()), 0)
	await _open()
	_away(3 * 3600000)
	var view: AwayView = main.get("away_view")
	assert_true((main.get("away_frame") as PanelFrame).visible, "three quiet hours: the card")
	assert_true(view.quiet.visible and view.quiet.text.begins_with("The island rested"), "a gentle word, no table of zeros")
	assert_eq(view.rows.get_child_count(), 0, "and no rows")
	assert_eq(view.counted_label.text, "Away 3 h 0 min.", "no claim that Momo kept working")
	main.queue_free()
	await tree.process_frame
	main = null
	_write(with_starter_momo(Simulation.new_game()), 0)
	await _open()
	_away(10 * 60000)
	assert_false((main.get("away_frame") as PanelFrame).visible, "ten quiet minutes: nothing to say")


func test_a_fresh_island_says_nothing() -> void:
	await _open()
	assert_false((main.get("away_frame") as PanelFrame).visible, "no save, no welcome back")


func test_hours_away_are_never_credited_at_a_launch_or_a_relaunch() -> void:
	var sim := _working_island()
	var saved_ms := sim.now_ms()
	var money := (sim.system(&"economy") as EconomySystem).money
	_write(sim, 2 * 3600)
	await _open()
	var live: Simulation = main.get("sim")
	assert_true(live.now_ms() - saved_ms < 1000, "two hours closed: the clock where it was saved (%d ms of frames since)" % (live.now_ms() - saved_ms))
	assert_eq((live.system(&"economy") as EconomySystem).money, money, "and the money")
	assert_false((main.get("away_frame") as PanelFrame).visible, "no welcome back")
	assert_eq(int((live.system(&"journey") as JourneySystem).totals()["offline_ms"]), 0, "no time away recorded")
	main.call("save_now")
	var now_ms := live.now_ms()
	main.queue_free()
	await tree.process_frame
	main = null
	# Launched again (a refresh): from the saved island, nothing more.
	await _open()
	var again: Simulation = main.get("sim")
	assert_true(again.now_ms() - now_ms < 1000, "a refresh runs nothing again (%d ms more)" % (again.now_ms() - now_ms))
	assert_eq((again.system(&"economy") as EconomySystem).money, money, "nor any money")
	assert_false((main.get("away_frame") as PanelFrame).visible, "and says nothing")


func test_a_tab_coming_back_catches_up_nothing() -> void:
	var sim := _working_island()
	_write(sim, 0)
	await _open()
	var live: Simulation = main.get("sim")
	var money := (live.system(&"economy") as EconomySystem).money
	var saves := int(main.get("saves_written"))
	# Twenty minutes hidden: saved once on the way out; the frames that come
	# while hidden and the whole twenty minutes handed over by the first frame
	# back move nothing.
	main.call("go_background")
	assert_eq(int(main.get("saves_written")), saves + 1, "saved as it went to the background")
	live.time_scale = 1.0
	var before := live.now_ms()
	main.call("_process", 1.0)
	main.call("come_back")
	main.call("_process", 1200.0)
	assert_eq(live.now_ms(), before, "the twenty minutes did not run")
	assert_eq((live.system(&"economy") as EconomySystem).money, money, "nothing earned")
	assert_false((main.get("away_frame") as PanelFrame).visible, "no card")
	main.call("_process", 0.1)
	live.time_scale = 0.0
	assert_eq(live.now_ms(), before + 100, "then on with the frames")


func test_research_points_and_the_economy_survive_away_and_a_reload() -> void:
	var sim := _working_island()
	var rs: ResearchSystem = sim.system(&"research")
	rs.completed["watering_efficiency"] = 0
	rs.bought["watering_efficiency"] = 2
	var economy: EconomySystem = sim.system(&"economy")
	var ledger_before := economy.lifetime_income()
	var r := OfflineProgress.catch_up(sim, 2 * 3600000)
	assert_eq(economy.lifetime_income() - ledger_before, int(r["income"]), "the card's income is exactly what the ledger added")
	assert_true(int(r["income"]) > 0, "and something was earned")
	var text := SaveService.encode(sim)
	var back := Simulation.from_save(SaveService.decode(text)["state"])
	var rs2: ResearchSystem = back.system(&"research")
	assert_eq(rs2.level("watering_efficiency"), rs.level("watering_efficiency"), "research levels kept")
	assert_eq(rs2.rp_allocated(), rs.rp_allocated(), "research points as allocated")
	var e2: EconomySystem = back.system(&"economy")
	assert_eq(e2.money, economy.money, "money kept")
	assert_eq(e2.lifetime_income(), economy.lifetime_income(), "the ledger kept")
	var inv: InventorySystem = sim.system(&"inventory")
	var inv2: InventorySystem = back.system(&"inventory")
	for item: String in inv.items:
		assert_eq(inv2.count(item), inv.count(item), "the store kept %s" % item)


func test_the_journey_says_only_what_was_played_on_a_new_island() -> void:
	await _open()
	var view: JourneyView = (main.get("stats_view") as Object).get("journey_view")
	view.refresh()
	assert_true(view.totals.text.begins_with("Played "), "time played (%s)" % view.totals.text)
	assert_false(view.totals.text.contains("away"), "and no time away: there is none to tell (Step 79)")
	# An island that has a record of time away (an old save, or the test
	# tool's catch-up) still reads it.
	_away(3600000)
	view.refresh()
	assert_true(view.totals.text.contains("away 1 h 0 min"), "a record of time away still reads (%s)" % view.totals.text)
