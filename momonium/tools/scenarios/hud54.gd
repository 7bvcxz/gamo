extends RefCounted

## Capture scenario (Step 54): the money and EXP display and its feedback at
## the moment they happen, for before/after shots at real gameplay scale.
## MOMONIUM_HUD54 picks the moment:
##   rest    -- a mid-game island, money and the EXP bar part-filled;
##   reward  -- a harvest by hand finishes 20 frames before the shot (its +$
##              over the farm and by the money, its +EXP by the EXP);
##   levelup -- the same harvest's EXP crosses a level 20 frames before.
## Events are the game's own (a real tap and its stage finishing), fired a few
## frames before the capture (capture.gd shoots at --seconds x 60 frames).

const FIRE_FRAME := 105


func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	(main.get("tips") as Tips).allowed = false
	# The island is set up as a catch-up is: quietly. Only the moment's own
	# events give feedback.
	sim.replaying = true
	var world: WorldSystem = sim.system(&"world")
	for x in 3:
		for y in 3:
			world.add_land(Vector2i(x, y))
	var prog: ProgressionSystem = sim.system(&"progression")
	while prog.level < 4:
		prog.add_exp(prog.next_level_exp() - prog.experience, "capture")
	var bs: BuildingSystem = sim.system(&"buildings")
	for id: int in bs.ids().duplicate():
		bs.demolish(id)
	bs.place_instant("research", Vector2i(0, 0))
	bs.place_instant("mine", Vector2i(2, 0))
	bs.place_instant("lumberyard", Vector2i(0, 2))
	var farm := bs.place_ready("farm", Vector2i(1, 1), "harvest")
	(sim.system(&"economy") as EconomySystem).earn(4230 - (sim.system(&"economy") as EconomySystem).money, "capture")
	var moment := OS.get_environment("MOMONIUM_HUD54")
	# Part of the way to the next level -- or one harvest short of it.
	var target := int(prog.next_level_exp() * 0.62)
	if moment == "levelup":
		target = prog.next_level_exp() - 1
	prog.experience = target
	var day: int = sim.clock.day_ms
	sim.advance_ms(posmod(int(0.3 * day) - sim.clock.time_in_day_ms(), day))
	sim.time_scale = 0.0
	sim.replaying = false
	(main.get("celebration") as CanvasItem).hide()
	(main.get("cameras") as CameraController).frame_island()
	if moment == "reward" or moment == "levelup":
		var frames := [0]
		main.get_tree().process_frame.connect(func() -> void:
			frames[0] += 1
			if frames[0] == FIRE_FRAME:
				sim.execute({"type": "building.tap", "id": farm})
				var st: Dictionary = sim.data.building_type("farm")["cycle"]["stages"][2]
				sim.advance_ms(int(float(st["seconds"]) * 1000.0) + 10))
