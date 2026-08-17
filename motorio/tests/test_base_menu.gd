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

	# And nothing to hand over means no row that refuses.
	for item_type: int in Defs.COUNTED_ITEMS:
		sim.stock[item_type] = 0
	var empty: Array[Dictionary] = main.base_rows()
	var still_fuel := false
	for row: Dictionary in empty:
		if String(row["kind"]) == "fuel":
			still_fuel = true
	_assert(not still_fuel, "넣을 것이 없으면 연료 줄이 아예 없다")

	main.clear_save()
	main.free()
