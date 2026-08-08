extends SceneTree

## The wait, checked as a distribution rather than as one draw. A single round
## landing inside 2-6s would also pass if the code returned a constant, and a
## constant is the failure that matters here -- a signal you can time is not a
## signal.

const MainScene := preload("res://scenes/Main.tscn")
const MainScript := preload("res://scripts/Main.gd")

func _init() -> void:
	var failures: int = 0
	var main: Node2D = MainScene.instantiate()
	root.add_child(main)

	var waits: Array[float] = []
	for i in range(200):
		main._begin_duel()
		waits.append(main.get("wait_left"))

	var low: float = waits.min()
	var high: float = waits.max()
	failures += _expect(low >= MainScript.WAIT_MIN, true,
		"never shorter than %.1fs (saw %.3f)" % [MainScript.WAIT_MIN, low])
	failures += _expect(high <= MainScript.WAIT_MAX, true,
		"never longer than %.1fs (saw %.3f)" % [MainScript.WAIT_MAX, high])
	# Spread across most of the range, which a constant or a near-constant fails.
	failures += _expect(high - low > 3.0, true,
		"spread over the range (saw %.2fs)" % (high - low))

	# The signal fires only when the wait runs out, and not before.
	main._begin_duel()
	main.set("wait_left", 0.30)
	main._process(0.10)
	failures += _expect(main.get("phase"), MainScript.Phase.STEADY, "quiet at 0.10s")
	main._process(0.10)
	failures += _expect(main.get("phase"), MainScript.Phase.STEADY, "quiet at 0.20s")
	main._process(0.15)
	failures += _expect(main.get("phase"), MainScript.Phase.SIGNAL, "fires past the wait")
	failures += _expect(main.get("signal_at_ms") > 0, true, "stamps the clock when it fires")

	# A press before the signal ends the round as a foul. This assertion used to
	# say the opposite and was right at the time -- the foul rule came later.
	# Behaviour tests describe the game, so changing the game dates them.
	main._begin_duel()
	main.set("wait_left", 5.0)
	main._advance()
	failures += _expect(main.get("outcome"), MainScript.Outcome.FOUL, "early press is a foul")

	# What this file is actually about: the signal itself never arrives early.
	main._begin_duel()
	main.set("wait_left", 5.0)
	for i in range(120):
		main._process(0.016)
	failures += _expect(main.get("phase"), MainScript.Phase.STEADY,
		"still quiet ~2s into a 5s wait")

	main.free()
	print("SIGNAL: %s" % ("PASS" if failures == 0 else "FAIL %d" % failures))
	quit(failures)

func _expect(got, want, what: String) -> int:
	if got == want:
		return 0
	print("  FAIL: %s -- got %s, wanted %s" % [what, got, want])
	return 1
