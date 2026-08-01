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
const EXCHANGER_PERIOD := 5.0
const COPPER_PERIOD := 20.0

# --- Electricity -------------------------------------------------------------
## Power is a rate, not a stock: it never accumulates, so there is no battery to
## manage. A generator burns one energy crystal every ten seconds to sustain one
## unit of capacity, and machines reserve a share of it. Running out does not
## break anything -- everything drawing power simply slows in proportion.
const GENERATOR_PERIOD := 10.0
const GENERATOR_OUTPUT := 1.0
const BELT_POWER_DRAW := 0.1

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

# --- Machines ----------------------------------------------------------------
const M_CORE := 0
const M_MINER := 1
const M_BELT := 2
const M_EXCHANGER := 3
const M_GENERATOR := 4

## Hotbar order is the order they unlock, so the row grows left to right as the
## player earns it rather than showing four greyed slots on the first frame.
const BUILDABLE: Array[int] = [M_MINER, M_EXCHANGER, M_BELT, M_GENERATOR]

const MACHINE_NAMES := ["열 코어", "채굴기", "컨테이너 벨트", "수정에너지교환기", "발전기"]
## Hotbar cards are one slot wide and the full names do not fit beside the colour
## swatch. The long name still appears in the hint line above the row.
const MACHINE_SHORT := ["코어", "채굴기", "벨트", "교환기", "발전기"]
## Machines are bought with materials now, never with heat.
const MACHINE_COSTS := [
	{},
	{ITEM_CRYSTAL: 5},
	{ITEM_COPPER: 3},
	{ITEM_CRYSTAL: 20},
	{ITEM_COPPER: 10},
]
const MACHINE_HINTS := [
	"",
	"수정 광맥 위에 설치하고 고양이를 올려놓으세요",
	"자원을 기지까지 끊김 없이 나릅니다 · 전력 0.1 필요",
	"수정조각 2개를 에너지결정 1개로 바꿉니다",
	"에너지결정을 태워 전력 1.0을 공급합니다",
]

## What each machine needs before it appears in the hotbar. The first crystal in
## hand opens the crystal line; the first copper opens the power line.
const MACHINE_UNLOCK_ITEM := [-1, ITEM_CRYSTAL, ITEM_COPPER, ITEM_CRYSTAL, ITEM_COPPER]

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
const BELT_SPEED := 2.6           # tiles per second
const BELT_CAPACITY := 3
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
const CAT_ARRIVE := 10.0           # how close counts as "at the machine"
const BOXES_PER_CAT := 3
const CAT_BOX_PER_TILES := 100.0   # one crate per hundred tiles of world
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
const UI_SCALE_DEFAULT := 1.0

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

static func machine_color(type: int) -> Color:
	match type:
		M_CORE: return COL_CORE
		M_MINER: return COL_CAT_FUR
		M_EXCHANGER: return Color8(210, 120, 52)
		M_GENERATOR: return Color8(120, 190, 235)
		M_BELT: return COL_BELT_RIM
		_: return COL_MACHINE

## Samples the amber ramp. `k` is 0 at the core and 1 at the frontier.
static func warm_tint(k: float) -> Color:
	var t: float = clampf(k, 0.0, 1.0)
	var hue: float = lerpf(38.0, 27.0, t) / 360.0
	var sat: float = lerpf(0.30, 0.62, t)
	var val: float = lerpf(1.0, 0.22, pow(t, 0.82))
	return Color.from_hsv(hue, sat, val)

static func warm_radius(total_heat: int) -> float:
	return minf(WARM_BASE + float(total_heat) * WARM_PER_HEAT, WARM_MAX)
