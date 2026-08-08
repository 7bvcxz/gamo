extends SceneTree

## Drives the state machine the way a player would and checks it comes back
## round. Loading without an error proves the script parses; it does not prove
## the flow exists, and the flow is the condition.

## Preloaded as a const so the enum can be reached through the class rather than
## through an instance. `load().instantiate()` hands back an untyped value and
## GDScript refuses to infer from it -- a trap this repository has recorded twice
## already, and I walked into it a third time.
const MainScene := preload("res://scenes/Main.tscn")
const MainScript := preload("res://scripts/Main.gd")

func _init() -> void:
	var failures: int = 0
	var main: Node2D = MainScene.instantiate()
	root.add_child(main)

	failures += _expect(main.get("state"), MainScript.State.TITLE, "starts on the title")

	# One press per screen, twice round, so a cycle that works once but wedges
	# on the second lap is caught too. The duel is stepped through its signal
	# first: since the wait was added, a press before DRAW! is deliberately
	# ignored, and a test that still assumed otherwise was describing behaviour
	# the game no longer has.
	# The score is cleared each lap. Best of three means a real match ends after
	# two rounds, and this file is about the round cycle -- the match cycle is
	# test_match's subject.
	var seen: Array[int] = []
	for i in range(6):
		main.set("player_wins", 0)
		main.set("rival_wins", 0)
		if main.get("state") == MainScript.State.DUEL:
			main.set("wait_left", 0.0)
			main._process(0.016)
		main._advance()
		seen.append(main.get("state"))

	var want: Array[int] = [
		MainScript.State.DUEL, MainScript.State.RESULT,
		MainScript.State.DUEL, MainScript.State.RESULT,
		MainScript.State.DUEL, MainScript.State.RESULT,
	]
	failures += _expect(seen, want, "title -> duel -> result -> duel, twice round")

	# Nothing may dead-end: every state must lead somewhere -- the duel once its
	# signal has fired, since a press before DRAW! is deliberately ignored.
	for st: int in [MainScript.State.TITLE, MainScript.State.DUEL, MainScript.State.RESULT]:
		main.set("state", st)
		main.set("player_wins", 0)
		main.set("rival_wins", 0)
		if st == MainScript.State.DUEL:
			main.set("phase", MainScript.Phase.SIGNAL)
		main._advance()
		failures += _expect(main.get("state") != st, true, "state %d advances" % st)

	main.free()
	print("FLOW: %s" % ("PASS" if failures == 0 else "FAIL %d" % failures))
	quit(failures)

func _expect(got, want, what: String) -> int:
	if got == want:
		return 0
	push_error("%s -- got %s, wanted %s" % [what, got, want])
	print("  FAIL: %s -- got %s, wanted %s" % [what, got, want])
	return 1
