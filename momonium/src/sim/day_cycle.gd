class_name DayCycle
extends RefCounted

## Which part of the day it is, from the one clock.
##
## Phases are fractions of the day in data (balance.clock.phases). Anything
## that behaves differently at night -- the sky, the light, later Momo going
## to sleep -- asks this, never its own timer, so they always agree.

var _bounds: Array[float] = []
var _names: Array[StringName] = []


func _init(data: GameData) -> void:
	var phases: Variant = data.get_value("balance", "clock.phases", [])
	if typeof(phases) != TYPE_ARRAY or (phases as Array).is_empty():
		_bounds = [0.0]
		_names = [&"day"]
		return
	for p: Dictionary in phases:
		_bounds.append(float(p["from"]))
		_names.append(StringName(p["name"]))


## Phase name at a point of the day (0 <= progress < 1).
func phase_at(progress: float) -> StringName:
	var p := fposmod(progress, 1.0)
	var name := _names[0]
	for i in _bounds.size():
		if p >= _bounds[i]:
			name = _names[i]
	return name


func phase(clock: SimClock) -> StringName:
	return phase_at(clock.day_progress())


func is_night(clock: SimClock) -> bool:
	return phase(clock) == &"night"
