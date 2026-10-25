class_name WatchOverlay
extends Node2D

## The tiles a selected Momo looks after, tinted on the ground in a soft
## teal no other marker uses (gold is the selected tile, green/red the land
## preview). Stronger while they are being edited; a tile that could not be
## added flashes red for a moment.

const FILL := Color(0.35, 0.86, 0.85)
const EDGE := Color(0.62, 1.0, 0.96)
const REFUSED := Color(1.0, 0.42, 0.36)
const FLASH_SECONDS := 0.6

var projection: IsoProjection
var momos: MomoSystem
var momo := 0
var editing := false
## cell -> seconds of red left
var _flash: Dictionary = {}
var _t := 0.0


func setup(sim: Simulation, p_projection: IsoProjection) -> void:
	momos = sim.system(&"momo")
	projection = p_projection
	sim.bus.emitted.connect(func(type: StringName, p: Dictionary) -> void:
		if type == &"momo_watch_changed" and int(p.get("id", 0)) == momo:
			queue_redraw())


func show_for(id: int) -> void:
	momo = id
	queue_redraw()


func clear() -> void:
	momo = 0
	editing = false
	_flash.clear()
	queue_redraw()


func flash(cell: Vector2i) -> void:
	_flash[cell] = FLASH_SECONDS
	queue_redraw()


func _process(delta: float) -> void:
	if momo == 0:
		return
	_t += delta
	for c: Vector2i in _flash.keys():
		_flash[c] = float(_flash[c]) - delta
		if float(_flash[c]) <= 0.0:
			_flash.erase(c)
	# Only while something moves: the edit pulse or a fading flash.
	if editing or not _flash.is_empty():
		queue_redraw()


func _draw() -> void:
	if momo == 0 or projection == null:
		return
	var pulse := 0.85 + 0.15 * sin(_t * 3.0) if editing else 1.0
	for cell: Vector2i in momos.watched(momo):
		var c := projection.cell_corners(cell)
		draw_colored_polygon(c, Color(FILL, (0.42 if editing else 0.32) * pulse))
		var loop := c.duplicate()
		loop.append(c[0])
		draw_polyline(loop, Color(EDGE, 0.95 if editing else 0.8), 4.0 if editing else 3.0, true)
	for cell: Vector2i in _flash:
		var c := projection.cell_corners(cell)
		draw_colored_polygon(c, Color(REFUSED, 0.45 * float(_flash[cell]) / FLASH_SECONDS))


## What is drawn, for tests: {cell: true} of tinted tiles.
func tinted() -> Array[Vector2i]:
	return momos.watched(momo) if momo != 0 else ([] as Array[Vector2i])
