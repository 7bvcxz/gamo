class_name MomoViews
extends Node

## Keeps one MomoActor per Momo in the entity layer, depth-sorted with the
## buildings, positioned from the simulation every frame.

var sim: Simulation
var momos: MomoSystem
var layer: EntityLayer
var lib: SpriteLibrary
var actors: Dictionary = {}


func setup(p_sim: Simulation, p_layer: EntityLayer, p_lib: SpriteLibrary) -> void:
	sim = p_sim
	momos = sim.system(&"momo")
	layer = p_layer
	lib = p_lib
	sim.bus.emitted.connect(func(type: StringName, _p: Dictionary) -> void:
		if type in [&"momo_added", &"momo_removed", &"game_loaded"]:
			sync())
	sync()


func sync() -> void:
	for id: int in actors.keys():
		if momos.get_momo(id).is_empty():
			(actors[id] as Node).queue_free()
			actors.erase(id)
	for id: int in momos.ids():
		if actors.has(id):
			continue
		var a := MomoActor.new()
		a.setup(id, sim, lib)
		layer.add_entity(a, momos.position_of(id))
		actors[id] = a


func _process(_delta: float) -> void:
	for id: int in actors:
		layer.move_entity(actors[id], momos.position_of(id))


func actor(id: int) -> MomoActor:
	return actors.get(id)
