class_name LandSystem
extends SimSystem

## Buying land: one 1x1 cell of sea at a time, sharing an edge with the island.
##
## The price climbs with every cell bought (balance.land) so expansion is a
## decision, not a reflex. Purchase is all-or-nothing: the cell must be
## edge-adjacent (the island stays one piece) and affordable, and only then is
## the money taken and the land raised. Any shape is allowed; `suggested()`
## names the cells that would grow the island towards the next fuller
## rectangle (2x2 -> 2x3 -> 3x3 ...) for the preview to point at, nothing more.

## Cells bought so far, in order: [x, y, cost, day].
var purchases: Array = []


func _init() -> void:
	key = &"land"


func handled_commands() -> PackedStringArray:
	return PackedStringArray(["land.buy"])


func on_new_game() -> void:
	purchases.clear()


func purchased_count() -> int:
	return purchases.size()


## Price of the next cell.
func next_cost() -> int:
	return cost_of(purchases.size())


func cost_of(k: int) -> int:
	var base := sim.data.get_float("balance", "land.base", 50.0)
	var growth := sim.data.get_float("balance", "land.growth", 1.3)
	var step := maxi(sim.data.get_int("balance", "land.round_to", 5), 1)
	return int(ceil(base * pow(growth, k) / step)) * step


func candidates() -> Array[Vector2i]:
	return (sim.system(&"world") as WorldSystem).frontier()


## Candidates that keep the island closest to a square: cells inside the
## smallest rectangle one size up from the current bounds, filling the shorter
## side first.
func suggested() -> Array[Vector2i]:
	var world: WorldSystem = sim.system(&"world")
	var b := world.bounds()
	var grow := Rect2i(b.position, b.size + (Vector2i(1, 0) if b.size.x <= b.size.y else Vector2i(0, 1)))
	var out: Array[Vector2i] = []
	for c: Vector2i in world.frontier():
		if b.has_point(c) or grow.has_point(c):
			out.append(c)
	return out


func execute(command: Dictionary) -> Dictionary:
	if String(command.get("type", "")) != "land.buy":
		return SimResult.fail("err.unknown_command")
	return buy(Cmd.vec2i(command, "cell"))


func buy(cell: Vector2i) -> Dictionary:
	var world: WorldSystem = sim.system(&"world")
	var economy: EconomySystem = sim.system(&"economy")
	if world.is_owned(cell):
		return SimResult.fail("err.owned")
	if not world.is_purchasable(cell):
		return SimResult.fail("err.not_adjacent")
	var cost := next_cost()
	if not economy.can_afford(cost):
		return SimResult.fail("err.not_enough_money", {"cost": cost, "money": economy.money})
	economy.spend(cost, "land")
	world.add_land(cell)
	purchases.append([cell.x, cell.y, cost, sim.clock.day_number()])
	sim.bus.emit(&"land_bought", {"cell": [cell.x, cell.y], "cost": cost, "next_cost": next_cost()})
	return SimResult.ok({"cost": cost, "next_cost": next_cost()})


func save_state() -> Dictionary:
	return {"purchases": purchases.duplicate(true)}


func load_state(state: Dictionary) -> void:
	purchases.clear()
	for p: Array in state.get("purchases", []):
		purchases.append([int(p[0]), int(p[1]), int(p[2]), int(p[3])])
