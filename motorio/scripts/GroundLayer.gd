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
## The torch's own little pool, in world pixels. The fog opening a hole is not
## enough on its own: outside the warm circle the ground is painted with the cold
## fill and the tiles multiply against it, so a hole with no light in it shows
## dark navy. A torch that reveals a black disc is not a torch.
var torch_at := Vector2.ZERO
var torch_radius: float = 0.0

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
## Which cells carry boulders, worked out once per block and kept. The floor
## never changes, so the alternative is deciding it again every frame.
var _rock: Dictionary[Vector2i, bool] = {}
var _blocks: Dictionary[Vector2i, bool] = {}

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
	if torch_radius > 0.0:
		_draw_torch_light(tint)

## The ground under the torch.
##
## Not the fire's own gradient scaled down, which is what this was first: that
## texture is baked for the warm radius and at a sixth of the size it came out a
## dim grey disc -- the fog opened correctly and what it revealed looked like a
## hole rather than lit snow. Drawn here instead, as its own stack of rings, so
## how bright it is has one number and that number can be looked at.
const TORCH_RINGS := 9
const TORCH_STEP := 0.14
func _draw_torch_light(tint: Color) -> void:
	# Lit snow, with a little of the flame in it. The base fill out here is the
	# cold navy and the tiles multiply against it, so this has to carry the
	# ground all the way from dark to readable on its own.
	var lit: Color = Color(0.96, 0.965, 0.99).lerp(Defs.COL_CORE, 0.10)
	lit = lit * Color(tint.r, tint.g, tint.b, 1.0)
	for index in TORCH_RINGS:
		var k: float = float(index) / float(TORCH_RINGS)
		draw_circle(torch_at, torch_radius * (1.0 - k * 0.82),
			Color(lit.r, lit.g, lit.b, TORCH_STEP))

## Deterministic and cheap. Not a hash function anyone should trust with
## anything, but it has to give the same answer on every machine and every run,
## which rules out randi() and anything seeded from the clock.
static func _mix(a: int, b: int, salt: int) -> int:
	var h: int = (a * 73856093) ^ (b * 19349663) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return absi(h ^ (h >> 16))

## Which of the sixteen a cell shows.
##
## A hash of the coordinates, not a random draw: the floor has to look the same
## every time the camera comes back to it, and the map is regenerated from a seed
## rather than stored. The multipliers are odd and coprime so the pattern does
## not fall into stripes along either axis, which two even ones do immediately.
static func tile_variant(cell: Vector2i) -> int:
	# Through a proper avalanche, and that is not decoration. The
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

## --- Boulders ------------------------------------------------------------------
## Six tiles of snow with rocks lying on it. They have nothing to do with each
## other: there is no autotiling, no neighbour mask, and a cell simply picks one
## of the six. That is what makes this sheet work where the last one did not --
## a tile that never has to agree with its neighbour cannot disagree with it.
##
## Still decoration and nothing else: not in the simulation, not in the save, and
## walked straight over, so it stays a pure function of the coordinates.
## Seams, six variants each, picked at random the same way boulders are. Ore moved
## in here when it stopped being an obstacle and became terrain: it is a thing the
## player walks over now, so it is drawn with the other things the player walks
## over, in the same batched pass.
const ORE_COLUMNS := 3
const ORE_VARIANTS := 6
const HEATSTONE_ATLAS: Texture2D = preload("res://assets/tiles/heatstone_6.png")
const CRYSTAL_ATLAS: Texture2D = preload("res://assets/tiles/crystal_6.png")
const COPPER_ATLAS: Texture2D = preload("res://assets/tiles/copper_6.png")
## Which sheet each seam shows. Keyed by item type, so an ore without a sheet
## falls back to the painted shard in WorldLayer rather than drawing nothing.
const ORE_ATLAS: Dictionary[int, Texture2D] = {
	Defs.ITEM_HEATSTONE: HEATSTONE_ATLAS,
	Defs.ITEM_CRYSTAL: CRYSTAL_ATLAS,
	Defs.ITEM_COPPER: COPPER_ATLAS,
}
## Cut, committed and waiting on an ore to belong to. This game has heat stone,
## crystal and copper; coal, gold, iron and uranium are seams it does not, and their
## atlases are in assets/tiles/ already. A mapping entry cannot exist before the
## item type does, so promoting one is: add the ITEM_ constant, preload the file
## beside the two above, and put it in ORE_ATLAS.
const ORE_ATLASES_READY := ["coal_6.png", "gold_6.png", "iron_6.png", "uranium_6.png"]

const ROCK_ATLAS: Texture2D = preload("res://assets/tiles/rock_6.png")
const ROCK_COLUMNS := 3
const ROCK_VARIANTS := 6

## A twentieth of the ground, in clumps of one to twelve. One clump is seeded per
## block of ROCK_BLOCK cells, so the share is the average clump over the block:
## 6.5 over 11x11 is 5.4%, and clumps from neighbouring blocks overlapping brings
## the measured figure down to about five.
const ROCK_BLOCK := 11
const ROCK_MIN := 1
const ROCK_MAX := 12
## How far a clump can reach out of the block that seeded it. Twelve cells grown
## from one seed cannot travel further, so the blocks around a cell are the only
## ones that can claim it.
const ROCK_REACH := 1

## The cells one block's clump claims. Grown by filling its own concavities
## rather than by walking, which keeps clumps close to round -- a random walk
## produces strings one cell wide, and a line of separate boulder tiles reads as
## a dotted line rather than as a scatter of rocks.
static func rock_clump(block: Vector2i) -> Array[Vector2i]:
	var size: int = ROCK_MIN + _mix(block.x, block.y, 7) % (ROCK_MAX - ROCK_MIN + 1)
	var origin := Vector2i(
		block.x * ROCK_BLOCK + _mix(block.x, block.y, 11) % ROCK_BLOCK,
		block.y * ROCK_BLOCK + _mix(block.x, block.y, 13) % ROCK_BLOCK)
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
		var pick: Vector2i = best[_mix(block.x, block.y, 300 + cells.size()) % best.size()]
		cells.append(pick)
		have[pick] = true
	return cells

## Fills the cache for every block that could reach into this range. Called once
## per frame with the visible range rather than per cell.
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
			for cell: Vector2i in rock_clump(block):
				_rock[cell] = true

## The sheet this cell's seam draws from, or null if there is no seam here or its
## ore has no sheet yet -- in which case WorldLayer paints the shard instead.
static func ore_atlas_at(sim_ref, cell: Vector2i) -> Texture2D:
	if sim_ref == null or not sim_ref.ore.has(cell):
		return null
	return ORE_ATLAS.get(int(sim_ref.ore[cell]), null)

func _seam_atlas(cell: Vector2i) -> Texture2D:
	return ore_atlas_at(sim, cell)

func is_rock(cell: Vector2i) -> bool:
	return _rock.has(cell)

## Which of the six, on a different salt from the snow so a cell that turns to
## rock does not inherit its snow variant's number.
static func rock_variant(cell: Vector2i) -> int:
	return _mix(cell.x, cell.y, 29) % ROCK_VARIANTS

static func rock_region(variant: int) -> Rect2:
	var index: int = clampi(variant, 0, ROCK_VARIANTS - 1)
	var size: float = float(ROCK_ATLAS.get_width()) / float(ROCK_COLUMNS)
	return Rect2(float(index % ROCK_COLUMNS) * size, float(index / ROCK_COLUMNS) * size,
		size, size)

## Which of the six a seam shows. Its own salt, so a cell does not inherit the
## number its snow or its boulder would have had.
static func ore_variant(cell: Vector2i) -> int:
	return _mix(cell.x, cell.y, 61) % ORE_VARIANTS

static func ore_region(atlas: Texture2D, variant: int) -> Rect2:
	var index: int = clampi(variant, 0, ORE_VARIANTS - 1)
	var size: float = float(atlas.get_width()) / float(ORE_COLUMNS)
	return Rect2(float(index % ORE_COLUMNS) * size,
		float(index / ORE_COLUMNS) * size, size, size)

## One quad per visible cell, culled to the camera the way everything else is, so
## the cost follows the screen rather than the map.
func _draw_tiles() -> void:
	if sim == null:
		return
	var tile := float(Defs.TILE)
	var start := Vector2i((view_rect.position / tile).floor())
	var end := Vector2i((view_rect.end / tile).ceil())
	_ensure_rock(start, end)
	# Two passes, one texture each. Interleaving them would break the batch at
	# every switch, and a boulder cell must not be drawn over a snow one: both
	# passes multiply, so a cell painted twice comes out twice as dark.
	for y in range(start.y, end.y + 1):
		for x in range(start.x, end.x + 1):
			var cell := Vector2i(x, y)
			if _rock.has(cell) or _seam_atlas(cell) != null:
				continue
			_tile_layer.draw_texture_rect_region(TILE_ATLAS,
				Rect2(Vector2(cell) * tile, Vector2(tile, tile)),
				tile_region(tile_variant(cell)))
	for y in range(start.y, end.y + 1):
		for x in range(start.x, end.x + 1):
			var cell := Vector2i(x, y)
			if not _rock.has(cell) or _seam_atlas(cell) != null:
				continue
			_tile_layer.draw_texture_rect_region(ROCK_ATLAS,
				Rect2(Vector2(cell) * tile, Vector2(tile, tile)),
				rock_region(rock_variant(cell)))
	# A third pass because a seam cell must be painted once -- both passes above
	# multiply, so a cell drawn twice comes out twice as dark. Unlike them this
	# one can switch texture between cells, since two ores on screen are two
	# sheets; seams are tens of cells rather than the whole floor, so the broken
	# batch costs less than sorting them would.
	for y in range(start.y, end.y + 1):
		for x in range(start.x, end.x + 1):
			var cell := Vector2i(x, y)
			var atlas: Texture2D = _seam_atlas(cell)
			if atlas == null:
				continue
			_tile_layer.draw_texture_rect_region(atlas,
				Rect2(Vector2(cell) * tile, Vector2(tile, tile)),
				ore_region(atlas, ore_variant(cell)))
