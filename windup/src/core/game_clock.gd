class_name GameClock
extends RefCounted

## The one clock the game runs on, in seconds.
##
## It only moves through `advance`, so tests step it by hand and the game steps
## it from `_process`. While any pause reason is set it does not move at all:
## the atelier never progresses while the player is away (CORE_LOOP.md, 멈춤과
## 저장 -- no offline progress).

signal paused_changed(paused: bool, reason: String)

## One frame never counts for more than this: a browser that stops drawing a
## hidden tab hands the next frame the whole gap.
const MAX_STEP := 0.25

var time: float = 0.0
var _reasons: Dictionary = {}


var paused: bool:
	get:
		return not _reasons.is_empty()


func reset() -> void:
	time = 0.0
	_reasons.clear()


## Moves the clock and answers how much of `dt` actually passed (0 when paused).
func advance(dt: float) -> float:
	if paused or dt <= 0.0:
		return 0.0
	var used := minf(dt, MAX_STEP)
	time += used
	return used


## Sets or clears one pause reason ("focus", "hidden", "manual").
## Answers true when the clock went from running to paused or back.
func set_paused(reason: String, on: bool) -> bool:
	var was := paused
	if on:
		_reasons[reason] = true
	else:
		_reasons.erase(reason)
	if was != paused:
		paused_changed.emit(paused, reason)
		return true
	return false


func reasons() -> Array:
	return _reasons.keys()
