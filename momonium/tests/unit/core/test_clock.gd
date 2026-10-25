extends "res://tests/framework/test_case.gd"


func test_day_numbering_and_rollover() -> void:
	var clock := SimClock.new(30000)
	assert_eq(clock.day_number(), 1, "a game starts on Day 1")
	clock.now_ms = 29999
	assert_eq(clock.day_number(), 1, "29.999 s is still Day 1")
	assert_eq(clock.time_in_day_ms(), 29999, "time in day")
	clock.now_ms = 30000
	assert_eq(clock.day_number(), 2, "30 s exactly is Day 2")
	assert_eq(clock.time_in_day_ms(), 0, "and Day 2 starts at 0")
	clock.now_ms = 30000 * 99 + 15000
	assert_eq(clock.day_number(), 100, "Day 100")
	assert_near(clock.day_progress(), 0.5, 0.0001, "halfway through the day")
	assert_eq(clock.next_day_start_ms(), 30000 * 100, "next boundary")


func test_save_roundtrip() -> void:
	var clock := SimClock.new(30000)
	clock.now_ms = 123456
	var other := SimClock.new(30000)
	other.load_state(clock.save_state())
	assert_eq(other.now_ms, 123456, "now survives a save")
