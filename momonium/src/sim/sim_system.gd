class_name SimSystem
extends RefCounted

## Base for one gameplay system (land, buildings, farming, economy, ...).
##
## A system owns its slice of the game state and is plain data plus rules: no
## nodes, no drawing, no input. It is told about time through scheduled events
## and day boundaries, changed through commands, and reports through the bus.
## Systems may call each other through `sim` (e.g. economy.spend) -- in-sim
## calls are direct so their order is fixed; signals are for the outside.

## The owning simulation. Held weakly: the simulation owns its systems, and a
## strong reference back would make a cycle that RefCounted never frees.
var sim: Simulation:
	get:
		return _sim_ref.get_ref() if _sim_ref != null else null
## Stable key used in saves and for lookups: sim.system("economy").
var key: StringName = &""

var _sim_ref: WeakRef


func setup(p_sim: Simulation) -> void:
	_sim_ref = weakref(p_sim)


## Event types this system handles when the scheduler reaches them.
func handled_events() -> PackedStringArray:
	return PackedStringArray()


func handle_event(_type: String, _data: Dictionary) -> void:
	pass


## Command types this system answers.
func handled_commands() -> PackedStringArray:
	return PackedStringArray()


func execute(_command: Dictionary) -> Dictionary:
	return SimResult.fail("err.unknown_command")


## Called in system order when a new day begins (Day N, 1-based).
func on_day_started(_day: int) -> void:
	pass


## Called once after a new game is created (not after a load).
func on_new_game() -> void:
	pass


func save_state() -> Dictionary:
	return {}


func load_state(_state: Dictionary) -> void:
	pass
