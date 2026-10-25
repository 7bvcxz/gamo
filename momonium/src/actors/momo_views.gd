class_name MomoViews
extends Node

## Keeps one MomoActor per Momo in the entity layer, depth-sorted with the
## buildings, positioned from the simulation every frame (or from the finger
## while dragged), and answers "which Momo is under this point".

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
	sim.bus.emitted.connect(func(type: StringName, p: Dictionary) -> void:
		if type in [&"momo_added", &"momo_removed", &"game_loaded"]:
			sync()
		if type == &"momo_hired" and actors.has(int(p["id"])):
			(actors[int(p["id"])] as MomoActor).appear())
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
		a.setup(id, sim, lib, layer.projection)
		layer.add_entity(a, momos.position_of(id))
		actors[id] = a


func _process(_delta: float) -> void:
	for id: int in actors:
		var a: MomoActor = actors[id]
		if a.dragged:
			a.position = a.drag_world + Vector2(0, MomoActor.LIFT)
		else:
			layer.move_entity(a, momos.position_of(id))


## Front-most Momo whose body covers `world_pos`, or 0.
func hit(world_pos: Vector2) -> int:
	var best := 0
	var best_y := -INF
	for id: int in actors:
		var a: MomoActor = actors[id]
		if a.hit_rect().has_point(world_pos) and a.position.y > best_y:
			best = id
			best_y = a.position.y
	return best


func actor(id: int) -> MomoActor:
	return actors.get(id)
