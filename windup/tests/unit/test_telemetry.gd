extends "res://tests/framework/test_case.gd"

## Events are {t, ev, ...} on the game clock, and come out as JSON lines.


func test_events_carry_game_time_and_fields() -> void:
	var clock := GameClock.new()
	var t := Telemetry.new(clock)
	t.emit("session_start", {"seed": 1})
	clock.advance(0.25)
	clock.advance(0.25)
	var e := t.emit("wind", {"source": "click"})
	assert_eq(e["t"], 0.5, "game time")
	assert_eq(e["ev"], "wind", "name")
	assert_eq(e["source"], "click", "field")
	assert_eq(t.count("wind"), 1, "count")
	assert_eq(t.first("session_start")["seed"], 1, "first")


func test_paused_time_is_not_counted() -> void:
	var clock := GameClock.new()
	var t := Telemetry.new(clock)
	clock.advance(0.1)
	clock.set_paused("focus", true)
	clock.advance(0.2)
	assert_eq(t.emit("x")["t"], 0.1, "paused seconds excluded")


func test_jsonl_round_trips() -> void:
	var clock := GameClock.new()
	var t := Telemetry.new(clock)
	t.emit("a", {"n": 2})
	t.emit("b")
	var lines := t.to_jsonl().split("\n")
	assert_eq(lines.size(), 2, "one line per event")
	var parsed: Dictionary = JSON.parse_string(lines[0])
	assert_eq(parsed["ev"], "a", "event name")
	assert_eq(int(parsed["n"]), 2, "field")


func test_limit_drops_oldest_but_counts_all() -> void:
	var t := Telemetry.new(GameClock.new())
	for i in Telemetry.LIMIT + 3:
		t.emit("wind")
	assert_eq(t.events.size(), Telemetry.LIMIT, "kept")
	assert_eq(t.dropped, 3, "dropped")
	assert_eq(t.count("wind"), Telemetry.LIMIT + 3, "count includes dropped")
