extends "res://tests/framework/test_case.gd"

## Village -> City -> Nation: milestones from the data, each with what the
## island has and needs; promotion only when all are met, keeping everything;
## special slots 1 / 2 / 3 in total; a sold island starts as a Village.

var sim: Simulation
var tiers: TierSystem
var bs: BuildingSystem


func before_each() -> void:
	sim = Simulation.new_game()
	tiers = sim.system(&"tiers")
	bs = sim.system(&"buildings")


func _meet_city() -> void:
	var world: WorldSystem = sim.system(&"world")
	for x in 3:
		for y in 3:
			world.add_land(Vector2i(x, y))
	var momos: MomoSystem = sim.system(&"momo")
	momos.add_momo(Vector2(0.5, 0.5))
	momos.add_momo(Vector2(1.5, 0.5))
	var rs: ResearchSystem = sim.system(&"research")
	rs.completed["momo_training"] = 0
	rs.bought["momo_training"] = 3
	(sim.system(&"economy") as EconomySystem).earn(1500, "sale")


func test_milestones_say_what_they_need() -> void:
	assert_eq(tiers.tier_name(), "village", "a new island is a village")
	var keys := tiers.progress().map(func(p: Dictionary) -> String: return p["key"])
	assert_eq(keys, ["tiles", "momos", "research_levels", "produced"], "land, Momo, research, value")
	var tiles: Dictionary = tiers.progress()[0]
	assert_eq([tiles["have"], tiles["need"], tiles["met"]], [4, 9, false], "4 of 9 tiles")
	assert_eq(sim.execute({"type": "tier.promote"})["reason"], "err.tier_not_yet", "not yet")


func test_promotion_keeps_everything_and_opens_a_slot() -> void:
	_meet_city()
	var farm := bs.place_instant("farm", Vector2i(1, 0))
	var money := (sim.system(&"economy") as EconomySystem).money
	assert_true(tiers.can_promote(), "all met")
	var r := sim.execute({"type": "tier.promote"})
	assert_true(r["ok"], "promoted")
	assert_eq([tiers.tier_name(), tiers.special_slots(), bs.special_slots()], ["city", 2, 2], "a city: two special slots")
	assert_false(bs.get_building(farm).is_empty(), "buildings kept")
	assert_eq((sim.system(&"economy") as EconomySystem).money, money, "money kept")
	assert_eq((sim.system(&"world") as WorldSystem).owned_count(), 9, "land kept")


func test_slots_are_a_total_and_demolition_frees_one() -> void:
	_meet_city()
	sim.execute({"type": "tier.promote"})
	var prog: ProgressionSystem = sim.system(&"progression")
	while prog.level < 6:
		prog.add_exp(prog.next_level_exp() - prog.experience, "test")
	(sim.system(&"economy") as EconomySystem).earn(5000, "test")
	for item: String in ["stone", "wood", "copper_ingot"]:
		(sim.system(&"inventory") as InventorySystem).add(item, 50, "test")
	var place := func(type: String, c: Vector2i) -> Dictionary:
		return sim.execute({"type": "building.place", "building": type, "anchor": [c.x, c.y]})
	assert_true(place.call("school", Vector2i(0, 2))["ok"], "first special")
	assert_true(place.call("clock_tower", Vector2i(1, 2))["ok"], "second: a city has two")
	assert_eq(place.call("momo_monument", Vector2i(2, 2))["reason"], "err.special_slots", "not a third")
	sim.advance_ms(60000)
	sim.execute({"type": "building.demolish", "id": bs.building_at(Vector2i(0, 2))})
	for item: String in ["stone", "copper_ingot"]:
		(sim.system(&"inventory") as InventorySystem).add(item, 50, "test")
	var r: Dictionary = place.call("momo_monument", Vector2i(2, 2))
	assert_true(r["ok"], "a demolition frees a slot (%s)" % r.get("reason", ""))


func test_to_the_top_and_saved() -> void:
	tiers.tier = 2
	assert_true(tiers.is_top(), "a nation is the top")
	assert_eq(tiers.special_slots(), 3, "three slots")
	assert_eq(sim.execute({"type": "tier.promote"})["reason"], "err.tier_top", "no higher")
	var copy := Simulation.from_save(JSON.parse_string(JSON.stringify(sim.save_state())))
	assert_eq((copy.system(&"tiers") as TierSystem).tier_name(), "nation", "kept across a save")
	var raw: Dictionary = JSON.parse_string(JSON.stringify(sim.save_state()))
	raw["systems"].erase("tiers")
	assert_eq((Simulation.from_save(raw).system(&"tiers") as TierSystem).tier_name(), "village", "an older save: a village")
	raw["systems"]["tiers"] = {"tier": 99}
	assert_eq((Simulation.from_save(raw).system(&"tiers") as TierSystem).tier_name(), "nation", "nonsense is clamped")


func test_a_sold_island_starts_as_a_village() -> void:
	tiers.tier = 2
	var prog: ProgressionSystem = sim.system(&"progression")
	while prog.level < sim.data.get_int("balance", "prestige.min_level", 5):
		prog.add_exp(prog.next_level_exp() - prog.experience, "test")
	var r := PrestigeSystem.sell(sim)
	assert_true(r["ok"], "sold")
	assert_eq(((r["sim"] as Simulation).system(&"tiers") as TierSystem).tier_name(), "village", "the next island is a village")


func test_korean_particles_fit_the_tier_names() -> void:
	# "{name}로 승급" and "이제 {name}예요" are right only after a vowel: every
	# tier one can promote into must end without a final consonant.
	LocaleService.apply("ko")
	for i in range(1, tiers.levels().size()):
		var n := TranslationServer.translate("tier." + tiers.tier_name(i))
		var code := n.unicode_at(n.length() - 1) - 0xAC00
		assert_true(code >= 0 and code % 28 == 0, "%s ends in a vowel" % n)
	LocaleService.apply("en")
