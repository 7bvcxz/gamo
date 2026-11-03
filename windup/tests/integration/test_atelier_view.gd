extends "res://tests/framework/test_case.gd"

## The atelier with its art, the fallback without it, and the doll's wake-up.


func _view(use_art: bool) -> AtelierView:
	var v := AtelierView.new()
	v.use_art = use_art
	tree.root.add_child(v)
	return v


func test_art_view_has_the_doll() -> void:
	var v := _view(true)
	await tree.process_frame
	assert_true(v.use_art, "art is used when present")
	assert_true(v.doll != null and v.doll.is_inside_tree(), "doll in the scene")
	assert_eq(v.doll.pose_name, "asleep", "starts asleep")
	v.queue_free()
	await tree.process_frame


func test_fallback_draws_without_art() -> void:
	var v := _view(false)
	await tree.process_frame
	assert_false(v.use_art, "fallback")
	assert_true(v.doll == null, "no rig without art")
	v.turn()
	v.queue_free()
	await tree.process_frame


func test_wake_up_rises_and_ends_standing() -> void:
	var v := _view(true)
	await tree.process_frame
	v.set_process(false)
	var d := v.doll
	d.start_wake()
	var asleep_top := d.head_top().y
	var last := asleep_top
	var rose_at := -1.0
	var t := 0.0
	while d.waking and t < 5.0:
		d.advance(0.05)
		t += 0.05
		if rose_at < 0.0 and d.head_top().y < asleep_top - 10.0:
			rose_at = t
		last = d.head_top().y
	assert_false(d.waking, "the wake-up ends")
	assert_between(t, 1.5, 1.7, "it takes ~1.6 s")
	assert_eq(d.pose_name, "stand", "ends standing")
	assert_true(last < asleep_top - 30.0, "the head ends well above where it slept (%f -> %f)" % [asleep_top, last])
	assert_between(rose_at, 0.05, 0.8, "the head lifts early")
	assert_near(float(d.pose["eyes"]), 1.0, 1e-6, "eyes open")
	v.reset()
	assert_eq(d.pose_name, "asleep", "a new game puts it back to sleep")
	v.queue_free()
	await tree.process_frame


func test_the_wake_up_is_deterministic() -> void:
	var a := DollRig._wake_pose(0.5)
	var b := DollRig._wake_pose(0.5)
	assert_eq(JSON.stringify(a), JSON.stringify(b), "same time, same pose")
	assert_eq(JSON.stringify(DollRig._wake_pose(0.0)), JSON.stringify(DollRig.POSES["asleep"]), "t=0 is asleep")
