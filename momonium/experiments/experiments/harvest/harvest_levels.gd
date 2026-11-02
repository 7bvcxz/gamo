class_name HarvestLevels
extends RefCounted

## Experiment D's field, level by level: how big it is (cells, two plants to a
## cell), what one ripe plant pays, and the price of the next Bigger Field.
## The field ripens over GROW_SECONDS of play and waits, ripe, for the one
## harvest -- nothing is ever harvested by itself.
##
## Harvesting a second after it is ripe and buying each level as soon as it
## can be paid: the first harvest at 15 s (16 coins), then 24, 36 ... 200 a
## harvest -- twelve harvests and eight upgrades in three minutes.

const GROW_SECONDS := 14.0
const PLANTS_PER_CELL := 2

## [width, height] in cells, coins a ripe plant, price of reaching the level.
const LEVELS: Array[Dictionary] = [
	{"field": [2, 2], "yield": 2, "cost": 0},
	{"field": [3, 2], "yield": 2, "cost": 16},
	{"field": [3, 3], "yield": 2, "cost": 24},
	{"field": [3, 3], "yield": 3, "cost": 40, "golden": true},
	{"field": [4, 3], "yield": 3, "cost": 60},
	{"field": [4, 4], "yield": 3, "cost": 90},
	{"field": [4, 4], "yield": 4, "cost": 130, "golden": true},
	{"field": [5, 4], "yield": 4, "cost": 190},
	{"field": [5, 5], "yield": 4, "cost": 270},
	{"field": [5, 5], "yield": 5, "cost": 380, "golden": true},
	{"field": [6, 5], "yield": 5, "cost": 540},
	{"field": [6, 6], "yield": 5, "cost": 760},
]
const ENDLESS_COST := 1.4


static func row(n: int) -> Dictionary:
	if n < LEVELS.size():
		return LEVELS[n]
	var k := n - LEVELS.size() + 1
	var last: Dictionary = LEVELS[LEVELS.size() - 1]
	return {"field": last["field"], "yield": int(last["yield"]) + k, "cost": int(round(float(last["cost"]) * pow(ENDLESS_COST, k))), "golden": true}


static func cost(n: int) -> int:
	return int(row(n)["cost"])


static func plants(n: int) -> int:
	var f: Array = row(n)["field"]
	return int(f[0]) * int(f[1]) * PLANTS_PER_CELL


## What one harvest pays at level `n`.
static func payout(n: int) -> int:
	return plants(n) * int(row(n)["yield"])


## Every field cell at level `n` (x right-down, y left-down from the corner).
static func cells(n: int) -> Array[Vector2i]:
	var f: Array = row(n)["field"]
	var out: Array[Vector2i] = []
	for x in int(f[0]):
		for y in int(f[1]):
			out.append(Vector2i(x, y))
	return out


## Whether level `n` changes what the field looks like (bigger, or golden).
static func visible_change(n: int) -> bool:
	if n == 0:
		return true
	return row(n)["field"] != row(n - 1)["field"] or bool(row(n).get("golden", false))


## A player who harvests `reaction` s after ripe and buys whenever it can pay
## (after a harvest): {harvests: [time, coins], upgrades: [time]}.
static func simulate(seconds: float, reaction: float = 0.0) -> Dictionary:
	var t := 0.0
	var level := 0
	var coins := 0
	var harvests: Array = []
	var ups: Array[float] = []
	while true:
		t += GROW_SECONDS + reaction
		if t > seconds:
			break
		var p := payout(level)
		coins += p
		harvests.append([t, p])
		while coins >= cost(level + 1):
			coins -= cost(level + 1)
			level += 1
			ups.append(t)
	return {"harvests": harvests, "upgrades": ups, "level": level, "coins": coins}
