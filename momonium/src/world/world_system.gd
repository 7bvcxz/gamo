class_name WorldSystem
extends SimSystem

## The land: which square cells the player owns, and what stands on them.
##
## Everything outside owned land is ocean. Cells are Vector2i keys in
## dictionaries, so an island of any shape and thousands of cells costs O(1)
## per lookup and nothing for the empty sea around it. Gameplay occupancy
## (a farm on a cell) lives here; decoration (flowers, pebbles) does not --
## renderers derive it from the cell, so it can never block a building.
##
## Cell states, as the rest of the game asks for them:
##   OCEAN       not owned (and not next to land)
##   PURCHASABLE not owned, shares an edge with owned land (Step 12 buys these)
##   BUILDABLE   owned and free
##   OCCUPIED    owned and something stands on it

enum CellState { OCEAN, PURCHASABLE, BUILDABLE, OCCUPIED }

const NEIGHBOURS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]

## Owned cells -> terrain id (e.g. &"grass").
var land: Dictionary = {}
## Occupied cells -> occupant id (> 0).
var occupancy: Dictionary = {}
## Occupant id -> Array[Vector2i] it covers (reverse index for vacate).
var _footprints: Dictionary = {}


func _init() -> void:
	key = &"world"


func on_new_game() -> void:
	land.clear()
	occupancy.clear()
	_footprints.clear()
	var origin := sim.data.get_vec2i("balance", "start.island.origin")
	var size := sim.data.get_vec2i("balance", "start.island.size", Vector2i(2, 2))
	for y in size.y:
		for x in size.x:
			land[origin + Vector2i(x, y)] = &"grass"


# --- queries ------------------------------------------------------------------

func is_owned(cell: Vector2i) -> bool:
	return land.has(cell)


func is_occupied(cell: Vector2i) -> bool:
	return occupancy.has(cell)


func is_buildable(cell: Vector2i) -> bool:
	return land.has(cell) and not occupancy.has(cell)


func occupant(cell: Vector2i) -> int:
	return occupancy.get(cell, 0)


## Not owned, but shares an edge with owned land. Diagonal contact is not
## enough: the island grows by whole edges so it stays one piece.
func is_purchasable(cell: Vector2i) -> bool:
	if land.has(cell):
		return false
	for d: Vector2i in NEIGHBOURS:
		if land.has(cell + d):
			return true
	return false


func cell_state(cell: Vector2i) -> CellState:
	if occupancy.has(cell):
		return CellState.OCCUPIED
	if land.has(cell):
		return CellState.BUILDABLE
	if is_purchasable(cell):
		return CellState.PURCHASABLE
	return CellState.OCEAN


func owned_count() -> int:
	return land.size()


## Owned cells in a stable order (row by row), so anything iterating them is
## deterministic whatever order they were bought in.
func owned_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Vector2i in land:
		out.append(c)
	out.sort_custom(_row_major)
	return out


func buildable_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Vector2i in owned_cells():
		if not occupancy.has(c):
			out.append(c)
	return out


## Every purchasable cell, row by row.
func frontier() -> Array[Vector2i]:
	var seen := {}
	for c: Vector2i in land:
		for d: Vector2i in NEIGHBOURS:
			var n: Vector2i = c + d
			if not land.has(n):
				seen[n] = true
	var out: Array[Vector2i] = []
	for c: Vector2i in seen:
		out.append(c)
	out.sort_custom(_row_major)
	return out


## Smallest rectangle containing all owned land.
func bounds() -> Rect2i:
	if land.is_empty():
		return Rect2i()
	var lo := Vector2i(2147483647, 2147483647)
	var hi := Vector2i(-2147483648, -2147483648)
	for c: Vector2i in land:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	return Rect2i(lo, hi - lo + Vector2i.ONE)


## True when all owned land is one edge-connected piece.
func is_contiguous() -> bool:
	if land.is_empty():
		return true
	var start: Vector2i = land.keys()[0]
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d: Vector2i in NEIGHBOURS:
			var n: Vector2i = c + d
			if land.has(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return seen.size() == land.size()


# --- changes (called by other systems; the player goes through commands) -------

## Adds one edge-adjacent cell. Refuses anything that would split the island.
func add_land(cell: Vector2i, terrain: StringName = &"grass") -> bool:
	if not is_purchasable(cell):
		return false
	land[cell] = terrain
	sim.bus.emit(&"land_added", {"cell": [cell.x, cell.y], "count": land.size()})
	return true


## Marks `cells` as covered by `id`. All or nothing: refuses if any cell is not
## buildable.
func occupy(cells: Array[Vector2i], id: int) -> bool:
	if id <= 0 or _footprints.has(id) or cells.is_empty():
		return false
	for c: Vector2i in cells:
		if not is_buildable(c):
			return false
	for c: Vector2i in cells:
		occupancy[c] = id
	_footprints[id] = cells.duplicate()
	sim.bus.emit(&"occupancy_changed", {"id": id, "occupied": true})
	return true


func vacate(id: int) -> bool:
	if not _footprints.has(id):
		return false
	for c: Vector2i in _footprints[id]:
		occupancy.erase(c)
	_footprints.erase(id)
	sim.bus.emit(&"occupancy_changed", {"id": id, "occupied": false})
	return true


func footprint(id: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Vector2i in _footprints.get(id, []):
		out.append(c)
	return out


# --- persistence ----------------------------------------------------------------

func save_state() -> Dictionary:
	var cells: Array = []
	for c: Vector2i in owned_cells():
		cells.append([c.x, c.y, String(land[c])])
	var occupied: Array = []
	var ids: Array = _footprints.keys()
	ids.sort()
	for id: int in ids:
		var fp: Array = []
		for c: Vector2i in _footprints[id]:
			fp.append([c.x, c.y])
		occupied.append({"id": id, "cells": fp})
	return {"land": cells, "occupants": occupied}


func load_state(state: Dictionary) -> void:
	land.clear()
	occupancy.clear()
	_footprints.clear()
	for entry: Array in state.get("land", []):
		land[Vector2i(int(entry[0]), int(entry[1]))] = StringName(entry[2] if entry.size() > 2 else "grass")
	for entry: Dictionary in state.get("occupants", []):
		var id := int(entry["id"])
		var cells: Array[Vector2i] = []
		for c: Array in entry["cells"]:
			var cell := Vector2i(int(c[0]), int(c[1]))
			cells.append(cell)
			occupancy[cell] = id
		_footprints[id] = cells


static func _row_major(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or (a.y == b.y and a.x < b.x)
