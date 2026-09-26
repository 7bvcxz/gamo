extends RefCounted

## The agent's legs' brain: A* over the same walkability the player's body
## obeys, plus the "where do I stand to touch that" search. Never a teleporter
## -- it returns paths, and the body walks them one cell at a time.
##
## Walkable is asked of `Sim.blocks_player`, the one function the game itself
## uses, so the graph cannot drift from the collision it models. Dynamic
## obstacles (a new machine, a put-down ice block) are handled by replanning
## rather than by trying to predict them.

## Five tiles either side of the start/goal box, in cells.
const REGION_MARGIN := 5 * Grid.SCALE
const GUARD := 80000
const STEPS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var sim
## Cells the caller wants treated as solid this plan (e.g. a build target).
var extra_blocked: Dictionary = {}

func _init(sim_ref) -> void:
	sim = sim_ref

## Nothing solid on the cell itself.
func open(cell: Vector2i) -> bool:
	if extra_blocked.has(cell):
		return false
	return not sim.blocks_player(cell)

## The two-by-two block whose top-left cell is `corner`, all of it open. Her body
## is eighteen pixels and a cell sixteen, so she always covers two cells each
## way: a block of four open cells is the smallest ground she fits on.
func _block_open(corner: Vector2i) -> bool:
	return open(corner) and open(corner + Vector2i(1, 0)) \
		and open(corner + Vector2i(0, 1)) and open(corner + Vector2i(1, 1))

## Whether she can stand on this cell: it is open and part of an open block.
##
## Grid v2 made a cell narrower than her. A path through a one-cell gap is a
## path her body cannot walk -- the mover stops her a pixel short and the plan
## says go on -- so the graph asks what the mover asks, the whole body.
func walkable(cell: Vector2i) -> bool:
	if not open(cell):
		return false
	for corner: Vector2i in [cell, cell - Vector2i(1, 0), cell - Vector2i(0, 1), cell - Vector2i(1, 1)]:
		if _block_open(corner):
			return true
	return false

## Where in `cell` the middle of her body can actually be: the middle, moved a
## pixel and a half away from any solid neighbour. Her body is eighteen pixels
## and a cell sixteen, so at the exact middle she overlaps every neighbour by a
## pixel -- and in a corridor exactly a tile wide, aiming at cell middles walks
## her into the wall on every step.
func safe_point(cell: Vector2i) -> Vector2:
	var push := Vector2.ZERO
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if (dx != 0 or dy != 0) and not open(cell + Vector2i(dx, dy)):
				push -= Vector2(dx, dy)
	return Grid.centre(cell) + Vector2(signf(push.x), signf(push.y)) * 1.5

## A step between neighbours is walkable when some open block holds both: that
## is a corridor at least a tile wide along the step, which her body fits.
func can_step(from: Vector2i, to: Vector2i) -> bool:
	var dir: Vector2i = to - from
	var side := Vector2i(absi(dir.y), absi(dir.x))
	var low: Vector2i = Vector2i(mini(from.x, to.x), mini(from.y, to.y))
	return _block_open(low) or _block_open(low - side)

## A* from start to goal, 4-neighbour, euclidean-ish heuristic. Returns the
## path *excluding* the start cell, or [] when no route exists inside the
## bounding region (start/goal box grown by REGION_MARGIN -- everything this
## game asks fits in it, and an unbounded flood on a 200-tile world is how a
## harness hangs).
func path(start: Vector2i, goal: Vector2i, goal_walkable_override: bool = false) -> Array[Vector2i]:
	if start == goal:
		return []
	var goals: Dictionary = {goal: true}
	return _search(start, goals, Rect2i(goal, Vector2i.ONE), goal_walkable_override)

## The shortest route to any of `goals`, heading for `area`.
func _search(start: Vector2i, goals: Dictionary, area: Rect2i,
		override: bool = false) -> Array[Vector2i]:
	var lo := Vector2i(mini(start.x, area.position.x) - REGION_MARGIN,
		mini(start.y, area.position.y) - REGION_MARGIN)
	var hi := Vector2i(maxi(start.x, area.end.x) + REGION_MARGIN,
		maxi(start.y, area.end.y) + REGION_MARGIN)
	var open_set := PriorityQueue.new()
	var came: Dictionary = {}
	var cost: Dictionary = {start: 0.0}
	open_set.push(start, _to_area(start, area))
	var found := Vector2i(9999, 9999)
	var guard := 0
	while not open_set.empty() and guard < GUARD:
		guard += 1
		var at: Vector2i = open_set.pop()
		if goals.has(at):
			found = at
			break
		for dir: Vector2i in STEPS:
			var next: Vector2i = at + dir
			if next.x < lo.x or next.y < lo.y or next.x > hi.x or next.y > hi.y:
				continue
			var ending: bool = goals.has(next) and override
			if not ending and (not walkable(next) or not can_step(at, next)):
				continue
			var step_cost: float = float(cost[at]) + 1.0
			if cost.has(next) and step_cost >= float(cost[next]):
				continue
			cost[next] = step_cost
			came[next] = at
			open_set.push(next, step_cost + _to_area(next, area))
	if found == Vector2i(9999, 9999):
		return []
	var out: Array[Vector2i] = []
	var walk: Vector2i = found
	while walk != start:
		out.push_front(walk)
		walk = came[walk]
	return out

static func _to_area(cell: Vector2i, area: Rect2i) -> float:
	var near := Vector2i(clampi(cell.x, area.position.x, area.end.x - 1),
		clampi(cell.y, area.position.y, area.end.y - 1))
	return Vector2(near - cell).length()

## The ground a thing on `target` covers: a machine's footprint, the hut, the
## bin, a block of ice or wreckage a tile across -- or the cell itself.
func footprint(target: Vector2i) -> Rect2i:
	var machine = sim.machine_at(target)
	if machine != null:
		return sim.machine_rect(machine)
	if sim.in_shelter(target):
		return sim.shelter_rect()
	if sim.in_food_bin(target):
		return sim.food_rect()
	for props: Dictionary in [sim.frozen_cats, sim.debris, sim.village]:
		var key: Vector2i = sim.prop_key(props, target)
		if key != Sim.NONE:
			return sim.prop_rect(key)
	if sim.is_kit(target):
		return sim.prop_rect(sim.kit_cell)
	if sim.is_sign(target):
		return sim.prop_rect(sim.sign_cell)
	return Rect2i(target, Vector2i.ONE)

## Where to stand to touch `target`: a walkable cell against its footprint,
## the nearest by real path length from `from`, and which way to face from it.
## Returns {"stand": cell, "path": [...], "face": dir} or {}.
## This is the search that kills the "walk straight at the object and stop
## against it" failure the straight-line harness had -- and, since Grid v2,
## the "stand beside the anchor, inside the building" one.
func interaction(from: Vector2i, target: Vector2i) -> Dictionary:
	return interaction_rect(from, footprint(target))

## `keep_clear`: the stand must keep her whole body off `rect` -- for ground a
## building is about to go on, which refuses a cell she is standing over.
func interaction_rect(from: Vector2i, rect: Rect2i, keep_clear: bool = false) -> Dictionary:
	var faces: Dictionary = {}
	for x in range(rect.position.x, rect.end.x):
		faces[Vector2i(x, rect.position.y - 1)] = Vector2i(0, 1)
		faces[Vector2i(x, rect.end.y)] = Vector2i(0, -1)
	for y in range(rect.position.y, rect.end.y):
		faces[Vector2i(rect.position.x - 1, y)] = Vector2i(1, 0)
		faces[Vector2i(rect.end.x, y)] = Vector2i(-1, 0)
	var goals: Dictionary = {}
	for stand: Vector2i in faces:
		if walkable(stand) and (not keep_clear or not _body_over(stand, rect)):
			goals[stand] = true
	if goals.is_empty():
		return {}
	if goals.has(from):
		return {"stand": from, "path": [] as Array[Vector2i], "face": faces[from]}
	var route: Array[Vector2i] = _search(from, goals, rect)
	if route.is_empty():
		return {}
	var stand: Vector2i = route[-1]
	return {"stand": stand, "path": route, "face": faces[stand]}

## Whether her body, standing on `stand`, covers a cell of `rect` -- measured
## the way Main.body_cells measures it for the build refusal.
func _body_over(stand: Vector2i, rect: Rect2i) -> bool:
	var at: Vector2 = safe_point(stand)
	var r: float = Defs.PLAYER_RADIUS - 2.0
	var low: Vector2i = Grid.cell_at(at - Vector2(r, r))
	var high: Vector2i = Grid.cell_at(at + Vector2(r, r))
	return rect.intersects(Rect2i(low, high - low + Vector2i.ONE))

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
