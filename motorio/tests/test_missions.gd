extends SceneTree

## Three tracks, and nothing on any of them until its moment.
##
## One ladder was wrong for this game. Everything the player works towards went
## through a single objective card, so the fire's next step, the animal in the
## ice and the first belt took turns evicting each other -- and whichever one
## happened to be showing was the only one that existed.
##
## A list of every rung at once would be a checklist. What is asserted here is
## the other half: that each rung is absent before its moment, present at it, and
## gone after -- and that the fire's own count is not on the card at all, because
## it is drawn over the fire.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_tracks()
	if failures == 0:
		print("MISSIONS: PASS")
	else:
		print("MISSIONS: FAIL (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _open_ids(main: Node2D) -> Array[String]:
	var out: Array[String] = []
	for row: Dictionary in main.open_missions():
		out.append(String(row["id"]))
	return out

func _test_tracks() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_run()
	main.state = main.State.PLAY
	var sim: Sim = main.sim

	# --- The table -------------------------------------------------------------
	# One track as of 1.0.8. The cat rungs and the automation rungs are gone --
	# every one of them described a thing the game teaches by having it happen,
	# and a card listing them turns finding a planet into working through a list.
	_assert(not Defs.missions_in(Defs.TRACK_BASE).is_empty(), "기지 계열에 임무가 있다")
	_assert(Defs.missions_in(Defs.TRACK_CAT).is_empty(), "고양이 계열은 비어 있다")
	_assert(Defs.missions_in(Defs.TRACK_AUTO).is_empty(), "자동화 계열도 비어 있다")
	var ids := {}
	for row: Dictionary in Defs.MISSIONS:
		_assert(not ids.has(String(row["id"])), "임무 id가 겹치지 않는다: %s" % String(row["id"]))
		ids[String(row["id"])] = true
		_assert(not String(row["line"]).is_empty(), "%s 에 문구가 있다" % String(row["id"]))
		_assert(not String(row["why"]).is_empty(), "%s 에 이유가 적혀 있다" % String(row["id"]))
		# No numbers in the lines. The card is deliberately unhelpful -- the
		# counts live on the things they are about.
		for digit: String in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]:
			_assert(not String(row["line"]).contains(digit),
				"%s 문구에 숫자가 없다: %s" % [String(row["id"]), String(row["line"])])

	# --- Nothing at the crash --------------------------------------------------
	main._update_missions()
	_assert(_open_ids(main).is_empty(),
		"불시착 직후에는 아무 임무도 없다: %s" % str(_open_ids(main)))

	# --- The fire ---------------------------------------------------------------
	main.finish_tutorial()
	main._update_missions()
	_assert(_open_ids(main).has("BASE2"), "거처가 서면 기지 임무가 열린다")
	# The world puts a frozen cat just past the opening circle, so raising the
	# radius would find one on the same frame and 생물 탐색 would open and close
	# together. Cleared first, so "has not seen one yet" is a real state here.
	sim.frozen_cats.clear()
	sim.stones_in = int(Defs.BASE_LEVELS[1]["stones"])
	sim._refresh_radius()
	main._update_missions()
	# And nothing takes its place. "불을 더 멀리 보낸다" was a second rung saying
	# the same thing as the first, and the fire's own window says what it wants.
	_assert(not _open_ids(main).has("BASE2"), "올리면 그 줄은 닫힌다")
	_assert(_open_ids(main).size() <= 1, "그 자리를 대신 채우는 줄은 없다")

	# What used to be here: eleven assertions walking the cat track and the
	# automation track rung by rung. Both tracks are gone, and the rungs they
	# described happen anyway -- a cat wakes up, a miner gets built -- which is
	# the argument for removing them.

	# --- And the card ----------------------------------------------------------
	# The fire's count is not on it. It is drawn over the fire, where a player
	# deciding whether to walk out for one more stone is already looking.
	# Both words, because the row was renamed once: a check that names the old
	# label passes forever afterwards while saying nothing.
	for row: Dictionary in main.open_missions():
		for word: String in ["업그레이드", "강화"]:
			_assert(not String(row["line"]).contains(word),
				"카드가 기지 강화를 말하지 않는다: %s" % String(row["line"]))
	_assert(main.objective().is_empty(),
		"오프닝이 끝나면 한 줄짜리 목표는 비어 있다: '%s'" % main.objective())
	var progress: Array[int] = main.upgrade_progress()
	_assert(progress.size() == 2, "대신 기지 위에 셀 숫자가 있다: %s" % str(progress))
	_assert(progress[1] > 0, "필요량이 0이 아니다")
	# And nothing at the top of the ladder, where there is nowhere left to count.
	sim.stones_in = int(Defs.BASE_LEVELS[-1]["stones"])
	sim._refresh_radius()
	_assert(main.upgrade_progress().is_empty(), "마지막 단계에서는 세지 않는다")

	main.clear_save()
	main.free()
