extends RefCounted

## The agent's legs' brain: A* over the same walkability the player's body
## obeys, plus the "where do I stand to touch that" search. Never a teleporter
## -- it returns paths, and the body walks them one cell at a time.
##
## Walkable is asked of `Sim.blocks_player`, the one function the game itself
## uses, so the graph cannot drift from the collision it models. Dynamic
## obstacles (a new machine, a put-down ice block) are handled by replanning
## rather than by trying to predict them.

const REGION_MARGIN := 10

var sim
## Cells the caller wants treated as solid this plan (e.g. a build target).
var extra_blocked: Dictionary = {}

func _init(sim_ref) -> void:
	sim = sim_ref

func walkable(cell: Vector2i) -> bool:
	if extra_blocked.has(cell):
		return false
	return not sim.blocks_player(cell)

## A* from start to goal, 4-neighbour, euclidean-ish heuristic. Returns the
## path *excluding* the start cell, or [] when no route exists inside the
## bounding region (start/goal box grown by REGION_MARGIN -- everything this
## game asks fits in it, and an unbounded flood on a 200-cell world is how a
## harness hangs).
func path(start: Vector2i, goal: Vector2i, goal_walkable_override: bool = false) -> Array[Vector2i]:
	if start == goal:
		return []
	var lo := Vector2i(mini(start.x, goal.x) - REGION_MARGIN, mini(start.y, goal.y) - REGION_MARGIN)
	var hi := Vector2i(maxi(start.x, goal.x) + REGION_MARGIN, maxi(start.y, goal.y) + REGION_MARGIN)
	var open := PriorityQueue.new()
	var came: Dictionary = {}
	var cost: Dictionary = {start: 0.0}
	open.push(start, Vector2(goal - start).length())
	var found := false
	var guard := 0
	while not open.empty() and guard < 20000:
		guard += 1
		var at: Vector2i = open.pop()
		if at == goal:
			found = true
			break
		for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = at + dir
			if next.x < lo.x or next.y < lo.y or next.x > hi.x or next.y > hi.y:
				continue
			if next != goal and not walkable(next):
				continue
			if next == goal and not goal_walkable_override and not walkable(next):
				continue
			var step_cost: float = float(cost[at]) + 1.0
			if cost.has(next) and step_cost >= float(cost[next]):
				continue
			cost[next] = step_cost
			came[next] = at
			open.push(next, step_cost + Vector2(goal - next).length())
	if not found:
		return []
	var out: Array[Vector2i] = []
	var walk: Vector2i = goal
	while walk != start:
		out.push_front(walk)
		walk = came[walk]
	return out

## Where to stand to touch `target`: its walkable 4-neighbours, each scored by
## real path length from `from`. Returns {"stand": cell, "path": [...]} or {}.
## This is the search that kills the "walk straight at the object and stop
## against it" failure the straight-line harness had.
func interaction(from: Vector2i, target: Vector2i) -> Dictionary:
	var best: Dictionary = {}
	var best_len := 1 << 30
	for dir: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
		var stand: Vector2i = target + dir
		if not walkable(stand):
			continue
		if stand == from:
			return {"stand": stand, "path": [] as Array[Vector2i]}
		var route: Array[Vector2i] = path(from, stand)
		if route.is_empty():
			continue
		if route.size() < best_len:
			best_len = route.size()
			best = {"stand": stand, "path": route}
	return best

## Plain reachability, for classification: is there any walking route at all?
func reachable(from: Vector2i, target: Vector2i) -> bool:
	if not interaction(from, target).is_empty():
		return true
	return walkable(target) and not path(from, target).is_empty()

## A tiny binary heap so the A* open set is not an O(n) scan.
class PriorityQueue:
	var _cells: Array[Vector2i] = []
	var _scores: Array[float] = []

	func empty() -> bool:
		return _cells.is_empty()

	func push(cell: Vector2i, score: float) -> void:
		_cells.append(cell)
		_scores.append(score)
		var index: int = _cells.size() - 1
		while index > 0:
			var parent: int = (index - 1) / 2
			if _scores[parent] <= _scores[index]:
				break
			_swap(index, parent)
			index = parent

	func pop() -> Vector2i:
		var top: Vector2i = _cells[0]
		var last: int = _cells.size() - 1
		_swap(0, last)
		_cells.resize(last)
		_scores.resize(last)
		var index := 0
		while true:
			var left: int = index * 2 + 1
			var right: int = left + 1
			var smallest: int = index
			if left < _cells.size() and _scores[left] < _scores[smallest]:
				smallest = left
			if right < _cells.size() and _scores[right] < _scores[smallest]:
				smallest = right
			if smallest == index:
				break
			_swap(index, smallest)
			index = smallest
		return top

	func _swap(a: int, b: int) -> void:
		var c: Vector2i = _cells[a]
		_cells[a] = _cells[b]
		_cells[b] = c
		var s: float = _scores[a]
		_scores[a] = _scores[b]
		_scores[b] = s
