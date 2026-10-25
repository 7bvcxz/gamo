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
