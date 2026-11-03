class_name Telemetry
extends RefCounted

## Structured gameplay events: one dictionary per event, `{t, ev, ...}`, where
## `t` is the game clock in seconds (paused time does not count). The event
## names and their fields are listed in design/CORE_LOOP.md (계측).
##
## Kept in memory for the run and handed out as JSON lines (the browser bridge,
## the smoke run, the playtest evidence). Nothing is sent anywhere.

signal emitted(event: Dictionary)

## A 30-minute run at the input cap is ~11,000 wind events; past this the
## oldest are dropped and counted, so a forgotten tab cannot grow without end.
const LIMIT := 50000

var events: Array[Dictionary] = []
var dropped: int = 0
var _clock: GameClock
var _counts: Dictionary = {}


func _init(clock: GameClock) -> void:
	_clock = clock


func clear() -> void:
	events.clear()
	_counts.clear()
	dropped = 0


func emit(ev: String, fields: Dictionary = {}) -> Dictionary:
	var e := {"t": snappedf(_clock.time, 0.001), "ev": ev}
	e.merge(fields)
	events.append(e)
	_counts[ev] = int(_counts.get(ev, 0)) + 1
	if events.size() > LIMIT:
		events.pop_front()
		dropped += 1
	emitted.emit(e)
	return e


## How many events of this name were emitted this run (dropped ones included).
func count(ev: String) -> int:
	return int(_counts.get(ev, 0))


func first(ev: String) -> Dictionary:
	for e: Dictionary in events:
		if e["ev"] == ev:
			return e
	return {}


func to_jsonl() -> String:
	var lines := PackedStringArray()
	for e: Dictionary in events:
		lines.append(JSON.stringify(e))
	return "\n".join(lines)
