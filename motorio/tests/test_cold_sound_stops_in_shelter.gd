extends SceneTree

## Through the hut's door the chill stops (World Visual Pass 01), and it does not
## come asleep, on a paused game, or on the game-over card either.

const Ear := preload("res://tests/helpers/cold_ear.gd")

var failures := 0
var main: Node2D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	main = load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	_test_shelter()
	_test_paused()
	_test_game_over()
	main.clear_save()
	main.free()
	if failures == 0:
		print("PASS test_cold_sound_stops_in_shelter")
	else:
		print("FAIL test_cold_sound_stops_in_shelter (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _test_shelter() -> void:
	Ear.out_in_the_cold(main)
	main.player.warmth = 40.0
	Ear.run(main, 12.0, -0.4, 10.0)
	_assert(Ear.chills(main) > 0, "(바깥에서 추위 소리가 났다)")
	main.player.position = main.shelter_doorstep()
	main.open_room()
	_assert(main.sim.indoors, "(숙소 안이다)")
	var before: int = Ear.chills(main)
	# Even if something in the room made her colder, the room is not the cold.
	Ear.run(main, 30.0, -0.3, 10.0)
	_assert(Ear.chills(main) == before, "숙소 안에서는 추위 소리가 없다 (%d번)" % (Ear.chills(main) - before))
	_assert(main.audio.sounding("chill") == 0 and main.audio.sounding("chill_hard") == 0,
		"울리던 소리도 없다")
	main.close_room()

func _test_paused() -> void:
	Ear.out_in_the_cold(main)
	main.player.warmth = 40.0
	Ear.run(main, 10.0, -0.4, 10.0)
	main.state_before_settings = main.State.PLAY
	main.state = main.State.SETTINGS
	var before: int = Ear.chills(main)
	Ear.run(main, 30.0, -0.4, 10.0)
	_assert(Ear.chills(main) == before, "일시정지(설정) 중에는 추위 소리가 없다")
	main.state = main.State.PLAY

func _test_game_over() -> void:
	Ear.out_in_the_cold(main)
	main.player.warmth = 20.0
	Ear.run(main, 6.0, -0.4, 5.0)
	main.state = main.State.GAMEOVER
	var before: int = Ear.chills(main)
	Ear.run(main, 20.0, -0.4, 5.0)
	_assert(Ear.chills(main) == before, "게임오버 화면에서는 추위 소리가 없다")
	main.state = main.State.PLAY
