class_name EconomySystem
extends SimSystem

## Money, and where it came from and went.
##
## Whole dollars as an int: amounts are what the player reads, prices and
## costs are integers in the data, and an int never drifts. Every change is
## booked under a reason (sale, build:farm, land, refund, ...) in today's
## ledger; when a day ends its ledger closes into `history` (newest last),
## which the status and analytics screens read instead of keeping their own
## counters.
##
## At each day boundary the store's crops are sold at their data price -- what
## was harvested today is money tomorrow.

var money: int = 0
## Today's bookings: category -> signed amount.
var today: Dictionary = {}
var today_open: int = 0
## Closed days: {day, open, close, income, expense, by: {category: amount}}.
var history: Array = []
## Since the game began: category -> signed amount (history keeps 30 days).
var lifetime: Dictionary = {}


func _init() -> void:
	key = &"economy"


func on_new_game() -> void:
	money = sim.data.get_int("balance", "start.money")
	today = {}
	today_open = money
	history = []
	lifetime = {}


func can_afford(amount: int) -> bool:
	return amount <= money


## Takes `amount` if there is enough. Returns whether it did.
func spend(amount: int, reason: String) -> bool:
	if amount < 0 or amount > money:
		return false
	if amount == 0:
		return true
	money -= amount
	_book(reason, -amount)
	sim.bus.emit(&"money_changed", {"money": money, "delta": -amount, "reason": reason})
	return true


func earn(amount: int, reason: String) -> void:
	if amount <= 0:
		return
	money += amount
	_book(reason, amount)
	sim.bus.emit(&"money_changed", {"money": money, "delta": amount, "reason": reason})


func _book(reason: String, amount: int) -> void:
	var category := reason.split(":")[0]
	today[category] = int(today.get(category, 0)) + amount
	lifetime[category] = int(lifetime.get(category, 0)) + amount


func lifetime_income() -> int:
	var total := 0
	for k: String in lifetime:
		total += maxi(int(lifetime[k]), 0)
	return total


func lifetime_expense() -> int:
	var total := 0
	for k: String in lifetime:
		total += maxi(-int(lifetime[k]), 0)
	return total


## Value of the crops waiting in the store at today's prices.
func pending_sale() -> int:
	var inv: InventorySystem = sim.system(&"inventory")
	var total := 0
	for item: String in inv.of_kind("crop"):
		total += inv.count(item) * int(sim.data.item(item).get("price", 0))
	return total


func on_day_started(day: int) -> void:
	_sell_crops(day)
	_close_day(day - 1)


func _sell_crops(day: int) -> void:
	var inv: InventorySystem = sim.system(&"inventory")
	var sold := {}
	var total := 0
	for item: String in inv.of_kind("crop"):
		if String(sim.data.item(item).get("sell", "")) != "daily":
			continue
		var n := inv.count(item)
		var price := int(sim.data.item(item).get("price", 0))
		if n <= 0 or price <= 0:
			continue
		inv.take_all({item: n}, "sale")
		sold[item] = n
		total += n * price
	if total > 0:
		earn(total, "sale")
		sim.bus.emit(&"sold", {"day": day, "items": sold, "money": total})


func _close_day(day: int) -> void:
	var income := 0
	var expense := 0
	for k: String in today:
		var v := int(today[k])
		if v > 0:
			income += v
		else:
			expense -= v
	# The boundary's sale is booked before this closes, so a day's income
	# includes the crops it harvested: "Day 3 earned $10".
	history.append({"day": day, "open": today_open, "close": money,
		"income": income, "expense": expense, "by": today.duplicate()})
	var keep := sim.data.get_int("balance", "economy.history_days", 30)
	while history.size() > keep:
		history.pop_front()
	today = {}
	today_open = money


## Income of the last closed day (for the HUD's one line of production).
func last_day_income() -> int:
	return int(history[-1]["income"]) if not history.is_empty() else 0


func save_state() -> Dictionary:
	return {"money": money, "today": today.duplicate(), "today_open": today_open, "history": history.duplicate(true), "lifetime": lifetime.duplicate()}


func load_state(state: Dictionary) -> void:
	money = int(state.get("money", 0))
	today = {}
	var t: Dictionary = state.get("today", {})
	for k: String in t:
		today[k] = int(t[k])
	today_open = int(state.get("today_open", money))
	lifetime = {}
	var lt: Dictionary = state.get("lifetime", {})
	for k: String in lt:
		lifetime[k] = int(lt[k])
	history = []
	for h: Dictionary in state.get("history", []):
		var by := {}
		for k: String in h.get("by", {}):
			by[k] = int(h["by"][k])
		history.append({"day": int(h["day"]), "open": int(h["open"]), "close": int(h["close"]),
			"income": int(h["income"]), "expense": int(h["expense"]), "by": by})
