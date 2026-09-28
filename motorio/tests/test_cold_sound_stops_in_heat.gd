extends SceneTree

## Back in the fire's warmth, the chill stops at once (World Visual Pass 01) --
## the one sounding is cut, and none comes while she warms up, however cold she
## still is. And out in the snow standing still with her warmth not falling
## (full, or held), it does not come either: it is the sound of freezing, not of
## being outside.

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
	_test_back_to_the_fire()
	_test_not_falling()
	main.clear_save()
	main.free()
	if failures == 0:
		print("PASS test_cold_sound_stops_in_heat")
	else:
		print("FAIL test_cold_sound_stops_in_heat (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _test_back_to_the_fire() -> void:
	Ear.out_in_the_cold(main)
	main.player.warmth = 40.0
	Ear.run(main, 15.0, -0.4, 10.0)
	_assert(Ear.chills(main) > 0, "(바깥에서 추위 소리가 났다)")
	# Into the warm ground, still cold, warming up.
	main.player.position = main.sim.core_centre() + Vector2(0.0, Grid.px(3.0))
	_assert(main.sim.is_warm(main.player.cell()), "(온기 안이다)")
	var before: int = Ear.chills(main)
	Ear.run(main, 0.2, 2.0)
	_assert(main.audio.sounding("chill") == 0 and main.audio.sounding("chill_hard") == 0,
		"온기에 들어서면 울리던 추위 소리가 멎는다")
	Ear.run(main, 30.0, 2.0)
	_assert(Ear.chills(main) == before, "온기 안에서 몸이 녹는 동안 추위 소리가 없다 (%d번)" % (Ear.chills(main) - before))
	# Warm ground at night: the night drains her even here, and it is still not
	# the snow taking her.
	var still: int = Ear.chills(main)
	main.player.warmth = 60.0
	Ear.run(main, 20.0, -0.5, 20.0)
	_assert(Ear.chills(main) == still, "온기 안에서는 체온이 떨어져도 추위 소리가 없다")

func _test_not_falling() -> void:
	Ear.out_in_the_cold(main)
	main.player.warmth = 70.0
	var before: int = Ear.chills(main)
	Ear.run(main, 30.0, 0.0)
	_assert(Ear.chills(main) == before, "체온이 그대로면 바깥에 서 있어도 추위 소리가 없다")
