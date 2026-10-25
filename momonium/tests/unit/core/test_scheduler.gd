extends "res://tests/framework/test_case.gd"


func test_orders_by_time_then_insertion() -> void:
	var s := Scheduler.new()
	s.schedule(500, &"a", {"n": 1})
	s.schedule(100, &"b", {"n": 2})
	s.schedule(500, &"c", {"n": 3})
	s.schedule(100, &"d", {"n": 4})
	var order: Array[String] = []
	while not s.is_empty():
		order.append(s.pop()["type"])
	assert_eq(order, ["b", "d", "a", "c"] as Array[String], "earliest first, ties in schedule order")


func test_many_events_stay_sorted() -> void:
	var s := Scheduler.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 2000:
		s.schedule(rng.randi_range(0, 10000), &"x")
	var last := -1
	var last_seq := -1
	var sorted := true
	while not s.is_empty():
		var e: Dictionary = s.pop()
		if e["at"] < last or (e["at"] == last and e["seq"] < last_seq):
			sorted = false
		last = e["at"]
		last_seq = e["seq"]
	assert_true(sorted, "2000 random events pop in (time, seq) order")


func test_save_roundtrip_keeps_order_and_sequence() -> void:
	var s := Scheduler.new()
	for at: int in [300, 100, 200, 100]:
		s.schedule(at, &"t", {"at": at})
	var copy := Scheduler.new()
	copy.load_state(JSON.parse_string(JSON.stringify(s.save_state())))
	var a: Array = []
	var b: Array = []
	while not s.is_empty():
		var e: Dictionary = s.pop()
		a.append([e["at"], e["seq"]])
	while not copy.is_empty():
		var e: Dictionary = copy.pop()
		b.append([int(e["at"]), int(e["seq"])])
	assert_eq(b, a, "a JSON round trip pops the same events in the same order")
	assert_eq(copy.schedule(1, &"t"), 4, "sequence numbering continues after load")
