class_name TycoonLevels
extends RefCounted

## Experiment E's line, level by level: what Improve Production Line changes
## (and what you see change): a bigger hopper, a second machine arm, a better
## machine and product, a Momo feeding the hopper, a faster belt, a second
## lane, gold, another Momo, a third lane, cars. Each level raises the line's
## narrowest point, so output rises every time.
##
## Bought the moment it can pay: the first improvement at about 20 s, eight in
## three minutes (`simulate`, the real line -- the first item takes a while
## to ride it).

const LEVELS: Array[Dictionary] = [
	{"name": "Little Line", "cost": 0, "lanes": 1, "speed": 0.8, "spawn": 3.0, "process": 2.4, "arms": 1, "value": 3, "machine": "smelter", "product": "item_iron_ingot", "raw": "item_stone", "helpers": 0, "show": "start"},
	{"name": "Bigger Hopper", "cost": 12, "spawn": 2.0, "show": "hopper"},
	{"name": "Second Arm", "cost": 24, "arms": 2, "show": "arm"},
	{"name": "Steam Machine", "cost": 36, "value": 5, "machine": "steam_engine", "product": "item_copper_ingot", "show": "machine"},
	{"name": "Momo Loader", "cost": 56, "spawn": 1.2, "helpers": 1, "show": "helper"},
	{"name": "Fast Belt", "cost": 90, "speed": 1.0, "spawn": 0.8, "process": 1.6, "show": "belt"},
	{"name": "Second Lane", "cost": 140, "lanes": 2, "show": "lane"},
	{"name": "Gold Bars", "cost": 220, "value": 8, "product": "item_gold_ingot", "raw": "item_gold", "show": "product"},
	{"name": "Momo Crew", "cost": 340, "spawn": 0.6, "arms": 3, "helpers": 2, "show": "helper"},
	{"name": "Third Lane", "cost": 520, "lanes": 3, "show": "lane"},
	{"name": "Car Factory", "cost": 800, "value": 14, "machine": "car_factory", "product": "item_car", "raw": "item_iron_ingot", "process": 1.4, "show": "machine"},
]
const ENDLESS_COST := 1.5


## Level `n` with everything carried over from the levels before it.
static func row(n: int) -> Dictionary:
	var out := {}
	for i in mini(n, LEVELS.size() - 1) + 1:
		for k: String in LEVELS[i]:
			out[k] = LEVELS[i][k]
	if n >= LEVELS.size():
		var k := n - LEVELS.size() + 1
		out["name"] = "Golden Line %d" % k
		out["cost"] = int(round(float(LEVELS[LEVELS.size() - 1]["cost"]) * pow(ENDLESS_COST, k)))
		out["value"] = int(out["value"]) + 3 * k
		out["show"] = "sparkle"
	return out


static func cost(n: int) -> int:
	return int(row(n)["cost"])


## A player who buys whenever it can pay, after `reaction` s, on the real
## line: [time of each improvement], deliveries, coins.
static func simulate(seconds: float, reaction: float = 0.0) -> Dictionary:
	var line := TycoonLine.new()
	var level := 0
	line.configure(row(0))
	var coins := 0
	var t := 0.0
	var ready_since := -1.0
	var ups: Array[float] = []
	while t < seconds:
		line.advance(TycoonLine.STEP)
		t += TycoonLine.STEP
		coins += line.just_delivered.size() * line.value
		if coins >= cost(level + 1):
			if ready_since < 0.0:
				ready_since = t
			if t - ready_since >= reaction:
				coins -= cost(level + 1)
				level += 1
				line.configure(row(level))
				ups.append(t)
				ready_since = -1.0
	return {"upgrades": ups, "delivered": line.delivered, "level": level, "coins": coins, "spawned": line.spawned}
