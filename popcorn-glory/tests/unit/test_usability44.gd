extends "res://tests/framework/test_case.gd"

## Step 44: the hand is not starved by its own machines (factory_rules.hand_reserve).
## At forty-four machines the packers are the bottleneck and the bin is full most of the time;
## the machines' small lots used to take every gap, so the hand's glass waited and the kettle
## refused almost every press (Step 43's soak: 19 tries in 20). Now the bin keeps the room the
## glass needs. The same test runs the old rule (hand_first = false) and must see it starve,
## so this test fails on the 0.43.0 rules.

const Factory := preload("res://variants/factory/factory_rules.gd")
const Rules := preload("res://tests/unit/test_factory_rules.gd")


func _forty(hand_first: bool) -> PopRules:
	var f: PopRules = Factory.new(null, 81)
	f.economy.table("factory")["reputation"]["arrival_effect"] = 0.0
	f.economy.table("factory")["news"] = {}
	f.hand_first = hand_first
	f.packer_tier = 3
	f.sign_tier = 8
	f.level = 6
	f.money = 1 << 30
	f.stats["packed"] = maxi(1, int(f.stats["packed"]))
	f.stats["sold"] = maxi(1, int(f.stats["sold"]))
	for row: Array in Rules.FORTY_PLAN:
		if f.machines.size() >= 44:
			break
		var floor := String(row[1])
		if f.floor_full(floor) and int(f.line_cost(floor)) >= 0:
			f.execute({"type": "buy_line", "floor": floor})
		if String(row[0]) == "U08" and not f.parallel_lines():
			continue
		f.execute({"type": "build", "machine": row[0], "floor": floor})
	return f


## Five minutes: every 1.5 s the hand tries to pop (a Perfect when the kettle lets it).
func _play(f: PopRules) -> Dictionary:
	var tries := 0
	var refused := 0
	var pops := 0
	var longest := 0
	for k in 200:
		f.advance(1500)
		if bool(f.heating) or int(f.cooldown_left) > 0:
			continue
		tries += 1
		var r := f.execute({"type": "press"})
		if not bool(r["ok"]):
			refused += 1
			longest = maxi(longest, int(f.glass_held_ms))
			continue
		f.advance(f.window_start() + 10)
		f.execute({"type": "release"})
		pops += 1
	return {"tries": tries, "refused": refused, "pops": pops, "longest_ms": longest, "packed": int(f.stats["packed"]),
		"sold": int(f.stats["sold"]), "made": int(f.stats["made_portions"]), "everywhere": int(f.portions_everywhere())}


func test_the_hand_pops_in_a_full_factory_and_the_old_rule_starved_it() -> void:
	var f := _forty(true)
	assert_eq(f.machines.size(), 44, "forty-four machines")
	var now := _play(f)
	var old := _play(_forty(false))
	print("  hand_first: %s" % JSON.stringify(now))
	print("  old rule:   %s" % JSON.stringify(old))
	assert_true(float(old["refused"]) / float(old["tries"]) > 0.6, "the old rule refused most presses (%d of %d)" % [old["refused"], old["tries"]])
	# (tries every 1.5 s while the lot waits count as refused: the wait, not the rate, is the measure)
	assert_true(int(old["longest_ms"]) > 120000, "the old rule kept the glass waiting minutes (%d ms)" % old["longest_ms"])
	assert_true(int(now["pops"]) >= 5 * maxi(1, int(old["pops"])), "five times the pops at least (%d vs %d)" % [now["pops"], old["pops"]])
	assert_true(int(now["longest_ms"]) < 20000, "the glass never waits 20 s (%d ms)" % now["longest_ms"])
	# The factory as a whole is not slowed: the packers are the bottleneck either way.
	assert_true(int(now["sold"]) >= int(int(old["sold"]) * 0.97), "sales within 3%% of the old rule (%d vs %d)" % [now["sold"], old["sold"]])
	assert_eq(int(now["everywhere"]), int(now["made"]), "every portion made is somewhere")
	assert_true(f.bin_portions() + f.coating_portions() <= int(f.state()["bin_cap"]), "the bin within its size")


func test_an_empty_glass_reserves_nothing() -> void:
	var f := _forty(true)
	assert_eq(f.hand_reserve(), 0, "no lot waiting, no room kept")
	f.glass = {"id": 999999, "recipe": "plain", "quality": 100, "portions": 3}
	assert_false(f._bin_draining(), "a factory just built packs nothing yet")
	assert_eq(f.hand_reserve(), 0, "nothing packing: no room kept (the machines may fill -- no dead factory)")
	f.packing = [{"id": 1}]   # (a pack on the station: the bin is draining)
	assert_eq(f.hand_reserve(), 3, "a small lot keeps its own size")
	f.glass["portions"] = int(f.bin_cap()) + 5
	assert_eq(f.hand_reserve(), 1, "a lot bigger than the bin pours into any room")
	f.glass = {}
	f.packing = []


## The flavors34 factory (two kettles, a hopper, the base mixer; sprayer cheese, coater caramel,
## sprayer spicy, coater cocoa), the hand releasing early every 5 s for ten minutes. Seed 22
## is one of 2 in 40 where the cocoa coater, built last, got no batch at all in build order:
## the coaters ahead of it took every four plain portions the bin ever held.
func _flavor_floor(fair: bool) -> Dictionary:
	var f: PopRules = Factory.new(null, 22)
	f.coater_fair = fair
	f.sign_tier = 6
	f.packer_tier = 3
	f.money = 200000
	f.stats["packed"] = maxi(1, int(f.stats["packed"]))
	f.stats["sold"] = maxi(1, int(f.stats["sold"]))
	for t in ["cooker", "cooker", "M01", "M12"]:
		f.execute({"type": "build", "machine": t, "floor": "kitchen"})
	var ids := []
	for t in ["P05", "P06", "P05", "P06"]:
		assert_true(bool(f.execute({"type": "build", "machine": t, "floor": "packing"})["ok"]), "%s built" % t)
		ids.append(f.machines[f.machines.size() - 1]["id"])
	assert_true(bool(f.execute({"type": "set_flavor", "id": ids[2], "flavor": "spicy"})["ok"]), "spicy set")
	assert_true(bool(f.execute({"type": "set_flavor", "id": ids[3], "flavor": "cocoa"})["ok"]), "cocoa set")
	for i in 120:
		if not bool(f.heating) and f.glass.is_empty() and int(f.cooldown_left) <= 0:
			if bool(f.execute({"type": "press"})["ok"]):
				f.advance(int(f.window_start() * 0.6))
				f.execute({"type": "release"})
		f.advance(5000)
	return {"coated": (f.stats.get("coated", {}) as Dictionary).duplicate(), "sold": int(f.stats["sold"])}


func test_the_coater_built_last_is_not_starved_by_the_ones_before_it() -> void:
	var now := _flavor_floor(true)
	var old := _flavor_floor(false)
	print("  fair: %s  build order: %s" % [JSON.stringify(now), JSON.stringify(old)])
	assert_eq(int(old["coated"].get("cocoa", 0)), 0, "the old build order starved the cocoa coater (this test fails on the 0.43.0 rules)")
	assert_true(int(now["coated"].get("cocoa", 0)) >= 4, "the coater that waited longest goes first: cocoa is coated")
	for fl in ["cheese", "caramel", "spicy"]:
		assert_true(int(now["coated"].get(fl, 0)) >= 4, "%s is still coated" % fl)
