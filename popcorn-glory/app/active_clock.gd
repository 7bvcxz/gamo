class_name PopClock
extends RefCounted

## Active play time: it moves only while the game is visible and running.
##
## A frame never counts for more than MAX_STEP seconds, so the first frame
## after a hidden tab (the browser stops drawing it) does not pour minutes into
## the run at once. Pauses have reasons ("hidden", "dev") so one cause ending
## does not unpause another.
##
## 1 s, not 0.25 s (Step 09): a hidden tab is already paused by "hidden", so the
## cap mostly met hitches -- and a hitch while B's finger was down vanished from
## the heat. A blind player held 1.98 s and was judged 1.16 s ("early"), right
## after an upgrade: "it felt like being punished for upgrading".
## tests/e2e/specs/stall09.spec.mjs blocks the page for 0.8 s during a hold.
## (Godot's own _process delta is capped near 0.133 s; PopApp measures the
## frame with the wall clock -- app/main.gd _process.)

const MAX_STEP := 1.0

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
