extends "res://tests/framework/test_case.gd"

## Experiment D's field (HarvestLevels): every Bigger Field shows (more cells
## or golden crops) and pays more a harvest; the first harvest in 15-30 s of
## a first launch, several harvest-and-upgrade loops in three minutes, with
## the second and third payouts clearly bigger than the first.


func test_every_upgrade_shows_and_pays_more() -> void:
	for n in range(1, 16):
		assert_true(HarvestLevels.visible_change(n), "level %d changes the field" % n)
		assert_true(HarvestLevels.payout(n) > HarvestLevels.payout(n - 1), "level %d pays more a harvest" % n)
		assert_true(HarvestLevels.cost(n + 1) > HarvestLevels.cost(n), "level %d+1 costs more" % n)
	assert_eq(HarvestLevels.plants(0), 8, "eight plants at first")
	assert_eq(HarvestLevels.payout(0), 16, "sixteen coins a harvest")


func test_the_pace() -> void:
	var s := HarvestLevels.simulate(180.0, 1.0)
	var h: Array = s["harvests"]
	assert_between(float(h[0][0]), 14.0, 30.0, "the first harvest")
	assert_true(h.size() >= 10, "many harvests in three minutes (%d)" % h.size())
	assert_true((s["upgrades"] as Array).size() >= 5, "several upgrades (%d)" % (s["upgrades"] as Array).size())
	assert_true(int(h[2][1]) >= 2 * int(h[0][1]), "the third payout at least twice the first (%d vs %d)" % [int(h[2][1]), int(h[0][1])])
	assert_true(int(h[h.size() - 1][1]) >= 6 * int(h[0][1]), "the last payout of three minutes is far bigger")


func test_the_field_is_its_cells() -> void:
	for n in 12:
		var f: Array = HarvestLevels.row(n)["field"]
		assert_eq(HarvestLevels.cells(n).size(), int(f[0]) * int(f[1]), "level %d's cells" % n)
		assert_eq(HarvestLevels.plants(n), HarvestLevels.cells(n).size() * HarvestLevels.PLANTS_PER_CELL, "two plants a cell")
