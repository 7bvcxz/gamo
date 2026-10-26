extends RefCounted

## Capture scenario (Step 52): the world art in one frame -- the four core
## buildings, the three Specials, a farm in each crop stage, two Momo at
## work -- on a 4x3 island, without tips or banners, for the reference / old /
## new comparison. MOMONIUM_CAPTURE_T picks the time of day (a fraction of
## the day), MOMONIUM_CAPTURE_ZOOM zooms in on the middle (1 = framed).
## MOMONIUM_ART52_SET=town shows the thirteen refit buildings instead, on a
## 5x3 island.

const TOWN := {
	"office": Vector2i(0, 0), "villa": Vector2i(1, 0), "apartment": Vector2i(2, 0), "pub": Vector2i(3, 0), "community_center": Vector2i(4, 0),
	"water_wheel": Vector2i(0, 1), "park": Vector2i(1, 1), "game_studio": Vector2i(2, 1), "car_factory": Vector2i(3, 1), "smelter": Vector2i(4, 1),
	"solar_panel": Vector2i(0, 2), "wind_turbine": Vector2i(1, 2), "steam_engine": Vector2i(2, 2),
}

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	var world: WorldSystem = sim.system(&"world")
	var town := OS.get_environment("MOMONIUM_ART52_SET") == "town"
	for x in (5 if town else 4):
		for y in 3:
			world.add_land(Vector2i(x, y))
	main.call("_on_hud_action", &"noop")
	(main.get("tips") as Tips).allowed = false
	var prog: ProgressionSystem = sim.system(&"progression")
	while prog.level < 6:
		prog.add_exp(prog.next_level_exp() - prog.experience, "capture")
	var bs: BuildingSystem = sim.system(&"buildings")
	# The starting farm makes way: every building goes where the frame wants it.
	for id: int in bs.ids().duplicate():
		bs.demolish(id)
	var at: Dictionary = TOWN if town else {
		"research": Vector2i(0, 0), "mine": Vector2i(3, 0), "lumberyard": Vector2i(0, 2),
		"clock_tower": Vector2i(1, 0), "school": Vector2i(2, 0), "momo_monument": Vector2i(3, 2),
	}
	for type: String in at:
		if bs.building_at(at[type]) == 0:
			bs.place_instant(type, at[type])
	# Farms in each stage: bare, sown, growing, ripe.
	var stages := [Vector2i(3, 2), Vector2i(4, 2)] if town else [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 2)]
	for i in stages.size():
		var c: Vector2i = stages[i]
		if bs.building_at(c) != 0:
			continue
		var farm := bs.place_instant("farm", c)
		for k in i:
			sim.execute({"type": "building.tap", "id": farm})
			sim.advance_ms(1500)
			if k == 1:
				sim.advance_ms(3000)
	var momos: MomoSystem = sim.system(&"momo")
	(sim.system(&"economy") as EconomySystem).earn(1000, "capture")
	sim.execute({"type": "momo.hire"})
	var ids := momos.ids()
	if ids.size() >= 2:
		sim.execute({"type": "momo.assign", "momo": ids[0], "building": bs.building_at(Vector2i(3, 0))})
		sim.execute({"type": "momo.assign", "momo": ids[1], "building": bs.building_at(Vector2i(0, 0))})
	sim.advance_ms(6000)
	var t := float(OS.get_environment("MOMONIUM_CAPTURE_T")) if OS.get_environment("MOMONIUM_CAPTURE_T") != "" else 0.3
	var day: int = sim.clock.day_ms
	sim.advance_ms(posmod(int(t * day) - sim.clock.time_in_day_ms(), day))
	sim.time_scale = 0.0
	var tips: Tips = main.get("tips")
	if tips.tip != "":
		tips.dismiss()
	(main.get("celebration") as CanvasItem).hide()
	var cams: CameraController = main.get("cameras")
	cams.frame_island()
	var z := float(OS.get_environment("MOMONIUM_CAPTURE_ZOOM")) if OS.get_environment("MOMONIUM_CAPTURE_ZOOM") != "" else 1.0
	if z != 1.0:
		cams.zoom_at(z, cams.viewport_size() * Vector2(0.5, 0.6))
