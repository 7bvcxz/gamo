extends "res://tests/framework/test_case.gd"

## The Lab as it starts: six tiles with PLAY or SOON, a finger on a tile opens
## that experiment, Back comes home, and every experiment launches in the
## frame.

const MainScene := preload("res://lab/main.tscn")
const H := preload("res://tests/integration/lab_helpers.gd")

var app: LabApp


func before_each() -> void:
	tree.root.size = Vector2i(720, 1280)
	app = MainScene.instantiate() as LabApp
	tree.root.add_child(app)
	await tree.process_frame
	await tree.process_frame


func after_each() -> void:
	app.queue_free()
	tree.paused = false
	await tree.process_frame


func test_six_tiles_with_their_badges() -> void:
	assert_true(app.launcher != null, "the launcher is the first screen")
	assert_eq(app.launcher.tiles.size(), 6, "six tiles")
	var view := Rect2(Vector2.ZERO, app.launcher.size)
	for id: String in LabRegistry.ids():
		var tile: Button = app.launcher.tiles[id]
		var badge: Label = tile.find_child("BadgeText", true, false)
		assert_eq(badge.text, "PLAY" if LabRegistry.playable(id) else "SOON", "%s's badge" % id)
		assert_true(view.encloses(tile.get_global_rect()), "%s's tile is on screen: %s" % [id, tile.get_global_rect()])


func test_a_finger_on_a_tile_opens_it_and_back_comes_home() -> void:
	await H.touch(tree, H.centre(app.launcher.tiles["rock"]))
	assert_true(app.host != null, "an experiment opened")
	assert_eq(app.host.exp_id, "rock", "the tile's own")
	assert_eq(app.state()["screen"], "experiment", "state says so")
	await H.touch(tree, H.centre(app.host.back_button))
	await tree.process_frame
	assert_true(app.host == null, "Back closed it")
	assert_true(app.launcher != null, "and the launcher is back")
	assert_eq(app.history.size(), 1, "the run's summary is kept for the visit")


func test_every_experiment_launches_in_the_frame() -> void:
	for id: String in LabRegistry.ids():
		app.open(id)
		await tree.process_frame
		await tree.process_frame
		assert_eq(app.host.exp_id, id, id + " is open")
		assert_true(app.host.experiment != null and app.host.experiment.is_inside_tree(), id + " runs")
		assert_true(app.host.back_button.is_visible_in_tree(), id + " has Back")
		assert_true(app.host.restart_button.is_visible_in_tree(), id + " has Restart")
		# Step 93: the same soft music in every experiment (a fair comparison).
		assert_true((app.audio.get("_music") as AudioStreamPlayer).playing, id + " plays the music from the start")
		var before := app.host.session.active_ms
		app.host.step(1.0)
		assert_near(app.host.session.active_ms - before, 1000.0, 0.01, id + "'s clock runs")
		app.back()
		await tree.process_frame
	assert_true(app.launcher != null, "home again")
	assert_eq(app.history.size(), LabRegistry.ids().size(), "one record per run")
