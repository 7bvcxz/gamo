extends RefCounted

## Reading a run saved before Grid v2 (schema 11) into this one (schema 12).
##
## A v11 file counts in tiles: every cell in it is one tile across, the base and
## the hut are a cell each, and a miner is a cell on a seam. Since Grid v2 a cell
## is half a tile, so each of those is a block of cells now -- and the seams are
## not in the file at all. Ore is regenerated from the seed on load, and the v12
## generator lays its seams on the finer lattice, so a v11 miner's seam is simply
## not where it was.
##
## So this is not a multiplication. It runs in two halves:
##
## `convert` rewrites what can be rewritten without the world: every position
## becomes the top-left cell of the tile it named (props, drops, the case), the
## base and the hut keep their middles where they were, and the machines are
## held back.
##
## `settle` runs once the new world exists, and puts the machines back into it
## one kind at a time -- each old 1x1 machine over its old tile's four cells,
## each belt as a run of cells along the tile's lane, each miner onto a seam in
## its old tile if the new world has one there. Whatever will not fit is taken
## down the way the player takes a machine down: the full cost back in stock.
## Whatever the bigger base or hut now covers moves out of the way. And the run
## is told, in one line, what happened -- a save is somebody's afternoon, and a
## factory quietly rearranged is a factory they cannot trust.
##
## The file itself is never touched: Main copies it aside before any of this.

const FROM := 11
const NONE := Vector2i(9999, 9999)
const STEPS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]

# --- The half that needs no world ------------------------------------------------

## Rewrites a v11 `state` dictionary into a v12 one. Returns
## {"state": the new state, "machines": the old machine rows, "cats": each cat's
## old assignment as a tile, or NONE}. Nothing in the argument is modified.
static func convert(state: Dictionary) -> Dictionary:
	var out: Dictionary = state.duplicate(true)
	var sim: Dictionary = out.get("sim", {})
	# The base's middle is where the old core's middle was: an eight-by-eight
	# anchored at 2T has its centre at the old tile's centre. The hut's six by
	# eight works out to the same anchor for the same reason.
	for pair: Array in [["core_x", "core_y"], ["shelter_x", "shelter_y"], ["food_x", "food_y"]]:
		if sim.has(pair[0]):
			sim[pair[0]] = int(sim[pair[0]]) * Grid.SCALE
			sim[pair[1]] = int(sim[pair[1]]) * Grid.SCALE
	if int(sim.get("kit_x", 9999)) != 9999:
		sim["kit_x"] = int(sim["kit_x"]) * Grid.SCALE
		sim["kit_y"] = int(sim["kit_y"]) * Grid.SCALE
	# Things a tile across, and things lying on a tile: the top-left cell of it.
	for key: String in ["frozen", "debris", "drops", "ground", "thawed"]:
		var rows: Array = []
		for row in sim.get(key, []):
			var copy: Array = (row as Array).duplicate()
			copy[0] = int(copy[0]) * Grid.SCALE
			copy[1] = int(copy[1]) * Grid.SCALE
			rows.append(copy)
		sim[key] = rows
	var shards := PackedInt32Array()
	for value: int in sim.get("shards", PackedInt32Array()):
		shards.append(value * Grid.SCALE)
	sim["shards"] = shards
	# `explored` is in chunks of ground, which did not move; `mined_rocks` is in
	# tiles, which is what rocks have always been counted in.
	var machines: Array = sim.get("machines", [])
	sim["machines"] = []
	var assignments: Array = []
	for row in sim.get("cats", []):
		var cat: Dictionary = row
		assignments.append(Vector2i(int(cat.get("ax", 9999)), int(cat.get("ay", 9999))))
		cat["ax"] = NONE.x
		cat["ay"] = NONE.y
		cat["state"] = Defs.CAT_IDLE
	out["sim"] = sim
	return {"state": out, "machines": machines, "cats": assignments}

# --- The half that needs the world ---------------------------------------------

## Puts the held-back machines into the loaded world, moves what the bigger
## buildings now cover, and returns what happened:
## {"kept": n, "refunded": n, "cut": n, "items": n, "moved": [names]}.
static func settle(sim: Sim, pending: Dictionary) -> Dictionary:
	var report := {"kept": 0, "refunded": 0, "cut": 0, "items": 0, "moved": []}
	if sim.base_placed:
		_make_way(sim, sim.base_rect(), report)
	# The hut and the bin are asked about with themselves lifted: standing, their
	# own cells are structure, and every spot would look blocked by them.
	if sim.shelter_placed:
		sim.shelter_placed = false
		if not sim.shelter_problems(sim.shelter_cell).is_empty():
			var hut: Vector2i = sim.free_anchor_near(sim.core_cell + Defs.SHELTER_CELL,
				Defs.SHELTER_SIZE,
				func(anchor: Vector2i) -> Dictionary: return sim.shelter_problems(anchor))
			if hut != Sim.NONE:
				sim.shelter_cell = hut
				(report["moved"] as Array).append("숙소")
		sim.shelter_placed = true
		_make_way(sim, sim.shelter_rect(), report)
	if sim.food_placed:
		sim.food_placed = false
		if not sim.food_problems(sim.food_cell).is_empty():
			var bin: Vector2i = sim.free_anchor_near(sim.shelter_cell + Defs.FOOD_CELL,
				Defs.FOOD_BIN_SIZE,
				func(anchor: Vector2i) -> Dictionary: return sim.food_problems(anchor))
			if bin != Sim.NONE:
				sim.food_cell = bin
				(report["moved"] as Array).append("사료 상자")
		sim.food_placed = true
		_make_way(sim, sim.food_rect(), report)

	var rows: Array = pending.get("machines", [])
	var by_tile: Dictionary = {}
	for row: Dictionary in rows:
		by_tile[Vector2i(int(row["x"]), int(row["y"]))] = row
	var posts: Dictionary = {}
	# Whole machines first: their footprints are fixed, and belts fill round them.
	for row: Dictionary in rows:
		var type: int = int(row["type"])
		if type == Defs.M_BELT or type == Defs.M_SPLITTER or Defs.machine_mines(type):
			continue
		_place_block(sim, row, report)
	for row: Dictionary in rows:
		if Defs.machine_mines(int(row["type"])):
			var tile := Vector2i(int(row["x"]), int(row["y"]))
			var anchor: Vector2i = _place_post(sim, row, report)
			if anchor != NONE:
				posts[tile] = anchor
	for row: Dictionary in rows:
		var type: int = int(row["type"])
		if type == Defs.M_BELT or type == Defs.M_SPLITTER:
			_place_transport(sim, row, by_tile, report)

	# The cats go back to whatever of their posts survived, and otherwise wait
	# to be carried to a new one -- as every cat without a job does.
	var assignments: Array = pending.get("cats", [])
	for index in mini(assignments.size(), sim.cats.size()):
		var cat: Sim.Cat = sim.cats[index]
		var tile: Vector2i = assignments[index]
		var post: Vector2i = NONE
		if posts.has(tile):
			post = posts[tile]
		elif tile != NONE:
			post = _seam_in(sim, tile, Callable())
		var taken := false
		for other: Sim.Cat in sim.cats:
			if other != cat and other.assigned == post:
				taken = true
		if post != NONE and not taken:
			cat.assigned = post
			cat.state = Defs.CAT_TO_MINER
		else:
			cat.assigned = NONE
			cat.state = Defs.CAT_IDLE
	sim._grid_dirty = true
	return report

## One line for the player, or "" when nothing needed saying.
static func describe(report: Dictionary) -> String:
	var parts: Array[String] = []
	if int(report.get("refunded", 0)) > 0:
		parts.append("설비 %d개는 재료로 돌려받았다" % int(report["refunded"]))
	var moved: Array = report.get("moved", [])
	if not moved.is_empty():
		parts.append("%s 자리를 옮겼다" % ", ".join(PackedStringArray(moved)))
	if parts.is_empty():
		return "새 격자로 옮겼다."
	return "새 격자로 옮기며 " + " · ".join(PackedStringArray(parts)) + "."

# --- Machines -------------------------------------------------------------------

static func _refund(sim: Sim, row: Dictionary, report: Dictionary) -> void:
	var type: int = int(row["type"])
	for item_type: int in sim.cost_of(type):
		sim.stock[item_type] = int(sim.stock.get(item_type, 0)) + int(sim.cost_of(type)[item_type])
	_return_items(sim, row, report)
	report["refunded"] = int(report["refunded"]) + 1

## What was riding on it or waiting in it goes into stock rather than into
## nothing: the run earned those.
static func _return_items(sim: Sim, row: Dictionary, report: Dictionary) -> void:
	for item: Dictionary in row.get("items", []):
		var item_type: int = int(item["type"])
		sim.stock[item_type] = int(sim.stock.get(item_type, 0)) + 1
		report["items"] = int(report["items"]) + 1
	for key in (row.get("buffer", {}) as Dictionary):
		var item_type: int = int(key)
		var count: int = int(row["buffer"][key])
		sim.stock[item_type] = int(sim.stock.get(item_type, 0)) + count
		report["items"] = int(report["items"]) + count
	for key in (row.get("outbox", {}) as Dictionary):
		var item_type: int = int(key)
		var count: int = int(row["outbox"][key])
		sim.stock[item_type] = int(sim.stock.get(item_type, 0)) + count
		report["items"] = int(report["items"]) + count

static func _machine(row: Dictionary, anchor: Vector2i, dir: Vector2i) -> Sim.Machine:
	var machine := Sim.Machine.new()
	machine.type = int(row["type"])
	machine.cell = anchor
	machine.dir = dir
	machine.progress = float(row.get("progress", 0.0))
	machine.buffer = (row.get("buffer", {}) as Dictionary).duplicate(true)
	machine.outbox = (row.get("outbox", {}) as Dictionary).duplicate(true)
	machine.recipe_key = String(row.get("recipe", ""))
	machine.tier = int(row.get("tier", 0))
	return machine

static func _dir(row: Dictionary) -> Vector2i:
	return Vector2i(int(row.get("dx", 1)), int(row.get("dy", 0)))

## A generator, manufacturer or assembler: it was one tile, and is two cells by
## two -- exactly that tile's four cells, anchored at their top-left. Its output
## lands on the lane of the next tile over, where the belts are put back.
static func _place_block(sim: Sim, row: Dictionary, report: Dictionary) -> void:
	var anchor: Vector2i = Vector2i(int(row["x"]), int(row["y"])) * Grid.SCALE
	var dir: Vector2i = _dir(row)
	if sim.footprint_problems(int(row["type"]), anchor, dir).is_empty():
		sim.add_machine(_machine(row, anchor, dir))
		report["kept"] = int(report["kept"]) + 1
	else:
		_refund(sim, row, report)

## A miner, onto a seam of the new world inside its old tile or the ring of
## cells round it -- the place it stood, give or take half a tile -- if its four
## by four fits there. There is usually none: the new generator put its seams on
## a different lattice. Then it comes down, at full refund.
static func _place_post(sim: Sim, row: Dictionary, report: Dictionary) -> Vector2i:
	var type: int = int(row["type"])
	var dir: Vector2i = _dir(row)
	var seam: Vector2i = _seam_in(sim, Vector2i(int(row["x"]), int(row["y"])),
		func(cell: Vector2i) -> bool: return sim.footprint_problems(type, cell, dir).is_empty())
	if seam == NONE:
		_refund(sim, row, report)
		return NONE
	var machine: Sim.Machine = _machine(row, seam, dir)
	machine.progress = 0.0
	sim.add_machine(machine)
	report["kept"] = int(report["kept"]) + 1
	return seam

## The seam nearest an old tile's middle within that tile or one cell round it,
## that `accept` takes (any, when it is not valid).
static func _seam_in(sim: Sim, tile: Vector2i, accept: Callable) -> Vector2i:
	var block := Rect2i(Grid.from_tile(tile) - Vector2i.ONE, Vector2i.ONE * (Grid.SCALE + 2))
	var middle: Vector2 = Grid.tile_centre(tile)
	var best: Vector2i = NONE
	var best_distance: float = 1e20
	for cell: Vector2i in Grid.cells_in(block):
		if not sim.ore.has(cell) or sim.machine_at(cell) != null:
			continue
		if accept.is_valid() and not accept.call(cell):
			continue
		var distance: float = Grid.centre(cell).distance_squared_to(middle)
		if distance < best_distance:
			best_distance = distance
			best = cell
	return best

## A belt or a splitter. Every connection between two old tiles crosses an edge,
## and edges are crossed on each tile's lane -- its top row and left column -- so
## the old tile becomes its top-left cell, plus the cell east of it if something
## goes out or comes in through the east edge, plus the cell south of it for
## the south edge. That keeps every line continuous, corners included.
static func _place_transport(sim: Sim, row: Dictionary, by_tile: Dictionary, report: Dictionary) -> void:
	var tile := Vector2i(int(row["x"]), int(row["y"]))
	var type: int = int(row["type"])
	var dir: Vector2i = _dir(row)
	var outs: Array[Vector2i] = [dir]
	if type == Defs.M_SPLITTER:
		outs = [Vector2i(-dir.y, dir.x), Vector2i(dir.y, -dir.x)]
	var ins: Array[Vector2i] = []
	for side: Vector2i in STEPS:
		if _feeds(by_tile, tile + side, -side):
			ins.append(side)
	var origin: Vector2i = Grid.from_tile(tile)
	var cells: Dictionary = {}
	# The tile's own cell: the belt or the splitter itself, facing its way.
	cells[origin] = dir
	for side: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
		if side in outs:
			cells[origin + side] = side
		elif side in ins:
			cells[origin + side] = -side
	var placed := 0
	for cell: Vector2i in cells:
		var solo: Dictionary = row.duplicate(true)
		solo["items"] = []
		var kind: int = type if cell == origin else Defs.M_BELT
		solo["type"] = kind
		if sim.footprint_problems(kind, cell, cells[cell]).is_empty():
			var machine: Sim.Machine = _machine(solo, cell, cells[cell])
			machine.buffer = {}
			machine.outbox = {}
			sim.add_machine(machine)
			placed += 1
		else:
			report["cut"] = int(report["cut"]) + 1
	if placed == 0:
		_refund(sim, row, report)
	else:
		_return_items(sim, row, report)
		report["kept"] = int(report["kept"]) + 1

## Whether the old machine on `tile` sends things out through its `side`.
static func _feeds(by_tile: Dictionary, tile: Vector2i, side: Vector2i) -> bool:
	if not by_tile.has(tile):
		return false
	var row: Dictionary = by_tile[tile]
	var dir: Vector2i = _dir(row)
	if int(row["type"]) == Defs.M_SPLITTER:
		return side == Vector2i(-dir.y, dir.x) or side == Vector2i(dir.y, -dir.x)
	return side == dir

# --- Making way -----------------------------------------------------------------

## Everything lying where a building that grew now stands moves out of it, to
## the nearest ground that takes it: a block of ice or a wreck a tile across,
## a tool or a kit on the snow. None of it is deleted.
static func _make_way(sim: Sim, rect: Rect2i, report: Dictionary) -> void:
	for props: Dictionary in [sim.frozen_cats, sim.debris]:
		for origin: Vector2i in props.keys():
			if not sim.prop_rect(origin).intersects(rect):
				continue
			var value = props[origin]
			props.erase(origin)
			var spot: Vector2i = sim.free_anchor_near(origin, Defs.PROP_SIZE,
				func(anchor: Vector2i) -> Dictionary: return _prop_problems(sim, anchor, rect))
			if spot != Sim.NONE:
				props[spot] = value
				(report["moved"] as Array).append("얼음" if is_same(props, sim.frozen_cats) else "잔해")
	for items: Dictionary in [sim.drops, sim.ground]:
		for cell: Vector2i in items.keys():
			if not rect.has_point(cell):
				continue
			var value = items[cell]
			var stack: int = int(sim.ground_stack.get(cell, 1))
			items.erase(cell)
			sim.ground_stack.erase(cell)
			var spot: Vector2i = sim.free_anchor_near(cell, Vector2i.ONE,
				func(anchor: Vector2i) -> Dictionary:
					return _prop_problems(sim, anchor, rect, Vector2i.ONE))
			if spot == Sim.NONE:
				continue
			items[spot] = value
			if is_same(items, sim.ground):
				sim.ground_stack[spot] = stack

static func _prop_problems(sim: Sim, anchor: Vector2i, avoid: Rect2i,
		size: Vector2i = Defs.PROP_SIZE) -> Dictionary:
	var out: Dictionary = {}
	for cell: Vector2i in Grid.cells_in(Rect2i(anchor, size)):
		if avoid.has_point(cell) or sim.is_structure(cell) or not sim.in_world(cell) \
				or sim.frozen_key(cell) != Sim.NONE or sim.debris_key(cell) != Sim.NONE \
				or sim.drops.has(cell) or sim.ground.has(cell):
			out[cell] = "막혀 있습니다"
	return out
