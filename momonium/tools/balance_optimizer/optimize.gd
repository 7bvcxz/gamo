extends SceneTree

## The pacing optimizer's simulator (Step 50): plays a fresh island with the
## play bot (tools/playtest/autoplayer.gd) as one of the player profiles in
## profiles.json, samples the economy at the checkpoints of the pacing
## targets (design/INCREMENTAL_PACING.md, targets.json), and scores the run
## against them -- the same definitions the blind playtests are scored by.
##
##   godot --headless --path momonium --script res://tools/balance_optimizer/optimize.gd -- \
##     --profile blind [--minutes 60] [--candidate tools/balance_optimizer/candidates/r1.json] \
##     [--set "buildings:types/farm/cost/money=12"] [--strategy no_land] [--json out.json] [--quiet]
##
## A candidate is a list of the same --set overrides with the reason for each,
## so a trial round is a file that can be read, rerun and compared. Without
## --minutes the profile's own length is played. --schedule 48h plays the
## two-day calendar of sessions and absences (as tools/playtest/run.gd).

const AutoPlayer := preload("res://tools/playtest/autoplayer.gd")
const Tune := preload("res://tools/playtest/tune.gd")
const DIR := "res://tools/balance_optimizer/"
## Seconds of play the series is read at (the pacing table's rows).
const CHECKPOINTS := [10, 30, 60, 120, 180, 240, 300, 360, 420, 480, 540, 600, 900, 1200, 1800, 3600]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var profile_name := "blind"
	var minutes := -1.0
	var json_out := ""
	var quiet := false
	var schedule := ""
	var sets: Array[String] = []
	var strategy := {}
	for i in args.size():
		match args[i]:
			"--profile": profile_name = args[i + 1]
			"--minutes": minutes = float(args[i + 1])
			"--json": json_out = args[i + 1]
			"--quiet": quiet = true
			"--schedule": schedule = args[i + 1]
			"--set": sets.append(args[i + 1])
			"--strategy":
				for s: String in args[i + 1].split(",", false):
					strategy[s] = true
			"--candidate":
				var cand: Variant = JSON.parse_string(FileAccess.get_file_as_string(_path(args[i + 1])))
				for e: Variant in (cand as Dictionary).get("sets", []):
					sets.append(String((e as Dictionary)["set"]))
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "profiles.json"))
	var profile: Dictionary = profiles["profiles"][profile_name]
	var data := GameData.load_default()
	for s: String in sets:
		var kv: PackedStringArray = s.split("=", true, 1)
		var where: PackedStringArray = kv[0].split(":", true, 1)
		Tune._put_in(data.tables[where[0]], where[1].split("/"), JSON.parse_string(kv[1]))
	var result := run(data, profile, strategy, minutes if minutes > 0.0 else float(profile.get("minutes", 10)), schedule)
	result["profile"] = profile_name
	result["sets"] = sets
	result["strategy"] = strategy.keys()
	var targets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "targets.json")) if FileAccess.file_exists(DIR + "targets.json") else {}
	if not targets.is_empty():
		result["score"] = score(result, targets, "sim")
	if not quiet:
		_print(result)
	if json_out != "":
		var f := FileAccess.open(_path(json_out), FileAccess.WRITE)
		if f == null:
			printerr("optimizer: cannot write %s" % _path(json_out))
			quit(1)
			return
		f.store_string(JSON.stringify(result, "  "))
		f.close()
	quit()


## A path given on the command line: res://, absolute, or relative to the
## repository root (where the commands are run from).
static func _path(p: String) -> String:
	if p.begins_with("res://") or p.begins_with("/"):
		return p
	return ProjectSettings.globalize_path("res://").path_join("..").path_join(p).simplify_path()


## The bot as `profile`, a new player's island, for `minutes` (or the 48-hour
## calendar). Returns {series: [checkpoint rows], milestones, quiet, ...}.
static func run(data: GameData, profile: Dictionary, strategy: Dictionary, minutes: float, schedule: String = "") -> Dictionary:
	var sim := Simulation.new_island(data)
	var bot := AutoPlayer.new(sim)
	bot.profile = String(profile.get("bot", "human"))
	bot.step_ms = int(profile.get("step_ms", 1000))
	bot.first_ms = int(profile.get("first_ms", 0))
	bot.explore_every = int(profile.get("explore_every", 0))
	bot.tutorial_taps = int(profile.get("tutorial_taps", 3))
	bot.sell_at_points = int(profile.get("sell_at_points", 2))
	bot.strategy = strategy
	var extra := {"prestige_ready_ms": -1, "first_income_ms": -1, "first_momo_income_ms": -1}
	bot.sim.bus.emitted.connect(_watcher(bot, extra))
	if schedule == "48h":
		for day in 2:
			for session: Array in [[30.0, 3.5], [15.0, 4.0], [40.0, 15.0]]:
				_play(bot, float(session[0]) * 60.0, extra)
				bot.away(float(session[1]) * 3600.0)
	else:
		_play(bot, minutes * 60.0, extra)
	var rows: Array = []
	for cp: int in CHECKPOINTS:
		if cp * 1000 > bot.active_ms:
			break
		rows.append(_at(bot.series, cp * 1000))
	var ms := {}
	for k: String in bot.milestones:
		ms[k] = int(bot.milestones[k]["active_ms"])
	var first_income := int(extra["first_income_ms"])
	return {"minutes": bot.active_ms / 60000.0, "series": rows, "milestones": ms,
		"first_income_ms": first_income, "first_momo_income_ms": int(extra["first_momo_income_ms"]),
		"prestige_ready_ms": int(extra["prestige_ready_ms"]),
		"income_gap_s": _income_gap(bot.events, maxi(int(extra["first_momo_income_ms"]), 0), mini(bot.active_ms, 600000)),
		"new_things_10min": bot.milestone_times(1).filter(func(t: int) -> bool: return t <= 600000).size(),
		"longest_between_new_s": int(bot.longest_between_milestones(0, mini(bot.active_ms, 600000), 1)["gap_ms"]) / 1000,
		"stuck_s": bot.stuck_seconds, "actions": bot.counts.duplicate(), "sales": bot.sales.duplicate(true),
		"wall_h": bot.wall_ms() / 3600000.0, "end": bot.series[-1] if not bot.series.is_empty() else {},
		"tier": (bot.sim.system(&"tiers") as TierSystem).tier_name(), "island": bot.island}


static func _play(bot: Object, seconds: float, extra: Dictionary) -> void:
	bot.play(seconds)
	# The bot looks at the sale on every decision and marks the first moment
	# the island could be sold for a point.
	if int(extra["prestige_ready_ms"]) < 0 and bot.milestones.has("prestige ready"):
		extra["prestige_ready_ms"] = int(bot.milestones["prestige ready"]["active_ms"])


static func _watcher(bot: Object, extra: Dictionary) -> Callable:
	return func(type: StringName, p: Dictionary) -> void:
		if type != &"money_changed" or int(p.get("delta", 0)) <= 0:
			return
		var cat := String(p.get("reason", "")).split(":")[0]
		if cat != "sale" and cat != "release":
			return
		var now: int = bot._now()
		if int(extra["first_income_ms"]) < 0:
			extra["first_income_ms"] = now
		if int(extra["first_momo_income_ms"]) < 0 and int(p.get("worker", 0)) > 0:
			extra["first_momo_income_ms"] = now
		bot.events.append({"active_ms": now, "island": bot.island, "kind": "income", "detail": "$%d" % int(p["delta"])})


## The sample at or just before `t_ms`.
static func _at(series: Array[Dictionary], t_ms: int) -> Dictionary:
	var best: Dictionary = {}
	for s: Dictionary in series:
		if int(s["t"]) <= t_ms:
			best = s
		else:
			break
	var out := best.duplicate(true)
	out["checkpoint_s"] = t_ms / 1000
	# Production money of the minute before (the income rate a player feels).
	var before: Dictionary = {}
	for s: Dictionary in series:
		if int(s["t"]) <= t_ms - 60000:
			before = s
		else:
			break
	out["rate_per_min"] = int(best.get("income_all", 0)) - int(before.get("income_all", 0))
	return out


## Longest stretch between two incomes after the first Momo income, up to
## `to_ms` (seconds).
static func _income_gap(events: Array[Dictionary], from_ms: int, to_ms: int) -> int:
	var last := -1
	var gap := 0
	for e: Dictionary in events:
		if String(e["kind"]) != "income" or int(e["active_ms"]) < from_ms or int(e["island"]) != 1:
			continue
		if int(e["active_ms"]) > to_ms:
			break
		if last >= 0:
			gap = maxi(gap, int(e["active_ms"]) - last)
		last = int(e["active_ms"])
	if last >= 0 and to_ms > last:
		gap = maxi(gap, to_ms - last)
	return gap / 1000


## Every target of `targets` that this kind of evidence ("sim" or "blind")
## measures, with the observed value, its relative error (or pass/fail) and
## the weighted aggregate of the exact targets.
static func score(result: Dictionary, targets: Dictionary, source: String) -> Dictionary:
	var rows: Array = []
	var wsum := 0.0
	var werr := 0.0
	var failed := 0
	for t: Dictionary in targets.get("targets", []):
		if not (t.get("sources", ["sim", "blind"]) as Array).has(source):
			continue
		var obs: Variant = observe(result, String(t["metric"]))
		var row := {"id": t["id"], "metric": t["metric"], "kind": t["kind"], "target": t.get("target", null), "observed": obs, "primary": t.get("primary", false)}
		match String(t["kind"]):
			"exact":
				if obs == null:
					row["error"] = null
					row["pass"] = false
				else:
					var err := absf(float(obs) - float(t["target"])) / float(t["target"])
					row["error"] = snappedf(err, 0.001)
					row["pass"] = err <= float(targets.get("tolerance", 0.1))
					if bool(t.get("primary", false)):
						wsum += float(t.get("weight", 1.0))
						werr += float(t.get("weight", 1.0)) * err
				if obs == null and bool(t.get("primary", false)):
					wsum += float(t.get("weight", 1.0))
					werr += float(t.get("weight", 1.0))
			"max":
				row["pass"] = obs != null and float(obs) <= float(t["target"])
			"min":
				row["pass"] = obs != null and float(obs) >= float(t["target"])
		if not bool(row["pass"]) and bool(t.get("primary", false)):
			failed += 1
		rows.append(row)
	var agg := werr / wsum if wsum > 0.0 else 0.0
	return {"rows": rows, "aggregate_error": snappedf(agg, 0.001), "primary_failed": failed,
		"pass": failed == 0 and agg <= float(targets.get("tolerance", 0.1))}


## A metric of the targets read from a run: "milestone:<key>" (seconds of
## play), "income_at:<s>" (production money by then), "level_at:<s>",
## "first_income", "first_momo_income", "prestige_ready", "income_gap",
## "new_things_10min", "longest_between_new".
static func observe(result: Dictionary, metric: String) -> Variant:
	var parts := metric.split(":", true, 1)
	match parts[0]:
		"milestone":
			var ms: Dictionary = result.get("milestones", {})
			return float(ms[parts[1]]) / 1000.0 if ms.has(parts[1]) else null
		"first_income":
			return float(result["first_income_ms"]) / 1000.0 if int(result.get("first_income_ms", -1)) >= 0 else null
		"first_momo_income":
			return float(result["first_momo_income_ms"]) / 1000.0 if int(result.get("first_momo_income_ms", -1)) >= 0 else null
		"prestige_ready":
			return float(result["prestige_ready_ms"]) / 1000.0 if int(result.get("prestige_ready_ms", -1)) >= 0 else null
		"income_at", "level_at", "momos_at", "land_at":
			var field := {"income_at": "income_all", "level_at": "level", "momos_at": "momos", "land_at": "land"}[parts[0]] as String
			for row: Dictionary in result.get("series", []):
				if int(row["checkpoint_s"]) == int(parts[1]):
					return row.get(field, null)
			return null
		"income_gap":
			return result.get("income_gap_s", null)
		"new_things_10min":
			return result.get("new_things_10min", null)
		"longest_between_new":
			return result.get("longest_between_new_s", null)
	return null


static func _t(s: float) -> String:
	if s < 0:
		return "-"
	return "%d:%02d" % [int(s) / 60, int(s) % 60]


static func _print(r: Dictionary) -> void:
	print("optimizer: profile %s, %.1f min, sets %d, strategy %s" % [r["profile"], r["minutes"], (r["sets"] as Array).size(), str(r["strategy"])])
	print("   time    money   income  $/min  Lv  land  bldg  momo  res  jobs(hand/momo/auto)")
	for row: Dictionary in r["series"]:
		var j: Dictionary = row.get("jobs", {})
		print("  %6s  %6d  %7d  %5d  %2d  %4d  %4d  %4d  %3d  %d/%d/%d" % [_t(float(row["checkpoint_s"])), int(row.get("money", 0)), int(row.get("income_all", 0)),
			int(row.get("rate_per_min", 0)), int(row.get("level", 0)), int(row.get("land", 0)), int(row.get("buildings", 0)), int(row.get("momos", 0)),
			int(row.get("research", 0)), int(j.get("hand", 0)), int(j.get("momo", 0)), int(j.get("auto", 0))])
	var keys: Array = (r["milestones"] as Dictionary).keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return int(r["milestones"][a]) < int(r["milestones"][b]))
	var line := ""
	for k: String in keys:
		if not k.contains("(island") and not k.begins_with("researched") and not k.contains("mastery"):
			line += "%s %s · " % [k, _t(float(r["milestones"][k]) / 1000.0)]
	print("  firsts: ", line)
	print("  first income %s, first Momo income %s, Prestige ready %s, income gap after automation %ds, new things in 10 min %d (longest wait %ds), stuck %ds" % [
		_t(float(r["first_income_ms"]) / 1000.0), _t(float(r["first_momo_income_ms"]) / 1000.0), _t(float(r["prestige_ready_ms"]) / 1000.0),
		int(r["income_gap_s"]), int(r["new_things_10min"]), int(r["longest_between_new_s"]), int(r["stuck_s"])])
	if r.has("score"):
		var sc: Dictionary = r["score"]
		for row: Dictionary in sc["rows"]:
			var obs: Variant = row["observed"]
			print("  %s %-6s %-26s target %-8s observed %-8s %s%s" % ["*" if row["primary"] else " ", row["id"], row["metric"], str(row["target"]),
				"-" if obs == null else str(snappedf(float(obs), 0.1)), ("err %4.1f%% " % (float(row["error"]) * 100.0)) if row.has("error") and row["error"] != null else "",
				"pass" if row["pass"] else "FAIL"])
		print("  aggregate error %.1f%%, primary failed %d -> %s" % [float(sc["aggregate_error"]) * 100.0, int(sc["primary_failed"]), "PASS" if sc["pass"] else "FAIL"])
