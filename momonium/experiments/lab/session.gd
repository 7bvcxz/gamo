class_name LabSession
extends RefCounted

## One run of one experiment, recorded locally and nowhere else: nothing here
## is sent anywhere or written to disk. The tester can download it as a small
## JSON or CSV (the frame's report, dev mode) or a test can read it.
##
## The clock is play time: it advances only while the page is visible and
## focused (the host stops it otherwise), so a hidden tab never adds time.
## Records every player action, each upgrade, milestones, the experiment's
## own numbers (`metric`), idle intervals (IDLE_MS or more between actions,
## including before the first one -- how long it took to start) and a copy
## of the summary taken when play time reaches three minutes -- and, for the
## C/E tracks' longer sessions (Step 94), at fifteen and thirty minutes too,
## with the frame rate at that moment. Step 99 added the start, seven and
## ten minutes (the 15-minute test's checkpoints), the experiment's own
## picture at each (`probe`) and the spacing of meaningful rewards -- breaks
## and upgrades in C, upgrades and eras in E.

const THREE_MINUTES_MS := 180000
const IDLE_MS := 5000
## The protocol's checkpoints (TRACKS.md): summary key -> play time.
const MARKS: Dictionary = {"at_0min": 0, "at_3min": 180000, "at_7min": 420000, "at_10min": 600000, "at_15min": 900000, "at_30min": 1800000}
## Milestones that are a reward in themselves (with every upgrade).
const REWARD_MILESTONES: Array[String] = ["break", "era"]

var experiment := ""
var version := ""
## The track's alternative (`?alt=`), "" for its default.
var variant := ""
## Which run of this experiment in the visit (Restart counts up from 1).
var run := 1
## Wall clock at the start (names the download; not part of any timing).
var started_unix := 0.0
var active_ms := 0.0
var events: Array[Dictionary] = []
var counts: Dictionary = {}
var upgrades: Array[Dictionary] = []
var milestones: Array[Dictionary] = []
var idle: Array = []
var metrics: Dictionary = {}
var at_three: Dictionary = {}
## Summaries frozen at each of MARKS (the three-minute one is `at_three`).
var at_marks: Dictionary = {}
## Actions in each minute of play: [minute 0, minute 1, ...].
var per_minute: Array[int] = []
## What the experiment looks like now, for the checkpoints (the host sets
## it to the experiment's `probe()`; empty without one).
var probe: Callable
var pauses := 0

var _last_action_ms := 0.0


func _init(p_experiment: String = "", p_version: String = "", p_unix: float = 0.0) -> void:
	experiment = p_experiment
	version = p_version
	started_unix = p_unix


func advance(dt_seconds: float) -> void:
	if dt_seconds <= 0.0:
		return
	active_ms += dt_seconds * 1000.0
	for key: String in MARKS:
		if not at_marks.has(key) and active_ms >= float(MARKS[key]):
			var snap := summary(false)
			snap["fps"] = Engine.get_frames_per_second()
			snap["probe"] = probe.call() if probe.is_valid() else {}
			at_marks[key] = snap
			if key == "at_3min":
				at_three = snap


## A player action: a tap, a button. `kind` names it; `detail` is kept as is.
func action(kind: String, detail: Dictionary = {}) -> void:
	_close_idle()
	counts[kind] = int(counts.get(kind, 0)) + 1
	var minute := int(active_ms / 60000.0)
	while per_minute.size() <= minute:
		per_minute.append(0)
	per_minute[minute] += 1
	_event(kind, detail)
	_last_action_ms = active_ms


## A successful upgrade (not counted again as an action: the press that
## bought it was).
func upgrade(level: int, cost: int, detail: Dictionary = {}) -> void:
	var u := {"t_ms": int(active_ms), "level": level, "cost": cost}
	u.merge(detail)
	upgrades.append(u)
	var d := {"level": level, "cost": cost}
	d.merge(detail)
	_event("upgrade", d)


func milestone(name: String, detail: Dictionary = {}) -> void:
	var m := {"t_ms": int(active_ms), "name": name}
	m.merge(detail)
	milestones.append(m)
	var d := {"name": name}
	d.merge(detail)
	_event("milestone", d)


## One of the experiment's own numbers, kept at its latest value.
func metric(key: String, value: Variant) -> void:
	metrics[key] = value


func paused(reason: String) -> void:
	pauses += 1
	_event("pause", {"reason": reason})


func resumed(reason: String) -> void:
	_event("resume", {"reason": reason})


func _event(kind: String, detail: Dictionary) -> void:
	var e := {"t_ms": int(active_ms), "kind": kind}
	e.merge(detail)
	events.append(e)


func _close_idle() -> void:
	if active_ms - _last_action_ms >= IDLE_MS:
		idle.append([int(_last_action_ms), int(active_ms)])


## Idle intervals so far, the one still open at the end included.
func idle_intervals() -> Array:
	var out := idle.duplicate()
	if active_ms - _last_action_ms >= IDLE_MS:
		out.append([int(_last_action_ms), int(active_ms)])
	return out


func action_count() -> int:
	var n := 0
	for k: String in counts:
		n += int(counts[k])
	return n


func summary(with_three: bool = true) -> Dictionary:
	var gaps := idle_intervals()
	var idle_ms := 0
	var longest := 0
	var intervals: Array = []
	for g: Array in gaps:
		var span := int(g[1]) - int(g[0])
		idle_ms += span
		longest = maxi(longest, span)
		intervals.append([_s(g[0]), _s(g[1])])
	var ups: Array = []
	var between: Array = []
	var prev := 0
	var longest_wait := 0
	for u: Dictionary in upgrades:
		var row := u.duplicate()
		row["t_s"] = _s(u["t_ms"])
		row.erase("t_ms")
		ups.append(row)
		between.append(_s(int(u["t_ms"]) - prev))
		longest_wait = maxi(longest_wait, int(u["t_ms"]) - prev)
		prev = int(u["t_ms"])
	# The wait still open counts too: a run whose next upgrade never comes
	# has its longest wait at the end.
	longest_wait = maxi(longest_wait, int(active_ms) - prev)
	var minutes: Array = []
	for n: int in per_minute:
		minutes.append(n)
	var played_minutes := int(ceil(active_ms / 60000.0))
	while minutes.size() < played_minutes:
		minutes.append(0)
	var ms: Array = []
	for m: Dictionary in milestones:
		var row := m.duplicate()
		row["t_s"] = _s(m["t_ms"])
		row.erase("t_ms")
		ms.append(row)
	var out := {
		"experiment": experiment,
		"variant": variant,
		"run": run,
		"version": version,
		"started": Time.get_datetime_string_from_unix_time(int(started_unix), true) if started_unix > 0.0 else "",
		"active_seconds": _s(active_ms),
		"idle_seconds": _s(idle_ms),
		"engaged_seconds": _s(active_ms - idle_ms),
		"actions": action_count(),
		"actions_by_kind": counts.duplicate(),
		"upgrades": ups,
		"first_upgrade_s": ups[0]["t_s"] if not ups.is_empty() else null,
		"seconds_between_upgrades": between,
		"longest_upgrade_wait_s": _s(longest_wait),
		"actions_per_minute": minutes,
		"milestones": ms,
		"idle_intervals": intervals,
		"longest_idle_s": _s(longest),
		"metrics": metrics.duplicate(true),
		"pauses": pauses,
		"rewards": rewards(),
		"visible_upgrades": upgrades.filter(func(u: Dictionary) -> bool: return String(u.get("show", "")) != "sparkle").size(),
	}
	if with_three:
		for key: String in MARKS:
			out[key] = (at_marks[key] as Dictionary).duplicate(true) if at_marks.has(key) else null
	return out


## Meaningful rewards so far (every upgrade, and breaks and eras): how many,
## and the spacing between them in seconds -- the median and the longest,
## the wait still open counting as the last.
func rewards() -> Dictionary:
	var times: Array[int] = []
	for u: Dictionary in upgrades:
		times.append(int(u["t_ms"]))
	for m: Dictionary in milestones:
		if String(m["name"]) in REWARD_MILESTONES:
			times.append(int(m["t_ms"]))
	times.sort()
	var gaps: Array[int] = []
	var prev := 0
	for t: int in times:
		gaps.append(t - prev)
		prev = t
	if int(active_ms) > prev:
		gaps.append(int(active_ms) - prev)
	var sorted := gaps.duplicate()
	sorted.sort()
	var median := 0.0
	if not sorted.is_empty():
		var n := sorted.size()
		median = float(sorted[n / 2]) if n % 2 == 1 else (float(sorted[n / 2 - 1]) + float(sorted[n / 2])) * 0.5
	return {"count": times.size(), "median_gap_s": _s(median), "longest_gap_s": _s(sorted.back() if not sorted.is_empty() else 0)}


func to_json() -> String:
	return JSON.stringify(summary(), "  ", false)


## Every event as a row (play time in seconds, kind, details), then the
## summary's headline numbers as `summary` rows.
func to_csv() -> String:
	var lines: Array[String] = ["t_seconds,kind,detail"]
	for e: Dictionary in events:
		var parts: Array[String] = []
		for k: String in e:
			if k != "t_ms" and k != "kind":
				parts.append("%s=%s" % [k, str(e[k])])
		lines.append("%s,%s,%s" % [str(_s(e["t_ms"])), String(e["kind"]), _csv("; ".join(parts))])
	var s := summary(false)
	for k: String in ["active_seconds", "idle_seconds", "engaged_seconds", "actions", "first_upgrade_s", "longest_idle_s", "pauses"]:
		lines.append("%s,summary,%s" % [str(s["active_seconds"]), _csv("%s=%s" % [k, str(s[k])])])
	for k: String in metrics:
		lines.append("%s,metric,%s" % [str(s["active_seconds"]), _csv("%s=%s" % [k, str(metrics[k])])])
	return "\n".join(lines) + "\n"


func file_stem() -> String:
	var when := Time.get_datetime_string_from_unix_time(int(started_unix)).replace(":", "").replace("T", "-") if started_unix > 0.0 else "run"
	return "funlab-%s-%s" % [experiment, when]


static func _s(ms: Variant) -> float:
	return snappedf(float(ms) / 1000.0, 0.1)


static func _csv(text: String) -> String:
	if text.contains(",") or text.contains("\"") or text.contains("\n"):
		return "\"%s\"" % text.replace("\"", "\"\"")
	return text
