class_name RockPlusFeel
extends RefCounted

## C+'s feel in one place (Step 95): how heavy each rock is, how hard one hit
## lands on it, what the pickaxe looks and sounds like at each level, and the
## stages a rock breaks in. Nothing here is economy: the rocks' HP and
## rewards and the pickaxe's damage and prices are RockPlusLevels (Step 96;
## in Step 95 they were C's RockLevels).

## A chunk breaks off at a third and at two thirds of the damage; the last
## hit shatters what is left.
const STAGES: Array[float] = [0.34, 0.67]

## The pickaxe's milestones: from these levels it looks and sounds new (a
## bigger head, a trail, sparks, a glow, crystal shards, an orbiting ring, a
## deeper strike with a heavy layer under it) and takes the tier's colour.
## Since Step 96 a new one every three levels (C+'s progression gives a level
## about every three rocks), thirteen in all; past the last it stays.
const TIERS: Array[Dictionary] = [
	{"from": 0, "name": "Wooden Pickaxe", "tint": Color(1, 1, 1), "head": 1.0, "trail": false, "sparks": 0, "glow": false, "shards": false, "ring": false, "pitch": 1.0, "layer": ""},
	{"from": 3, "name": "Copper Pickaxe", "tint": Color("#f2a46c"), "head": 1.06, "trail": true, "sparks": 2, "glow": false, "shards": false, "ring": false, "pitch": 0.97, "layer": ""},
	{"from": 6, "name": "Iron Pickaxe", "tint": Color("#c7c9cc"), "head": 1.12, "trail": true, "sparks": 3, "glow": false, "shards": false, "ring": false, "pitch": 0.94, "layer": ""},
	{"from": 9, "name": "Steel Pickaxe", "tint": Color("#dfe6ee"), "head": 1.18, "trail": true, "sparks": 4, "glow": false, "shards": false, "ring": false, "pitch": 0.91, "layer": "thunk"},
	{"from": 12, "name": "Silver Pickaxe", "tint": Color("#eef3ff"), "head": 1.23, "trail": true, "sparks": 5, "glow": false, "shards": false, "ring": false, "pitch": 0.88, "layer": "thunk"},
	{"from": 15, "name": "Golden Pickaxe", "tint": Color("#ffd34d"), "head": 1.28, "trail": true, "sparks": 6, "glow": true, "shards": false, "ring": false, "pitch": 0.85, "layer": "thunk"},
	{"from": 18, "name": "Ruby Pickaxe", "tint": Color("#ff8da0"), "head": 1.32, "trail": true, "sparks": 7, "glow": true, "shards": false, "ring": false, "pitch": 0.83, "layer": "thunk"},
	{"from": 21, "name": "Jade Pickaxe", "tint": Color("#8ff5c0"), "head": 1.36, "trail": true, "sparks": 7, "glow": true, "shards": false, "ring": false, "pitch": 0.81, "layer": "thunk"},
	{"from": 24, "name": "Crystal Pickaxe", "tint": Color("#a6f4ff"), "head": 1.4, "trail": true, "sparks": 8, "glow": true, "shards": true, "ring": false, "pitch": 0.79, "layer": "thunk"},
	{"from": 27, "name": "Amethyst Pickaxe", "tint": Color("#d4b0ff"), "head": 1.44, "trail": true, "sparks": 8, "glow": true, "shards": true, "ring": false, "pitch": 0.77, "layer": "thunk"},
	{"from": 30, "name": "Starmetal Pickaxe", "tint": Color("#b9c8ff"), "head": 1.48, "trail": true, "sparks": 9, "glow": true, "shards": true, "ring": true, "pitch": 0.75, "layer": "thunk"},
	{"from": 33, "name": "Sunforged Pickaxe", "tint": Color("#ffb347"), "head": 1.52, "trail": true, "sparks": 10, "glow": true, "shards": true, "ring": true, "pitch": 0.73, "layer": "thunk"},
	{"from": 36, "name": "Mythic Pickaxe", "tint": Color("#ff5ec8"), "head": 1.56, "trail": true, "sparks": 10, "glow": true, "shards": true, "ring": true, "pitch": 0.71, "layer": "thunk"},
]

## Two hit sounds never start closer than this (two taps in one frame are
## one sound, not a doubled one).
const SOUND_GAP := 0.04
## The most chips, pieces, sparks and puffs in the air at once.
const MAX_BITS := 140
## Where the damage number rises from, above the hit: higher under a finger
## (the finger covers the spot it hits), lower under a mouse.
const NUMBER_LIFT_TOUCH := 120.0
const NUMBER_LIFT_MOUSE := 56.0
## The press-and-hold experiment (`?alt=hold`, dev only): one hit every
## HOLD_PERIOD seconds of play while the press stays on the rock -- a little
## slower than a natural 2.5 taps a second, so it is never the better deal.
const HOLD_PERIOD := 0.45


static func tier_index(pick: int) -> int:
	var out := 0
	for i in TIERS.size():
		if pick >= int(TIERS[i]["from"]):
			out = i
	return out


static func tier(pick: int) -> Dictionary:
	return TIERS[tier_index(pick)]


## Whether reaching `pick` changes the pickaxe's look and sound (not just its tint).
static func is_milestone(pick: int) -> bool:
	return pick > 0 and tier_index(pick) != tier_index(pick - 1)


## How heavy a rock feels: 1 for a first-sized boulder, more for each bigger
## one, a kind's big one heavier and a crystal heaviest. Heavier rocks squash and jolt less, sound
## lower, break into more pieces and hold the breaking moment longer.
static func weight(r: Dictionary) -> float:
	return float(r["radius"]) / 120.0 * (1.25 if bool(r["goal"]) else 1.0)


## How hard one hit lands, 0.25..1: the share of the rock one hit takes. The
## usual hit (about forty to a rock) is near the middle; a strong pickaxe on
## a small rock is a full 1.
static func impact(damage: int, max_hp: int) -> float:
	return clampf(sqrt(float(damage) / float(maxi(max_hp, 1)) * 12.0), 0.25, 1.0)


## The sound of one hit: stone knocks, ore rings, gems and crystal chime
## (ringing, higher) -- the rock's `sound`, or for C's rocks ore from the
## fifth on; heavier rocks and heavier pickaxes sound lower; a hard hit with
## a steel or better pickaxe adds a low thunk under it. Restrained: never
## louder than -2 dB.
static func hit_sound(r: Dictionary, pick: int, p_impact: float) -> Dictionary:
	var w := weight(r)
	var t := tier(pick)
	var voice := String(r.get("sound", "metal" if int(r["index"]) >= 4 or bool(r["goal"]) else "stone"))
	var ringing := voice != "stone"
	var pitch := float(t["pitch"]) / sqrt(w) * (1.2 if voice == "glass" or bool(r["goal"]) else 1.0)
	var layer := String(t["layer"]) if p_impact >= 0.4 else ""
	return {"name": "metal" if ringing else "pick", "pitch": pitch, "db": -4.0 + 2.0 * p_impact,
		"layer": layer, "layer_pitch": 0.95 / sqrt(w), "layer_db": -12.0 + 4.0 * p_impact}


## How many pieces a rock shatters into: 8 for the first, 16 for the crystal.
static func shatter_pieces(r: Dictionary) -> int:
	return clampi(int(round(8.0 + 8.0 * (weight(r) - 1.0))), 8, 16)


## How long the breaking moment holds (the rock flashes, then flies apart),
## in seconds of play: longer for heavier rocks.
static func break_hold(r: Dictionary) -> float:
	return 0.06 + 0.05 * (weight(r) - 1.0)


## The damage number's size: bigger for harder hits.
static func number_size(p_impact: float) -> int:
	return int(round(30.0 + 28.0 * p_impact))
