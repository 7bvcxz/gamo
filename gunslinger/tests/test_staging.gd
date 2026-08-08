extends SceneTree

## The win and loss staging. Drawing cannot be checked headless, so what is
## checked is the state the drawing reads: whose figure falls, how far along it
## is, and that a foul stages no shot. If those are right the picture follows;
## if they are wrong no amount of looking at it will help.

const MainScene := preload("res://scenes/Main.tscn")
const MainScript := preload("res://scripts/Main.gd")

func _init() -> void:
	var failures: int = 0
	var main: Node2D = MainScene.instantiate()
	root.add_child(main)

	# A decision restarts the staging clock, so the second round is staged like
	# the first rather than starting mid-fall.
	_win(main)
	failures += _expect(main.get("result_t"), 0.0, "staging starts at zero")

	# It runs while the result is up, and only there.
	main._process(0.1)
	failures += _expect(main.get("result_t") > 0.0, true, "staging advances on the result")
	var before: float = main.get("result_t")
	main.set("state", MainScript.State.DUEL)
	main.set("phase", MainScript.Phase.STEADY)
	main._process(0.1)
	failures += _expect(main.get("result_t"), before, "and not during the duel")

	# The flash reads as an instant and the fall as something you watch. If the
	# flash outlasted the fall the shot would arrive after the body.
	failures += _expect(MainScript.FLASH_S < MainScript.FALL_S, true,
		"flash is briefer than the fall")
	failures += _expect(MainScript.FLASH_S <= 0.2, true, "flash reads as instant")

	# The fall is complete by the time the staging is over, so nobody is left
	# frozen half-toppled while the result text sits on screen.
	_win(main)
	main._process(MainScript.FLASH_S + MainScript.FALL_S)
	var f: float = clampf((float(main.get("result_t")) - MainScript.FLASH_S) / MainScript.FALL_S, 0.0, 1.0)
	failures += _expect(f, 1.0, "the fall finishes")

	# A foul is not a gunfight: nobody drew, so nothing should be staged as a shot.
	main._begin_duel()
	main.set("wait_left", 3.0)
	main._advance()
	failures += _expect(main.get("outcome"), MainScript.Outcome.FOUL, "foul recorded")
	failures += _expect(main.get("player_ms"), -1, "and carries no reaction time")

	main.free()
	print("STAGING: %s" % ("PASS" if failures == 0 else "FAIL %d" % failures))
	quit(failures)

func _win(main: Node2D) -> void:
	main._begin_duel()
	main.set("phase", MainScript.Phase.SIGNAL)
	main.set("signal_at_ms", Time.get_ticks_msec() - 80)
	main.set("outcome", MainScript.Outcome.NONE)
	main._advance()

func _expect(got, want, what: String) -> int:
	if got == want:
		return 0
	print("  FAIL: %s -- got %s, wanted %s" % [what, got, want])
	return 1
