extends "res://tests/framework/test_case.gd"

## Experiment F in the Lab's frame: coins come by themselves, Grow Tree turns
## the tree into its next shape (the next one already standing behind it as a
## pale silhouette), the tree stays planted where it stands, grows on screen
## and always fits between the frame's top and its button, and the same play
## gives the same tree.

const MainScene := preload("res://lab/main.tscn")
const H := preload("res://tests/integration/lab_helpers.gd")

var app: LabApp
var host: LabHost
var tree_exp: LabExperiment


func before_each() -> void:
	tree.root.size = Vector2i(720, 1280)
	app = MainScene.instantiate() as LabApp
	tree.root.add_child(app)
	await tree.process_frame
	app.open("tree")
	await tree.process_frame
	await tree.process_frame
	host = app.host
	tree_exp = host.experiment


func after_each() -> void:
	app.queue_free()
	tree.paused = false
	await tree.process_frame


func _s() -> Dictionary:
	return tree_exp.state()


func test_the_first_change() -> void:
	assert_true(LabRegistry.playable("tree"), "the tile says PLAY")
	var s := _s()
	assert_eq(int(s["stage"]), 0, "a sprout")
	assert_true(bool(s["preview"]), "the next shape stands behind it")
	assert_eq(String(s["next_name"]), "Sapling", "the sapling")
	host.step(12.1)
	await H.touch(tree, H.centre(host.action_button))
	s = _s()
	assert_eq(int(s["stage"]), 1, "Grow Tree")
	assert_eq(String(s["name"]), "Sapling", "a sapling now")
	assert_eq(String(host.session.upgrades[0]["shape"]), "Sapling", "recorded with its shape")
	assert_eq(host.experiment.intent_question(), "See the next tree?", "its own three-minute question")


func test_planted_growing_and_fitting() -> void:
	var heights: Array[float] = []
	var button := host.action_button.get_global_rect()
	for to: int in range(0, 15):
		tree_exp.dev("stage", to)
		tree_exp.call("_frame", false)
		var s := _s()
		var r: Array = s["tree_rect"]
		var rect := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
		var foot: Array = s["foot"]
		assert_near(rect.end.y, float(foot[1]), 1.0, "stage %d stands on its foot" % to)
		assert_true(rect.position.y >= LabHost.TOP_UI + 60.0, "stage %d is below the frame's top (%s)" % [to, rect])
		assert_true(float(foot[1]) <= button.position.y, "stage %d's foot is above the button" % to)
		assert_true(rect.position.x >= -1.0 and rect.end.x <= host.size.x + 1.0, "stage %d fits across (%s)" % [to, rect])
		heights.append(rect.size.y)
	for i in range(1, 6):
		assert_true(heights[i] > heights[i - 1] * 1.08, "the tree grows on screen: %s" % [heights])
	for i in range(1, heights.size()):
		assert_true(heights[i] >= heights[i - 1] - 1.0, "and never shrinks on screen: %s" % [heights])
	assert_true(float(_s()["zoom"]) >= 0.42, "never zoomed out past 0.42")


func test_three_minutes_buying_at_once() -> void:
	host.set_process(false)
	var t := 0.0
	while t < 180.0:
		host.step(0.25)
		t += 0.25
		if float(_s()["coins"]) >= float(_s()["next_cost"]):
			host.press_action()
	var s := _s()
	assert_true(int(s["stage"]) >= 9, "many shapes in three minutes (stage %d)" % int(s["stage"]))
	var times := TreeLevels.instant_times(int(s["stage"]))
	for u: Dictionary in host.session.upgrades:
		# The bot looks every 0.25 s, so each purchase may come up to a step late.
		assert_near(float(u["t_ms"]) / 1000.0, times[int(u["level"])], 0.25 * float(u["level"]), "stage %d when the table says" % int(u["level"]))
	var shapes: Array = host.session.upgrades.map(func(u: Dictionary) -> String: return String(u["shape"]))
	assert_eq(shapes.size(), int(s["stage"]), "every change recorded with its shape")


func test_the_same_play_gives_the_same_tree() -> void:
	host.set_process(false)
	host.restart()
	tree_exp = host.experiment
	var a := _play()
	host.restart()
	tree_exp = host.experiment
	var b := _play()
	assert_eq(a, b, "deterministic")


func _play() -> Array:
	for i in 300:
		host.step(0.25)
		if i % 9 == 0:
			host.press_action()
	var s := _s()
	return [int(s["stage"]), snappedf(float(s["coins"]), 0.001), int(s["segments"]), int(s["tips"]), host.session.upgrades.map(func(u: Dictionary) -> int: return int(u["t_ms"]))]


func test_a_hidden_page_grows_nothing() -> void:
	host.step(5.0)
	var coins := float(_s()["coins"])
	host.set_pause("hidden", true)
	for i in 8:
		await tree.process_frame
	assert_eq(float(_s()["coins"]), coins, "no coins while hidden")
	host.set_pause("hidden", false)
