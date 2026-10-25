class_name InventorySystem
extends SimSystem

## The island's store: how many of each item it holds. Building costs take
## items from here, production puts them here, and (Step 15) the day's sale
## empties crops from here into money. Counts are whole numbers; partial
## production accumulates elsewhere and only whole items land in the store.

var items: Dictionary = {}


func _init() -> void:
	key = &"inventory"


func on_new_game() -> void:
	items.clear()


func count(item: String) -> int:
	return int(items.get(item, 0))


func has_all(wanted: Dictionary) -> bool:
	for item: String in wanted:
		if count(item) < int(wanted[item]):
			return false
	return true


## What is missing from `wanted`: item -> shortfall.
func shortfall(wanted: Dictionary) -> Dictionary:
	var out := {}
	for item: String in wanted:
		var short := int(wanted[item]) - count(item)
		if short > 0:
			out[item] = short
	return out


func add(item: String, amount: int, reason: String = "") -> int:
	if amount <= 0:
		return 0
	items[item] = count(item) + amount
	sim.bus.emit(&"inventory_changed", {"item": item, "count": items[item], "delta": amount, "reason": reason})
	return amount


## Takes all of `wanted` or nothing.
func take_all(wanted: Dictionary, reason: String = "") -> bool:
	if not has_all(wanted):
		return false
	for item: String in wanted:
		var n := int(wanted[item])
		if n <= 0:
			continue
		items[item] = count(item) - n
		sim.bus.emit(&"inventory_changed", {"item": item, "count": items[item], "delta": -n, "reason": reason})
	return true


func save_state() -> Dictionary:
	var out := {}
	var keys: Array = items.keys()
	keys.sort()
	for k: String in keys:
		if int(items[k]) != 0:
			out[k] = int(items[k])
	return {"items": out}


func load_state(state: Dictionary) -> void:
	items.clear()
	var saved: Dictionary = state.get("items", {})
	for k: String in saved:
		items[k] = int(saved[k])
