extends "res://tests/framework/test_case.gd"

## Step 45: the app's side of the save (app/main.gd) -- a refused save is set aside,
## never written over; the last good one is tried; a restart takes two taps and
## leaves the old factory recoverable; the stand, the factory and A/B/C keep apart.

const Main := preload("res://app/main.tscn")
const NAMES := ["test.factory.v1", "test.factory.v1.bak", "test.factory.v1.rejected", "test.stand.v1", "test.stand.v1.bak",
	"test.stand.v1.rejected", "test.click.v1", "test.perfect.v1", "test.explosion.v1"]
var app: PopApp


func before_each() -> void:
	for n: String in NAMES:
		PopSaveStore.clear(n)
	app = _new_app()
	tree.root.add_child(app)
	await tree.process_frame


func after_each() -> void:
	app.queue_free()
	await tree.process_frame
	for n: String in NAMES:
		PopSaveStore.clear(n)


func _new_app() -> PopApp:
	var a: PopApp = Main.instantiate()
	a.save_prefix = "test."
	return a


func _play_factory(a: PopApp, ms: int) -> void:
	a.open("factory")
	await tree.process_frame
	a.rules.money = 5000
	a.rules.execute({"type": "build", "machine": "cooker", "floor": "kitchen"})
	a.dev_advance(ms)


func _reopen() -> PopApp:
	app.queue_free()
	await tree.process_frame
	app = _new_app()
	tree.root.add_child(app)
	await tree.process_frame
	app.open("factory")
	await tree.process_frame
	return app


func test_a_refused_save_is_set_aside_and_the_backup_comes_back() -> void:
	await _play_factory(app, 70000)
	assert_true(app.save_now(), "saves")
	var good := PopSaveStore.read("test.factory.v1")
	var machines: int = app.rules.machines.size()
	assert_eq(PopSaveStore.read("test.factory.v1.bak"), "", "no backup in the first minute of a new factory")
	app.dev_advance(61000)
	assert_true(app.save_now(), "saves again a minute later")
	assert_eq(PopSaveStore.read("test.factory.v1.bak"), good, "the backup is the save of a minute ago")
	# The main save is damaged (one character): it is refused, set aside, and the backup restores.
	var main := PopSaveStore.read("test.factory.v1")
	var broken := main.substr(0, main.length() - 30) + "7" + main.substr(main.length() - 29)
	PopSaveStore.write("test.factory.v1", broken)
	await _reopen()
	assert_eq(String(app.save_info["from"]), "backup", "picked up from the backup")
	assert_ne(String(app.save_info["rejected"]), "", "and says why the main save was refused (%s)" % app.save_info["rejected"])
	assert_eq(PopSaveStore.read("test.factory.v1.rejected"), broken, "the refused save is set aside, whole")
	assert_true(app.frame.recover_button.visible, "the set-aside icon shows the way to it")
	assert_true(app.state()["rects"].has("recover"), "and it can be tapped")
	assert_eq(app.rules.machines.size(), machines, "the paid machine is there")
	# The next save writes the main save; the refused one stays set aside.
	assert_true(app.save_now(), "saves")
	assert_eq(PopSaveStore.read("test.factory.v1.rejected"), broken, "still set aside after a new save")


func test_when_nothing_is_whole_a_fresh_factory_starts_and_keeps_the_broken_one() -> void:
	PopSaveStore.write("test.factory.v1", "{\"schema\":1,\"game\":\"popcorn-glory\",\"exp\":\"factory\",\"rules\":{\"money\":")
	PopSaveStore.write("test.factory.v1.bak", "not json")
	await _reopen()
	assert_eq(String(app.save_info["from"]), "fresh", "a fresh factory")
	assert_true(app.frame.recover_button.visible, "a fresh start after a refusal is not silent: the set-aside icon")
	assert_eq(String(app.save_info["rejected"]), "not_json", "the main save's reason")
	assert_eq(String(app.save_info["backup_rejected"]), "not_json", "the backup's reason")
	assert_true(app.save_now(), "the fresh factory saves")
	assert_true(PopSaveStore.read("test.factory.v1.rejected").begins_with("{\"schema\":1"), "the broken save is still there to recover")
	# A save from a newer schema is refused and kept, not written over.
	var newer := PopSaveDoc.encode("factory", "9.0.0", 0, 0, app.rules.to_save()).replace("\"schema\":1", "\"schema\":2")
	PopSaveStore.write("test.factory.v1", newer)
	await _reopen()
	assert_eq(String(app.save_info["rejected"]), "newer_schema", "a newer save is refused")
	assert_eq(PopSaveStore.read("test.factory.v1.rejected"), newer, "and kept")


func test_restart_takes_two_taps_and_the_old_factory_stays_recoverable() -> void:
	await _play_factory(app, 20000)
	assert_true(app.save_now(), "saves")
	var before := PopSaveStore.read("test.factory.v1")
	var r0 = app.rules
	assert_false(app.frame.recover_button.visible, "no set-aside icon when nothing was refused")
	assert_true(app.frame.arms_restart, "the factory's restart is armed (saved progress)")
	app.frame._on_restart()
	await tree.process_frame
	assert_true(app.rules == r0, "one tap does not restart the factory")
	assert_eq(PopSaveStore.read("test.factory.v1"), before, "nor touch its save")
	app.frame._on_restart()
	await tree.process_frame
	assert_false(app.rules == r0, "the second tap restarts")
	assert_eq(app.rules.machines.size(), 0, "a new factory")
	assert_eq(PopSaveStore.read("test.factory.v1.bak"), before, "the old factory is the backup")
	# The new run does not write over it for the first ten minutes of play.
	app.dev_advance(5 * 60000)
	app.save_now()
	assert_eq(PopSaveStore.read("test.factory.v1.bak"), before, "five minutes on: still the old factory")
	app.dev_advance(6 * 60000)
	app.save_now()
	assert_ne(PopSaveStore.read("test.factory.v1.bak"), before, "eleven minutes on: the new factory's own backup")


func test_the_stand_the_factory_and_the_experiments_keep_apart() -> void:
	app.open("stand")
	await tree.process_frame
	app.dev_advance(3000)
	assert_true(app.save_now(), "the stand saves")
	var stand := PopSaveStore.read("test.stand.v1")
	app.back()
	await tree.process_frame
	await _play_factory(app, 30000)
	assert_true(app.save_now(), "the factory saves")
	assert_eq(PopSaveStore.read("test.stand.v1"), stand, "the factory never touches the stand's save")
	app.restart()
	app.frame._on_restart()
	app.frame._on_restart()
	await tree.process_frame
	assert_eq(PopSaveStore.read("test.stand.v1"), stand, "nor does restarting the factory")
	for id: String in ["click", "perfect", "explosion"]:
		app.back()
		await tree.process_frame
		app.open(id)
		await tree.process_frame
		assert_false(app.save_now(), "%s is a disposable session" % id)
		assert_eq(PopSaveStore.read("test.%s.v1" % id), "", "%s writes nothing" % id)
	var r := PopSaveDoc.decode(PopSaveStore.read("test.stand.v1"), "stand")
	assert_true(bool(r["ok"]), "the stand's save is whole")
