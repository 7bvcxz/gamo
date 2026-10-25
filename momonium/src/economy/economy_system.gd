class_name EconomySystem
extends SimSystem

## Money. Whole dollars as an int: amounts are what the player reads, costs and
## prices are integers in the data, and an int never drifts.

var money: int = 0


func _init() -> void:
	key = &"economy"


func on_new_game() -> void:
	money = sim.data.get_int("balance", "start.money")


func can_afford(amount: int) -> bool:
	return amount <= money


## Takes `amount` if there is enough. Returns whether it did.
func spend(amount: int, reason: String) -> bool:
	if amount < 0 or amount > money:
		return false
	money -= amount
	sim.bus.emit(&"money_changed", {"money": money, "delta": -amount, "reason": reason})
	return true


func earn(amount: int, reason: String) -> void:
	if amount <= 0:
		return
	money += amount
	sim.bus.emit(&"money_changed", {"money": money, "delta": amount, "reason": reason})


func save_state() -> Dictionary:
	return {"money": money}


func load_state(state: Dictionary) -> void:
	money = int(state.get("money", 0))
