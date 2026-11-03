extends "res://tests/framework/test_case.gd"

## Which sound each moment makes, and the mute button. (Whether sound reaches
## the speakers is measured as signal in the browser: specs/sound05.spec.mjs.)

const Main := preload("res://app/main.tscn")

var app: PopApp


func before_each() -> void:
	app = Main.instantiate()
	tree.root.add_child(app)
	await tree.process_frame


func after_each() -> void:
	app.audio.set_muted(false)
	app.queue_free()
	await tree.process_frame


func _played(name: String) -> int:
	return int(app.audio.played.get(name, 0))


func test_a_press_pops_and_pays_audibly() -> void:
	app.open("click")
	await tree.process_frame
	app.on_command("press", {"type": "press"})
	assert_eq(_played("pop_1") + _played("pop_2") + _played("pop_3"), 0, "not yet: the machine is still pressing down")
	await tree.create_timer(0.15).timeout
	assert_eq(_played("pop_1") + _played("pop_2") + _played("pop_3"), 1, "the pop at the impact")
	assert_eq(_played("coin"), 1, "the coin")


func test_b_sizzles_while_held_and_chimes_on_a_perfect() -> void:
	app.open("perfect")
	await tree.process_frame
	app.on_command("press", {"type": "press"})
	await tree.process_frame
	assert_true(_played("sizzle") >= 1, "sizzle while heating")
	app.dev_advance(1600)
	app.on_command("release", {"type": "release"})
	assert_eq(_played("ding"), 1, "a perfect chimes")
	app.dev_advance(500)
	app.on_command("press", {"type": "press"})
	app.dev_advance(3000)
	assert_eq(_played("hiss"), 1, "a burnt batch hisses")


func test_c_clinks_and_booms() -> void:
	app.open("explosion")
	await tree.process_frame
	for i in 8:
		app.on_command("press", {"type": "press"})
		app.audio._last_ms.clear()   # presses in one frame would be merged by the 45 ms gap
	assert_eq(_played("clink"), 8, "a clink per kernel")
	assert_eq(_played("boom"), 1, "one boom")
	assert_eq(_played("crackle"), 1, "one crackle")


func test_an_upgrade_chimes() -> void:
	app.open("click")
	await tree.process_frame
	app.rules.money = 100
	app.buy()
	assert_eq(_played("upgrade"), 1, "upgrade chime")


func test_the_sound_button_steps_loud_soft_off() -> void:
	app.open("click")
	await tree.process_frame
	var bus := AudioServer.get_bus_index(&"SFX")
	assert_false(AudioServer.is_bus_mute(bus), "loud at start")
	assert_near(AudioServer.get_bus_volume_db(bus), 0.0, 0.01, "0 dB")
	app.toggle_sound()
	assert_false(AudioServer.is_bus_mute(bus), "soft is not muted")
	assert_near(AudioServer.get_bus_volume_db(bus), -12.0, 0.01, "-12 dB")
	assert_eq(app.frame.sound_button.icon, "soft", "one wave")
	app.toggle_sound()
	assert_true(AudioServer.is_bus_mute(bus), "off")
	assert_eq(app.frame.sound_button.icon, "mute", "the cross")
	app.toggle_sound()
	assert_false(AudioServer.is_bus_mute(bus), "loud again")
	assert_near(AudioServer.get_bus_volume_db(bus), 0.0, 0.01, "0 dB again")


func test_a_new_machine_look_is_a_milestone_with_a_fanfare() -> void:
	app.open("click")
	await tree.process_frame
	app.rules.money = 100000
	app.buy()
	app.audio._last_ms.clear()   # two buys in one millisecond would be merged by the 45 ms gap
	app.buy()
	assert_eq(_played("upgrade"), 2, "levels 1 and 2: the ordinary chime")
	assert_eq(_played("fanfare"), 0, "no fanfare yet")
	app.audio._last_ms.clear()
	app.buy()
	assert_eq(app.rules.level, 3, "level 3: the carnival look")
	assert_eq(_played("fanfare"), 1, "the milestone fanfare")
	assert_eq(_played("upgrade"), 2, "instead of, not on top of, the chime")
	assert_eq(app.frame.play.milestones_shown, 1, "one milestone shown")
