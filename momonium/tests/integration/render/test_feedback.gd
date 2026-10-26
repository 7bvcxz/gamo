extends "res://tests/framework/test_case.gd"

## Step 47: growth feedback is exact -- one pop per real event (a batch of
## jobs is one pop, a tap is one harvest is one pop), nothing for time caught
## up on return, nothing with effects off, still with reduced motion, short
## numbers when they are big, a bounded pool, and before -> after only where
## the data states it.

const MainScene := preload("res://scenes/main.tscn")

var main: Node
var sim: Simulation
var fx: FeedbackFx
var hud: Hud
var bs: BuildingSystem
var vp: Viewport


func before_each() -> void:
	FxPrefs.reset()
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	sim = main.get("sim")
	sim.time_scale = 0.0
	# The Momo these cases are about (Step 53: a new island has none).
	with_starter_momo(sim)
	await tree.process_frame
	fx = main.get("feedback_fx")
	hud = main.get("hud")
	bs = sim.system(&"buildings")
	vp = main.get_viewport()
	LocaleService.apply("en")


func after_each() -> void:
	FxPrefs.reset()
	main.queue_free()
	await tree.process_frame


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


## A farm one tap away from harvest (sown and watered three times by command).
func _ripe_farm() -> int:
	var id := bs.place_ready("farm", Vector2i(1, 0), "harvest")
	fx.shown.clear()
	hud.flush_feedback()
	hud.pops.clear()
	return id


func _produced(kind: String = "produced") -> Array:
	return fx.shown.filter(func(s: Dictionary) -> bool: return s["kind"] == kind)


## Crops the simulation reports harvested (they are sold as they are picked
## and never reach the store, so count the events).
func _harvests() -> Array:
	var got: Array = []
	sim.bus.emitted.connect(func(type: StringName, p: Dictionary) -> void:
		if type == &"produced" and (p.get("items", {}) as Dictionary).has("crop"):
			got.append(int(p["items"]["crop"])))
	return got


func test_a_real_tap_harvests_once_and_pops_once() -> void:
	var id := _ripe_farm()
	var harvests := _harvests()
	var cams: CameraController = main.get("cameras")
	var proj: IsoProjection = main.get("projection")
	# Touch and its emulated mouse click together, as on a phone.
	_tap(cams.world_to_screen(proj.cell_center(Vector2i(1, 0))))
	await tree.process_frame
	sim.advance_ms(2000)
	assert_eq(harvests.size(), 1, "the tap harvested once (%s)" % [harvests])
	var got := int(harvests[0]) if not harvests.is_empty() else 0
	var pops := _produced("money")
	assert_eq(pops.size(), 1, "one pop for one harvest (%s)" % [pops])
	assert_eq(int(pops[0]["amount"]), got * (sim.system(&"economy") as EconomySystem).unit_price("crop"), "showing the money it fetched")
	assert_eq(String(pops[0]["key"]), "money:%d" % id, "over that farm")
	assert_eq(_produced().size(), 0, "the crop sold at once is shown as its money, not as a crop")


func test_a_batch_of_jobs_is_one_pop_per_building_and_item() -> void:
	var a := bs.place_instant("lumberyard", Vector2i(1, 0))
	var b := bs.place_instant("mine", Vector2i(0, 1))
	for i in 4:
		sim.bus.emit(&"produced", {"id": a, "type": "lumberyard", "items": {"wood": 2}})
	sim.bus.emit(&"produced", {"id": b, "type": "mine", "items": {"stone": 3}})
	var pops := _produced()
	assert_eq(pops.size(), 2, "one pop per building")
	var wood: Array = pops.filter(func(s: Dictionary) -> bool: return String(s["key"]).ends_with(":wood"))
	assert_eq(int(wood[0]["amount"]), 8, "four batches of 2 wood read +8")
	assert_eq(String(wood[0]["text"]), "+8")


func test_hud_gathers_money_and_exp_into_one_pop_each() -> void:
	hud.pops.clear()
	var economy: EconomySystem = sim.system(&"economy")
	for i in 5:
		economy.earn(3, "test")
	(sim.system(&"progression") as ProgressionSystem).add_exp(2, "test")
	(sim.system(&"progression") as ProgressionSystem).add_exp(3, "test")
	hud.flush_feedback()
	assert_eq(hud.pops.filter(func(t: String) -> bool: return t.begins_with("+$")), ["+$15"], "five sales, one +$15")
	assert_eq(hud.pops.filter(func(t: String) -> bool: return t.ends_with("EXP")), ["+5 EXP"], "one +5 EXP")
	hud.flush_feedback()
	assert_eq(hud.pops.size(), 2, "nothing shows twice")


func test_time_away_caught_up_on_return_pops_nothing() -> void:
	var f := bs.place_instant("farm", Vector2i(1, 0))
	sim.execute({"type": "momo.assign", "momo": 1, "building": f})
	await tree.process_frame
	fx.shown.clear()
	hud.flush_feedback()
	hud.pops.clear()
	var jobs_before := int(bs.get_building(f).get("completed", 0))
	# The tab was hidden for ten minutes: the frame loop catches it up.
	sim.time_scale = 1.0
	main.set("_last_wall", Time.get_unix_time_from_system() - 600.0)
	await tree.process_frame
	sim.time_scale = 0.0
	assert_true(int(bs.get_building(f).get("completed", 0)) > jobs_before, "Momo worked while away")
	assert_false(sim.replaying, "replaying ends with the catch-up")
	hud.flush_feedback()
	assert_eq(fx.shown.size(), 0, "no world pops for time caught up (%s)" % [fx.shown])
	assert_eq(hud.pops.filter(func(t: String) -> bool: return t.begins_with("+$") or t.ends_with("EXP")), [], "no HUD pops for it either")


func test_effects_off_shows_nothing_but_changes_nothing() -> void:
	FxPrefs.enabled = false
	var id := _ripe_farm()
	var harvests := _harvests()
	sim.execute({"type": "building.tap", "id": id})
	sim.advance_ms(2000)
	hud.flush_feedback()
	assert_eq(harvests.size(), 1, "the harvest still happens")
	assert_eq(fx.shown.size(), 0, "no world pops")
	assert_eq(hud.pops.size(), 0, "no HUD pops")
	var view: BuildingView = (main.get("building_views") as BuildingViews).view(id)
	view.celebrate()
	assert_eq(float(view.get("_celebrate")), 0.0, "no celebration")


func test_reduced_motion_pops_without_moving() -> void:
	FxPrefs.reduced_motion = true
	var a := bs.place_instant("lumberyard", Vector2i(1, 0))
	sim.bus.emit(&"produced", {"id": a, "type": "lumberyard", "items": {"wood": 2}})
	assert_eq(fx.active_count(), 1, "it still shows")
	var node: Node2D = fx.get_children().filter(func(c: Node) -> bool: return c is Node2D and c.visible)[0]
	var at := node.position
	fx._process(0.5)
	assert_eq(node.position, at, "but does not rise")
	fx._process(0.6)
	assert_eq(node.modulate.a, 1.0, "Step 54: held fully readable for two thirds of its life")
	fx._process(0.4)
	assert_true(node.modulate.a < 1.0, "then it fades where it is")
	var view: BuildingView = (main.get("building_views") as BuildingViews).view(a)
	view.celebrate()
	assert_eq(float(view.get("_bounce")), 0.0, "no bounce")


func test_big_numbers_are_short() -> void:
	assert_eq(FxPrefs.compact(950), "950")
	assert_eq(FxPrefs.compact(9999), "9999")
	assert_eq(FxPrefs.compact(12345), "12.3K")
	assert_eq(FxPrefs.compact(1200000), "1.2M")
	assert_eq(FxPrefs.compact(2500000000), "2.5B")
	assert_eq(FxPrefs.compact(-40000), "-40K")
	hud.pops.clear()
	hud.pop_money(1234567)
	assert_eq(hud.pops, ["+$1.2M"], "a big sale reads +$1.2M")


func test_a_flood_stays_within_the_pool() -> void:
	var ids: Array[int] = []
	var world: WorldSystem = sim.system(&"world")
	for x in 6:
		for y in 6:
			world.add_land(Vector2i(x, y))
	for x in 6:
		for y in 4:
			ids.append(bs.place_instant("lumberyard", Vector2i(x, y)))
	await tree.process_frame
	for id: int in ids:
		sim.bus.emit(&"produced", {"id": id, "type": "lumberyard", "items": {"wood": 1}})
	assert_true(fx.active_count() <= FeedbackFx.MAX_ACTIVE, "at most %d at once (%d)" % [FeedbackFx.MAX_ACTIVE, fx.active_count()])
	var nodes := fx.get_children().filter(func(c: Node) -> bool: return c is Node2D).size()
	assert_true(nodes <= FeedbackFx.MAX_ACTIVE + 1, "nodes are pooled, not made per pop (%d)" % nodes)


func test_research_pop_says_before_and_after_from_the_data() -> void:
	var rs: ResearchSystem = sim.system(&"research")
	var id := ""
	for n: Dictionary in rs.nodes():
		var nid := String(n["id"])
		if rs.max_level(nid) >= 2 and ResearchText.at_level(sim, nid, 1) != "" and ResearchText.at_level(sim, nid, 1) != ResearchText.at_level(sim, nid, 2):
			id = nid
			break
	assert_true(id != "", "some research grows with its level")
	var text := hud.research_text([{"id": id, "level": 2}])
	assert_true(text.contains(ResearchText.at_level(sim, id, 1)) and text.contains(ResearchText.at_level(sim, id, 2)) and text.contains("→"), "Lv 2 says Lv 1 -> Lv 2 (%s)" % text)
	assert_false(hud.research_text([{"id": id, "level": 1}]).contains("→"), "a first level has no before")
	assert_eq(hud.research_text([{"id": id, "level": 1}, {"id": id, "level": 2}]), "Research ×2 done!", "several at once are counted")


func test_promotion_banner_names_the_new_special_slots() -> void:
	var tiers: TierSystem = sim.system(&"tiers")
	var levels := tiers.levels()
	var a := int((levels[0] as Dictionary).get("special_slots", 1))
	var b := int((levels[1] as Dictionary).get("special_slots", 1))
	var line := String(main.call("_promotion_change", {"tier": 1, "special_slots": b}))
	if a != b:
		assert_eq(line, "Special slots %d → %d" % [a, b], "before and after, from the tier data")
	else:
		assert_eq(line, "", "no line when nothing changed")


func test_a_new_island_says_how_much_sooner_it_sold() -> void:
	var prestige: PrestigeSystem = sim.system(&"prestige")
	prestige.history = [{"n": 1, "value": 5000, "points": 3, "rp": 2, "day": 40}, {"n": 2, "value": 9000, "points": 5, "rp": 3, "day": 25}]
	main.call("_welcome_new_island")
	var c: TierCelebration = main.get("celebration")
	assert_eq(c.text, "A new island · legacy points +5")
	assert_eq(c.sub, "Sold on Day 25 — the last island on Day 40", "sooner, by the recorded days")
	prestige.history = [{"n": 1, "value": 5000, "points": 3, "rp": 2, "day": 30}, {"n": 2, "value": 9000, "points": 5, "rp": 3, "day": 33}]
	main.call("_welcome_new_island")
	assert_eq(c.sub, "", "not sooner: nothing claimed")


func test_clock_hands_sit_on_the_painted_faces() -> void:
	var lib := SpriteLibrary.load_atlas()
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites.json"))
	var spec: Dictionary = manifest["sprites"]["clock_tower"]
	var o: Array = spec["pivots"]["origin"]
	for pv: String in ["face_l", "face_r"]:
		var f: Array = spec["pivots"][pv]
		var want := (Vector2(f[0], f[1]) - Vector2(o[0], o[1])) * float(spec["scale"]) * float(spec["world_scale"])
		var got := (lib.pivot("clock_tower", pv) - lib.pivot("clock_tower", "origin")) * lib.world_scale("clock_tower")
		assert_true(got.distance_to(want) < 0.6, "%s at %s (want %s)" % [pv, got, want])


func test_a_fresh_pop_grows_instead_of_stacking() -> void:
	hud.pops.clear()
	hud.pop_money(5)
	hud.pop_money(3)
	var labels := hud.get_children().filter(func(n: Node) -> bool: return n is Label and n.name.begins_with("Pop") and (n as Label).text.begins_with("+$") and not n.is_queued_for_deletion())
	assert_eq(labels.size(), 1, "one label beside the money")
	assert_eq((labels[0] as Label).text, "+$8", "+$5 then +$3 reads +$8")
