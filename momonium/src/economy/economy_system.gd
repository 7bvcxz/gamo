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
## Finished work is money at once (Step 50): a harvest's crops are sold the
## moment they are picked (items with sell "instant"), a stage's `revenue`
## (ore sold at the mine face, timber at the yard) is paid as it completes,
## and what the store has no room for is sold at its price (sell "surplus")
## instead of stopping the work -- never thrown away, never sold twice. The
## day boundary only closes the day's book.

var money: int = 0
## Today's bookings: category -> signed amount.
var today: Dictionary = {}
var today_open: int = 0
## Closed days: {day, open, close, income, expense, by: {category: amount}}.
var history: Array = []
## Since the game began: category -> signed amount (history keeps 30 days).
var lifetime: Dictionary = {}
## Production income of the last minute: [[ms, amount], ...] oldest first --
## the HUD's "+$N/min". Rebuilt by play, not saved.
var recent: Array = []
const RATE_WINDOW_MS := 60000


func _init() -> void:
	key = &"economy"


func on_new_game() -> void:
	money = sim.data.get_int("balance", "start.money")
	today = {}
	today_open = money
	history = []
	lifetime = {}
	recent = []


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


## What one unit fetches: its price, times market research (sale_price).
func unit_price(item: String) -> int:
	var research: ResearchSystem = sim.system(&"research")
	var m := research.sale_multiplier() if research != null else 1.0
	return int(floor(float(sim.data.item(item).get("price", 0)) * m))


## Sold the moment it is made (sell "instant": crops, cars).
func sells_at_once(item: String) -> bool:
	return String(sim.data.item(item).get("sell", "")) == "instant"


## Can be sold at all -- at once, or what the store has no room for.
func sellable(item: String) -> bool:
	return String(sim.data.item(item).get("sell", "")) in ["instant", "surplus"] and int(sim.data.item(item).get("price", 0)) > 0


## A finished stage's output turned into the island's: `items` (whole items
## made) are stored, or sold -- at once (instant), or the part that does not
## fit (surplus) -- and `revenue` money is paid with them, all booked as one
## sale of building `b` by `worker`. Returns {stored, sold, money}.
func cash_in(b: Dictionary, items: Dictionary, revenue: int, worker: int) -> Dictionary:
	var inv: InventorySystem = sim.system(&"inventory")
	var type := String(b.get("type", ""))
	var stored := {}
	var sold := {}
	var money := maxi(revenue, 0)
	for item: String in items:
		var n := int(items[item])
		if n <= 0:
			continue
		var keep := 0
		if not sells_at_once(item):
			keep = inv.add(item, n, "yield:" + type)
			if keep > 0:
				stored[item] = keep
		var rest := n - keep
		if rest > 0 and sellable(item):
			inv.count_made(item, rest)
			sold[item] = rest
			money += rest * unit_price(item)
	if money > 0:
		earn(money, "sale:" + type)
		_note_rate(money)
		sim.bus.emit(&"sold", {"id": int(b.get("id", 0)), "type": type, "items": sold, "money": money, "worker": worker, "revenue": maxi(revenue, 0)})
	return {"stored": stored, "sold": sold, "money": money}


func _note_rate(amount: int) -> void:
	var now := sim.now_ms()
	recent.append([now, amount])
	while not recent.is_empty() and int(recent[0][0]) <= now - RATE_WINDOW_MS:
		recent.pop_front()


## Production money of the last minute (what the HUD shows as +$N/min).
func income_per_minute() -> int:
	var from := sim.now_ms() - RATE_WINDOW_MS
	var total := 0
	for r: Array in recent:
		if int(r[0]) > from:
			total += int(r[1])
	return total


func on_day_started(day: int) -> void:
	_close_day(day - 1)


func _close_day(day: int) -> void:
	var income := 0
	var expense := 0
	for k: String in today:
		var v := int(today[k])
		if v > 0:
			income += v
		else:
			expense -= v
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
