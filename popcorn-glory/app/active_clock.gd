class_name PopClock
extends RefCounted

## Active play time: it moves only while the game is visible and running.
##
## A frame never counts for more than MAX_STEP seconds, so the first frame
## after a hidden tab (the browser stops drawing it) or a stall does not pour
## minutes into the run at once. Pauses have reasons ("hidden", "dev") so one
## cause ending does not unpause another.

const MAX_STEP := 0.25

var now_ms: int = 0
var _ms_f: float = 0.0
var _pauses: Dictionary = {}


## Returns how many whole milliseconds this frame added.
func step(delta: float) -> int:
	if paused():
		return 0
	_ms_f += clampf(delta, 0.0, MAX_STEP) * 1000.0
	var whole := int(_ms_f)
	var added := whole - now_ms
	now_ms = whole
	return added


## For tests and the dev hook: exact milliseconds, no clamp.
func add_ms(ms: int) -> int:
	if ms <= 0:
		return 0
	now_ms += ms
	_ms_f = float(now_ms) + fmod(_ms_f, 1.0)
	return ms


func set_pause(reason: String, on: bool) -> void:
	if on:
		_pauses[reason] = true
	else:
		_pauses.erase(reason)


func paused() -> bool:
	return not _pauses.is_empty()


func pause_reasons() -> Array:
	return _pauses.keys()
