extends SceneTree

## Who wins, and whether the number shown is a real measurement.
##
## The clock is faked by moving signal_at_ms rather than by sleeping, so the test
## runs instantly and, more importantly, deterministically -- a test that waits
## on wall-clock time to assert about wall-clock time fails on a loaded machine
## and teaches you to rerun it instead of reading it.

const MainScene := preload("res://scenes/Main.tscn")
const MainScript := preload("res://scripts/Main.gd")

func _init() -> void:
	var failures: int = 0
	var main: Node2D = MainScene.instantiate()
	root.add_child(main)

	# Player fires 100ms after a 320ms rival: the player wins.
	_arm(main, 100)
	main._advance()
	failures += _expect(main.get("outcome"), MainScript.Outcome.PLAYER, "faster player wins")
	failures += _expect(main.get("state"), MainScript.State.RESULT, "a decided round ends")
	var shown: int = main.get("player_ms")
	failures += _expect(shown >= 95 and shown <= 115, true,
		"reaction reported as measured (%dms for a 100ms press)" % shown)

	# Player fires 500ms after the same rival: the rival wins.
	_arm(main, 500)
	main._advance()
	failures += _expect(main.get("outcome"), MainScript.Outcome.RIVAL, "slower player loses")

	# The rival fires on its own, with no press at all.
	_arm(main, 400)
	main._process(0.016)
	failures += _expect(main.get("outcome"), MainScript.Outcome.RIVAL, "rival fires unprompted")
	failures += _expect(main.get("player_ms"), -1, "no press means no time to show")

	# After a decision the next press starts a fresh round rather than editing
	# the last one. (An earlier version of this test asserted the opposite and
	# was wrong about the game, not about the code.)
	_arm(main, 50)
	main._advance()
	failures += _expect(main.get("state"), MainScript.State.RESULT, "settles to the result")
	main._advance()
	failures += _expect(main.get("state"), MainScript.State.DUEL, "next press re-arms")
	failures += _expect(main.get("phase"), MainScript.Phase.STEADY, "and waits again")
	failures += _expect(main.get("player_ms"), -1, "with last round's time cleared")

	main.free()
	print("REACTION: %s" % ("PASS" if failures == 0 else "FAIL %d" % failures))
	quit(failures)

## Puts the duel in the signalled state with the clock set so that "now" reads as
## `elapsed` milliseconds after DRAW!.
func _arm(main: Node2D, elapsed: int) -> void:
	# A fresh match, not just a fresh round: two rounds into a best-of-three the
	# result screen leads to the match screen, and these scenarios are about the
	# round.
	main._begin_match()
	main.set("phase", MainScript.Phase.SIGNAL)
	main.set("signal_at_ms", Time.get_ticks_msec() - elapsed)
	main.set("outcome", MainScript.Outcome.NONE)

func _expect(got, want, what: String) -> int:
	if got == want:
		return 0
	print("  FAIL: %s -- got %s, wanted %s" % [what, got, want])
	return 1
