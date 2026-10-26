class_name SelectionController
extends Node

## What a tap on the world means, and what is selected.
##
## Receives taps from the InputRouter (which has already given the UI and any
## drag the first say). A Momo under the finger wins (but tapped again while
## selected, it lets the tap through to its building), then the front-most
## building sprite, then the building on the tapped cell, then the cell
## itself; open sea deselects.
## Tapping a ready building starts its work at once -- the tap is the action,
## not a request to open a menu -- and selects it so its cards show progress.
## Selection is presentation state: it is not saved and the simulation never
## sees it. A building keeps working when something else is selected.

signal selection_changed(kind: String)
## World units a tap may miss a Momo by and still pick it -- set by the
## tutorial while it asks for one (Step 50: blind players needed three or four
## taps to catch a Momo walking away).
var momo_slack := 0.0

var sim: Simulation
var world: WorldSystem
var buildings: BuildingSystem
var projection: IsoProjection
var views: BuildingViews
var marker: SelectionMarker
var panel: ContextPanel

## Sea next to the island: preview, then buy.
var land_buyer: LandBuyer
var momo_views: MomoViews
var momo_panel: MomoPanel
var kind := ""
var selected_id := 0
var selected_cell := Vector2i.ZERO
var last_result: Dictionary = {}
## Where taps come from (it says whether the last one was a mouse click).
var router: InputRouter


func setup(p_sim: Simulation, p_projection: IsoProjection, p_views: BuildingViews, p_marker: SelectionMarker, p_panel: ContextPanel, p_router: InputRouter) -> void:
	router = p_router
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
	# Editing a Momo's tiles: taps are the brush.
	if watch_editor != null and watch_editor.active:
		watch_editor.on_tap(world_pos)
		return
	# A finger's land preview waits for a second tap on that tile; any other
	# tap puts it away.
	if land_buyer != null and land_buyer.pending != projection.cell_at(world_pos):
		land_buyer.clear()
	# Assign mode (the no-drag way): the next building tapped gets the Momo.
	if kind == "momo" and momo_panel != null and momo_panel.assigning:
		var target := views.hit(world_pos)
		if target == 0:
			target = buildings.building_at(projection.cell_at(world_pos))
		if target != 0:
			last_result = sim.execute({"type": "momo.assign", "momo": selected_id, "building": target})
			momo_panel.assigning = false
			if not last_result["ok"]:
				# Why, in words (Step 50: a refused assignment only shook the
				# Momo and blind players thought Assign did nothing).
				momo_panel.say(tr(String(last_result.get("reason", ""))))
				if momo_views.actor(selected_id) != null:
					momo_views.actor(selected_id).refuse()
			return
	var id := views.hit(world_pos)
	if id == 0:
		id = buildings.building_at(projection.cell_at(world_pos))
	var momo := momo_views.hit(world_pos, momo_slack) if momo_views != null else 0
	# The Momo in front wins -- except a second tap on the one already
	# selected: that reaches what it stands on, a building or an empty tile.
	# A working Momo stands on its farm, and the blind playtest (Step 45)
	# kept getting the Momo.
	if momo != 0 and not (kind == "momo" and selected_id == momo):
		select_momo(momo)
		return
	if id != 0:
		select_building(id)
		_act_on(id)
		return
	var cell := projection.cell_at(world_pos)
	if world.is_owned(cell):
		select_tile(cell, "tile.grass")
		# An empty tile of the island: the four families to build, right here.
		if build_strip != null and world.is_buildable(cell):
			panel.hide_panel()
			build_strip.show_for(cell)
	elif land_buyer != null and land_buyer.buyable(cell):
		deselect()
		land_buyer.on_tap(world_pos, router.last_tap_mouse)
	else:
		deselect()


func _act_on(id: int) -> void:
	last_result = sim.execute({"type": "building.tap", "id": id})
	var v := views.view(id)
	if v != null and not last_result["ok"]:
		v.refuse()


## The four choices beside an empty tile.
var build_strip: BuildStrip
## The selected Momo's tiles and their pencil.
var watch_editor: WatchEditor


func select_momo(id: int) -> void:
	# A Momo that is not there (any more) selects nothing -- Step 53 islands
	# may have none at all.
	if momo_views.actor(id) == null:
		return
	_unmark()
	kind = "momo"
	selected_id = id
	momo_views.actor(id).selected = true
	marker.clear()
	panel.hide_panel()
	momo_panel.show_momo(id)
	if watch_editor != null:
		watch_editor.show_for(id)
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
	if build_strip != null:
		build_strip.close()
	if kind == "building":
		var v := views.view(selected_id)
		if v:
			v.selected = false
	elif kind == "momo":
		var a := momo_views.actor(selected_id)
		if a:
			a.selected = false
		momo_panel.hide_panel()
		if watch_editor != null:
			watch_editor.hide_editor()
	selected_id = 0
