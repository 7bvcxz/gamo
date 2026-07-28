extends Node2D
class_name GroundLayer

## The warm pool used to be forty concentric filled circles. Godot re-rasterises
## every draw command each frame regardless of queue_redraw(), so that cost about
## 2.9M pixels of fill per frame and pinned the software-WebGL build near 15 FPS.
## The ramp is scale-invariant, so it is baked once into a small texture and
## drawn as a single quad; growing the radius is then free.

const TEX_SIZE := 192

var sim: Sim
var night: float = 0.0
var view_rect := Rect2()

var _texture: ImageTexture

func _ready() -> void:
	_texture = _bake_pool()

## Redrawn every frame, but the whole layer is now one screen fill plus one
## textured quad, which is a fraction of the old forty-circle gradient.
func _process(_delta: float) -> void:
	queue_redraw()

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
			# A wide feather, but the ramp is already dark by the time alpha drops,
			# so blending toward the night never produces a mid-tone mud band.
			col.a = 1.0 if d < 0.74 else clampf((1.0 - d) / 0.26, 0.0, 1.0)
			image.set_pixel(x, y, col)
	return ImageTexture.create_from_image(image)

func _draw() -> void:
	if sim == null or _texture == null:
		return
	draw_rect(view_rect, Defs.COL_SNOW_COLD.lerp(Defs.COL_VOID, night * 0.55))
	var tile := float(Defs.TILE)
	var core_px: Vector2 = Vector2(sim.core_cell) * tile + Vector2.ONE * tile * 0.5
	var radius: float = sim.warm_radius * tile
	# Night darkens the pool through modulation rather than a second fill pass.
	var tint: Color = Color.WHITE.lerp(Color(0.55, 0.5, 0.6, 1.0), night * 0.5)
	draw_texture_rect(_texture, Rect2(core_px - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false, tint)
