class_name SimClock
extends RefCounted

## The world's one time source.
##
## Time is an integer count of simulated milliseconds since the save began. It
## only moves when the simulation is advanced, never by reading a frame counter
## or the wall clock, so the same commands at the same times always produce the
## same world -- offline catch-up and tests rely on that.

var now_ms: int = 0
var day_ms: int = 30000


func _init(p_day_ms: int = 30000) -> void:
	assert(p_day_ms > 0)
	day_ms = p_day_ms


## Zero-based index of the current day (Day 1 is index 0).
func day_index() -> int:
	return now_ms / day_ms


## The number the player sees: Day 1, Day 2, ...
func day_number() -> int:
	return day_index() + 1


func time_in_day_ms() -> int:
	return now_ms - day_index() * day_ms


## 0.0 at the start of a day, approaching 1.0 at its end.
func day_progress() -> float:
	return float(time_in_day_ms()) / float(day_ms)


func next_day_start_ms() -> int:
	return (day_index() + 1) * day_ms


func save_state() -> Dictionary:
	return {"now_ms": now_ms}


func load_state(state: Dictionary) -> void:
	now_ms = int(state.get("now_ms", 0))
