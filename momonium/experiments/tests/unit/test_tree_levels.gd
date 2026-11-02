extends "res://tests/framework/test_case.gd"

## Experiment F's stages (TreeLevels) and their shapes (TreeView.build): every
## stage costs more and makes more, the first change comes in 10-30 s and
## many shapes inside three minutes, and each stage's shape differs from the
## one before in more than size -- the silhouette changes.

const LOOK := 20


func test_costs_and_income_rise() -> void:
	for n in range(1, LOOK):
		assert_true(TreeLevels.cost(n + 1) > TreeLevels.cost(n), "cost %d" % (n + 1))
		assert_true(TreeLevels.rate(n) > TreeLevels.rate(n - 1), "rate %d" % n)


func test_the_pace() -> void:
	var t := TreeLevels.instant_times(LOOK)
	assert_between(t[1], 10.0, 30.0, "the first change")
	var within := 0
	for n in t.size():
		if t[n] <= 180.0:
			within = n
	assert_true(within >= 8, "many shapes within three minutes (%d)" % within)
	for n in range(1, within + 1):
		assert_true(t[n] - t[n - 1] <= 30.0, "a change at least every 30 s (stage %d: %.1f s)" % [n, t[n] - t[n - 1]])


## What makes a silhouette: the crown's kind, how it branches, twin trunks,
## a twist, and what hangs on it -- never the size alone.
func _signature(s: Dictionary) -> Array:
	var g := TreeView.build(s, 7)
	return [String(s.get("crown", "")), int(s.get("depth", 0)), int(s.get("kids", 2)), bool(s.get("twin", false)),
		float(s.get("twist", 0.0)) > 0.0, int(s.get("blossom", 0)) > 0, int(s.get("fruit", 0)) > 0, bool(s.get("glow", false)),
		int(s.get("lanterns", 0)) > 0, bool(s.get("house", false)), bool(s.get("clouds", false)), bool(s.get("rainbow", false)),
		(s["leaf"] as Color).to_html(false), (g["segs"] as Array).size(), (g["tips"] as Array).size()]


func test_every_stage_changes_the_silhouette() -> void:
	for n in range(1, LOOK):
		var a := _signature(TreeLevels.stage(n - 1))
		var b := _signature(TreeLevels.stage(n))
		var differ := 0
		for i in a.size():
			if a[i] != b[i]:
				differ += 1
		assert_true(differ >= 2, "stage %d (%s) differs from %d in more than one way: %s vs %s" % [n, TreeLevels.stage(n)["name"], n - 1, a, b])


func test_the_tree_grows_taller() -> void:
	var last := 0.0
	for n in LOOK:
		var g := TreeView.build(TreeLevels.stage(n), 1000 + n)
		var height := -float(g["top"])
		assert_true(height > last, "stage %d is taller (%.0f > %.0f)" % [n, height, last])
		last = height


func test_the_same_shape_draws_the_same_tree() -> void:
	var a := TreeView.build(TreeLevels.stage(6), 1006)
	var b := TreeView.build(TreeLevels.stage(6), 1006)
	assert_eq(var_to_str(a), var_to_str(b), "deterministic")
