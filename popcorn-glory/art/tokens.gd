class_name PopTokens
extends RefCounted

## Step 15: the factory's design tokens -- direction B, "candy-coloured industrial
## diorama" (design/ART_DIRECTION.md). Everything the factory draws takes its
## colours, sizes and timings from here, so the look is one decision, not forty.
## Sizes are in the 720x1280 design canvas (the game stretches it with
## canvas_items/expand). PopPalette (0.12.x) stays; these extend it.

# -- colour ------------------------------------------------------------------
## Floors, top to bottom: the shop, packing, the kitchen. Each a lighter top
## and a deeper bottom (light from above), on the butter background.
const FLOOR_TOP := [Color(1.0, 0.902, 0.69), Color(0.984, 0.839, 0.541)]
const FLOOR_MID := [Color(0.992, 0.922, 0.769), Color(0.969, 0.851, 0.62)]
const FLOOR_LOW := [Color(0.984, 0.878, 0.659), Color(0.953, 0.788, 0.471)]
const FLOOR_EDGE := Color(0.91, 0.722, 0.353)          # the shelf's rim
const MACHINE := Color(1.0, 0.416, 0.333)              # glossy red, top
const MACHINE_DEEP := Color(0.839, 0.208, 0.165)       # red, bottom
const MACHINE_LINE := Color(0.541, 0.137, 0.094)
const MINT := Color(0.561, 0.878, 0.769)               # pipes, automation
const MINT_DEEP := Color(0.31, 0.643, 0.537)
const STEEL := Color(0.906, 0.929, 0.949)
const STEEL_DEEP := Color(0.663, 0.714, 0.761)
const SKY := Color(0.435, 0.714, 0.91)                 # the ring's heat, 'cold'
const BRASS := Color(0.953, 0.812, 0.42)               # signage tiers (from direction A)
const AUTO := Color(0.435, 0.714, 0.91)                # automation's own colour (blue, as 0.11)
const WARN := Color(0.91, 0.282, 0.227)                # stopped, unpaid -- always with a shape
const OK := Color(0.31, 0.643, 0.537)
## Information never by colour alone: each state also has a shape
## (STATE_SHAPES), so colour-blind players read the same thing.
const STATE_SHAPES := {"run": "chevron", "starved": "empty_cup", "blocked": "stack", "unpaid": "coin_slash", "off": "bar"}

# -- light and shape -----------------------------------------------------------
const LIGHT_DIR := Vector2(-0.6, -0.8)                 # from the top left
const SHADOW_OFFSET := Vector2(6, 10)
const SHADOW_COLOR := Color(0, 0, 0, 0.12)
## Corner radii: floors > machines > buttons > small parts.
const R_FLOOR := 28.0
const R_MACHINE := 18.0
const R_BUTTON := 24.0
const R_PART := 8.0
## Outline weights: the hand's machine is the boldest thing on screen.
const LINE_HERO := 5.0
const LINE_MACHINE := 4.0
const LINE_PART := 3.0

# -- layout (portrait 720x1280; design/ART_DIRECTION.md section 3) --------------
const BAR_H := 0.07          # the top bar, as a share of the height
const TOP_FLOOR := Vector2(0.07, 0.30)
const MID_FLOOR := Vector2(0.30, 0.52)
const LOW_FLOOR := Vector2(0.52, 0.88)
const CARD := Vector2(0.88, 1.0)
const LIFT_X := 0.9          # the glass tube carrying goods up, as a share of the width
const HERO_MIN_SHARE := 0.5  # the hand's kettle is at least half the screen's width

# -- type ------------------------------------------------------------------------
## Numbers only (the game draws no words). Minimum 24 px in the design canvas.
const TEXT_MONEY := 40
const TEXT_PRICE := 34
const TEXT_DELTA := 24
const TEXT_MIN := 24

# -- motion ---------------------------------------------------------------------
## Seconds. Every moving good has a start, a travel and an arrival.
const T_POP := 0.12          # the pop's squash
const T_LIFT := 0.9          # one floor up in the tube
const T_SCOOP := 0.45
const T_SEAL := 0.25
const T_HANDOFF := 0.6
const T_COIN := 0.7
const T_UPGRADE := 0.8
const EASE_TRAVEL := Tween.TRANS_SINE
const EASE_ARRIVE := Tween.TRANS_BACK


static func floor_rect(band: Vector2, size: Vector2, margin: float = 20.0) -> Rect2:
	return Rect2(Vector2(margin, size.y * band.x + 6.0), Vector2(size.x - margin * 2.0, size.y * (band.y - band.x) - 12.0))
