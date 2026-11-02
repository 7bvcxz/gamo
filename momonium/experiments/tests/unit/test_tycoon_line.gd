extends "res://tests/framework/test_case.gd"

## Experiment E's line (TycoonLine, TycoonLevels): every item is delivered
## once and in order, never closer than SPACING to the one ahead; each level
## raises what the line delivers; the machine's arms really work in
## parallel; and the pace -- the first improvement in 10-30 s, several in
## three minutes.


func _line(n: int) -> TycoonLine:
	var l := TycoonLine.new()
	l.configure(TycoonLevels.row(n))
	return l


func test_each_item_is_delivered_once_and_in_order() -> void:
	var l := _line(8)
	var last_by_lane := {}
	for i in 2400:
		l.advance(0.05)
		for lane in l.lanes:
			var xs: Array = l.items.filter(func(it: Dictionary) -> bool: return int(it["lane"]) == lane and not bool(it["in"])).map(func(it: Dictionary) -> float: return float(it["x"]))
			xs.sort()
			for k in range(1, xs.size()):
				if float(xs[k]) - float(xs[k - 1]) < TycoonLine.SPACING - 0.001:
					fail("lane %d: two items closer than SPACING (%s)" % [lane, xs])
					return
		for it: Dictionary in l.just_delivered:
			assert_true(int(it["id"]) > int(last_by_lane.get(int(it["lane"]), 0)), "delivered in order")
			last_by_lane[int(it["lane"])] = int(it["id"])
			assert_true(bool(it["done"]), "only worked items are delivered")
	assert_true(l.delivered > 100, "it delivered (%d)" % l.delivered)
	var seen := {}
	for id: int in l.delivered_ids:
		assert_false(seen.has(id), "item %d delivered once" % id)
		seen[id] = true
	assert_eq(l.coins_made, l.delivered * l.value, "coins are deliveries times value")
	assert_eq(l.spawned, l.delivered + l.items.size(), "nothing lost, nothing made twice")


func test_every_level_delivers_more() -> void:
	var last := 0.0
	for n in 12:
		var l := _line(n)
		l.advance(60.0)
		var d0 := l.coins_made
		l.advance(60.0)
		var rate := float(l.coins_made - d0) / 60.0
		assert_true(rate > last, "level %d (%s) earns more: %.2f > %.2f a second" % [n, TycoonLevels.row(n)["name"], rate, last])
		last = rate


func test_arms_work_in_parallel() -> void:
	var one := TycoonLine.new()
	var two := TycoonLine.new()
	var row := TycoonLevels.row(1).duplicate()
	row["spawn"] = 0.5
	one.configure(row)
	row["arms"] = 2
	two.configure(row)
	one.advance(120.0)
	two.advance(120.0)
	assert_true(two.delivered > one.delivered * 1.6, "two arms nearly double a machine-bound line (%d vs %d)" % [two.delivered, one.delivered])


func test_the_pace() -> void:
	var s := TycoonLevels.simulate(180.0, 1.5)
	var ups: Array = s["upgrades"]
	assert_between(float(ups[0]), 10.0, 30.0, "the first improvement")
	assert_true(ups.size() >= 6, "several in three minutes (%d)" % ups.size())
	for i in range(1, ups.size()):
		assert_true(float(ups[i]) - float(ups[i - 1]) <= 32.0, "never a long wait (%.1f s before %d)" % [float(ups[i]) - float(ups[i - 1]), i + 1])


func test_every_level_shows() -> void:
	for n in range(1, 14):
		var a := TycoonLevels.row(n - 1)
		var b := TycoonLevels.row(n)
		var shows := false
		for k: String in ["lanes", "arms", "helpers", "machine", "product", "speed", "spawn"]:
			if a.get(k) != b.get(k):
				shows = true
		assert_true(shows or String(b["show"]) == "sparkle", "level %d changes something on the line" % n)
