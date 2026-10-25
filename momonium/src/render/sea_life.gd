class_name SeaLife
extends Node2D

## A little life in the water by the island, never on a loop: now and then a
## fish jumps just off the shore -- a splash and two widening rings. Where and
## when come from a hash of the game clock's slot and the island's shoreline,
## so it is different every few seconds, the same on every replay, and costs
## nothing between splashes.

const SLOT_MS := 4200
const SPLASH_MS := 1600

var projection: IsoProjection
var world: WorldSystem
var sim: Simulation
## The water beside the island, kept until the land changes.
var _shore: Array[Vector2i] = []
var _shown := false


func setup(p_sim: Simulation, p_projection: IsoProjection) -> void:
	sim = p_sim
	projection = p_projection
	world = sim.system(&"world")
	_shore = world.frontier()
	sim.bus.emitted.connect(func(type: StringName, _p: Dictionary) -> void:
		if type in [&"land_added", &"game_loaded"]:
			_shore = world.frontier())


## The splash now: {cell, at (0..1 of its life), x, y (inside the tile)} or {}.
func current() -> Dictionary:
	var now := sim.now_ms()
	var slot := now / SLOT_MS
	var h := hash(slot * 7919 + 13)
	# About two slots in three have a fish; it jumps somewhere in the slot.
	if h % 3 == 0:
		return {}
	var start := slot * SLOT_MS + (h >> 4) % (SLOT_MS - SPLASH_MS)
	if now < start or now >= start + SPLASH_MS:
		return {}
	if _shore.is_empty():
		return {}
	var cell: Vector2i = _shore[(h >> 9) % _shore.size()]
	return {"cell": cell, "at": float(now - start) / SPLASH_MS, "x": float((h >> 3) % 60) / 100.0 + 0.2, "y": float((h >> 7) % 60) / 100.0 + 0.2}


## Redrawn only around a splash (and once after, to clear it).
func _process(_delta: float) -> void:
	var on := not current().is_empty()
	if on or _shown:
		queue_redraw()
	_shown = on


func _draw() -> void:
	var s := current()
	if s.is_empty():
		return
	var c := projection.to_screen(Vector2(s["cell"]) + Vector2(float(s["x"]), float(s["y"])), -projection.cliff_height)
	var k := float(s["at"])
	for i in 2:
		var r := 6.0 + (k + i * 0.25) * 26.0
		draw_arc(c, r, 0, TAU, 28, Color(1, 1, 1, 0.55 * (1.0 - k)), 2.0, true)
	if k < 0.35:
		var j := k / 0.35
		draw_circle(c + Vector2(0, -sin(j * PI) * 18.0), 3.5, Color(0.85, 0.93, 1.0, 1.0 - j))
