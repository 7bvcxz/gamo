extends "res://tests/framework/test_case.gd"

## The Momo rig on the sprite sheet (Step 51): every state, view, job and
## mood shows the sheet's cell for it; a walk plays its four frames; blinks
## are short; the size never changes between cells.

var rig: MomoRig


func before_each() -> void:
	rig = MomoRig.new()
	tree.root.add_child(rig)
	rig.setup(null, 3)
	rig.set_process(false)


func after_each() -> void:
	rig.queue_free()
	await tree.process_frame


func _cell_after(state: String, facing: Vector2, work := "", mood := "") -> String:
	rig.set_state(state)
	rig.face(facing)
	rig.work_pose = work
	rig.mood_pose = mood
	rig.blinking = false
	rig.tick(0.0)
	return rig.cell_name()


func test_the_body_is_one_cell_of_the_sheet() -> void:
	var sheet := MomoSheet.shared()
	assert_eq(rig.body.texture, sheet.texture, "drawn from the sheet")
	assert_true(rig.body.region_enabled, "one cell of it")
	assert_eq(rig.body.region_rect.size, Vector2(sheet.cell), "a whole cell")
	assert_eq(rig.body.offset, -sheet.pivot, "the feet on the node's origin (depth sorting, the shadow, taps)")
	assert_eq(rig.body.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "smooth when drawn small")


func test_views_follow_the_direction() -> void:
	assert_eq(_cell_after("idle", Vector2(0.5, 1)), "front_idle", "down the screen: the front")
	assert_eq(_cell_after("idle", Vector2(0.3, -1)), "back_idle", "up the screen: the back")
	assert_true(rig.is_back_view(), "")
	assert_eq(_cell_after("idle", Vector2(1, 0.1)), "side_idle", "straight across: the side")
	assert_eq(rig.scale.x, 1.0, "facing right")
	assert_eq(_cell_after("idle", Vector2(-1, 0.1)), "side_idle", "the same cell to the left")
	assert_eq(rig.scale.x, -1.0, "mirrored")
	assert_eq(_cell_after("idle", Vector2(-1, 0.5)), "front_idle", "an iso step down-left: the front, mirrored")


func test_walk_plays_its_four_frames_in_every_view() -> void:
	for v: Array in [["front", Vector2(0.5, 1)], ["back", Vector2(0.3, -1)], ["side", Vector2(1, 0)]]:
		rig.set_state("walk")
		rig.face(v[1])
		rig.time = 0.0
		var seen: Array[String] = []
		for i in 32:
			rig.tick(1.0 / 32.0)
			if seen.is_empty() or seen[-1] != rig.cell_name():
				seen.append(rig.cell_name())
		var name := String(v[0])
		assert_true(seen.has(name + "_walk_a") and seen.has(name + "_walk_b") and seen.has(name + "_walk_c"), "%s: A, B and C within a second (%s)" % [name, seen])
		var i_a := seen.find(name + "_walk_a")
		if i_a >= 0 and i_a + 3 < seen.size():
			assert_eq(seen.slice(i_a, i_a + 4), [name + "_walk_a", name + "_walk_b", name + "_walk_c", name + "_walk_b"] as Array[String], "%s: A B C B" % name)


func test_walking_faster_steps_faster() -> void:
	rig.set_state("walk")
	rig.face(Vector2(0.5, 1))
	var count := func(speed: float) -> int:
		rig.walk_speed = speed
		rig.time = 0.0
		var changes := 0
		var last := ""
		for i in 120:
			rig.tick(1.0 / 60.0)
			if rig.cell_name() != last:
				changes += 1
				last = rig.cell_name()
		return changes
	assert_true(int(count.call(2.0)) > int(count.call(1.0)), "dragged (walk_speed 2) steps faster")


func test_jobs_moods_and_rest_have_their_own_cells() -> void:
	for work: String in ["harvest", "water", "dig", "study", "sow", "chop", "replant", "hammer", "stoke", "write"]:
		_cell_after("idle", Vector2(1, 0.5))
		assert_eq(_cell_after("work", Vector2(-1, -0.4), work), work + "_0", "%s: starts its loop with its tool (Steps 66-67)" % work)
	assert_eq(_cell_after("work", Vector2(-1, -0.4), "carry"), "carry", "a sheet pose with no work frames: the sheet's")
	assert_eq(_cell_after("work", Vector2(-1, -0.4), ""), "back_work", "other work: back turned, busy")
	assert_eq(_cell_after("sit", Vector2(1, 0.5)), "sit", "")
	assert_eq(_cell_after("sleep", Vector2(1, 0.5)), "sleep", "")
	for mood: String in ["happy", "waiting", "confused"]:
		assert_eq(_cell_after("idle", Vector2(1, 0.5), "", mood), mood, "a mood shows in the pose (%s)" % mood)
	assert_eq(_cell_after("walk", Vector2(0.5, 1), "", "happy"), "front_walk_a", "but never stops a walk")


func test_idle_blinks_and_a_blink_is_short() -> void:
	rig.set_state("idle")
	rig.face(Vector2(0.5, 1))
	var blinks := 0
	var was := false
	var longest := 0
	var run := 0
	for i in 1200:
		rig.tick(1.0 / 60.0)
		var closed := rig.cell_name() == "front_blink"
		assert_eq(closed, rig.blinking, "the closed-eyes cell exactly while blinking")
		if closed and not was:
			blinks += 1
		was = closed
		run = run + 1 if closed else 0
		longest = maxi(longest, run)
	assert_true(blinks >= 4, "blinks every few seconds (%d in 20 s)" % blinks)
	assert_between(longest, 4, 12, "a blink lasts about 0.13 s (%d frames)" % longest)


func test_same_size_in_every_state() -> void:
	var sheet := MomoSheet.shared()
	for st: String in ["idle", "walk", "sit", "sleep", "work"]:
		rig.set_state(st)
		rig.tick(0.2)
		assert_near(absf(rig.body.scale.x), MomoRig.HEIGHT / sheet.stand_height_of(rig.cell_name()), 0.01, "%s: the one size on the island (a breath at most)" % st)
	assert_near(MomoRig.HEIGHT, 72.0, 0.01, "as tall as before Step 51 (taps and the HUD's anchors)")


## Step 67: a job is a loop -- wind-up, swing, strike, recover -- each frame
## held its own time, then a pause that is not the same twice; going back to
## work starts at the wind-up; reduced motion slows it; it runs on the real
## seconds that pass, whatever the simulation does.
func test_a_job_loops_through_its_frames_in_time() -> void:
	var sheet := MomoSheet.shared()
	for work: String in ["dig", "water", "study"]:
		var anim := "work_" + work
		var cells: Array = sheet.frames(anim)
		var timed: Array = sheet.animations[anim]["durations"]
		_cell_after("idle", Vector2(1, 0.5))
		rig.set_state("work")
		rig.work_pose = work
		var seen: Array[String] = []
		var held := {}
		for i in 600:
			rig.tick(1.0 / 60.0)
			var c := rig.cell_name()
			if seen.is_empty() or seen[-1] != c:
				seen.append(c)
			held[c] = int(held.get(c, 0)) + 1
		assert_eq(seen.slice(0, cells.size()), cells, "%s: the frames in order" % work)
		assert_true(seen.size() > cells.size(), "%s: and again (%d changes in 10 s)" % [work, seen.size()])
		for c: String in cells:
			assert_true(held.has(c), "%s: %s shows" % [work, c])
		# The first pass: each frame for its own time.
		var t0 := 0.0
		_cell_after("idle", Vector2(1, 0.5))
		rig.set_state("work")
		rig.work_pose = work
		for i in cells.size():
			rig.tick(0.0 if i == 0 else float(timed[i - 1]))
			assert_eq(rig.cell_name(), String(cells[i]), "%s: frame %d after %.2f s" % [work, i, t0])
			t0 += float(timed[i])


func test_the_pause_after_a_pass_varies() -> void:
	_cell_after("idle", Vector2(1, 0.5))
	rig.set_state("work")
	rig.work_pose = "dig"
	var last_frame := 0.0
	var pauses: Array[float] = []
	var on_last := false
	var since := 0.0
	var cells: Array = MomoSheet.shared().frames("work_dig")
	for i in 60 * 30:
		rig.tick(1.0 / 60.0)
		var last := rig.cell_name() == String(cells[-1])
		if last:
			since += 1.0 / 60.0
		elif on_last:
			pauses.append(since)
			since = 0.0
		on_last = last
	assert_true(pauses.size() >= 5, "many passes in 30 s (%d)" % pauses.size())
	var lo: float = pauses.min()
	var hi: float = pauses.max()
	assert_true(hi - lo > 0.08, "the end of a pass is not held the same every time (%.2f..%.2f s)" % [lo, hi])


func test_reduced_motion_slows_the_loop() -> void:
	var count := func() -> int:
		_cell_after("idle", Vector2(1, 0.5))
		rig.set_state("work")
		rig.work_pose = "hammer"
		var changes := 0
		var was := ""
		for i in 600:
			rig.tick(1.0 / 60.0)
			if rig.cell_name() != was:
				changes += 1
				was = rig.cell_name()
		return changes
	FxPrefs.reduced_motion = false
	var normal: int = count.call()
	FxPrefs.reduced_motion = true
	var reduced: int = count.call()
	FxPrefs.reduced_motion = false
	assert_true(reduced < normal * 0.8, "fewer swings with reduced motion (%d vs %d in 10 s)" % [reduced, normal])
	assert_true(reduced > 4, "but still working")
