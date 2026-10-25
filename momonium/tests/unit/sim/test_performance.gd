extends "res://tests/framework/test_case.gd"

## Big islands stay quick without the game playing any differently: the same
## world whether time runs in frames, in one stretch, offline, or across a
## reload -- landmarks' timed effects included -- the shortcuts the systems
## keep (lists by kind, sorted ids, research memos) following every change,
## and a generous wall-time ceiling on a big island so a slowdown of the old
## size cannot come back unseen. (The fine budgets: tools/bench/budgets.json.)


## A busy island with every timed effect: a Clock Tower, a School, a furnace
## with ore, a Momo-heavy watch layout.
func _island() -> Simulation:
	var sim := StressIsland.build(12)
	var w: WorldSystem = sim.system(&"world")
	for x in range(12, 15):
		for y in 3:
			w.add_land(Vector2i(x, y))
	var bs: BuildingSystem = sim.system(&"buildings")
	bs.place_instant("clock_tower", Vector2i(12, 0))
	bs.place_instant("school", Vector2i(13, 2))
	bs.place_instant("smelter", Vector2i(14, 0))
	(sim.system(&"inventory") as InventorySystem).add("copper_ore", 200, "test")
	return sim


func _state(sim: Simulation) -> String:
	return JSON.stringify(sim.snapshot())


func test_frames_one_stretch_offline_and_a_reload_agree() -> void:
	var minutes := 20
	var stretch := _island()
	stretch.advance_ms(minutes * 60000)
	var frames := _island()
	for i in minutes * 60 * 4:
		frames.advance_seconds(0.25)
	var away := _island()
	away.advance_ms(5 * 60000)
	var reloaded := Simulation.from_save(JSON.parse_string(JSON.stringify(away.save_state())))
	var rep := OfflineProgress.catch_up(reloaded, (minutes - 5) * 60000)
	assert_false(bool(rep["capped_events"]), "the catch-up was not cut short")
	assert_true((stretch.system(&"specials") as SpecialSystem).burst()["standing"], "the tower rang through it")
	assert_true(int((stretch.system(&"buildings") as BuildingSystem).get_building((stretch.system(&"buildings") as BuildingSystem).special_built("school")).get("id", 0)) > 0, "the school taught through it")
	var want := _state(stretch)
	assert_eq(_state(frames), want, "frame by frame = one stretch")
	assert_eq(_state(reloaded), want, "saved, reloaded and caught up offline = played")


func test_a_reload_keeps_whole_tile_numbers() -> void:
	var sim := _island()
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(sim.save_state())))
	var b: Dictionary = (copy.system(&"buildings") as BuildingSystem).get_building(1)
	assert_eq(typeof(b["anchor"][0]), TYPE_INT, "anchors come back as whole numbers")
	assert_eq(_state(copy), _state(sim), "the same world, number for number")


func test_lists_by_kind_follow_the_island() -> void:
	var sim := _island()
	var bs: BuildingSystem = sim.system(&"buildings")
	var community: CommunitySystem = sim.system(&"community")
	assert_eq(bs.ids_where("special").size(), 2, "the tower and the school")
	assert_eq(community.homes(), [] as Array[int], "no homes yet")
	var w: WorldSystem = sim.system(&"world")
	w.add_land(Vector2i(14, 2))
	var villa := bs.place_instant("villa", Vector2i(14, 2))
	assert_eq(community.homes(), [villa] as Array[int], "a new home is found at once")
	bs.demolish(bs.special_built("school"))
	assert_eq(bs.ids_where("special").size(), 1, "a landmark pulled down leaves the list")
	assert_false((sim.system(&"specials") as SpecialSystem).skill_exp_multiplier() > 1.0, "and its effect with it")
	# A refit changes the kind under the same id.
	var mine := 0
	for id: int in bs.ids():
		if bs.get_building(id)["type"] == "mine":
			mine = id
			break
	var jobs: JobSystem = sim.system(&"jobs")
	var before := jobs._consumer_ids().size()
	(sim.system(&"economy") as EconomySystem).earn(100000, "test")
	for option: Dictionary in bs.refits(mine):
		if option["type"] == "smelter":
			var items: Dictionary = option["cost"].get("items", {})
			for item: String in items:
				(sim.system(&"inventory") as InventorySystem).add(item, int(items[item]), "test")
	var r := bs.refit(mine, "smelter")
	assert_true(r["ok"], "a mine refitted into a furnace (%s)" % r.get("reason", ""))
	assert_eq(jobs._consumer_ids().size(), before + 1, "the furnace joins the buildings that wait for inputs")


func test_ids_after_loading_another_island() -> void:
	var a := StressIsland.build(6, 4)
	var b := StressIsland.build(6, 4)
	var mb: MomoSystem = b.system(&"momo")
	mb.ids()
	# Same number of Momo, other ids: what b answers must be a's after a load.
	var ma: MomoSystem = a.system(&"momo")
	var raw: Dictionary = JSON.parse_string(JSON.stringify(a.save_state()))
	for m: Dictionary in raw["systems"]["momo"]["momos"]:
		m["id"] = int(m["id"]) + 100
	b.load_state(raw)
	assert_eq(mb.ids(), [101, 102, 103, 104] as Array[int], "ids are read again after a load")
	assert_eq(ma.ids().size(), 4, "")
	var cells := mb.watched(101)
	if not cells.is_empty():
		var bs: BuildingSystem = b.system(&"buildings")
		var at := bs.building_at(cells[0])
		if at != 0:
			assert_true(mb.watchers_of(at).has(101), "who watches what is read again too")


func test_a_big_island_runs_well_inside_its_ceiling() -> void:
	var sim := StressIsland.build(20)
	var t0 := Time.get_ticks_usec()
	sim.advance_ms(10 * 60000)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	# About 0.4 s on the development machine; before Step 41 it was ~3.5 s.
	# The ceiling is loose on purpose (CI machines vary) but not loose enough
	# to let the old cost back in.
	assert_true(ms < 2500.0, "ten simulated minutes of a 20x20 island: %.0f ms" % ms)
	assert_eq((sim.system(&"buildings") as BuildingSystem).ids().size(), 133, "with every building")
	assert_eq((sim.system(&"momo") as MomoSystem).ids().size(), 44, "and every Momo")
