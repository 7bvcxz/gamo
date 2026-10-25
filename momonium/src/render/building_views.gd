class_name BuildingViews
extends Node

## Keeps one BuildingView per building in the entity layer, in step with the
## simulation's building_added / removed events, and answers "which building
## is under this point" for taps (front-most first).

var sim: Simulation
var buildings: BuildingSystem
var layer: EntityLayer
var lib: SpriteLibrary
var views: Dictionary = {}
## Set by the composition root: views outside the camera's sight (with a
## margin for tall sprites) stop their per-frame work -- rings, smoke, lights
## -- until seen; zoomed far out, the rest draw their motions less often.
var cameras: CameraController
const CULL_MARGIN := 220.0


func setup(p_sim: Simulation, p_layer: EntityLayer, p_lib: SpriteLibrary) -> void:
	sim = p_sim
	buildings = sim.system(&"buildings")
	layer = p_layer
	lib = p_lib
	sim.bus.emitted.connect(_on_event)
	sync()


func _on_event(type: StringName, payload: Dictionary) -> void:
	match type:
		&"building_added", &"building_removed", &"game_loaded":
			sync()
		&"building_refit":
			# Same building, another facility: drawn afresh as what it is now.
			var old: BuildingView = views.get(int(payload["id"]))
			if old:
				old.queue_free()
				views.erase(int(payload["id"]))
			sync()
		&"task_started":
			var v: BuildingView = views.get(int(payload["id"]))
			if v:
				v.pulse()
		&"building_built":
			var v: BuildingView = views.get(int(payload["id"]))
			if v:
				v.celebrate()
		&"task_completed":
			# A Momo finished a job: a few stars.
			if int(payload.get("worker", 0)) > 0:
				var v: BuildingView = views.get(int(payload["id"]))
				if v:
					v.sparkle()
		&"mastery_up", &"game_loaded":
			for v: BuildingView in views.values():
				v.refresh_pennant()
		&"momo_skilled":
			# A Momo learned something: the School twinkles if there is one.
			var school := buildings.special_built("school")
			if school != 0 and views.has(school):
				(views[school] as BuildingView).sparkle()


func sync() -> void:
	for id: int in views.keys():
		if buildings.get_building(id).is_empty():
			(views[id] as Node).queue_free()
			views.erase(id)
	for id: int in buildings.ids():
		if views.has(id):
			continue
		var v := BuildingView.new()
		v.setup(id, buildings, layer.projection, lib)
		var cells := buildings.cells_of(buildings.get_building(id))
		var centre := Vector2.ZERO
		for c: Vector2i in cells:
			centre += Vector2(c) + Vector2(0.5, 0.5)
		layer.add_entity(v, centre / cells.size())
		views[id] = v


func _process(_delta: float) -> void:
	if cameras == null or cameras.camera == null or not cameras.camera.is_inside_tree():
		return
	var sight := cameras.sight_rect(CULL_MARGIN)
	var far := cameras.far()
	for id: int in views:
		var v: BuildingView = views[id]
		var on := sight.has_point(v.position)
		if v.is_processing() != on:
			v.set_process(on)
			v.ring.visible = on
		v.far = far


## How many views are doing their per-frame work (tests, benchmarks).
func active_count() -> int:
	var n := 0
	for v: BuildingView in views.values():
		if v.is_processing():
			n += 1
	return n


## The front-most building whose sprite covers `world_pos`, or 0.
func hit(world_pos: Vector2) -> int:
	var best := 0
	var best_y := -INF
	for id: int in views:
		var v: BuildingView = views[id]
		if v.hit_rect().has_point(world_pos) and v.position.y > best_y:
			best = id
			best_y = v.position.y
	return best


func view(id: int) -> BuildingView:
	return views.get(id)
