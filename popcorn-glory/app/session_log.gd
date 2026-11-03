class_name PopSession
extends RefCounted

## The run's local record (FUN_FIRST.md): one line per thing that happened,
## stamped with active play time. Nothing leaves the page and nothing is
## stored -- `?dev=1` offers it as a download, the tests read it.
##
##   input      a press of the main action (data.kind: press|release|key)
##   pop, earn  from the rules
##   upgrade    from the rules
##   milestone  first_input, first_earn, first_affordable, first_upgrade, three_minutes
##   idle       a gap of IDLE_MS or more between inputs (data.start, data.ms)
##   reset      the run was restarted (the last line of a log)

const IDLE_MS := 5000
const THREE_MINUTES_MS := 180000

var variant := ""
var lines: Array[Dictionary] = []
var milestones: Dictionary = {}
var inputs: int = 0
var upgrades: Array[int] = []
var idle_total_ms: int = 0
var idle_longest_ms: int = 0
var last_input_ms: int = -1


func _init(p_variant: String = "") -> void:
	variant = p_variant


func record(t: int, type: String, data: Dictionary = {}) -> void:
	lines.append({"t": t, "type": type, "data": data})


func record_input(t: int, kind: String) -> void:
	if last_input_ms >= 0 and t - last_input_ms >= IDLE_MS:
		_idle(last_input_ms, t - last_input_ms)
	inputs += 1
	last_input_ms = t
	record(t, "input", {"kind": kind})
	_milestone("first_input", t)


## The rules' events, in order.
func record_events(events: Array[Dictionary]) -> void:
	for e: Dictionary in events:
		var t := int(e["t"])
		record(t, String(e["type"]), e["data"])
		match String(e["type"]):
			"earn":
				_milestone("first_earn", t)
			"upgrade":
				upgrades.append(t)
				_milestone("first_upgrade", t)


## Once a frame: what is true by now rather than what happened.
func observe(t: int, rules: PopRules) -> void:
	if rules.can_buy():
		_milestone("first_affordable", t)
	if t >= THREE_MINUTES_MS and not milestones.has("three_minutes"):
		_milestone("three_minutes", t, {"level": rules.level, "money": rules.money, "earned": rules.earned})


func reset(t: int) -> void:
	record(t, "reset", {})


func summary(t: int, rules: PopRules) -> Dictionary:
	var open_idle := t - last_input_ms if last_input_ms >= 0 else t
	return {
		"variant": variant, "t_ms": t, "inputs": inputs,
		"money": rules.money if rules else 0, "level": rules.level if rules else 0,
		"earned": rules.earned if rules else 0, "milestones": milestones.duplicate(),
		"upgrades": upgrades.duplicate(), "idle_total_ms": idle_total_ms + (open_idle if open_idle >= IDLE_MS else 0),
		"idle_longest_ms": maxi(idle_longest_ms, open_idle if open_idle >= IDLE_MS else 0),
	}


func to_json() -> String:
	return JSON.stringify({"variant": variant, "lines": lines})


func to_csv() -> String:
	var out := PackedStringArray(["t_ms,type,data"])
	for l: Dictionary in lines:
		out.append("%d,%s,\"%s\"" % [int(l["t"]), String(l["type"]), JSON.stringify(l["data"]).replace("\"", "\"\"")])
	return "\n".join(out) + "\n"


func _idle(start: int, ms: int) -> void:
	idle_total_ms += ms
	idle_longest_ms = maxi(idle_longest_ms, ms)
	record(start + ms, "idle", {"start": start, "ms": ms})


func _milestone(name: String, t: int, data: Dictionary = {}) -> void:
	if milestones.has(name):
		return
	milestones[name] = t
	var d := data.duplicate()
	d["name"] = name
	record(t, "milestone", d)
