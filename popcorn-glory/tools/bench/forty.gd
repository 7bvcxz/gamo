extends SceneTree
## Step 33: what a flow step of the forty-machine factory costs, and where.
##   godot --headless --path popcorn-glory --script res://tools/bench/forty.gd
## Builds the unit test's 44-machine plan, warms up a minute, then times 60 model
## seconds of _flow_step and its parts (the machines, the lines, the rest).

const Factory := preload("res://variants/factory/factory_rules.gd")
const Tests := preload("res://tests/unit/test_factory_rules.gd")


func _init() -> void:
	var f: PopRules = Factory.new(null, 83)
	f.packer_tier = 3
	f.sign_tier = 6
	f.level = 6
	f.money = 1 << 30
	f.stats["packed"] = 1
	f.stats["sold"] = 1
	for row: Array in Tests.FORTY_PLAN:
		var floor := String(row[1])
		if f.floor_full(floor) and int(f.line_cost(floor)) >= 0:
			f.execute({"type": "buy_line", "floor": floor})
		f.execute({"type": "build", "machine": row[0], "floor": floor})
	f.money = 5000
	f.advance(60000)
	var parts := {"machines": 0, "lines": 0, "devices": 0, "on_hand": 0, "next_pack": 0}
	var t0 := Time.get_ticks_usec()
	f.advance(60000)
	var total := Time.get_ticks_usec() - t0
	# Parts, measured on their own (the same state, repeated).
	var n := 1200
	var a := Time.get_ticks_usec()
	for i in n:
		f._machines_step(0)
	parts["machines"] = Time.get_ticks_usec() - a
	a = Time.get_ticks_usec()
	for i in n:
		f._lines_step(0)
	parts["lines"] = Time.get_ticks_usec() - a
	a = Time.get_ticks_usec()
	for i in n:
		f._device_on("M14")
	parts["devices"] = Time.get_ticks_usec() - a
	a = Time.get_ticks_usec()
	for i in n:
		f.on_hand("plain", 2)
	parts["on_hand"] = Time.get_ticks_usec() - a
	a = Time.get_ticks_usec()
	for i in n:
		f._next_pack([2, 4], 1)
	parts["next_pack"] = Time.get_ticks_usec() - a
	# Per machine type: one machine-step call each (dt 0: the same questions, no time passes).
	var by_type := {}
	for m: Dictionary in f.machines:
		var b := Time.get_ticks_usec()
		for i in 200:
			var st := String(m["state"])
			f.machines = [m] if false else f.machines
			match String(m["type"]):
				"cooker", "M16": f._cooker_step(m, 0)
				"bagger", "P01": f._bagger_step(m, 0)
				"kiosk", "S05": f._kiosk_step(m, 0)
				"U08": f._balancer_step(m, 0)
				"M01": f._hopper_step(m, 0)
				_:
					if String(m["type"]).begins_with("P"):
						f._packing_device_step(m, 0)
					elif String(m["type"]).begins_with("S"):
						f._shop_device_step(m, 0)
					elif String(m["type"]).begins_with("U"):
						f._utility_step(m, 0)
					else:
						f._device_step(m, 0)
			m["state"] = st
		var t := String(m["type"])
		by_type[t] = float(by_type.get(t, 0.0)) + float(Time.get_ticks_usec() - b) / 200.0
	var rows: Array = by_type.keys()
	rows.sort_custom(func(a: String, b: String) -> bool: return float(by_type[a]) > float(by_type[b]))
	print("per type, all of its machines (us a step):")
	for t: String in rows.slice(0, 10):
		print("  %s %.1f" % [t, by_type[t]])
	print("machines %d, a model minute in %.1f ms (%.3f ms a 50 ms step)" % [f.machines.size(), total / 1000.0, total / 1000.0 / 1200.0])
	for k: String in parts:
		print("  %s: %.3f ms a call" % [k, float(parts[k]) / 1000.0 / n])
	quit(0)
