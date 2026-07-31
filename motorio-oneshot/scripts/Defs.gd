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
const ITEM_COPPER := 1
const ITEM_IRON := 2

const ITEM_NAMES := ["서리광석", "구리", "철"]
## Ember was a muddy brown against the cold ground (1.66:1); copper reads as a
## valuable metal and clears 6:1.
## The copper seam sat at 1.99:1 against the night and shared a hue band with the warm
## ground, so it vanished exactly when the player was told to go find it.
const ITEM_COLORS := [Color8(127, 212, 232), Color8(252, 104, 46), Color8(255, 217, 138)]
const COPPER_CORE := Color8(255, 238, 205)
const ORE_OUTLINE := Color8(28, 20, 18)
## Heat is still the currency that widens the warm radius; copper and iron are
## counted separately as materials.
const ITEM_VALUES := [3, 6, 22]
const COUNTED_ITEMS: Array[int] = [ITEM_COPPER, ITEM_IRON]

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
const M_FURNACE := 3

const BUILDABLE: Array[int] = [M_MINER, M_BELT, M_FURNACE]

const MACHINE_NAMES := ["열 코어", "채굴기", "벨트", "제련로"]
const MACHINE_COSTS := [0, 12, 2, 30]
const MACHINE_HINTS := [
	"",
	"광맥 위에 설치하고 고양이가 와야 돌아갑니다",
	"광석을 바라보는 방향으로 옮깁니다",
	"서리광석과 구리를 철로 제련합니다",
]

# --- Economy -----------------------------------------------------------------
## Days repeat and accumulate rather than ending the game, so one day is short
## enough that the dusk-to-dawn arc is felt several times in a sitting.
const DAY_SECONDS := 180.0
const START_HEAT := 30
## Deliberately slow: one cat is a trickle, so throughput has to come from more
## miners and better routing rather than from a single well-placed worker.
const MINER_PERIOD := 5.75
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
const SHELTER_OFFSET := Vector2(-2.5, 2.5)
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

const FROST_RING := Vector2(4.0, 9.5)
const COPPER_RING := Vector2(11.0, 17.0)

## UI scale. The web export renders at the device pixel ratio, so a phone that is
## physically 390 CSS px wide reports a ~960 px logical viewport: every constant
## below lands at roughly 0.4 of the physical size it was drawn for, which made
## the HUD text about 5 CSS px tall. Touch therefore starts at 2x and desktop at
## half, and the player can trim either from the settings panel.
const UI_SCALE_TOUCH_BASE := 2.0
const UI_SCALE_DESKTOP_BASE := 0.5
const UI_SCALE_MIN := 0.6
const UI_SCALE_MAX := 1.6
const UI_SCALE_DEFAULT := 1.0

## Rounded to this step so the slider lands on repeatable values and the label
## never shows a number the player cannot get back to.
const UI_SCALE_STEP := 0.05

static func quantise_ui_scale(value: float) -> float:
	var clamped: float = clampf(value, UI_SCALE_MIN, UI_SCALE_MAX)
	return snappedf(clamped, UI_SCALE_STEP)

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
