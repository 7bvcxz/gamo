extends RefCounted

## Capture scenario (Step 83): the player's hands at work, three at a time
## (the rule). MOMONIUM_HANDS_SET picks the jobs -- farm (sow, water,
## harvest), wood (dig, chop, replant), craft (study, smelt, stoke) or studio
## (design) -- each placed ready at that stage and started by a real
## `building.tap`. MOMONIUM_HANDS_AT is how far into the stage, in seconds
## (the pose of the loop at that moment); MOMONIUM_CAPTURE_ZOOM zooms in.

const SETS := {
	"farm": [["farm", "sow"], ["farm", "water"], ["farm", "harvest"]],
	"wood": [["mine", "dig"], ["lumberyard", "chop"], ["lumberyard", "replant"]],
	"craft": [["research", "study"], ["smelter", "smelt"], ["steam_engine", "stoke"]],
	"studio": [["game_studio", "design"]],
}


func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	var world: WorldSystem = sim.system(&"world")
	for x in 4:
		for y in 3:
			world.add_land(Vector2i(x, y))
	main.call("_on_hud_action", &"noop")
	(main.get("tips") as Tips).allowed = false
	var prog: ProgressionSystem = sim.system(&"progression")
	while prog.level < 40:
		prog.add_exp(prog.next_level_exp() - prog.experience, "capture")
	var bs: BuildingSystem = sim.system(&"buildings")
	for id: int in bs.ids().duplicate():
		bs.demolish(id)
	var inv: InventorySystem = sim.system(&"inventory")
	# Power for the studio (a turbine at the back corner).
	bs.place_instant("wind_turbine", Vector2i(3, 0))
	var set_name := OS.get_environment("MOMONIUM_HANDS_SET")
	var jobs: Array = SETS.get(set_name if set_name != "" else "farm", SETS["farm"])
	# MOMONIUM_HANDS_ONLY=type:action -- that one job alone, in the middle.
	var only := OS.get_environment("MOMONIUM_HANDS_ONLY")
	if only != "":
		jobs = [only.split(":")]
	for i in jobs.size():
		var type := String(jobs[i][0])
		var action := String(jobs[i][1])
		var id := bs.place_instant(type, Vector2i(i + (1 if only != "" else 0), 1))
		if id == 0:
			push_error("hands83: could not place %s" % type)
			continue
		var b := bs.get_building(id)
		var list := bs.stages(b)
		for k in list.size():
			if String((list[k] as Dictionary).get("action", "")) == action:
				b["stage"] = k
				break
		# A building that needs a crew (the studio) gets its Momo first: the
		# player works with them, never in their place.
		var momos: MomoSystem = sim.system(&"momo")
		var short := bs.crew_short(b)
		for k in short:
			var m := momos.add_momo(Vector2(float(i) + 1.5, 2.5))
			sim.execute({"type": "momo.assign", "momo": m, "building": id})
		# The crew walks over; the player taps as soon as it is there.
		for k in 600:
			if bs.crew_short(b) == 0 or b["state"] != BuildingSystem.IDLE:
				break
			sim.advance_ms(100)
		if short > 0:
			print("hands83: crew there, %s %s %s by %d" % [type, b["state"], "worked" if b["state"] == BuildingSystem.WORKING else "", int(b["worker"])])
		# What the stage takes, in the store; what it makes, room for.
		var stage := bs.current_stage(b)
		for item: String in stage.get("consumes", {}):
			inv.add(item, int(stage["consumes"][item]) * 4, "capture")
		var r := sim.execute({"type": "building.tap", "id": id})
		if not r["ok"]:
			push_error("hands83: %s %s did not start: %s" % [type, action, r])
	var at := float(OS.get_environment("MOMONIUM_HANDS_AT")) if OS.get_environment("MOMONIUM_HANDS_AT") != "" else 0.5
	sim.advance_ms(int(at * 1000.0))
	sim.time_scale = 0.0
	(main.get("celebration") as CanvasItem).hide()
	var tips: Tips = main.get("tips")
	if tips.tip != "":
		tips.dismiss()
	var cams: CameraController = main.get("cameras")
	cams.frame_island()
	var z := float(OS.get_environment("MOMONIUM_CAPTURE_ZOOM")) if OS.get_environment("MOMONIUM_CAPTURE_ZOOM") != "" else 1.0
	if z != 1.0:
		cams.zoom_at(z, cams.viewport_size() * Vector2(0.5, 0.5))
	var hw: HandWorks = main.get("hand_works")
	print("hands83: ", hw.shown().keys().size(), " hands, manual ", bs.manual_slots_used(), "/", bs.manual_limit())
	# Where each hand is in the window, for cropping (the capture's frame).
	(func() -> void:
		await main.get_tree().process_frame
		var vp: Viewport = main.get_viewport()
		var to_win := vp.get_final_transform() * vp.get_canvas_transform()
		var shown := hw.shown()
		for id: int in shown:
			var r: Rect2 = shown[id]["rect"]
			var a: Vector2 = to_win * r.position
			var b2: Vector2 = to_win * r.end
			print("HAND %s %d %d %d %d" % [shown[id]["pose"], int(a.x), int(a.y), int(b2.x - a.x), int(b2.y - a.y)])).call()
