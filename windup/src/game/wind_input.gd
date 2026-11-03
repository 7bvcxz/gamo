class_name WindInput
extends RefCounted

## How presses become turns of the key, apart from the rules and the screen:
## a press is one turn now; holding (any source: mouse, touch, Space) keeps
## turning at `hold_turns_per_second` after `hold_delay`; letting go of the
## last held source is "release" (variant A's spring lets go then). The cap on
## how fast turns count is the rules' (Atelier.can_turn), not this class's.

var hold_rate: float = 5.0
var hold_delay: float = 0.25
var _held: Dictionary = {}
var _t: float = 0.0


func _init(balance: Balance) -> void:
	hold_rate = balance.hold_turns_per_second
	hold_delay = balance.hold_delay


func reset() -> void:
	_held.clear()
	_t = 0.0


func holding() -> bool:
	return not _held.is_empty()


## A press from `source`. "dev" presses are taps (never held).
func press(source: String) -> void:
	if source != "dev":
		_held[source] = true
		_t = -hold_delay


## Answers true when this was the last held source (the key is let go).
func release(source: String) -> bool:
	var had := _held.has(source)
	_held.erase(source)
	return had and _held.is_empty()


## Advances game time; answers how many held turns are due now.
func advance(dt: float) -> int:
	if _held.is_empty():
		return 0
	_t += dt
	var every := 1.0 / hold_rate
	var n := 0
	while _t >= every:
		_t -= every
		n += 1
	return n


## Releases everything at once (focus lost, pause); answers whether anything was held.
func release_all() -> bool:
	var had := not _held.is_empty()
	_held.clear()
	return had
