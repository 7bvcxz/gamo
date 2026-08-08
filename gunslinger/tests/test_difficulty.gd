extends SceneTree

## Three settings that actually differ, and differ in the direction claimed.
## A difficulty selector whose levels play the same is worse than none: it costs
## the player a decision and gives nothing back.

const MainScene := preload("res://scenes/Main.tscn")
const MainScript := preload("res://scripts/Main.gd")

func _init() -> void:
	var failures: int = 0
	var main: Node2D = MainScene.instantiate()
	root.add_child(main)

	failures += _expect(MainScript.RIVAL_MS.size(), 3, "three levels")
	failures += _expect(MainScript.DIFFICULTY_NAME.size(), 3, "three names")

	# Strictly faster each step, and by enough to feel. 50ms is about the gap
	# between two people's reaction times; below that the levels are decoration.
	for i in range(2):
		var slower: int = MainScript.RIVAL_MS[i]
		var faster: int = MainScript.RIVAL_MS[i + 1]
		failures += _expect(slower - faster >= 50, true,
			"level %d (%dms) is meaningfully faster than %d (%dms)" % [i + 1, faster, i, slower])

	# The chosen level is what the round is actually played against.
	for level: int in [0, 1, 2]:
		main.set("difficulty", level)
		main._begin_duel()
		failures += _expect(main.get("rival_ms"), MainScript.RIVAL_MS[level],
			"level %d arms the rival at %dms" % [level, MainScript.RIVAL_MS[level]])

	# A press that beats the easy rival loses to the hard one -- the levels
	# change outcomes, not just a displayed number.
	var at_ms: int = 350
	for level: int in [0, 2]:
		main.set("difficulty", level)
		main._begin_duel()
		main.set("phase", MainScript.Phase.SIGNAL)
		main.set("signal_at_ms", Time.get_ticks_msec() - at_ms)
		main.set("outcome", MainScript.Outcome.NONE)
		main._advance()
		var want: int = MainScript.Outcome.PLAYER if level == 0 else MainScript.Outcome.RIVAL
		failures += _expect(main.get("outcome"), want,
			"a %dms draw %s at level %d" % [at_ms, "wins" if level == 0 else "loses", level])

	main.free()
	print("DIFFICULTY: %s" % ("PASS" if failures == 0 else "FAIL %d" % failures))
	quit(failures)

func _expect(got, want, what: String) -> int:
	if got == want:
		return 0
	print("  FAIL: %s -- got %s, wanted %s" % [what, got, want])
	return 1
