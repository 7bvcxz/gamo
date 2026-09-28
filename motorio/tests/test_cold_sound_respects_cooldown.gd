extends SceneTree

## The chill keeps its distance (World Visual Pass 01): four to eight seconds
## apart, randomised, never on a fixed beat, and never within the rule's gap.

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
	# Rates that never reach the floor in ninety seconds: a lift back up is a
	# frame of warming, which rightly resets the wait and is not what this reads.
	_test_gaps(90.0, -0.3, 55.0, 6.0, 8.0, "추위")
	_test_gaps(24.9, -0.2, 5.0, 4.0, 5.5, "위험")
	main.clear_save()
	main.free()
	if failures == 0:
		print("PASS test_cold_sound_respects_cooldown")
	else:
		print("FAIL test_cold_sound_respects_cooldown (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _test_gaps(warmth: float, rate: float, floor: float, low: float, high: float, name: String) -> void:
	Ear.out_in_the_cold(main)
	main.player.warmth = warmth
	var from: int = Ear.chills(main)
	Ear.run(main, 90.0, rate, floor)
	var log: Array = (main.audio.chill_log as Array).slice(from)
	_assert(log.size() >= 8, "%s: 90초에 여러 번 (%d번)" % [name, log.size()])
	var shortest := 1e9
	var longest := 0.0
	var gaps: Dictionary = {}
	for index in range(1, log.size()):
		var gap: float = float(log[index]) - float(log[index - 1])
		shortest = minf(shortest, gap)
		longest = maxf(longest, gap)
		gaps[snappedf(gap, 0.1)] = true
	var frame: float = Ear.DT + 0.001
	_assert(shortest >= low - frame, "%s: 간격이 %.1f초 이상이다 (최소 %.2f)" % [name, low, shortest])
	_assert(longest <= high + frame, "%s: 간격이 %.1f초 이하다 (최대 %.2f)" % [name, high, longest])
	_assert(gaps.size() >= 3, "%s: 간격이 일정한 박자가 아니다 (%d가지)" % [name, gaps.size()])
