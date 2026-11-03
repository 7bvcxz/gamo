extends "res://tests/framework/test_case.gd"

## Failure cases from Step 04 V2 on the real scene: input spam, automation and
## an unlock in the same tick, every doll awake, long runs, resizing, and dolls
## that must never leave the screen.

const MainScene := preload("res://scenes/main.tscn")

var main: WindupMain


func before_each() -> void:
	main = MainScene.instantiate()
	main.config = RunConfig.from_pairs({"fresh": "1"})
	tree.root.add_child(main)
	await tree.process_frame
	main.set_process(false)


func after_each() -> void:
	tree.root.size = Vector2i(64, 64)
	main.queue_free()
	await tree.process_frame


func test_spam_counts_at_most_the_cap() -> void:
	for i in 10000:
		main.press("click")
		main.release("click")
	assert_eq(main.atelier.turns, 1, "10,000 presses in one instant are one turn")
	assert_eq(main.atelier.blocked, 9999, "the rest refused")
	for i in 600:
		main.press("click")
		main.release("click")
		main.advance(0.05)
	assert_true(main.atelier.turns <= int(30.0 * main.balance.max_turns_per_second) + 2, "never faster than the cap over 30 s (%d)" % main.atelier.turns)
	assert_true(main.atelier.energy >= 0.0, "energy never negative")


func test_automation_and_unlock_in_one_tick() -> void:
	main.atelier.energy = main.balance.costs[0]
	main.atelier.manual_energy = main.atelier.energy
	# The awakening starts at the end of the first tick, then takes awaken_seconds.
	main.advance(main.balance.awaken_seconds + 0.5)
	assert_eq(main.atelier.awake, 1, "first doll up")
	# Energy one hair short; the automatic contribution and a turn land together.
	var top_up: float = (main.balance.costs[1] - 0.5) - main.atelier.energy
	main.atelier.energy += top_up
	main.atelier.manual_energy += top_up
	main.advance(0.25)
	main.press("dev")
	main.advance(0.1)
	assert_eq(main.telemetry.count("doll_awake"), 2, "one awakening, not two")
	assert_eq(main.atelier.waking, 1, "doll 1 is the one waking")
	assert_near(main.atelier.accounted_energy(), main.atelier.energy, 1e-6, "accounting holds")


func _fast_forward(seconds: float, every: float) -> void:
	var t := 0.0
	while t < seconds:
		main.press("dev")
		main.advance(every)
		t += every


func test_every_doll_awake_is_a_quiet_end_not_a_crash() -> void:
	_fast_forward(2400.0, 0.5)
	assert_eq(main.atelier.awake, main.atelier.doll_count(), "all twelve awake within 40 minutes")
	assert_eq(main.atelier.target(), main.atelier.doll_count(), "no next doll")
	var e := main.atelier.energy
	main.press("dev")
	main.advance(2.0)
	assert_true(main.atelier.energy > e, "winding and the dolls still add energy")
	assert_eq(main.view.gears_shown(), 12, "a full gear train")
	for i in main.atelier.doll_count():
		assert_eq(main.atelier.doll_state(i), "WORKING", "doll %d working" % i)


func test_dolls_stay_on_screen_while_they_walk() -> void:
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(844, 390)]:
		tree.root.size = size
		await tree.process_frame
		main.new_game(1)
		var vis := main.view.get_viewport_rect()
		var off := 0
		var t := 0.0
		while t < 400.0:
			main.press("dev")
			main.advance(0.2)
			t += 0.2
			for d in main.view.dolls:
				var p := d.global_position
				if p.x < vis.position.x - 2.0 or p.x > vis.end.x + 2.0 or p.y < vis.position.y or p.y > vis.end.y + 2.0:
					off += 1
		assert_eq(off, 0, "no doll off screen at %s" % size)
		assert_true(main.atelier.awake >= 5, "dolls woke and walked (%d)" % main.atelier.awake)


func test_resize_mid_game_keeps_dolls_where_they_were_in_the_room() -> void:
	tree.root.size = Vector2i(1280, 720)
	await tree.process_frame
	main.new_game(1)
	var before := main.view.dolls[3].position - main.view._layout_offset()
	tree.root.size = Vector2i(1920, 1080)
	await tree.process_frame
	var after := main.view.dolls[3].position - main.view._layout_offset()
	assert_true(before.distance_to(after) < 1.0, "same place in the room after a resize (%s -> %s)" % [before, after])
