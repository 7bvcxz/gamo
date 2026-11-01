extends "res://tests/framework/test_case.gd"

## Step 80: Settings > Advanced > Reset All Data, in the game itself with
## saving on (its own save and settings files): folded until opened; the
## button only asks; the dialog sits above everything and needs Continue,
## then the red Erase everything after a moment -- Cancel, the dim or Escape at
## either step change nothing. Confirmed, every store goes (the save with its
## .bak/.tmp/.corrupt, the settings), the old island can never be written
## back, and the next start is a brand-new player's: a new island, no Momo,
## default settings, the tutorial. A store that will not go leaves everything
## as it was and says so. Under tests' no-save nothing on disk is touched;
## in the demo the player's own data still goes.

const MainScene := preload("res://scenes/main.tscn")
const SAVE := "user://test_reset_main_save.json"
const SETTINGS := "user://test_reset_main_settings.json"

var main: Node


func before_each() -> void:
	Engine.remove_meta("momonium_no_save")
	Engine.set_meta("momonium_save_path", SAVE)
	Engine.set_meta("momonium_settings_path", SETTINGS)
	LocaleService.apply("en")


func after_each() -> void:
	if main != null:
		main.queue_free()
		await tree.process_frame
		main = null
	Engine.set_meta("momonium_no_save", true)
	Engine.remove_meta("momonium_save_path")
	Engine.remove_meta("momonium_settings_path")
	Engine.remove_meta("momonium_demo")
	FxPrefs.reset()
	for p: String in _files():
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	LocaleService.apply("en")


func _files() -> Array[String]:
	return [SAVE, SAVE + ".tmp", SAVE + ".bak", SAVE + ".corrupt", SETTINGS]


func _put(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


## A played island on disk: money, a level, Momo with a schedule, a lab, a
## finished research -- with a backup, a temp and a corrupt fragment beside it
## -- and settings that are not the defaults (Korean, tutorial done, tips seen).
func _played() -> void:
	var sim := with_starter_momo(Simulation.new_island())
	(sim.system(&"economy") as EconomySystem).earn(5000, "test")
	(sim.system(&"progression") as ProgressionSystem).add_exp(2000, "test")
	sim.execute({"type": "momo.hire"})
	var bs: BuildingSystem = sim.system(&"buildings")
	bs.place_instant("research", Vector2i(0, 1))
	sim.execute({"type": "momo.watch", "momo": 1, "cells": [[0, 0]], "op": "add"})
	(sim.system(&"research") as ResearchSystem).completed["farm_expansion"] = 0
	SaveService.write(sim, SAVE)
	SaveService.write(sim, SAVE)
	_put(SAVE + ".tmp", "half written")
	_put(SAVE + ".corrupt", "{ broken")
	_put(SETTINGS, JSON.stringify({"language": "ko", "tutorial_done": true, "tips_seen": ["land", "watch"], "music_volume": 0.1, "effects": false}))


func _open() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	(main.get("sim") as Simulation).time_scale = 0.0
	LocaleService.apply("en")


func _disk() -> Dictionary:
	var out := {}
	for p: String in _files():
		out[p] = FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else "<none>"
	return out


func _dialog() -> ResetDialog:
	return main.get("reset_dialog")


## Settings opened, Advanced unfolded, Reset tapped: the first step.
func _ask() -> void:
	var frame: PanelFrame = main.get("settings_frame")
	frame.open()
	var view: SettingsView = main.get("settings_view")
	if not view.advanced_box.visible:
		view.advanced_button.pressed.emit()
	view.reset_button.pressed.emit()


func test_folded_until_opened_and_the_button_only_asks() -> void:
	_played()
	await _open()
	var view: SettingsView = main.get("settings_view")
	(main.get("settings_frame") as PanelFrame).open()
	view.refresh()
	assert_false(view.advanced_box.visible, "Advanced is folded")
	assert_false(view.reset_button.is_visible_in_tree(), "the reset is not on show")
	view.advanced_button.pressed.emit()
	assert_true(view.reset_button.is_visible_in_tree(), "unfolded: Reset All Data")
	assert_eq(view.reset_button.text, "Reset All Data", "in words")
	assert_eq(view.reset_button.theme_type_variation, &"DangerButton", "red")
	assert_true(view.reset_button.custom_minimum_size.y >= 48.0, "a finger's height")
	var disk := _disk()
	view.reset_button.pressed.emit()
	assert_true(_dialog().visible, "the dialog asks")
	assert_eq(_dialog().stage, 1, "step one")
	assert_eq(_disk(), disk, "nothing erased by the button")
	assert_true(_dialog().body.text.contains("island") and _dialog().body.text.contains("Momo") and _dialog().body.text.contains("research"), "it lists what goes (%s)" % _dialog().body.text)
	assert_true(_dialog().kept.text.contains("purchases"), "and what stays")


func test_cancel_the_dim_and_escape_at_either_step_change_nothing() -> void:
	_played()
	await _open()
	var sim: Simulation = main.get("sim")
	var money := (sim.system(&"economy") as EconomySystem).money
	var disk := _disk()
	var d := _dialog()
	# Step one: Cancel, the dim, Escape.
	_ask()
	d.cancel_button.pressed.emit()
	assert_false(d.visible, "Cancel")
	_ask()
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	d.dim.gui_input.emit(tap)
	assert_false(d.visible, "a tap on the dim")
	_ask()
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	d._input(esc)
	assert_false(d.visible, "Escape (a phone's back)")
	# Step two: the red button waits, then Cancel, Escape.
	_ask()
	d.continue_button.pressed.emit()
	assert_eq(d.stage, 2, "Continue: step two")
	assert_true(d.confirm_button.visible and d.confirm_button.disabled, "the red button shows, not yet armed")
	assert_ne(d.confirm_button.get_parent(), d.continue_button.get_parent(), "and not where Continue was")
	d.confirm_button.pressed.emit()
	assert_eq(_disk(), disk, "a double tap through Continue erases nothing")
	d.cancel_button.pressed.emit()
	assert_false(d.visible, "Cancel at step two")
	_ask()
	d.continue_button.pressed.emit()
	d._process(1.0)
	d._input(esc)
	assert_false(d.visible, "Escape at step two")
	assert_eq(_disk(), disk, "every store as it was")
	assert_eq((sim.system(&"economy") as EconomySystem).money, money, "the island as it was")
	assert_true(bool(main.get("persist")), "and still saved as usual")


func test_confirmed_everything_goes_and_the_next_start_is_brand_new() -> void:
	_played()
	await _open()
	var old: Node = main
	var d := _dialog()
	_ask()
	d.continue_button.pressed.emit()
	d._process(ResetDialog.ARM_SECONDS + 0.1)
	assert_false(d.confirm_button.disabled, "armed after a moment")
	d.confirm_button.pressed.emit()
	var r: Dictionary = old.get("last_reset")
	assert_true(r["ok"], "reset (%s)" % [r])
	for p: String in _files():
		assert_false(FileAccess.file_exists(p), "%s is gone" % p.get_file())
	assert_false(d.visible, "the dialog goes")
	# The old island can never write itself back: autosave, focus, the
	# background, the save button.
	assert_ne(old.call("save_now"), OK, "saving is refused")
	old.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	old.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	old.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	old.set("_autosave_left", 0.0)
	old.call("_process", 0.1)
	for p: String in _files():
		assert_false(FileAccess.file_exists(p), "%s stays gone" % p.get_file())
	main.queue_free()
	await tree.process_frame
	main = null
	# The next start (the scene reloads in play): a brand-new player's.
	await _open()
	var sim: Simulation = main.get("sim")
	var fresh := Simulation.new_island()
	assert_eq(main.get("load_status"), "missing", "no save to open")
	assert_eq((sim.system(&"economy") as EconomySystem).money, (fresh.system(&"economy") as EconomySystem).money, "the starting money")
	assert_eq((sim.system(&"progression") as ProgressionSystem).level, 1, "level 1")
	assert_eq((sim.system(&"progression") as ProgressionSystem).experience, 0, "no EXP")
	assert_eq((sim.system(&"momo") as MomoSystem).ids().size(), 0, "no Momo")
	var types: Array = (sim.system(&"buildings") as BuildingSystem).ids().map(func(id: int) -> String: return String((sim.system(&"buildings") as BuildingSystem).get_building(id)["type"]))
	assert_eq(types, ["farm"], "the starting farm alone")
	assert_eq((sim.system(&"research") as ResearchSystem).completed, {}, "no research")
	assert_eq((sim.system(&"prestige") as PrestigeSystem).points, 0, "no legacy points")
	assert_eq(JSON.stringify(sim.snapshot()["buildings"]), JSON.stringify(fresh.snapshot()["buildings"]), "the island a new install opens on")
	var settings: SettingsStore = main.get("settings")
	assert_eq(settings.get_value("language"), "", "the language follows the device again")
	assert_eq(settings.get_value("tutorial_done"), false, "the tutorial is due")
	assert_eq(settings.get_value("tips_seen"), [], "no tip seen")
	assert_eq(settings.get_value("effects"), true, "default settings")
	assert_true((main.get("tutorial") as Tutorial).running, "and the first-run tutorial starts, as for a new install")
	# Opened once more (a refresh): still a brand-new island.
	main.call("save_now")
	main.queue_free()
	await tree.process_frame
	main = null
	await _open()
	var again: Simulation = main.get("sim")
	assert_eq((again.system(&"momo") as MomoSystem).ids().size(), 0, "a refresh: still no Momo")
	assert_eq((again.system(&"economy") as EconomySystem).money, (fresh.system(&"economy") as EconomySystem).money, "and the starting money")


func test_a_store_that_will_not_go_changes_nothing_and_says_so() -> void:
	_played()
	await _open()
	var sim: Simulation = main.get("sim")
	var money := (sim.system(&"economy") as EconomySystem).money
	var disk := _disk()
	var io := FailingIO.new()
	io.fail = SAVE + ".bak"
	_ask()
	_dialog().continue_button.pressed.emit()
	var r: Dictionary = main.call("reset_all_data", io)
	_dialog().show_failure(r["failed"])
	assert_false(r["ok"], "no reset")
	assert_eq(r["failed"], [SAVE + ".bak"], "the backup would not go")
	assert_eq(_disk(), disk, "every store put back as it was")
	assert_true(bool(main.get("persist")), "saving goes on")
	assert_eq((sim.system(&"economy") as EconomySystem).money, money, "the island plays on")
	assert_true(_dialog().failure.visible and _dialog().failure.text.contains("test_reset_main_save.json.bak"), "the dialog says what failed (%s)" % _dialog().failure.text)
	assert_true(_dialog().failure.text.contains("Nothing was reset"), "and that nothing was reset")


class FailingIO extends LocalData.IO:
	var fail := ""

	func remove(s: Dictionary) -> bool:
		return false if String(s["name"]) == fail else super.remove(s)


func test_under_tests_no_save_nothing_on_disk_is_touched() -> void:
	_played()
	Engine.set_meta("momonium_no_save", true)
	await _open()
	var disk := _disk()
	var r: Dictionary = main.call("reset_all_data")
	assert_true(r["ok"], "the game starts over")
	assert_eq(String(r.get("skipped", "")), "saving is off", "and says why it erased nothing")
	assert_eq(_disk(), disk, "no file touched")


func test_in_the_demo_the_players_data_still_goes() -> void:
	_played()
	Engine.set_meta("momonium_demo", "full")
	await _open()
	assert_true(bool(main.get("in_demo")), "in the demo (nothing of it is saved)")
	var r: Dictionary = main.call("reset_all_data")
	assert_true(r["ok"], "reset")
	for p: String in _files():
		assert_false(FileAccess.file_exists(p), "%s gone all the same" % p.get_file())
	assert_false(Engine.has_meta("momonium_demo"), "and the demo left behind")


func test_the_dialog_is_above_everything_and_takes_every_touch() -> void:
	_played()
	await _open()
	var d := _dialog()
	var top := 0
	for n: Node in main.get_children():
		if n is CanvasLayer and n != d:
			top = maxi(top, (n as CanvasLayer).layer)
	assert_true(d.layer > top, "its layer (%d) is over every other (%d)" % [d.layer, top])
	assert_eq(d.dim.mouse_filter, Control.MOUSE_FILTER_STOP, "the dim takes touches")
	# A selected Momo's Schedule button under it is not reached.
	var sel: SelectionController = main.get("selection")
	sel.select_momo(1)
	await tree.process_frame
	var editor: WatchEditor = main.get("watch_editor")
	var at := editor.schedule.get_global_rect().get_center()
	_ask()
	await tree.process_frame
	_touch(at)
	await tree.process_frame
	assert_false(editor.active, "the Schedule button under the dialog did not turn on")
	# Outside the card, on the dim: dismissed, nothing changed.
	_ask()
	await tree.process_frame
	var card := d.card.get_global_rect()
	var corner := Vector2(6, 6)
	assert_false(card.has_point(corner), "a corner is off the card")
	_touch(corner)
	await tree.process_frame
	assert_false(d.visible, "a tap on the dim dismisses the dialog")
	assert_false(editor.active, "and reaches nothing under it")


func _touch(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var m := InputEventMouseButton.new()
		m.button_index = MOUSE_BUTTON_LEFT
		m.position = at
		m.global_position = at
		m.pressed = pressed
		main.get_viewport().push_input(m, true)
