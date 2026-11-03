extends "res://tests/framework/test_case.gd"

## WindInput: a press is a turn, holding repeats after the delay, the last
## release is "let go".


func test_hold_repeats_after_the_delay() -> void:
	var w := WindInput.new(Balance.load_default())
	w.press("click")
	assert_true(w.holding(), "held")
	assert_eq(w.advance(w.hold_delay - 0.01), 0, "nothing during the delay")
	assert_eq(w.advance(0.01), 0, "the delay is over, the first repeat is 1/rate later")
	assert_eq(w.advance(1.001), 5, "then 5 a second")
	assert_true(w.release("click"), "last release lets go")
	assert_false(w.holding(), "not held")
	assert_eq(w.advance(1.0), 0, "no turns after letting go")


func test_two_sources_let_go_only_when_both_are_up() -> void:
	var w := WindInput.new(Balance.load_default())
	w.press("click")
	w.press("key")
	assert_false(w.release("click"), "space still holds")
	assert_true(w.release("key"), "now let go")
	assert_false(w.release("key"), "a second release is not another let-go")


func test_dev_presses_are_taps() -> void:
	var w := WindInput.new(Balance.load_default())
	w.press("dev")
	assert_false(w.holding(), "a dev press never holds")
	w.press("click")
	assert_true(w.release_all(), "release_all reports a hold")
	assert_false(w.release_all(), "and only once")


func test_hold_hint_only_for_slow_clickers_who_never_held() -> void:
	var slow: Array = []
	for i in 12:
		slow.append(2.0 + i * 2.0)              # a press every 2 s
	assert_true(WindInput.wants_hold_hint(slow, 24.0, false, false), "slow, never held, 20 s in: show it")
	assert_false(WindInput.wants_hold_hint(slow, 15.0, false, false), "not before 20 s")
	assert_false(WindInput.wants_hold_hint(slow, 24.0, true, false), "not after they have held")
	assert_false(WindInput.wants_hold_hint(slow, 24.0, false, true), "not once the first doll is up")
	var fast: Array = []
	for i in 100:
		fast.append(2.0 + i * 0.25)             # 4 a second
	assert_false(WindInput.wants_hold_hint(fast, 26.0, false, false), "not for someone clicking fast")
