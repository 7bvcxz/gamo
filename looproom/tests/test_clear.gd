extends SceneTree

## "모든 방 발견 시 클리어 화면 + 소요 시간 표시"를 검사한다.
##
## 소요 시간에서 조용히 틀리는 방법은 프레임을 세는 것이다. 60fps를 가정하고 프레임 수에
## 1/60을 곱하면 느린 기기에서 같은 플레이가 더 좋은 기록으로 나오고, 기록끼리 비교할 수
## 없게 된다. 그래서 여기서는 **같은 프레임 수를 서로 다른 delta로** 돌려 결과가 달라지는지
## 본다 -- 프레임을 세고 있으면 두 값이 같게 나온다.

const MainScene := preload("res://scenes/Main.tscn")
const MainScript := preload("res://scripts/Main.gd")
const Rooms := preload("res://scripts/Rooms.gd")

func _init() -> void:
	var failures: int = 0
	var main: Node2D = MainScene.instantiate()
	root.add_child(main)
	# `_init` 시점에는 root Window 자체가 아직 트리에 없어서 `_ready`가 미뤄진다.
	main._ready()

	failures += _test_not_cleared_at_start(main)
	failures += _test_time_is_real_time(main)
	failures += _test_last_room_clears(main)
	failures += _test_clock_stops_and_locks(main)
	failures += _test_format()

	main.free()
	print("CLEAR: %s" % ("PASS" if failures == 0 else "FAIL %d" % failures))
	quit(failures)

func _test_not_cleared_at_start(main: Node2D) -> int:
	var failures: int = _expect(main.get("cleared"), false, "시작하자마자 클리어가 아니다")
	failures += _expect(main.call("discovered_count") < Rooms.count(), true,
		"시작 시점에 못 찾은 방이 남아 있다")
	return failures

## 시계는 프레임이 아니라 실제 시간을 잰다.
func _test_time_is_real_time(main: Node2D) -> int:
	var failures: int = 0

	_reset(main)
	for i in range(100):
		main._process(0.016)
	var fast: float = main.get("elapsed")

	_reset(main)
	for i in range(100):
		main._process(0.050)
	var slow: float = main.get("elapsed")

	failures += _expect(absf(fast - 1.6) < 0.05, true, "100프레임 x 16ms = %.2f초" % fast)
	failures += _expect(absf(slow - 5.0) < 0.05, true, "100프레임 x 50ms = %.2f초" % slow)
	# 프레임을 세고 있었다면 두 값이 같다.
	failures += _expect(slow > fast * 2.0, true,
		"같은 프레임 수라도 delta가 다르면 시간이 다르다 (%.2f vs %.2f)" % [fast, slow])
	return failures

## 마지막 한 방을 채우는 순간 클리어가 되고, 그 전에는 아니다.
func _test_last_room_clears(main: Node2D) -> int:
	var failures: int = 0
	_reset(main)

	var coords: Array = Rooms.ROOMS.keys()
	for i: int in range(coords.size() - 1):
		main.call("arrive", coords[i])
		main._process(0.016)
	failures += _expect(main.get("cleared"), false,
		"%d / %d 에서는 아직 클리어가 아니다" % [main.call("discovered_count"), Rooms.count()])

	var before: float = main.get("elapsed")
	main.call("arrive", coords[coords.size() - 1])
	failures += _expect(main.get("cleared"), true, "마지막 방을 찾으면 클리어")
	failures += _expect(main.call("discovered_count"), Rooms.count(),
		"%d개를 다 찾았다" % Rooms.count())
	failures += _expect(absf(main.get("clear_time") - before) < 0.001, true,
		"기록이 그 순간의 경과 시간이다 (%.3f)" % main.get("clear_time"))
	failures += _expect(main.get("clear_time") > 0.0, true, "기록이 0이 아니다")
	return failures

## 클리어 뒤에는 시계가 멈추고 조작이 잠긴다. 안 멈추면 화면의 기록이 계속 올라간다.
func _test_clock_stops_and_locks(main: Node2D) -> int:
	var failures: int = _expect(main.get("cleared"), true, "앞 검사에서 클리어된 상태다")
	var record: float = main.get("clear_time")
	var frozen: float = main.get("elapsed")

	Input.action_press("move_right")
	var where: Vector2 = main.get("player_pos")
	for i in range(30):
		main._process(0.016)
	Input.action_release("move_right")

	failures += _expect(main.get("elapsed"), frozen, "클리어 뒤에는 시계가 멈춘다")
	failures += _expect(main.get("clear_time"), record, "기록이 바뀌지 않는다")
	failures += _expect(main.call("is_locked"), true, "클리어 화면에서는 조작이 잠긴다")
	failures += _expect(main.get("player_pos"), where, "클리어 뒤에는 움직이지 않는다")
	return failures

## 초만 쓰면 3분짜리 플레이가 "184.3"으로 나와 읽히지 않는다.
func _test_format() -> int:
	var failures: int = _expect(MainScript.format_time(0.0), "0:00.0", "0초")
	failures += _expect(MainScript.format_time(7.4), "0:07.4", "7.4초")
	failures += _expect(MainScript.format_time(65.0), "1:05.0", "1분 5초")
	failures += _expect(MainScript.format_time(184.3), "3:04.3", "3분 4.3초")
	return failures

func _reset(main: Node2D) -> void:
	main.set("discovered", {Rooms.START: true})
	main.set("cleared", false)
	main.set("clear_time", 0.0)
	main.set("elapsed", 0.0)
	main.set("current_room", Rooms.START)
	main.set("player_pos", Rooms.room_rect().get_center())
	main.set("recall_timer", 0.0)
	main.set("recall_pending", false)

func _expect(got, want, what: String) -> int:
	if got == want:
		return 0
	push_error("%s -- got %s, wanted %s" % [what, got, want])
	print("  FAIL: %s -- got %s, wanted %s" % [what, got, want])
	return 1
