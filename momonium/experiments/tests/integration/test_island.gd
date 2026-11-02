extends "res://tests/framework/test_case.gd"

## Experiment A in the Lab's frame: coins come by themselves, the button buys
## the next level when it can pay and shows it on the island, the next level
## stands there as a ghost first, three minutes of buying at once reach the
## Town, the island always fits between the frame's top and its button, and
## the same play gives the same island.

const MainScene := preload("res://lab/main.tscn")
const H := preload("res://tests/integration/lab_helpers.gd")

var app: LabApp
var host: LabHost


func before_each() -> void:
	tree.root.size = Vector2i(720, 1280)
	app = MainScene.instantiate() as LabApp
	tree.root.add_child(app)
	await tree.process_frame
	app.open("island")
	await tree.process_frame
	await tree.process_frame
	host = app.host


func after_each() -> void:
	app.queue_free()
	tree.paused = false
	await tree.process_frame


func _exp() -> Dictionary:
	return host.experiment.state()


func test_it_is_playable() -> void:
	assert_true(LabRegistry.playable("island"), "the tile says PLAY")
	assert_eq(String(host.experiment.get_script().resource_path), "res://experiments/island/island.gd", "A's own script")


func test_the_first_upgrade() -> void:
	var s := _exp()
	assert_eq(int(s["level"]), 0, "level 0")
	assert_eq(int(s["cells"]), 4, "a 2x2 islet")
	assert_eq(int(s["momos"]), 1, "one Momo")
	assert_true(int(s["ghost_cells"]) > 0, "the next coast shows as a ghost")
	host.step(14.9)
	host.press_action()
	assert_eq(int(_exp()["level"]), 0, "14.9 coins cannot pay 15")
	assert_eq(int(host.session.counts.get("button_refused", 0)), 1, "the refused press is recorded")
	host.step(0.2)
	await H.touch(tree, H.centre(host.action_button))
	s = _exp()
	assert_eq(int(s["level"]), 1, "a finger on Upgrade Island bought level 1")
	assert_eq(int(s["cells"]), 9, "the coast grew to 3x3")
	assert_eq(int(s["props"]), 1, "a bush")
	assert_between(float(s["coins"]), 0.1, 0.4, "15 coins paid (the frames of the touch earned a little)")
	var u: Dictionary = host.session.upgrades[0]
	assert_eq(int(u["level"]), 1, "recorded")
	assert_between(float(u["t_ms"]), 15000.0, 15200.0, "at 15 s of play")


func test_three_minutes_buying_at_once_reach_the_town() -> void:
	var t := 0.0
	while t < 180.0:
		host.step(0.25)
		t += 0.25
		if float(_exp()["coins"]) >= float(_exp()["next_cost"]):
			host.press_action()
	var s := _exp()
	assert_eq(String(s["stage"]), "town", "the Town by 3:00")
	assert_true(int(s["level"]) >= 8, "level %d" % int(s["level"]))
	var names: Array = host.session.milestones.map(func(m: Dictionary) -> String: return String(m["name"]))
	assert_eq(names, ["village", "town"], "the stage milestones, in order")
	var times := IslandLevels.instant_times(int(s["level"]))
	for u: Dictionary in host.session.upgrades:
		assert_near(float(u["t_ms"]) / 1000.0, times[int(u["level"])], 0.3, "level %d when the table says" % int(u["level"]))
	assert_true(bool(s["monument_ghost"]), "the Monument waits as a ghost")
	assert_true(int(s["momos"]) >= 3, "three Momo")


func test_the_same_play_gives_the_same_island() -> void:
	# Only the explicit steps move play time here (no frame's own delta).
	host.set_process(false)
	host.restart()
	var a := _play()
	host.restart()
	var b := _play()
	assert_eq(a, b, "deterministic")


func _play() -> Array:
	for i in 400:
		host.step(0.25)
		if i % 7 == 0:
			host.press_action()
	var s := _exp()
	return [int(s["level"]), snappedf(float(s["coins"]), 0.001), int(s["cells"]), int(s["props"]), host.session.upgrades.map(func(u: Dictionary) -> int: return int(u["t_ms"]))]


func test_the_island_fits_between_the_frame_and_the_button() -> void:
	var button := host.action_button.get_global_rect()
	for to: int in [0, 3, 6, 10, 14]:
		host.experiment.dev("level", to)
		host.experiment.call("_frame", false)
		var r: Array = _exp()["island_rect"]
		var island := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
		assert_true(island.position.x >= -1.0 and island.end.x <= host.size.x + 1.0, "level %d fits across: %s" % [to, island])
		assert_true(island.position.y >= LabHost.TOP_UI, "level %d is below the frame's top: %s" % [to, island])
		assert_true(island.end.y <= button.position.y, "level %d is above the button: %s / %s" % [to, island, button])
	assert_true(float(_exp()["zoom"]) >= 0.55, "never zoomed out past 0.55")


## A tile keeps its size while the island fits, so the island itself grows on
## screen; once it fills the width the view draws back, and the land on screen
## still grows.
func test_a_bigger_island_is_bigger_on_screen() -> void:
	var widths: Array[float] = []
	var land: Array[float] = []
	for to: int in [0, 1, 3, 6, 10]:
		host.experiment.dev("level", to)
		host.experiment.call("_frame", false)
		var s := _exp()
		widths.append(float((s["island_rect"] as Array)[2]))
		land.append(float(s["cells"]) * pow(float(s["zoom"]), 2.0))
	for i in range(1, 4):
		assert_true(widths[i] > widths[i - 1] * 1.08, "the island grows on screen: %s" % [widths])
	for i in range(1, widths.size()):
		assert_true(widths[i] >= widths[i - 1] - 1.0, "and never shrinks: %s" % [widths])
		assert_true(land[i] > land[i - 1], "the land on screen grows: %s" % [land])


func test_a_hidden_page_earns_nothing() -> void:
	host.step(5.0)
	var coins := float(_exp()["coins"])
	host.set_pause("hidden", true)
	for i in 8:
		await tree.process_frame
	assert_eq(float(_exp()["coins"]), coins, "no coins while hidden")
	host.set_pause("hidden", false)
