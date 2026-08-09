extends SceneTree

## "회귀 시 전용 연출(화면 효과 0.5초 이상)이 표시된다"를 검사한다.
##
## 시간만 재면 반쪽이다. 연출이 도는 동안 조작이 살아 있으면 플레이어는 닫힌 화면
## 뒤에서 걸어가 있게 되고, 연출이 끝난 자리가 어디인지 알 수 없다. 그리고 연출이
## 끝나지 않으면 그건 연출이 아니라 멈춤이다 -- 이 저장소가 이미 한 번 겪었다.

const MainScene := preload("res://scenes/Main.tscn")
const MainScript := preload("res://scripts/Main.gd")
const Rooms := preload("res://scripts/Rooms.gd")

const FRAME := 0.016

func _init() -> void:
	var failures: int = 0
	var main: Node2D = MainScene.instantiate()
	root.add_child(main)
	# `_init` 시점에는 root Window 자체가 아직 트리에 없어서 `_ready`가 다음 프레임으로
	# 미뤄진다. 테스트는 그 프레임까지 가지 않고 끝나므로 직접 부른다 -- 이걸 빼면
	# `_ready`가 하는 초기화(시작 방 발견, 시작 위치)가 통째로 검사되지 않는다.
	main._ready()

	failures += _expect(MainScript.RECALL_TIME >= 0.5, true,
		"연출 길이 %.2f초 >= 0.5초" % MainScript.RECALL_TIME)

	failures += _test_runs_and_ends(main)
	failures += _test_locked_while_playing(main)
	failures += _test_room_changes_when_closed(main)
	failures += _test_not_restartable_midway(main)

	main.free()
	print("RECALL: %s" % ("PASS" if failures == 0 else "FAIL %d" % failures))
	quit(failures)

## 시작하면 실제로 돌고, 상한 안에 반드시 끝난다.
func _test_runs_and_ends(main: Node2D) -> int:
	var failures: int = 0
	main.set("current_room", Vector2i(3, 0))
	main.set("player_pos", Rooms.room_rect().get_center())
	main.call("recall")

	failures += _expect(main.get("recall_timer") > 0.0, true, "연출이 시작된다")
	failures += _expect(main.call("is_locked"), true, "연출 중에는 잠긴다")

	var elapsed: float = 0.0
	# 넉넉한 상한을 두고 그 안에 끝나는지 본다. 끝나지 않는 연출은 멈춤이다.
	while main.get("recall_timer") > 0.0 and elapsed < 5.0:
		main.call("advance_recall", FRAME)
		elapsed += FRAME

	failures += _expect(elapsed >= 0.5, true, "실제로 %.2f초 이상 돌았다" % elapsed)
	failures += _expect(elapsed < 5.0, true, "상한 안에 끝난다 (%.2f초)" % elapsed)
	failures += _expect(main.call("is_locked"), false, "끝나면 잠금이 풀린다")
	failures += _expect(main.get("current_room"), Rooms.START, "끝나면 시작 방에 있다")
	return failures

## 연출 중에는 입력이 있어도 움직이지 않는다.
func _test_locked_while_playing(main: Node2D) -> int:
	var failures: int = 0
	main.set("current_room", Vector2i(3, 0))
	main.set("player_pos", Rooms.room_rect().get_center())
	main.call("recall")

	Input.action_press("move_left")
	var before: Vector2 = main.get("player_pos")
	for i in range(6):
		main._process(FRAME)
	var after: Vector2 = main.get("player_pos")
	Input.action_release("move_left")

	# 셔터가 닫히기 전 구간이라 방은 아직 안 바뀌었고, 그 사이 걸어가지도 않았다.
	failures += _expect(after, before, "연출 중 입력해도 제자리")

	while main.get("recall_timer") > 0.0:
		main.call("advance_recall", FRAME)
	return failures

## 방이 바뀌는 순간은 화면이 다 닫힌 뒤여야 한다. 먼저 바뀌면 함정 방이 아니라
## 시작 방이 어두워지는 것이 보인다.
func _test_room_changes_when_closed(main: Node2D) -> int:
	var failures: int = 0
	var from := Vector2i(3, 0)
	main.set("current_room", from)
	main.set("player_pos", Rooms.room_rect().get_center())
	main.call("recall")

	var changed_at: float = -1.0
	while main.get("recall_timer") > 0.0:
		main.call("advance_recall", FRAME)
		if changed_at < 0.0 and main.get("current_room") != from:
			changed_at = main.call("recall_progress")

	failures += _expect(changed_at >= 0.0, true, "연출 도중 방이 바뀐다")
	failures += _expect(changed_at >= MainScript.RECALL_CLOSE, true,
		"셔터가 닫힌 뒤에 바뀐다 (진행도 %.2f)" % changed_at)
	failures += _expect(changed_at < 1.0, true,
		"연출이 끝나기 전에 바뀐다 (진행도 %.2f)" % changed_at)
	failures += _expect(main.get("recall_from"), from, "번쩍일 색은 함정을 밟은 방의 것")
	return failures

## 연출 중에 다시 회귀가 걸리면 타이머가 되감겨 영영 끝나지 않을 수 있다.
func _test_not_restartable_midway(main: Node2D) -> int:
	main.set("current_room", Vector2i(3, 0))
	main.call("recall")
	for i in range(10):
		main.call("advance_recall", FRAME)
	var mid: float = main.get("recall_timer")
	main.call("recall")
	var after: float = main.get("recall_timer")

	var failures: int = _expect(after <= mid, true, "연출 중 재시작으로 되감기지 않는다")
	while main.get("recall_timer") > 0.0:
		main.call("advance_recall", FRAME)
	return failures

func _expect(got, want, what: String) -> int:
	if got == want:
		return 0
	push_error("%s -- got %s, wanted %s" % [what, got, want])
	print("  FAIL: %s -- got %s, wanted %s" % [what, got, want])
	return 1
