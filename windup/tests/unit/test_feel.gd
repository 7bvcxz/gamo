extends "res://tests/framework/test_case.gd"

## Step 05's feel layer: settings, the music box's layers, the gear train.


func test_settings_cycle_and_persist() -> void:
	var s := Settings.new()
	s.path = "user://test_windup_settings.json"
	assert_eq(s.volume(), 1.0, "full by default")
	s.cycle_volume()
	assert_eq(s.volume(), 0.5, "half")
	s.cycle_volume()
	assert_eq(s.volume(), 0.0, "off")
	s.cycle_volume()
	assert_eq(s.volume(), 1.0, "back to full")
	s.volume_step = 2
	s.reduced_motion = true
	s.save()
	var t := Settings.new()
	t.path = s.path
	t.load_saved()
	assert_eq(t.volume_step, 2, "volume kept")
	assert_true(t.reduced_motion, "reduced motion kept")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(s.path))


func test_music_grows_with_the_stage() -> void:
	assert_eq(MusicBox.layers(0).size(), 0, "a sleeping atelier is silent")
	assert_eq(MusicBox.layers(1).size(), 1, "first light: one line")
	assert_eq(MusicBox.layers(3).size(), 2, "bustling: + bass")
	assert_eq(MusicBox.layers(4).size(), 3, "festival: + counter-line")
	var sparse := 0
	var full := 0
	for n: int in MusicBox.MELODY_SPARSE:
		sparse += 1 if n >= 0 else 0
	for n: int in MusicBox.MELODY_FULL:
		full += 1 if n >= 0 else 0
	assert_true(full > sparse, "the melody fills in from stage 2")


func test_gear_slots_mesh_and_do_not_overlap() -> void:
	# First ring meshes with the big gear, second ring with the first.
	for k in 6:
		assert_near(AtelierView.gear_slot(k).length(), AtelierView.BIG_PITCH + AtelierView.SMALL_PITCH, 0.01, "ring 1 slot %d" % k)
		assert_near(AtelierView.gear_slot(k + 6).length(), AtelierView.BIG_PITCH + 3.0 * AtelierView.SMALL_PITCH, 0.01, "ring 2 slot %d" % k)
	for a in 12:
		for b in range(a + 1, 12):
			assert_true(AtelierView.gear_slot(a).distance_to(AtelierView.gear_slot(b)) >= 2.0 * AtelierView.SMALL_PITCH - 1.0,
				"slots %d and %d do not overlap" % [a, b])


func test_hold_hint_hand_stays_down_while_its_ring_fills() -> void:
	# Step 10: the hint shows a long press -- down for 2 s of every 3, the
	# fingertip ring filling only while down -- not a ring that fills by itself.
	var down := 0
	var last_fill := -1.0
	var monotonic := true
	for i in 300:
		var p := AtelierView.hold_hint_phase(i * 0.01)
		if p.x > 0.5:
			down += 1
			if p.y < last_fill:
				monotonic = false
			last_fill = p.y
		else:
			assert_eq(p.y, 0.0, "no ring while the hand is up (t=%.2f)" % (i * 0.01))
	assert_true(down >= 195 and down <= 205, "down about 2 s of each 3 s (%d of 300)" % down)
	assert_true(monotonic, "the ring only fills while held")
	assert_true(AtelierView.hold_hint_phase(2.34).y > 0.98, "full just before the hand lifts")
