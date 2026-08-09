extends SceneTree

## "../motorio-oneshot의 Grim 캐릭터를 주인공으로 사용"을 검사한다.
##
## 시트를 preload 하는 것만으로는 부족하다. 이 저장소가 스프라이트에서 실제로 겪은
## 문제는 전부 "불러와지긴 하는데 자리가 틀린" 종류였다: 셀 경계를 넘어가는 프레임,
## 프레임마다 다른 발 위치, 반전할 때 반 픽셀 밀리는 기준점. 그래서 여기서는 셀 산술과
## 반전 축을 직접 잰다.
##
## 그리고 파일이 `looproom/assets/` 안에 있어야 한다. `../motorio-oneshot`을 가리키면
## `res://` 밖이라 Web export에 들어가지 않고, 처음 clone한 상태에서 실행되지 않는다.

const MainScene := preload("res://scenes/Main.tscn")
const MainScript := preload("res://scripts/Main.gd")
const Rooms := preload("res://scripts/Rooms.gd")

func _init() -> void:
	var failures: int = 0
	var main: Node2D = MainScene.instantiate()
	root.add_child(main)
	# `_init` 시점에는 root Window 자체가 아직 트리에 없어서 `_ready`가 미뤄진다.
	main._ready()

	failures += _test_sheets_are_local()
	failures += _test_cell_arithmetic()
	failures += _test_facing_picks_sheet(main)
	failures += _test_west_mirrors_east(main)
	failures += _test_frames_advance(main)

	main.free()
	print("GRIM: %s" % ("PASS" if failures == 0 else "FAIL %d" % failures))
	quit(failures)

## 시트가 이 프로젝트 안에 있고, 실제로 128 x 8 배치다.
func _test_sheets_are_local() -> int:
	var failures: int = 0
	var sheets := {
		"idle_s": MainScript.IDLE_S, "walk_s": MainScript.WALK_S,
		"walk_e": MainScript.WALK_E, "walk_n": MainScript.WALK_N,
	}
	for name: String in sheets.keys():
		var sheet: Texture2D = sheets[name]
		failures += _expect(sheet != null, true, "%s 시트가 있다" % name)
		if sheet == null:
			continue
		failures += _expect(sheet.get_height(), int(MainScript.CELL),
			"%s 높이가 셀 한 칸" % name)
		failures += _expect(sheet.get_width(),
			int(MainScript.CELL) * MainScript.SHEET_FRAMES,
			"%s 폭이 셀 x %d프레임" % [name, MainScript.SHEET_FRAMES])
		failures += _expect(sheet.resource_path.begins_with("res://assets/"), true,
			"%s 가 이 프로젝트 안에 있다 (%s)" % [name, sheet.resource_path])
	return failures

## 마지막 프레임이 시트 밖으로 나가면 안 된다. 셀 산술이 한 칸이라도 어긋나면
## 마지막 프레임에서 빈 칸이나 잘린 그림이 나온다.
func _test_cell_arithmetic() -> int:
	var last: float = float(MainScript.SHEET_FRAMES - 1) * MainScript.CELL
	var failures: int = _expect(last + MainScript.CELL,
		MainScript.CELL * float(MainScript.SHEET_FRAMES), "마지막 프레임이 시트 안에 맞는다")
	# 발 기준점은 셀 안에 있고, x는 정확히 셀 중앙이어야 반전이 어긋나지 않는다.
	failures += _expect(MainScript.FOOT_ANCHOR.x, MainScript.CELL * 0.5,
		"발 기준점 x가 셀 정중앙")
	failures += _expect(MainScript.FOOT_ANCHOR.y < MainScript.CELL, true,
		"발 기준점 y가 셀 안")
	return failures

## 방향마다 맞는 시트가 나와야 한다. 서쪽 시트는 없고 동쪽을 뒤집는다.
func _test_facing_picks_sheet(main: Node2D) -> int:
	var failures: int = 0
	main.set("moving", true)

	failures += _expect(main.call("sheet_for", Vector2.DOWN), MainScript.WALK_S, "남쪽")
	failures += _expect(main.call("sheet_for", Vector2.UP), MainScript.WALK_N, "북쪽")
	failures += _expect(main.call("sheet_for", Vector2.RIGHT), MainScript.WALK_E, "동쪽")
	failures += _expect(main.call("sheet_for", Vector2.LEFT), MainScript.WALK_E,
		"서쪽도 동쪽 시트를 쓴다")
	failures += _expect(main.call("flip_for", Vector2.LEFT), true, "서쪽은 뒤집는다")
	failures += _expect(main.call("flip_for", Vector2.RIGHT), false, "동쪽은 안 뒤집는다")
	failures += _expect(main.call("flip_for", Vector2.DOWN), false, "남쪽은 안 뒤집는다")
	failures += _expect(main.call("flip_for", Vector2.UP), false, "북쪽은 안 뒤집는다")

	# 대각선은 더 큰 성분을 따른다. 어느 쪽도 아닌 상태가 생기면 시트가 깜빡인다.
	failures += _expect(main.call("sheet_for", Vector2(0.9, 0.4)), MainScript.WALK_E,
		"동남쪽은 옆모습")
	failures += _expect(main.call("sheet_for", Vector2(0.4, -0.9)), MainScript.WALK_N,
		"북동쪽은 뒷모습")

	# 서 있을 때 남쪽은 전용 대기 시트를 쓴다.
	main.set("moving", false)
	failures += _expect(main.call("sheet_for", Vector2.DOWN), MainScript.IDLE_S,
		"남쪽으로 서 있으면 대기 시트")
	return failures

## 반전 축이 발 기준점이어야 한다. 셀 중심으로 뒤집으면 발이 옆으로 밀린다.
## 기준점 x가 셀 정중앙이므로 두 값은 같아야 한다.
func _test_west_mirrors_east(main: Node2D) -> int:
	var half: float = MainScript.CELL * 0.5
	var failures: int = _expect(MainScript.FOOT_ANCHOR.x, half,
		"반전 축과 셀 중심선이 일치한다")
	# 뒤집힌 셀의 왼쪽 끝이 안 뒤집힌 셀의 오른쪽 끝과 기준점에서 같은 거리에 있다.
	var left_edge: float = -MainScript.FOOT_ANCHOR.x * MainScript.SPRITE_SCALE
	var right_edge: float = (MainScript.CELL - MainScript.FOOT_ANCHOR.x) * MainScript.SPRITE_SCALE
	failures += _expect(absf(left_edge) - absf(right_edge), 0.0,
		"기준점에서 양쪽 끝까지 거리가 같다")
	return failures

## 걸을 때는 프레임이 돌고, 서 있을 때는 (남쪽 대기를 빼면) 멈춘다.
func _test_frames_advance(main: Node2D) -> int:
	var failures: int = 0
	main.set("facing", Vector2.RIGHT)
	main.set("moving", true)

	var seen := {}
	for i: int in range(MainScript.SHEET_FRAMES * 3):
		main.set("anim_time", float(i) / MainScript.ANIM_FPS)
		var f: int = main.call("frame_index")
		failures += _expect(f >= 0 and f < MainScript.SHEET_FRAMES, true,
			"프레임 번호 %d 가 범위 안" % f)
		seen[f] = true
	failures += _expect(seen.size(), MainScript.SHEET_FRAMES,
		"걸으면 %d프레임을 전부 쓴다" % MainScript.SHEET_FRAMES)

	# 옆을 보고 서 있으면 첫 프레임에 머문다. 걷기 프레임을 제자리에서 돌리면
	# 발이 땅을 긁는 것처럼 보인다.
	main.set("moving", false)
	main.set("anim_time", 3.7)
	failures += _expect(main.call("frame_index"), 0, "옆을 보고 서 있으면 첫 프레임")

	# 남쪽 대기는 전용 시트라 계속 돈다.
	main.set("facing", Vector2.DOWN)
	var idle_seen := {}
	for i: int in range(MainScript.SHEET_FRAMES * 3):
		main.set("anim_time", float(i) / MainScript.ANIM_FPS)
		idle_seen[main.call("frame_index")] = true
	failures += _expect(idle_seen.size(), MainScript.SHEET_FRAMES,
		"남쪽 대기는 호흡 프레임이 돈다")
	return failures

func _expect(got, want, what: String) -> int:
	if got == want:
		return 0
	push_error("%s -- got %s, wanted %s" % [what, got, want])
	print("  FAIL: %s -- got %s, wanted %s" % [what, got, want])
	return 1
