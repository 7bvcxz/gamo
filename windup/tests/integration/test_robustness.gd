extends "res://tests/framework/test_case.gd"

## Step 07 V2 regression scenarios on the real scene: a paused game is a still
## picture, corrupt saves start fresh, no node or player growth over a long
## run, each doll wakes on screen exactly once, and a late-game frame is cheap.

const MainScene := preload("res://scenes/main.tscn")


func _start(pairs: Dictionary) -> WindupMain:
	var m: WindupMain = MainScene.instantiate()
	m.config = RunConfig.from_pairs(pairs)
	tree.root.add_child(m)
	return m


func _play(m: WindupMain, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		m.press("dev")
		m.advance(0.2)
		t += 0.2


func test_paused_game_is_a_still_picture() -> void:
	var m := _start({"fresh": "1"})
	await tree.process_frame
	m.set_process(false)
	_play(m, 40.0)
	m.set_pause("manual", true)
	var poses := []
	for d in m.view.dolls:
		poses.append([d.position, JSON.stringify(d.pose), d.modulate])
	var key := m.view.key_angle
	var e := m.atelier.energy
	m.advance(5.0)
	m.press("click")
	m.release("click")
	m.advance(5.0)
	for i in m.view.dolls.size():
		var d: DollRig = m.view.dolls[i]
		assert_eq([d.position, JSON.stringify(d.pose), d.modulate], poses[i], "doll %d still while paused" % i)
	assert_eq(m.view.key_angle, key, "the key does not move while paused")
	assert_eq(m.atelier.energy, e, "no energy while paused (not even from a click)")
	m.set_pause("manual", false)
	m.advance(1.0)
	assert_true(m.atelier.energy > e, "it goes on after resuming")
	m.queue_free()
	await tree.process_frame


func test_corrupt_saves_start_fresh() -> void:
	var path := SaveStore.PATH
	for bad: String in ["{not json", "", "[1,2,3]", "{\"schema\": 99, \"atelier\": {\"awake\": 5}}",
			"{\"schema\": 1, \"atelier\": {\"awake\": \"lots\", \"energy\": -1e30, \"waking\": 7}}"]:
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(bad)
		f.close()
		var m := _start({})
		await tree.process_frame
		assert_true(m.atelier.energy >= 0.0, "energy not negative after %s" % bad.left(20))
		assert_true(m.atelier.awake >= 0 and m.atelier.awake <= 12, "awake in range after %s" % bad.left(20))
		assert_near(m.atelier.accounted_energy(), m.atelier.energy, 1e-6, "accounting after %s" % bad.left(20))
		m.queue_free()
		await tree.process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_no_growth_in_nodes_or_players_over_a_long_run() -> void:
	var m := _start({"fresh": "1"})
	await tree.process_frame
	m.set_process(false)
	_play(m, 60.0)
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var players := m.sfx.get_child_count() + m.music.get_child_count() + m.ambient.get_child_count()
	_play(m, 1200.0)
	assert_true(m.atelier.awake >= 8, "the run got far (%d dolls)" % m.atelier.awake)
	var grew := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) - nodes
	assert_true(grew <= 0, "no nodes added over 20 minutes (%+d)" % grew)
	assert_eq(m.sfx.get_child_count() + m.music.get_child_count() + m.ambient.get_child_count(), players, "sound players are reused, not created")
	assert_eq(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), 0, "no orphan nodes (no forgotten timers)")
	for i in m.atelier.awake:
		assert_eq(m.view.dolls[i].wake_count, 1, "doll %d woke on screen exactly once" % i)
	for i in range(m.atelier.awake + 1, 12):
		assert_eq(m.view.dolls[i].wake_count, 0, "doll %d has not started waking" % i)
	# A late-game frame (everything lit, dolls walking) costs little.
	var t0 := Time.get_ticks_usec()
	for i in 600:
		m.advance(1.0 / 60.0)
	var per_frame_ms := (Time.get_ticks_usec() - t0) / 600.0 / 1000.0
	print("  late-game step %.3f ms per frame (headless, rules + view)" % per_frame_ms)
	assert_true(per_frame_ms < 4.0, "late-game step under 4 ms (%.3f)" % per_frame_ms)
	m.queue_free()
	await tree.process_frame


func test_a_press_after_losing_focus_brings_the_game_back() -> void:
	var m := _start({"fresh": "1"})
	await tree.process_frame
	m.set_process(false)
	m.set_pause("focus", true)
	m.press("click")
	m.release("click")
	assert_false(m.clock.paused, "a press on the window is the player coming back")
	assert_eq(m.winds, 1, "and it winds")
	m.set_pause("hidden", true)
	m.press("click")
	assert_eq(m.winds, 1, "a hidden page takes no presses")
	m.queue_free()
	await tree.process_frame


func test_a_slow_clicker_is_shown_holding_once() -> void:
	var m := _start({"fresh": "1"})
	await tree.process_frame
	m.set_process(false)
	for i in 14:
		m.press("click")
		m.release("click")
		m.advance(2.0)
	assert_true(m.view.hold_hint, "the spirit shows holding")
	assert_eq(m.telemetry.events.filter(func(e: Dictionary) -> bool: return e["ev"] == "hint" and e["reason"] == "hold").size(), 1, "once")
	m.press("click")
	m.advance(1.0)
	m.release("click")
	assert_false(m.view.hold_hint, "holding the key clears it")
	m.queue_free()
	await tree.process_frame


func test_a_price_drains_out_of_the_number_into_the_doll() -> void:
	# Step 12: the number does not drop in one frame when a doll starts waking;
	# it drains over the awakening while the price flows to that doll.
	var m := _start({"fresh": "1"})
	await tree.process_frame
	m.set_process(false)
	m.press("key")
	var guard := 0
	while m.atelier.waking < 0 and m.atelier.awake == 0 and guard < 6000:
		m.advance(1.0 / 60.0)
		guard += 1
	m.release("key")
	assert_true(m.atelier.waking == 0, "the first doll started waking")
	var before := m.hud.shown()
	assert_true(before > m.atelier.energy + 10.0, "right after: the number still shows most of the price (%.1f vs %.1f)" % [before, m.atelier.energy])
	assert_eq(m.view.spends_in_flight(), 1, "its price is on its way to the doll")
	m.hud.step(m.balance.awaken_seconds * 0.5)
	var mid := m.hud.shown()
	assert_true(mid < before and mid > m.atelier.energy, "half way: draining (%.1f)" % mid)
	m.hud.step(m.balance.awaken_seconds)
	assert_near(m.hud.shown(), m.atelier.energy, 0.001, "then it shows what is left")
	m.advance(2.0)
	assert_eq(m.view.spends_in_flight(), 0, "the light has arrived")
	assert_near(m.hud.shown(), m.atelier.energy, 0.001, "and the number is the energy again")
	m.queue_free()
	await tree.process_frame


func test_clicking_a_sleeper_or_the_spirit_answers_but_never_winds() -> void:
	var m := _start({"fresh": "1"})
	await tree.process_frame
	m.set_process(false)
	var e0 := m.atelier.energy
	var sleeper := m.view.to_local(m.view.dolls[3].global_position) + Vector2(0, -38)
	m.view.poke(sleeper)
	var target := m.view.to_local(m.view.dolls[m.atelier.target()].global_position) + Vector2(0, -38)
	m.view.poke(target)
	m.view.poke(m.view._spirit_home(m.view.key_center()))
	m.view.poke(Vector2(5, 5))
	var pokes := m.telemetry.events.filter(func(e: Dictionary) -> bool: return e["ev"] == "poke")
	assert_eq(pokes.map(func(e: Dictionary) -> String: return "%s:%d" % [e["target"], e["index"]]),
		["doll:3", "doll:%d" % m.atelier.target(), "spirit:-1", "none:-1"], "what each click touched")
	assert_eq(m.atelier.energy, e0, "no click away from the key winds")
	assert_eq(m.view._pokes.size(), 1, "only the doll the key is feeding answers up its thread")
	m.advance(0.2)
	assert_true(absf(m.view.dolls[3].rotation) > 0.0 or m.view.dolls[3].flutter > 0.0, "the touched sleeper stirs")
	m.queue_free()
	await tree.process_frame
