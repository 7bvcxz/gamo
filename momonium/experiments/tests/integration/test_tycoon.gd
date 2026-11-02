extends "res://tests/framework/test_case.gd"

## Experiment E in the Lab's frame: the line delivers by itself, coins are
## exactly the deliveries' value less what was spent, Improve Line (a real
## touch) changes the line you see, and a hidden page produces nothing.

const MainScene := preload("res://lab/main.tscn")
const H := preload("res://tests/integration/lab_helpers.gd")

var app: LabApp
var host: LabHost
var line_exp: LabExperiment


func before_each() -> void:
	tree.root.size = Vector2i(720, 1280)
	app = MainScene.instantiate() as LabApp
	tree.root.add_child(app)
	await tree.process_frame
	app.open("tycoon")
	await tree.process_frame
	await tree.process_frame
	host = app.host
	host.set_process(false)
	host.restart()
	line_exp = host.experiment


func after_each() -> void:
	app.queue_free()
	tree.paused = false
	await tree.process_frame


func _s() -> Dictionary:
	return line_exp.state()


func test_it_delivers_by_itself() -> void:
	assert_true(LabRegistry.playable("tycoon"), "the tile says PLAY")
	host.step(5.0)
	assert_eq(int(_s()["delivered"]), 0, "the first item is still on its way")
	assert_true(int(_s()["on_belt"]) >= 1, "but it is on the belt")
	host.step(40.0)
	var s := _s()
	assert_true(int(s["delivered"]) >= 8, "deliveries (%d)" % int(s["delivered"]))
	assert_eq(int(s["coins"]), int(s["delivered"]) * 3, "three coins each, once")
	assert_true(bool(s["unique_deliveries"]), "no item delivered twice")


func test_improve_line_changes_what_you_see() -> void:
	host.step(30.0)
	var before := _s()
	await H.touch(tree, H.centre(host.action_button))
	var s := _s()
	assert_eq(int(s["level"]), 1, "Improve Line")
	assert_eq(int(s["coins"]), int(before["coins"]) - 12, "paid 12")
	var shown := {}
	for to: int in [2, 3, 4, 6, 8, 9]:
		line_exp.dev("level", to)
		var t := _s()
		shown[to] = [int(t["arms"]), String(t["machine"]), int(t["helpers"]), int(t["lanes"])]
	assert_eq(shown[2][0], 2, "level 2: a second arm")
	assert_eq(shown[3][1], "steam_engine", "level 3: a new machine")
	assert_eq(shown[4][2], 1, "level 4: a Momo")
	assert_eq(shown[6][3], 2, "level 6: a second lane")
	assert_eq(shown[8][2], 2, "level 8: two Momo")
	assert_eq(shown[9][3], 3, "level 9: a third lane")


func test_coins_are_deliveries_less_spending() -> void:
	var spent := 0
	var t := 0.0
	while t < 180.0:
		host.step(0.25)
		t += 0.25
		var s := _s()
		if int(s["coins"]) >= int(s["next_cost"]):
			spent += int(s["next_cost"])
			host.press_action()
	var s := _s()
	assert_eq(int(s["coins"]), int(s["earned"]) - spent, "coins = earned - spent")
	assert_true(int(s["level"]) >= 7, "several improvements (%d)" % int(s["level"]))
	assert_true(bool(s["unique_deliveries"]), "every delivery once")
	assert_true(int(s["on_belt"]) <= 3 * 16, "the belt never overflows (%d items)" % int(s["on_belt"]))


func test_a_hidden_page_produces_nothing() -> void:
	host.set_process(true)
	host.step(20.0)
	var d := int(_s()["delivered"])
	var spawned := int(_s()["spawned"])
	host.set_pause("hidden", true)
	for i in 10:
		await tree.process_frame
	assert_eq(int(_s()["delivered"]), d, "no deliveries while hidden")
	assert_eq(int(_s()["spawned"]), spawned, "nothing made while hidden")
	host.set_pause("hidden", false)
