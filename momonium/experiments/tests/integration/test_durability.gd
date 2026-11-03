extends "res://tests/framework/test_case.gd"

## Step 100: what keeps a 30-minute comparison honest, on the real frame for
## ten minutes of each track variant. The books balance at every step (coins =
## earned - spent, whole numbers: one currency, no drift); an untouched rock
## gives nothing and an unbought line still delivers; the 10-minute
## checkpoint is kept.

const MainScene := preload("res://lab/main.tscn")

var app: LabApp


func before_each() -> void:
	tree.root.size = Vector2i(720, 1280)
	app = MainScene.instantiate() as LabApp
	tree.root.add_child(app)
	await tree.process_frame


func after_each() -> void:
	app.queue_free()
	tree.root.size = Vector2i(720, 1280)
	tree.paused = false
	await tree.process_frame


func _open(id: String) -> LabHost:
	app.open(id)
	app.host.set_process(false)
	await tree.process_frame
	return app.host


static func _spent(host: LabHost) -> int:
	var n := 0
	for u: Dictionary in host.session.upgrades:
		n += int(u["cost"])
	return n


func test_the_books_balance_for_ten_minutes_of_each() -> void:
	for id: String in ["rock", "rock-plus", "tycoon", "tycoon-plus"]:
		var host := await _open(id)
		var e := host.experiment
		var bad := 0
		for second in 600:
			if id.begins_with("rock"):
				e.dev("hits", 3)
			host.step(1.0)
			if bool(e.action_info().get("affordable", false)):
				host.press_action()
			var st := e.state()
			if typeof(st["coins"]) != TYPE_INT or typeof(st["earned"]) != TYPE_INT or int(st["coins"]) != int(st["earned"]) - _spent(host) or int(st["coins"]) < 0:
				bad += 1
		assert_eq(bad, 0, "%s: coins = earned - spent, whole and never negative, every second" % id)
		assert_true(host.session.at_marks.has("at_10min"), "%s: the 10-minute checkpoint" % id)
		assert_true(host.session.upgrades.size() >= 5, "%s: it grew (%d upgrades)" % [id, host.session.upgrades.size()])
		app.back()
		await tree.process_frame


func test_left_alone() -> void:
	# Nothing tapped: a rock gives nothing. Nothing bought: a line still runs.
	for id: String in ["rock", "rock-plus"]:
		var host := await _open(id)
		host.step(300.0)
		assert_eq(int(host.experiment.state()["earned"]), 0, "%s: an untouched rock pays nothing" % id)
		app.back()
		await tree.process_frame
	for id: String in ["tycoon", "tycoon-plus"]:
		var host := await _open(id)
		host.step(300.0)
		var st := host.experiment.state()
		assert_true(int(st["delivered"]) > 50, "%s: an unbought line keeps delivering (%d)" % [id, int(st["delivered"])])
		assert_eq(int(st["level"]), 0, "%s: and does not grow by itself" % id)
		app.back()
		await tree.process_frame
