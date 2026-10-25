extends RefCounted

## Capture scenario (Step 48): four Momo, four moods from the real rules --
## free time (heart), a farm's cooldown (dots), a smelter with no ore (sweat
## drop), watching an empty tile (question mark). Frozen by day so the bubbles
## settle; take the shot with --seconds 5 (the capture's frames run faster than
## 60 a second, so 5 "seconds" of frames is about 2.5 s of the game's time).

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	var world: WorldSystem = sim.system(&"world")
	for x in 3:
		for y in 3:
			world.add_land(Vector2i(x, y))
	main.call("_on_hud_action", &"noop")
	(sim.system(&"economy") as EconomySystem).earn(500, "capture")
	for i in 3:
		sim.execute({"type": "momo.hire"})
	var bs: BuildingSystem = sim.system(&"buildings")
	var farm := bs.place_instant("farm", Vector2i(2, 0))
	var smelter := bs.place_instant("smelter", Vector2i(0, 2))
	sim.execute({"type": "momo.assign", "momo": 2, "building": farm})
	sim.execute({"type": "momo.assign", "momo": 3, "building": smelter})
	sim.execute({"type": "momo.watch", "momo": 4, "cells": [[1, 1]], "op": "add"})
	var cycle := DayCycle.new(sim.data)
	var momos: MomoSystem = sim.system(&"momo")
	# A moment by day when all four stand still and the farm waits.
	for i in 12000:
		sim.advance_ms(100)
		var settled := true
		for id: int in momos.ids():
			settled = settled and not momos.is_moving(id)
		var midday := float(sim.clock.time_in_day_ms()) / float(sim.clock.day_ms) < 0.6
		if settled and midday and bs.get_building(farm)["state"] == BuildingSystem.COOLDOWN and not cycle.is_night(sim.clock):
			break
	sim.time_scale = 0.0
	var tips: Tips = main.get("tips")
	tips.allowed = false
	tips.dismiss()
	(main.get("cameras") as CameraController).frame_island()
