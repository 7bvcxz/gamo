class_name MomoDrag
extends RefCounted

## Dragging a Momo (an InputRouter drag handler, so it wins over panning).
##
## Pick a Momo up, carry it: the building under the finger lights green if the
## Momo can work there, red if not. Drop on a building to assign it; drop on
## open land to put it down there (an assigned Momo dropped off its building
## is released); drop in the sea or on a full or job-less building and it
## shakes its head and goes back. A second finger cancels the carry.

var sim: Simulation
var momos: MomoSystem
var buildings: BuildingSystem
var projection: IsoProjection
var momo_views: MomoViews
var building_views: BuildingViews
var carrying := 0
var target := 0
var last_result: Dictionary = {}


func setup(p_sim: Simulation, p_projection: IsoProjection, p_momo_views: MomoViews, p_building_views: BuildingViews) -> void:
	sim = p_sim
	momos = sim.system(&"momo")
	buildings = sim.system(&"buildings")
	projection = p_projection
	momo_views = p_momo_views
	building_views = p_building_views


func try_begin_drag(_screen: Vector2, world: Vector2) -> bool:
	var id := momo_views.hit(world)
	if id == 0:
		return false
	carrying = id
	var a := momo_views.actor(id)
	a.dragged = true
	a.drag_world = world
	return true


func drag_to(_screen: Vector2, world: Vector2) -> void:
	if carrying == 0:
		return
	momo_views.actor(carrying).drag_world = world
	_mark(_building_under(world))


func end_drag(_screen: Vector2, world: Vector2) -> void:
	if carrying == 0:
		return
	var id := carrying
	var a := momo_views.actor(id)
	var b := _building_under(world)
	_mark(0)
	a.dragged = false
	carrying = 0
	if b != 0:
		last_result = sim.execute({"type": "momo.assign", "momo": id, "building": b})
	else:
		var ground := projection.to_logical(world)
		last_result = sim.execute({"type": "momo.move", "momo": id, "pos": [ground.x, ground.y]})
	if not last_result["ok"]:
		a.refuse()


func cancel_drag() -> void:
	if carrying == 0:
		return
	momo_views.actor(carrying).dragged = false
	_mark(0)
	carrying = 0


func _building_under(world: Vector2) -> int:
	var id := building_views.hit(world)
	return id if id != 0 else buildings.building_at(projection.cell_at(world))


func _mark(building: int) -> void:
	if target != 0 and building_views.view(target) != null:
		building_views.view(target).drop_hint = 0
	target = building
	if building != 0 and building_views.view(building) != null:
		var ok: bool = momos.can_assign(carrying, building)["ok"]
		building_views.view(building).drop_hint = 1 if ok else -1
