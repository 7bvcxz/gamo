class_name SelectionController
extends Node

## What a tap on the world means, and what is selected.
##
## Receives taps from the InputRouter (which has already given the UI and any
## drag the first say). Front-most building sprite under the finger wins, then
## the building on the tapped cell, then the cell itself; open sea deselects.
## Tapping a ready building starts its work at once -- the tap is the action,
## not a request to open a menu -- and selects it so its cards show progress.
## Selection is presentation state: it is not saved and the simulation never
## sees it. A building keeps working when something else is selected.

signal selection_changed(kind: String)

var sim: Simulation
var world: WorldSystem
var buildings: BuildingSystem
var projection: IsoProjection
var views: BuildingViews
var marker: SelectionMarker
var panel: ContextPanel

## While a mode (land, placement) is open it owns world taps.
var land_mode: LandMode
var placement: PlacementMode
var momo_views: MomoViews
var momo_panel: MomoPanel
var kind := ""
var selected_id := 0
var selected_cell := Vector2i.ZERO
var last_result: Dictionary = {}


func setup(p_sim: Simulation, p_projection: IsoProjection, p_views: BuildingViews, p_marker: SelectionMarker, p_panel: ContextPanel, router: InputRouter) -> void:
	sim = p_sim
	world = sim.system(&"world")
	buildings = sim.system(&"buildings")
	projection = p_projection
	views = p_views
	marker = p_marker
	panel = p_panel
	router.tapped.connect(on_tap)
	panel.start_pressed.connect(func(id: int) -> void: _act_on(id))
	panel.cancel_pressed.connect(func(id: int) -> void:
		last_result = sim.execute({"type": "building.cancel", "id": id})
		if last_result["ok"]:
			deselect())


func on_tap(_screen: Vector2, world_pos: Vector2) -> void:
	if land_mode != null and land_mode.active:
		land_mode.on_world_tap(world_pos)
		return
	if placement != null and placement.active:
		placement.on_world_tap(world_pos)
		return
	# Assign mode (the no-drag way): the next building tapped gets the Momo.
	if kind == "momo" and momo_panel != null and momo_panel.assigning:
		var target := views.hit(world_pos)
		if target == 0:
			target = buildings.building_at(projection.cell_at(world_pos))
		if target != 0:
			last_result = sim.execute({"type": "momo.assign", "momo": selected_id, "building": target})
			momo_panel.assigning = false
			if not last_result["ok"] and momo_views.actor(selected_id) != null:
				momo_views.actor(selected_id).refuse()
			return
	var momo := momo_views.hit(world_pos) if momo_views != null else 0
	if momo != 0:
		select_momo(momo)
		return
	var id := views.hit(world_pos)
	if id == 0:
		id = buildings.building_at(projection.cell_at(world_pos))
	if id != 0:
		select_building(id)
		_act_on(id)
		return
	var cell := projection.cell_at(world_pos)
	if world.is_owned(cell):
		select_tile(cell, "tile.grass")
	elif world.is_purchasable(cell):
		select_tile(cell, "tile.sea")
	else:
		deselect()


func _act_on(id: int) -> void:
	last_result = sim.execute({"type": "building.tap", "id": id})
	var v := views.view(id)
	if v != null and not last_result["ok"]:
		v.refuse()


func select_momo(id: int) -> void:
	_unmark()
	kind = "momo"
	selected_id = id
	momo_views.actor(id).selected = true
	marker.clear()
	panel.hide_panel()
	momo_panel.show_momo(id)
	selection_changed.emit(kind)


func select_building(id: int) -> void:
	if kind == "building" and selected_id == id:
		return
	_unmark()
	kind = "building"
	selected_id = id
	var v := views.view(id)
	if v:
		v.selected = true
	marker.clear()
	panel.show_building(id)
	selection_changed.emit(kind)


func select_tile(cell: Vector2i, label_key: String) -> void:
	_unmark()
	kind = "tile"
	selected_cell = cell
	marker.show_cell(cell)
	panel.show_tile(label_key)
	selection_changed.emit(kind)


func deselect() -> void:
	if kind == "":
		return
	_unmark()
	kind = ""
	marker.clear()
	panel.hide_panel()
	selection_changed.emit(kind)


func _unmark() -> void:
	if kind == "building":
		var v := views.view(selected_id)
		if v:
			v.selected = false
	elif kind == "momo":
		var a := momo_views.actor(selected_id)
		if a:
			a.selected = false
		momo_panel.hide_panel()
	selected_id = 0
