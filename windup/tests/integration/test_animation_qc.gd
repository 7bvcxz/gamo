extends "res://tests/framework/test_case.gd"

## Animation QC (Step 03 V2), measured rather than eyeballed: in the standing
## loops (idle, wind, work) and the temperament gestures the doll's feet stay
## on its baseline -- no root drift, no jump -- and nothing turns NaN; the
## wake-up never moves the feet sideways. Walking swings the legs by design and
## is checked for staying on the floor only.

const STEP := 1.0 / 30.0


func _rig() -> DollRig:
	var d := DollRig.new()
	tree.root.add_child(d)
	return d


## The lowest point of the near leg's shoe in the rig's own space.
func _foot(d: DollRig) -> Vector2:
	return d.to_local(d._leg_near.get_global_transform() * Vector2(14, 52))


func test_standing_loops_keep_the_feet_still() -> void:
	var d := _rig()
	await tree.process_frame
	d.set_pose("stand")
	for act: String in ["idle", "wind", "work"]:
		d.activity = act
		var base := _foot(d)
		var worst := 0.0
		for i in 150:
			d.advance(STEP)
			var f := _foot(d)
			if is_nan(f.x) or is_nan(f.y):
				fail("%s: NaN foot" % act)
				break
			worst = maxf(worst, f.distance_to(base))
		assert_true(worst <= 1.0, "%s: feet stay put (moved %.2f px over 5 s)" % [act, worst])
	d.queue_free()
	await tree.process_frame


func test_quirks_do_not_lift_the_feet() -> void:
	var d := _rig()
	await tree.process_frame
	d.set_pose("stand")
	d.activity = "work"
	var base := _foot(d)
	for q: String in ["look", "bow", "cheer"]:
		d.play_quirk(q, 1.0)
		var worst := 0.0
		for i in 40:
			d.advance(STEP)
			worst = maxf(worst, _foot(d).distance_to(base))
		assert_true(worst <= 1.0, "%s: feet stay put (moved %.2f px)" % [q, worst])
	d.queue_free()
	await tree.process_frame


func test_walking_stays_on_the_floor() -> void:
	var d := _rig()
	await tree.process_frame
	d.set_pose("stand")
	d.activity = "walk"
	var lowest := -INF
	var highest := INF
	for i in 120:
		d.advance(STEP)
		var y := _foot(d).y
		lowest = maxf(lowest, y)
		highest = minf(highest, y)
	assert_true(lowest <= 4.0, "the foot never sinks below the floor (%.2f)" % lowest)
	assert_true(highest >= -14.0, "and lifts only a step (%.2f)" % highest)
	d.queue_free()
	await tree.process_frame
