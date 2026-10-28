extends "res://tests/framework/test_case.gd"

## Step 72 on screen: the HUD chip and the Status tier view are the one place
## for the one goal. The chip says it with how much is met; the view draws the
## road (named steps reached and current, a faint star for each still ahead),
## the conditions with have / need -- money with a labelled estimate -- and
## promotes for a tier goal only; a milestone reached celebrates briefly and
## the next takes its place. It all fits a phone.

const MainScene := preload("res://scenes/main.tscn")

var main: Node
var sim: Simulation
var hud: Hud
var tv: TierView


func before_each() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	sim = main.get("sim")
	sim.time_scale = 0.0
	with_starter_momo(sim)
	await tree.process_frame
	hud = main.get("hud")
	tv = (main.get("status_panel") as StatusPanel).tier_view
	LocaleService.apply("en")


func after_each() -> void:
	main.queue_free()
	await tree.process_frame


func _open_status() -> void:
	main.call("_on_hud_action", &"status")
	await tree.process_frame
	tv.refresh()
	await tree.process_frame


func _golden_age_met() -> void:
	var tiers: TierSystem = sim.system(&"tiers")
	tiers.tier = 2
	sim.bus.emit(&"tier_promoted", {"tier": 2, "name": "nation", "special_slots": tiers.special_slots()})
	var m: MomoSystem = sim.system(&"momo")
	while m.ids().size() < 10:
		m.add_momo(Vector2(0.5, 0.5))
	var rs: ResearchSystem = sim.system(&"research")
	for id: String in ["combine_harvester", "coppice_woodland"]:
		rs.completed[id] = 0
	sim.bus.emit(&"research_completed", {"id": "coppice_woodland"})


func test_the_chip_and_the_view_say_one_goal() -> void:
	assert_eq(hud.goal_text(), "Next: City 0/4", "a new island: the City")
	await _open_status()
	assert_eq(tv.next_label.text, "Next: City", "the same goal on Status")
	assert_eq(tv.ladder.shown.map(func(st: Dictionary) -> String: return st["state"]), ["done", "current", "ahead", "ahead", "ahead"], "the road drawn")
	assert_true(tv.promote_button.visible, "a tier goal promotes from here")
	# Money: an estimate at today's pace, said to be one.
	# Money coming in (the last minute's sales, as the HUD's +$N/min).
	(sim.system(&"economy") as EconomySystem)._note_rate(60)
	tv.refresh()
	var est := tv.list.get_node_or_null("Estimate_produced") as Label
	assert_true(est != null and est.text.begins_with("About ") and est.text.ends_with("(estimate)"), "an estimate, labelled (%s)" % (est.text if est else "none"))


func test_after_the_nation_the_golden_age_then_the_civilization() -> void:
	var tiers: TierSystem = sim.system(&"tiers")
	tiers.tier = 2
	sim.bus.emit(&"tier_promoted", {"tier": 2, "name": "nation", "special_slots": tiers.special_slots()})
	assert_eq(hud.goal_text(), "Next: Golden Age 1/3", "the Nation is met: one of three")
	await _open_status()
	assert_eq(tv.next_label.text, "Next: Golden Age", "named on Status")
	assert_false(tv.promote_button.visible, "nothing to press: it comes by playing")
	assert_eq((tv.list.get_node("Need_eighth_tiers").get_child(1) as Label).text, "0 / 2", "eighth tiers, have / need")
	_golden_age_met()
	await tree.process_frame
	var celebration: TierCelebration = main.get("celebration")
	assert_true(celebration.playing(), "a brief celebration")
	assert_eq(hud.goal_text(), "Next: Civilization 1/3", "the next distant goal at once (the Nation met; 2 of 6 eighth tiers, no island sold)")
	var views: BuildingViews = main.get("building_views")
	for v: BuildingView in views.views.values():
		assert_eq(v.golden_age(), 1, "gold pennants on the island")


func test_every_goal_reached_reads_so() -> void:
	_golden_age_met()
	var rs: ResearchSystem = sim.system(&"research")
	for ind: String in rs.industries():
		for n: Dictionary in rs.nodes(ind):
			if rs.tier_of(String(n["id"])) >= 8:
				rs.completed[String(n["id"])] = 0
	(sim.system(&"prestige") as PrestigeSystem).sales = 3
	(sim.system(&"goals") as GoalSystem).check()
	assert_eq(hud.goal_text(), "★ Civilization", "a star and the last milestone")
	await _open_status()
	assert_eq(tv.next_label.text, "Every goal reached. Keep growing", "said plainly")
	assert_eq(tv.list.get_child_count(), 0, "no list of conditions left")


func test_it_fits_a_phone() -> void:
	var win := tree.root
	var before := win.size
	win.size = Vector2i(390, 844)
	await tree.process_frame
	var tiers: TierSystem = sim.system(&"tiers")
	tiers.tier = 2
	sim.bus.emit(&"tier_promoted", {"tier": 2, "name": "nation", "special_slots": tiers.special_slots()})
	await _open_status()
	await tree.process_frame
	var frame: Rect2 = tv.get_global_rect()
	assert_true(frame.size.x > 100.0, "the view has room (%s)" % frame)
	for c: Node in tv.list.get_children():
		var r := (c as Control).get_global_rect()
		assert_true(r.position.x >= frame.position.x - 0.5 and r.end.x <= frame.end.x + 0.5, "%s inside the view" % c.name)
	var font := tv.ladder.get_theme_default_font()
	for i in tv.ladder.shown.size():
		var st: Dictionary = tv.ladder.shown[i]
		if st["state"] == "ahead":
			continue
		var w := font.get_string_size(tr(GoalLadder._name_key(String(st["id"]))), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		assert_true(w <= tv.ladder.size.x / 2.0, "%s's name fits the strip (%.0f of %.0f)" % [st["id"], w, tv.ladder.size.x])
	win.size = before
	await tree.process_frame
