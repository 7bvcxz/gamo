extends SceneTree

## The fire's window reads the same way on every row.
##
## What a row does goes under its title; what it costs goes on the right. The
## fuel row was mirrored -- what it would consume under the title, what it would
## give on the right -- so a reader who had learned where to look in this window
## had to unlearn it for one line out of three.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_rows_agree()
	if failures == 0:
		print("BASE_MENU: PASS")
	else:
		print("BASE_MENU: FAIL (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _test_rows_agree() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_run()
	main.finish_tutorial()
	main.state = main.State.PLAY
	var sim: Sim = main.sim
	sim.stock[Defs.ITEM_HEATSTONE] = 12

	# The crafts open at 3단계, so this window has one row before that. These
	# cases are about the window's shape, not about the ladder.
	main.sim.stones_in = int(Defs.BASE_LEVELS[2]["stones"])
	main.sim._refresh_radius()
	var rows: Array[Dictionary] = main.base_rows()
	_assert(rows.size() >= 2, "기지 창에 줄이 여럿 있다: %d" % rows.size())
	var kinds: Array[String] = []
	for row: Dictionary in rows:
		kinds.append(String(row["kind"]))
	_assert(kinds.has("fuel"), "넣을 것이 있으면 연료 줄이 있다")
	_assert(kinds.has("craft"), "제작 줄도 있다")

	# Every row is laid out by the same geometry, so a row that read the other way
	# round could only do it by drawing its two halves swapped.
	var hud: Node = main.hud
	for index in rows.size():
		var rect: Rect2 = hud.call("base_menu_row_rect", index)
		_assert(rect.size.x > 120.0 and rect.size.y > 20.0,
			"%d번째 줄이 그릴 만한 크기다" % index)
		var card: Rect2 = hud.call("base_menu_rect")
		_assert(card.encloses(rect.grow(-1.0)), "%d번째 줄이 창 안에 있다" % index)

	# Nothing to hand over, and the row is still there. It used to vanish, which
	# meant the one line that says what the fire wants was missing at exactly the
	# moment the player had nothing and needed to know what to go and fetch -- so
	# it stays and refuses instead.
	for item_type: int in Defs.COUNTED_ITEMS:
		sim.stock[item_type] = 0
	var empty: Array[Dictionary] = main.base_rows()
	var still_fuel := false
	for row: Dictionary in empty:
		if String(row["kind"]) == "fuel":
			still_fuel = true
	_assert(still_fuel, "넣을 것이 없어도 투입 줄은 남는다")
	_assert(not sim.can_feed_base(), "그리고 그때는 넣을 수 없다")
	# Short of the step is also a refusal. Half-paying moves the material and not
	# the circle, and the player cannot see where it went.
	sim.stock[Defs.ITEM_HEATSTONE] = maxi(sim.stones_to_next() - 1, 0)
	_assert(not sim.can_feed_base(), "한 개 모자라도 넣을 수 없다")
	sim.stock[Defs.ITEM_HEATSTONE] = sim.stones_to_next()
	_assert(sim.can_feed_base(), "다 모으면 넣을 수 있다")

	# --- One recipe per rung ---------------------------------------------------
	# The list used to open all at once, so a box of fish for cats she may not
	# have met arrived beside the torch -- which at three steps is the answer to
	# the thing actually killing her.
	for row: Dictionary in Defs.BASE_CRAFTS:
		_assert(row.has("level"), "제작법마다 해금 단계가 있다: %s" % String(row["id"]))
	for level in range(1, 6):
		sim.stones_in = int(Defs.BASE_LEVELS[level - 1]["stones"])
		sim._refresh_radius()
		var ids: Array[String] = []
		for row: Dictionary in main.base_rows():
			if String(row["kind"]) == "craft":
				ids.append(String(Defs.BASE_CRAFTS[int(row["craft"])]["id"]))
		for craft: Dictionary in Defs.BASE_CRAFTS:
			var id: String = String(craft["id"])
			# Level is one gate of three now: a row can wait for a state
			# ("when") and retire on one ("until"). This world is past the
			# opening -- shelter standing, tools owned -- so the golden-path
			# rows are correctly absent at every level.
			var expected: bool = level >= int(craft["level"]) \
				and main._craft_state(String(craft.get("when", ""))) \
				and not main._craft_state(String(craft.get("until", "__never__")))
			_assert(ids.has(id) == expected,
				"%d단계에 %s 는 %s" % [level, id, "있다" if expected else "없다"])
	var bin_level := -1
	for craft: Dictionary in Defs.BASE_CRAFTS:
		if String(craft["id"]) == "food_bin":
			bin_level = int(craft["level"])
	_assert(bin_level == 4, "사료 상자는 4단계다")

	main.clear_save()
	main.free()
