extends RefCounted
class_name Defs

## Single source of truth for balance numbers, palette and machine data.
## Keeping this data-driven means tuning the game never requires touching logic.

const TILE := 32

# --- Art direction -----------------------------------------------------------
# A cold navy world so that anything warm reads as valuable. Every warm hue in
# the game belongs to the player's factory; the environment never uses them.
const COL_VOID := Color("0e1320")
const COL_SNOW_COLD := Color("222c44")

## The ramp is computed in HSV rather than interpolated in RGB. A straight RGB
## lerp toward the navy night rotated the hue through red into magenta and
## dropped saturation to 0.17, which is what made the outer pool read as mud.
## Hue and saturation are held; only value and alpha fall off.
const COL_GRID := Color8(96, 116, 156)
const COL_CORE := Color("ffb347")
const COL_CORE_DEEP := Color("e0702a")
const COL_BRASS := Color("d8a34a")
const COL_MACHINE := Color("2f6d72")
## Machines are self-lit so they never rely on the ground for contrast.
## The belt used to sit at hue 222 - the same family as the cold it is fighting -
## so every belt read as a hole punched in the warm floor. It now shares the
## factory's warm hue and is separated from the ground by value, not colour.
## Two reviews pulled in opposite directions here. Making the belt warm fixed it
## reading as "the enemy's colour" but left it at 1.5-3.5:1 against a warm floor.
## The resolution is a cool steel body -- which separates from the amber ground by
## hue and value -- carrying warm emissive accents, so the light still belongs to
## the player while the object stays readable on both grounds.
const COL_BELT_BODY := Color8(56, 67, 79)
const COL_BELT_BODY_COLD := Color8(38, 46, 56)
const COL_BELT_RIM := Color8(255, 211, 160)
const COL_BELT_GLOW := Color8(255, 154, 60)
const COL_BELT_CHEVRON := Color8(255, 196, 120)
const COL_FROZEN_CHEVRON := Color8(120, 140, 160)
const COL_VALID := Color8(120, 220, 140)
const COL_PANEL := Color8(16, 21, 34)
const COL_PANEL_EDGE := Color8(70, 82, 108)
const COL_CLOCK := Color8(150, 164, 190)
const COL_CLOCK_FILL := Color8(120, 150, 190)
const COL_MACHINE_EDGE := Color("6fd2c8")
const COL_CAT_FUR := Color8(168, 90, 36)
const COL_CAT_FACE := Color8(250, 226, 190)
## The SSR cat, which is a pig. Warm, like everything the player earns, but a
## pink that no machine and no ore uses, so half a second of it on screen is
## unmistakably the rare thing rather than another amber light.
const COL_PIG_BODY := Color8(242, 168, 186)
const COL_PIG_SNOUT := Color8(212, 118, 144)
const COL_DANGER := Color("e8574c")
const COL_TEXT := Color("e6eef7")
const COL_TEXT_DIM := Color("8fa0bd")

# --- Items -------------------------------------------------------------------
## Three materials, in the order the player meets them. Crystal is hand-mined
## from the first minute; copper needs a miner and the warmth to reach it; energy
## is the only thing the core turns into heat.
const ITEM_CRYSTAL := 0
const ITEM_COPPER := 1
const ITEM_ENERGY := 2

const ITEM_NAMES := ["수정조각", "구리광석", "에너지결정"]
## Short forms for the status panel, where three counters share one row.
const ITEM_SHORT := ["수정", "구리", "에너지"]
## Ember was a muddy brown against the cold ground (1.66:1); copper reads as a
## valuable metal and clears 6:1.
## The copper seam sat at 1.99:1 against the night and shared a hue band with the warm
## ground, so it vanished exactly when the player was told to go find it.
const ITEM_COLORS := [Color8(127, 212, 232), Color8(252, 104, 46), Color8(255, 217, 138)]
const COPPER_CORE := Color8(255, 238, 205)
const ORE_OUTLINE := Color8(28, 20, 18)

# --- Object drawing language --------------------------------------------------
## An audit of the world layer found nine objects using three different shadow
## styles, body footprints from 20 to 28 px, twelve one-off colours and no shared
## light direction. That is what makes a scene look assembled rather than
## designed, so every object now obeys the same four rules:
##
##   1. Light comes from the top-left. A raised body lightens its top and left
##      faces and darkens its bottom and right ones.
##   2. Anything standing on the plateau casts the same squashed shadow, at its
##      base, in one colour.
##   3. Every body carries the same near-black outline. Outlines are never
##      coloured -- colour is for identity, not for edges.
##   4. Objects that lie flat on the ground (belts, dropped items) are inset and
##      shadowless; objects that stand up are raised and cast one.
##
## Warm hues stay reserved for the player's factory and its light; the
## environment is never warm.
const OUTLINE := Color8(16, 20, 28)
const SHADOW := Color(0.02, 0.04, 0.08, 0.34)
const SHADOW_SQUASH := 0.42
## One footprint for every machine, so they read as one class of object.
const MACHINE_BODY := 23.0

## What frost does to a machine's art. Every machine that is drawn from a texture
## is tinted toward this rather than swapping to a second colour, so a half
## frozen factory reads as one condition instead of as several.
const COL_FROST_TINT := Color(0.60, 0.70, 0.86)

## The four orthogonal neighbours, in one place. Belts read these to work out
## which way things arrive, and every copy of this list that lives somewhere else
## is a copy that can disagree about the order.
const STEPS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1),
]
const FACE_LIGHT := 0.20
const FACE_DARK := 0.24
const FACE_BAND := 3.0
## Only energy crystals become heat. Crystal and copper are materials: they go
## into the base's stock and are spent on machines. Splitting the build currency
## from the progress meter is what gives the player something to decide -- heat
## buys distance, materials buy production, and the exchanger is where you choose
## between them.
##
## Five was derived, not guessed. Reaching copper at radius 11 needs 182 heat;
## two miners over three days produce about 72 crystal, which is 36 energy at the
## 2:1 exchange, so each energy crystal has to be worth 182/36 ~= 5.
const ITEM_VALUES := [0, 0, 5]
const COUNTED_ITEMS: Array[int] = [ITEM_CRYSTAL, ITEM_COPPER, ITEM_ENERGY]

## Hand mining. Deliberately slow: it is the floor the whole factory is measured
## against, and it has to stay worth replacing.
const HAND_MINE_PERIOD := 10.0
## Crystal in, energy out. Two-to-one at five seconds means one exchanger keeps
## up with four miners, so miners stay the bottleneck rather than the converter.
const CRYSTAL_COST_ENERGY := 2

## --- Exchanger recipes --------------------------------------------------------
## The device this genre uses to turn efficiency from an answer into a choice.
## Neither of these is a straight upgrade: the second stretches crystal much
## further and produces more, but it eats copper -- and copper is also what
## generators, belts and splitters are made of, and it mines at half the rate.
## So the right recipe depends on which resource your map and your factory have
## spare, which is exactly the question a dominant strategy would erase.
const RECIPE_PLAIN := 0
const RECIPE_ALLOY := 1
const RECIPES := [
	{"in": {ITEM_CRYSTAL: 2}, "out": 1, "period": 5.0, "name": "기본"},
	{"in": {ITEM_CRYSTAL: 2, ITEM_COPPER: 1}, "out": 3, "period": 10.0, "name": "구리 촉매"},
]

## Recipes open the same way machines do: by holding the resource once.
const RECIPE_UNLOCK_ITEM := [-1, ITEM_COPPER]

static func recipe_line(index: int) -> String:
	var recipe: Dictionary = RECIPES[index]
	var parts: Array[String] = []
	for item_type: int in recipe["in"]:
		parts.append("%s %d" % [ITEM_SHORT[item_type], int(recipe["in"][item_type])])
	return "%s → 에너지 %d · %.0f초" % [" + ".join(parts), int(recipe["out"]), float(recipe["period"])]

## Energy per minute for a recipe, and crystal spent per energy produced. The
## second number is the one that makes the trade legible.
static func recipe_rate(index: int) -> float:
	var recipe: Dictionary = RECIPES[index]
	return float(recipe["out"]) * per_minute(float(recipe["period"]))

static func recipe_crystal_cost(index: int) -> float:
	var recipe: Dictionary = RECIPES[index]
	return float(recipe["in"].get(ITEM_CRYSTAL, 0)) / float(recipe["out"])
const EXCHANGER_PERIOD := 5.0
const COPPER_PERIOD := 20.0

## --- Throughput ---------------------------------------------------------------
## Published on purpose. The pleasure in this genre is making numbers line up,
## and a number the player cannot see is a number they cannot plan around: it
## turns ratio design into trial and error. Every rate below is derived from the
## periods above rather than typed twice.
static func per_minute(seconds: float) -> float:
	return 60.0 / maxf(seconds, 0.001)

## One line per machine describing what it does per minute, for the hotbar and
## for the readout over a machine the player is facing.
static func throughput_line(type: int) -> String:
	match type:
		M_MINER:
			return "수정 %.0f/분 · 고양이 또는 전력 %.1f" % [per_minute(MINER_PERIOD), MINER_POWER_DRAW]
		M_EXCHANGER:
			return "수정 %.0f/분 → 에너지 %.0f/분" % [
				per_minute(EXCHANGER_PERIOD) * float(CRYSTAL_COST_ENERGY),
				per_minute(EXCHANGER_PERIOD)]
		M_GENERATOR:
			return "에너지 %.0f/분 → 전력 %.1f" % [per_minute(GENERATOR_PERIOD), GENERATOR_OUTPUT]
		M_BELT:
			return "%.0f/분 · 칸당 %.1f초 · F로 등급" % [BELT_SPEED / 0.34 * 60.0, 1.0 / BELT_SPEED]
		M_SPLITTER:
			return "한 줄을 두 줄로 · R로 나뉘는 축 회전"
		M_CORE:
			return "에너지결정 1개 = 열 %d" % ITEM_VALUES[ITEM_ENERGY]
	return ""

## The ratio that actually matters, stated plainly. One exchanger keeps up with
## four miners; a player who knows that builds in fours.
static func ratio_hint() -> String:
	var miners: float = (per_minute(EXCHANGER_PERIOD) * float(CRYSTAL_COST_ENERGY)) / per_minute(MINER_PERIOD)
	return "교환기 1대 = 채굴기 %.0f대" % miners

# --- Electricity -------------------------------------------------------------
## Power is a rate, not a stock: it never accumulates, so there is no battery to
## manage. A generator burns one energy crystal every ten seconds to sustain one
## unit of capacity, and machines reserve a share of it. Running out does not
## break anything -- everything drawing power simply slows in proportion.
const GENERATOR_PERIOD := 10.0
const GENERATOR_OUTPUT := 1.0
## Belts do not draw power, and must not. They used to, at 0.1 each, which meant
## that before the first generator existed the grid had capacity zero against a
## non-zero draw -- and the supply ratio that every belt multiplied its speed by
## came out at exactly zero. Belts placed in the ordinary early game simply never
## moved, and whatever fed them reported a blocked output. The belt unlocks on
## the first copper and the generator needs ten of it plus crystals to burn, so
## requiring power to run a belt inverts the progression: logistics would depend
## on the tier that logistics is supposed to lead to.
## Power's job is stated in the design doc and is only this: it runs a miner that
## has no cat. Nothing else asks the grid for anything.
## What an unstaffed miner asks of the grid. This is the moment electricity stops
## being a tax on belts and becomes the thing that scales the factory: early on a
## miner needs a cat, and a cat comes from exploring, so the factory is capped by
## how far the player has walked rather than by anything they can engineer. Once
## power exists, a miner can run on it instead -- and the freed cat goes back to
## hauling, which is its other job.
const MINER_POWER_DRAW := 0.5

# --- Tile attributes ---------------------------------------------------------
## Attributes describe what a tile *is*, independent of what sits on it. They are
## flags so a tile can eventually carry several at once; STRUCTURE is the first.
##
## STRUCTURE: solid terrain. The player cannot walk through it and cannot pick it
## up with Z. Ore seams are structures -- they are part of the landscape, not
## loose objects.
const ATTR_NONE := 0
const ATTR_STRUCTURE := 1 << 0

const ATTR_NAMES := {ATTR_STRUCTURE: "구조물"}

## How much of a tile the player's body occupies, used for collision.
const PLAYER_RADIUS := 9.0

# --- Debug ---------------------------------------------------------------------
## Time multipliers for testing. A day is three minutes and the progression is
## measured in days, so watching a run reach copper honestly takes ten minutes of
## real time -- which makes "play it to the end and see how it feels" a thing
## nobody does. This exists so that check is cheap enough to actually perform.
##
## Applied through Engine.time_scale rather than by scaling the sim tick, so it
## moves everything at once: machines, cats, the day clock, warmth, the player,
## and every animation that accumulates delta. A speed-up that left one system
## running at normal rate would be worse than none, because it would silently
## change the balance being observed.
const DEBUG_SPEEDS: Array[float] = [1.0, 4.0, 10.0]
## How many cats the debug unlock tops the crew up to. Three, because one cat
## tells you nothing about whether a line of them steps in unison.
const DEBUG_CATS := 3

## How far apart cats stand when they line up on the doorstep.
##
## A cat is drawn about 58 pixels wide now, of which roughly 30 is body. At 16 --
## the old value, from when a cat was drawn 44 wide and mostly padding -- three
## of them standing together overlap almost completely, and each one's body
## covers the next one's shadow and hunger bar. What that looks like in the game
## is not "cats are close together", it is "the cats have come loose from their
## own shadows", which is how it was reported.
const CAT_LANE := 30.0

# --- Gacha -------------------------------------------------------------------
## Cats have grades now, and the slot machine is where the rare ones come from.
##
## The five grades are the player's own table, kept in exactly the order and the
## numbers they were promised. Cumulative thresholds would be the same
## information, but nobody can read "60 / 93 / 98 / 99.5" and check it against
## what the window says -- so the percentages that roll are the percentages that
## are drawn, and roll_rarity is what turns one into the other.
const RARITY_O := 0
const RARITY_N := 1
const RARITY_R := 2
const RARITY_SR := 3
const RARITY_SSR := 4

const RARITY_NAMES: Array[String] = ["O", "N", "R", "SR", "SSR"]
const RARITY_PERCENT: Array[float] = [60.0, 33.0, 5.0, 1.5, 0.5]
## Cool for the common ones and warm for the rare ones, which is the same rule
## the rest of the game follows: warmth belongs to what the player earned.
const RARITY_COLORS: Array[Color] = [
	Color8(140, 154, 178), Color8(190, 204, 224), Color8(120, 220, 140),
	Color8(186, 138, 246), Color8(255, 196, 84),
]

## What a grade is worth at a miner, as a multiplier on the work it does.
##
## O is exactly one, and that is deliberate: a cat carried home in a crate is an
## O cat, so the whole existing economy stays where it was and the gacha can only
## ever add. A grade is not a different job -- it is the same cat, faster -- so
## this is the only number a grade changes. Hunger still bites on top of it:
## a starving SSR works at three times a third, not at three.
const RARITY_WORK_RATE: Array[float] = [1.0, 1.2, 1.5, 2.0, 3.0]

## One coin, one cat. The three buttons are just three of them at once, which is
## why there is one price rather than a discount for volume: a bulk rate would
## make the single pull a mistake, and the single pull is the one that teaches
## the player what the machine does.
const GACHA_COUNTS: Array[int] = [1, 3, 10]
const GACHA_SPIN_SECONDS := 3.0
## What the debug key tops the purse up to. Enough for three ten-pulls, so the
## rare end of the table can actually be seen without playing for it.
const DEBUG_COINS := 30

## Which grade a 0..100 roll lands on. Walks the published percentages in order,
## so the table on screen and the table that decides are the same array.
static func roll_rarity(roll: float) -> int:
	var edge: float = 0.0
	for index in RARITY_PERCENT.size():
		edge += RARITY_PERCENT[index]
		if roll < edge:
			return index
	# Only reachable through floating-point slop at the very top of the range,
	# where the rarest grade is what the player was owed.
	return RARITY_PERCENT.size() - 1

# --- Machines ----------------------------------------------------------------
const M_CORE := 0
const M_MINER := 1
const M_BELT := 2
const M_EXCHANGER := 3
const M_GENERATOR := 4
const M_SPLITTER := 5

## Hotbar order is the order they unlock, so the row grows left to right as the
## player earns it rather than showing four greyed slots on the first frame.
const BUILDABLE: Array[int] = [M_MINER, M_EXCHANGER, M_BELT, M_SPLITTER, M_GENERATOR]

## The machines you can walk over. Everything else is a solid object standing on
## the plateau, which is what a picture of a drill or a furnace already says.
##
## Written as the exceptions rather than as the list of things that block, so a
## machine added later blocks by default. That is the safe direction to be wrong
## in: a new machine you cannot walk through is a moment's annoyance, and one you
## can walk through is a player strolling out of the middle of a furnace.
##
## Belts and splitters are floor. They are laid along routes people and cats use,
## and the whole point of a belt is to run between places rather than to stand
## between them.
const WALKABLE_MACHINES: Array[int] = [M_BELT, M_SPLITTER]

const MACHINE_NAMES := ["열 코어", "채굴기", "컨테이너 벨트", "수정에너지교환기", "발전기", "분배기"]
## Hotbar cards are one slot wide and the full names do not fit beside the colour
## swatch. The long name still appears in the hint line above the row.
const MACHINE_SHORT := ["코어", "채굴기", "벨트", "교환기", "발전기", "분배기"]
## Machines are bought with materials now, never with heat.
const MACHINE_COSTS := [
	{},
	{ITEM_CRYSTAL: 5},
	{ITEM_COPPER: 3},
	{ITEM_CRYSTAL: 20},
	{ITEM_COPPER: 10},
	{ITEM_COPPER: 2},
]
const MACHINE_HINTS := [
	"",
	"수정 광맥 위에 설치하고 고양이를 올려놓으세요",
	"자원을 기지까지 끊김 없이 나릅니다",
	"수정조각 2개를 에너지결정 1개로 바꿉니다",
	"에너지결정을 태워 전력 1.0을 공급합니다",
	"한 줄로 들어온 자원을 여러 줄로 균등하게 나눕니다",
]

## What goes in and what comes out, for the build menu. A machine with nothing
## going in states the property that defines it instead: for a belt the useful
## sentence is that it never needs power, not an empty input line.
static func machine_io(type: int) -> Array[String]:
	match type:
		M_MINER:
			return ["입력   없음 · 광맥 위에만 설치",
				"출력   광맥의 자원 %.0f/분" % per_minute(MINER_PERIOD),
				"일손   고양이 1마리 또는 전력 %.1f" % MINER_POWER_DRAW]
		M_EXCHANGER:
			var recipe: Dictionary = RECIPES[RECIPE_PLAIN]
			return ["입력   수정조각 %d" % int(recipe["in"][ITEM_CRYSTAL]),
				"출력   에너지결정 %d · %.0f초마다" % [int(recipe["out"]), float(recipe["period"])],
				"제법   F로 전환 · 구리 촉매는 한 번에 3개"]
		M_BELT:
			return ["입력   뒤쪽에서 받음",
				"출력   앞쪽으로 %.0f/분" % (BELT_SPEED / 0.34 * 60.0),
				"특성   전력이 필요 없음 · F로 등급 변경"]
		M_SPLITTER:
			return ["입력   한 줄",
				"출력   좌우 두 줄로 번갈아",
				"특성   막힌 쪽은 건너뜀 · R로 축 회전"]
		M_GENERATOR:
			return ["입력   에너지결정 1 · %.0f초마다" % GENERATOR_PERIOD,
				"출력   전력 %.1f" % GENERATOR_OUTPUT,
				"특성   전력은 저장되지 않는 비율"]
	return []

## What each machine needs before it appears in the hotbar. The first crystal in
## hand opens the crystal line; the first copper opens the power line.
const MACHINE_UNLOCK_ITEM := [-1, ITEM_CRYSTAL, ITEM_COPPER, ITEM_CRYSTAL, ITEM_COPPER, ITEM_COPPER]

# --- Economy -----------------------------------------------------------------
## Days repeat and accumulate rather than ending the game, so one day is short
## enough that the dusk-to-dawn arc is felt several times in a sitting.
const DAY_SECONDS := 180.0
const START_HEAT := 30
## Deliberately slow: one cat is a trickle, so throughput has to come from more
## miners and better routing rather than from a single well-placed worker.
## Matched to hand mining on purpose. A miner is not faster than the player --
## it is somewhere else while the player is here, which makes the first one read
## as parallelism rather than as a speed upgrade. It also makes one exchanger
## exactly absorb four miners.
const MINER_PERIOD := 10.0
const FURNACE_PERIOD := 2.2
## Deliberately slow. A tenth of what it used to be, which puts a ten-tile run at
## about 38 seconds: never a hard throughput gate -- it still carries nearly four
## times a pure seam's output -- but slow enough that a long line starts to feel
## like something you would rather not wait for. That feeling is what makes the
## grades worth having, and grade 3 restores exactly the old speed.
const BELT_SPEED := 0.26          # tiles per second

## --- Belt grades --------------------------------------------------------------
## Deliberately not a throughput gate. Grade 1 already carries far more than
## every miner in the game put together, so grades buy latency -- how fast a
## thing you just made reaches the core -- and nothing else. That makes them a
## convenience the player may ignore entirely, which is the intent: this game
## should never make you rebuild a working line to keep up.
const BELT_TIERS := [
	{"name": "벨트", "speed": 1.0, "cost": 3},
	{"name": "고속 벨트", "speed": 3.0, "cost": 9},
	{"name": "초고속 벨트", "speed": 10.0, "cost": 30},
]

static func belt_speed(tier: int) -> float:
	return BELT_SPEED * float(BELT_TIERS[clampi(tier, 0, BELT_TIERS.size() - 1)]["speed"])
const BELT_CAPACITY := 3
## A splitter holds a little so a momentary block on one branch does not stall
## the line feeding it.
const SPLITTER_CAPACITY := 3
const SPLITTER_PERIOD := 0.25
## Seconds the throughput meter averages over. Long enough that a miner on a
## ten-second cycle contributes several items -- a window shorter than a couple
## of cycles reports a square wave rather than a rate -- and short enough that
## fixing a starved line shows up while the player is still standing there.
const METER_WINDOW := 30.0
const FROST_COST_IRON := 1
const COPPER_COST_IRON := 1

## Warmth grows with everything the core has ever received, so investing in the
## factory is what expands the map rather than hoarding.
const WARM_BASE := 7.0
const WARM_PER_HEAT := 0.022
const WARM_MAX := 22.0

const COLD_DRAIN := 13.0          # warmth lost per second outside the radius
## Night is the reason to go home. Once it falls the warm pool is no longer
## enough on its own, so standing next to the core all night is not a strategy:
## the shelter is.
const NIGHT_SECONDS := 50.0
const DUSK_SECONDS := 95.0
const NIGHT_DRAIN := 7.5          # warmth lost per second at night even when warm
## How far in front of the player a carried cat rides, in tiles. Small enough to
## read as "in her arms" rather than as a cat standing on the next tile, but far
## enough that the carry is visible at a glance.
const CARRY_AHEAD := 0.3

## Whole tiles, not a half-tile offset. The shelter is a building that occupies
## one cell of the grid exactly, like the core, so it can be a structure the
## player walks around rather than a decal they walk through.
const SHELTER_CELL := Vector2i(-3, 3)
## Measured from the cell centre, so standing on any of the four neighbouring
## tiles counts as being at the door.
const SHELTER_REACH := 62.0
const FOOD_OFFSET := Vector2(-4.5, 2.5)

# --- Cat workers -------------------------------------------------------------
## A miner is a machine, not a worker. It only runs while a cat stands at it,
## so automation is gated on adopting cats rather than on spending heat.
const CAT_SPEED := 46.0            # pixels per second while walking
## No longer an arrival threshold: a cat arrives by standing on the spot. Kept as
## a name for "comfortably away from it", which is what tests need when they want
## a cat that has not got there yet.
const CAT_AWAY := 10.0

## Loitering. A cat with nothing to do used to stand exactly still, which reads
## as the game being paused rather than as an animal waiting, so it strolls: a
## pause, a short walk in some direction, another pause. The numbers are ranges
## because a fixed rhythm is its own kind of stillness -- four cats stepping on
## the same beat look like one animation played four times.
const WANDER_PAUSE := Vector2(2.0, 6.0)    # seconds of standing
const WANDER_STROLL := Vector2(0.5, 1.5)   # seconds of walking
## Ambling, not commuting. A cat crossing the base to reach a machine has
## somewhere to be and moves at CAT_SPEED; one killing time does not.
const WANDER_SPEED := 0.55
## How far from the hut a loitering cat may drift before it is steered back. Far
## enough to look free, near enough that the crew is still where the player left
## it -- a cat that wandered out of the warm radius would look lost, and the
## player would go looking for it.
const WANDER_LEASH := 96.0
const BOXES_PER_CAT := 3
## Crate density: one per this many tiles of world. Raised by half on request --
## cats are what gate automation, so how many crates the map holds is the pace at
## which the factory is allowed to grow.
const CAT_BOX_PER_TILES := 66.7
const STARTER_CAT_BOXES := 3

## Hunger runs 0..1. Working costs 1/18 every ten seconds, so a fed cat works
## about three real minutes before it needs the food bin.
const HUNGER_PER_SECOND := (1.0 / 18.0) / 10.0
const HUNGER_STARVED_RATE := 1.0 / 3.0    # work speed multiplier at zero hunger
const FOOD_START := 200
const FOOD_SECONDS_PER_UNIT := 5.0
const FOOD_HUNGER_PER_UNIT := 1.0 / 3.0

## An idle cat is not decoration: it looks for loose items and walks them to the
## base, one at a time. Slow and single-file on purpose -- it clears the floor
## before belts exist, and it degrades with distance so belts stay worth building.
const CAT_HAUL_TO_ITEM := 5
const CAT_HAUL_TO_BASE := 6

const CAT_IDLE := 0
const CAT_TO_MINER := 1
const CAT_WORKING := 2
const CAT_TO_FOOD := 3
const CAT_EATING := 4
## Nightfall: everyone walks back to the hut and stays there until morning.
const CAT_TO_SHELTER := 7
const CAT_ASLEEP := 8

## The states in which a cat is crossing the ground. Kept here rather than
## written out at the one place that draws it, because it was written out there
## and two of the five were missing: a cat fetching a dropped rock and carrying
## it back to the core covers most of the map on its own legs, and did it
## playing the standing sheet. Anything that calls _step_toward belongs in this
## list, and there are exactly five such handlers.
const CAT_WALKING_STATES: Array[int] = [
	CAT_TO_MINER, CAT_TO_FOOD, CAT_TO_SHELTER, CAT_HAUL_TO_ITEM, CAT_HAUL_TO_BASE,
]

## --- The night sequence ------------------------------------------------------
## The day does not simply cut to a summary card. The workforce walks home, the
## lamp goes on, and the hut spends five seconds turning from night to morning.
## It is the one moment the game is not asking the player to do anything, which
## is what makes the factory they built visible to them.
##
## Every phase is bounded. A cinematic that can wait indefinitely for a cat that
## got stuck is a cinematic that will eventually hang the game.
const NIGHT_GATHER_MAX := 7.0      ## after this the stragglers are simply home
const NIGHT_GLOW_SECONDS := 2.2    ## lamp lit, silhouettes on the wall
const DAWN_SECONDS := 5.0          ## night -> morning
const DAWN_SPILL_SECONDS := 1.4    ## the door opens and everyone walks out
## How much closer the camera pulls in while the sequence plays. The hut is one
## tile across, so at normal zoom the silhouettes in the window are a few pixels.
const NIGHT_CAMERA_ZOOM := 1.7
const NIGHT_CAMERA_LERP := 2.6     ## per second, toward the target zoom
const COLD_RECOVER := 26.0
const RESCUE_PENALTY := 0.25      # share of banked heat lost when you black out
## Cold is a slope, not a cliff: movement degrades the whole way down so the
## player feels the danger long before the number reaches zero.
const COLD_SPEED_FLOOR := 0.10    # movement multiplier at zero warmth
const FROST_STAGES: Array[float] = [80.0, 50.0, 20.0]
const COLLAPSE_GRACE := 5.0       # seconds upright at zero warmth
const COLLAPSE_FALL := 2.0        # seconds of the collapse animation
const BLACKOUT_SECONDS := 2.2     # the world fading out after the fall

## Feedback hierarchy. The most frequent event has to be the quietest or the
## game becomes exhausting, and the rarest has to be the loudest or milestones do
## not land. Call sites pick from this scale instead of inventing a number, which
## is how placing a belt ended up shaking the screen almost as hard as finishing
## a tech.
const FX_QUIET := 0.0        ## routine and constant: an item stepping onto a belt
const FX_SMALL := 0.6        ## frequent and expected: picking something up
const FX_MEDIUM := 1.3       ## a deliberate action: placing a machine
const FX_LARGE := 2.4        ## a real gain: energy reaching the core
const FX_MILESTONE := 3.6    ## rare and structural: a machine unlocking

const RING_SMALL := 15.0
const RING_MEDIUM := 24.0
const RING_LARGE := 40.0
const RING_MILESTONE := 58.0

## --- Node purity --------------------------------------------------------------
## Borrowed straight from Satisfactory: the same resource is worth more at some
## nodes than others, and the good ones are further out. It converts "walk
## further" from a chore into a trade, and it gives the fixed map a terrain of
## value rather than a uniform field.
const PURITY_NORMAL := 0
const PURITY_RICH := 1
const PURITY_PURE := 2
const PURITY_RATE: Array[float] = [1.0, 1.5, 2.0]
const PURITY_NAMES := ["보통", "풍부", "순수"]
const PURITY_RICH_RING := 11.0
const PURITY_PURE_RING := 17.0

const FROST_RING := Vector2(4.0, 9.5)
const COPPER_RING := Vector2(11.0, 17.0)

## UI scale. The web export renders at the device pixel ratio, so a phone that is
## physically 390 CSS px wide reports a ~960 px logical viewport: every constant
## below lands at roughly 0.4 of the physical size it was drawn for, which made
## the HUD text about 5 CSS px tall. Touch therefore starts at 2x and desktop at
## half, and the player can trim either from the settings panel.
const UI_SCALE_TOUCH_BASE := 2.0
## Desktop was set to half size back when the HUD held a clock and two numbers.
## Measured on a 1100x760 window that put body text at about 7 device pixels --
## legible in a screenshot, not on a monitor -- and the rebuilt economy put far
## more on the panel. The floor of the slider is lowered to match, so anyone who
## preferred the small HUD can still reach it.
const UI_SCALE_DESKTOP_BASE := 0.9
const UI_SCALE_MIN := 0.45
const UI_SCALE_MAX := 1.6
## What the sliders read on a fresh install. Per platform, because the two are
## not the same question: a phone reports a logical viewport far wider than its
## physical one and needs everything enlarged just to be legible, while on a
## desktop the HUD is competing with the factory for the screen and wants to get
## out of the way.
const UI_SCALE_DEFAULT := 1.0
const UI_SCALE_DEFAULT_DESKTOP := 0.70

## Rounded to this step so the slider lands on repeatable values and the label
## never shows a number the player cannot get back to.
const UI_SCALE_STEP := 0.05

## How large the world itself is drawn, independent of the HUD. The camera has no
## authored zoom, so on a phone it shows a 960x1634 logical slice of the world at
## 1:1 -- an enormous area rendered into a small screen, which is why the player
## and the ore read as smudges. Touch therefore starts 60% zoomed in.
const GAME_SCALE_TOUCH_BASE := 1.6
const GAME_SCALE_DESKTOP_BASE := 1.0
const GAME_SCALE_MIN := 0.6
const GAME_SCALE_MAX := 1.6
const GAME_SCALE_DEFAULT := 1.0
const GAME_SCALE_DEFAULT_DESKTOP := 0.90

static func quantise_scale(value: float, low: float, high: float) -> float:
	return snappedf(clampf(value, low, high), UI_SCALE_STEP)

static func quantise_ui_scale(value: float) -> float:
	return quantise_scale(value, UI_SCALE_MIN, UI_SCALE_MAX)

static func quantise_game_scale(value: float) -> float:
	return quantise_scale(value, GAME_SCALE_MIN, GAME_SCALE_MAX)

## Eight-direction facing. The source art only contains four views (and the
## engineer's sheet only one), so a diagonal is rendered as its nearest real view
## plus a lean. That is enough to read direction at a glance without inventing
## artwork that does not exist.
const DIR_S := 0
const DIR_SE := 1
const DIR_E := 2
const DIR_NE := 3
const DIR_N := 4
const DIR_NW := 5
const DIR_W := 6
const DIR_SW := 7

const DIR_VECTORS: Array[Vector2] = [
	Vector2(0, 1), Vector2(0.7071, 0.7071), Vector2(1, 0), Vector2(0.7071, -0.7071),
	Vector2(0, -1), Vector2(-0.7071, -0.7071), Vector2(-1, 0), Vector2(-0.7071, 0.7071),
]

static func facing_index(direction: Vector2) -> int:
	if direction.is_zero_approx():
		return DIR_S
	var step: float = TAU / 8.0
	# Screen space has +y pointing south. Index 0 is south and the index rises as
	# the heading sweeps south -> east -> north -> west, which is why the angle is
	# measured down from south rather than up from east.
	var angle: float = fposmod(PI * 0.5 - direction.angle(), TAU)
	return int(round(angle / step)) % 8

## Which of the four drawn views a facing should use, and whether it is mirrored.
## Diagonals borrow the front or back view and lean, so NE and NW differ.
static func facing_view(index: int) -> Dictionary:
	match index:
		DIR_S: return {"view": "front", "flip": false, "lean": 0.0}
		DIR_SE: return {"view": "front", "flip": false, "lean": 1.0}
		DIR_E: return {"view": "right", "flip": false, "lean": 0.0}
		DIR_NE: return {"view": "back", "flip": false, "lean": 1.0}
		DIR_N: return {"view": "back", "flip": false, "lean": 0.0}
		DIR_NW: return {"view": "back", "flip": true, "lean": -1.0}
		DIR_W: return {"view": "left", "flip": false, "lean": 0.0}
		_: return {"view": "front", "flip": true, "lean": -1.0}

## --- Korean particles ----------------------------------------------------------
## 은/는, 을/를 and 이/가 are chosen by whether the preceding word ends in a final
## consonant, so a sentence built with "%s" and a fixed particle is right for
## some words and wrong for others -- and nothing about it looks wrong in the
## source.
##
## Both of the sentences that did this were wrong for every word they could ever
## receive. Every machine name in the game ends in a vowel, so "%s은 아직
## 해금되지 않았습니다" read "컨테이너 벨트은"; every material ends in a consonant, so
## "%s가 부족합니다" read "수정조각가 부족합니다" -- which is what a player sees the
## first time they try to build something they cannot afford.
##
## A Hangul syllable is 0xAC00 + (initial * 588) + (vowel * 28) + final, so the
## remainder modulo 28 is the final consonant and zero means there is none.
static func has_final(word: String) -> bool:
	if word.is_empty():
		return false
	var code: int = word.unicode_at(word.length() - 1)
	if code < 0xAC00 or code > 0xD7A3:
		return false
	return (code - 0xAC00) % 28 != 0

## Topic: 은 after a consonant, 는 after a vowel.
static func topic(word: String) -> String:
	if has_final(word):
		return "은"
	return "는"

## Object: 을 / 를.
static func object_of(word: String) -> String:
	if has_final(word):
		return "을"
	return "를"

## Subject: 이 / 가.
static func subject(word: String) -> String:
	if has_final(word):
		return "이"
	return "가"

static func machine_color(type: int) -> Color:
	match type:
		M_CORE: return COL_CORE
		M_MINER: return COL_CAT_FUR
		M_EXCHANGER: return Color8(210, 120, 52)
		M_GENERATOR: return Color8(120, 190, 235)
		M_SPLITTER: return Color8(150, 210, 160)
		M_BELT: return COL_BELT_RIM
		_: return COL_MACHINE

## Samples the amber ramp. `k` is 0 at the core and 1 at the frontier.
## Sunlit snow, not soil. The old ramp drove saturation up and value down as it
## went outward -- 0.62 saturation at 0.22 value -- which is the recipe for mud:
## the warm pool read as a patch of dug earth rather than as ground with a fire
## on it. The ground is snow at every distance, so it stays high-value and
## low-saturation everywhere; what changes across the pool is the colour of the
## light falling on it, warm at the core and cold out at the frontier.
##
## Interpolated in RGB rather than swept through HSV hue. Between two colours
## this desaturated there is barely any hue to rotate, so the midpoint cannot go
## muddy the way an amber-to-navy sweep did -- and a hue lerp from warm to cold
## would pass straight through green on the way.
const SNOW_LIT := Color8(238, 226, 209)
const SNOW_SHADE := Color8(136, 147, 163)

static func warm_tint(k: float) -> Color:
	return SNOW_LIT.lerp(SNOW_SHADE, pow(clampf(k, 0.0, 1.0), 0.85))

static func warm_radius(total_heat: int) -> float:
	return minf(WARM_BASE + float(total_heat) * WARM_PER_HEAT, WARM_MAX)
