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
##   godot --headless --path motorio --script res://tools/dump_balance.gd
##
## Output: web/lib/generated/balance.json, committed alongside the change that
## moved the number.

const OUT := "res://../web/lib/generated/balance.json"

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

	# The gate the whole progression hangs on. The circle goes up in steps now, so
	# this is the step that first reaches copper rather than an arithmetic.
	var stones_to_copper: float = 0.0
	for level: Dictionary in Defs.BASE_LEVELS:
		if float(level["radius"]) >= Defs.COPPER_RING.x:
			stones_to_copper = float(level["stones"])
			break

	# One row per base step, so the doc can say what each upgrade reaches without
	# anyone typing a radius twice.
	var heatstone_bands: Array = []
	for index in Defs.HEATSTONE_BANDS.size():
		var band: Dictionary = Defs.HEATSTONE_BANDS[index]
		var ring: Vector2 = band["ring"]
		heatstone_bands.append({
			"from": snappedf(ring.x, 0.1), "to": snappedf(ring.y, 0.1),
			"seams": int(band["patches"]) * int(band["size"]),
			"radius": float(Defs.BASE_LEVELS[index]["radius"]) if index < Defs.BASE_LEVELS.size() else 0.0,
			"stones": int(Defs.BASE_LEVELS[index]["stones"]) if index < Defs.BASE_LEVELS.size() else 0,
		})

	var data := {
		"generated_by": "motorio/tools/dump_balance.gd",
		"version": String(ProjectSettings.get_setting("application/config/version", "")),
		"day": {
			"seconds": Defs.DAY_SECONDS,
			"dusk_seconds": Defs.DUSK_SECONDS,
			"night_seconds": Defs.NIGHT_SECONDS,
		},
		# Carrying heat out past the fire. The burn is the range and the melt is
		# the toll: how many liftable things one torch can free is the ratio of
		# these two, and that ratio is the whole shape of an expedition.
		# Wreckage. The distances are a design promise -- nothing inside eleven,
		# exactly one on the eleventh ring -- so they belong where the
		# documentation can quote them instead of restating them by hand.
		"debris": {
			"first_ring": Defs.DEBRIS_FIRST_RING,
			"start_ring": Defs.DEBRIS_START_RING,
			"per_tiles": Defs.DEBRIS_PER_TILES,
			"shapes": Defs.DEBRIS_SHAPES,
			"search_seconds": Defs.DEBRIS_SEARCH_SECONDS,
			"high": [Defs.DEBRIS_HIGH.x, Defs.DEBRIS_HIGH.y],
			"low": [Defs.DEBRIS_LOW.x, Defs.DEBRIS_LOW.y],
			"high_item": Defs.ITEM_NAMES[Defs.ORE_TIERS[Defs.ORE_TIERS.size() - 1]],
			"low_item": Defs.ITEM_NAMES[Defs.ORE_TIERS[maxi(Defs.ORE_TIERS.size() - 2, 0)]],
			"core_one": Defs.DEBRIS_CORE_ONE,
			"core_two": Defs.DEBRIS_CORE_TWO,
		},
		"torch": {
			"seconds": Defs.TORCH_SECONDS,
			"sight": Defs.TORCH_SIGHT,
			"thaw_seconds": Defs.THAW_GROUND_SECONDS,
		},
		# The objective card, id by id, with the reason each line is the way it
		# is. Exported rather than written into the documentation page by hand:
		# a line rewritten in the game and not on the page is a page that lies,
		# and this repository has watched that happen to balance numbers.
		"missions": Defs.MISSION_LINES,
		# And the keys, which are the other half of the same job: the card says
		# the situation and never a key, this says the key and never why.
		"prompts": Defs.KEY_PROMPTS,
		"warmth": {
			"base_radius": Defs.WARM_BASE,
			"levels": Defs.BASE_LEVELS,
			"max_radius": Defs.WARM_MAX,
			"outside_speed": 0.45,
			"cold_drain": Defs.COLD_DRAIN,
			"night_drain": Defs.NIGHT_DRAIN,
			"collapse_grace": Defs.COLLAPSE_GRACE,
		},
		"items": {
			"names": Defs.ITEM_NAMES,
			# Heat is gone as of 1.0.5. There is no per-item heat value because
			# there is no heat: the fire counts stones.
			"fuel": Defs.ITEM_NAMES[Defs.ITEM_HEATSTONE],
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
			"miner_draw": Defs.MINER_POWER_DRAW,
			"miners_per_generator": Defs.GENERATOR_OUTPUT / Defs.MINER_POWER_DRAW,
		},
		"cats": {
			"tiles_per_frozen": Defs.FROZEN_PER_TILES,
			"starter_frozen": Defs.STARTER_FROZEN,
			"carry_speed": Defs.FROZEN_CARRY_SPEED,
			"thaw_radius": Defs.THAW_RADIUS,
			"thaw_seconds": Defs.THAW_SECONDS,
			"speed": Defs.CAT_SPEED,
			"food_start": Defs.FOOD_START,
		},
		"rings": {
			"heatstone": [float(Defs.HEATSTONE_BANDS[0]["ring"].x),
				float(Defs.HEATSTONE_BANDS[-1]["ring"].y)],
			"heatstone_bands": heatstone_bands,
			"crystal_shards": [Defs.CRYSTAL_RING.x, Defs.CRYSTAL_RING.y],
			"crystal_shard_count": Defs.CRYSTAL_SHARDS,
			"copper": [Defs.COPPER_RING.x, Defs.COPPER_RING.y],
			"purity_rich": Defs.PURITY_RICH_RING,
			"purity_pure": Defs.PURITY_PURE_RING,
		},
		"gate_to_copper": {
			"stones": stones_to_copper,
			"days_two_miners": stones_to_copper / (2.0 / Defs.MINER_PERIOD) / 120.0,
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
