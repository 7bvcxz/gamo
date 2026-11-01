extends SceneTree

## The seconds the island's work really takes, from the game's own rules --
## BuildingSystem.stage_seconds (the one place the work's scales and every
## speed-up apply), stage_cooldown (the one place the wait's do), the Momo's
## multiplier and build_seconds_of (construction). Step 69 wrote it for the
## before -> after table of design/INCREMENTAL_BALANCE_REPORT.md; Step 78
## widened it to every building, variety and recipe, the waits and their
## floors, and the speed-ups that compose on top (design/PACE78.md).
##
##   godot --headless --path momonium --script res://tools/pace_table.gd

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
	var pace: Dictionary = sim.data.get_value("balance", "pace", {})
	print("scales: %s" % JSON.stringify(_without_doc(pace)))
	print("work_scale() %.4f  wait_scale() %.4f  build_scale() %.4f  momo x%.2f" % [bs.work_scale(), _wait(bs), bs.build_scale(), momos.work_multiplier(m, "farm")])
	print("")
	print("| building | variety / recipe | stage | data s | player s | Momo s | data wait | wait s | wait floor s |")
	print("|---|---|---|---|---|---|---|---|---|")
	for type: String in sim.data.table("buildings")["types"]:
		var def := sim.data.building_type(type)
		if not def.has("cycle"):
			continue
		var kinds: Array = []
		if def.has("recipes"):
			for r: String in bs.recipes(type):
				kinds.append({"recipe": r})
		elif bs.varieties(type).size() > 0:
			for v: String in bs.varieties(type):
				kinds.append({"variety": v})
		else:
			kinds.append({})
		for k: Dictionary in kinds:
			var rec := {"id": 0, "type": type}
			rec.merge(k)
			for st: Dictionary in bs.stages(rec):
				var player := bs.stage_seconds(rec, st)
				var floor_s := float(st.get("cooldown_floor", 0.0)) * _wait(bs)
				print("| %s | %s | %s | %.1f | %.1f | %.1f | %.1f | %.1f | %s |" % [type, String(k.values()[0]) if not k.is_empty() else "-", st.get("id", ""),
					float(st.get("seconds", 0)), player, player * momos.work_multiplier(m, type),
					float(st.get("cooldown", 0)), bs.stage_cooldown(rec, st), ("%.1f" % floor_s) if st.has("cooldown_floor") else "-"])
	print("")
	print("| construction | data s | built in s |")
	print("|---|---|---|")
	for type: String in sim.data.table("buildings")["types"]:
		print("| %s | %.1f | %.1f |" % [type, float(sim.data.building_type(type).get("build_seconds", 0)), bs.build_seconds_of(type)])
	# A whole farm cycle as a Momo works it (work x the Momo, plus the waits).
	var farm := bs.get_building(bs.place_instant("farm", Vector2i(0, 0)))
	var mine := bs.get_building(bs.place_instant("mine", Vector2i(1, 0)))
	print("")
	print("| scenario | seconds |")
	print("|---|---|")
	var est := bs.cycle_estimate(farm, momos.work_multiplier(m, "farm"))
	print("| farm cycle by a new Momo (work %.1f + wait %.1f) | %.1f |" % [est["work_seconds"], est["wait_seconds"], est["cycle_seconds"]])
	est = bs.cycle_estimate(farm, 1.0)
	print("| farm cycle by hand (work %.1f + wait %.1f) | %.1f |" % [est["work_seconds"], est["wait_seconds"], est["cycle_seconds"]])
	var water := _stage(bs, farm, "water")
	var dig := _stage(bs, mine, "dig")
	print("| farm water, no research | %.2f |" % bs.stage_seconds(farm, water))
	print("| farm: the wait after watering (crop ripens), no research | %.2f |" % bs.stage_cooldown(farm, water))
	print("| mine dig, no research | %.2f |" % bs.stage_seconds(mine, dig))
	for id: String in ["watering_can", "pickaxes"]:
		research.bought[id] = 1
		research.unlocked[id] = true
		research.completed[id] = sim.now_ms()
	print("| farm water, Watering Can Lv1 | %.2f |" % bs.stage_seconds(farm, water))
	print("| mine dig, Pickaxes Lv1 | %.2f |" % bs.stage_seconds(mine, dig))
	for id: String in ["drip_irrigation"]:
		research.bought[id] = 1
		research.unlocked[id] = true
		research.completed[id] = sim.now_ms()
	print("| farm: the wait after watering, Drip Irrigation (x0.8 of the wait) | %.2f |" % bs.stage_cooldown(farm, water))
	var exp: Dictionary = momos.get_momo(m)["experience"]
	exp["mine"] = 1000000
	print("| mine dig, Pickaxes Lv1 + a master Momo (x%.2f) | %.2f |" % [momos.work_multiplier(m, "mine"), bs.stage_seconds(mine, dig) * momos.work_multiplier(m, "mine")])
	var tower := bs.place_instant("clock_tower", Vector2i(3, 0))
	bs.get_building(tower)["state"] = BuildingSystem.IDLE
	var burst := specials.burst(sim.now_ms())
	print("| farm water, Watering Can Lv1 + the Clock Tower burst (%s) | %.2f |" % ["on" if burst["active"] else "off", bs.stage_seconds(farm, water)])
	print("")
	print("| research topic (not building production) | seconds |")
	print("|---|---|")
	for id: String in ["watering_can", "drip_irrigation", "pickaxes"]:
		print("| %s | %.0f |" % [id, research.duration_ms(id) / 1000.0])
	quit()


## The wait's scale (Step 78), or 1 on a build before it (the baseline run).
func _wait(bs: BuildingSystem) -> float:
	return float(bs.call("wait_scale")) if bs.has_method("wait_scale") else 1.0


func _without_doc(d: Dictionary) -> Dictionary:
	var out := d.duplicate(true)
	out.erase("_doc")
	for k: String in out.keys():
		if out[k] is Dictionary:
			(out[k] as Dictionary).erase("_doc")
	return out


func _stage(bs: BuildingSystem, rec: Dictionary, action: String) -> Dictionary:
	for st: Dictionary in bs.stages(rec):
		if String(st.get("action", "")) == action:
			return st
	return {}
