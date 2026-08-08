extends SceneTree

## Drawing before the signal. The rule exists to make waiting cost something --
## without it, holding the button down from the first frame wins every round and
## the reaction never happens.

const MainScene := preload("res://scenes/Main.tscn")
const MainScript := preload("res://scripts/Main.gd")

func _init() -> void:
	var failures: int = 0
	var main: Node2D = MainScene.instantiate()
	root.add_child(main)

	# Pressing at any point during the wait is a loss, not just near the end.
	for left: float in [5.9, 3.0, 0.05]:
		main._begin_match()
		main.set("wait_left", left)
		main._advance()
		failures += _expect(main.get("outcome"), MainScript.Outcome.FOUL,
			"press with %.2fs left is a foul" % left)
		failures += _expect(main.get("state"), MainScript.State.RESULT,
			"a foul ends the round immediately")

	# Mashing cannot win: the strategy the rule exists to defeat.
	main._begin_match()
	for i in range(40):
		main._advance()
		if main.get("state") == MainScript.State.RESULT:
			break
	failures += _expect(main.get("outcome"), MainScript.Outcome.FOUL, "mashing fouls out")

	# And the honest path still works after a foul.
	main._begin_match()
	main.set("phase", MainScript.Phase.SIGNAL)
	main.set("signal_at_ms", Time.get_ticks_msec() - 90)
	main.set("outcome", MainScript.Outcome.NONE)
	main._advance()
	failures += _expect(main.get("outcome"), MainScript.Outcome.PLAYER, "a clean draw still wins")

	main.free()
	print("FOUL: %s" % ("PASS" if failures == 0 else "FAIL %d" % failures))
	quit(failures)

func _expect(got, want, what: String) -> int:
	if got == want:
		return 0
	print("  FAIL: %s -- got %s, wanted %s" % [what, got, want])
	return 1
