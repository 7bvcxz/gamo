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
## The ice a rescued cat comes out of. Pale blue rather than white so it reads
## against the snow it is lying on -- a white block on a white field is a hole in
## the ground, not an object.
const COL_ICE := Color8(178, 216, 238)

## --- The opening ----------------------------------------------------------
## Seven panels, in order, with the picture and its shake in the same row. Two
## parallel lists -- one of textures, one of shake amounts -- is the arrangement
## this repository has watched go out of step twice, and a cutscene where the
## ground shakes on the wrong picture is worse than one that never shakes.
##
## The story was written as twelve beats. Twelve pictures before a game starts
## is a wait, not an opening, so beats sharing a place and a moment were merged:
## running for the rocket happens inside the bombardment, and the break-up, the
## ejection and the falling debris are one picture. What survives is what changes
## her situation.
##
## Shake is on the three panels where something hits: the bombardment, the Earth
## going, and the crash. Everywhere else it is still, because a shake that never
## stops is not a shake.
## The opening, seven panels.
##
## Each line is one or two sentences rather than the single clause it used to be.
## "그날, 하늘이 어두워졌다" is a caption; it says what the picture already says
## and nothing about what it means, and seven of those in a row leave the player
## on the ice knowing nothing except that they are on ice.
##
## `hot` marks the words drawn in the display face, bold, shaking on their own.
## They are the nouns the rest of the game is about -- the fleet, the planet, the
## cold, the fire -- so the first time each of them appears it is the word that
## moves. Marked as a list rather than with markup inside the string, because a
## string with tags in it is a string every width measurement has to learn to
## strip, and the one that forgets draws the tags.
const CUTSCENE_PANELS: Array[Dictionary] = [
	{"art": preload("res://assets/cutscene/01.webp"), "shake": 0.0,
		"line": "그날 하늘이 어두워졌다. 아무도 그것을 함대라고 부르지 않았다,\n이름을 붙일 시간이 없었으니까.",
		"hot": ["함대"]},
	{"art": preload("res://assets/cutscene/02.webp"), "shake": 7.0,
		"line": "펭귄 함대는 도시를 지나갔고 아무것도 남기지 않았다.\n협상도, 요구도, 경고도 없었다.",
		"hot": ["아무것도"]},
	{"art": preload("res://assets/cutscene/03.webp"), "shake": 2.5,
		"line": "마지막 로켓이 떠올랐다. 정원은 하나였고,\n그 자리에 앉은 것은 정비공 Grim이었다.",
		"hot": ["마지막"]},
	{"art": preload("res://assets/cutscene/04.webp"), "shake": 15.0,
		"line": "그리고 지구가 사라졌다. 창밖에서, 소리도 없이.\n돌아갈 곳은 그 순간부터 없었다.",
		"hot": ["사라졌다"]},
	{"art": preload("res://assets/cutscene/05.webp"), "shake": 0.0,
		"line": "경보가 그녀를 깨웠다. 연료는 바닥이었고 창밖에는\n이름 없는 얼음 행성 하나뿐이었다.",
		"hot": ["얼음 행성"]},
	{"art": preload("res://assets/cutscene/06.webp"), "shake": 12.0,
		"line": "로켓은 얼음 구름 속에서 부서졌다. 그녀는 살았고,\n타고 온 것은 눈밭에 흩어졌다.",
		"hot": ["부서졌다"]},
	{"art": preload("res://assets/cutscene/07.webp"), "shake": 0.0,
		"line": "추위가 그녀를 깨웠다. 여기서는 불이 곧 목숨이고,\n불을 키우는 것 말고는 할 수 있는 일이 없다.",
		"hot": ["불"]},
]

const CUTSCENE_FADE := 0.55
const CUTSCENE_HOLD := 3.40

static func cutscene_panel_seconds() -> float:
	return CUTSCENE_FADE * 2.0 + CUTSCENE_HOLD

## Where the picture sits this instant. Deterministic rather than random so a
## test can ask what the offset is at a given time, and decaying across the
## panel because an impact is loudest when it lands.
## How far a marked word has wandered from where it was set, this instant.
##
## Deterministic, like the panel shake and for the same reason: a test can ask
## where the word is at a given time. Each word gets its own pair of frequencies
## from its index, so two marked words on one panel never move together -- which
## would read as the line itself sliding rather than as the words shaking.
##
## It does not decay. The panel's shake is an impact and impacts fade; this is a
## word that will not sit still, and a word that settles after two seconds is a
## word the player watched stop.
const CUTSCENE_HOT_SHAKE := 1.15

static func cutscene_word_shake(word_index: int, elapsed: float) -> Vector2:
	var seed_a: float = 31.0 + float(word_index) * 7.0
	var seed_b: float = 43.0 + float(word_index) * 11.0
	return Vector2(
		sin(elapsed * seed_a) * 0.6 + sin(elapsed * (seed_b * 0.7)) * 0.4,
		sin(elapsed * seed_b) * 0.5 + sin(elapsed * (seed_a * 0.8)) * 0.5) * CUTSCENE_HOT_SHAKE

## The line broken into runs, each either plain or marked. One pass, so the
## drawing side never has to search the string for the marked words itself --
## which is where a substring that also occurs inside an ordinary word would have
## turned half a sentence bold.
static func cutscene_runs(index: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if index < 0 or index >= CUTSCENE_PANELS.size():
		return out
	# Copied, and each word crossed off as it is used: a word listed once is
	# emphasised once. "불이 곧 목숨이고, 불을 키우는 것" contains it twice, and two
	# words shaking in one short line reads as the line being broken rather than
	# as one word standing out of it.
	var hot: Array = []
	for word in CUTSCENE_PANELS[index].get("hot", []):
		hot.append(String(word))
	var word_index := 0
	for line: String in String(CUTSCENE_PANELS[index]["line"]).split("\n"):
		var runs: Array[Dictionary] = []
		var rest: String = line
		while rest != "":
			# The earliest marked word still ahead of us, so overlapping marks
			# resolve left to right rather than in table order.
			var at := -1
			var found := ""
			for word: String in hot:
				var here: int = rest.find(String(word))
				if here >= 0 and (at < 0 or here < at):
					at = here
					found = String(word)
			if at < 0:
				runs.append({"text": rest, "hot": false, "index": -1})
				break
			if at > 0:
				runs.append({"text": rest.substr(0, at), "hot": false, "index": -1})
			runs.append({"text": found, "hot": true, "index": word_index})
			hot.erase(found)
			word_index += 1
			rest = rest.substr(at + found.length())
		out.append({"runs": runs})
	return out

static func cutscene_shake(index: int, elapsed: float) -> Vector2:
	if index < 0 or index >= CUTSCENE_PANELS.size():
		return Vector2.ZERO
	var amount: float = float(CUTSCENE_PANELS[index]["shake"])
	if amount <= 0.0:
		return Vector2.ZERO
	var span: float = cutscene_panel_seconds()
	var decay: float = clampf(1.0 - elapsed / span, 0.0, 1.0)
	# Two frequencies per axis, none of them a multiple of another, so the
	# picture never returns to the same place on a beat.
	return Vector2(
		sin(elapsed * 37.0) * 0.6 + sin(elapsed * 23.0) * 0.4,
		sin(elapsed * 29.0) * 0.5 + sin(elapsed * 43.0) * 0.5) * amount * decay
## The SSR cat, which is a pig. Warm, like everything the player earns, but a
## pink that no machine and no ore uses, so half a second of it on screen is
## unmistakably the rare thing rather than another amber light.
const COL_PIG_BODY := Color8(242, 168, 186)
const COL_PIG_SNOUT := Color8(212, 118, 144)
const COL_DANGER := Color("e8574c")
const COL_TEXT := Color("e6eef7")
const COL_TEXT_DIM := Color("8fa0bd")

# --- Items -------------------------------------------------------------------
## Four materials, in the order the player meets them. Heat stone is hand-mined
## from the first minute and burns straight in the core; crystal and copper are
## the middle of the game; energy is what crystal becomes.
##
## Heat stone was added at the end rather than at the front, and everything
## indexed by item type is an array, so the constants below stay where they are
## and no save written before it changes meaning. `COUNTED_ITEMS` decides the
## order the player sees, which is the only place the order matters.
const ITEM_CRYSTAL := 0
const ITEM_COPPER := 1
const ITEM_ENERGY := 2
const ITEM_HEATSTONE := 3
## Ordinary stone, out of the boulders lying on the snow. The one material that
## is everywhere and never runs out, which is what makes it the floor the rest
## of the costs are measured against.
const ITEM_STONE := 4

const ITEM_NAMES := ["수정조각", "구리광석", "에너지결정", "열석", "돌"]
## Short forms for the status panel, where the counters share one row.
const ITEM_SHORT := ["수정", "구리", "에너지", "열석", "돌"]
## Ember was a muddy brown against the cold ground (1.66:1); copper reads as a
## valuable metal and clears 6:1.
## The copper seam sat at 1.99:1 against the night and shared a hue band with the warm
## ground, so it vanished exactly when the player was told to go find it.
## Heat stone against copper is the pair that has to survive being 38 pixels of
## snow: copper is a bright metal, heat stone is a dark coal with fire inside it,
## and the colour here is the fire rather than the coal because it is the fire
## the player is looking for.
const ITEM_COLORS := [Color8(127, 212, 232), Color8(252, 104, 46), Color8(255, 217, 138),
	Color8(255, 122, 48), Color8(150, 152, 158)]
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
## Heat stone burns in the core the way an energy crystal does, and for now it is
## worth the same. It is deliberately the *only* thing in the early game that
## makes heat, so the first thing the player learns -- carry this to the fire and
## the circle grows -- is one sentence with nothing else in it.
##
## The tutorial asks for three stones to take the warm radius from 7 to 9, which
## is 91 heat, or thirty a stone. Thirty here collapses the rest of the curve:
## the moment a miner is on heat stone, two of them reach the copper ring in
## about a minute. So the opening's jump has to come from the mission and not
## from this number, and which of the two moves is a question for when the
## tutorial is built.
const ITEM_VALUES := [0, 0, 5, 5, 0]
## The order the counters appear in, which is the order the player meets them.
const COUNTED_ITEMS: Array[int] = [ITEM_HEATSTONE, ITEM_STONE, ITEM_CRYSTAL, ITEM_COPPER, ITEM_ENERGY]

## Hand mining. Deliberately slow: it is the floor the whole factory is measured
## against, and it has to stay worth replacing.
## How long a torch takes to melt the ground out from under something that has
## to be carried.
##
## Long enough to be a decision -- a torch burns for thirty seconds, so this is a
## sixth of one -- and short enough that the answer to "I want that" is the walk
## rather than the wait.
const THAW_GROUND_SECONDS := 5.0

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
			# Whatever the seam under it holds -- there is no longer one ore.
			return "광맥의 자원 %.0f/분 · 고양이 또는 전력 %.1f" % [per_minute(MINER_PERIOD), MINER_POWER_DRAW]
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
			# Both of the things that burn, because the player meets heat stone
			# first and a line naming only the other one is a line telling them
			# their whole opening does nothing.
			return "Z 로 연료 투입 · 열석 1개 = 열 %d · 에너지결정 1개 = 열 %d" \
				% [ITEM_VALUES[ITEM_HEATSTONE], ITEM_VALUES[ITEM_ENERGY]]
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
## The slot machine, and whether the game has one this week.
##
## Decided 2026-08-14: keep it, but not in the Vertical Slice. The first thirty
## minutes are about being cold, finding a cat and watching a belt move, and a
## slot machine in the corner of that is a second game asking for attention.
##
## Nothing is deleted -- the reels, the five grades, the five cat portraits and
## the odds table are all still here and still tested. This is the one switch.
##
## Turning it back on is this line plus **a way to earn a coin**. There is no
## such way today: `sim.coins` is only ever raised by a debug key, which is how
## an entire finished system came to be unreachable in ordinary play without
## anyone noticing. Whoever flips this is signing up for that too.
##
## A static var rather than a const so the tests can turn it on and prove the
## machinery still works. A switch nobody can flip is indistinguishable from a
## feature that has quietly rotted.
static var GACHA_ENABLED := false

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
	{ITEM_HEATSTONE: 5},
	{ITEM_COPPER: 3},
	{ITEM_CRYSTAL: 20},
	{ITEM_COPPER: 10},
	{ITEM_COPPER: 2},
]
const MACHINE_HINTS := [
	"",
	"광맥 위에 설치하고 고양이를 올려놓으세요 · 고양이보다 빠릅니다",
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

## What each machine needs before it appears in the hotbar. The first heat stone
## opens the miner; the first crystal opens the exchanger line; the first copper
## opens power.
const MACHINE_UNLOCK_ITEM := [-1, ITEM_HEATSTONE, ITEM_COPPER, ITEM_CRYSTAL, ITEM_COPPER, ITEM_COPPER]
## Boulders take longer than a seam: a rock is a rock and a seam is a seam, and
## the difference is what makes walking to a seam worth it.
const ROCK_MINE_PERIOD := 14.0

# --- Economy -----------------------------------------------------------------
## Days repeat and accumulate rather than ending the game, so one day is short
## enough that the dusk-to-dawn arc is felt several times in a sitting.
## Five minutes, up from three as of 1.0.2.
##
## Dusk and night are counted back from the end and stay where they are, so the
## tail is the same length and what grew is the daylight in front of it: the last
## 95 seconds used to be half the day and are now under a third of it.
const DAY_SECONDS := 300.0
const START_HEAT := 30
## Deliberately slow: one cat is a trickle, so throughput has to come from more
## miners and better routing rather than from a single well-placed worker.
## Matched to hand mining on purpose. A miner is not faster than the player --
## it is somewhere else while the player is here, which makes the first one read
## as parallelism rather than as a speed upgrade. It also makes one exchanger
## exactly absorb four miners.
## Twelve a minute. The miner used to be six, which is a cat on a bare seam
## doing 2.2 with a walk in between -- close enough that the machine was a small
## improvement rather than the reason to build one. At twelve it is five times
## the animal, and that gap is what a machine is for.
const MINER_PERIOD := 5.0
## A cat digging a bare seam with its paws, for comparison. Twice the miner's
## period, and then it walks the stone to the core itself and walks back -- so a
## seam-cat is much slower than the number alone suggests.
##
## That gap is the whole point of the miner. A rescued cat is useful the minute
## it wakes, which is what the rescue promised; the machine is what you build
## when carrying stones one at a time stops being enough, and the reason to build
## it is speed rather than possibility.
const CAT_DIG_PERIOD := 20.0

## --- Boulders ---------------------------------------------------------------
## Moved here from the ground layer when rock became a resource: the simulation
## has to answer "is there one on this cell" and it cannot ask a drawing layer.
## The field is a pure function of the coordinates, so there is nothing to
## generate and nothing to store except which ones have been broken.
const ROCK_BLOCK := 11
const ROCK_MIN := 1
const ROCK_MAX := 12
## How far a clump can reach out of the block that seeded it. Twelve cells grown
## from one seed cannot travel further, so the blocks around a cell are the only
## ones that can claim it.
const ROCK_REACH := 1

## Deterministic and cheap. Not a hash anyone should trust with anything, but it
## has to give the same answer on every machine and every run, which rules out
## randi() and anything seeded from the clock.
static func rock_mix(a: int, b: int, salt: int) -> int:
	var h: int = (a * 73856093) ^ (b * 19349663) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return absi(h ^ (h >> 16))

## The cells one block's clump claims. Grown by filling its own concavities
## rather than by walking, which keeps clumps close to round -- a random walk
## produces strings one cell wide, and a line of separate boulder tiles reads as
## a dotted line rather than as a scatter of rocks.
static func rock_clump(block: Vector2i) -> Array[Vector2i]:
	var size: int = ROCK_MIN + rock_mix(block.x, block.y, 7) % (ROCK_MAX - ROCK_MIN + 1)
	var origin := Vector2i(
		block.x * ROCK_BLOCK + rock_mix(block.x, block.y, 11) % ROCK_BLOCK,
		block.y * ROCK_BLOCK + rock_mix(block.x, block.y, 13) % ROCK_BLOCK)
	var cells: Array[Vector2i] = [origin]
	var have: Dictionary[Vector2i, bool] = {origin: true}
	var steps: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	while cells.size() < size:
		var best: Array[Vector2i] = []
		var best_score: int = -1
		for from: Vector2i in cells:
			for step: Vector2i in steps:
				var candidate: Vector2i = from + step
				if have.has(candidate):
					continue
				var score: int = 0
				for around: Vector2i in steps:
					if have.has(candidate + around):
						score += 1
				if score > best_score:
					best_score = score
					best = [candidate]
				elif score == best_score and not best.has(candidate):
					best.append(candidate)
		if best.is_empty():
			break
		var pick: Vector2i = best[rock_mix(block.x, block.y, 300 + cells.size()) % best.size()]
		cells.append(pick)
		have[pick] = true
	return cells


## --- The crash ------------------------------------------------------------
## Before the emergency base is down there is no fire on this planet, and the
## numbers say so: nothing is warm, the map is three tiles of snow, and she is
## already more than half cold.
##
## The drain is a twenty-sixth of the ordinary one. Thirteen a second is the
## rule for a player who has a fire to run back to; at the crash there is
## nowhere to run, so it has to be long enough to look around in and short
## enough to be the reason she does.
const CRASH_WARMTH := 40.0
const CRASH_DRAIN := 0.5           # one degree every two seconds -- eighty of them
const CRASH_SIGHT := 3.0           # tiles of map, before there is a fire to see by
## How far from the crash site the base may be put down. Small on purpose: the
## world is generated around this point -- the ore rings, the frozen cats, the
## fog -- so the base moving far would mean moving all of it. Two tiles is
## enough for the placement to be a choice and small enough that nothing else
## has to know it happened.
const BASE_PLACE_RADIUS := 2.0
## What comes out of the survival kit, in the order it comes out. One list, so
## the thing being carried and the thing it turns into cannot disagree.
const KIT_NONE := 0
const KIT_BASE := 1
const KIT_SHELTER := 2
## How long Z is held to search the kit. Two seconds: long enough to be an act
## rather than a keypress, short enough that it is not a chore the second time.
## How long the pickaxe marker hangs over a seam after she picks the tool up.
## She is told which key it is; this is where to point it.
const PICKAXE_HINT_SECONDS := 14.0

const KIT_SEARCH_SECONDS := 2.0
## Where the kit lands relative to the crash site. Two tiles, in sight from the
## first frame: the opening's first instruction has to be visible without
## walking, because at three tiles of vision walking is how you get lost.
const KIT_OFFSET := Vector2i(2, 1)
## How far the shelter must stand from the base. A hut built against the fire is
## a hut that teaches nothing about the fire, and the two buildings drawn on top
## of each other is a picture of one building.
const SHELTER_CLEARANCE := 2.0
## Stones the opening asks for before it calls the fire established. Three: few
## enough to carry by hand without it becoming a chore, and enough that the
## player makes the trip more than once and learns what the trip is.
const OPENING_STONES := 3

## --- The energy torch -------------------------------------------------------
## The only way to see anything outside the fire.
##
## The snow fog used to keep a nine tile preview band past the warm edge so the
## next ore field was visible and worth walking to. That is gone: past the
## circle is white, and what is out there is found by carrying a light into it.
## Exploration stopped being "walk further" and became "spend something".
##
## And it holds the cold off. A lit torch is a fire she is carrying, so the
## thirty seconds buy light *and* not freezing, and when it goes out both stop at
## once. Without that the torch showed her a place she could not stay in.
##
## Two tiles is deliberately not enough to survey with. It is enough to walk by
## and to recognise a thing you are standing next to, which makes a torch a
## number of tiles travelled rather than a map.
const TORCH_SECONDS := 30.0
const TORCH_SIGHT := 2.0
## Two heat stones. The same fuel the fire runs on, so every torch is warmth the
## base did not get -- which is the trade the whole middle of the opening is.
const TORCH_COST := {ITEM_HEATSTONE: 2}
const TORCH_NAME := "에너지횃불"

## What the fire can make. A table so the second thing is a row rather than a
## rewrite of the window that shows it.
const BASE_CRAFTS: Array[Dictionary] = [
	{
		"id": "torch",
		"name": TORCH_NAME,
		"cost": TORCH_COST,
		"note": "들고 있는 동안 주위 %d칸이 보이고 춥지 않다 · %d초"
			% [int(TORCH_SIGHT), int(TORCH_SECONDS)],
	},
	{
		"id": "food_bin",
		"name": "사료 상자",
		"cost": {ITEM_HEATSTONE: 5},
		"note": "고양이가 배고프면 여기서 먹는다 · 거처 옆에 선다",
	},
]
## Where the circle stands when the third mission is done. Set to a number
## rather than added as a bonus: the mission promises nine tiles, and three
## stones of heat on their own come to 7.3. What the card says and what the
## screen shows have to be the same thing.
const OPENING_WARM_RADIUS := 9.0

## --- What the objective card says -------------------------------------------
## One table, keyed by an id that does not change, so a line can be rewritten
## without hunting for it in a ladder of branches -- and so the documentation
## page can list them beside the reason each one exists.
##
## The voice is deliberately unhelpful. The card used to read "임무 3 · 탐험할
## 방법을 찾자  열석을 캐서 기지에 넣으세요  (0/3)", which is a checklist item:
## it says the number, the verb and the key, and nothing at all about being cold
## and alone on someone else's planet. A count on the card also turns the first
## ten minutes into an errand with a progress bar.
##
## What is left is what she would notice, in the order she would notice it. The
## rule the lines are written against: **name the thing, never the action.** A
## player who is told there is a box in the snow walks to the box; a player who
## is told to press a key has been handed a manual.
##
## `why` is for the documentation page and is never drawn.
## The three things a run is about, and the rungs of each.
##
## One ladder was wrong for this game. Everything the player is working towards
## went through a single objective card, so the fire's next step, the animal in
## the ice and the first belt took turns evicting each other -- and whichever one
## happened to be showing was the only one that existed.
##
## Three tracks, and nothing on any of them until its moment. A list of every
## rung at once is a checklist; a rung that appears the first time a frozen cat
## comes into the light is the game noticing.
##
## The conditions are in Main, one `match` for opening and one for finishing,
## because they read the run and this file does not. The table is what they are
## about; the predicates are when.
const TRACK_BASE := 0
const TRACK_CAT := 1
const TRACK_AUTO := 2
const TRACK_NAMES := ["기지", "고양이", "자동화"]

const MISSIONS: Array[Dictionary] = [
	{"id": "BASE2", "track": TRACK_BASE, "line": "불을 한 번 더 키운다",
		"why": "거처가 서면 바로 열린다. 그 시점의 온기는 7칸이고 얼어붙은 고양이는 8.5칸부터 누워 있으므로, 첫 업그레이드는 세상에 무언가가 더 있다는 것을 알게 되는 일이다."},
	{"id": "BASE3", "track": TRACK_BASE, "line": "불을 더 멀리 보낸다",
		"why": "2단계에 닿으면 열린다. 11칸에서 풍부 등급 열석이 처음 나오므로, 같은 곡괭이질이 더 많이 준다."},
	{"id": "BASE4", "track": TRACK_BASE, "line": "구리가 있는 곳까지",
		"why": "3단계에 닿으면 열린다. 15칸이 구리 고리의 안쪽 가장자리이고 구리가 벨트의 입구다 — 이 줄은 자동화 계열이 열리는 문이기도 하다."},

	{"id": "CAT_LOOK", "track": TRACK_CAT, "line": "이 행성에 다른 것이 있는지 본다",
		"why": "기지가 2단계가 되어 온기가 9칸이 되면 열린다. 그 순간 처음으로 얼어붙은 고양이가 불빛 안에 들어오는데, 카드가 그것을 가리키지 않으면 플레이어는 눈밭의 얼음 덩어리를 지형으로 보고 지나간다."},
	{"id": "CAT_THAW", "track": TRACK_CAT, "line": "얼음 속의 것을 불 곁으로",
		"why": "얼어붙은 고양이를 실제로 본 뒤에 열린다. 무엇을 해야 하는지는 말하지 않는다 — 안아 오는 것과 불 가까이 두는 것은 들어 보면 알게 된다."},
	{"id": "CAT_WORK", "track": TRACK_CAT, "line": "혼자 하던 일을 나눈다",
		"why": "첫 고양이가 깨어나면 열린다. 광맥이든 기계든 어디에 놓든 일한다는 것을 여기서 배운다."},
	{"id": "CAT_FEED", "track": TRACK_CAT, "line": "일하는 것은 먹어야 한다",
		"why": "고양이가 실제로 배고파졌을 때 열린다. 나흘 걸린다 — 사료 상자를 처음부터 세워 두는 것은 일어나지도 않은 문제 옆에 답을 놓는 것이고, 이 줄은 그 문제가 실제로 생긴 날에 나타난다."},

	{"id": "AUTO_MINER", "track": TRACK_AUTO, "line": "손 대신 기계가 캐게 한다",
		"why": "`[질문]` 사용자가 자동화 계열을 비워 두었으므로 초안이다. 채굴기를 지을 열석이 모였을 때 열린다 — 지을 수 있게 된 그 순간이지, 그 전이 아니다."},
	{"id": "AUTO_BELT", "track": TRACK_AUTO, "line": "나르는 일을 그만둔다",
		"why": "`[질문]` 초안. 첫 구리를 손에 넣어 벨트가 해금되면 열린다."},
	{"id": "AUTO_LINE", "track": TRACK_AUTO, "line": "아무도 만지지 않는 한 줄",
		"why": "`[질문]` 초안. 벨트를 한 칸이라도 놓으면 열리고, 벨트가 기지에 무언가를 실어 넣으면 닫힌다. 이 게임이 향하는 그림이 실제로 한 번 돌아가는 순간이다."},
]

## The rungs of one track, in order.
static func missions_in(track: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: Dictionary in MISSIONS:
		if int(row["track"]) == track:
			out.append(row)
	return out

static func mission_row(id: String) -> Dictionary:
	for row: Dictionary in MISSIONS:
		if String(row["id"]) == id:
			return row
	return {}

const MISSION_LINES: Array[Dictionary] = [
	{
		"id": "M1",
		"line": "춥다.  눈 위에 상자가 하나 있다.",
		"why": "게임의 첫 문장. 처지와 목표물만 말하고 동사는 말하지 않는다. 상자는 맥박치며 빛나고, 3칸 시야 안에 그것 말고는 아무것도 없다.",
	},
	{
		"id": "M1-HOLD",
		"line": "불을 피울 자리를 골라야 한다.  떨어진 곳에서 멀지 않게.",
		"why": "들고 있는 것이 무엇인지 말하지 않는다. 대신 그것으로 무엇이 되는지와, 놓을 수 있는 범위가 있다는 것만 흘린다.",
	},
	{
		"id": "M2",
		"line": "밤이 오면 이대로는 안 된다.  상자에 무언가 더 있었던 것 같다.",
		"why": "왜 더 필요한지(밤)와 어디를 봐야 하는지(상자)를 한 줄에. 상자를 두 번 뒤진다는 것은 아무도 알려주지 않는다.",
	},
	{
		"id": "M2-HOLD",
		"line": "불에서 조금 떨어진 곳에 세운다.",
		"why": "거처가 기지에 붙으면 설치가 거부되는데, 그 규칙을 거부당하기 전에 한 번 말해 둔다. 몇 칸인지는 말하지 않는다.",
	},
	{
		"id": "UPGRADE",
		"line": "기지 업그레이드 NN  ·  열석 N/N",
		"why": "거처를 세운 뒤부터 카드가 지시를 멈추고 이것만 남는다. 다음 기지 단계와 모자란 열석 수뿐이고, 동사도 키도 경로도 없다. 그 시점의 그녀는 불과 거처와 곡괭이와 세계를 가졌고, 거기서 또 심부름을 받으면 게임이 체크리스트가 된다. NN과 N은 실행 중에 채워진다. 모인 수는 이번 단계의 시작점부터 0에서 세고 필요 수는 고정이다 — 줄어드는 숫자는 얼마나 남았는지를 말하고 차오르는 숫자는 얼마나 왔는지를 말하는데, 돌 하나를 더 나르게 만드는 것은 뒤쪽이다.",
	},
	{
		"id": "BROWNOUT",
		"line": "전력이 모자랍니다.",
		"why": "지시가 아니라 상태다. 전력이 부족하면 지어 둔 기계 전부가 비율만큼 느려지는데 그 사실을 말하는 것이 화면에 하나도 없다. 무엇을 하라고는 말하지 않는다.",
	},
	{
		"id": "MAXED",
		"line": "불은 더 커지지 않는다.",
		"why": "마지막 단계에 닿았을 때. 다음 목표를 지어내지 않는다 — 없는 것을 있는 척하면 그 뒤로 카드를 아무도 믿지 않는다.",
	},
	{
		"id": "CARRY-FROZEN",
		"line": "품 안이 차갑다.  불 가까이에 두어야 한다.",
		"why": "해동은 기지 2칸 안에서만 시작한다. 거리 대신 '가까이'라고만 말하고, 틀리면 그때 정확히 알려준다.",
	},
	{
		"id": "THAW",
		"line": "얼음이 녹고 있다.",
		"why": "12초 동안 아무것도 요구하지 않는 유일한 줄. 이 게임에서 가장 비싼 3초를 앞두고 화면이 다른 말을 하면 안 된다.",
	},
	{
		"id": "CARRY-CAT",
		"line": "고양이가 일할 곳을 찾는다.  광맥이든, 기계든.",
		"why": "광맥에 직접 놓을 수 있다는 것과 기계가 따로 있다는 것을 한 번에 흘린다. 어느 쪽이 빠른지는 말하지 않는다.",
	},
	{
		"id": "COLD-NOBASE",
		"line": "몸이 얼고 있다.  불이 필요하다.",
		"why": "기지가 서기 전의 동결 경고. 돌아갈 온기 반경이 아직 없으므로 '반경 안으로'라고 말할 수 없다.",
	},
]

## --- Key prompts ------------------------------------------------------------
## A key cap over Grim's head, an arrow, and one word.
##
## The objective card was made deliberately unhelpful, and the cost of that
## showed up the first time someone actually played the opening: she lands on a
## planet and does not know a single control. "춥다. 눈 위에 상자가 하나 있다."
## tells you where to go and nothing about how to go there.
##
## So the two jobs are split. The card says the **situation** and never a key;
## this says the **key** and never why. One word each -- 이동, 조사, 안기 -- so
## it is read in the time it takes to glance up rather than read.
##
## Ordered by priority: the first one that is wanted and not yet learned is the
## one that shows. Only ever one at a time; two prompts over her head is a menu.
##
## `why` is for the documentation page and is never drawn.
const KEY_PROMPTS: Array[Dictionary] = [
	{
		"id": "KIT", "keys": ["Z"], "hold": true, "verb": "조사",
		"why": "상자 옆에 섰을 때. 게임에서 처음 누르는 키이고, 누르고 있어야 한다는 것은 화면의 고리가 말해준다.",
	},
	{
		"id": "PLACE", "keys": ["Z"], "verb": "내려놓기",
		"why": "긴급기지나 긴급거처를 들고 있을 때. 같은 키가 든 것을 내려놓는다는 규칙을 여기서 한 번 배우면 얼어붙은 고양이에서 다시 배울 필요가 없다.",
	},
	{
		"id": "THAW", "keys": ["Z"], "verb": "내려놓기",
		"why": "얼어붙은 고양이를 안고 있을 때. PLACE와 같은 동작이지만 그때는 이미 배운 뒤라 대개 뜨지 않는다.",
	},
	{
		"id": "MELT", "keys": ["Z"], "hold": true, "verb": "녹이기",
		"why": "횃불을 든 채 온기 밖의 들 수 있는 것을 마주했을 때. 횃불이 손에 있으면 만질 수는 있지만 드는 것은 땅이 놓아준 다음이고, 그 5초를 누르고 있어야 한다는 것은 화면의 고리가 말해준다.",
	},
	{
		"id": "FROZEN", "keys": ["Z"], "verb": "안기",
		"why": "얼어붙은 고양이 옆에 섰을 때. 이 게임에서 가장 중요한 한 번이고, 첫 고양이가 생기면 다시 뜨지 않는다.",
	},
	{
		"id": "CATPLACE", "keys": ["Z"], "verb": "배치",
		"why": "고양이를 안고 있을 때. 어디에 놓을 수 있는지는 목표 카드가 말한다.",
	},
	{
		"id": "CATLIFT", "keys": ["Z"], "verb": "안기",
		"why": "일 없는 고양이 옆에 섰을 때. 고양이를 옮길 수 있다는 것을 아무도 알려주지 않으면 평생 숙소 앞에 서 있는다.",
	},
	{
		"id": "FUEL", "keys": ["Z"], "verb": "기지",
		"why": "연료를 들고 기지를 바라볼 때. 캔 열석이 불에 들어가지 않으면 오프닝이 끝나지 않는다.",
	},
	{
		"id": "MINE", "keys": ["Z"], "hold": true, "verb": "캐기",
		"why": "곡괭이를 들고 광맥을 바라볼 때. 누르는 것이 아니라 누르고 있어야 한다.",
	},
	{
		"id": "TORCH", "keys": ["3"], "verb": "횃불",
		"why": "횃불을 만들어 두고 아직 꺼내지 않았을 때. 만들어만 두고 쓰지 않는 물건이 되기 쉽다.",
	},
	{
		"id": "TOOL", "keys": ["1", "2", "3"], "verb": "도구",
		"why": "곡괭이가 생긴 뒤 아직 도구를 바꿔 본 적이 없을 때. 숫자 키가 손에 든 것을 바꾼다는 규칙 하나.",
	},
	{
		"id": "BUILD", "keys": ["B"], "verb": "건설",
		"why": "설비가 해금됐는데 아직 아무것도 짓지 않았을 때.",
	},
	{
		"id": "RUN", "keys": ["Shift"], "verb": "달리기",
		"why": "조금 걸어 본 뒤에. 처음부터 알려주면 이동과 달리기 두 가지를 한 번에 배우게 된다.",
	},
	{
		"id": "MOVE", "keys": ["←", "↑", "→", "↓"], "verb": "이동",
		"why": "맨 처음. 그녀는 방금 다른 행성에 떨어졌고 조작키를 하나도 모른다. 목록의 맨 뒤에 있는 이유는 우선순위가 낮아서가 아니라, 시작 순간에는 다른 어떤 것도 해당되지 않기 때문이다.",
	},
]

## How far she has to walk before 이동 counts as learned, and before 달리기 is
## worth mentioning. In tiles.
const PROMPT_WALK_LEARNED := 3.0
const PROMPT_WALK_RUN := 6.0

static func key_prompt(id: String) -> Dictionary:
	for row: Dictionary in KEY_PROMPTS:
		if String(row["id"]) == id:
			return row
	return {}

## The line for an id. Missing ids return the id itself rather than an empty
## card, so a typo shows up on screen instead of as silence.
static func mission_line(id: String) -> String:
	for row: Dictionary in MISSION_LINES:
		if String(row["id"]) == id:
			return String(row["line"])
	return id
const FURNACE_PERIOD := 2.2
## Deliberately slow. A tenth of what it used to be, which puts a ten-tile run at
## about 38 seconds: never a hard throughput gate -- it still carries nearly four
## times a pure seam's output -- but slow enough that a long line starts to feel
## like something you would rather not wait for. That feeling is what makes the
## grades worth having, and grade 3 restores exactly the old speed.
## Raised with the miner. The rule a belt has to keep is that one of them
## carries one miner without choking, and doubling the miner to 12/min put the
## richest seam at 24 -- past what 0.26 could move. The grades buy latency, not
## throughput, so a belt that cannot keep up with a single machine turns them
## into a throughput gate the design says they must never be.
## How fast a belt carries a person, as a multiple of what it carries a crate at.
##
## A belt moves its cargo at BELT_SPEED cells a second, which is under a third of
## a tile: a person drifting at that rate cannot tell they are standing on one.
## Three and a half times it is a tile a second -- unmistakable standing still,
## and about a quarter added to a run going the same way. Written as a multiple
## rather than as a number so a faster belt carries her faster too.
const BELT_CARRY_FACTOR := 3.5

## Pixels per second a belt drags whatever is standing on it.
static func belt_carry_speed() -> float:
	return BELT_SPEED * float(TILE) * BELT_CARRY_FACTOR

const BELT_SPEED := 0.30          # tiles per second

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
## How far the map fills in around the player as they walk, and how much of the
## base is on it from the start. Sight is smaller than the screen on purpose: a
## radius that matched what is visible would fill the map in as fast as the
## camera moves, and there would be nothing to explore.
const SIGHT_RADIUS := 9
## What the map's zoom slider spans, as world cells per map pixel at each end.
## The wide end shows roughly the whole reachable plateau; the close end is about
## what the game screen shows, so the two ends answer "where am I in the world"
## and "what is right here".
const MAP_ZOOM_MIN := 0.4
const MAP_ZOOM_MAX := 3.0
const MAP_ZOOM_STEP := 0.2
const MAP_ZOOM_DEFAULT := 1.0
## How many map pixels one cell covers at zoom 1.
##
## Four, not two. At two the card showed 180 cells across, and the plateau a
## player can actually reach is a few tens of cells wide -- so a run's whole
## exploration sat in the middle of the card as a smudge the size of a coin,
## with most of the map showing fog that is not merely unexplored but unreachable.
## A map is worth opening when what you have done fills it.
const MAP_CELL_PX := 4.0
const BASE_REVEAL_RADIUS := 11

const WARM_BASE := 7.0
const WARM_MAX := 22.0
## --- Base levels ------------------------------------------------------------
## The circle used to grow by a hundredth of a tile at a time, which is a number
## in a corner rather than a thing that happens. It goes up in steps now: the
## base upgrades, and two tiles of white ground turn into ground.
##
## The thresholds are in heat, and the heat stone is worth five, so the first
## four are the three, nine, fifteen and twenty-seven stones the opening asks
## for. Written in heat rather than in stones because an energy crystal is heat
## too, and a table that counted only stones would stop the exchanger from
## contributing to the thing heat is for.
##
## `[초안]` beyond level 4. The first four are the design's; the rest exist
## because the copper ring starts at 15 and a player who cannot pass 15 can
## never reach it. They escalate the same way -- roughly double the last step.
const BASE_LEVELS: Array[Dictionary] = [
	{"heat": 0,   "radius": 7.0},     # the emergency base, the moment it is lit
	{"heat": 15,  "radius": 9.0},     # 열석 3
	{"heat": 45,  "radius": 11.0},    # 열석 9
	{"heat": 75,  "radius": 13.0},    # 열석 15
	{"heat": 135, "radius": 15.0},    # 열석 27 -- and the first copper
	{"heat": 255, "radius": 17.0},
	{"heat": 435, "radius": 19.0},
	{"heat": 675, "radius": WARM_MAX},
]

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
## How far below a cat's position its feet are drawn.
##
## Lives here rather than in the drawing layer because the simulation needs it
## too: a cat put at the middle of a tile has its *torso* there and its feet ten
## pixels south, which on a 32 pixel tile is a third of the way to the next one.
## Measured off a screenshot at full zoom -- the cat working a miner stood 19
## screen pixels below the machine it was running.
const CAT_FOOT_DROP := 10.0
const CAT_SPEED := 46.0            # pixels per second while walking
## No longer an arrival threshold: a cat arrives by standing on the spot. Kept as
## a name for "comfortably away from it", which is what tests need when they want
## a cat that has not got there yet.
const CAT_AWAY := 10.0

## --- The warmth gauge -------------------------------------------------------
## Over her head, the way a cat's hunger sits over its own. The game already has
## that sentence -- a bar above an animal is its condition -- and giving Grim a
## second, different one somewhere else would be two rules where one will do.
##
## Her head occupies about y = -22 to -10 in her own space, so the bar clears it
## by eight pixels. Wider than a cat's because she is the one being read at a
## glance while everything else is happening.
const WARMTH_BAR_LIFT := 30.0
const WARMTH_BAR_SIZE := Vector2(26.0, 3.5)
## Above this it is not drawn at all, and it fades in over the fifteen below.
## Warmth stops being a question once the factory is running, and a gauge that is
## always full is a gauge nobody reads when it finally is not.
const WARMTH_BAR_SHOW := 92.0
const WARMTH_BAR_FADE := 15.0

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
## --- Frozen cats ----------------------------------------------------------
## Cats are not bought, they are found frozen and carried home. This replaced the
## crates entirely: three crates on the doorstep was a fetch quest, and the
## vision asks for a meeting -- ice melts, the cat opens its eyes, it looks at
## Grim.
##
## One frozen cat is one cat, where three crates used to be one cat, so the
## density is a third of the crates' and the number of cats a map can support is
## exactly what it was. The pace of the factory has not changed; what changed is
## what the walk is for.
const FROZEN_PER_TILES := 200.1
## One inside reach, so the first cat is always findable. The crates guaranteed
## three for the same reason -- three of them made one cat.
const STARTER_FROZEN := 1
## And no closer than this to the base.
##
## Eight and a half, which is outside the opening circle of seven and inside the
## nine the third mission takes it to. So the first frozen cat is not visible
## when the game starts: it appears in the ring of new ground that opens the
## moment the player feeds the fire. That is the answer to a complaint the
## design has had since it was written -- that the warm radius grows and nothing
## on screen says so.
const FROZEN_MIN_RING := 8.5
## Carrying one. She walks at half speed and cannot run: a frozen cat is a body
## in her arms, and the distance she chose to walk out is the price of it. This
## is the only thing in the game that slows her down other than the cold.
const FROZEN_CARRY_SPEED := 0.5
## How close to the core it has to be put down before the ice starts to go. Two
## tiles, measured from the core's own cell -- the base has to be somewhere, and
## "near the fire" is the reason the walk home exists at all.
const THAW_RADIUS := 2.0
## How long the ice takes once it is in place. Long enough to be watched and
## short enough to be waited for; the four stages are three seconds each.
const THAW_SECONDS := 12.0
## Stages in cat_freeze_4.png. The fourth is still icy on purpose: what follows
## it is the ordinary cat sprite, so a stage that had finished melting would be a
## duplicate of something the game already draws.
const FROZEN_STAGES := 4

## Hunger runs 0..1, and falls slowly on purpose.
##
## It used to cost 1/18 every ten seconds, so a fed cat was hungry after three
## real minutes -- which is inside the first day, before the player has built
## anything for the food to be a problem *with*. Feeding was a chore introduced
## before its own reason existed.
##
## At a quarter of that a cat works about twelve minutes, which is four days. By
## then there is a factory to slow down, and a cat visibly working at a third
## speed is a question the player asks rather than an errand they are handed.
const HUNGER_PER_SECOND := (1.0 / 18.0) / 40.0
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

## Heat stone in bands, one per step of the base ladder.
##
## It used to be a single ring from 3 to 6, which put every seam in the world
## inside the opening circle. Counted across forty seeds, radius 13 and radius 15
## reached exactly the same seams as radius 11 -- so the third and fourth
## upgrades, which cost 15 and 27 heat stone, returned no heat stone at all. A
## ladder paid for in the thing it does not give back gets harder to climb the
## higher you go, and the only honest answer to "why upgrade" was "you do not".
##
## The band edges sit just inside each warm radius (7 / 9 / 11 / 13 / 15 / 17) so
## a step lands a field rather than a fraction of one, and the purity rings at 11
## and 17 finally have something to grade: before this, no heat stone seam in any
## world was ever above 보통.
const HEATSTONE_BANDS: Array[Dictionary] = [
	{"ring": Vector2(3.0, 6.0), "patches": 3, "size": 2},      # 시작 반경 7
	{"ring": Vector2(7.5, 8.8), "patches": 2, "size": 2},      # 1단계 · 9
	{"ring": Vector2(9.5, 10.8), "patches": 2, "size": 2},     # 2단계 · 11 · 풍부
	{"ring": Vector2(11.5, 12.8), "patches": 2, "size": 2},    # 3단계 · 13
	{"ring": Vector2(13.5, 14.8), "patches": 2, "size": 3},    # 4단계 · 15
	{"ring": Vector2(15.5, 16.8), "patches": 2, "size": 3},    # 5단계 · 17
	{"ring": Vector2(17.5, 18.8), "patches": 2, "size": 3},    # 6단계 · 19 · 순수
	{"ring": Vector2(19.5, 21.5), "patches": 2, "size": 3},    # 7단계 · 22 · 마지막
]
## Crystal has no seam. It used to have one, and a seam is a promise that there
## will always be more -- which is the opposite of what a rare material is. It
## lies in the snow instead, a fixed number of pieces put down when the world is
## made and never replaced: what is out there is all there will ever be, and
## every one of them was found by walking somewhere.
##
## Scattered from just outside the opening circle to past the furthest the base
## can ever reach, so there is something to find at every stage rather than a
## band that is exhausted at one.
const CRYSTAL_RING := Vector2(8.0, 26.0)
## How many exist. Twenty builds the exchanger and the rest is what it has to
## live on -- one exchanger and about twenty energy crystals in a whole world.
## `[초안]`: the number that decides how far the energy line can go, and it wants
## a play-through before it is trusted.
const CRYSTAL_SHARDS := 60
## First reachable at base level 4, which is where the fourth upgrade puts the
## circle. Copper is the door to power and belts, and it opens on an upgrade
## rather than on a number quietly passing a threshold.
const COPPER_RING := Vector2(15.0, 19.0)
## And one patch guaranteed at the very edge of that circle, because scattering
## three patches anywhere in 15..19 put an average of 0.3 seams inside 15 -- the
## upgrade the design calls "the one that opens copper" opened it in about a
## quarter of runs, and a belt costs three. A guaranteed patch makes the promise
## true every time; the scatter is still what rewards walking past it.
## Fourteen, not fifteen: the patch grows outward from its origin, so an origin
## on the line puts half the cluster outside the circle it is supposed to open.
## Measured that way, a belt was buildable at level 4 in 29 runs out of 60.
const FIRST_COPPER_BAND := Vector2(13.4, 14.8)
const FIRST_COPPER_SIZE := 4

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

## The level a run has reached, which is the only thing that decides the circle.
static func base_level(total_heat: int) -> int:
	var level: int = 0
	for index in BASE_LEVELS.size():
		if total_heat >= int(BASE_LEVELS[index]["heat"]):
			level = index
	return level

static func warm_radius(total_heat: int) -> float:
	return float(BASE_LEVELS[base_level(total_heat)]["radius"])

## What the next upgrade costs and gives, or an empty dictionary at the top. The
## HUD reads this so the player can see what they are working towards rather
## than watching a number they cannot interpret.
static func next_base_level(total_heat: int) -> Dictionary:
	var level: int = base_level(total_heat)
	if level + 1 >= BASE_LEVELS.size():
		return {}
	return BASE_LEVELS[level + 1]
