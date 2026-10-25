class_name IslandRenderer
extends Node2D

## Draws owned land. Step 05 version: the top face of every owned cell, flat,
## with its 1x1 boundary. Cliffs, shoreline and textures arrive in Step 06.

var _world: WorldSystem
var _proj: IsoProjection
var _grass: Color
var _line: Color


func setup(sim: Simulation, projection: IsoProjection) -> void:
	_world = sim.system(&"world")
	_proj = projection
	_grass = sim.data.color("grass", 1)
	_line = sim.data.color("grass", 2)
	sim.bus.emitted.connect(_on_event)
	queue_redraw()


func _on_event(type: StringName, _payload: Dictionary) -> void:
	if type == &"land_added" or type == &"game_loaded":
		queue_redraw()


func _draw() -> void:
	if _world == null:
		return
	for cell: Vector2i in _world.owned_cells():
		var corners := _proj.cell_corners(cell)
		draw_colored_polygon(corners, _grass)
		var loop := corners.duplicate()
		loop.append(corners[0])
		draw_polyline(loop, _line, 1.5, true)
