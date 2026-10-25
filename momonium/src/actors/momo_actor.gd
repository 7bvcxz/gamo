class_name MomoActor
extends Node2D

## One Momo on the island: the rig standing at the agent's position, idling by
## day and asleep at night. What it does comes from the simulation (Steps
## 18-19 add walking and work); here it only chooses a pose.

var id := 0
var rig: MomoRig
var momos: MomoSystem
var cycle: DayCycle
var clock: SimClock
var _rng := RandomNumberGenerator.new()
var _sit_until := 0.0
var _next_sit := 0.0


func setup(p_id: int, sim: Simulation, lib: SpriteLibrary) -> void:
	id = p_id
	name = "Momo_%d" % id
	momos = sim.system(&"momo")
	cycle = DayCycle.new(sim.data)
	clock = sim.clock
	_rng.seed = id * 7919
	_next_sit = _rng.randf_range(8.0, 16.0)
	rig = MomoRig.new()
	rig.setup(lib, id)
	add_child(rig)


func _process(delta: float) -> void:
	var t := rig.time
	if cycle.is_night(clock):
		rig.set_state("sleep")
	elif t < _sit_until:
		rig.set_state("sit")
	else:
		rig.set_state("idle")
		if t >= _next_sit:
			_sit_until = t + _rng.randf_range(3.0, 6.0)
			_next_sit = _sit_until + _rng.randf_range(10.0, 20.0)
