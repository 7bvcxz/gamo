extends "res://tests/framework/test_case.gd"

## Step 68: tap, tap, THUNK. While a Momo works, its tool's landing (the
## animation's contact frame) is a quiet tap -- only from Momo on screen, a
## few a second at most across the island. When the simulation finishes the
## job, exactly then and exactly once: the THUNK sound, a ring and rays at
## the building, and the money/resources it earned through the existing
## FeedbackFx. Nothing for a job cut short, nothing while time away is
## caught up, no flourish with effects off, no squash with reduced motion.

const MainScene := preload("res://scenes/main.tscn")

var main: Node
var sim: Simulation
var bs: BuildingSystem
var momos: MomoSystem
var audio: AudioService
var fx: FeedbackFx
var views: BuildingViews
var mviews: MomoViews


func before_each() -> void:
	FxPrefs.reset()
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	sim = main.get("sim")
	sim.time_scale = 0.0
	with_starter_momo(sim)
	await tree.process_frame
	bs = sim.system(&"buildings")
	momos = sim.system(&"momo")
	audio = main.get("audio")
	fx = main.get("feedback_fx")
	views = main.get("building_views")
	mviews = main.get("momo_views")
	audio.clock_ms = 100000


func after_each() -> void:
	FxPrefs.reset()
	main.queue_free()
	await tree.process_frame


## A mine with the starter Momo at work in it, its dig half done.
func _mine_at_work() -> int:
	for id: int in bs.ids().duplicate():
		bs.demolish(id)
	var b := bs.place_instant("mine", Vector2i(1, 0))
	sim.execute({"type": "momo.assign", "momo": 1, "building": b})
	for i in 400:
		sim.advance_ms(200)
		if bs.get_building(b)["state"] == BuildingSystem.WORKING:
			break
	assert_eq(bs.get_building(b)["state"], BuildingSystem.WORKING, "the mine is at work")
	return b


func _view(b: int) -> BuildingView:
	return views.views[b]


func test_one_finished_job_is_one_thunk_one_flourish_one_reward() -> void:
	var b := _mine_at_work()
	await tree.process_frame
	audio.played.clear()
	fx.shown.clear()
	var before := _view(b).impacts
	var done := [0]
	var count := func(type: StringName, p: Dictionary) -> void:
		if type == &"task_completed" and int(p.get("id", 0)) == b:
			done[0] += 1
	sim.bus.emitted.connect(count)
	# To the end of the stage, and no further than one completion.
	var end := int(bs.get_building(b)["task_end"])
	sim.advance_ms(end - sim.now_ms() + 1)
	sim.bus.emitted.disconnect(count)
	assert_eq(done[0], 1, "the simulation finished the job once")
	assert_eq(int(audio.played.get("thunk", 0)), 1, "THUNK, once, with it")
	assert_eq(_view(b).impacts - before, 1, "one flourish at the mine")
	var money := fx.shown.filter(func(s: Dictionary) -> bool: return String(s["kind"]) == "money")
	assert_eq(money.size(), 1, "the money it earned, once, by the existing pops (%s)" % [fx.shown])


func test_a_job_cut_short_gives_no_finish() -> void:
	var b := _mine_at_work()
	audio.played.clear()
	var before := _view(b).impacts
	sim.execute({"type": "momo.unassign", "momo": 1})
	bs.demolish(b)
	sim.advance_ms(60000)
	assert_eq(int(audio.played.get("thunk", 0)), 0, "no THUNK for work that did not finish")
	assert_eq(_view(b).impacts if views.views.has(b) else before, before, "no flourish")


func test_harvest_keeps_its_own_sound_and_unmanned_work_is_quiet() -> void:
	audio.played.clear()
	sim.bus.emit(&"task_completed", {"id": 1, "stage": "harvest", "type": "farm", "worker": 1})
	assert_eq(int(audio.played.get("harvest", 0)), 1, "a harvest: its own")
	assert_eq(int(audio.played.get("thunk", 0)), 0, "not also a THUNK")
	audio.clock_ms += 1000
	sim.bus.emit(&"task_completed", {"id": 1, "stage": "stoke", "type": "steam_engine", "worker": 0})
	assert_eq(int(audio.played.get("thunk", 0)), 0, "no Momo did it: no THUNK")


func test_many_finishing_together_are_one_thunk() -> void:
	audio.played.clear()
	for i in 10:
		sim.bus.emit(&"task_completed", {"id": i + 1, "stage": "dig", "type": "mine", "worker": i + 1})
	assert_eq(int(audio.played.get("thunk", 0)), 1, "ten at once: one THUNK, not a cascade")
	audio.clock_ms += 400
	sim.bus.emit(&"task_completed", {"id": 1, "stage": "dig", "type": "mine", "worker": 1})
	assert_eq(int(audio.played.get("thunk", 0)), 2, "the next one later is heard")


func test_time_away_is_silent_and_still() -> void:
	var b := _mine_at_work()
	audio.played.clear()
	var before := _view(b).impacts
	sim.replaying = true
	sim.advance_ms(120000)
	audio.tap("tap_pick")
	sim.replaying = false
	assert_true(int(bs.get_building(b).get("completed", 0)) > 0, "work was done meanwhile")
	assert_eq(audio.played, {}, "no sound for time caught up (%s)" % [audio.played])
	assert_eq(_view(b).impacts, before, "no flourish either")


func test_effects_off_no_flourish_but_the_sound_follows_the_sound_settings() -> void:
	var b := _mine_at_work()
	await tree.process_frame
	FxPrefs.enabled = false
	audio.played.clear()
	var before := _view(b).impacts
	sim.advance_ms(int(bs.get_building(b)["task_end"]) - sim.now_ms() + 1)
	assert_eq(_view(b).impacts, before, "effects off: no flourish")
	assert_eq(int(audio.played.get("thunk", 0)), 1, "the sound is the sound settings' to silence")


func test_reduced_motion_flashes_without_squash() -> void:
	var b := _mine_at_work()
	await tree.process_frame
	FxPrefs.reduced_motion = true
	var v := _view(b)
	v.set("_bounce", 0.0)
	v.impact()
	assert_eq(v.get("_bounce"), 0.0, "no squash")
	assert_true(float(v.get("_impact")) > 0.0, "the ring still flashes")


## The taps: a Momo's tool landing, from its rig's contact frame, while seen.
func test_a_working_momo_taps_on_its_strike_and_the_island_stays_quiet() -> void:
	var b := _mine_at_work()
	await tree.process_frame
	var actor: MomoActor = mviews.actors[1]
	audio.played.clear()
	var strikes := [0]
	actor.rig.struck.connect(func(pose: String) -> void:
		strikes[0] += 1
		assert_eq(pose, "dig", "the dig's strike"))
	actor._process(0.0)
	for i in 60 * 6:
		actor.rig.tick(1.0 / 60.0)
		audio.clock_ms += 16
	assert_true(strikes[0] >= 4, "the pickaxe landed on every pass (%d in 6 s)" % strikes[0])
	assert_true(int(audio.played.get("tap_pick", 0)) >= 4, "and each was a tap (%d)" % int(audio.played.get("tap_pick", 0)))
	assert_eq(int(bs.get_building(b).get("completed", 0)), 0, "tapping finishes nothing")
	# Ten Momo striking at once across the island: a few taps a second.
	audio.played.clear()
	for t in 60:
		for k in 10:
			audio.tap("tap_wood")
		audio.clock_ms += 50
	var n := int(audio.played.get("tap_wood", 0))
	assert_between(n, 8, 11, "ten Momo for three seconds: about three taps a second (%d)" % n)


func test_taps_are_quiet_and_on_their_own_players() -> void:
	audio.tap("tap_metal")
	var p: AudioStreamPlayer = audio.taps[0] if audio.taps[0].playing else audio.taps[1]
	assert_true(p.playing, "a tap plays")
	assert_eq(p.bus, &"Effects", "on the effects bus (its volume, mute)")
	assert_near(p.volume_db, AudioService.TAP_DB, 0.01, "well under the effects")
	for v: AudioStreamPlayer in audio.voices:
		assert_false(v.stream != null and v.stream.resource_path.contains("tap_"), "never a reward's voice")


func test_every_job_has_a_tap_on_a_frame_it_has() -> void:
	var sheet := MomoSheet.shared()
	for anim: String in sheet.animations:
		var a: Dictionary = sheet.animations[anim]
		if not a.has("durations"):
			continue
		assert_true(int(a.get("contact", -1)) >= 0 and int(a.get("contact", -1)) < (a["cells"] as Array).size(), "%s: a contact frame" % anim)
		assert_true(ResourceLoader.exists("res://assets/audio/sfx_%s.ogg" % String(a.get("tap", ""))), "%s: a tap sound" % anim)
	assert_true(ResourceLoader.exists("res://assets/audio/sfx_thunk.ogg"), "the THUNK")
