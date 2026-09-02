extends RefCounted

## What the agent is allowed to know, split by mode -- the one place the QA/
## PLAYER boundary lives, so a planner cannot quietly read the world.
##
## QA reads world internals for *navigation stability only*; the planner's
## goals are still gated by real progression state (unlocks, held items), so
## knowing where iron lies never lets it skip the ladder to iron.
##
## PLAYER sees a cell only if a person at the screen would: inside the fog the
## player has actually lifted -- explored ground -- and, for liftability, the
## warmth/torch rules the game itself applies. Nothing outside the fog exists.

var sim
var mode := "qa"

func _init(sim_ref, mode_v: String) -> void:
	sim = sim_ref
	mode = mode_v

func _knows(cell: Vector2i) -> bool:
	if mode == "qa":
		return true
	return bool(sim.explored.get(cell, false))

func ore_cells(item_type: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in sim.ore:
		if int(sim.ore[cell]) != item_type:
			continue
		if not _knows(cell):
			continue
		out.append(cell)
	return out

func frozen_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in sim.frozen_cats:
		if _knows(cell):
			out.append(cell)
	return out

func debris_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in sim.debris:
		if _knows(cell):
			out.append(cell)
	return out

## The nearest of a list to `from`, or the sentinel.
static func nearest(from: Vector2i, cells: Array[Vector2i]) -> Vector2i:
	var best := Vector2i(9999, 9999)
	var dist := 1e18
	for cell: Vector2i in cells:
		var d: float = Vector2(cell - from).length_squared()
		if d < dist:
			dist = d
			best = cell
	return best

## A frontier cell for the exploration goal: just past the warm edge, in a
## direction not yet explored. Used by PLAYER mode (and by QA when a needed
## resource genuinely is not inside the circle yet).
func frontier(core: Vector2i, radius: float) -> Vector2i:
	var best := Vector2i(9999, 9999)
	var best_score := -1.0
	for step in 24:
		var angle: float = TAU * float(step) / 24.0
		var cell: Vector2i = core + Vector2i(
			roundi(cos(angle) * (radius - 1.0)), roundi(sin(angle) * (radius - 1.0)))
		var beyond: Vector2i = core + Vector2i(
			roundi(cos(angle) * (radius + 2.0)), roundi(sin(angle) * (radius + 2.0)))
		var unseen: float = 0.0 if bool(sim.explored.get(beyond, false)) else 1.0
		if unseen > best_score and not sim.blocks_player(cell):
			best_score = unseen
			best = cell
	return best
