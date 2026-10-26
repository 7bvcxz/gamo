class_name MomoViews
extends Node

## Keeps one MomoActor per Momo in the entity layer, depth-sorted with the
## buildings, positioned from the simulation every frame (or from the finger
## while dragged), and answers "which Momo is under this point".
##
## Step 55: a Momo sorts `art.momo_depth.bias_tiles` nearer than its feet --
## its node sits that much lower on screen and its drawing that much higher
## (MomoActor.depth_lift), so only the order changes: in front of a building
## it stands beside or in front of, still behind one it is clearly behind.

var sim: Simulation
var momos: MomoSystem
var layer: EntityLayer
var lib: SpriteLibrary
var actors: Dictionary = {}
## Set by the composition root: Momo out of sight stop animating (their place
## is still kept, for when the camera comes), and far out they move their
## limbs at half the rate.
var cameras: CameraController
const CULL_MARGIN := 160.0
## The depth bias in screen pixels (from the data, through the projection).
var depth_lift := 0.0


func setup(p_sim: Simulation, p_layer: EntityLayer, p_lib: SpriteLibrary) -> void:
	sim = p_sim
	momos = sim.system(&"momo")
	layer = p_layer
	lib = p_lib
	var bias := sim.data.get_float("art", "momo_depth.bias_tiles", 0.5)
	depth_lift = layer.projection.to_screen(Vector2(bias, bias) * 0.5).y - layer.projection.to_screen(Vector2.ZERO).y if layer.projection != null else 0.0
	sim.bus.emitted.connect(func(type: StringName, p: Dictionary) -> void:
		if type in [&"momo_added", &"momo_removed", &"game_loaded"]:
			sync()
		if type == &"momo_hired" and actors.has(int(p["id"])):
			(actors[int(p["id"])] as MomoActor).appear()
		# A Momo the manager sends elsewhere hops before it sets off.
		if type == &"manager_moved" and actors.has(int(p["momo"])):
			(actors[int(p["momo"])] as MomoActor).appear())
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
		a.depth_lift = depth_lift
		layer.add_entity(a, momos.position_of(id))
		a.position.y += depth_lift
		actors[id] = a


func _process(_delta: float) -> void:
	var culling := cameras != null and cameras.camera != null and cameras.camera.is_inside_tree()
	var sight := cameras.sight_rect(CULL_MARGIN) if culling else Rect2()
	var far := culling and cameras.far()
	for id: int in actors:
		var a: MomoActor = actors[id]
		if a.dragged:
			a.position = a.drag_world + Vector2(0, MomoActor.LIFT + depth_lift)
		else:
			layer.move_entity(a, momos.position_of(id))
			a.position.y += depth_lift
		if culling:
			a.set_awake(a.dragged or a.selected or sight.has_point(a.ground()))
			a.rig.lod_step = 2 if far else 1


## How many Momo are animating now (tests and the performance view).
func awake_count() -> int:
	var n := 0
	for a: MomoActor in actors.values():
		if a.is_processing():
			n += 1
	return n


## Front-most Momo whose body covers `world_pos`, or 0.
func hit(world_pos: Vector2, slack: float = 0.0) -> int:
	var best := 0
	var best_y := -INF
	for id: int in actors:
		var a: MomoActor = actors[id]
		if a.hit_rect().grow(slack).has_point(world_pos) and a.position.y > best_y:
			best = id
			best_y = a.position.y
	return best


func actor(id: int) -> MomoActor:
	return actors.get(id)
