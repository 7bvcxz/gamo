extends SceneTree

## The cold you can hear.
##
## The cold bed was read off her warmth alone, and she walks into the hut at
## whatever warmth she made it home on -- which is the lowest it gets all day. So
## the freezing sound was loudest at the exact moment she was finally safe, and
## the door shutting made no difference to it.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_indoors_is_quiet()
	if failures == 0:
		print("AMBIENCE: PASS")
	else:
		print("AMBIENCE: FAIL (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

## The bed's own eased level, which is what the ear hears. Read rather than the
## target, because the ease is the thing that would keep a stopped sound audible.
func _cold(main: Node2D) -> float:
	return float(main.audio.call("bed_level", "cold"))

func _settle(main: Node2D, seconds: float) -> void:
	var steps: int = int(seconds / 0.05)
	for _step in steps:
		main._update_ambience(0.05)

func _test_indoors_is_quiet() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_run()
	main.finish_tutorial()
	main.state = main.State.PLAY

	# Out in the weather at the warmth she typically gets home on.
	main.player.warmth = 35.0
	main.player.position = main.sim.cell_centre(main.sim.core_cell + Vector2i(30, 0))
	_settle(main, 4.0)
	var outside: float = _cold(main)
	_assert(outside > 0.3, "밖에서는 추위가 들린다: %.2f" % outside)

	# The door shuts. Nothing about her warmth changes -- that is the point.
	main.state = main.State.NIGHTFALL
	main.night_phase = main.Phase.GATHER
	_settle(main, 4.0)
	_assert(_cold(main) < 0.03,
		"들어가면 조용해진다 (고양이들이 아직 걸어오는 중이어도): %.2f" % _cold(main))

	main.night_phase = main.Phase.GLOW
	_settle(main, 1.0)
	_assert(_cold(main) < 0.03, "자는 동안에도 조용하다: %.2f" % _cold(main))
	main.state = main.State.RESULT
	_settle(main, 1.0)
	_assert(_cold(main) < 0.03, "정산 카드에서도 조용하다: %.2f" % _cold(main))
	main.state = main.State.DAYBREAK
	main.night_phase = main.Phase.DAWN
	_settle(main, 1.0)
	_assert(_cold(main) < 0.03, "아침에도 조용하다: %.2f" % _cold(main))

	# And back out into it.
	main.state = main.State.PLAY
	_settle(main, 4.0)
	_assert(_cold(main) > 0.3, "다시 나가면 다시 들린다: %.2f" % _cold(main))

	main.clear_save()
	main.free()
