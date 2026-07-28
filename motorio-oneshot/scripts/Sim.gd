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

class Machine extends RefCounted:
	var type: int = Defs.M_BELT
	var cell: Vector2i = Vector2i.ZERO
	var dir: Vector2i = Vector2i.RIGHT
	var progress: float = 0.0
	var flash: float = 0.0
	## Belts: [{ "type": int, "t": float }] ordered from the front of the tile.
	var items: Array[Dictionary] = []
	## Furnace input buffer keyed by item type.
	var buffer: Dictionary = {}

var ore: Dictionary[Vector2i, int] = {}
var machines: Dictionary[Vector2i, Machine] = {}
var core_cell := Vector2i.ZERO

var heat: int = Defs.START_HEAT
var total_heat: int = 0
var delivered: Dictionary[int, int] = {}
var warm_radius: float = Defs.WARM_BASE

var _cached_radius := -1.0

func setup(seed_value: int) -> void:
	ore.clear()
	machines.clear()
	heat = Defs.START_HEAT
	total_heat = 0
	delivered = {Defs.ITEM_FROST: 0, Defs.ITEM_EMBER: 0, Defs.ITEM_ALLOY: 0}
	warm_radius = Defs.WARM_BASE
	_cached_radius = -1.0
	var core := Machine.new()
	core.type = Defs.M_CORE
	core.cell = core_cell
	machines[core_cell] = core
	_generate_ore(seed_value)

## Cells kept clear so the guaranteed opening always has a belt route home.
## A single row, not a block: a square patch would put ore directly in front of
## the miner's output and the guaranteed opening would dead-end.
const STARTER_PATCH: Array[Vector2i] = [Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3)]
const STARTER_LANE: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, 2)]

func _generate_ore(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# A guaranteed first patch just south of the core. The opening minute should
	# be about learning the miner-belt-core sentence, not about searching.
	for offset: Vector2i in STARTER_PATCH:
		ore[core_cell + offset] = Defs.ITEM_FROST
	_scatter_ore(rng, Defs.ITEM_FROST, Defs.FROST_RING, 7, 4)
	_scatter_ore(rng, Defs.ITEM_EMBER, Defs.EMBER_RING, 6, 5)
	for offset: Vector2i in STARTER_LANE:
		ore.erase(core_cell + offset)

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

func _ring_distance(cell: Vector2i) -> float:
	return Vector2(cell - core_cell).length()

func is_warm(cell: Vector2i) -> bool:
	return _ring_distance(cell) <= warm_radius

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
	for cell: Vector2i in machines:
		var machine: Machine = machines[cell]
		machine.flash = maxf(0.0, machine.flash - delta)
		var speed: float = 1.0 if is_warm(cell) else 0.45
		match machine.type:
			Defs.M_MINER: _tick_miner(machine, delta * speed)
			Defs.M_BELT: _tick_belt(machine, delta * speed)
			Defs.M_FURNACE: _tick_furnace(machine, delta * speed)
	_refresh_radius()

func _refresh_radius() -> void:
	warm_radius = Defs.warm_radius(total_heat)
	if not is_equal_approx(warm_radius, _cached_radius):
		_cached_radius = warm_radius
		warmth_changed.emit(warm_radius)

func _tick_miner(machine: Machine, delta: float) -> void:
	machine.progress += delta
	if machine.progress < Defs.MINER_PERIOD:
		return
	var item_type: int = ore.get(machine.cell, Defs.ITEM_FROST)
	if _push_into(machine.cell + machine.dir, item_type):
		machine.progress = 0.0
		machine.flash = 0.35
	else:
		# Hold the finished item instead of losing it when the output is blocked.
		machine.progress = Defs.MINER_PERIOD

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
		return
	if _push_into(machine.cell + machine.dir, int(head["type"])):
		machine.items.remove_at(0)

func _tick_furnace(machine: Machine, delta: float) -> void:
	var frost: int = int(machine.buffer.get(Defs.ITEM_FROST, 0))
	var ember: int = int(machine.buffer.get(Defs.ITEM_EMBER, 0))
	if frost < Defs.FROST_COST_ALLOY or ember < Defs.EMBER_COST_ALLOY:
		machine.progress = 0.0
		return
	machine.progress += delta
	if machine.progress < Defs.FURNACE_PERIOD:
		return
	if not _push_into(machine.cell + machine.dir, Defs.ITEM_ALLOY):
		machine.progress = Defs.FURNACE_PERIOD
		return
	machine.buffer[Defs.ITEM_FROST] = frost - Defs.FROST_COST_ALLOY
	machine.buffer[Defs.ITEM_EMBER] = ember - Defs.EMBER_COST_ALLOY
	machine.progress = 0.0
	machine.flash = 0.5

## Returns true when the destination accepted the item.
func _push_into(cell: Vector2i, item_type: int) -> bool:
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
			if item_type == Defs.ITEM_ALLOY:
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
