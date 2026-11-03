class_name RockPlusFeel
extends RefCounted

## C+'s feel in one place (Step 95): how heavy each rock is, how hard one hit
## lands on it, what the pickaxe looks and sounds like at each level, and the
## stages a rock breaks in. Nothing here touches the economy: the rocks' HP
## and rewards and the pickaxe's damage and prices are RockLevels -- exactly
## C's, so C and C+ pay the same for the same taps.

## A chunk breaks off at a third and at two thirds of the damage; the last
## hit shatters what is left.
const STAGES: Array[float] = [0.34, 0.67]

## The pickaxe's milestones: from these levels it looks and sounds new (a
## bigger head, a trail, sparks, a glow, crystal shards, a deeper strike with
## a heavy layer under it). Between them only its tint changes (RockLevels.TINT).
const TIERS: Array[Dictionary] = [
	{"from": 0, "name": "Wooden Pickaxe", "head": 1.0, "trail": false, "sparks": 0, "glow": false, "shards": false, "pitch": 1.0, "layer": ""},
	{"from": 3, "name": "Copper Pickaxe", "head": 1.1, "trail": true, "sparks": 3, "glow": false, "shards": false, "pitch": 0.95, "layer": ""},
	{"from": 5, "name": "Steel Pickaxe", "head": 1.2, "trail": true, "sparks": 5, "glow": false, "shards": false, "pitch": 0.9, "layer": "thunk"},
	{"from": 7, "name": "Golden Pickaxe", "head": 1.3, "trail": true, "sparks": 7, "glow": true, "shards": false, "pitch": 0.85, "layer": "thunk"},
	{"from": 9, "name": "Crystal Pickaxe", "head": 1.4, "trail": true, "sparks": 9, "glow": true, "shards": true, "pitch": 0.8, "layer": "thunk"},
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


## How heavy a rock feels: 1 for the first boulder, more for each bigger one,
## and the Giant Crystal heaviest. Heavier rocks squash and jolt less, sound
## lower, break into more pieces and hold the breaking moment longer.
static func weight(r: Dictionary) -> float:
	return float(r["radius"]) / 120.0 * (1.25 if bool(r["goal"]) else 1.0)


## How hard one hit lands, 0.25..1: the share of the rock one hit takes. The
## usual hit (about forty to a rock) is near the middle; a strong pickaxe on
## a small rock is a full 1.
static func impact(damage: int, max_hp: int) -> float:
	return clampf(sqrt(float(damage) / float(maxi(max_hp, 1)) * 12.0), 0.25, 1.0)


## The sound of one hit: stone knocks, ore and crystal ring; heavier rocks
## and heavier pickaxes sound lower; a hard hit with a steel or better
## pickaxe adds a low thunk under it. Restrained: never louder than -2 dB.
static func hit_sound(r: Dictionary, pick: int, p_impact: float) -> Dictionary:
	var w := weight(r)
	var t := tier(pick)
	var ringing := int(r["index"]) >= 4 or bool(r["goal"])
	var pitch := float(t["pitch"]) / sqrt(w) * (1.2 if bool(r["goal"]) else 1.0)
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
