extends SceneTree

## Step 69: the seconds the island's work really takes, from the game's own
## rules -- BuildingSystem.stage_seconds (the one place `work_scale` and every
## speed-up apply), the Momo's multiplier, the construction timer -- for the
## before -> after table of design/INCREMENTAL_BALANCE_REPORT.md.
##
##   godot --headless --path momonium --script res://tools/pace_table.gd

const JOBS := [
	["farm", "sow"], ["farm", "water"], ["farm", "harvest"], ["mine", "dig"],
	["lumberyard", "chop"], ["lumberyard", "replant"], ["research", "study"],
	["smelter", "smelt"], ["steam_engine", "stoke"], ["car_factory", "assemble"], ["game_studio", "design"],
]


func _init() -> void:
	var sim := Simulation.new_game()
	var bs: BuildingSystem = sim.system(&"buildings")
	var momos: MomoSystem = sim.system(&"momo")
	var research: ResearchSystem = sim.system(&"research")
	var specials: SpecialSystem = sim.system(&"specials")
	var world: WorldSystem = sim.system(&"world")
	for x in 6:
		for y in 3:
			world.add_land(Vector2i(x, y))
	for id: int in bs.ids().duplicate():
		bs.demolish(id)
	var m := momos.add_momo(Vector2(0.5, 0.5))
	print("work_scale %.2f  build_scale %.2f  momo x%.2f" % [bs.work_scale(), bs.build_scale(), momos.work_multiplier(m, "farm")])
	print("| job | data s | player s | Momo s | wait s |")
	print("|---|---|---|---|---|")
	for j: Array in JOBS:
		var rec := bs.get_building(bs.place_instant(String(j[0]), Vector2i(0, 0)))
		var st := _stage(bs, rec, String(j[1]))
		var player := bs.stage_seconds(rec, st)
		print("| %s %s | %.1f | %.1f | %.1f | %.1f |" % [j[0], j[1], float(st.get("seconds", 0)), player, player * momos.work_multiplier(m, String(j[0])), bs.stage_cooldown(rec, st)])
		bs.demolish(int(rec["id"]))
	print("| construction | data s | built in s |")
	print("|---|---|---|")
	for type: String in ["farm", "mine", "lumberyard", "research", "smelter", "clock_tower"]:
		print("| %s | %.1f | %.1f |" % [type, float(sim.data.building_type(type).get("build_seconds", 0)), bs.build_seconds_of(type)])
	# Speed-ups compose on top, once: research on the farm's watering and the
	# mine's pickaxes, a Momo's mastery, the Clock Tower's burst.
	var farm := bs.get_building(bs.place_instant("farm", Vector2i(0, 0)))
	var mine := bs.get_building(bs.place_instant("mine", Vector2i(1, 0)))
	var water := _stage(bs, farm, "water")
	var dig := _stage(bs, mine, "dig")
	print("| scenario | seconds |")
	print("|---|---|")
	print("| farm water, no research | %.2f |" % bs.stage_seconds(farm, water))
	print("| mine dig, no research | %.2f |" % bs.stage_seconds(mine, dig))
	for id: String in ["watering_can", "pickaxes"]:
		research.bought[id] = 1
		research.unlocked[id] = true
		research.completed[id] = sim.now_ms()
	print("| farm water, Watering Can Lv1 | %.2f |" % bs.stage_seconds(farm, water))
	print("| mine dig, Pickaxes Lv1 | %.2f |" % bs.stage_seconds(mine, dig))
	var exp: Dictionary = momos.get_momo(m)["experience"]
	exp["mine"] = 1000000
	print("| mine dig, Pickaxes Lv1 + a master Momo (x%.2f) | %.2f |" % [momos.work_multiplier(m, "mine"), bs.stage_seconds(mine, dig) * momos.work_multiplier(m, "mine")])
	var tower := bs.place_instant("clock_tower", Vector2i(3, 0))
	bs.get_building(tower)["state"] = BuildingSystem.IDLE
	var burst := specials.burst(sim.now_ms())
	print("| farm water, Watering Can Lv1 + the Clock Tower burst (%s) | %.2f |" % ["on" if burst["active"] else "off", bs.stage_seconds(farm, water)])
	quit()


func _stage(bs: BuildingSystem, rec: Dictionary, action: String) -> Dictionary:
	for st: Dictionary in bs.stages(rec):
		if String(st.get("action", "")) == action:
			return st
	return {}
