extends "res://tests/framework/test_case.gd"

## Experiment A's economy and what each upgrade shows (IslandLevels): costs and
## income rise, every upgrade changes the island, and the pace the issue asks
## for -- first upgrade in 10-30 s, three stages inside three minutes, the
## bigger milestone just after -- holds when every upgrade is bought at once.

const LOOK := 16


func test_costs_and_income_rise() -> void:
	for n in range(1, LOOK):
		assert_true(IslandLevels.cost(n + 1) > IslandLevels.cost(n), "cost %d > %d" % [n + 1, n])
		assert_true(IslandLevels.rate(n) > IslandLevels.rate(n - 1), "rate %d > %d" % [n, n - 1])
	assert_eq(IslandLevels.rate(0), 1.0, "a coin a second at the start")


func test_every_upgrade_changes_what_is_seen() -> void:
	for n in range(1, LOOK):
		var cells_before := IslandLevels.cells(n - 1).size()
		var change := IslandLevels.cells(n).size() > cells_before \
			or IslandLevels.props(n).size() > IslandLevels.props(n - 1).size() \
			or IslandLevels.momos(n).size() > IslandLevels.momos(n - 1).size() \
			or IslandLevels.field(n) != IslandLevels.field(n - 1) \
			or IslandLevels.paths(n).size() > IslandLevels.paths(n - 1).size()
		assert_true(change, "level %d adds something visible" % n)
		assert_true(LabAtlas.has(String(IslandLevels.row(n)["icon"])), "level %d's button picture exists" % n)


func test_the_pace() -> void:
	var t := IslandLevels.instant_times(LOOK)
	assert_between(t[1], 10.0, 30.0, "the first upgrade")
	var stages := {}
	var upgrades := 0
	for n in t.size():
		if t[n] <= 180.0:
			stages[IslandLevels.stage(n)] = true
			upgrades = n
	assert_true(stages.size() >= 3, "three stages within three minutes: %s" % [stages.keys()])
	assert_true(upgrades >= 6, "several upgrades within three minutes (%d)" % upgrades)
	var m := IslandLevels.MONUMENT_LEVEL
	assert_eq(IslandLevels.stage(m), "monument", "the milestone's level")
	assert_between(t[m], 180.0, 240.0, "the bigger milestone comes just after three minutes")
	for n in range(1, m + 1):
		assert_true(t[n] - t[n - 1] <= 35.0, "never a long wait before %d (%.1f s)" % [n, t[n] - t[n - 1]])
	assert_true(t[m] - t[m - 1] > t[m - 1] - t[m - 2], "the milestone takes longer than the step before it")


func test_things_stand_on_land_and_never_share_a_cell() -> void:
	for n in LOOK:
		var land := {}
		for c: Vector2i in IslandLevels.cells(n):
			land[c] = true
		var used := {}
		for p: Array in IslandLevels.props(n):
			var c: Vector2i = p[1]
			assert_true(land.has(c), "level %d: %s stands on land %s" % [n, p[0], c])
			assert_false(used.has(c), "level %d: one thing on %s" % [n, c])
			used[c] = true
		for c: Vector2i in IslandLevels.FIELD_CELLS:
			assert_false(used.has(c), "the field is free")
		for c: Vector2i in IslandLevels.momos(n):
			assert_true(land.has(c), "level %d: a Momo on land %s" % [n, c])
		for c: Vector2i in IslandLevels.paths(n):
			assert_true(land.has(c) and not used.has(c), "level %d: a path on free land %s" % [n, c])


func test_the_endless_coast_is_new_land() -> void:
	var land := {}
	for c: Vector2i in IslandLevels.cells(IslandLevels.LEVELS.size() - 1):
		land[c] = true
	for c: Vector2i in IslandLevels.ENDLESS_RING:
		assert_false(land.has(c), "%s is new coast" % c)
		land[c] = true
	assert_eq(IslandLevels.ENDLESS_RING.size(), land.size() - IslandLevels.cells(IslandLevels.LEVELS.size() - 1).size(), "no repeats")
