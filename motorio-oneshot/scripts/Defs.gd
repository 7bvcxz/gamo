extends RefCounted
class_name Defs

## Single source of truth for balance numbers, palette and machine data.
## Keeping this data-driven means tuning the game never requires touching logic.

const TILE := 32

# --- Art direction -----------------------------------------------------------
# A cold navy world so that anything warm reads as valuable. Every warm hue in
# the game belongs to the player's factory; the environment never uses them.
const COL_VOID := Color("0e1320")
const COL_SNOW_WARM := Color("dfe7f2")
const COL_SNOW_COLD := Color("222c44")
const COL_GRID := Color("38445f")
const COL_CORE := Color("ffb347")
const COL_CORE_DEEP := Color("e0702a")
const COL_BRASS := Color("d8a34a")
const COL_MACHINE := Color("2f6d72")
const COL_MACHINE_EDGE := Color("6fd2c8")
const COL_CAT_FUR := Color("e79a4f")
const COL_CAT_FACE := Color("f7e6cd")
const COL_DANGER := Color("e8574c")
const COL_TEXT := Color("e6eef7")
const COL_TEXT_DIM := Color("8fa0bd")

# --- Items -------------------------------------------------------------------
const ITEM_FROST := 0
const ITEM_EMBER := 1
const ITEM_ALLOY := 2

const ITEM_NAMES := ["서리광석", "잉걸광석", "합금"]
const ITEM_COLORS := [Color("7fd4e8"), Color("f0894a"), Color("ffd98a")]
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
const DAY_SECONDS := 300.0
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
		M_FURNACE: return Color("8e5ac0")
		_: return COL_MACHINE

static func warm_radius(total_heat: int) -> float:
	return minf(WARM_BASE + float(total_heat) * WARM_PER_HEAT, WARM_MAX)
