extends "res://tests/framework/test_case.gd"

## Step 41: the cast, the reactions and the runtime audit of their motion.
## - looks: each part chosen on its own (no colour paired with a skin), neighbours differ
## - the leaving reactions: thanks and smiles common, delight rare (about one in nine)
## - a crowded shop run frame by frame: nobody jumps (no frame moves anyone more than a step),
##   standing feet stay on their line, the pose stays a sway (not a fall), the people never
##   stand over the glass tube or the shop's buttons, they fade in and out at the door, every
##   sale ends in one of the three exits, a received bag is a hop
## - reduced motion: no sway, no breath, no hop

const Main := preload("res://app/main.tscn")
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


func test_looks_are_chosen_part_by_part_and_neighbours_differ() -> void:
	var pairs := {}
	var styles := {}
	for id in range(1, 121):
		for who: String in PopCastArt.STYLES.keys():
			var a := PopCastArt.look_for(id, who)
			var b := PopCastArt.look_for(id + 1, who)
			assert_true(a != b, "customers %d and %d (%s) do not look the same" % [id, id + 1, who])
			assert_eq(a, PopCastArt.look_for(id, who), "the same customer always looks the same")
			pairs["%s|%s" % [a["body"], a["skin"]]] = true
			styles["%s|%s" % [who, a["style"]]] = true
	assert_true(pairs.size() >= 30, "clothes and skin are chosen on their own (%d pairs; the old drawing had 5)" % pairs.size())
	var all := 0
	for who: String in PopCastArt.STYLES:
		all += (PopCastArt.STYLES[who] as Array).size()
	assert_eq(styles.size(), all, "every hair style of every cast member is used")


func test_most_leave_with_thanks_or_a_smile_and_delight_is_rare() -> void:
	var n := {"thanks": 0, "happy": 0, "delight": 0}
	for id in range(1, 1801):
		var m := PopCastArt.exit_mood(id)
		n[m] = int(n[m]) + 1
	var d := float(n["delight"]) / 1800.0
	assert_true(d > 0.07 and d < 0.16, "delight is rare: %.3f" % d)
	assert_true(int(n["thanks"]) > 600 and int(n["happy"]) > 600, "thanks and smiles both common %s" % n)


func _crowd() -> void:
	# The 44-machine factory of the unit test, bought through the app's commands, at sign 8.
	var rr = app.rules
	rr.sign_tier = 6
	rr.packer_tier = 3
	rr.level = maxi(int(rr.level), 6)
	rr.stats["packed"] = maxi(1, int(rr.stats["packed"]))
	rr.stats["sold"] = maxi(1, int(rr.stats["sold"]))
	rr.money += 1 << 24
	for row: Array in preload("res://tests/unit/test_factory_rules.gd").FORTY_PLAN:
		var fl := String(row[1])
		if rr.floor_full(fl) and int(rr.line_cost(fl)) >= 0:
			app.on_command("buy_line", {"type": "buy_line", "floor": fl})
		app.on_command("build", {"type": "build", "machine": row[0], "floor": fl})
	rr.sign_tier = 8
	rr.money = 3000


func test_a_crowded_shop_moves_without_jumps_and_keeps_clear_of_the_tube_and_buttons() -> void:
	app.open("factory")
	await tree.process_frame
	var v: Node = app.frame.play
	_crowd()
	var hp: float = v._head_px()
	var tube: Rect2 = v.tube_rect()
	var top: Rect2 = v.floor_rect(0)
	# The badge is on the floor layer (under the people): nobody may stand over it. The news paper
	# is in the corner above the shop's machines: it is drawn over the people (its own layer).
	var buttons := [v.badge_rect(0)]
	assert_true(v.news_node.z_index > v.actor_layer.z_index and v.news_node.get_index() > v.actor_layer.get_index(), "the news paper is drawn over the people")
	var closest := 1e9
	var last := {}
	var worst_step := 0.0   # per frame, or per tenth of a second when the frame was longer
	var worst_raw := 0.0
	var d_last := 0.0   # the engine's delta of the frame before (see below)
	var worst_rot := 0.0
	var sy_lo := 9.0
	var sy_hi := 0.0
	var feet_off := 0
	var over_tube := 0
	var over_button := 0
	var seen_motion := {}
	var people_max := 0
	var at_door_visible := 0
	var sold0 := int(app.rules.stats["sold"])
	var exits0 := 0
	for m: String in ["thanks", "happy", "delight"]:
		exits0 += int(v.cast_stats.get(m, 0))
	for f in 1100:
		# the game's minutes pass 120 ms a frame; the last 200 frames at 4 ms (the people settle)
		app.dev_advance(120 if f < 900 else 4)
		await tree.process_frame
		# The people move by the frame's own delta (a walk, never faster). On a slow machine a
		# headless frame reaches the engine's cap (~0.133 s): a walk step there is ~28-32 px
		# (CI, Steps 46-48). So a step is judged per tenth of a second when the frame was longer.
		# The frame's length is the engine's own delta, not a wall clock around the await: that
		# clock missed the time dev_advance took before it (a slow model step on CI made a capped
		# 0.133 s frame look short, and an honest walk failed as a jump). process_frame comes before
		# the nodes' _process, so the positions read now moved by the previous frame's delta:
		# the longer of the two is used.
		var d_now := tree.root.get_process_delta_time()
		var frame_s := clampf(maxf(d_now, d_last), 0.0, 8.0 / 60.0)
		d_last = d_now
		var per_tenth := minf(1.0, 0.1 / maxf(frame_s, 1e-6))
		var people: Array = v.cast_debug()["people"]
		people_max = maxi(people_max, people.size())
		var now := {}
		for p: Dictionary in people:
			var key := "%d|%s" % [int(p["id"]), p["who"]]
			var at := Vector2(float(p["x"]), float(p["y"]))
			now[key] = at
			if last.has(key):
				worst_raw = maxf(worst_raw, at.distance_to(last[key]))
				worst_step = maxf(worst_step, at.distance_to(last[key]) * per_tenth)
			worst_rot = maxf(worst_rot, absf(float(p["rot"])))
			sy_lo = minf(sy_lo, float(p["sy"]))
			sy_hi = maxf(sy_hi, float(p["sy"]))
			seen_motion[String(p["motion"])] = true
			# standing in the queue or at the counter: feet on the shop's floor lines
			if not bool(p["moving"]) and not top.has_point(at):
				feet_off += 1
			var a := float(p["alpha"])
			var box := Rect2(float(p["box"][0]), float(p["box"][1]), float(p["box"][2]), float(p["box"][3]))
			if a > 0.5 and box.end.x > tube.position.x + 1.0:
				over_tube += 1
			if a > 0.5:
				for b: Rect2 in buttons:
					if box.intersects(b):
						over_button += 1
						if over_button <= 3:
							print("cast41 over: ", JSON.stringify(p), " button ", b)
			if not bool(p["moving"]) and a > 0.99:
				for q: Dictionary in people:
					if q != p and not bool(q["moving"]) and float(q["alpha"]) > 0.99 and absf(float(q["y"]) - at.y) < 2.0:
						closest = minf(closest, absf(float(q["x"]) - at.x))
						if absf(float(q["x"]) - at.x) < hp * 0.5:
							print("cast41 near: ", JSON.stringify([p, q]))
			if at.distance_to(v._door()) < 1.0 and a > 0.05:
				at_door_visible += 1
				if at_door_visible <= 2:
					print("cast41 door: ", JSON.stringify(p))
		last = now
	var exits := -exits0
	for m: String in ["thanks", "happy", "delight"]:
		exits += int(v.cast_stats.get(m, 0))
	var sold := int(app.rules.stats["sold"]) - sold0
	var report := {"closest_heads": closest / hp, "people_max": people_max, "worst_step": worst_step, "worst_raw": worst_raw, "head": hp, "worst_rot": worst_rot, "sy": [sy_lo, sy_hi],
		"motions": seen_motion.keys(), "stats": v.cast_stats, "sold": sold}
	print("cast41: ", JSON.stringify(report))
	assert_true(people_max >= 6, "a crowded shop (%d people at once)" % people_max)
	assert_true(worst_step < hp * 1.2, "nobody jumps: the largest step in a frame (or a tenth of a second) %.1f px, raw %.1f (head %.1f)" % [worst_step, worst_raw, hp])
	assert_true(worst_rot <= 0.1, "the lean stays a lean (%.3f rad)" % worst_rot)
	assert_true(sy_lo >= 0.8 and sy_hi <= 1.25, "the breath and the hops stay small %s" % [[sy_lo, sy_hi]])
	assert_eq(feet_off, 0, "standing feet stay inside the shop")
	assert_eq(over_tube, 0, "nobody seen stands over the glass tube")
	assert_eq(over_button, 0, "nobody seen covers the floor's badge")
	assert_true(closest >= hp * 1.0, "two people standing in a row are a body apart at least (%.2f heads)" % (closest / hp))
	assert_eq(at_door_visible, 0, "at the door they have faded out")
	for m: String in ["walk", "idle", "receive"]:
		assert_true(seen_motion.has(m), "the %s motion was seen %s" % [m, seen_motion.keys()])
	assert_true(sold > 10, "the shop sold (%d)" % sold)
	assert_true(exits >= sold - 2 and exits <= sold, "every sale leaves with thanks, a smile or delight (%d exits, %d sales)" % [exits, sold])
	assert_true(int(v.cast_stats["receive"]) >= sold - 2, "a bag received is a hop (%d)" % int(v.cast_stats["receive"]))


func test_reduced_motion_holds_the_cast_still() -> void:
	app.reduced_motion = true
	app.open("factory")
	await tree.process_frame
	var v: Node = app.frame.play
	assert_true(bool(v.reduced_motion), "the view is in reduced motion")
	_crowd()
	var moving := 0
	for f in 300:
		app.dev_advance(120)
		await tree.process_frame
		for p: Dictionary in v.cast_debug()["people"]:
			if absf(float(p["rot"])) > 0.0001 or absf(float(p["sy"]) - 1.0) > 0.0001:
				moving += 1
	assert_eq(moving, 0, "no sway, no breath, no hop")
