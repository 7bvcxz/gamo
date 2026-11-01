extends "res://tests/framework/test_case.gd"

## Step 79: only the game on screen moves. A frame advances the island by its
## own time, at most max_frame; in the background nothing; the first frame
## back nothing (a browser hands over the hidden time as one frame); going
## and coming are each said once.

func test_on_screen_a_frame_is_its_time_at_most_max_frame() -> void:
	var s := PlaySession.new()
	s.max_frame = 0.5
	assert_true(s.foreground, "on screen from the start")
	assert_near(s.step(0.016), 0.016, 0.0001, "a frame's own time")
	assert_near(s.step(0.3), 0.3, 0.0001, "a slow frame in full")
	assert_near(s.step(42.0), 0.5, 0.0001, "a stall counts at most half a second")
	assert_near(s.step(-1.0), 0.0, 0.0001, "never backwards")


func test_the_background_stands_still_and_the_first_frame_back_too() -> void:
	var s := PlaySession.new()
	assert_true(s.hide(1000.0), "gone to the background: a change")
	assert_false(s.hide(1001.0), "said once (visibilitychange and pagehide both come)")
	for d: float in [0.016, 1.0, 3600.0]:
		assert_eq(s.step(d), 0.0, "in the background: no time (%.3f s frame)" % d)
	assert_true(s.show(1060.0), "back: a change")
	assert_false(s.show(1061.0), "said once")
	assert_eq(s.step(60.0), 0.0, "the first frame back carries the whole hidden minute: none of it counts")
	assert_near(s.step(0.016), 0.016, 0.0001, "then frames as before")
	assert_eq([s.pauses, s.resumes], [1, 1], "one pause, one resume")
	assert_near(s.away_seconds, 60.0, 0.0001, "a minute away, noted (never credited)")


func test_a_session_with_many_switches_counts_only_what_was_seen() -> void:
	var s := PlaySession.new()
	var seen := 0.0
	var wall := 0.0
	for i in 20:
		for f in 30:
			seen += s.step(1.0 / 30.0)
			wall += 1.0 / 30.0
		s.hide(wall)
		wall += 600.0
		s.show(wall)
		seen += s.step(600.0)
	assert_near(seen, 20.0, 0.001, "twenty seconds on screen, 200 minutes away: twenty seconds of game")
	assert_near(s.away_seconds, 20 * 600.0, 0.01, "the time away, apart")
