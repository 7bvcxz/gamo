extends SceneTree
## Step 24: which stage limits sales, by sign tier, packing tier, kettle level and how often
## the hand pops (a gold-middle hold every `every` seconds when the kettle is free).
## godot --headless --path popcorn-glory --script res://tools/sim/bottleneck.gd -- [minutes]
const Factory := preload("res://variants/factory/factory_rules.gd")

func _run(sign: int, packer: int, level: int, every_ms: int, minutes: int, seed_value: int) -> Dictionary:
	var f: PopRules = Factory.new(null, seed_value)
	f.sign_tier = sign
	f.packer_tier = packer
	f.level = level
	var t := 0
	var next_pop := 0
	var shares := {"production": 0, "packaging": 0, "demand": 0, "": 0}
	var pops := 0
	while t < minutes * 60000:
		if t >= next_pop and f.glass.is_empty() and not bool(f.state()["heating"]) and int(f.state()["cooldown_left"]) <= 0:
			f.execute({"type": "press"})
			var hold: int = (int(f.window_start()) + int(f.window_end())) / 2
			f.advance(hold)
			t += hold
			f.execute({"type": "release"})
			pops += 1
			next_pop = t + every_ms
		f.advance(250)
		t += 250
		shares[String(f.bottleneck())] += 250
	var total := float(t)
	return {"sales_min": float(f.stats["sold"]) / minutes, "visitors_min": float(f.stats["visitors"]) / minutes,
		"packs_min": float(f.stats["packed"]) / minutes, "pops": pops, "money_min": float(f.stats["revenue"]) / minutes,
		"left": int(f.stats["abandoned"]) + int(f.stats["passed_by"]),
		"prod": shares["production"] / total, "pack": shares["packaging"] / total, "dem": shares["demand"] / total}

func _init() -> void:
	var minutes := 10
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		minutes = int(args[0])
	print("sign packer level every | visitors/min sales/min packs/min money/min left | production packaging demand (share of time)")
	# Pairs: each sign tier with the station below and at what it needs; a slow hand with kettle levels.
	for row in [[0, 0, 0, 2000], [3, 0, 0, 2000], [4, 0, 0, 2000], [4, 1, 0, 2000], [5, 1, 0, 2000], [5, 2, 0, 2000],
			[6, 2, 0, 2000], [6, 3, 0, 2000], [6, 3, 4, 2000], [6, 3, 8, 2000], [3, 0, 0, 20000], [3, 0, 4, 20000], [5, 2, 0, 8000], [5, 2, 6, 8000]]:
		var r := _run(row[0], row[1], row[2], row[3], minutes, 20261116)
		print("%d %d %2d %5d | %5.1f %5.1f %5.1f %6.1f %3d | %.2f %.2f %.2f" % [row[0], row[1], row[2], row[3], r["visitors_min"], r["sales_min"], r["packs_min"], r["money_min"], r["left"], r["prod"], r["pack"], r["dem"]])
	quit(0)
