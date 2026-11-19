class_name PopSoundscape
extends RefCounted

## Step 43: how loud each of the factory's beds is, from what is really running
## (design/SOUND.md section 3). It decides levels only; the beds themselves are
## PopAudio's looping players on the Ambient bus.
##
##   hum     the kitchen's machines -- barely there with one kettle, a warm floor with thirty
##   belt    the belts' rollers -- only while a belt runs (a stopped line is silent)
##   chug    the industrial rhythm -- it fades in only once the factory is crowded (9 to 24 running)
##   murmur  the shop's customers -- a small town's storefront as the queue grows
##
## Every level is under the bed's ceiling (BED_DB) and the audio's headroom, so
## all four at their loudest sum far under full scale (measured: specs/sound43).

const BED_DB := {"hum": -15.0, "belt": -18.0, "chug": -18.0, "murmur": -15.0}
const SILENT := -80.0
const KITCHEN_FULL := 30.0   ## kitchen machines at which the hum is at its ceiling
const BELTS_FULL := 6.0
const CHUG_FROM := 8         ## running machines: above this the rhythm starts (the 'crowded' tier)
const CHUG_FULL := 24
const PEOPLE_FULL := 14.0


## 0 when `n` is 0; `floor_gain` at one; rising like a square root to 1 at `full`.
static func gain(n: float, full: float, floor_gain: float) -> float:
	if n <= 0.0:
		return 0.0
	return floor_gain + (1.0 - floor_gain) * sqrt(clampf(n / full, 0.0, 1.0))


static func _db(bed: String, g: float) -> float:
	return SILENT if g <= 0.0 else float(BED_DB[bed]) + linear_to_db(g)


## `kitchen` machines running on the kitchen floor, `belts` belts moving,
## `running` machines running in all, `people` customers in the shop.
static func targets(kitchen: int, belts: int, running: int, people: int) -> Dictionary:
	var chug := 0.0
	if running > CHUG_FROM:
		chug = clampf(float(running - CHUG_FROM) / float(CHUG_FULL - CHUG_FROM), 0.06, 1.0)
	return {
		"hum": _db("hum", gain(kitchen, KITCHEN_FULL, 0.2)),
		"belt": _db("belt", gain(belts, BELTS_FULL, 0.4)),
		"chug": _db("chug", chug),
		"murmur": _db("murmur", gain(maxf(0.0, people - 1.0), PEOPLE_FULL, 0.25)),
	}
