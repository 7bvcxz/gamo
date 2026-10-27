class_name WatchOverlay
extends Node2D

## The tiles a selected Momo looks after, tinted on the ground in a soft
## teal no other marker uses (gold is the selected tile, green/red the land
## preview). Stronger in Schedule mode (Step 60), where the island's other
## tiles it could take are outlined too -- faintly, a little more on a
## building it could work, dimmer still once it is full -- so what it works
## and what it could work never look alike. A tile added swells once, one
## taken away fades out; a tile that could not be added flashes red with a
## cross. Its route: a thin line from the Momo through its buildings in the
## order it will visit them, numbered.

const FILL := Color(0.35, 0.86, 0.85)
const EDGE := Color(0.62, 1.0, 0.96)
const REFUSED := Color(1.0, 0.42, 0.36)
const FLASH_SECONDS := 0.6
const PULSE_SECONDS := 0.35

var projection: IsoProjection
var momos: MomoSystem
var jobs: JobSystem
var world: WorldSystem
var buildings: BuildingSystem
var font: Font
var _route_t := 0.0
## The route is drawn above the buildings (the tint stays on the ground).
var route_layer: Node2D
var momo := 0
var editing := false:
	set(value):
		editing = value
		_eligible_dirty = true
		_eligible_t = 0.0
## cell -> seconds of red left
var _flash: Dictionary = {}
## cell -> [seconds left, added]: the calm answer to a tile changed.
var _pulse: Dictionary = {}
## The tiles it could take, as drawn in Schedule mode: [[corners, workplace]].
## Worked out again (at most four times a second) when anything changes.
var _eligible: Array = []
var _eligible_dirty := true
var _eligible_t := 0.0
var _t := 0.0
## How many times the route has been drawn (tests: not with every pulse).
var route_draws := 0


func setup(sim: Simulation, p_projection: IsoProjection) -> void:
	momos = sim.system(&"momo")
	jobs = sim.system(&"jobs")
	world = sim.system(&"world")
	buildings = sim.system(&"buildings")
	projection = p_projection
	font = ThemeDB.fallback_font
	route_layer = Node2D.new()
	route_layer.name = "Route"
	route_layer.z_as_relative = false
	route_layer.z_index = 50
	route_layer.draw.connect(_draw_route)
	add_child(route_layer)
	sim.bus.emitted.connect(func(type: StringName, p: Dictionary) -> void:
		# Land, buildings, research (room for more tiles): what it could take.
		_eligible_dirty = true
		if type in [&"momo_watch_changed", &"momo_route_changed", &"momo_assigned"] and int(p.get("id", 0)) == momo:
			queue_redraw()
			route_layer.queue_redraw())


func show_for(id: int) -> void:
	momo = id
	_eligible_dirty = true
	_eligible_t = 0.0
	queue_redraw()
	route_layer.queue_redraw()


func clear() -> void:
	momo = 0
	editing = false
	_flash.clear()
	_pulse.clear()
	queue_redraw()
	if route_layer != null:
		route_layer.queue_redraw()


func flash(cell: Vector2i) -> void:
	_flash[cell] = FLASH_SECONDS
	queue_redraw()


func pulse(cell: Vector2i, added: bool) -> void:
	_pulse[cell] = [PULSE_SECONDS, added]
	queue_redraw()


## The owned tiles this Momo could still take (not watched; land; a building
## only if it has Momo work), [cell, workplace] each -- what Schedule mode
## outlines. Room left is not asked here: a full Momo's are dimmed instead.
func eligible() -> Array:
	var out: Array = []
	if momo == 0 or world == null:
		return out
	for cell: Vector2i in world.owned_cells():
		if momos.is_watching(momo, cell):
			continue
		var on := buildings.building_at(cell)
		if on != 0 and momos.slots_of(on) <= 0:
			continue
		out.append([cell, on != 0])
	return out


func _process(delta: float) -> void:
	if momo == 0:
		return
	_t += delta
	for c: Vector2i in _flash.keys():
		_flash[c] = float(_flash[c]) - delta
		if float(_flash[c]) <= 0.0:
			_flash.erase(c)
	for c: Vector2i in _pulse.keys():
		_pulse[c][0] = float(_pulse[c][0]) - delta
		if float(_pulse[c][0]) <= 0.0:
			_pulse.erase(c)
	_eligible_t -= delta
	if editing and _eligible_dirty and _eligible_t <= 0.0:
		_eligible_t = 0.25
		_eligible_dirty = false
		_eligible = eligible().map(func(e: Array) -> Array: return [projection.cell_corners(e[0]), e[1]])
	# Only while something moves: the edit pulse or a fading flash -- and the
	# route line, which starts at the Momo, twice a second.
	_route_t += delta
	if editing or not _flash.is_empty() or not _pulse.is_empty():
		queue_redraw()
	if _route_t >= 0.5:
		_route_t = 0.0
		route_layer.queue_redraw()


func _draw() -> void:
	if momo == 0 or projection == null:
		return
	var pulse := 0.85 + 0.15 * sin(_t * 3.0) if editing else 1.0
	if editing:
		# What it could take: outlined, never filled like what it works.
		var full := momos.watched(momo).size() >= momos.watch_capacity(momo)
		for e: Array in _eligible:
			var c: PackedVector2Array = e[0]
			if bool(e[1]):
				draw_colored_polygon(c, Color(1, 1, 1, 0.05 if full else 0.12))
			var loop := c.duplicate()
			loop.append(c[0])
			draw_polyline(loop, Color(1, 1, 1, 0.22 if full else 0.5), 1.5, true)
	for cell: Vector2i in momos.watched(momo):
		var c := projection.cell_corners(cell)
		draw_colored_polygon(c, Color(FILL, (0.42 if editing else 0.32) * pulse))
		var loop := c.duplicate()
		loop.append(c[0])
		draw_polyline(loop, Color(EDGE, 0.95 if editing else 0.8), 4.0 if editing else 3.0, true)
	for cell: Vector2i in _pulse:
		var a := float(_pulse[cell][0]) / PULSE_SECONDS
		var m := projection.cell_center(cell)
		var c := projection.cell_corners(cell)
		if bool(_pulse[cell][1]):
			# Added: a light swell over the new tile.
			draw_colored_polygon(c, Color(EDGE, 0.45 * a))
		else:
			# Taken away: its outline shrinks into the middle and goes.
			var k := 0.6 + 0.4 * a
			var ring := PackedVector2Array()
			for v: Vector2 in c:
				ring.append(m + (v - m) * k)
			ring.append(ring[0])
			draw_polyline(ring, Color(1, 1, 1, 0.8 * a), 2.5, true)
	for cell: Vector2i in _flash:
		var c := projection.cell_corners(cell)
		var a := float(_flash[cell]) / FLASH_SECONDS
		draw_colored_polygon(c, Color(REFUSED, 0.45 * a))
		# Not by colour alone: a cross says "no" to anyone who cannot tell red.
		var m := projection.cell_center(cell)
		draw_line(m + Vector2(-10, -6), m + Vector2(10, 6), Color(1, 1, 1, a), 3.0, true)
		draw_line(m + Vector2(-10, 6), m + Vector2(10, -6), Color(1, 1, 1, a), 3.0, true)
	# The route is not redrawn with the pulse: ordering it walks the whole
	# watch set, and it only moves when the tiles, the route or the Momo do
	# (the events above, and the half-second timer for walking).


## The route: Momo -> 1 -> 2 -> ..., in the order route_order() gives.
func _draw_route() -> void:
	route_draws += 1
	if jobs == null or momo == 0:
		return
	var order := route()
	if order.is_empty():
		return
	var pts := PackedVector2Array([projection.to_screen(momos.position_of(momo))])
	for id: int in order:
		pts.append(projection.to_screen(momos.work_spot(id)))
	var r := route_layer
	for i in range(pts.size() - 1):
		var steps := maxi(1, int(pts[i].distance_to(pts[i + 1]) / 10.0))
		for s in steps:
			if s % 2 == 0:
				r.draw_line(pts[i].lerp(pts[i + 1], float(s) / steps), pts[i].lerp(pts[i + 1], float(s + 1) / steps), Color(EDGE, 0.8), 3.0, true)
	for i in range(1, pts.size()):
		r.draw_circle(pts[i], 15.0, Color(0.06, 0.2, 0.26, 0.92))
		r.draw_arc(pts[i], 15.0, 0.0, TAU, 20, Color(EDGE, 0.95), 2.5, true)
		var t := str(i)
		var ts := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
		r.draw_string(font, pts[i] + Vector2(-ts.x * 0.5, 7), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)


## The buildings in visiting order, for the drawing and for tests.
func route() -> Array[int]:
	return jobs.route_order(momo) if jobs != null and momo != 0 else ([] as Array[int])


## What is drawn, for tests: {cell: true} of tinted tiles.
func tinted() -> Array[Vector2i]:
	return momos.watched(momo) if momo != 0 else ([] as Array[Vector2i])
