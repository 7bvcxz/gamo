class_name InventorySystem
extends SimSystem

## The island's store: how many of each item it holds, up to each item's
## stack limit (items.json). Building costs take items from here, production
## puts them here (crops and other goods sold at once never land here).
##
## Nothing is created or destroyed silently: `room_for` lets producers check
## before they start, and `add` reports what actually fitted.

var items: Dictionary = {}
## Since the game began: item -> how many were produced into the store.
var produced: Dictionary = {}


func _init() -> void:
	key = &"inventory"


func on_new_game() -> void:
	items.clear()
	produced.clear()


func count(item: String) -> int:
	return int(items.get(item, 0))


func capacity(item: String) -> int:
	return int(sim.data.item(item).get("stack", 999999))


func room_for(item: String) -> int:
	return maxi(capacity(item) - count(item), 0)


## Whether every item of `wanted` fits.
func fits(wanted: Dictionary) -> bool:
	for item: String in wanted:
		if room_for(item) < int(wanted[item]):
			return false
	return true


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


## Adds up to the free room and returns how many were stored.
func add(item: String, amount: int, reason: String = "") -> int:
	var stored := mini(maxi(amount, 0), room_for(item))
	if stored <= 0:
		return 0
	items[item] = count(item) + stored
	if reason.begins_with("yield"):
		produced[item] = int(produced.get(item, 0)) + stored
	sim.bus.emit(&"inventory_changed", {"item": item, "count": items[item], "delta": stored, "reason": reason})
	return stored


## Counts `amount` of `item` as made without storing it (sold the moment it
## was made): the "made" totals stay true when crops never reach the store.
func count_made(item: String, amount: int) -> void:
	if amount > 0:
		produced[item] = int(produced.get(item, 0)) + amount


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


## Every item of a kind ("crop", ...) with a positive count, sorted.
func of_kind(kind: String) -> Array[String]:
	var out: Array[String] = []
	var keys: Array = items.keys()
	keys.sort()
	for k: String in keys:
		if count(k) > 0 and String(sim.data.item(k).get("kind", "")) == kind:
			out.append(k)
	return out


func save_state() -> Dictionary:
	var out := {}
	var keys: Array = items.keys()
	keys.sort()
	for k: String in keys:
		if int(items[k]) != 0:
			out[k] = int(items[k])
	var made := {}
	for k: String in produced:
		made[k] = int(produced[k])
	return {"items": out, "produced": made}


func load_state(state: Dictionary) -> void:
	items.clear()
	var saved: Dictionary = state.get("items", {})
	for k: String in saved:
		items[k] = int(saved[k])
	produced.clear()
	var made: Dictionary = state.get("produced", {})
	for k: String in made:
		produced[k] = int(made[k])
