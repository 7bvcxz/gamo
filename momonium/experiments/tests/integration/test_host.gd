extends "res://tests/framework/test_case.gd"

## The frame around a run (the stub here; every experiment uses the same):
## Restart starts from nothing, a hidden or unfocused page stops play time
## and nothing is caught up, a long frame advances at most MAX_STEP, one
## finger is one press, and a paused run takes no taps.

const MainScene := preload("res://lab/main.tscn")
const H := preload("res://tests/integration/lab_helpers.gd")

var app: LabApp
var host: LabHost


func before_each() -> void:
	tree.root.size = Vector2i(720, 1280)
	app = MainScene.instantiate() as LabApp
	tree.root.add_child(app)
	await tree.process_frame
	app.open("evolution")
	await tree.process_frame
	await tree.process_frame
	host = app.host


func after_each() -> void:
	app.queue_free()
	tree.paused = false
	await tree.process_frame


func test_restart_starts_from_nothing() -> void:
	var first := host.experiment
	host.step(30.0)
	assert_true(float(host.experiment.state()["coins"]) >= 30.0, "coins came in")
	host.press_action()
	assert_eq(int(host.experiment.state()["level"]), 1, "an upgrade")
	host.restart()
	assert_true(host.experiment != first, "a new experiment")
	assert_eq(int(host.experiment.state()["level"]), 0, "from level 0")
	assert_eq(float(host.experiment.state()["coins"]), 0.0, "and no coins")
	assert_eq(host.session.active_ms, 0.0, "a new clock")
	await tree.process_frame
	assert_false(is_instance_valid(first), "the old one is gone")
	assert_eq(host.finished.size(), 1, "the old run's record is kept")
	assert_eq((host.finished[0]["upgrades"] as Array).size(), 1, "with its upgrade")
	assert_eq(host.runs, 2, "the second run")


func test_a_hidden_page_stops_play_time() -> void:
	host.set_pause("hidden", true)
	var ms := host.session.active_ms
	var coins := float(host.experiment.state()["coins"])
	for i in 10:
		await tree.process_frame
	assert_eq(host.session.active_ms, ms, "no play time while hidden")
	assert_eq(float(host.experiment.state()["coins"]), coins, "no coins while hidden")
	assert_true(tree.paused, "the run's tree is paused")
	host.set_pause("hidden", false)
	assert_false(tree.paused, "and runs again")
	await tree.process_frame
	await tree.process_frame
	assert_true(host.session.active_ms > ms, "time moves again")
	assert_true(host.session.active_ms - ms <= LabHost.MAX_STEP * 1000.0 * 3.0, "nothing caught up")
	var kinds: Array = host.session.events.map(func(e: Dictionary) -> String: return String(e["kind"]))
	assert_true(kinds.has("pause") and kinds.has("resume"), "both recorded")


func test_two_reasons_need_two_returns() -> void:
	host.set_pause("hidden", true)
	host.set_pause("focus", true)
	host.set_pause("hidden", false)
	assert_true(host.is_paused(), "still unfocused")
	assert_true(host.pause_overlay.visible, "the paused card shows")
	host.set_pause("focus", false)
	assert_false(host.is_paused(), "both back")
	assert_false(host.pause_overlay.visible, "the card is gone")


func test_a_long_frame_is_capped() -> void:
	var ms := host.session.active_ms
	host._process(30.0)
	assert_near(host.session.active_ms - ms, LabHost.MAX_STEP * 1000.0, 0.01, "a 30 s frame (a tab that slept) counts 0.25 s")


func test_one_finger_is_one_press() -> void:
	host.experiment.dev("coins", 100)
	host._refresh_action()
	await tree.process_frame
	await H.touch(tree, H.centre(host.action_button))
	assert_eq(int(host.session.counts.get("button", 0)), 1, "one touch: one press (not one for the touch and one for its mouse copy)")
	assert_eq(int(host.experiment.state()["level"]), 1, "one upgrade")
	await H.click(tree, H.centre(host.action_button))
	assert_eq(int(host.session.counts.get("button", 0)), 2, "a click is one press too")


func test_a_press_that_cannot_pay_is_refused_and_recorded() -> void:
	host.press_action()
	assert_eq(int(host.experiment.state()["level"]), 0, "nothing bought")
	assert_eq(int(host.session.counts.get("button_refused", 0)), 1, "the refused press is recorded")
	assert_eq(int(host.session.counts.get("button", 0)), 0, "not as a press that bought something")


func test_a_paused_run_takes_no_taps() -> void:
	host.experiment.dev("coins", 100)
	host.set_pause("focus", true)
	await tree.process_frame
	await H.touch(tree, H.centre(host.action_button))
	assert_eq(host.session.action_count(), 0, "the tap went to the paused card")
	assert_false(host.is_paused(), "and the tap brought the player back")
	assert_eq(int(host.experiment.state()["level"]), 0, "nothing bought by it")


func test_sound_switch() -> void:
	assert_false(app.audio.muted, "sound on")
	await H.touch(tree, H.centre(host.sound_button))
	assert_true(app.audio.muted, "off")
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "the master bus is muted")
	await H.touch(tree, H.centre(host.sound_button))
	assert_false(app.audio.muted, "on again")
