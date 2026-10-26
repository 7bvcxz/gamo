extends "res://tests/framework/test_case.gd"

## Step 48: a Momo's mood comes from the real job rules -- free time, waiting
## on a cooldown, nothing on its tiles, an input short, the store full, the
## night -- and shows as at most one small bubble, calmly and sparingly:
## after the reason holds a moment, for a few seconds, then resting; never
## while it works, walks, sleeps or holds up a letter; the same after a load.

const MainScene := preload("res://scenes/main.tscn")

var sim: Simulation
var momos: MomoSystem
var bs: BuildingSystem


func before_each() -> void:
	FxPrefs.reset()
	sim = with_starter_momo(Simulation.new_game())
	momos = sim.system(&"momo")
	bs = sim.system(&"buildings")


## Advance until `f` holds (at most `limit_ms`); true when it did.
func _until(f: Callable, limit_ms: int = 120000, step_ms: int = 250) -> bool:
	var t := 0
	while t < limit_ms:
		if f.call():
			return true
		sim.advance_ms(step_ms)
		t += step_ms
	return f.call()


## Daytime: at night a Momo not at work is asleep and has no mood.
func _day() -> bool:
	return not DayCycle.new(sim.data).is_night(sim.clock)


func _farm_with_momo() -> int:
	var f := bs.place_instant("farm", Vector2i(1, 0))
	sim.execute({"type": "momo.assign", "momo": 1, "building": f})
	return f


func test_free_time_is_content() -> void:
	assert_true(_until(func() -> bool: return not momos.is_moving(1)), "a moment standing still")
	assert_eq(MomoMood.reason(sim, 1), "free", "no building, no tiles: free time")
	assert_eq(MomoMood.mood(sim, 1), "content")


func test_working_and_walking_have_no_mood() -> void:
	var f := _farm_with_momo()
	assert_true(momos.is_moving(1) or (sim.system(&"jobs") as JobSystem).is_working(1), "on the way or at work")
	assert_eq(MomoMood.reason(sim, 1), "", "no mood on the way")
	assert_true(_until(func() -> bool: return (sim.system(&"jobs") as JobSystem).is_working(1)), "it starts the job")
	assert_eq(MomoMood.reason(sim, 1), "", "no mood while working")
	assert_true(f != 0)


func test_a_cooldown_is_thinking() -> void:
	var f := _farm_with_momo()
	assert_true(_until(func() -> bool: return bs.get_building(f)["state"] == BuildingSystem.COOLDOWN and _day()), "the farm reaches a wait by day")
	assert_eq(MomoMood.reason(sim, 1), "waiting", "waiting for the plants")
	assert_eq(MomoMood.mood(sim, 1), "thinking")


func test_tiles_with_nothing_on_them_are_confusing() -> void:
	assert_true(_until(func() -> bool: return not momos.is_moving(1)))
	assert_true(sim.execute({"type": "momo.watch", "momo": 1, "cells": [[0, 1]], "op": "add"})["ok"], "watches an empty tile")
	assert_eq(MomoMood.reason(sim, 1), "no_work")
	assert_eq(MomoMood.mood(sim, 1), "confused")


func test_a_missing_input_is_worrying() -> void:
	var s := bs.place_instant("smelter", Vector2i(1, 0))
	sim.execute({"type": "momo.assign", "momo": 1, "building": s})
	assert_true(_until(func() -> bool: return not momos.is_moving(1)), "it arrives")
	assert_eq(String(bs.can_start(s)["reason"]), "err.missing_inputs", "no ore in the store")
	assert_eq(MomoMood.reason(sim, 1), "short")
	assert_eq(MomoMood.mood(sim, 1), "worried")


func test_a_full_store_is_worrying() -> void:
	# Research notes are never sold, so a full store of them stays full
	# (wood and crops are sold rather than stop the work, Step 50).
	var inv: InventorySystem = sim.system(&"inventory")
	inv.add("notes", inv.room_for("notes"), "test")
	var l := bs.place_instant("research", Vector2i(1, 0))
	sim.execute({"type": "momo.assign", "momo": 1, "building": l})
	assert_true(_until(func() -> bool: return not momos.is_moving(1)), "it arrives")
	assert_eq(String(bs.can_start(l)["reason"]), "err.storage_full", "nowhere to put the notes")
	assert_eq(MomoMood.reason(sim, 1), "full")
	assert_eq(MomoMood.mood(sim, 1), "worried")


func test_night_has_no_mood() -> void:
	var cycle := DayCycle.new(sim.data)
	assert_true(_until(func() -> bool: return cycle.is_night(sim.clock), 40000), "night falls")
	assert_eq(MomoMood.reason(sim, 1), "", "asleep: the z's say it")


func test_the_most_urgent_of_several_buildings_wins() -> void:
	var f := bs.place_instant("farm", Vector2i(1, 0))
	var s := bs.place_instant("smelter", Vector2i(0, 1))
	sim.execute({"type": "momo.assign", "momo": 1, "building": f})
	assert_true(_until(func() -> bool: return bs.get_building(f)["state"] == BuildingSystem.COOLDOWN and not momos.is_moving(1) and _day()), "the farm waits by day")
	sim.execute({"type": "momo.watch", "momo": 1, "cells": [[0, 1]], "op": "add"})
	assert_eq(MomoMood.reason(sim, 1), "short", "a missing input outranks a wait")
	assert_true(s != 0)


func test_the_mood_is_the_same_after_a_load() -> void:
	var f := _farm_with_momo()
	assert_true(_until(func() -> bool: return bs.get_building(f)["state"] == BuildingSystem.COOLDOWN and _day()))
	var before := MomoMood.reason(sim, 1)
	assert_eq(before, "waiting")
	var loaded := SaveService.decode(SaveService.encode(sim))
	assert_eq(loaded["status"], "ok", "the save opens")
	var again := Simulation.from_save(loaded["state"])
	assert_eq(MomoMood.reason(again, 1), before, "derived, not saved: the same after a load")
	assert_false(JSON.stringify(SaveService.encode(sim)).contains("mood"), "nothing about moods is saved")


# --- the bubble ---------------------------------------------------------------

func _bubble() -> MoodBubble:
	var b := MoodBubble.new()
	b.setup(SpriteLibrary.load_atlas())
	return b


func _run(b: MoodBubble, reason: String, seconds: float, held: bool = false) -> void:
	var steps := int(seconds / 0.05)
	for i in steps:
		b.step(0.05, reason, held, Vector2.ZERO)


func test_a_mood_waits_to_settle_then_shows_briefly_then_rests() -> void:
	var b := _bubble()
	_run(b, "free", 1.0)
	assert_eq(b.mood, "", "not before it settles")
	_run(b, "free", 0.6)
	assert_eq(b.mood, "content", "then the heart")
	_run(b, "free", 3.3)
	assert_eq(b.mood, "", "for a few seconds only")
	_run(b, "free", 20.0)
	assert_eq(b.shown_count, 1, "resting: not back within half a minute")
	_run(b, "free", 12.0)
	assert_eq(b.shown_count, 2, "and back after")
	b.free()


func test_it_goes_at_once_when_work_starts_and_yields_to_the_letter() -> void:
	var b := _bubble()
	_run(b, "short", 2.0)
	assert_eq(b.mood, "worried")
	_run(b, "", 0.1)
	assert_eq(b.mood, "", "work started: gone")
	var c := _bubble()
	_run(c, "short", 4.0, true)
	assert_eq(c.mood, "", "a letter held up: no bubble beside it")
	b.free()
	c.free()


func test_flapping_reasons_do_not_blink() -> void:
	var b := _bubble()
	for i in 40:
		_run(b, "waiting" if i % 2 == 0 else "", 0.5)
	assert_true(b.shown_count <= 1, "a reason that never holds 1.5 s never shows (%d)" % b.shown_count)
	var c := _bubble()
	for i in 12:
		_run(c, "waiting", 2.0)
		_run(c, "", 1.0)
	assert_true(c.shown_count <= 3, "waits between jobs all afternoon: rarely, not every time (%d in 36 s)" % c.shown_count)
	b.free()
	c.free()


func test_on_the_island_each_momo_has_at_most_one_bubble_and_takes_no_input() -> void:
	sim = null
	var main: Node = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var live: Simulation = main.get("sim")
	for i in 5:
		live.execute({"type": "momo.hire"})
	var views: MomoViews = main.get("momo_views")
	views.sync()
	for i in 120:
		await tree.process_frame
	for id: int in views.actors:
		var a: MomoActor = views.actors[id]
		assert_eq(a.get_children().filter(func(c: Node) -> bool: return c is MoodBubble).size(), 1, "Momo %d: one bubble node" % id)
		var node: Object = a.mood_bubble
		assert_false(node is Control, "a sprite, not a control: it takes no taps")
	main.queue_free()
	await tree.process_frame
