class_name EventBus
extends RefCounted

## How the simulation tells the rest of the game what happened.
##
## One bus per Simulation instance, handed to whoever needs it -- not an
## autoload. Views, audio and analytics listen; the simulation never listens to
## them. Payloads are plain data (no nodes), so the same stream can be logged,
## counted or replayed.

signal emitted(type: StringName, payload: Dictionary)


func emit(type: StringName, payload: Dictionary = {}) -> void:
	emitted.emit(type, payload)
