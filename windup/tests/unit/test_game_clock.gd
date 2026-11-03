extends "res://tests/framework/test_case.gd"

## The one clock: moves only through advance, never while paused, never by a
## whole hidden-tab gap in one frame.


func test_advance_moves_time() -> void:
	var c := GameClock.new()
	assert_near(c.advance(0.1), 0.1, 1e-9, "used")
	c.advance(0.2)
	assert_near(c.time, 0.3, 1e-9, "time")


func test_paused_clock_does_not_move() -> void:
	var c := GameClock.new()
	c.advance(1.0 / 60.0)
	var before := c.time
	assert_true(c.set_paused("focus", true), "paused changed")
	assert_eq(c.advance(0.2), 0.0, "nothing used while paused")
	assert_eq(c.time, before, "time held")
	assert_false(c.set_paused("hidden", true), "second reason: still paused, no change")
	assert_false(c.set_paused("focus", false), "one reason left")
	assert_true(c.paused, "still paused by hidden")
	assert_true(c.set_paused("hidden", false), "running again")
	c.advance(0.1)
	assert_near(c.time, before + 0.1, 1e-9, "moves after resume")


func test_one_step_is_capped() -> void:
	var c := GameClock.new()
	assert_eq(c.advance(30.0), GameClock.MAX_STEP, "a 30 s frame counts as MAX_STEP")
	assert_eq(c.time, GameClock.MAX_STEP, "time")


func test_reset_clears_time_and_pauses() -> void:
	var c := GameClock.new()
	c.advance(0.2)
	c.set_paused("manual", true)
	c.reset()
	assert_eq(c.time, 0.0, "time")
	assert_false(c.paused, "pause reasons cleared")
