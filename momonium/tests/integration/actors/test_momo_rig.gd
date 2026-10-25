extends "res://tests/framework/test_case.gd"

## The Momo rig: parts assemble back into the reference drawing, and each
## state moves the right joints the right way.

var lib: SpriteLibrary
var rig: MomoRig


func before_each() -> void:
	lib = SpriteLibrary.load_atlas()
	rig = MomoRig.new()
	tree.root.add_child(rig)
	rig.setup(lib, 3)
	rig.set_process(false)


func after_each() -> void:
	rig.queue_free()
	await tree.process_frame


func test_has_every_part_of_the_reference() -> void:
	for part: String in ["leg_l", "leg_r", "body", "arm_l", "arm_r", "head", "eyes", "tuft", "ear_l", "ear_r"]:
		assert_true(rig.parts.has(part), "has %s" % part)
	for sprite: String in ["momo_ear_l", "momo_ear_r", "momo_tuft", "momo_eyes_open", "momo_eyes_closed", "momo_body", "momo_head_back", "momo_body_back"]:
		assert_true(lib.has(sprite), "atlas has %s" % sprite)


func test_rest_pose_puts_every_part_on_its_joint() -> void:
	rig.time = 0.0
	rig.set_state("idle")
	rig.tick(0.0)
	for part: String in ["leg_l", "leg_r", "body", "arm_l", "arm_r"]:
		var expected := (rig._joint(part) - MomoRig.FRAME_ORIGIN) * MomoRig.UNIT
		var got: Vector2 = (rig.parts[part] as Sprite2D).position + rig.body_root.position
		assert_true(got.distance_to(expected) < 0.01, "%s at its joint (%s vs %s)" % [part, got, expected])
	var head := (rig._joint("head") - MomoRig.FRAME_ORIGIN) * MomoRig.UNIT
	assert_true(rig.head_root.position.distance_to(head) < 0.01, "head on the neck")


func test_idle_blinks_and_looks_around() -> void:
	var blinks := 0
	var looked := false
	var was := false
	for i in 600:
		rig.tick(1.0 / 60.0)
		if rig.blinking and not was:
			blinks += 1
		was = rig.blinking
		if rig.looking != 0.0:
			looked = true
	assert_true(blinks >= 2, "blinks every few seconds (%d in 10 s)" % blinks)
	assert_true(looked, "looks around at least once in 10 s")


func test_a_blink_is_short() -> void:
	var longest := 0
	var run := 0
	for i in 1200:
		rig.tick(1.0 / 60.0)
		run = run + 1 if rig.blinking else 0
		longest = maxi(longest, run)
	assert_between(longest, 4, 12, "a blink lasts about 0.13 s (%d frames)" % longest)


func test_walk_swings_legs_and_arms_in_opposition() -> void:
	rig.set_state("walk")
	var signs := {}
	for i in 60:
		rig.tick(1.0 / 60.0)
		var l: float = (rig.parts["leg_l"] as Sprite2D).rotation
		var r: float = (rig.parts["leg_r"] as Sprite2D).rotation
		var a: float = (rig.parts["arm_l"] as Sprite2D).rotation
		if absf(l) > 0.1:
			signs[signf(l)] = true
			assert_true(signf(l) == -signf(r), "legs opposite")
			assert_true(signf(a) == -signf(l), "left arm against left leg")
	assert_eq(signs.size(), 2, "each leg swings both ways within a second")


func test_sit_and_sleep_lower_the_body_and_sleep_closes_the_eyes() -> void:
	rig.set_state("idle")
	rig.tick(0.01)
	var stand := rig.body_root.position.y
	rig.set_state("sit")
	rig.tick(0.01)
	var sit := rig.body_root.position.y
	rig.set_state("sleep")
	rig.tick(0.01)
	var sleep := rig.body_root.position.y
	assert_true(sit > stand + 5.0 and sleep > sit, "sitting is lower than standing, sleeping lower still")
	var closed := lib.region("momo_eyes_closed")
	for i in 120:
		rig.tick(1.0 / 60.0)
		assert_eq((rig.parts["eyes"] as Sprite2D).region_rect, closed, "eyes stay closed asleep")


func test_facing_back_and_left() -> void:
	rig.face(Vector2(0.3, -1))
	assert_true(rig.is_back_view(), "walking up the screen shows the back")
	assert_eq((rig.parts["head"] as Sprite2D).region_rect, lib.region("momo_head_back"), "back of the head")
	assert_false((rig.parts["eyes"] as Sprite2D).visible, "no face from behind")
	rig.face(Vector2(-1, 0.5))
	assert_false(rig.is_back_view(), "front again")
	assert_eq(rig.scale.x, -1.0, "mirrored to face left")


func test_same_size_in_every_state() -> void:
	var heights := {}
	for st: String in ["idle", "walk"]:
		rig.set_state(st)
		rig.tick(0.2)
		var top := rig.head_root.position.y + (rig.parts["tuft"] as Sprite2D).position.y
		heights[st] = -top
	assert_true(absf(float(heights["idle"]) - float(heights["walk"])) / float(heights["idle"]) < 0.08, "walking does not shrink or grow Momo (%s)" % [heights])
