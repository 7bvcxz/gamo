extends "res://tests/framework/test_case.gd"

## The real scene: one gear per awake doll, the next doll's anticipation, and
## reduced motion turning off the shake and the flash.

const MainScene := preload("res://scenes/main.tscn")

var main: WindupMain


func before_each() -> void:
	main = MainScene.instantiate()
	main.config = RunConfig.from_pairs({"fresh": "1"})
	tree.root.add_child(main)
	await tree.process_frame
	main.set_process(false)


func after_each() -> void:
	main.queue_free()
	await tree.process_frame


func _wind_until_awake(n: int) -> void:
	var guard := 0
	while main.atelier.awake < n and guard < 20000:
		main.press("dev")
		main.advance(0.2)
		guard += 1


func test_one_gear_per_awake_doll() -> void:
	assert_eq(main.view.gears_shown(), 0, "no gears while everything sleeps")
	_wind_until_awake(3)
	main.advance(1.0)
	assert_eq(main.view.gears_shown(), main.atelier.awake + (1 if main.atelier.waking >= 0 else 0), "a gear for every doll that woke")


func test_the_next_doll_shivers_near_its_cost() -> void:
	var d := main.view.dolls[0]
	main.atelier.energy = main.balance.costs[0] * 0.95
	main.atelier.manual_energy = main.atelier.energy
	main.view.advance(0.013)
	assert_true(d.flutter > 0.5, "eyes flutter near the cost")
	main.atelier.energy = main.balance.costs[0] * 0.2
	main.view.advance(0.013)
	assert_eq(d.rotation, 0.0, "still when far from it")


func test_no_camera_shake_and_no_flash_on_awakening() -> void:
	# Step 05 V2: no camera shake, no flashing -- with or without reduced motion.
	for reduced: bool in [false, true]:
		main.settings.reduced_motion = reduced
		main._apply_settings()
		main.view.on_awakening(1)
		main.view.advance(0.05)
		assert_eq(main.view.position, Vector2.ZERO, "no shake (reduced %s)" % reduced)
		assert_eq(main.hud.flash, 0.0, "no flash (reduced %s)" % reduced)


func test_music_plays_only_after_the_first_awakening() -> void:
	main.advance(10.0)
	assert_eq(main.music.notes_played, 0, "silent while asleep")
	_wind_until_awake(1)
	var before := main.music.notes_played
	main.advance(10.0)
	assert_true(main.music.notes_played > before, "the music box plays once the first doll is up")


func test_life_follows_the_rules() -> void:
	main.view.advance(0.1)
	assert_eq(main.view.dolls[5].modulate, AtelierView.TINT_ASLEEP, "a dormant doll is cold and dim")
	_wind_until_awake(2)
	for i in 120:
		main.advance(0.1)
	assert_true(main.view.dolls[0].modulate.is_equal_approx(Color.WHITE), "an awake doll is in full colour")
	assert_true(main.view._dust < 0.9, "the dust starts to clear")
	assert_near(main.view._clock_hand, AtelierView._hand_for(main.atelier.awake), 0.05, "the clock shows how many are up")
	assert_true(main.telemetry.count("help") >= 1, "a doll went to help another (help event)")


func test_room_tone_goes_from_hush_to_hum() -> void:
	var cold := AmbientBed.levels(0)
	var warm := AmbientBed.levels(3)
	assert_true(cold.x > cold.y + 20.0, "asleep: the hush, no hum")
	assert_true(warm.y > warm.x, "bustling: the hum over the hush")
	_wind_until_awake(1)
	main.advance(20.0)
	assert_true(main.ambient.beats > 0, "the mechanical heartbeat runs once a doll works")


func test_long_frames_do_not_throw_the_key() -> void:
	# A 0.25 s frame (the clock's cap) right after a turn: the key settles near its target.
	main.press("dev")
	for i in 20:
		main.view.advance(0.25)
	var err := absf(main.view.key_angle - AtelierView.QUARTER)
	assert_true(err < 0.05, "the key settles (off by %.4f rad)" % err)
	assert_false(is_nan(main.view.key_angle) or is_inf(main.view.key_angle), "and stays a number")
