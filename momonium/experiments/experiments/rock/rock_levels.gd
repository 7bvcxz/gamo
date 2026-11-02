class_name RockLevels
extends RefCounted

## Experiment C's numbers in one place: the rocks one after another (each
## harder, bigger and paying more) and the pickaxe's power levels with their
## prices. Nothing is random: the same taps break the same rocks.
##
## At a natural 2.5 taps a second, buying each pickaxe level as soon as it can
## be paid: the first rock breaks at 20 s and pays the first upgrade; about
## seven rocks and five upgrades in three minutes. The tenth rock, the Giant
## Crystal, stands on a far islet from the start as the distant goal.

## [name, hp, reward, body colour, vein colour, radius (px at 720 wide)]
const ROCKS: Array[Array] = [
	["Pebble Boulder", 50, 25, Color("#9aa3ad"), Color("#c9d1d8"), 120.0],
	["Grey Stone", 80, 40, Color("#8c939c"), Color("#b8c0c8"), 128.0],
	["Mossy Rock", 130, 60, Color("#7f8e80"), Color("#9fd26b"), 136.0],
	["Copper Vein", 200, 90, Color("#8a7a70"), Color("#f08a4b"), 144.0],
	["Iron Lump", 300, 130, Color("#6f7680"), Color("#d8dee6"), 152.0],
	["Silver Seam", 450, 190, Color("#737b8a"), Color("#eef3ff"), 160.0],
	["Gold Nugget Rock", 650, 270, Color("#7d705c"), Color("#ffd34d"), 168.0],
	["Amethyst Geode", 950, 380, Color("#6b6280"), Color("#c792ff"), 176.0],
	["Ruby Heart", 1400, 540, Color("#6e5a5e"), Color("#ff5f7a"), 184.0],
	["Giant Crystal", 3600, 1600, Color("#5c7d9a"), Color("#9ff0ff"), 200.0],
]
const GOAL := 9

## Damage per hit at each pickaxe level, and the price of reaching it.
const DAMAGE: Array[int] = [1, 2, 3, 5, 8, 12, 18, 27, 40, 60, 90]
const COST: Array[int] = [0, 20, 45, 90, 170, 300, 520, 900, 1500, 2500, 4200]
## The pickaxe's colour at each level (wood and stone to crystal).
const TINT: Array[Color] = [Color(1, 1, 1), Color("#d9c3a0"), Color("#c7c9cc"), Color("#f2a46c"), Color("#dfe6ee"),
	Color("#fff0b0"), Color("#ffd34d"), Color("#c9a6ff"), Color("#ff9db0"), Color("#a6f4ff"), Color("#ffffff")]


static func rock_count() -> int:
	return ROCKS.size()


## Rock `n` (past the last: the Giant Crystal again, harder each time).
static func rock(n: int) -> Dictionary:
	var i := mini(n, ROCKS.size() - 1)
	var r: Array = ROCKS[i]
	var extra := maxi(0, n - (ROCKS.size() - 1))
	var k := pow(1.6, extra)
	return {"index": n, "name": String(r[0]), "hp": int(round(float(r[1]) * k)), "reward": int(round(float(r[2]) * k)),
		"body": r[3], "vein": r[4], "radius": float(r[5]), "goal": i == GOAL}


static func max_pick() -> int:
	return DAMAGE.size() - 1


static func damage(pick: int) -> int:
	return DAMAGE[clampi(pick, 0, max_pick())]


## Price of pickaxe level `pick` (from pick - 1); -1 past the last.
static func cost(pick: int) -> int:
	return COST[pick] if pick <= max_pick() else -1


static func tint(pick: int) -> Color:
	return TINT[clampi(pick, 0, TINT.size() - 1)]


## A player who taps `taps_per_second` and buys every level when it can pay:
## [time of each break], [time of each upgrade] up to `seconds`.
static func simulate(taps_per_second: float, seconds: float) -> Dictionary:
	var t := 0.0
	var dt := 1.0 / taps_per_second
	var coins := 0
	var pick := 0
	var n := 0
	var hp := int(rock(0)["hp"])
	var breaks: Array[float] = []
	var upgrades: Array[float] = []
	while t + dt <= seconds:
		t += dt
		hp -= damage(pick)
		if hp <= 0:
			coins += int(rock(n)["reward"])
			breaks.append(t)
			n += 1
			hp = int(rock(n)["hp"])
			while pick < max_pick() and coins >= cost(pick + 1):
				coins -= cost(pick + 1)
				pick += 1
				upgrades.append(t)
	return {"breaks": breaks, "upgrades": upgrades, "pick": pick, "rock": n, "coins": coins}
