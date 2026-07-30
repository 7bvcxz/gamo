extends Node
class_name Sim

## Pure simulation: the grid, machines, item flow and economy.
## It owns no rendering and no input, which keeps it testable headlessly and
## lets the view layers stay dumb. Items are plain data rather than physics
## bodies so that a few hundred of them cost almost nothing.

signal heat_gained(amount: int, cell: Vector2i, item_type: int)
signal machine_built(cell: Vector2i, type: int)
signal machine_removed(cell: Vector2i, type: int)
signal build_rejected(reason: String, cell: Vector2i)
signal warmth_changed(radius: float)
signal cat_adopted(total: int)
signal box_collected(carried: int)

## A cat worker. Miners cannot run without one standing at them, so the number
## of cats -- not the amount of heat -- is what gates automation.
class Cat extends RefCounted:
	var pos := Vector2.ZERO
	var state: int = Defs.CAT_IDLE
	var assigned := Vector2i(9999, 9999)   ## the miner cell this cat works
	var hunger: float = 1.0
	var eat_timer: float = 0.0

	func has_job() -> bool:
		return assigned != Vector2i(9999, 9999)

class Machine extends RefCounted:
	var type: int = Defs.M_BELT
	var cell: Vector2i = Vector2i.ZERO
	var dir: Vector2i = Vector2i.RIGHT
	var progress: float = 0.0
	var flash: float = 0.0
	## True when this machine has finished work it cannot hand on. Surfacing it is
	## the only way a player can tell a mis-aimed belt line from a working one.
	var stalled: bool = false
	## Belts: [{ "type": int, "t": float }] ordered from the front of the tile.
	var items: Array[Dictionary] = []
	## Furnace input buffer keyed by item type.
	var buffer: Dictionary = {}
	## Miners only run while a cat is standing here.
	var operated: bool = false

var ore: Dictionary[Vector2i, int] = {}
var machines: Dictionary[Vector2i, Machine] = {}
var core_cell := Vector2i.ZERO

var cats: Array[Cat] = []
var cat_boxes: Dictionary[Vector2i, bool] = {}
var carried_boxes: int = 0
## The cat currently in the player's arms. Cats are placed on machines by hand;
## there is no automatic assignment, so the player decides who works where.
var carried_cat: Cat = null
var food: int = Defs.FOOD_START
var shelter_cell := Vector2i.ZERO
var food_cell := Vector2i.ZERO

var heat: int = Defs.START_HEAT
var total_heat: int = 0
var delivered: Dictionary[int, int] = {}
var warm_radius: float = Defs.WARM_BASE

var _cached_radius := -1.0

## --- Persistence ----------------------------------------------------------
## Terrain is not stored: it is regenerated from the seed, so the save only has
## to carry what the player changed. That keeps the file small and means a
## world-generation tweak cannot corrupt an existing save's geometry.
func to_save() -> Dictionary:
	var machine_rows: Array = []
	for cell: Vector2i in machines:
		var machine: Machine = machines[cell]
		if machine.type == Defs.M_CORE:
			continue
		machine_rows.append({
			"x": cell.x, "y": cell.y, "type": machine.type,
			"dx": machine.dir.x, "dy": machine.dir.y,
			"progress": machine.progress, "items": machine.items.duplicate(true),
			"buffer": machine.buffer.duplicate(true),
		})
	var cat_rows: Array = []
	for cat: Cat in cats:
		cat_rows.append({
			"px": cat.pos.x, "py": cat.pos.y, "state": cat.state,
			"ax": cat.assigned.x, "ay": cat.assigned.y,
			"hunger": cat.hunger, "eat": cat.eat_timer,
		})
	var box_rows: Array = []
	for cell: Vector2i in cat_boxes:
		box_rows.append([cell.x, cell.y])
	var delivered_rows: Dictionary = {}
	for key: int in delivered:
		delivered_rows[str(key)] = int(delivered[key])
	return {
		"heat": heat, "total_heat": total_heat, "delivered": delivered_rows,
		"machines": machine_rows, "cats": cat_rows, "boxes": box_rows,
		"carried": carried_boxes, "food": food,
	}

func from_save(data: Dictionary) -> void:
	heat = int(data.get("heat", Defs.START_HEAT))
	total_heat = int(data.get("total_heat", 0))
	var delivered_rows: Dictionary = data.get("delivered", {})
	for key: String in delivered_rows:
		delivered[int(key)] = int(delivered_rows[key])
	carried_boxes = int(data.get("carried", 0))
	food = int(data.get("food", Defs.FOOD_START))

	for row: Dictionary in data.get("machines", []):
		var cell := Vector2i(int(row["x"]), int(row["y"]))
		var machine := Machine.new()
		machine.type = int(row["type"])
		machine.cell = cell
		machine.dir = Vector2i(int(row["dx"]), int(row["dy"]))
		machine.progress = float(row.get("progress", 0.0))
		machine.buffer = (row.get("buffer", {}) as Dictionary).duplicate(true)
		for item: Dictionary in row.get("items", []):
			machine.items.append({"type": int(item["type"]), "t": float(item["t"])})
		machines[cell] = machine

	cat_boxes.clear()
	for row: Array in data.get("boxes", []):
		cat_boxes[Vector2i(int(row[0]), int(row[1]))] = true

	cats.clear()
	for row: Dictionary in data.get("cats", []):
		var cat := Cat.new()
		cat.pos = Vector2(float(row["px"]), float(row["py"]))
		cat.state = int(row.get("state", Defs.CAT_IDLE))
		cat.assigned = Vector2i(int(row["ax"]), int(row["ay"]))
		cat.hunger = float(row.get("hunger", 1.0))
		cat.eat_timer = float(row.get("eat", 0.0))
		cats.append(cat)
	_refresh_radius()

func setup(seed_value: int) -> void:
	ore.clear()
	machines.clear()
	heat = Defs.START_HEAT
	total_heat = 0
	delivered = {Defs.ITEM_FROST: 0, Defs.ITEM_COPPER: 0, Defs.ITEM_IRON: 0}
	warm_radius = Defs.WARM_BASE
	# Seed the cache so the opening frame does not announce a radius that has
	# not actually changed yet.
	_cached_radius = warm_radius
	var core := Machine.new()
	core.type = Defs.M_CORE
	core.cell = core_cell
	machines[core_cell] = core
	cats.clear()
	cat_boxes.clear()
	carried_boxes = 0
	carried_cat = null
	food = Defs.FOOD_START
	shelter_cell = core_cell + Vector2i(Defs.SHELTER_OFFSET.round())
	food_cell = core_cell + Vector2i(Defs.FOOD_OFFSET.round())
	_generate_ore(seed_value)
	_generate_cat_boxes(seed_value)

## Cells kept clear so the guaranteed opening always has a belt route home.
## A single row, not a block: a square patch would put ore directly in front of
## the miner's output and the guaranteed opening would dead-end.
const STARTER_PATCH: Array[Vector2i] = [Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3)]
const STARTER_LANE: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, 2)]
## A guaranteed ember seam due north, just outside the opening warm radius, with
## a clear column back to the core. Without it the alloy recipe -- the design's
## payoff -- depends on where the scatter happened to drop ember, which made the
## mid-game beat unreliable and left the headline mechanic unreachable in a
## five-minute run.
const STARTER_COPPER: Array[Vector2i] = [Vector2i(1, -9), Vector2i(0, -9), Vector2i(2, -9)]

func _generate_ore(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# A guaranteed first patch just south of the core. The opening minute should
	# be about learning the miner-belt-core sentence, not about searching.
	for offset: Vector2i in STARTER_PATCH:
		ore[core_cell + offset] = Defs.ITEM_FROST
	# Ore is deliberately scarce: a fifth of the earlier density. Finding a seam
	# should be an event, and a single miner should be worth protecting.
	_scatter_ore(rng, Defs.ITEM_FROST, Defs.FROST_RING, 3, 2)
	_scatter_ore(rng, Defs.ITEM_COPPER, Defs.COPPER_RING, 3, 2)
	for offset: Vector2i in STARTER_COPPER:
		ore[core_cell + offset] = Defs.ITEM_COPPER
	for offset: Vector2i in STARTER_LANE:
		ore.erase(core_cell + offset)
	# Two clear columns home: one from the frost row, one from the ember seam.
	for step in range(1, 9):
		ore.erase(core_cell + Vector2i(1, -step))
	for step in range(1, 3):
		ore.erase(core_cell + Vector2i(1, step))

## Ore arrives in patches so the player reads them as destinations rather than
## noise, and so a single miner placement decision matters.
func _scatter_ore(rng: RandomNumberGenerator, item_type: int, ring: Vector2, patches: int, size: int) -> void:
	for index in patches:
		var angle: float = TAU * (float(index) + rng.randf() * 0.6) / float(patches)
		var radius: float = rng.randf_range(ring.x, ring.y)
		var origin := core_cell + Vector2i(roundi(cos(angle) * radius), roundi(sin(angle) * radius))
		var placed := 0
		var cursor := origin
		var attempts := 0
		while placed < size and attempts < size * 12:
			attempts += 1
			if not ore.has(cursor) and cursor != core_cell and _ring_distance(cursor) >= ring.x - 1.0:
				ore[cursor] = item_type
				placed += 1
			cursor = origin + Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1)) * (1 + placed / 3)

## Crates are strewn across the map at roughly one per hundred tiles, plus a
## guaranteed three inside the opening warm radius so the first cat is always
## reachable. Walking further is what buys more workers.
func _generate_cat_boxes(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 7717
	for index in Defs.STARTER_CAT_BOXES:
		var angle: float = TAU * float(index) / float(Defs.STARTER_CAT_BOXES) + 0.6
		var radius: float = Defs.WARM_BASE - 2.0
		var cell := core_cell + Vector2i(roundi(cos(angle) * radius), roundi(sin(angle) * radius))
		if not ore.has(cell) and cell != core_cell:
			cat_boxes[cell] = true
	var reach: float = Defs.WARM_MAX + 8.0
	var target: int = int((PI * reach * reach) / Defs.CAT_BOX_PER_TILES)
	var attempts := 0
	while cat_boxes.size() < target + Defs.STARTER_CAT_BOXES and attempts < target * 30:
		attempts += 1
		var angle: float = rng.randf() * TAU
		var radius: float = sqrt(rng.randf()) * reach
		var cell := core_cell + Vector2i(roundi(cos(angle) * radius), roundi(sin(angle) * radius))
		if cat_boxes.has(cell) or ore.has(cell) or machines.has(cell):
			continue
		if _ring_distance(cell) < Defs.WARM_BASE - 1.0:
			continue
		cat_boxes[cell] = true

func _ring_distance(cell: Vector2i) -> float:
	return Vector2(cell - core_cell).length()

func is_warm(cell: Vector2i) -> bool:
	return _ring_distance(cell) <= warm_radius

## Walking over a crate picks it up; three carried crates become a cat when the
## player reaches the shelter.
func collect_box_at(cell: Vector2i) -> bool:
	if not cat_boxes.has(cell):
		return false
	cat_boxes.erase(cell)
	carried_boxes += 1
	box_collected.emit(carried_boxes)
	return true

func adopt_cats() -> int:
	var adopted: int = carried_boxes / Defs.BOXES_PER_CAT
	if adopted <= 0:
		return 0
	carried_boxes -= adopted * Defs.BOXES_PER_CAT
	for index in adopted:
		var cat := Cat.new()
		cat.pos = Vector2(shelter_cell) * float(Defs.TILE) + Vector2.ONE * Defs.TILE * 0.5
		cats.append(cat)
	cat_adopted.emit(cats.size())
	return adopted

## Picking a cat up takes it off its machine; the machine stops immediately.
func pick_up_cat(cell: Vector2i) -> bool:
	if carried_cat != null:
		return false
	var reach: float = float(Defs.TILE) * 0.9
	var centre: Vector2 = cell_centre(cell)
	var best: Cat = null
	var best_distance: float = reach
	for cat: Cat in cats:
		var distance: float = cat.pos.distance_to(centre)
		if distance <= best_distance:
			best = cat
			best_distance = distance
	if best == null:
		return false
	if best.has_job() and machines.has(best.assigned):
		machines[best.assigned].operated = false
	best.assigned = Vector2i(9999, 9999)
	best.state = Defs.CAT_IDLE
	carried_cat = best
	return true

## Putting a cat down on a miner assigns it to that machine for good; it will
## return there every morning and after every meal.
func place_cat(cell: Vector2i) -> bool:
	if carried_cat == null:
		return false
	var machine: Machine = machines.get(cell, null)
	if machine == null or machine.type != Defs.M_MINER:
		return false
	for cat: Cat in cats:
		if cat != carried_cat and cat.assigned == cell:
			return false
	carried_cat.assigned = cell
	carried_cat.pos = cell_centre(cell)
	carried_cat.state = Defs.CAT_WORKING
	carried_cat = null
	return true

## Dropping a cat anywhere else simply leaves it standing there.
func drop_cat(at: Vector2) -> bool:
	if carried_cat == null:
		return false
	carried_cat.pos = at
	carried_cat.state = Defs.CAT_IDLE
	carried_cat = null
	return true

func idle_miner_cells() -> Array[Vector2i]:
	var free: Array[Vector2i] = []
	for cell: Vector2i in machines:
		if machines[cell].type != Defs.M_MINER:
			continue
		var taken := false
		for cat: Cat in cats:
			if cat.assigned == cell:
				taken = true
				break
		if not taken:
			free.append(cell)
	return free

## Each morning every cat walks back to the machine the player assigned it to.
## Cats without an assignment simply wait at the shelter to be carried somewhere:
## the game never picks a job for them.
func dispatch_cats() -> void:
	for cat: Cat in cats:
		if cat == carried_cat:
			continue
		if cat.has_job() and machines.has(cat.assigned):
			cat.state = Defs.CAT_TO_MINER
			continue
		cat.assigned = Vector2i(9999, 9999)
		cat.state = Defs.CAT_IDLE
		cat.pos = cell_centre(shelter_cell)

func machine_at(cell: Vector2i) -> Machine:
	return machines.get(cell, null)

func can_build(type: int, cell: Vector2i) -> String:
	if machines.has(cell):
		return "이미 설비가 있습니다"
	if heat < Defs.MACHINE_COSTS[type]:
		return "열이 부족합니다"
	if type == Defs.M_MINER and not ore.has(cell):
		return "광맥 위에만 설치할 수 있습니다"
	if type != Defs.M_MINER and ore.has(cell):
		return "광맥 위에는 설치할 수 없습니다"
	return ""

func build(type: int, cell: Vector2i, dir: Vector2i) -> bool:
	var reason := can_build(type, cell)
	if reason != "":
		build_rejected.emit(reason, cell)
		return false
	var machine := Machine.new()
	machine.type = type
	machine.cell = cell
	machine.dir = dir
	machine.flash = 0.45
	machines[cell] = machine
	heat -= Defs.MACHINE_COSTS[type]
	machine_built.emit(cell, type)
	return true

func demolish(cell: Vector2i) -> bool:
	var machine: Machine = machines.get(cell, null)
	if machine == null or machine.type == Defs.M_CORE:
		return false
	machines.erase(cell)
	# Refund most of the cost so experimenting with layouts stays cheap.
	heat += int(round(float(Defs.MACHINE_COSTS[machine.type]) * 0.75))
	machine_removed.emit(cell, machine.type)
	return true

func tick(delta: float) -> void:
	_tick_cats(delta)
	for cell: Vector2i in machines:
		var machine: Machine = machines[cell]
		machine.flash = maxf(0.0, machine.flash - delta)
		var speed: float = 1.0 if is_warm(cell) else 0.45
		if machine.type == Defs.M_MINER:
			speed *= _operator_rate(cell)
		match machine.type:
			Defs.M_MINER: _tick_miner(machine, delta * speed)
			Defs.M_BELT: _tick_belt(machine, delta * speed)
			Defs.M_FURNACE: _tick_furnace(machine, delta * speed)
	_refresh_radius()

func cell_centre(cell: Vector2i) -> Vector2:
	return Vector2(cell) * float(Defs.TILE) + Vector2.ONE * Defs.TILE * 0.5

## Work rate contributed by whichever cat is standing at this miner. Zero means
## nobody is home; a starving cat still works, at a third of the pace.
func _operator_rate(cell: Vector2i) -> float:
	for cat: Cat in cats:
		if cat.assigned == cell and cat.state == Defs.CAT_WORKING:
			return 1.0 if cat.hunger > 0.0 else Defs.HUNGER_STARVED_RATE
	return 0.0

func _tick_cats(delta: float) -> void:
	for cell: Vector2i in machines:
		if machines[cell].type == Defs.M_MINER:
			machines[cell].operated = false
	for cat: Cat in cats:
		match cat.state:
			Defs.CAT_TO_MINER: _cat_walk_to_miner(cat, delta)
			Defs.CAT_WORKING: _cat_work(cat, delta)
			Defs.CAT_TO_FOOD: _cat_walk_to_food(cat, delta)
			Defs.CAT_EATING: _cat_eat(cat, delta)

func _step_toward(cat: Cat, goal: Vector2, delta: float) -> bool:
	var to_goal: Vector2 = goal - cat.pos
	var step: float = Defs.CAT_SPEED * delta
	if to_goal.length() <= maxf(step, Defs.CAT_ARRIVE):
		cat.pos = goal
		return true
	cat.pos += to_goal.normalized() * step
	return false

func _cat_walk_to_miner(cat: Cat, delta: float) -> void:
	if not cat.has_job() or not machines.has(cat.assigned):
		cat.state = Defs.CAT_IDLE
		return
	if _step_toward(cat, cell_centre(cat.assigned), delta):
		cat.state = Defs.CAT_WORKING

func _cat_work(cat: Cat, delta: float) -> void:
	if not cat.has_job() or not machines.has(cat.assigned):
		cat.state = Defs.CAT_IDLE
		return
	machines[cat.assigned].operated = true
	cat.hunger = maxf(0.0, cat.hunger - Defs.HUNGER_PER_SECOND * delta)
	if cat.hunger <= 0.0 and food > 0:
		cat.state = Defs.CAT_TO_FOOD

func _cat_walk_to_food(cat: Cat, delta: float) -> void:
	if _step_toward(cat, cell_centre(food_cell), delta):
		cat.state = Defs.CAT_EATING
		cat.eat_timer = 0.0

## Eating is slow on purpose: one unit every five seconds, a third of a belly
## each. A hungry workforce is a real interruption, not a formality.
func _cat_eat(cat: Cat, delta: float) -> void:
	if food <= 0:
		cat.state = Defs.CAT_TO_MINER
		return
	cat.eat_timer += delta
	while cat.eat_timer >= Defs.FOOD_SECONDS_PER_UNIT and food > 0 and cat.hunger < 1.0:
		cat.eat_timer -= Defs.FOOD_SECONDS_PER_UNIT
		food -= 1
		cat.hunger = minf(1.0, cat.hunger + Defs.FOOD_HUNGER_PER_UNIT)
	if cat.hunger >= 1.0:
		cat.state = Defs.CAT_TO_MINER

func _refresh_radius() -> void:
	warm_radius = Defs.warm_radius(total_heat)
	if not is_equal_approx(warm_radius, _cached_radius):
		_cached_radius = warm_radius
		warmth_changed.emit(warm_radius)

func _tick_miner(machine: Machine, delta: float) -> void:
	# A miner is inert without a cat standing at it. This is the whole point of
	# the worker system: heat buys the machine, cats buy the output.
	if not machine.operated:
		machine.stalled = false
		return
	machine.progress += delta
	if machine.progress < Defs.MINER_PERIOD:
		return
	var item_type: int = ore.get(machine.cell, Defs.ITEM_FROST)
	if _push_into(machine.cell + machine.dir, item_type, machine.cell):
		machine.progress = 0.0
		machine.flash = 0.35
		machine.stalled = false
	else:
		# Hold the finished item instead of losing it when the output is blocked.
		machine.progress = Defs.MINER_PERIOD
		machine.stalled = true

func _tick_belt(machine: Machine, delta: float) -> void:
	var step: float = Defs.BELT_SPEED * delta
	for index in range(machine.items.size()):
		var item: Dictionary = machine.items[index]
		var limit: float = 1.0
		if index > 0:
			limit = float(machine.items[index - 1]["t"]) - 0.34
		item["t"] = minf(float(item["t"]) + step, limit)
		machine.items[index] = item
	if machine.items.is_empty():
		return
	var head: Dictionary = machine.items[0]
	if float(head["t"]) < 1.0:
		machine.stalled = false
		return
	if _push_into(machine.cell + machine.dir, int(head["type"]), machine.cell):
		machine.items.remove_at(0)
		machine.stalled = false
	else:
		machine.stalled = machine.items.size() >= Defs.BELT_CAPACITY

func _tick_furnace(machine: Machine, delta: float) -> void:
	var frost: int = int(machine.buffer.get(Defs.ITEM_FROST, 0))
	var ember: int = int(machine.buffer.get(Defs.ITEM_COPPER, 0))
	if frost < Defs.FROST_COST_IRON or ember < Defs.COPPER_COST_IRON:
		machine.progress = 0.0
		return
	machine.progress += delta
	if machine.progress < Defs.FURNACE_PERIOD:
		return
	if not _push_into(machine.cell + machine.dir, Defs.ITEM_IRON, machine.cell):
		machine.progress = Defs.FURNACE_PERIOD
		machine.stalled = true
		return
	machine.stalled = false
	machine.buffer[Defs.ITEM_FROST] = frost - Defs.FROST_COST_IRON
	machine.buffer[Defs.ITEM_COPPER] = ember - Defs.COPPER_COST_IRON
	machine.progress = 0.0
	machine.flash = 0.5

## Returns true when the destination accepted the item. `from` is the cell the
## item is arriving from, which is what lets a machine refuse a face.
func _push_into(cell: Vector2i, item_type: int, from: Vector2i = Vector2i(9999, 9999)) -> bool:
	var target: Machine = machines.get(cell, null)
	if target == null:
		return false
	match target.type:
		Defs.M_CORE:
			_deliver(item_type, cell)
			return true
		Defs.M_BELT:
			if target.items.size() >= Defs.BELT_CAPACITY:
				return false
			var tail_ok: bool = target.items.is_empty() or float(target.items[-1]["t"]) > 0.34
			if not tail_ok:
				return false
			target.items.append({"type": item_type, "t": 0.0})
			return true
		Defs.M_FURNACE:
			if item_type == Defs.ITEM_IRON:
				return false
			# Every face except the output takes ore. Feeding the mouth the
			# furnace pours out of would let a line quietly eat its own product.
			if from == target.cell + target.dir:
				return false
			var held: int = int(target.buffer.get(item_type, 0))
			if held >= 4:
				return false
			target.buffer[item_type] = held + 1
			target.flash = 0.25
			return true
	return false

func _deliver(item_type: int, cell: Vector2i) -> void:
	var value: int = Defs.ITEM_VALUES[item_type]
	heat += value
	total_heat += value
	delivered[item_type] = int(delivered.get(item_type, 0)) + 1
	var core: Machine = machines.get(core_cell, null)
	if core != null:
		core.flash = 0.4
	heat_gained.emit(value, cell, item_type)

func spend_rescue() -> int:
	var lost: int = int(round(float(heat) * Defs.RESCUE_PENALTY))
	heat -= lost
	return lost

func machine_count(type: int) -> int:
	var count := 0
	for cell: Vector2i in machines:
		if machines[cell].type == type:
			count += 1
	return count

func items_in_transit() -> int:
	var count := 0
	for cell: Vector2i in machines:
		count += machines[cell].items.size()
	return count
