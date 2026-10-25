extends SceneTree

## The playtest report (headless):
##
##   godot --headless --path momonium --script res://tools/playtest/run.gd [-- --minutes 30 --schedule 48h]
##
## Plays a fresh island with tools/playtest/autoplayer.gd for --minutes of
## active play (default 30) and prints the milestones (active / wall /
## offline time), the longest quiet stretches, how the bot spent its actions,
## stuck time, and sales. --schedule 48h plays a two-day calendar of
## sessions and absences instead. --sell N: sell an island once it offers N
## legacy points (default 2). --set as in tune.gd.

const AutoPlayer := preload("res://tools/playtest/autoplayer.gd")
const Tune := preload("res://tools/playtest/tune.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var minutes := 30.0
	var schedule := ""
	var sell := 2
	var data := GameData.load_default()
	for i in args.size():
		match args[i]:
			"--minutes": minutes = float(args[i + 1])
			"--schedule": schedule = args[i + 1]
			"--sell": sell = int(args[i + 1])
			"--set":
				var kv: PackedStringArray = args[i + 1].split("=", true, 1)
				var where: PackedStringArray = kv[0].split(":", true, 1)
				Tune._put_in(data.tables[where[0]], where[1].split("/"), JSON.parse_string(kv[1]))
	var bot := AutoPlayer.new(Simulation.new_game(data))
	bot.sell_at_points = sell
	var t0 := Time.get_ticks_msec()
	if schedule == "48h":
		# Two days: sessions in the morning, at lunch, in the evening; nights away.
		for day in 2:
			for session: Array in [[30.0, 3.5], [15.0, 4.0], [40.0, 15.0]]:
				bot.play(float(session[0]) * 60.0)
				bot.away(float(session[1]) * 3600.0)
	else:
		bot.play(minutes * 60.0)
	print("playtest: %.1f min active, %.1f h wall, %.1f h offline counted, %d actions, %.1f s to run" % [
		bot.active_ms / 60000.0, bot.wall_ms() / 3600000.0, bot.offline_ms / 3600000.0, bot.actions, (Time.get_ticks_msec() - t0) / 1000.0])
	var keys: Array = bot.milestones.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return int(bot.milestones[a]["wall_ms"]) < int(bot.milestones[b]["wall_ms"]))
	for k: String in keys:
		var m: Dictionary = bot.milestones[k]
		print("  %-28s active %7s  wall %8s  offline %7s" % [k, _t(m["active_ms"]), _t(m["wall_ms"]), _t(m["offline_ms"])])
	for span: Array in [[0, 60], [60, 300], [300, 900], [900, 1800]]:
		var q: Dictionary = bot.longest_quiet(int(span[0]) * 1000, int(span[1]) * 1000)
		print("  quiet longest %4d-%4d s: %5.1f s (from %s)" % [span[0], span[1], q["gap_ms"] / 1000.0, _t(q["at_ms"])])
	for span: Array in [[0, 300], [300, 900], [900, 1800]]:
		var q: Dictionary = bot.longest_between_milestones(int(span[0]) * 1000, int(span[1]) * 1000)
		print("  new things %4d-%4d s: %d, longest wait %5.1f s (from %s)" % [span[0], span[1], q["count"], q["gap_ms"] / 1000.0, _t(q["at_ms"])])
	print("  stuck (nothing to do, nothing working): %d s, longest %d s" % [bot.stuck_seconds, bot.longest_stuck])
	var acts: Array = bot.counts.keys()
	acts.sort()
	for k: String in acts:
		print("  action %-40s %d" % [k, bot.counts[k]])
	for s: Dictionary in bot.sales:
		print("  sold island %d at %s active: Lv %d, %d points, %d RP" % [s["island"], _t(s["active_ms"]), s["level"], s["points"], s["rp"]])
	var prog: ProgressionSystem = bot.sim.system(&"progression")
	print("  now: island %d, Lv %d, $%d, %d buildings, %d Momo, tier %s" % [bot.island, prog.level, (bot.sim.system(&"economy") as EconomySystem).money,
		(bot.sim.system(&"buildings") as BuildingSystem).ids().size(), (bot.sim.system(&"momo") as MomoSystem).ids().size(), (bot.sim.system(&"tiers") as TierSystem).tier_name()])
	quit()


static func _t(ms: int) -> String:
	var s := int(ms / 1000)
	if s >= 3600:
		return "%dh%02dm" % [s / 3600, (s % 3600) / 60]
	return "%dm%02ds" % [s / 60, s % 60]
