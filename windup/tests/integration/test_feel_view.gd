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


func test_reduced_motion_has_no_shake_and_no_flash() -> void:
	main.settings.reduced_motion = true
	main._apply_settings()
	_wind_until_awake(1)
	main.view.advance(0.05)
	assert_eq(main.view.position, Vector2.ZERO, "no shake")
	assert_eq(main.hud.flash, 0.0, "no flash")
	main.settings.reduced_motion = false
	main._apply_settings()
	main.view.on_awakening(1)
	main.hud.flash_now()
	main.view.advance(0.05)
	assert_true(main.view.position != Vector2.ZERO, "shake when allowed")
	assert_true(main.hud.flash > 0.0, "flash when allowed")


func test_music_plays_only_after_the_first_awakening() -> void:
	main.advance(10.0)
	assert_eq(main.music.notes_played, 0, "silent while asleep")
	_wind_until_awake(1)
	var before := main.music.notes_played
	main.advance(10.0)
	assert_true(main.music.notes_played > before, "the music box plays once the first doll is up")
