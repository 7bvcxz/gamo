extends "res://tests/framework/test_case.gd"

## Step 48: two frictions the Step 47 blind players met, fixed for the release candidate.
## - the contests page keeps the running contest's place: the posted cards do not move down when
##   the first contest is entered or ends ("the rows had shifted and I restarted the popping
##   challenge instead" -- a tap meant for the second card hit the first); and an entry tap right
##   after the list changed is not taken (no entry, no fee)
## - a press refused while the paper is open folds the paper: the floors that are full -- the
##   reason -- were under it (two players found out why only after closing it)

const Main := preload("res://app/main.tscn")
const Actor := preload("res://variants/factory/actor.gd")   # (like test_factory: see test_cargo46)
var app: PopApp


func before_each() -> void:
	app = Main.instantiate()
	app.save_prefix = "test."
	PopSaveStore.clear("test.factory.v1")
	tree.root.add_child(app)
	await tree.process_frame
	await tree.process_frame


func after_each() -> void:
	app.queue_free()
	await tree.process_frame


func _open() -> Node:
	app.open("factory")
	app.clock.set_pause("dev", true)
	await tree.process_frame
	return app.frame.play


func _frames(n: int, ms: int = 100) -> void:
	for i in n:
		app.dev_advance(ms)
		await tree.process_frame


func _card_ys(v: Node) -> Array:
	var L: Dictionary = v._contest_layout(v.detail_rect())
	return (L["cards"] as Array).map(func(c: Dictionary) -> float: return (c["rect"] as Rect2).position.y)


func test_the_posted_contests_stay_where_they_are_when_one_is_entered() -> void:
	var v: Node = await _open()
	app.rules.stats["sold"] = maxi(30, int(app.rules.stats["sold"]))
	app.rules.sign_tier = maxi(3, int(app.rules.sign_tier))   # rush_hour asks for sign 3
	app.dev_money(1000)
	assert_true(bool(app.dev_contest("perfect_streak")["ok"]), "a contest posted")
	assert_true(bool(app.dev_contest("rush_hour")["ok"]), "and a second")
	await _frames(2)
	v.toggle_news()
	v.news_tab = "contests"
	await _frames(2)
	var before := _card_ys(v)
	var L0: Dictionary = v._contest_layout(v.detail_rect())
	assert_true((L0["top"] as Dictionary).is_empty(), "nothing running yet")
	assert_eq(before.size(), 2, "two cards")
	# Enter the first through its own button (a real press on the page), after the list settled.
	await tree.create_timer(0.7).timeout
	var enter: Rect2 = (L0["cards"] as Array)[0]["enter"]
	var fee0 := int(app.rules.stats.get("contest_fees", 0))
	assert_true(v._contest_press(enter.get_center()), "the page took the press")
	await _frames(3)
	assert_false((app.rules.contests["entry"] as Dictionary).is_empty(), "the contest runs")
	assert_true(int(app.rules.stats.get("contest_fees", 0)) > fee0, "its fee paid once")
	var L1: Dictionary = v._contest_layout(v.detail_rect())
	assert_false((L1["top"] as Dictionary).is_empty(), "the running contest at the top")
	var after := _card_ys(v)
	print("  card ys before ", before, " after ", after)
	if not after.is_empty():
		assert_eq(after[0], before[0], "the card left in the list did not move down (it took the first card's place or stayed)")


func test_an_entry_tap_right_after_the_list_changed_is_not_taken() -> void:
	var v: Node = await _open()
	app.rules.stats["sold"] = maxi(30, int(app.rules.stats["sold"]))
	app.rules.sign_tier = maxi(3, int(app.rules.sign_tier))
	app.dev_money(1000)
	assert_true(bool(app.dev_contest("perfect_streak")["ok"]), "a contest posted")
	await _frames(2)
	v.toggle_news()
	v.news_tab = "contests"
	await _frames(2)
	await tree.create_timer(0.7).timeout
	var L0: Dictionary = v._contest_layout(v.detail_rect())
	assert_true((L0["cards"] as Array).size() >= 2, "cards posted (%d)" % (L0["cards"] as Array).size())
	# A card leaves the board (its window ends): the list changes under the finger, and the tap
	# lands at once.
	(app.rules.contests["posted"] as Array).pop_front()
	await tree.process_frame
	var L1: Dictionary = v._contest_layout(v.detail_rect())
	var held0 := int(v.contest_taps_held)
	var fee0 := int(app.rules.stats.get("contest_fees", 0))
	v._contest_press(((L1["cards"] as Array)[0]["enter"] as Rect2).get_center())
	await _frames(2)
	assert_eq(int(v.contest_taps_held), held0 + 1, "the tap was held back")
	assert_true((app.rules.contests["entry"] as Dictionary).is_empty(), "no contest started")
	assert_eq(int(app.rules.stats.get("contest_fees", 0)), fee0, "no fee taken")
	# A moment later the same tap enters.
	await tree.create_timer(0.7).timeout
	var L2: Dictionary = v._contest_layout(v.detail_rect())
	v._contest_press(((L2["cards"] as Array)[0]["enter"] as Rect2).get_center())
	await _frames(3)
	assert_false((app.rules.contests["entry"] as Dictionary).is_empty(), "a settled list takes the entry")


func test_a_press_refused_while_the_paper_is_open_folds_the_paper() -> void:
	var v: Node = await _open()
	app.dev_fill_bin()
	app.rules.glass = {"id": 777777, "recipe": "plain", "quality": 90, "portions": 4}
	app.rules.stats["made_portions"] = int(app.rules.stats["made_portions"]) + 4
	await _frames(2)
	v.toggle_news()
	await _frames(1)
	assert_true(bool(v.news_open), "the paper is open")
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = v.machine_centre()
	v._gui_input(e)
	await _frames(2)
	e = e.duplicate()
	e.pressed = false
	v._gui_input(e)
	await _frames(2)
	assert_eq(int(v.papers_folded), 1, "the refused press folded the paper")
	assert_false(bool(v.news_open), "so the full floors show")
	assert_true(v.full_cue.visible, "with the cue")
	app.rules.glass = {}
	app.rules.stats["made_portions"] = int(app.rules.stats["made_portions"]) - 4
