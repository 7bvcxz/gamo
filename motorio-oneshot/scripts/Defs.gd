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
const ITEM_FROST := 0
const ITEM_EMBER := 1
const ITEM_ALLOY := 2

const ITEM_NAMES := ["서리광석", "잉걸광석", "합금"]
## Ember was a muddy brown against the cold ground (1.66:1); copper reads as a
## valuable metal and clears 6:1.
## Ember sat at 1.99:1 against the night and shared a hue band with the warm
## ground, so it vanished exactly when the player was told to go find it.
const ITEM_COLORS := [Color8(127, 212, 232), Color8(252, 104, 46), Color8(255, 217, 138)]
const EMBER_CORE := Color8(255, 238, 205)
const ORE_OUTLINE := Color8(28, 20, 18)
const ITEM_VALUES := [3, 6, 22]

# --- Machines ----------------------------------------------------------------
const M_CORE := 0
const M_MINER := 1
const M_BELT := 2
const M_FURNACE := 3

const BUILDABLE: Array[int] = [M_MINER, M_BELT, M_FURNACE]

const MACHINE_NAMES := ["열 코어", "채굴 고양이", "벨트", "제련로"]
const MACHINE_COSTS := [0, 12, 2, 30]
const MACHINE_HINTS := [
	"",
	"광맥 위에 설치하면 광석을 캐냅니다",
	"광석을 바라보는 방향으로 옮깁니다",
	"서리+잉걸 광석을 합금으로 제련합니다",
]

# --- Economy -----------------------------------------------------------------
## Days repeat and accumulate rather than ending the game, so one day is short
## enough that the dusk-to-dawn arc is felt several times in a sitting.
const DAY_SECONDS := 180.0
const START_HEAT := 30
const MINER_PERIOD := 1.15
const FURNACE_PERIOD := 2.2
const BELT_SPEED := 2.6           # tiles per second
const BELT_CAPACITY := 3
const FROST_COST_ALLOY := 1
const EMBER_COST_ALLOY := 1

## Warmth grows with everything the core has ever received, so investing in the
## factory is what expands the map rather than hoarding.
const WARM_BASE := 7.0
const WARM_PER_HEAT := 0.022
const WARM_MAX := 22.0

const COLD_DRAIN := 13.0          # warmth lost per second outside the radius
const COLD_RECOVER := 26.0
const RESCUE_PENALTY := 0.25      # share of banked heat lost when you black out

const FROST_RING := Vector2(4.0, 9.5)
const EMBER_RING := Vector2(11.0, 17.0)

static func machine_color(type: int) -> Color:
	match type:
		M_CORE: return COL_CORE
		M_MINER: return COL_CAT_FUR
		M_FURNACE: return Color8(210, 120, 52)
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
