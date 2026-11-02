class_name EvolutionLevels
extends RefCounted

## Experiment B's one Momo, level by level: what work it does (one of the
## game's work loops, each with its own tool), how fast it does it, what one
## finished pass pays, what it wears, and the price of getting there. Every
## level changes something on the Momo: a new tool and motion (every second
## level), or something to wear and a quicker hand. Past the table it keeps
## working faster and earning more, a sparkle each time.
##
## A pass of `pose` takes LabMomo.loop_seconds(pose) / speed seconds of play
## and pays `pay` coins when it ends -- coins come from finished work only.
## Bought the moment it can pay: the first upgrade at about 18 s, the tools
## change every ~35 s, ten upgrades in three minutes; the Scholar's crown
## (level 12) waits just past three minutes.

const LEVELS: Array[Dictionary] = [
	{"name": "Seed Sower", "pose": "work_sow", "speed": 0.85, "pay": 1, "cost": 0, "tool": "seed_pouch", "spot": "crop_seeds", "item": "crop_sprout"},
	{"name": "Satchel", "pose": "work_sow", "speed": 1.0, "pay": 2, "cost": 10, "wear": "bag"},
	{"name": "Waterer", "pose": "work_water", "speed": 1.0, "pay": 4, "cost": 20, "tool": "watering_can", "spot": "crop_sprout", "item": "crop_leafy"},
	{"name": "Leaf Hat", "pose": "work_water", "speed": 1.25, "pay": 4, "cost": 36, "wear": "hat"},
	{"name": "Harvester", "pose": "work_harvest", "speed": 1.0, "pay": 7, "cost": 48, "tool": "basket", "spot": "crop_ripe", "item": "crop_ripe"},
	{"name": "Apron", "pose": "work_harvest", "speed": 1.3, "pay": 7, "cost": 75, "wear": "apron"},
	{"name": "Woodcutter", "pose": "work_chop", "speed": 1.0, "pay": 11, "cost": 100, "tool": "axe", "spot": "prop_logs", "item": "item_wood"},
	{"name": "Scarf", "pose": "work_chop", "speed": 1.3, "pay": 11, "cost": 160, "wear": "scarf"},
	{"name": "Miner", "pose": "work_dig", "speed": 1.1, "pay": 18, "cost": 210, "tool": "pickaxe", "spot": "prop_rocks", "item": "item_stone"},
	{"name": "Lamp Helmet", "pose": "work_dig", "speed": 1.4, "pay": 18, "cost": 300, "wear": "helmet"},
	{"name": "Smith", "pose": "work_hammer", "speed": 1.0, "pay": 22, "cost": 380, "tool": "hammer", "spot": "anvil", "item": "item_iron_ingot"},
	{"name": "Medal", "pose": "work_hammer", "speed": 1.3, "pay": 22, "cost": 480, "wear": "medal"},
	{"name": "Scholar", "pose": "work_study", "speed": 1.0, "pay": 100, "cost": 900, "tool": "flask", "spot": "desk", "item": "icon_star", "wear": "crown"},
]
## What is worn where: a later thing on the same place replaces the earlier.
const PLACE := {"bag": "side", "hat": "head", "helmet": "head", "crown": "head", "apron": "body", "scarf": "neck", "medal": "chest"}
const ENDLESS_COST := 1.45
const ENDLESS_PAY := 1.3
const ENDLESS_SPEED := 1.04


## Level `n`'s row with everything it carries over filled in (pose, tool,
## spot and item from the last level that set them).
static func row(n: int) -> Dictionary:
	var out := {}
	for i in mini(n, LEVELS.size() - 1) + 1:
		var r: Dictionary = LEVELS[i]
		for k: String in r:
			out[k] = r[k]
		if not r.has("wear"):
			out.erase("wear")
	if n >= LEVELS.size():
		var k := n - LEVELS.size() + 1
		out["name"] = "Star Scholar %d" % k
		out["cost"] = int(round(float(LEVELS[LEVELS.size() - 1]["cost"]) * pow(ENDLESS_COST, k)))
		out["pay"] = int(round(float(LEVELS[LEVELS.size() - 1]["pay"]) * pow(ENDLESS_PAY, k)))
		out["speed"] = snappedf(float(LEVELS[LEVELS.size() - 1]["speed"]) * pow(ENDLESS_SPEED, k), 0.001)
		out.erase("wear")
		out["sparkle"] = k
	return out


static func cost(n: int) -> int:
	return int(row(n)["cost"])


## Seconds of play for one pass at level `n`.
static func cycle(n: int) -> float:
	var r := row(n)
	return LabMomo.loop_seconds(String(r["pose"])) / float(r["speed"])


## Coins a second at level `n` (finished passes only; this is the average).
static func rate(n: int) -> float:
	return float(row(n)["pay"]) / cycle(n)


## What the Momo wears at level `n`, one thing per place.
static func wearing(n: int) -> Array[String]:
	var by_place := {}
	var order: Array[String] = []
	for i in mini(n, LEVELS.size() - 1) + 1:
		var w := String(LEVELS[i].get("wear", ""))
		if w == "":
			continue
		var place := String(PLACE[w])
		if not by_place.has(place):
			order.append(place)
		by_place[place] = w
	var out: Array[String] = []
	for p: String in order:
		out.append(String(by_place[p]))
	return out


## Whether level `n` brings a new tool and motion (not only a thing to wear).
static func new_tool(n: int) -> bool:
	return n > 0 and n < LEVELS.size() and LEVELS[n].has("tool")


## Buying the moment it can pay (after `reaction` s): [time of each upgrade].
static func simulate(seconds: float, reaction: float = 0.0, step: float = 0.05) -> Array[float]:
	var t := 0.0
	var level := 0
	var coins := 0
	var cycle_t := 0.0
	var ready_since := -1.0
	var ups: Array[float] = []
	while t < seconds:
		t += step
		cycle_t += step
		var c := cycle(level)
		while cycle_t >= c:
			cycle_t -= c
			coins += int(row(level)["pay"])
		if coins >= cost(level + 1):
			if ready_since < 0.0:
				ready_since = t
			if t - ready_since >= reaction:
				coins -= cost(level + 1)
				cycle_t *= cycle(level + 1) / c
				level += 1
				ups.append(t)
				ready_since = -1.0
	return ups
