extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await physics_frame
	_assert(main.tutorial_step == 0 and not main.tutorial_complete(), "new players start in quick start instead of the campaign")
	_assert(main.tutorial_detail().contains("WASD") and main.tutorial_detail().contains("RIGHT"), "movement lesson covers keyboard and mobile wheel")
	main.call("_update_survival", 60.0)
	_assert(main.day_time == 0.0 and main.temperature == 100.0, "the survival clock and cold wait until quick start is complete")
	main.tutorial_picked = true
	main.call("_refresh_tutorial")
	_assert(main.tutorial_step == 0, "actions done early are remembered without skipping the current lesson")
	main.tutorial_moved = true
	main.call("_refresh_tutorial")
	_assert(main.tutorial_step == 2 and main.tutorial_detail().contains("0.7"), "movement and pickup lead to the timed rotation lesson")
	main.tutorial_rotated = true
	main.call("_refresh_tutorial")
	_assert(main.tutorial_step == 3 and main.tutorial_detail().contains("Tap X"), "rotation leads to short-X placement")
	main.tutorial_placed = true
	main.call("_refresh_tutorial")
	_assert(main.tutorial_step == 4, "placement leads to base port education")
	_assert(main.tutorial_detail().contains("gold IN") and main.tutorial_detail().contains("Green OUT"), "base lesson explains input and output colors")
	main.tutorial_delivered = true
	main.call("_refresh_tutorial")
	_assert(main.tutorial_step == 5, "delivery leads to fabricator controls")
	_assert(main.tutorial_detail().contains("X SELECT") and main.tutorial_detail().contains("Z CRAFT") and main.tutorial_detail().contains("RUN/Esc CLOSE"), "fabricator lesson explains every menu action")
	main.tutorial_menu_opened = true
	main.call("_refresh_tutorial")
	_assert(main.tutorial_complete(), "opening the fabricator completes quick start")
	_assert(main.celebration_text.contains("BASICS COMPLETE"), "completion clearly hands off to automation campaign")
	if failures == 0:
		print("TUTORIAL_TEST: PASS")
	quit(failures)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("TUTORIAL_TEST: FAIL - " + message)
		failures += 1
