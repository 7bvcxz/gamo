class_name TycoonPlusLevels
extends RefCounted

## E+'s line for thirty minutes (Step 98) -- still one line, one button
## (Improve Line), one coin. Levels 0-10 are E's (TycoonLevels, the three
## minutes the owner liked, unchanged); then twenty more, each something you
## can see on the line, and none of them a decision:
##   machine mechanisms (twin presses, robot arms, the night shift's lit
##   factory), stations the goods pass through (a paint arch that colours
##   them, gift wrap), the line branching into two crates at its end, more
##   lanes (up to six), more Momo at work, and buildings rising beside the
##   line (wind and sun power, a clock tower, a water wheel, a head office).
## Every level raises the line's narrowest point or what a delivery pays, so
## output only grows; the prices are calibrated on the real line
## (tools/e_costs.gd) for an upgrade about every 20 s at first (E's), 55 s
## by minute 8, 75 s by 15 and 95 s by 30 -- the twentieth, the Head Office,
## near minute 25, the Grand Line after it. Every fifth level from 10 opens
## an era with a short celebration (`era`). Past the last, "Grand Line" levels
## add value with a gentler price than E's x1.5 wall, each painting the goods
## a new colour.
##
## New row keys (TycoonLine reads only its own): paint (the goods' colour
## after the arch), wrap (gift wrap after the arch), branch (two crates),
## lit (the factory's windows lit: the night shift), decor (a building
## beside the line; one with a lit version shows it lit), era (the era it
## opens).

const PLUS: Array[Dictionary] = [
	{"name": "Twin Presses", "cost": 2400, "arms": 4, "process": 1.2, "show": "arm"},
	{"name": "Fourth Lane", "cost": 2700, "lanes": 4, "show": "lane"},
	{"name": "Paint Arch", "cost": 3600, "value": 18, "paint": Color("#4f8ff7"), "show": "paint"},
	{"name": "Momo Packers", "cost": 5300, "spawn": 0.5, "helpers": 3, "show": "helper"},
	{"name": "Express Belt", "cost": 6200, "speed": 1.25, "show": "belt", "era": "Express Era"},
	{"name": "Fifth Lane", "cost": 7000, "lanes": 5, "show": "lane"},
	{"name": "Night Shift", "cost": 9000, "lit": true, "arms": 5, "process": 1.0, "show": "machine"},
	{"name": "Wind Power", "cost": 9700, "spawn": 0.42, "decor": "wind_turbine", "show": "decor"},
	{"name": "Gold Paint", "cost": 12000, "value": 26, "paint": Color("#ffd34d"), "show": "paint"},
	{"name": "Second Crate", "cost": 19000, "speed": 1.45, "branch": true, "show": "branch", "era": "Golden Era"},
	{"name": "Sixth Lane", "cost": 20000, "lanes": 6, "show": "lane"},
	{"name": "Robot Arms", "cost": 24000, "arms": 6, "process": 0.85, "show": "arm"},
	{"name": "Solar Roof", "cost": 26000, "spawn": 0.36, "decor": "solar_panel", "show": "decor"},
	{"name": "Gift Wrap", "cost": 30000, "value": 36, "wrap": true, "show": "wrap"},
	{"name": "Momo Band", "cost": 43000, "helpers": 5, "spawn": 0.33, "show": "helper", "era": "Festival Era"},
	{"name": "Hyper Belt", "cost": 49000, "speed": 1.75, "show": "belt"},
	{"name": "Factory Clock", "cost": 52000, "arms": 7, "process": 0.72, "decor": "clock_tower", "show": "decor"},
	{"name": "Rainbow Cars", "cost": 55000, "value": 50, "paint": Color("#ff5ec8"), "show": "paint"},
	{"name": "Water Wheel", "cost": 74000, "spawn": 0.3, "decor": "water_wheel", "show": "decor"},
	{"name": "Head Office", "cost": 88000, "value": 62, "decor": "office", "show": "decor", "era": "Grand Era"},
]
const GRAND_COST := 1.3
const GRAND_VALUE := 6
## Each Grand Line level paints the goods anew (the arch takes the colour):
## a level that only paid more would be income with nothing to see.
const GRAND_PAINTS: Array[Color] = [Color("#7a5cff"), Color("#29c7b8"), Color("#ff7a29"), Color("#ffffff"), Color("#5cd65c"), Color("#ff3b6b")]
## The buildings beside the line, in the order they rise.
const DECOR_ORDER: Array[String] = ["wind_turbine", "solar_panel", "clock_tower", "water_wheel", "office"]


static func count() -> int:
	return TycoonLevels.LEVELS.size() + PLUS.size()


static func _raw(n: int) -> Dictionary:
	if n < TycoonLevels.LEVELS.size():
		return TycoonLevels.LEVELS[n]
	return PLUS[n - TycoonLevels.LEVELS.size()]


## Level `n` with everything carried over from the levels before it; `decor`
## becomes the list of buildings standing so far.
static func row(n: int) -> Dictionary:
	var out := {"paint": Color(0, 0, 0, 0), "wrap": false, "branch": false, "lit": false, "era": ""}
	var decor: Array[String] = []
	for i in mini(n, count() - 1) + 1:
		var r := _raw(i)
		for k: String in r:
			if k == "decor":
				decor.append(String(r[k]))
			elif k != "era":
				out[k] = r[k]
		out["era"] = String(r.get("era", ""))
	out["decor"] = decor
	if n >= count():
		var k := n - count() + 1
		out["name"] = "Grand Line %d" % k
		out["cost"] = int(round(float(_raw(count() - 1)["cost"]) * pow(GRAND_COST, k)))
		out["value"] = int(out["value"]) + GRAND_VALUE * k
		out["paint"] = GRAND_PAINTS[(k - 1) % GRAND_PAINTS.size()]
		out["show"] = "paint"
		out["era"] = ""
	return out


static func cost(n: int) -> int:
	return int(row(n)["cost"])


## The era level `n` opens ("" for most).
static func era(n: int) -> String:
	return String(row(n)["era"]) if n < count() else ""


## The line's narrowest point at level `n`: deliveries a second it can make
## at most (spawning, the machine's arms, the belt -- per lane, times lanes).
static func capacity(n: int) -> float:
	var r := row(n)
	var per_lane := minf(1.0 / float(r["spawn"]), minf(float(r["arms"]) / float(r["process"]), float(r["speed"]) / TycoonLine.SPACING))
	return per_lane * float(r["lanes"])


## A player who buys whenever it can pay, `reaction` s later, on the real
## line; `grand` buys only the bundles of the grand alternative. Returns the
## upgrade times, deliveries, coins, the level, the items made.
static func simulate(seconds: float, reaction: float = 1.5, grand: bool = false) -> Dictionary:
	var line := TycoonLine.new()
	var level := 0
	line.configure(row(0))
	var coins := 0
	var earned := 0
	var t := 0.0
	var ready_since := -1.0
	var ups: Array[float] = []
	var first_delivery := -1.0
	while t < seconds:
		line.advance(TycoonLine.STEP)
		t += TycoonLine.STEP
		var got := line.just_delivered.size() * line.value
		coins += got
		earned += got
		if got > 0 and first_delivery < 0.0:
			first_delivery = t
		var to := next_target(level, grand)
		var price := price_to(level, to)
		if coins >= price:
			if ready_since < 0.0:
				ready_since = t
			if t - ready_since >= reaction:
				coins -= price
				level = to
				line.configure(row(level))
				ups.append(t)
				ready_since = -1.0
		else:
			ready_since = -1.0
	return {"upgrades": ups, "delivered": line.delivered, "spawned": line.spawned, "level": level, "coins": coins, "earned": earned,
		"first_delivery": first_delivery, "delivered_ids": line.delivered_ids}


## The grand alternative (`?alt=grand`): fewer, bigger transformations -- the
## button buys up to the end of the next bundle at once, for the sum of
## their prices. The default buys one level.
const GRAND_BUNDLES: Array[int] = [3, 6, 8, 10, 13, 15, 18, 20, 23, 25, 28, 30]


static func next_target(level: int, grand: bool) -> int:
	if not grand:
		return level + 1
	for b: int in GRAND_BUNDLES:
		if b > level:
			return b
	return level + 1


## What it costs to go from `level` to `to`.
static func price_to(level: int, to: int) -> int:
	var sum := 0
	for n in range(level + 1, to + 1):
		sum += cost(n)
	return sum
