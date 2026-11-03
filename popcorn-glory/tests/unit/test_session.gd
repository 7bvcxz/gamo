extends "res://tests/framework/test_case.gd"

## The local record: milestones once each, idle gaps of five seconds or more,
## a summary at three minutes, CSV that survives quotes.

const StubRules := preload("res://variants/stub/stub_rules.gd")


func test_milestones_come_once_in_order() -> void:
	var s := PopSession.new("stub")
	var r: PopRules = StubRules.new()
	s.observe(0, r)
	s.record_input(2000, "press")
	r.now_ms = 2000
	r.execute({"type": "press"})
	s.record_events(r.drain_events())
	s.record_input(2100, "press")
	assert_eq(int(s.milestones["first_input"]), 2000, "first input")
	assert_eq(int(s.milestones["first_earn"]), 2000, "first earn")
	assert_false(s.milestones.has("first_affordable"), "not yet")
	r.money = 10
	s.observe(9000, r)
	assert_eq(int(s.milestones["first_affordable"]), 9000, "affordable")
	s.observe(9500, r)
	assert_eq(int(s.milestones["first_affordable"]), 9000, "only once")
	s.observe(180000, r)
	assert_true(s.milestones.has("three_minutes"), "three minutes")


func test_idle_gaps_of_five_seconds_or_more() -> void:
	var s := PopSession.new("stub")
	s.record_input(1000, "press")
	s.record_input(5900, "press")
	assert_eq(s.idle_total_ms, 0, "4.9 s is not idle")
	s.record_input(11900, "press")
	assert_eq(s.idle_total_ms, 6000, "6 s idle")
	s.record_input(31900, "press")
	assert_eq(s.idle_longest_ms, 20000, "longest 20 s")
	var r: PopRules = StubRules.new()
	var sum := s.summary(40000, r)
	assert_eq(int(sum["idle_total_ms"]), 26000 + 8100, "the open gap at the end counts too")


func test_csv_escapes_quotes() -> void:
	var s := PopSession.new("stub")
	s.record(5, "note", {"say": "a \"quoted\" word"})
	var csv := s.to_csv()
	assert_true(csv.begins_with("t_ms,type,data\n"), "header")
	assert_true(csv.contains("\"{\"\"say\"\":"), "the JSON's quotes doubled inside one quoted field: %s" % csv.replace("\n", " | "))
	assert_eq(csv.split("\n", false).size(), 2, "header + one line")
