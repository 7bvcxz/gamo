extends SceneTree

## Two minutes of freezing is a handful of quiet sounds, not a noise (World
## Visual Pass 01).
##
## Counted against the slowest pace the brief allows, never two chills within
## the rule's gap, never on top of the step-down frost, quieter than anything
## she does with her hands, and the takes rotated so the same recording is not
## struck twice running.

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
	_test_two_minutes()
	main.clear_save()
	main.free()
	if failures == 0:
		print("PASS test_cold_sound_does_not_spam")
	else:
		print("FAIL test_cold_sound_does_not_spam (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _test_two_minutes() -> void:
	Ear.out_in_the_cold(main)
	main.player.warmth = 30.0
	var from: int = Ear.chills(main)
	var frost_before: int = int(main.audio.started.get("frost", 0))
	Ear.run(main, 120.0, -0.3, 5.0)
	var log: Array = (main.audio.chill_log as Array).slice(from)
	_assert(log.size() <= int(120.0 / 4.0) + 1, "2분에 %d번 이하 (%d번)" % [int(120.0 / 4.0) + 1, log.size()])
	_assert(log.size() >= 10, "그래도 들린다 (%d번)" % log.size())
	var crowded := 0
	for index in range(1, log.size()):
		if float(log[index]) - float(log[index - 1]) < 3.5:
			crowded += 1
	_assert(crowded == 0, "3.5초 안에 두 번 나는 일이 없다 (%d건)" % crowded)
	for sound: String in ["chill", "chill_hard"]:
		_assert(float(AudioScript.VOLUMES[sound]) <= float(AudioScript.VOLUMES["breath"]),
			"%s 는 숨소리보다 크지 않다" % sound)
		_assert(float(AudioScript.VOLUMES[sound]) < float(AudioScript.VOLUMES["pick"]), "%s 는 곡괭이보다 작다" % sound)
	var takes: Array = main.audio.take_log.get("chill_hard", [])
	var repeats := 0
	for index in range(1, takes.size()):
		if takes[index] == takes[index - 1]:
			repeats += 1
	_assert(repeats == 0, "같은 녹음이 연달아 울리지 않는다")
	# The step-down frost and a chill never land in the same breath.
	_assert(int(main.audio.started.get("frost", 0)) - frost_before <= 1, "얼음 소리는 단계가 바뀔 때 한 번뿐")
