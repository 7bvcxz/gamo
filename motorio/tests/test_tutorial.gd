extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await physics_frame
	_assert(main.tutorial_step == 0 and not main.tutorial_complete(), "new players start in quick start instead of the campaign")
	_assert(main.tutorial_detail().contains("WASD") and main.tutorial_detail().contains("오른쪽 이동 휠"), "movement lesson covers keyboard and mobile wheel")
	var day_before: float = main.day_time
	main.call("_update_survival", 60.0)
	_assert(is_equal_approx(main.day_time, day_before + 60.0) and main.temperature == 100.0, "the natural day clock advances during quick start while base warmth preserves temperature")
	main.tutorial_picked = true
	main.call("_refresh_tutorial")
	_assert(main.tutorial_step == 0, "actions done early are remembered without skipping the current lesson")
	main.tutorial_moved = true
	main.call("_refresh_tutorial")
	_assert(main.tutorial_step == 2 and main.tutorial_detail().contains("0.7"), "movement and pickup lead to the timed rotation lesson")
	main.tutorial_rotated = true
	main.call("_refresh_tutorial")
	_assert(main.tutorial_step == 3 and main.tutorial_detail().contains("X를 짧게"), "rotation leads to short-X placement")
	main.tutorial_placed = true
	main.call("_refresh_tutorial")
	_assert(main.tutorial_step == 4, "placement leads to base port education")
	_assert(main.tutorial_detail().contains("금색 IN") and main.tutorial_detail().contains("초록색 OUT"), "base lesson explains IN and OUT colors")
	main.tutorial_delivered = true
	main.call("_refresh_tutorial")
	_assert(main.tutorial_step == 5, "delivery leads to fabricator controls")
	_assert(main.tutorial_detail().contains("이동으로 선택") and main.tutorial_detail().contains("Z 제작") and main.tutorial_detail().contains("X 또는 Esc"), "fabricator lesson explains selection, crafting, and exit controls")
	main.tutorial_menu_opened = true
	main.call("_refresh_tutorial")
	_assert(main.tutorial_step == 6 and main.tutorial_title().contains("2단계"), "fabricator lesson leads to the first base upgrade")
	main.tutorial_base_two = true
	main.call("_refresh_tutorial")
	_assert(main.tutorial_step == 7 and main.tutorial_title().contains("3단계"), "level two leads to the second base upgrade")
	main.tutorial_base_three = true
	main.call("_refresh_tutorial")
	_assert(main.tutorial_complete(), "level three completes quick start")
	_assert(main.celebration_text.contains("기초 완료"), "completion clearly hands off to automation campaign")
	if failures == 0:
		print("TUTORIAL_TEST: PASS")
	quit(failures)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("TUTORIAL_TEST: FAIL - " + message)
		failures += 1
