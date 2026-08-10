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

## Which of the sixteen a cell shows.
##
## A hash of the coordinates, not a random draw: the floor has to look the same
## every time the camera comes back to it, and the map is regenerated from a seed
## rather than stored. The multipliers are odd and coprime so the pattern does
## not fall into stripes along either axis, which two even ones do immediately.
static func tile_variant(cell: Vector2i) -> int:
	var mixed: int = cell.x * 73856093 ^ cell.y * 19349663
	return absi(mixed) % TILE_VARIANTS

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
	for y in range(start.y, end.y + 1):
		for x in range(start.x, end.x + 1):
			var cell := Vector2i(x, y)
			_tile_layer.draw_texture_rect_region(TILE_ATLAS,
				Rect2(Vector2(cell) * tile, Vector2(tile, tile)),
				tile_region(tile_variant(cell)))
