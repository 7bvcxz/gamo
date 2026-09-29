extends RefCounted

## A bare simulation to lay machines in, for the port, transfer, rotation and
## splitter tests (Factory Interaction Pass 01).
##
## The base is placed, the fire is at its last rung (so nothing out here is
## frozen), every machine is open and the bank holds plenty. The test area is a
## square well east of the fire, cleared of ore, loose items and machines, so a
## test that builds there is not building on whatever this seed scattered.

const AREA := Rect2i(Vector2i(24, -12), Vector2i(28, 28))

static func world(seed: int = 5150) -> Sim:
	var sim := Sim.new()
	sim.setup(seed)
	if not sim.base_placed:
		sim.carried_kit = Defs.KIT_BASE
		sim.place_base(sim.core_cell)
	sim.stones_in = maxi(sim.stones_in, int(Defs.BASE_LEVELS[-1]["stones"]))
	sim._refresh_radius()
	for item_id: int in range(Defs.ITEM_NAMES.size()):
		sim.held_items[item_id] = true
		sim.stock[item_id] = 500
	for type: int in Defs.BUILDABLE:
		sim.unlocked[type] = true
	clear(sim, Rect2i(sim.core_cell + AREA.position, AREA.size))
	return sim

## A cell of the test area, from its top-left corner.
static func at(sim: Sim, local: Vector2i) -> Vector2i:
	return sim.core_cell + AREA.position + local

static func clear(sim: Sim, rect: Rect2i) -> void:
	for cell: Vector2i in Grid.cells_in(rect):
		if sim.has_ore(cell):
			sim.erase_ore_at(cell)
		sim.ground.erase(cell)
		sim.ground_stack.erase(cell)
		if sim.machine_at(cell) != null and sim.machine_at(cell).type != Defs.M_CORE:
			sim.remove_machine(cell)

## Builds through `Sim.build`, the way she builds. Null if it was refused.
static func put(sim: Sim, type: int, cell: Vector2i, dir: Vector2i) -> Sim.Machine:
	if not sim.build(type, cell, dir):
		return null
	return sim.machine_at(cell)

## Runs the simulation for `seconds` in small steps.
static func run(sim: Sim, seconds: float, step: float = 0.05) -> void:
	var t := 0.0
	while t < seconds:
		sim.tick(step)
		t += step

## A generator, full, out of the way, so recipe machines have power.
static func power(sim: Sim) -> void:
	var cell: Vector2i = at(sim, Vector2i(24, 24))
	var generator: Sim.Machine = put(sim, Defs.M_GENERATOR, cell, Vector2i.RIGHT)
	if generator != null:
		generator.buffer[Defs.GENERATOR_FUEL] = 4000
