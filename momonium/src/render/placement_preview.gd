class_name PlacementPreview
extends Node2D

## The ghost of a building being placed: its footprint tinted green where it
## can go and red where it cannot, and the building itself, translucent,
## standing where it would stand. Visual only; PlacementMode decides.

var projection: IsoProjection
var buildings: BuildingSystem
var lib: SpriteLibrary
var type := ""
var anchor := Vector2i.ZERO
var valid := false
var active := false
var _ghost: Sprite2D
var _t := 0.0


func setup(sim: Simulation, p_projection: IsoProjection, p_lib: SpriteLibrary) -> void:
	projection = p_projection
	buildings = sim.system(&"buildings")
	lib = p_lib
	_ghost = Sprite2D.new()
	_ghost.modulate = Color(1, 1, 1, 0.6)
	_ghost.visible = false
	add_child(_ghost)


func show_at(p_type: String, p_anchor: Vector2i, p_valid: bool) -> void:
	type = p_type
	anchor = p_anchor
	valid = p_valid
	active = true
	var sprite_name: String = buildings.sim.data.building_type(type).get("sprite", "")
	if lib.has(sprite_name):
		lib.place(_ghost, sprite_name)
		_ghost.modulate = Color(1, 1, 1, 0.65) if valid else Color(1, 0.55, 0.5, 0.55)
	_ghost.position = _centre()
	_ghost.visible = true
	queue_redraw()


func clear() -> void:
	active = false
	_ghost.visible = false
	queue_redraw()


func footprint() -> Array[Vector2i]:
	return buildings.cells_of({"type": type, "anchor": [anchor.x, anchor.y]})


func _centre() -> Vector2:
	var cells := footprint()
	var c := Vector2.ZERO
	for cell: Vector2i in cells:
		c += Vector2(cell) + Vector2(0.5, 0.5)
	return projection.to_screen(c / maxf(cells.size(), 1.0))


func _process(delta: float) -> void:
	if active:
		_t += delta
		queue_redraw()


func _draw() -> void:
	if not active:
		return
	var pulse := 0.8 + 0.2 * sin(_t * 5.0)
	var fill := Color(0.45, 0.95, 0.5, 0.3 * pulse) if valid else Color(1.0, 0.35, 0.3, 0.32 * pulse)
	var line := Color(0.6, 1.0, 0.6, 0.95) if valid else Color(1.0, 0.45, 0.4, 0.95)
	for cell: Vector2i in footprint():
		var c := projection.cell_corners(cell)
		draw_colored_polygon(c, fill)
		var loop := c.duplicate()
		loop.append(c[0])
		draw_polyline(loop, line, 3.0, true)
