extends SceneTree

## The freezing sound comes back for as long as she keeps freezing (World Visual
## Pass 01). It used to play once, as she left the warm, and never again.
##
## Forty seconds out on the snow with her warmth falling: the chill is heard
## again and again, at the cold step's pace, and the danger step's is closer.

const Ear := preload("res://tests/helpers/cold_ear.gd")
const AudioScript := preload("res://scripts/Audio.gd")

var failures := 0
var main: Node2D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	main = load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	_test_cold()
	_test_danger()
	main.clear_save()
	main.free()
	if failures == 0:
		print("PASS test_cold_sound_repeats_while_temperature_falls")
	else:
		print("FAIL test_cold_sound_repeats_while_temperature_falls (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _test_cold() -> void:
	Ear.out_in_the_cold(main)
	main.player.warmth = 90.0
	var before: int = Ear.chills(main)
	# Cold step (exposure 0.45 out here), falling slowly.
	Ear.run(main, 40.0, -0.5, 55.0)
	var heard: int = Ear.chills(main) - before
	_assert(heard >= 4, "추위 속 40초 동안 추위 소리가 여러 번 난다 (%d번)" % heard)
	_assert(int(main.audio.started.get("chill", 0)) >= 4, "추위 단계의 소리다")

func _test_danger() -> void:
	Ear.out_in_the_cold(main)
	main.player.warmth = 22.0
	var before: int = Ear.chills(main)
	Ear.run(main, 40.0, -0.3, 5.0)
	var heard: int = Ear.chills(main) - before
	_assert(heard >= 6, "위험 단계에서는 더 자주 난다 (%d번)" % heard)
	_assert(int(main.audio.started.get("chill_hard", 0)) >= 6, "위험 단계의 소리다")
	_assert(float(AudioScript.VOLUMES["chill_hard"]) > float(AudioScript.VOLUMES["chill"]),
		"위험 단계가 조금 더 크다")
