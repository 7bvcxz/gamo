extends SceneTree

## Best of three. The format is what stops one unlucky draw from being the whole
## game, so what matters is that it ends at two wins and not before, and that a
## foul costs a round like any other loss.

const MainScene := preload("res://scenes/Main.tscn")
const MainScript := preload("res://scripts/Main.gd")

func _init() -> void:
	var failures: int = 0
	var main: Node2D = MainScene.instantiate()
	root.add_child(main)

	# Two straight wins take it, and the third round is never played.
	main._begin_match()
	_win(main)
	failures += _expect(main.get("player_wins"), 1, "first win counted")
	failures += _expect(main.get("state"), MainScript.State.RESULT, "round one shows its result")
	main._advance()
	failures += _expect(main.get("state"), MainScript.State.DUEL, "round two starts")
	_win(main)
	failures += _expect(main.get("player_wins"), 2, "second win counted")
	main._advance()
	failures += _expect(main.get("state"), MainScript.State.MATCH_OVER, "2-0 ends the match")

	# Losing the first round is still a game: 1-2 goes the distance.
	main._advance()
	failures += _expect(main.get("state"), MainScript.State.DUEL, "a new match starts")
	failures += _expect(main.get("player_wins"), 0, "with the score reset")
	_lose(main); main._advance()
	_win(main);  main._advance()
	failures += _expect(main.get("state"), MainScript.State.DUEL, "1-1 plays a decider")
	_lose(main)
	failures += _expect(main.get("rival_wins"), 2, "decider counted")
	main._advance()
	failures += _expect(main.get("state"), MainScript.State.MATCH_OVER, "the decider ends it")

	# A foul costs the round. If it did not, drawing early would be free and the
	# rule that makes waiting matter would be decoration.
	main._advance()
	main._begin_match()
	main.set("wait_left", 4.0)
	main._advance()
	failures += _expect(main.get("outcome"), MainScript.Outcome.FOUL, "fouled")
	failures += _expect(main.get("rival_wins"), 1, "and the rival takes the round")

	main.free()
	print("MATCH: %s" % ("PASS" if failures == 0 else "FAIL %d" % failures))
	quit(failures)

func _win(main: Node2D) -> void:
	_armed(main, 60)

func _lose(main: Node2D) -> void:
	_armed(main, 900)

func _armed(main: Node2D, elapsed: int) -> void:
	main.set("phase", MainScript.Phase.SIGNAL)
	main.set("signal_at_ms", Time.get_ticks_msec() - elapsed)
	main.set("outcome", MainScript.Outcome.NONE)
	main._advance()

func _expect(got, want, what: String) -> int:
	if got == want:
		return 0
	print("  FAIL: %s -- got %s, wanted %s" % [what, got, want])
	return 1
