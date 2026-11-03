extends "res://tests/framework/test_case.gd"

## Active play time: whole milliseconds, a frame never counts more than a
## quarter second, and it stops while any pause reason is set.


func test_frames_add_whole_milliseconds_without_drift() -> void:
	var c := PopClock.new()
	var total := 0
	for i in 600:
		total += c.step(1.0 / 60.0)
	assert_eq(total, c.now_ms, "the sum of steps is the clock")
	assert_between(float(c.now_ms), 9999.0, 10000.0, "600 frames at 60 fps = 10 s")


func test_a_long_frame_counts_for_a_quarter_second() -> void:
	var c := PopClock.new()
	assert_eq(c.step(30.0), 250, "a 30 s gap (a hidden tab's first frame) is 250 ms")


func test_pauses_have_reasons() -> void:
	var c := PopClock.new()
	c.set_pause("hidden", true)
	c.set_pause("dev", true)
	assert_eq(c.step(0.1), 0, "paused")
	c.set_pause("hidden", false)
	assert_eq(c.step(0.1), 0, "still paused by the other reason")
	c.set_pause("dev", false)
	assert_eq(c.step(0.1), 100, "runs again")


func test_add_ms_is_exact() -> void:
	var c := PopClock.new()
	c.step(0.0105)
	c.add_ms(1000)
	assert_eq(c.now_ms, 1010, "10 + 1000")
	assert_eq(c.step(0.0004), 0, "the half millisecond kept from before + 0.4 ms: not yet whole")
	assert_eq(c.step(0.0002), 1, "+ 0.2 ms: now whole")
