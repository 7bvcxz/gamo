extends "res://tests/framework/test_case.gd"

## Step 66: on the island a Momo at work holds the tool of the job the
## simulation has it doing -- sowing, watering and harvesting at a farm,
## digging at a mine, felling and replanting at a lumberyard, studying at a
## lab, hammering at a smelter and a car factory, stoking a steam engine,
## writing at a game studio -- drawn from the work atlas on its own pivot,
## the feet where they always are; and puts it away when the work stops.

var sim: Simulation
var momos: MomoSystem
var bs: BuildingSystem
var actors: Array[MomoActor] = []


func before_each() -> void:
	sim = with_starter_momo(Simulation.new_game())
	momos = sim.system(&"momo")
	bs = sim.system(&"buildings")


func after_each() -> void:
	for a: MomoActor in actors:
		a.queue_free()
	actors.clear()
	await tree.process_frame


func _actor(id: int) -> MomoActor:
	var a := MomoActor.new()
	a.setup(id, sim, null, IsoProjection.new())
	tree.root.add_child(a)
	a.set_process(false)
	a.rig.set_process(false)
	actors.append(a)
	return a


func _show(a: MomoActor) -> String:
	a._process(0.0)
	a.rig.tick(0.0)
	return a.rig.cell_name()


func test_the_real_cycle_shows_each_stage_tool() -> void:
	# A farm, a mine, a lumberyard and a lab run by the starter Momo, as the
	# job rules dispatch it: every stage it works shows that stage's pose.
	var cells := {"farm": Vector2i(1, 0), "mine": Vector2i(0, 1), "lumberyard": Vector2i(1, 1), "research": Vector2i(0, 0)}
	var want := {"sow": "sow_0", "water": "water_0", "harvest": "harvest_0", "dig": "dig_0", "chop": "chop_0", "replant": "replant_0", "study": "study_0"}
	var a := _actor(1)
	for id: int in bs.ids().duplicate():
		bs.demolish(id)
	for type: String in cells:
		var b := bs.place_instant(type, cells[type])
		assert_true(b > 0, "%s placed" % type)
		sim.execute({"type": "momo.assign", "momo": 1, "building": b})
		var seen := {}
		for i in 1600:
			sim.advance_ms(250)
			if a.is_working():
				var stage := String(bs.current_stage(bs.get_building(b)).get("action", ""))
				seen[stage] = _show(a)
			if seen.size() >= bs.stages(bs.get_building(b)).size():
				break
		for stage: String in seen:
			assert_eq(String(seen[stage]), String(want[stage]), "%s: %s shows %s" % [type, stage, want[stage]])
		assert_eq(seen.size(), bs.stages(bs.get_building(b)).size(), "%s: every stage worked (%s)" % [type, seen.keys()])
		sim.execute({"type": "momo.unassign", "momo": 1})
		bs.demolish(b)


func test_every_job_on_the_island_draws_its_tool_from_the_atlas() -> void:
	var sheet := MomoSheet.shared()
	for id: int in bs.ids().duplicate():
		bs.demolish(id)
	var data: Dictionary = sim.data.table("buildings")["types"]
	var x := 0
	for type: String in data:
		var t: Dictionary = data[type]
		var stages: Array = (t.get("cycle", {}) as Dictionary).get("stages", [])
		for i in stages.size():
			var b := bs.place_instant(type, Vector2i(x % 3, x / 3))
			x += 1
			if b == 0:
				continue
			var m := momos.add_momo(momos.work_spot(b))
			var rec := bs.get_building(b)
			rec["state"] = BuildingSystem.WORKING
			rec["stage"] = i
			rec["worker"] = m
			momos.get_momo(m)["assigned"] = b
			var a := _actor(m)
			var action := String((stages[i] as Dictionary).get("action", ""))
			var frame := _show(a)
			var pose := sheet.work_animation(action)
			assert_eq(frame, pose + "_0", "%s %s: %s" % [type, action, pose])
			assert_eq(a.rig.body.texture, sheet.work_texture, "%s: from the work atlas" % action)
			assert_eq(a.rig.body.region_rect, sheet.region(frame), "%s: its frame" % action)
			assert_eq(a.rig.body.offset, -sheet.pivot_of(frame), "%s: the feet on the ground point" % action)
			assert_eq(a.rig.scale.x, -1.0, "%s: facing the building (left), mirrored" % action)
			bs.demolish(b)
			x -= 1


func test_the_tool_goes_away_when_the_work_stops() -> void:
	var sheet := MomoSheet.shared()
	for id: int in bs.ids().duplicate():
		bs.demolish(id)
	var b := bs.place_instant("mine", Vector2i(1, 0))
	sim.execute({"type": "momo.assign", "momo": 1, "building": b})
	var a := _actor(1)
	var worked := false
	for i in 400:
		sim.advance_ms(250)
		if a.is_working():
			worked = true
			assert_eq(_show(a), "dig_0", "at work: the pickaxe")
			break
	assert_true(worked, "it went to work")
	sim.execute({"type": "momo.unassign", "momo": 1})
	var cell := _show(a)
	assert_false(cell.ends_with("_0") and sheet.work_frames.has(cell), "off work: no tool (%s)" % cell)
	assert_eq(a.rig.body.texture, sheet.texture, "back on the sheet")
	assert_eq(a.rig.body.offset, -sheet.pivot, "with the sheet's pivot")


## Step 67: the swing runs on the real seconds the rig is given, not the
## simulation's clock -- a stopped simulation still shows the job moving, a
## simulation run ahead without frames shows nothing new -- and drawing it
## never touches the work: no stage ends, nothing is paid.
func test_the_swing_is_presentation_on_its_own_clock() -> void:
	for id: int in bs.ids().duplicate():
		bs.demolish(id)
	var b := bs.place_instant("mine", Vector2i(1, 0))
	sim.execute({"type": "momo.assign", "momo": 1, "building": b})
	var a := _actor(1)
	for i in 400:
		sim.advance_ms(250)
		if a.is_working():
			break
	assert_true(a.is_working(), "at work")
	var rec := bs.get_building(b)
	var end_ms := int(rec["task_end"])
	var state := int(rec["state"])
	var completed := [0]
	var count := func(type: StringName, _p: Dictionary) -> void:
		if type == &"task_completed":
			completed[0] += 1
	sim.bus.emitted.connect(count)
	a._process(0.0)
	var seen := {}
	for i in 600:
		a.rig.tick(1.0 / 60.0)
		seen[a.rig.cell_name()] = true
	assert_eq(seen.size(), 4, "ten real seconds, the clock stopped: all four frames (%s)" % [seen.keys()])
	assert_eq(int(bs.get_building(b)["task_end"]), end_ms, "the stage did not move")
	assert_eq(int(bs.get_building(b)["state"]), state, "nor its state")
	assert_eq(completed[0], 0, "no frame finished any work")
	var shown := a.rig.cell_name()
	sim.advance_ms(200)
	assert_eq(a.rig.cell_name(), shown, "the simulation moving does not step the swing")
	sim.bus.emitted.disconnect(count)


func test_many_momos_do_not_swing_in_step() -> void:
	for id: int in bs.ids().duplicate():
		bs.demolish(id)
	var rigs: Array[MomoRig] = []
	for i in 4:
		var b := bs.place_instant("mine", Vector2i(i % 2, i / 2))
		var m := momos.add_momo(momos.work_spot(b))
		var rec := bs.get_building(b)
		rec["state"] = BuildingSystem.WORKING
		rec["worker"] = m
		momos.get_momo(m)["assigned"] = b
		var a := _actor(m)
		a._process(0.0)
		rigs.append(a.rig)
		# They start a moment apart, as Momos arrive.
		for k in i * 13:
			a.rig.tick(1.0 / 60.0)
	var apart := 0
	for t in 300:
		var frames := {}
		for r: MomoRig in rigs:
			r.tick(1.0 / 60.0)
			frames[r.cell_name()] = true
		if frames.size() > 1:
			apart += 1
	assert_true(apart > 150, "four miners mostly on different frames (%d of 300)" % apart)


func test_a_loaded_island_works_on_with_its_tools() -> void:
	for id: int in bs.ids().duplicate():
		bs.demolish(id)
	var b := bs.place_instant("lumberyard", Vector2i(1, 0))
	sim.execute({"type": "momo.assign", "momo": 1, "building": b})
	for i in 400:
		sim.advance_ms(250)
		if bs.get_building(b)["state"] == BuildingSystem.WORKING and momos.at_work(1):
			break
	var loaded := SaveService.decode(SaveService.encode(sim))
	assert_eq(loaded["status"], "ok", "the save opens")
	sim = Simulation.from_save(loaded["state"])
	momos = sim.system(&"momo")
	bs = sim.system(&"buildings")
	var a := _actor(1)
	assert_true(a.is_working(), "still at work after the load")
	a._process(0.0)
	var seen := {}
	for i in 300:
		a.rig.tick(1.0 / 60.0)
		seen[a.rig.cell_name()] = true
	var job := MomoSheet.shared().work_animation(String(bs.current_stage(bs.get_building(b)).get("action", "")))
	assert_true(seen.size() >= 4, "and swinging again: %s" % [seen.keys()])
	for c: String in seen:
		assert_true(c.begins_with(job + "_"), "%s: a %s frame" % [c, job])
