class_name IslandLevels
extends RefCounted

## Experiment A's whole economy and what every upgrade puts on the island, in
## one table, so tests read exactly what the player is shown.
##
## Row n is level n. `cost` is the price of upgrading from n-1 to n, `rate` the
## coins a second after it. `coast` rectangles [x0, y0, x1, y1] (inclusive)
## become land; `props` are the game's atlas sprites standing on a cell; `momos`
## are helpers arriving at a cell; `paths` turn grass to a sandy path; `field`
## replaces the crop on the two field cells. Every row adds something that can
## be seen. Past the table the island keeps growing (`endless`): a new piece of
## coast and a tree or bush each time, costs x1.55, rate x1.3.
##
## With every upgrade bought the moment it is affordable: the first at 15 s,
## the Village (level 3) at 49 s, the Town (level 6) at 1:43, and the Monument
## (level 10) -- the bigger milestone the Town shows as a ghost -- at 3:16.

const FIELD_CELLS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 1)]

const LEVELS: Array[Dictionary] = [
	{"cost": 0, "rate": 1.0, "stage": "islet", "coast": [[0, 0, 1, 1]], "momos": [[1, 0]], "icon": "momo_front"},
	{"cost": 15, "rate": 1.6, "stage": "islet", "coast": [[0, 0, 2, 2]], "props": [["prop_bush", 2, 0]], "icon": "prop_bush"},
	{"cost": 26, "rate": 2.4, "stage": "islet", "props": [["prop_tree", 0, 0], ["prop_flowers", 1, 2]], "icon": "prop_tree"},
	{"cost": 42, "rate": 4.0, "stage": "village", "coast": [[-1, -1, 2, 2]], "props": [["villa", -1, -1]], "momos": [[2, 1]], "field": "crop_seeds", "icon": "villa"},
	{"cost": 68, "rate": 5.5, "stage": "village", "paths": [[-1, 0], [-1, 1], [-1, 2]], "props": [["prop_pine_small", 2, 1]], "field": "crop_sprout", "icon": "crop_sprout"},
	{"cost": 100, "rate": 7.5, "stage": "village", "coast": [[3, 0, 3, 1]], "props": [["villa", 2, -1], ["prop_bush_flowers", 1, -1]], "field": "crop_leafy", "icon": "villa"},
	{"cost": 145, "rate": 12.0, "stage": "town", "coast": [[-1, -1, 3, 3]], "props": [["clock_tower", -1, 3], ["prop_pine", 3, 3]], "momos": [[1, 3]], "icon": "clock_tower"},
	{"cost": 220, "rate": 16.0, "stage": "town", "props": [["park", 2, 2]], "field": "crop_ripe", "icon": "park"},
	{"cost": 320, "rate": 21.0, "stage": "town", "coast": [[0, -2, 1, -2], [-2, 1, -2, 2]], "props": [["apartment", 0, -2], ["prop_pine", -2, 1]], "icon": "apartment"},
	{"cost": 460, "rate": 28.0, "stage": "town", "coast": [[4, 1, 4, 2]], "props": [["wind_turbine", 3, -1], ["prop_rocks", 4, 2]], "icon": "wind_turbine"},
	{"cost": 900, "rate": 45.0, "stage": "monument", "coast": [[-2, -2, 3, 3]], "props": [["momo_monument", -2, -2]], "momos": [[0, 3]], "icon": "momo_monument"},
]

const MONUMENT_LEVEL := 10
const ENDLESS_COST := 1.55
const ENDLESS_RATE := 1.3
const ENDLESS_PROPS: Array[String] = ["prop_tree", "prop_bush_flowers", "prop_pine", "prop_flowers", "prop_bush", "prop_pine_small"]
## Where the endless coast grows, in order (a ring round the 6x6 island).
const ENDLESS_RING: Array[Vector2i] = [
	Vector2i(4, -1), Vector2i(-1, 4), Vector2i(4, 0), Vector2i(0, 4), Vector2i(-3, 0), Vector2i(0, -3),
	Vector2i(4, 3), Vector2i(3, 4), Vector2i(-3, -1), Vector2i(-1, -3), Vector2i(1, 4), Vector2i(4, -2),
	Vector2i(-3, 1), Vector2i(1, -3), Vector2i(2, 4), Vector2i(-3, 2), Vector2i(-3, -2), Vector2i(-2, -3),
]


## Level `n`'s row (past the table: an endless row made the same way).
static func row(n: int) -> Dictionary:
	if n < LEVELS.size():
		return LEVELS[n]
	var k := n - LEVELS.size() + 1
	var last: Dictionary = LEVELS[LEVELS.size() - 1]
	var cell: Vector2i = ENDLESS_RING[(k - 1) % ENDLESS_RING.size()]
	var prop := ENDLESS_PROPS[(k - 1) % ENDLESS_PROPS.size()]
	return {"cost": int(round(float(last["cost"]) * pow(ENDLESS_COST, k))), "rate": snappedf(float(last["rate"]) * pow(ENDLESS_RATE, k), 0.1),
		"stage": "monument", "coast": [[cell.x, cell.y, cell.x, cell.y]], "props": [[prop, cell.x, cell.y]], "icon": prop}


static func cost(n: int) -> int:
	return int(row(n)["cost"])


static func rate(n: int) -> float:
	return float(row(n)["rate"])


static func stage(n: int) -> String:
	return String(row(n)["stage"])


## Every land cell at level `n`.
static func cells(n: int) -> Array[Vector2i]:
	var seen := {}
	var out: Array[Vector2i] = []
	for i in n + 1:
		for c: Vector2i in coast_of(i):
			if not seen.has(c):
				seen[c] = true
				out.append(c)
	return out


## The cells level `i` itself turns to land (some may be land already).
static func coast_of(i: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for r: Array in row(i).get("coast", []):
		for x in range(int(r[0]), int(r[2]) + 1):
			for y in range(int(r[1]), int(r[3]) + 1):
				out.append(Vector2i(x, y))
	return out


## [sprite, cell] of every prop standing at level `n`.
static func props(n: int) -> Array:
	var out: Array = []
	for i in n + 1:
		for p: Array in row(i).get("props", []):
			out.append([String(p[0]), Vector2i(int(p[1]), int(p[2]))])
	return out


static func momos(n: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in n + 1:
		for m: Array in row(i).get("momos", []):
			out.append(Vector2i(int(m[0]), int(m[1])))
	return out


static func paths(n: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in n + 1:
		for p: Array in row(i).get("paths", []):
			out.append(Vector2i(int(p[0]), int(p[1])))
	return out


## The crop on the field at level `n` ("" before there is one).
static func field(n: int) -> String:
	var f := ""
	for i in n + 1:
		f = String(row(i).get("field", f))
	return f


## Seconds from the start to each level, buying the moment it is affordable.
static func instant_times(levels: int) -> Array[float]:
	var out: Array[float] = [0.0]
	var t := 0.0
	for n in range(1, levels + 1):
		t += float(cost(n)) / rate(n - 1)
		out.append(t)
	return out
