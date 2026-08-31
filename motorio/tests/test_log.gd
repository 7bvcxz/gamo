extends SceneTree

## The play log: everything the game said out loud this sitting, newest first.
##
## The one thing worth pinning is where the entries come from. They are not
## written at the places that have something to say -- they are taken from
## `_notify`, which is already the single door every banner goes through. A
## second list beside the first is the arrangement this repository has watched
## go out of step every single time, and here it would fail silently: the log
## would simply be missing whatever someone forgot to add to it.

var failures := 0
var main: Node2D = null

func _init() -> void:
	main = load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_run()
	main.finish_tutorial()
	main.state = main.State.PLAY
	_run()

func _run() -> void:
	_test_notify_is_the_only_door()
	_test_newest_first()
	_test_bounded()
	_test_not_saved()
	_test_window()
	_test_unlock_banner_stays_longer()
	if failures == 0:
		print("PASS test_log")
	else:
		print("FAIL test_log (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _test_notify_is_the_only_door() -> void:
	main.play_log.clear()
	main._notify("첫 줄", Defs.COL_CORE)
	_assert(main.play_log.size() == 1, "화면에 뜬 말이 기록에 남는다")
	_assert(String(main.play_log[0]["text"]) == "첫 줄", "그대로 남는다")
	_assert(int(main.play_log[0]["day"]) == main.day_number, "며칠째였는지와 함께")
	_assert(String(main.play_log[0]["clock"]) == main.clock_text(), "몇 시였는지와 함께")

	# A real event that goes through the ordinary game code, not through _notify
	# by hand: the fire being fed. If someone later writes a message that skips
	# _notify, this is the assertion that notices.
	main.play_log.clear()
	main.sim.stock[Defs.ITEM_HEATSTONE] = 4
	main._deposit_at_core()
	_assert(main.play_log.size() >= 1, "게임이 스스로 한 말도 남는다")

	# The same line twice in a row is one event. Popups already refresh rather
	# than stack for the same reason, and a log that repeats a message every
	# frame is a log with one message in it.
	main.play_log.clear()
	main._notify("같은 말", Defs.COL_CORE)
	main._notify("같은 말", Defs.COL_CORE)
	_assert(main.play_log.size() == 1, "연달아 같은 말은 한 줄이다")

func _test_newest_first() -> void:
	main.play_log.clear()
	main._notify("하나", Defs.COL_CORE)
	main._notify("둘", Defs.COL_CORE)
	main._notify("셋", Defs.COL_CORE)
	_assert(String(main.play_log[0]["text"]) == "셋", "가장 최근이 맨 위다")
	_assert(String(main.play_log[2]["text"]) == "하나", "가장 오래된 것이 맨 아래다")

func _test_bounded() -> void:
	main.play_log.clear()
	for index in main.LOG_MAX + 60:
		main._notify("줄 %d" % index, Defs.COL_TEXT)
	_assert(main.play_log.size() == main.LOG_MAX,
		"기록은 %d줄에서 멈춘다 (%d)" % [main.LOG_MAX, main.play_log.size()])
	_assert(String(main.play_log[0]["text"]) == "줄 %d" % (main.LOG_MAX + 59),
		"넘치면 오래된 쪽이 밀려난다")

func _test_not_saved() -> void:
	main._notify("이 줄은 저장되지 않는다", Defs.COL_CORE)
	_assert(main.save_game(false), "저장된다")
	_assert(main.load_game(), "불러온다")
	# The log is a memory of this sitting, not a document. Restarting is the same
	# thing from the player's side, and that is what _start_run clears.
	main._start_run()
	_assert(main.play_log.is_empty(), "다시 시작하면 기록이 비워진다")
	main.finish_tutorial()
	main.clear_save()

func _test_window() -> void:
	main.state = main.State.PLAY
	main.log_open = false
	_assert(main.toggle_log(), "기록 창이 열린다")
	_assert(main.log_open and main.modal_open(),
		"열려 있는 동안 주인공은 입력을 받지 않는다")
	# One window at a time: two of them would both claim the arrow keys.
	main.toggle_map()
	_assert(not main.log_open, "지도를 열면 기록이 닫힌다")
	main.toggle_log()
	_assert(not main.map_open, "그 반대도 마찬가지다")
	main.toggle_log()
	_assert(not main.log_open and not main.modal_open(), "닫으면 조작이 돌아온다")
	# And a button to press, beside the map.
	main.hud._layout()
	var map_rect: Rect2 = main.hud.map_button_rect
	var log_rect: Rect2 = main.hud.log_button_rect
	_assert(log_rect.size.x > 0.0, "버튼에 자리가 있다")
	_assert(log_rect.position.x > map_rect.position.x, "지도 아이콘 오른쪽이다")
	_assert(absf(log_rect.position.y - map_rect.position.y) < 0.01, "같은 줄이다")
	_assert(not log_rect.intersects(map_rect), "겹치지 않는다")

## How long a banner stays is a property of what it says.
##
## A refusal and a machine opening used to share one constant, and 2.4 seconds
## is the right number for the refusal: it is said in reply to a key that was
## just pressed, so the player is already looking. An unlock is not a reply to
## anything -- it arrives while she is walking somewhere else -- and it changes
## what she can do next, which is the only banner in the game that does.
func _test_unlock_banner_stays_longer() -> void:
	main.messages.clear()
	main._notify("보통 알림", Defs.COL_TEXT)
	_assert(main.messages.size() == 1, "보통 알림이 하나 놓인다")
	_assert(is_equal_approx(float(main.messages[0]["life"]), main.MESSAGE_LIFE),
		"그리고 기본 수명을 갖는다")

	main.messages.clear()
	# Typed, because the parameter is `Array[int]` and an array literal is not.
	# The call fails at runtime otherwise, and a SceneTree test that dies mid-run
	# prints PASS -- the assertions after it simply never happen.
	var opened: Array[int] = [Defs.M_BELT]
	main._announce_unlocks(opened)
	_assert(main.messages.size() == 1, "해금 알림이 하나 놓인다")
	_assert(is_equal_approx(float(main.messages[0]["life"]), main.UNLOCK_MESSAGE_LIFE),
		"그리고 더 오래 머무는 수명을 갖는다")
	# The plate is solid while life is above one and fades over the last second,
	# so "five" has to mean four seconds of a banner that is simply there. A
	# number that only clears the fade would read as a flash.
	_assert(main.UNLOCK_MESSAGE_LIFE - 1.0 >= 3.0,
		"페이드 1초를 빼고도 3초 이상 또렷하게 남는다 (%.1f초)" % (main.UNLOCK_MESSAGE_LIFE - 1.0))

	# And it is still one door: the log heard it too.
	var said := false
	for entry: Dictionary in main.play_log:
		if String(entry["text"]).find("해금") >= 0:
			said = true
	_assert(said, "해금 알림도 기록에 남는다")
