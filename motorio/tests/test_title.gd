extends SceneTree

## The title's menu.
##
## Any key used to start a game, which meant "I want to change the controls
## first" and "I want the run I was on" were the same keypress -- and which of
## the two happened was decided by whether a save file existed, not by the
## player.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_rows()
	if failures == 0:
		print("TITLE: PASS")
	else:
		print("TITLE: FAIL (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _test_rows() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main.state = main.State.TITLE

	# Deleting the file is enough. It used not to be: `resumed` stayed true, so
	# the menu offered to continue a run whose save had just been thrown away.
	_assert(not main.resumed, "세이브를 지우면 이어할 것도 없어진다")

	# No save, no 이어하기. A row that is present and refuses teaches the player
	# to skip past the row.
	var fresh: Array[int] = main.title_menu()
	_assert(not fresh.has(main.MENU_CONTINUE), "세이브가 없으면 이어하기가 없다")
	_assert(fresh.has(main.MENU_NEW) and fresh.has(main.MENU_SETTINGS),
		"처음부터와 설정은 항상 있다")
	_assert(fresh[0] == main.MENU_NEW, "그때는 처음부터가 첫 줄이다")

	main.resumed = true
	var saved: Array[int] = main.title_menu()
	_assert(saved[0] == main.MENU_CONTINUE, "세이브가 있으면 이어하기가 첫 줄이다")
	_assert(saved.size() == fresh.size() + 1, "줄이 하나 늘어날 뿐이다")

	# The cursor wraps, and every row is reachable.
	main.title_index = 0
	var seen := {}
	for _step in saved.size():
		seen[main.title_choice()] = true
		main.title_step(1)
	_assert(seen.size() == saved.size(), "위아래로 모든 줄에 닿는다: %d/%d"
		% [seen.size(), saved.size()])
	_assert(main.title_index == 0, "그리고 한 바퀴 돌면 처음으로 돌아온다")
	main.title_step(-1)
	_assert(main.title_index == saved.size() - 1, "위로 가면 끝으로 감긴다")

	# What each row does.
	main.title_index = saved.find(main.MENU_CONTINUE)
	main.title_confirm()
	_assert(main.state == main.State.PLAY, "이어하기는 하던 게임으로 들어간다")

	main.state = main.State.TITLE
	main.title_index = saved.find(main.MENU_SETTINGS)
	main.title_confirm()
	_assert(main.state == main.State.SETTINGS, "설정은 설정을 연다")
	_assert(main.state_before_settings == main.State.TITLE, "그리고 돌아올 곳을 기억한다")
	main.close_settings()
	_assert(main.state == main.State.TITLE, "닫으면 타이틀로 돌아온다")

	# 처음부터 clears the file. Leaving it in place meant the next launch offered
	# to continue a run the player had already thrown away.
	main.save_game(false)
	_assert(FileAccess.file_exists(main.SAVE_PATH), "세이브가 있는 상태를 만든다")
	main.resumed = true
	main.title_index = main.title_menu().find(main.MENU_NEW)
	main.title_confirm()
	_assert(main.state == main.State.OPENING, "처음부터는 컷씬으로 간다")
	_assert(not main.resumed, "그리고 이어할 것이 없어진다")
	_assert(not main.title_menu().has(main.MENU_CONTINUE),
		"메뉴에서도 이어하기가 사라진다")

	# The rows are laid out where they are hit-tested. One geometry, so the
	# picture and the touch cannot disagree about where 처음부터 is.
	main.state = main.State.TITLE
	main.resumed = true
	var hud: Node = main.hud
	for index in main.title_menu().size():
		var box: Rect2 = hud.call("title_menu_rect", index)
		_assert(int(hud.call("title_menu_at", box.get_center())) == index,
			"%d번째 줄을 누르면 그 줄이 잡힌다" % index)
		_assert(box.position.x >= 0.0 and box.position.x + box.size.x <= hud.size.x,
			"%d번째 줄이 화면 안에 있다" % index)
	_assert(int(hud.call("title_menu_at", Vector2(2.0, 2.0))) < 0,
		"딴 곳을 누르면 어떤 줄도 아니다")

	main.clear_save()
	main.free()
