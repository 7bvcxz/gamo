class_name RockPlusLevels
extends RefCounted

## C+'s progression for thirty minutes (Step 96) -- still one rock at a time,
## one currency, one pickaxe, one tap. C's ten rocks and ten pickaxe levels
## end in three minutes with the Giant Crystal repeating at x1.6 HP each
## time (a wall). C+ instead keeps one steady shape that does not wear out:
##   - a rock takes about HITS hits whatever the level: each rock is GROWTH
##     harder and richer than the one before, each pickaxe level DAMAGE_GROWTH
##     stronger and dearer, and GROWTH is the ROCKS_PER_LEVEL-th root of it;
##   - so in the long run a level comes every ROCKS_PER_LEVEL rocks (about a
##     minute at 2.5 taps a second), and the first levels come sooner
##     (EARLY_COST: the first at about 16 s, six in three minutes);
##   - the rocks change kind every KIND_SIZE: eighteen kinds, each with its
##     look and shape, the sixth of each its big one (BIG_HP, BIG_REWARD);
##     past the last the kinds come round again, deeper;
##   - two chunks pay CHUNK_SHARE of the rock's reward each as they break off
##     (RockPlusFeel.STAGES), the break pays the rest: the same coins a rock,
##     paid in three moments.
## Nothing is random. `simulate` plays it at any tapping rate (the
## experiment's own rules: the breaking moment, the rise, a reaction time).

const HITS := 36.0
const BASE_DAMAGE := 3
const REWARD0 := 25.0
const DAMAGE_GROWTH := 1.2
const ROCKS_PER_LEVEL := 3.0
const EARLY_COST: Array[float] = [0.6, 1.0, 1.3, 1.6, 1.9, 2.2, 2.5, 2.8]
const KIND_SIZE := 6
const BIG_HP := 2.4
const BIG_REWARD := 3.0
const CHUNK_SHARE := 0.15

## [name, body, vein, shape, sound]: shape is how RockPlusView builds it --
## round, slab (wide and low), tall, layered (banded), spiky, geode (crystals
## breaking through) or crystal (all shards); GLOWING kinds' cracks shine.
## The sound is stone (knock), metal (ring) or glass (a higher chime).
const KINDS: Array[Array] = [
	["Pebble Boulder", Color("#9aa3ad"), Color("#c9d1d8"), "round", "stone"],
	["Mossy Rock", Color("#7f8e80"), Color("#9fd26b"), "round", "stone"],
	["Sandstone", Color("#c4a074"), Color("#ecd3a2"), "layered", "stone"],
	["Copper Vein", Color("#8a7a70"), Color("#f08a4b"), "round", "metal"],
	["Coal Seam", Color("#55565e"), Color("#1f2026"), "slab", "stone"],
	["Iron Lump", Color("#6f7680"), Color("#d8dee6"), "tall", "metal"],
	["Rose Granite", Color("#a08890"), Color("#f3d0dc"), "round", "stone"],
	["Silver Seam", Color("#737b8a"), Color("#eef3ff"), "slab", "metal"],
	["Jade Rock", Color("#5f7d6a"), Color("#7ff0b0"), "geode", "glass"],
	["Gold Nugget Rock", Color("#7d705c"), Color("#ffd34d"), "round", "metal"],
	["Amethyst Geode", Color("#6b6280"), Color("#c792ff"), "geode", "glass"],
	["Ice Crag", Color("#9fc3d8"), Color("#f2fbff"), "spiky", "glass"],
	["Ruby Heart", Color("#6e5a5e"), Color("#ff5f7a"), "geode", "glass"],
	["Lava Rock", Color("#3d3438"), Color("#ff8a3d"), "spiky", "stone"],
	["Sapphire Geode", Color("#4f5d80"), Color("#5fa8ff"), "geode", "glass"],
	["Obsidian", Color("#2a2631"), Color("#9a8cff"), "spiky", "glass"],
	["Emerald Crown", Color("#4b6a58"), Color("#3fe08a"), "layered", "glass"],
	["Giant Crystal", Color("#5c7d9a"), Color("#9ff0ff"), "crystal", "glass"],
]
const GLOWING: Array[String] = ["Lava Rock", "Obsidian"]

static var _damage: Array[int] = []


## The growth from one rock to the next.
static func growth() -> float:
	return pow(DAMAGE_GROWTH, 1.0 / ROCKS_PER_LEVEL)


static func kind_index(n: int) -> int:
	return n / KIND_SIZE


## Whether rock `n` is its kind's big one (the sixth).
static func is_big(n: int) -> bool:
	return n % KIND_SIZE == KIND_SIZE - 1


## Rock `n`: {index, name, kind, kind_index, hp, reward, body, vein, shape,
## sound, glow, radius, goal (drawn as a crystal), big, round (how many times
## the kinds have come round), step (its place in its kind, 0..5)}.
static func rock(n: int) -> Dictionary:
	var k := kind_index(n)
	var row: Array = KINDS[k % KINDS.size()]
	var lap := k / KINDS.size()
	var big := is_big(n)
	var g := pow(growth(), n)
	var hp := int(round(HITS * float(BASE_DAMAGE) * g * (BIG_HP if big else 1.0)))
	var reward := int(round(REWARD0 * g * (BIG_REWARD if big else 1.0)))
	var name := String(row[0])
	if big:
		name = "Great " + name
	if lap > 0:
		name = "Deep " + name
	var body: Color = row[1]
	var vein: Color = row[2]
	var step := n % KIND_SIZE
	return {"index": n, "name": name, "kind": String(row[0]), "kind_index": k, "hp": maxi(1, hp), "reward": maxi(1, reward),
		"body": body.darkened(0.12 * lap), "vein": vein, "shape": String(row[3]), "sound": String(row[4]), "glow": GLOWING.has(String(row[0])),
		"radius": 185.0 if big else 120.0 + 7.0 * float(step), "goal": String(row[3]) == "crystal", "big": big, "round": lap,
		"step": step}


## Damage per hit at pickaxe level `pick`: x DAMAGE_GROWTH a level, and always
## at least one more than the level before.
static func damage(pick: int) -> int:
	if _damage.is_empty():
		_damage.append(BASE_DAMAGE)
	while _damage.size() <= pick:
		var p := _damage.size()
		_damage.append(maxi(_damage[p - 1] + 1, int(round(float(BASE_DAMAGE) * pow(DAMAGE_GROWTH, p)))))
	return _damage[maxi(pick, 0)]


## The price of pickaxe level `pick` (from pick - 1). There is no last level.
static func cost(pick: int) -> int:
	var m := EARLY_COST[pick - 1] if pick - 1 < EARLY_COST.size() else ROCKS_PER_LEVEL
	return int(round(m * REWARD0 * pow(DAMAGE_GROWTH, pick)))


## The share of rock `r`'s reward one chunk pays.
static func chunk_pay(r: Dictionary) -> int:
	return int(round(float(r["reward"]) * CHUNK_SHARE))


## A player who taps `taps_per_second` and buys each level `reaction` s after
## it can pay, for `seconds`; `hp_scale` < 1 is the light alternative. The
## experiment's own rules: chunks pay as they break off, the break pays the
## rest, nothing can be hit while a rock breaks and the next rises
## (`wait` s). Returns the breaks, chunks and upgrades with their times, the
## coins, and the taps that fell in a wait.
static func simulate(taps_per_second: float, seconds: float, reaction: float = 1.5, hp_scale: float = 1.0, wait: float = 0.57) -> Dictionary:
	var dt := 1.0 / taps_per_second
	var t := 0.0
	var coins := 0
	var earned := 0
	var pick := 0
	var n := 0
	var r := rock(n)
	var max_hp := maxi(1, int(round(float(r["hp"]) * hp_scale)))
	var hp := max_hp
	var paid := 0
	var waiting_until := 0.0
	var ready_since := -1.0
	var breaks: Array[float] = []
	var chunks: Array[float] = []
	var ups: Array[float] = []
	var taps := 0
	var waited := 0
	while t + dt <= seconds:
		t += dt
		taps += 1
		if t < waiting_until:
			waited += 1
		else:
			var before := float(max_hp - hp) / float(max_hp)
			hp = maxi(0, hp - damage(pick))
			var frac := float(max_hp - hp) / float(max_hp)
			if hp <= 0:
				var pay := int(r["reward"]) - paid
				coins += pay
				earned += pay
				breaks.append(t)
				n += 1
				r = rock(n)
				max_hp = maxi(1, int(round(float(r["hp"]) * hp_scale)))
				hp = max_hp
				paid = 0
				waiting_until = t + wait
			else:
				for at: float in RockPlusFeel.STAGES:
					if before < at and frac >= at:
						var c := chunk_pay(r)
						coins += c
						earned += c
						paid += c
						chunks.append(t)
		if coins >= cost(pick + 1):
			if ready_since < 0.0:
				ready_since = t
			elif t - ready_since >= reaction:
				coins -= cost(pick + 1)
				pick += 1
				ups.append(t)
				ready_since = -1.0
		else:
			ready_since = -1.0
	return {"breaks": breaks, "chunks": chunks, "upgrades": ups, "pick": pick, "rock": n, "coins": coins, "earned": earned,
		"taps": taps, "waited": waited, "hp": hp, "max_hp": max_hp}
