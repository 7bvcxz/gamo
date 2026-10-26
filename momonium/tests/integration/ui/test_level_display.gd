extends "res://tests/framework/test_case.gd"

## Step 54: money and the level are the HUD's first read. The EXP bar is the
## exact share of the level from ProgressionSystem's own thresholds, slides
## (never jumps) and runs round once per level gained; a level gained shows a
## burst and "LEVEL UP!" at the card -- one per moment, however many levels
## came in it -- and nothing at all of it with effects off; reduced motion
## only fades. Pops show at once, large, and stay readable before they fade.

const MainScene := preload("res://scenes/main.tscn")
const SIZES := [Vector2i(720, 1280), Vector2i(720, 1600), Vector2i(1280, 800), Vector2i(2048, 1280)]

var main: Node
var sim: Simulation
var hud: Hud
var prog: ProgressionSystem


func before_each() -> void:
	FxPrefs.reset()
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	sim = main.get("sim")
	sim.time_scale = 0.0
	hud = main.get("hud")
	prog = sim.system(&"progression")
	LocaleService.apply("en")


func after_each() -> void:
	FxPrefs.reset()
	main.queue_free()
	await tree.process_frame


func _settle() -> void:
	hud.refresh()
	for i in 60:
		if not hud.exp_bar.moving():
			break
		await tree.create_timer(0.05).timeout


func test_the_bar_is_the_exact_share_of_the_level() -> void:
	var need := prog.next_level_exp()
	prog.add_exp(need / 2, "test")
	await _settle()
	assert_eq(hud._level_label.text, "Lv %d" % prog.level, "the level, large")
	assert_eq(hud._exp_label.text, "%d / %d" % [prog.experience, need], "exact EXP of the next level's need")
	assert_near(hud.exp_bar.target, float(prog.experience) / need, 0.0001, "the bar heads to exactly that share")
	assert_near(hud.exp_bar.value, hud.exp_bar.target, 0.0001, "and gets there")
	assert_eq(ExpBar.fraction(0, 95), 0.0, "empty at the start of a level")
	assert_eq(ExpBar.fraction(95, 95), 1.0, "full at its end")
	assert_eq(ExpBar.fraction(5, 0), 1.0, "a level with nothing more to earn reads full (a cap)")


func test_crossing_a_level_runs_round_to_the_new_share() -> void:
	prog.add_exp(prog.next_level_exp() - 10, "test")
	await _settle()
	assert_true(hud.exp_bar.value > 0.85, "nearly full")
	prog.add_exp(25, "test")
	hud.refresh()
	assert_eq(hud.exp_bar.level, 2, "the bar is on the new level")
	assert_near(hud.exp_bar.target, 15.0 / prog.next_level_exp(), 0.0001, "the 15 left over, of the new level's need")
	assert_true(hud.exp_bar.moving(), "it slides (to the end, then from empty)")
	await _settle()
	assert_near(hud.exp_bar.value, hud.exp_bar.target, 0.0001, "and stands at the new share")


func test_several_levels_at_once_are_one_level_up() -> void:
	hud.pops.clear()
	var total := 0
	for lv in range(1, 4):
		total += prog.exp_needed_for(lv)
	prog.add_exp(total + 7, "test")
	assert_eq(prog.level, 4, "three levels in one gain")
	hud.flush_feedback()
	var fx: LevelUpFx = hud.level_fx
	assert_true(fx.playing(), "the level-up shows")
	assert_eq([fx.from_level, fx.to_level], [1, 4], "from where it was to where it is")
	assert_eq(fx.line.text, "Lv 1 → 4", "said as such")
	assert_eq(fx.title.text, "LEVEL UP!", "")
	assert_eq(hud.pops.filter(func(t: String) -> bool: return t == "Lv 4!").size(), 1, "once, not three times")
	hud.refresh()
	assert_eq(hud.exp_bar.level, 4, "the bar on level 4")
	assert_near(hud.exp_bar.target, 7.0 / prog.next_level_exp(), 0.0001, "with the 7 left over")
	hud.flush_feedback()
	assert_eq(hud.pops.filter(func(t: String) -> bool: return t == "Lv 4!").size(), 1, "nothing shows twice")


func test_a_level_while_one_still_shows_updates_it() -> void:
	prog.add_exp(prog.next_level_exp(), "test")
	hud.flush_feedback()
	prog.add_exp(prog.next_level_exp(), "test")
	hud.flush_feedback()
	assert_eq([hud.level_fx.from_level, hud.level_fx.to_level], [1, 3], "one show, from 1 to 3 -- not two stacked")


func test_high_levels_read_cleanly() -> void:
	while prog.level < 40:
		prog.add_exp(prog.next_level_exp() - prog.experience, "test")
	prog.add_exp(12345, "test")
	hud.refresh(true)
	assert_true(hud._exp_label.text.contains(","), "big numbers with separators (%s)" % hud._exp_label.text)
	assert_between(hud.exp_bar.value, 0.0, 1.0, "the bar stays a share")
	assert_eq(hud._level_label.text, "Lv %d" % prog.level, "")


func test_reduced_motion_sets_at_once_and_only_fades() -> void:
	FxPrefs.reduced_motion = true
	prog.add_exp(prog.next_level_exp() + 3, "test")
	hud.refresh()
	assert_false(hud.exp_bar.moving(), "no slide")
	assert_near(hud.exp_bar.value, hud.exp_bar.target, 0.0001, "set at once")
	hud.flush_feedback()
	var fx: LevelUpFx = hud.level_fx
	assert_true(fx.playing(), "the words still show: a level is news")
	fx._process(0.1)
	assert_eq(fx.title.scale, Vector2.ONE, "but do not grow")
	assert_eq(hud.exp_pill.scale, Vector2.ONE, "nor does the card pulse")


func test_effects_off_shows_no_level_up_but_the_numbers_change() -> void:
	FxPrefs.enabled = false
	prog.add_exp(prog.next_level_exp() + 3, "test")
	hud.flush_feedback()
	assert_false(hud.level_fx.playing(), "no show")
	hud.refresh()
	assert_eq(hud._level_label.text, "Lv 2", "the level changed all the same")
	assert_eq(hud.exp_bar.level, 2, "and the bar")


func test_the_level_up_does_no_work_when_idle() -> void:
	var fx: LevelUpFx = hud.level_fx
	await tree.process_frame
	assert_false(fx.is_processing(), "idle: no per-frame work (it once ran from start-up and took a real level for a show in progress)")
	assert_false(fx.visible, "")
	prog.add_exp(prog.next_level_exp(), "test")
	hud.flush_feedback()
	assert_eq([fx.from_level, fx.to_level], [1, 2], "the first level-up of a session: from 1")
	assert_true(fx.is_processing(), "playing: it animates")
	fx._process(LevelUpFx.DURATION + 0.1)
	assert_false(fx.playing() or fx.visible or fx.is_processing(), "then idle again")


func test_a_load_shows_the_level_at_once() -> void:
	prog.add_exp(prog.next_level_exp() + 40, "test")
	hud.refresh()
	assert_true(hud.exp_bar.moving(), "a level gained slides")
	sim.bus.emit(&"game_loaded", {})
	hud.refresh()
	assert_false(hud.exp_bar.moving(), "a loaded island is shown as it is")
	assert_near(hud.exp_bar.value, 40.0 / prog.next_level_exp(), 0.0001, "")


func test_pops_are_large_and_at_once() -> void:
	hud.pops.clear()
	(sim.system(&"economy") as EconomySystem).earn(12, "test")
	await tree.create_timer(Hud.FEEDBACK_WINDOW + 0.05).timeout
	assert_eq(hud.pops, ["+$12"] as Array[String], "the money pops within a few frames")
	var label: Label = hud.get_children().filter(func(n: Node) -> bool: return n is Label and (n as Label).text == "+$12")[0]
	assert_true(label.get_theme_font_size("font_size") >= 32, "large")
	assert_true(label.get_theme_constant("outline_size") >= 10, "with a heavy dark rim")
	assert_true(Hud.POP_HOLD >= 0.8, "held before it fades")
	assert_true(FeedbackFx.FONT_SIZE >= 34 and FeedbackFx.LIFE >= 1.8, "world pops too")
	var bs: BuildingSystem = sim.system(&"buildings")
	var farm := bs.place_instant("farm", Vector2i(1, 0))
	await tree.process_frame
	var fx: FeedbackFx = main.get("feedback_fx")
	sim.bus.emit(&"sold", {"id": farm, "type": "farm", "items": {"crop": 1}, "money": 3, "worker": 0, "revenue": 3})
	assert_eq(fx.active_count(), 1, "over the farm, the moment it sells (it used to wait 0.45 s)")
	sim.bus.emit(&"sold", {"id": farm, "type": "farm", "items": {"crop": 1}, "money": 3, "worker": 0, "revenue": 3})
	assert_eq(fx.active_count(), 1, "a second sale grows the same pop")
	assert_eq(String(fx.shown.back()["text"]), "+$6", "+$3 then +$3 reads +$6")


func test_money_and_level_lead_the_hud_at_every_size() -> void:
	for size: Vector2i in SIZES:
		var holder := SubViewport.new()
		holder.size = size
		tree.root.add_child(holder)
		var m: Node = MainScene.instantiate()
		holder.add_child(m)
		await tree.process_frame
		await tree.process_frame
		var h: Hud = m.get("hud")
		var p: ProgressionSystem = (m.get("sim") as Simulation).system(&"progression")
		p.add_exp(p.next_level_exp() + 1, "test")
		h.flush_feedback()
		var fx: LevelUpFx = h.level_fx
		var screen := Rect2(Vector2.ZERO, Vector2(size))
		assert_true(h._money_label.get_theme_font_size("font_size") > h._day_label.get_theme_font_size("font_size"), "%s: money is the largest number" % size)
		for l: Label in [fx.title, fx.line]:
			var r := l.get_global_rect()
			assert_true(screen.encloses(r), "%s: '%s' on screen" % [size, l.text])
			for other: Rect2 in h.occupied_rects():
				assert_false(r.intersects(other), "%s: '%s' clear of the HUD's pills and buttons" % [size, l.text])
		assert_true(h.exp_bar.get_global_rect().size.x >= 150.0, "%s: a bar long enough to read (%.0f)" % [size, h.exp_bar.get_global_rect().size.x])
		holder.queue_free()
		await tree.process_frame
