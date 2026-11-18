extends "res://tests/framework/test_case.gd"

## Step 42: the motion director (art/motion.gd, design/MOTION.md) and the factory's motion under
## stress.
## - tiers: 1 / 5 / 20 / 40 running machines are solo, busy, crowded, swarm; each machine's share
##   of the effects shrinks as the floor fills; low effects are below the swarm
## - a bucket holds one second at most: a hidden tab or a ten-second frame pours no backlog
## - slow frames turn low effects on by themselves, fast frames turn them off again
## - a celebration waits while the hand holds the kettle, then the light climbs the floors from
##   the kitchen to the shop; the ring (B's target) never moves while it plays
## - one batch's real events light the floors in order: kitchen, packing, shop
## - forty-four machines for two minutes: the pieces, the nodes and the light stay bounded
## - stress (resizes, a hidden tab, ten-second frames, reduced motion and low effects): every
##   journey that starts ends once, nothing is left over -- and the game is the same game as a
##   run with full effects and no stress (the effects never change a rule)

const Main := preload("res://app/main.tscn")
const PLAN: Array = preload("res://tests/unit/test_factory_rules.gd").FORTY_PLAN
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


func _open(reduced: bool = false, low: bool = false) -> Node:
	app.reduced_motion = reduced
	app.low_effects = low
	app.open("factory")
	app.clock.set_pause("dev", true)   # the game's time only through dev_advance (a deterministic run;
	await tree.process_frame           # paused before the first frame, whose real milliseconds differ)
	return app.frame.play


func _mouse(p: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = p
	app.frame.play._gui_input(e)


func test_tiers_follow_the_running_machines_and_each_share_shrinks() -> void:
	var m := PopMotion.new()
	var names := []
	var last_share := INF
	var last_lot := 99
	for n in [1, 5, 20, 40]:
		m.running = n
		names.append(PopMotion.TIER_NAMES[m.tier()])
		var share := m.ambient_per_s() / float(n)
		assert_true(share < last_share, "each machine's share of the ambient pieces shrinks at %d machines (%.3f/s)" % [n, share])
		assert_true(m.lot_pieces() <= last_lot, "a lot's fountain is no bigger at %d machines" % n)
		last_share = share
		last_lot = m.lot_pieces()
	assert_eq(names, ["solo", "busy", "crowded", "swarm"], "1 / 5 / 20 / 40 machines")
	m.forced_low = true
	assert_true(m.ambient_per_s() <= float(PopMotion.AMBIENT_PER_S[3]) and m.lot_pieces() == 1 and m.sparkle_scale() < float(PopMotion.SPARKLE_SCALE[3]), "low effects are below the swarm")
	m.reduced = true
	assert_eq(m.ambient_per_s(), 0.0, "reduced motion: no ambient pieces")
	assert_eq(m.sparkles(10), 3, "a real event still shows (low: 10 sparkles -> 3)")
	assert_eq(m.sparkles(1), 1, "never zero for a real event")


func test_a_hidden_tab_or_a_long_frame_pours_no_backlog() -> void:
	var m := PopMotion.new()
	m.running = 1
	m.step(10.0, false)   # a ten-second frame (the tab came back)
	var got := m.allow("ambient", 1000)
	assert_true(got <= int(PopMotion.AMBIENT_PER_S[0]), "at most one second of ambient pieces (%d)" % got)
	for i in 600:
		m.step(1.0 / 60.0, false)
	got = m.allow("lot", 1000)
	assert_true(got <= int(PopMotion.LOT_PER_S[0]), "ten seconds idle keep one second of lot pieces (%d)" % got)


func test_slow_frames_lower_the_effects_and_fast_frames_restore_them() -> void:
	var m := PopMotion.new()
	for i in 30:
		m.step(1.0 / 15.0, false)   # 2 s at 15 fps: not yet
	assert_false(m.auto_low, "a short slow patch is not a slow device")
	for i in 60:
		m.step(1.0 / 15.0, false)
	assert_true(m.auto_low, "4+ s under %d fps: low effects" % int(PopMotion.LOW_FPS))
	for i in 300:
		m.step(1.0 / 60.0, false)
	assert_true(m.auto_low, "5 s of fast frames: still low (no flicker between budgets)")
	for i in 420:
		m.step(1.0 / 60.0, false)
	assert_false(m.auto_low, "10+ s over %d fps: full effects again" % int(PopMotion.HIGH_FPS))
	assert_eq([int(m.stats["auto_low_on"]), int(m.stats["auto_low_off"])], [1, 1], "once each way")


func test_a_celebration_waits_for_the_hand_and_the_ring_stays_put() -> void:
	var v: Node = await _open()
	var ring0: Rect2 = v.extra_rects()["ring"]
	var centre0: Vector2 = v.machine_centre()
	_mouse(centre0, true)   # the hand holds the kettle
	app.dev_advance(200)
	await tree.process_frame
	assert_true(bool(v._r()["heating"]), "heating")
	v._celebrate("sign")
	await tree.process_frame
	var d: Dictionary = v.motion_debug()
	assert_eq(String(d["queued"]), "sign", "while the hand holds, the celebration waits")
	assert_eq(float(d["sweep"]), -1.0, "no light runs while the gold is being aimed at")
	app.dev_advance(app.rules.window_start() - 200 + 60)
	_mouse(centre0, false)
	var seen_at := [-1.0, -1.0, -1.0]
	var moved := 0.0
	var started := false
	for f in 90:
		await tree.process_frame
		d = v.motion_debug()
		if float(d["sweep"]) >= 0.0:
			started = true
		for i in 3:
			if seen_at[i] < 0.0 and float(d["glow"][i]) >= 0.99:
				seen_at[i] = float(f)
		moved = maxf(moved, (v.extra_rects()["ring"] as Rect2).position.distance_to(ring0.position))
		moved = maxf(moved, (v.machine_centre() as Vector2).distance_to(centre0))
	assert_true(started, "once the hand lets go the light climbs")
	assert_true(seen_at[2] >= 0.0 and seen_at[1] >= seen_at[2] and seen_at[0] >= seen_at[1], "kitchen, then packing, then shop light up %s" % [seen_at])
	assert_eq(moved, 0.0, "the ring never moved")
	assert_eq(int(v.motion.stats["deferred"]), 1, "counted as deferred once")


func test_one_batch_lights_the_floors_from_the_bottom_to_the_top() -> void:
	var v: Node = await _open()
	var c: Vector2 = v.machine_centre()
	_mouse(c, true)
	app.dev_advance(app.rules.window_start() + 60)
	_mouse(c, false)
	var first := [-1.0, -1.0, -1.0]   # the clock when each floor was first lit by the batch
	for f in 400:
		app.dev_advance(50)
		await tree.process_frame
		var at: Array = v.motion.glow_peak_at
		for i in 3:
			if first[i] < 0.0 and float(at[i]) >= 0.0:
				first[i] = float(at[i])
		if first[0] >= 0.0 and int(app.rules.stats["sold"]) > 0:
			break
	assert_true(int(app.rules.stats["sold"]) > 0, "the batch was sold")
	assert_true(first[2] >= 0.0 and first[1] > first[2] and first[0] > first[1], "kitchen < packing < shop: %s" % [first])


func _build(n: int) -> void:
	app.dev_build(PLAN.slice(0, n), 8, 3)


func test_forty_four_machines_stay_bounded_for_two_minutes() -> void:
	var v: Node = await _open()
	_build(44)
	assert_eq(app.rules.machines.size(), 44, "forty-four machines")
	var peak_alive := 0
	var tiers := {}
	var nodes_mid := 0
	var light_kids := {}
	var belts := {}
	var ambient0 := 0
	var t0 := 0.0
	for f in 1200:
		app.dev_advance(100)
		await tree.process_frame
		var d: Dictionary = v.motion_debug()
		peak_alive = maxi(peak_alive, int(d["fx_alive"]))
		tiers[String(d["tier_name"])] = true
		light_kids[int(d["light_children"])] = true
		belts[int(d["belt_children"])] = true
		if f == 600:
			nodes_mid = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
			ambient0 = int((d["stats"]["given"] as Dictionary).get("ambient", 0))
			t0 = float(v.motion.clock)
	var d2: Dictionary = v.motion_debug()
	var nodes_end := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var given := int((d2["stats"]["given"] as Dictionary).get("ambient", 0)) - ambient0
	var secs := float(v.motion.clock) - t0
	print("motion42 forty: ", JSON.stringify({"peak_alive": peak_alive, "tiers": tiers.keys(), "nodes": [nodes_mid, nodes_end], "ambient": [given, secs], "d": d2}))
	assert_true(tiers.has("swarm") or tiers.has("crowded"), "a crowded floor's budget %s" % [tiers.keys()])
	assert_true(peak_alive <= PopFx.CAP, "the pieces stay inside the pool (%d)" % peak_alive)
	assert_true(nodes_end <= nodes_mid + 12, "no node pile-up in the second minute (%d -> %d)" % [nodes_mid, nodes_end])
	assert_eq(light_kids.keys(), [4], "the light is always three glows and the sweep")
	assert_eq(belts.size(), 1, "the belts are made once for a layout %s" % [belts.keys()])
	assert_true(int(d2["belts"]) == 6 and int(d2["belts_moving"]) >= 1, "six belts, the working ones moving (%d)" % int(d2["belts_moving"]))
	assert_true(float(given) <= secs * float(PopMotion.AMBIENT_PER_S.max()) + float(PopMotion.AMBIENT_PER_S.max()) + 1.0, "ambient pieces stay within the budget (%d in %.1f s)" % [given, secs])


## A scripted session (machines, hand pops, the game's time) with the view's motion settings and
## the stresses as parameters. Answers the rules' save and the journeys' coherence.
func _session(reduced: bool, low: bool, stress: bool) -> Dictionary:
	var v: Node = await _open(reduced, low)
	_build(12)
	var starts := {}
	var ends := {}
	var bad := []
	var seen := 0
	var sizes := [Vector2i(720, 1280), Vector2i(1280, 800), Vector2i(390, 844)]
	# The game's time follows one schedule in every session (100 ms a frame, plus the hand's
	# holds); a stress only changes WHEN the frames are drawn: a hidden tab draws frames with no
	# game time and catches up after, a stall is one long frame. Presses fall outside both.
	var advanced := 0
	var offset := 0
	var presses := []
	var trace := []
	for f in 700:
		if f % 40 == 0:
			if advanced < 100 * f + offset:
				app.dev_advance(100 * f + offset - advanced)
				advanced = 100 * f + offset
			var c: Vector2 = v.machine_centre()
			if not bool(v._r()["heating"]) and (v._r()["glass"] as Dictionary).is_empty():
				_mouse(c, true)
				var hold: int = app.rules.window_start() + 60
				presses.append([f, hold, int(app.rules.get("flow_ms"))])
				app.dev_advance(hold)
				advanced += hold
				offset += hold
				_mouse(c, false)
		if stress and f % 90 == 45:
			tree.root.size = sizes[(f / 90) % sizes.size()]   # a resize mid-journey
		var hidden := stress and f >= 282 and f < 318
		app.clock.set_pause("hidden", hidden)
		var stalled := stress and f % 100 >= 61 and f % 100 < 70   # nothing drawn, then one long frame at 70
		var target := 100 * (f + 1) + offset
		if not hidden and not stalled and target > advanced:
			app.dev_advance(target - advanced)
			advanced = target
		trace.append([f, advanced, int(app.rules.get("flow_ms")), app.clock.now_ms])
		await tree.process_frame
		# The journeys' record, entry by entry (the log keeps only its last 400).
		var new_n: int = int(v.log_count) - seen
		var log: Array = v.cargo_log
		for e: Dictionary in log.slice(maxi(0, log.size() - new_n)):
			if String(e["kind"]) == "fill":
				continue
			var key := "%s:%d" % [e["kind"], e["id"]]
			if String(e["what"]) in ["start", "serve"]:
				if int(starts.get(key, 0)) > int(ends.get(key, 0)):
					bad.append("%s started again before it ended" % key)
				starts[key] = int(starts.get(key, 0)) + 1
			elif String(e["what"]) == "end":
				ends[key] = int(ends.get(key, 0)) + 1
				if int(ends[key]) > int(starts.get(key, 0)):
					bad.append("%s ended without a start" % key)
		seen = int(v.log_count)
	tree.root.size = Vector2i(720, 1280)
	var open := 0
	for k: String in starts:
		open += int(starts[k]) - int(ends.get(k, 0))
	var out := {"save": JSON.stringify(app.rules.to_save()), "starts": starts.size(), "open": open, "cargo": v.cargo.size(),
		"bad": bad, "presses": presses, "trace": trace, "sold": int(app.rules.stats["sold"]), "actors": v.actor_layer.get_child_count(), "motion": v.motion_debug()}
	app.restart()
	await tree.process_frame
	return out


func test_stress_keeps_every_journey_whole_and_the_game_the_same() -> void:
	var calm: Dictionary = await _session(false, false, false)
	var hard: Dictionary = await _session(true, true, true)
	var full_stress: Dictionary = await _session(false, false, true)
	print("motion42 stress: ", JSON.stringify({"calm": [calm["starts"], calm["open"], calm["cargo"], calm["sold"], calm["actors"]],
		"hard": [hard["starts"], hard["open"], hard["cargo"], hard["sold"], hard["actors"]],
		"full_stress": [full_stress["starts"], full_stress["open"], full_stress["cargo"], full_stress["sold"], full_stress["actors"], full_stress["motion"]["stats"]]}))
	for r: Dictionary in [calm, hard, full_stress]:
		assert_eq(r["bad"], [], "no journey starts twice or ends without starting")
		assert_true(int(r["starts"]) > 20, "goods were followed (%d)" % int(r["starts"]))
		assert_eq(int(r["open"]), int(r["cargo"]), "what has not ended is exactly what is still moving (%d open, %d moving)" % [int(r["open"]), int(r["cargo"])])
		assert_true(int(r["sold"]) > 5, "the shop sold (%d)" % int(r["sold"]))
	for i in (calm["trace"] as Array).size():
		if JSON.stringify(calm["trace"][i]) != JSON.stringify(hard["trace"][i]) and not (hard["trace"][i][1] < calm["trace"][i][1]):
			print("motion42 first divergence: ", calm["trace"].slice(maxi(0, i - 2), i + 2), " | ", hard["trace"].slice(maxi(0, i - 2), i + 2))
			break
	var diff := _diff(JSON.parse_string(String(calm["save"])), JSON.parse_string(String(hard["save"])), "")
	assert_eq(diff, [], "reduced motion, low effects, resizes and a hidden tab change nothing in the game")
	assert_eq(_diff(JSON.parse_string(String(calm["save"])), JSON.parse_string(String(full_stress["save"])), ""), [], "nor do the stresses with full effects")


func _diff(a: Variant, b: Variant, path: String) -> Array:
	if typeof(a) == TYPE_DICTIONARY and typeof(b) == TYPE_DICTIONARY:
		var out := []
		for k: String in (a as Dictionary).keys() + (b as Dictionary).keys().filter(func(x: String) -> bool: return not (a as Dictionary).has(x)):
			out += _diff((a as Dictionary).get(k), (b as Dictionary).get(k), path + "/" + k)
			if out.size() > 8:
				break
		return out
	if typeof(a) == TYPE_ARRAY and typeof(b) == TYPE_ARRAY and (a as Array).size() == (b as Array).size():
		var out := []
		for i in (a as Array).size():
			out += _diff(a[i], b[i], "%s[%d]" % [path, i])
			if out.size() > 8:
				break
		return out
	return [] if JSON.stringify(a) == JSON.stringify(b) else ["%s: %s != %s" % [path, JSON.stringify(a).left(80), JSON.stringify(b).left(80)]]
