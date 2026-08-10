extends Node2D
class_name GroundLayer

## The warm pool used to be forty concentric filled circles. Godot re-rasterises
## every draw command each frame regardless of queue_redraw(), so that cost about
## 2.9M pixels of fill per frame and pinned the software-WebGL build near 15 FPS.
## The ramp is scale-invariant, so it is baked once into a small texture and
## drawn as a single quad; growing the radius is then free.

const TEX_SIZE := 192

## The ground tiles. Sixteen painted variants in one 4x4 atlas, cut by
## tools/sprite/build_tiles.py -- one texture rather than sixteen so the whole
## floor batches into a single draw call instead of one per cell.
const TILE_ATLAS: Texture2D = preload("res://assets/tiles/ground_16.png")
const TILE_COLUMNS := 4
const TILE_VARIANTS := 16

var sim: Sim
var night: float = 0.0
var view_rect := Rect2()

var _texture: ImageTexture
## The tile pass, drawn multiplied over the ground rather than on it.
##
## The warm pool is an opaque ramp, so tiles underneath it are invisible exactly
## where the player stands. Painting them over it instead would erase the pool,
## which is the thing the whole game is read through. Multiplying keeps both:
## the colour stays whatever the pool and the night decided, and the near-white
## tile art only darkens it where the snow has shape.
##
## It is a child node because blend mode belongs to a CanvasItem, not to a draw
## call, and the ground's other two passes must stay ordinary.
var _tile_layer: Node2D
## Rock, worked out once per cell and kept. The floor never changes, so the only
## alternative is deciding it again every frame for a thousand cells.
var _rock: Dictionary[Vector2i, bool] = {}
var _blocks: Dictionary[Vector2i, bool] = {}
var _slots: Dictionary[Vector2i, int] = {}

func _ready() -> void:
	_texture = _bake_pool()
	_tile_layer = Node2D.new()
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_tile_layer.material = material
	add_child(_tile_layer)
	_tile_layer.draw.connect(_draw_tiles)

## Redrawn every frame, but the whole layer is now one screen fill plus one
## textured quad, which is a fraction of the old forty-circle gradient.
func _process(_delta: float) -> void:
	queue_redraw()
	if _tile_layer != null:
		_tile_layer.queue_redraw()

## One radial ramp, transparent outside the disc so it composites over the night.
func _bake_pool() -> ImageTexture:
	var image := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	var centre := float(TEX_SIZE - 1) * 0.5
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			var d: float = Vector2(float(x) - centre, float(y) - centre).length() / centre
			if d > 1.0:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var col: Color = Defs.warm_tint(d)
			# Alpha-blending amber over navy leaves the warm gamut wherever the
			# blend sits mid-way, so a wide feather reintroduced the mud ring it
			# was meant to remove (25.3% of the disc out of gamut, hue reaching
			# 330 degrees). Keep the transition narrow: the ramp is already dark
			# by this point, so a short blend is not a visible cliff.
			col.a = 1.0 if d < 0.96 else clampf((1.0 - d) / 0.04, 0.0, 1.0)
			image.set_pixel(x, y, col)
	return ImageTexture.create_from_image(image)

func _draw() -> void:
	if sim == null or _texture == null:
		return
	# A real 2.5x drop in ground value across the day, so dusk is unmistakable.
	draw_rect(view_rect, Defs.COL_SNOW_COLD.lerp(Color8(9, 12, 20), pow(night, 1.4)))
	var tile := float(Defs.TILE)
	var core_px: Vector2 = Vector2(sim.core_cell) * tile + Vector2.ONE * tile * 0.5
	var radius: float = sim.warm_radius * tile
	# Night darkens the pool through modulation rather than a second fill pass.
	var tint: Color = Color.WHITE.lerp(Color(0.42, 0.36, 0.48, 1.0), pow(night, 1.3) * 0.72)
	draw_texture_rect(_texture, Rect2(core_px - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false, tint)

## --- Rock ---------------------------------------------------------------------
## Rock is a pattern on the floor and nothing else: it is not in the simulation,
## it is not saved, and the player walks straight over it. That is what lets it
## be a pure function of the coordinates -- ask any cell whether it is rock and
## it answers the same way forever, including cells nobody has visited.
##
## Patches rather than speckle. One patch is seeded per block of BLOCK cells and
## grown to between one and twelve tiles, which at 8x8 blocks puts the average
## patch (6.5) over the average block (64) at just over a tenth of the ground.
const ROCK_BLOCK := 8
const ROCK_MIN := 1
const ROCK_MAX := 12
## How far a patch can reach out of the block that seeded it. Twelve cells grown
## from one seed cannot travel further than this, so the blocks around a cell are
## the only ones that can claim it.
const ROCK_REACH := 1

## Deterministic and cheap. Not a hash function anyone should trust with
## anything, but it has to give the same answer on every machine and every run,
## which rules out randi() and anything seeded from the clock.
static func _mix(a: int, b: int, salt: int) -> int:
	var h: int = (a * 73856093) ^ (b * 19349663) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return absi(h ^ (h >> 16))

## The cells one block's patch claims. Grown by walking out from a seed, which
## keeps the patch connected -- a patch that scattered would defeat the point of
## having patches.
static func rock_patch(block: Vector2i) -> Array[Vector2i]:
	var size: int = ROCK_MIN + _mix(block.x, block.y, 7) % (ROCK_MAX - ROCK_MIN + 1)
	var origin := Vector2i(
		block.x * ROCK_BLOCK + _mix(block.x, block.y, 11) % ROCK_BLOCK,
		block.y * ROCK_BLOCK + _mix(block.x, block.y, 13) % ROCK_BLOCK)
	var cells: Array[Vector2i] = [origin]
	var have: Dictionary[Vector2i, bool] = {origin: true}
	var steps: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	while cells.size() < size:
		# Grow into whichever free cell already touches the patch most. A plain
		# random walk was tried first and it produced strings one cell wide, which
		# is the worst possible shape here: a cell with a single rock neighbour is
		# a configuration the sheet does not draw, so it falls back to the lone
		# boulder and a whole chain renders as a dotted line rather than as rock.
		# Filling the concavities first keeps patches close to round, and round
		# patches ask for the shapes the sheet actually has.
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
		var pick: Vector2i = best[_mix(block.x, block.y, 300 + cells.size()) % best.size()]
		cells.append(pick)
		have[pick] = true
	return cells

## Fills the cache for every block that could reach into this range. Called once
## per frame with the visible range rather than per cell, because the answer for
## a cell depends on its neighbours' blocks as well as its own.
func _ensure_rock(start: Vector2i, end: Vector2i) -> void:
	var low := Vector2i(floori(float(start.x) / ROCK_BLOCK) - ROCK_REACH,
		floori(float(start.y) / ROCK_BLOCK) - ROCK_REACH)
	var high := Vector2i(floori(float(end.x) / ROCK_BLOCK) + ROCK_REACH,
		floori(float(end.y) / ROCK_BLOCK) + ROCK_REACH)
	for by in range(low.y, high.y + 1):
		for bx in range(low.x, high.x + 1):
			var block := Vector2i(bx, by)
			if _blocks.has(block):
				continue
			_blocks[block] = true
			for cell: Vector2i in rock_patch(block):
				_rock[cell] = true

func is_rock(cell: Vector2i) -> bool:
	return _rock.has(cell)

## Which atlas cell a rock tile draws, from its eight neighbours. Cached because
## it never changes and the alternative is nine dictionary lookups per cell per
## frame for a floor that is decided once.
func rock_slot(cell: Vector2i) -> int:
	if _slots.has(cell):
		return int(_slots[cell])
	var mask: int = 0
	var bits: Array[int] = [1, 2, 4, 8, 16, 32, 64, 128]
	var around: Array[Vector2i] = [
		Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
		Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)]
	for index in around.size():
		if _rock.has(cell + around[index]):
			mask |= bits[index]
	var slot: int = RockTiles.LOOKUP[mask]
	_slots[cell] = slot
	return slot

## Which of the sixteen a cell shows.
##
## A hash of the coordinates, not a random draw: the floor has to look the same
## every time the camera comes back to it, and the map is regenerated from a seed
## rather than stored. The multipliers are odd and coprime so the pattern does
## not fall into stripes along either axis, which two even ones do immediately.
static func tile_variant(cell: Vector2i) -> int:
	# Through the same avalanche the rock uses, and that is not decoration. The
	# first version was `x * 73856093 ^ y * 19349663` taken modulo sixteen, and
	# because both multipliers are odd that reduces to a function of x and y
	# modulo sixteen -- a perfectly regular lattice repeating every sixteen
	# tiles in both directions. Dumping a field made it obvious: every row read
	# 0, 13, 10, 7, 4, 1, ... and then started again. Multiplying by odd numbers
	# scatters the high bits; only a shift-xor moves them down where a modulo can
	# see them.
	return _mix(cell.x, cell.y, 3) % TILE_VARIANTS

static func tile_region(variant: int) -> Rect2:
	var index: int = clampi(variant, 0, TILE_VARIANTS - 1)
	var size: float = float(TILE_ATLAS.get_width()) / float(TILE_COLUMNS)
	return Rect2(float(index % TILE_COLUMNS) * size, float(index / TILE_COLUMNS) * size,
		size, size)

## One quad per visible cell, culled to the camera the way everything else is, so
## the cost follows the screen rather than the map.
func _draw_tiles() -> void:
	if sim == null:
		return
	var tile := float(Defs.TILE)
	var start := Vector2i((view_rect.position / tile).floor())
	var end := Vector2i((view_rect.end / tile).ceil())
	_ensure_rock(start, end)
	# Two passes, one texture each. Interleaving rock and snow would break the
	# batch at every switch, and a rock cell must not be drawn over a snow one:
	# both passes multiply, so a cell painted twice comes out twice as dark.
	for y in range(start.y, end.y + 1):
		for x in range(start.x, end.x + 1):
			var cell := Vector2i(x, y)
			if _rock.has(cell):
				continue
			_tile_layer.draw_texture_rect_region(TILE_ATLAS,
				Rect2(Vector2(cell) * tile, Vector2(tile, tile)),
				tile_region(tile_variant(cell)))
	for y in range(start.y, end.y + 1):
		for x in range(start.x, end.x + 1):
			var cell := Vector2i(x, y)
			if not _rock.has(cell):
				continue
			_tile_layer.draw_texture_rect_region(RockTiles.ATLAS,
				Rect2(Vector2(cell) * tile, Vector2(tile, tile)),
				RockTiles.region(rock_slot(cell)))
