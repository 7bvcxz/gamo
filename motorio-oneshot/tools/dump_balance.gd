extends SceneTree

## Writes every balance number the documentation quotes into a JSON file, read
## straight out of Defs.
##
## The reason this exists: the design pages used to restate the numbers by hand,
## and hand-copied numbers rot. Belt speed changed by a factor of ten and the
## level-design page went on claiming the old figure, which makes the document
## actively worse than no document -- you cannot design against it if you cannot
## trust it.
##
##   godot --headless --path motorio-oneshot --script res://tools/dump_balance.gd
##
## Output: web/src/generated/balance.json, committed alongside the change that
## moved the number.

const OUT := "res://../web/src/generated/balance.json"

func _initialize() -> void:
	var machines: Array = []
	for type: int in Defs.BUILDABLE:
		var cost: Array = []
		for item_type: int in Defs.MACHINE_COSTS[type]:
			cost.append({
				"item": Defs.ITEM_NAMES[item_type],
				"count": int(Defs.MACHINE_COSTS[type][item_type]),
			})
		machines.append({
			"name": Defs.MACHINE_NAMES[type],
			"short": Defs.MACHINE_SHORT[type],
			"cost": cost,
			"throughput": Defs.throughput_line(type),
			"hint": Defs.MACHINE_HINTS[type],
			"unlock": Defs.ITEM_NAMES[Defs.MACHINE_UNLOCK_ITEM[type]] if Defs.MACHINE_UNLOCK_ITEM[type] >= 0 else "",
		})

	var recipes: Array = []
	for index in Defs.RECIPES.size():
		recipes.append({
			"name": String(Defs.RECIPES[index]["name"]),
			"line": Defs.recipe_line(index),
			"energy_per_minute": Defs.recipe_rate(index),
			"crystal_per_energy": Defs.recipe_crystal_cost(index),
		})

	var belts: Array = []
	for index in Defs.BELT_TIERS.size():
		var speed: float = Defs.belt_speed(index)
		belts.append({
			"name": String(Defs.BELT_TIERS[index]["name"]),
			"multiplier": float(Defs.BELT_TIERS[index]["speed"]),
			"tiles_per_second": speed,
			"seconds_per_tile": 1.0 / speed,
			"ten_tile_seconds": 10.0 / speed,
			"items_per_minute": speed / 0.34 * 60.0,
			"copper": int(Defs.BELT_TIERS[index]["cost"]),
		})

	var purity: Array = []
	for grade in Defs.PURITY_NAMES.size():
		purity.append({
			"name": String(Defs.PURITY_NAMES[grade]),
			"multiplier": Defs.PURITY_RATE[grade],
			"crystal_per_minute": Defs.per_minute(Defs.MINER_PERIOD / Defs.PURITY_RATE[grade]),
		})

	# The gate the whole progression hangs on, computed the same way the test does.
	var heat_to_copper: float = (Defs.COPPER_RING.x - Defs.WARM_BASE) / Defs.WARM_PER_HEAT
	var energy_to_copper: float = heat_to_copper / float(Defs.ITEM_VALUES[Defs.ITEM_ENERGY])
	var crystal_to_copper: float = energy_to_copper * float(Defs.CRYSTAL_COST_ENERGY)

	var data := {
		"generated_by": "motorio-oneshot/tools/dump_balance.gd",
		"version": String(ProjectSettings.get_setting("application/config/version", "")),
		"day": {
			"seconds": Defs.DAY_SECONDS,
			"dusk_seconds": Defs.DUSK_SECONDS,
			"night_seconds": Defs.NIGHT_SECONDS,
		},
		"warmth": {
			"base_radius": Defs.WARM_BASE,
			"per_heat": Defs.WARM_PER_HEAT,
			"max_radius": Defs.WARM_MAX,
			"outside_speed": 0.45,
			"cold_drain": Defs.COLD_DRAIN,
			"night_drain": Defs.NIGHT_DRAIN,
			"collapse_grace": Defs.COLLAPSE_GRACE,
		},
		"items": {
			"names": Defs.ITEM_NAMES,
			"heat_value": Defs.ITEM_VALUES,
		},
		"rates": {
			"hand_mine_seconds": Defs.HAND_MINE_PERIOD,
			"miner_seconds": Defs.MINER_PERIOD,
			"copper_seconds": Defs.COPPER_PERIOD,
			"exchanger_seconds": Defs.EXCHANGER_PERIOD,
			"generator_seconds": Defs.GENERATOR_PERIOD,
			"crystal_per_energy": Defs.CRYSTAL_COST_ENERGY,
			"ratio_hint": Defs.ratio_hint(),
		},
		"power": {
			"generator_output": Defs.GENERATOR_OUTPUT,
			"belt_draw": Defs.BELT_POWER_DRAW,
			"miner_draw": Defs.MINER_POWER_DRAW,
			"miners_per_generator": Defs.GENERATOR_OUTPUT / Defs.MINER_POWER_DRAW,
		},
		"cats": {
			"boxes_per_cat": Defs.BOXES_PER_CAT,
			"tiles_per_box": Defs.CAT_BOX_PER_TILES,
			"speed": Defs.CAT_SPEED,
			"food_start": Defs.FOOD_START,
		},
		"rings": {
			"crystal": [Defs.FROST_RING.x, Defs.FROST_RING.y],
			"copper": [Defs.COPPER_RING.x, Defs.COPPER_RING.y],
			"purity_rich": Defs.PURITY_RICH_RING,
			"purity_pure": Defs.PURITY_PURE_RING,
		},
		"gate_to_copper": {
			"heat": heat_to_copper,
			"energy": energy_to_copper,
			"crystal": crystal_to_copper,
			"days_two_miners": crystal_to_copper / (2.0 / Defs.MINER_PERIOD) / 120.0,
		},
		"machines": machines,
		"recipes": recipes,
		"belts": belts,
		"purity": purity,
	}

	var file := FileAccess.open(OUT, FileAccess.WRITE)
	if file == null:
		push_error("BALANCE_DUMP: cannot write %s" % OUT)
		quit(1)
		return
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	print("BALANCE_DUMP: wrote %s" % OUT)
	quit(0)
