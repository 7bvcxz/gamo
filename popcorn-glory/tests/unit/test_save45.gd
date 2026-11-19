extends "res://tests/framework/test_case.gd"

## Step 45: old saves come back, a save is whole or refused, and a refused save
## changes nothing. The fixtures in tests/fixtures/saves/ were written by the old
## builds themselves (fixture_gen.gd.txt run in detached worktrees of 0.12.2,
## 0.22.0 and 0.43.0) and must never change: SHA256SUMS pins them.

const Factory := preload("res://variants/factory/factory_rules.gd")
const Stand := preload("res://variants/stand/stand_rules.gd")
const Rules := preload("res://tests/unit/test_factory_rules.gd")
const DIR := "res://tests/fixtures/saves/"


func _fixture(name: String) -> String:
	return FileAccess.get_file_as_string(DIR + name)


func test_the_fixtures_are_the_ones_the_old_builds_wrote() -> void:
	var sums := _fixture("SHA256SUMS")
	var n := 0
	for line: String in sums.split("\n", false):
		var parts := line.split("  ")
		var file := parts[1].get_file()
		assert_eq(_fixture(file).sha256_text(), parts[0], "%s unchanged" % file)
		n += 1
	assert_eq(n, 4, "four fixtures")


func test_a_0_12_2_stand_save_comes_back_whole() -> void:
	for name: String in ["stand_0.12.2.json", "stand_0.43.0.json"]:
		var r := PopSaveDoc.decode(_fixture(name), "stand")
		assert_true(bool(r["ok"]), "%s reads (%s)" % [name, r.get("reason", "")])
		var raw: Dictionary = r["rules"]
		var s: PopRules = Stand.new()
		assert_true(bool(s.from_save(raw)), "%s restores" % name)
		for k: String in ["level", "money", "earned", "auto_level", "helper_batches"]:
			assert_eq(int(s.get(k)), int(raw[k]), "%s: %s kept" % [name, k])
	var s12: PopRules = Stand.new()
	s12.from_save(PopSaveDoc.decode(_fixture("stand_0.12.2.json"), "stand")["rules"])
	assert_eq(int(s12.level), 9, "the 0.12.2 stand at level 9")
	# It plays on: a press and a release on the restored stand.
	assert_true(bool(s12.execute({"type": "press"})["ok"]), "the restored stand cooks")


func test_old_factory_saves_come_back_and_conserve() -> void:
	for name: String in ["factory_0.22.0.json", "factory_0.43.0_forty.json"]:
		var r := PopSaveDoc.decode(_fixture(name), "factory")
		assert_true(bool(r["ok"]), "%s reads (%s)" % [name, r.get("reason", "")])
		var f: PopRules = Factory.new()
		assert_true(bool(f.from_save(r["rules"])), "%s restores" % name)
		assert_eq(int(f.money), int((r["rules"] as Dictionary)["money"]), "%s: money kept" % name)
		assert_eq(f.machines.size(), ((r["rules"] as Dictionary).get("machines", []) as Array).size(), "%s: every paid machine" % name)
		f.advance(120000)
		assert_eq(int(f.portions_everywhere()), int(f.stats["made_portions"]), "%s: every portion somewhere after two minutes" % name)
		assert_true(int(f.money) >= 0, "%s: no debt" % name)
	var forty: PopRules = Factory.new()
	forty.from_save(PopSaveDoc.decode(_fixture("factory_0.43.0_forty.json"), "factory")["rules"])
	assert_eq(forty.machines.size(), 44, "the 0.43.0 factory's forty-four machines")


func test_the_envelope_round_trips_and_an_old_build_still_reads_it() -> void:
	var f: PopRules = Rules.new()._forty(44, 81)
	f.advance(30000)
	var text := PopSaveDoc.encode("factory", "0.45.0", 123456, 1763500000, f.to_save())
	var r := PopSaveDoc.decode(text, "factory")
	assert_true(bool(r["ok"]), "reads back (%s)" % r.get("reason", ""))
	assert_eq(int((r["doc"] as Dictionary)["active_ms"]), 123456, "active time")
	assert_eq(int((r["doc"] as Dictionary)["saved_unix"]), 1763500000, "the last play's wall clock")
	var g: PopRules = Factory.new()
	assert_true(bool(g.from_save(r["rules"])), "restores")
	assert_eq(JSON.stringify(g.to_save()), JSON.stringify(f.to_save()), "the same factory")
	# What a 0.12-0.44 build does with it (app/main.gd before Step 45): parse, schema 1, its exp, a rules dict.
	var doc: Variant = JSON.parse_string(text)
	assert_eq(int(doc["schema"]), 1, "schema stays 1")
	assert_eq(String(doc["game"]), "popcorn-glory", "game")
	assert_eq(String(doc["exp"]), "factory", "exp")
	assert_eq(typeof(doc["rules"]), TYPE_DICTIONARY, "rules a dictionary")
	assert_true(text.ends_with("}") and text.find(",\"rules\":") > 0, "rules last")


func test_a_damaged_save_is_refused_with_its_reason() -> void:
	var f: PopRules = Rules.new()._forty(20, 81)
	var text := PopSaveDoc.encode("factory", "0.45.0", 1000, 1, f.to_save())
	var at := text.find("\"money\":") + 8
	var edited := text.substr(0, at) + "9" + text.substr(at)
	assert_eq(String(PopSaveDoc.decode(edited, "factory")["reason"]), "checksum", "an edited number")
	assert_eq(String(PopSaveDoc.decode(text.substr(0, text.length() - 40), "factory")["reason"]), "not_json", "cut short")
	assert_eq(String(PopSaveDoc.decode("", "factory")["reason"]), "empty", "empty")
	assert_eq(String(PopSaveDoc.decode(text, "stand")["reason"]), "other_experiment", "the stand does not take the factory's save")
	assert_eq(String(PopSaveDoc.decode(text.replace("\"game\":\"popcorn-glory\"", "\"game\":\"momo\""), "factory")["reason"]), "foreign", "another game")
	assert_eq(String(PopSaveDoc.decode(text.replace("\"schema\":1", "\"schema\":2"), "factory")["reason"]), "newer_schema", "a newer schema")
	assert_eq(String(PopSaveDoc.decode("[1,2]", "factory")["reason"]), "not_json", "not an object")


## Each damage adds up (conservation holds) but is not a factory play can make.
func test_a_save_out_of_bounds_is_refused_and_changes_nothing() -> void:
	var f: PopRules = Rules.new()._forty(44, 81)
	f.advance(20000)
	var good: Dictionary = JSON.parse_string(JSON.stringify(f.to_save()))
	var cases := ["a machine twice", "two in one place", "a place that does not exist", "an unknown machine",
		"a machine on another floor", "money past 2^53", "a tier from nowhere", "an id of zero"]
	var g: PopRules = Factory.new()
	var before := JSON.stringify(g.to_save())
	for label: String in cases:
		var d: Dictionary = good.duplicate(true)
		_damage(label, d)
		assert_false(bool(g.from_save(d)), "refused: %s" % label)
		assert_eq(JSON.stringify(g.to_save()), before, "nothing applied: %s" % label)
	assert_true(bool(g.from_save(good.duplicate(true))), "the undamaged save restores")


func _damage(label: String, d: Dictionary) -> void:
	var ms: Array = d["machines"]
	match label:
		"a machine twice":
			ms.append((ms[0] as Dictionary).duplicate(true))
		"two in one place":
			for k: String in ["slot", "floor", "type"]:
				ms[1][k] = ms[0][k]
		"a place that does not exist":
			ms[0]["slot"] = 99
		"an unknown machine":
			ms[0]["type"] = "Z99"
		"a machine on another floor":
			ms[0]["floor"] = "shop" if String(ms[0]["floor"]) != "shop" else "kitchen"
		"money past 2^53":
			d["money"] = 1.0e17
		"a tier from nowhere":
			ms[0]["tier"] = 40
		"an id of zero":
			ms[0]["id"] = 0


## A save cut at the worst moments of a 44-machine factory: a pack on the station,
## a serve on its way to a customer, lots on the lift. The restored factory goes on
## exactly as the one that was never saved -- nothing sold twice, nothing lost.
func test_a_save_mid_pack_and_mid_serve_goes_on_the_same() -> void:
	var a: PopRules = Rules.new()._forty(44, 83)
	var t := 0
	var cut := false
	while t < 600000 and not cut:
		a.advance(250)
		t += 250
		cut = not a.packing.is_empty() and not a.serves.is_empty() and not a.lift.is_empty()
	assert_true(cut, "found a moment with a pack, a serve and a lift in flight (%d ms)" % t)
	var b: PopRules = Rules.new()._steady(Factory.new())
	var r := PopSaveDoc.decode(PopSaveDoc.encode("factory", "t", t, 0, a.to_save()), "factory")
	assert_true(bool(r["ok"]) and bool(b.from_save(r["rules"])), "saved mid-flight, through the envelope")
	var sold_before := int(a.stats["sold"])
	a.advance(180000)
	b.advance(180000)
	assert_eq(JSON.stringify(b.to_save()), JSON.stringify(a.to_save()), "the restored factory goes on exactly the same")
	assert_true(int(b.stats["sold"]) > sold_before, "and keeps selling")
	assert_eq(int(b.portions_everywhere()), int(b.stats["made_portions"]), "every portion somewhere")
