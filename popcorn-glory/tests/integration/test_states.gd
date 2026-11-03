extends "res://tests/framework/test_case.gd"

## Animation state and leftovers (Step 07): the spring settles, the upgrade's
## hop ends, effects drain, nothing is written to user://, and a run that
## restarts many times stays clean.

const Main := preload("res://app/main.tscn")

var app: PopApp


func before_each() -> void:
	app = Main.instantiate()
	tree.root.add_child(app)
	await tree.process_frame


func after_each() -> void:
	app.queue_free()
	await tree.process_frame


func test_the_spring_and_the_hop_settle() -> void:
	app.open("click")
	await tree.process_frame
	app.on_command("press", {"type": "press"})
	app.rules.money = 1000
	app.buy()
	var view: PopPlayView = app.frame.play
	for i in 240:
		view._process(1.0 / 60.0)
	assert_eq(view._squash, 0.0, "the spring is at rest after 4 s")
	assert_eq(view._squash_v, 0.0, "and still")
	assert_eq(view._jump, 0.0, "the hop is over")
	assert_eq(view.fx.alive, 0, "every piece has landed and gone")


func test_a_session_writes_nothing_to_user_storage() -> void:
	var before := _user_files()
	for id: String in ["click", "perfect", "explosion"]:
		app.open(id)
		await tree.process_frame
		for i in 20:
			app.on_command("press", {"type": "press"})
			app.on_command("release", {"type": "release"})
		app.dev_advance(5000)
		app.restart()
		app.back()
	assert_eq(_user_files(), before, "user:// unchanged (on the web it is shared by every game on the origin)")


func test_fifty_restarts_and_switches_stay_clean() -> void:
	var ids := ["click", "perfect", "explosion"]
	for i in 50:
		app.open(ids[i % 3])
		await tree.process_frame
		for k in 5:
			app.on_command("press", {"type": "press"})
		app.restart()
		assert_eq(app.rules.money, 0, "restart %d: from nothing" % i)
		assert_eq(app.clock.now_ms, 0, "restart %d: the clock from zero" % i)
		app.back()
	assert_eq(app.history.size(), 20, "the visit's history is capped at 20 summaries")
	assert_true(app.ui.get_child_count() <= 4, "no screens pile up (%d children)" % app.ui.get_child_count())


func _user_files() -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open("user://")
	if dir == null:
		return out
	for f: String in dir.get_files():
		if not f.begins_with("logs"):
			out.append(f)
	out.sort()
	return out
