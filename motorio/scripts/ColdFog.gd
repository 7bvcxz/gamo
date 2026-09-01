extends Node2D
class_name ColdFog

## World-space fog hiding everything outside the warm radius.
##
## It used to keep a nine tile preview band past the frontier so the next ore
## field was visible and worth walking to, and it was never dense enough to stop
## anyone exploring. Both of those are gone as of 0.20.70. Past the circle is
## white, and the way to see into it is to carry a light -- which turns
## exploring from "walk further" into "spend something", and is what the energy
## torch is for.
##
## The torch does not lift the fog; it punches a two tile hole in it that
## follows her. That is done in the shader rather than by drawing a lighter
## patch on top, because the fog is one full-screen quad and alpha cannot be
## subtracted by drawing over it.
##
## This used to rasterise its puff field live -- a 1.7-tile grid of 2.9-tile
## circles, so every fogged pixel was painted about nine times, plus a scalloped
## bank of up to 170 more circles along the frontier. Measured on a 1920x1080
## canvas that was around 70% of the whole frame: disabling this one layer took
## the build from 3.7 to 10.3 FPS, and from 1.5 to 5.0 at 2880x1800. Cost scaled
## with canvas pixels, which is why a HiDPI laptop suffered where a phone did
## not.
##
## Both fields depend on distance from the core alone, so they are now summed
## once into a small radial texture and drawn as a single quad -- the same trick
## GroundLayer uses for the warm pool. Per frame this layer is one textured quad
## plus at most four flat fills.

## How far past the warm edge the fog takes to close. Not a preview any more --
## it is the softness of the edge, and at two tiles you can see the ground you
## are about to step onto and nothing beyond it.
const PREVIEW_BAND := 2.0
## Heavy overlap: at low alpha, sparse puffs read as separate bubbles rather
## than as weather. Radius well above spacing is what makes it merge.
const PUFF_SPACING := 1.7
const PUFF_RADIUS := 2.9
## Solid fog baked past the preview band, so the quad's own edge never lands
## anywhere the alpha is still changing.
const EDGE_MARGIN := 5.0
const TEX_SIZE := 128
## A rebake waits for the radius to actually travel rather than firing on every
## delivery; the profile only moves when the radius does.
const REBAKE_STEP := 0.4
const PROFILE_SAMPLES := 64
## Rings averaged per sample. A single ray through a wobbled grid is lumpy;
## averaging around the circle is what makes the baked ramp match the eye's
## impression of the old field rather than one arbitrary slice through it.
const PROFILE_ANGLES := 8
## The field's puffs are 2.9 tiles across and are only skipped when their centre
## is inside the warm edge, so they bleed inward past it. Sampling that far in
## keeps the hole's edge as soft as the circles made it instead of cutting it
## into a hard disc.
const INNER_BLEED := PUFF_RADIUS

var sim: Sim
var view_rect := Rect2()
var night: float = 0.0

var _texture: ImageTexture
var _baked_radius: float = -1000.0
var _extent_tiles: float = 0.0
var _far_alpha: float = 0.0

## Where the torch hole is, in world pixels, and how big. Set by Main every
## frame; radius 0 means no light and the shader does nothing.
var torch_at := Vector2.ZERO
var torch_radius: float = 0.0

## World coordinates, carried into the fragment stage as a varying.
##
## The first version used FRAGCOORD and a position converted to viewport pixels,
## and the hole landed somewhere else entirely -- the game stretches its canvas
## from a 960x540 base, so the two spaces are neither the same nor a clean scale
## apart. This layer is a Node2D at the world origin, so its own vertices are
## already in world pixels and the shader can compare like with like.
const HOLE_SHADER := """
shader_type canvas_item;
uniform vec2 hole_at;
uniform float hole_radius;
varying vec2 world_pos;
void vertex() {
	world_pos = VERTEX;
}
void fragment() {
	if (hole_radius > 0.0) {
		float d = distance(world_pos, hole_at);
		// Fully clear at the centre, fully fogged at the edge. The inner two
		// thirds are clear so the hole reads as a lit circle rather than as a
		// smudge that never quite opens.
		COLOR.a *= smoothstep(hole_radius * 0.62, hole_radius, d);
	}
}
"""

func _ready() -> void:
	# The project default is nearest filtering, which would show this texture's
	# ramp as concentric steps once it is stretched across the whole band.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var shader := Shader.new()
	shader.code = HOLE_SHADER
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	material = shader_material

func _process(_delta: float) -> void:
	if sim != null and absf(sim.shown_radius - _baked_radius) >= REBAKE_STEP:
		rebake(sim.shown_radius)
	var shader_material: ShaderMaterial = material as ShaderMaterial
	if shader_material != null:
		shader_material.set_shader_parameter("hole_at", torch_at)
		shader_material.set_shader_parameter("hole_radius", torch_radius)
	queue_redraw()

## 0 at the warm edge, 1 once past the preview band.
func fog_strength(distance_tiles: float) -> float:
	if sim == null:
		return 0.0
	var beyond: float = distance_tiles - sim.shown_radius
	if beyond <= 0.0:
		return 0.0
	return clampf(beyond / PREVIEW_BAND, 0.0, 1.0)

func fog_alpha_for_cell(cell: Vector2i) -> float:
	if sim == null:
		return 0.0
	var strength: float = fog_strength(Vector2(cell - sim.core_cell).length())
	if strength <= 0.0:
		return 0.0
	return 0.16 + strength * 0.72

## Alpha accumulated at one point from both fields, in the same over-operator
## order the draw calls used, so the bake reproduces the image the circles made
## instead of approximating it with a guessed curve.
func _alpha_at(at: Vector2, warm_tiles: float, bank: PackedVector3Array) -> float:
	var tile := float(Defs.TILE)
	var spacing: float = tile * PUFF_SPACING
	var radius: float = tile * PUFF_RADIUS
	var warm_px: float = warm_tiles * tile
	var alpha: float = 0.0
	var reach: int = int(ceil(radius / spacing)) + 1
	var gx0: int = int(floor(at.x / spacing))
	var gy0: int = int(floor(at.y / spacing))
	for gy in range(gy0 - reach, gy0 + reach + 1):
		for gx in range(gx0 - reach, gx0 + reach + 1):
			var wobble := Vector2(sin(float(gy * 7 + gx)) * 18.0, cos(float(gx * 5 - gy)) * 14.0)
			var centre: Vector2 = Vector2(float(gx) * spacing, float(gy) * spacing) + wobble
			var from_core: float = centre.length()
			if from_core <= warm_px + radius * 0.42:
				continue
			if centre.distance_to(at) > radius:
				continue
			var strength: float = clampf((from_core / tile - warm_tiles) / PREVIEW_BAND, 0.0, 1.0)
			var a: float = 0.07 + strength * 0.30
			alpha = alpha + a - alpha * a
	# The scalloped bank that marks the frontier itself. Its circles are the same
	# for every sample, so they arrive precomputed as (x, y, radius).
	for entry: Vector3 in bank:
		var distance: float = Vector2(entry.x, entry.y).distance_to(at)
		if distance > entry.z * 1.3:
			continue
		alpha = alpha + 0.16 - alpha * 0.16
		if distance <= entry.z:
			alpha = alpha + 0.5 - alpha * 0.5
	return clampf(alpha, 0.0, 1.0)

## The frontier bank's circles, as (x, y, radius). Built once per bake rather
## than re-derived for every sample point, which was most of the bake's cost.
func _bank_circles(warm_tiles: float) -> PackedVector3Array:
	var tile := float(Defs.TILE)
	var warm_px: float = warm_tiles * tile
	var count: int = maxi(28, int(TAU * warm_px / (tile * 1.6)))
	var out := PackedVector3Array()
	out.resize(count)
	for index in count:
		var angle: float = TAU * float(index) / float(count)
		var jitter: float = sin(float(index) * 2.17) * 9.0 + cos(float(index) * 0.73) * 6.0
		var centre: Vector2 = Vector2.from_angle(angle) * (warm_px + tile * 1.1 + jitter)
		out[index] = Vector3(centre.x, centre.y, tile * (1.2 + 0.2 * sin(float(index) * 1.91)))
	return out

## Accumulated alpha as a function of distance past the warm edge.
func _sample_profile(warm_tiles: float) -> PackedFloat32Array:
	var tile := float(Defs.TILE)
	var bank: PackedVector3Array = _bank_circles(warm_tiles)
	var span: float = PREVIEW_BAND + EDGE_MARGIN + INNER_BLEED
	var out := PackedFloat32Array()
	out.resize(PROFILE_SAMPLES)
	for index in PROFILE_SAMPLES:
		var d_tiles: float = warm_tiles - INNER_BLEED + span * float(index) / float(PROFILE_SAMPLES - 1)
		var total: float = 0.0
		for step in PROFILE_ANGLES:
			var angle: float = TAU * float(step) / float(PROFILE_ANGLES)
			total += _alpha_at(Vector2.from_angle(angle) * d_tiles * tile, warm_tiles, bank)
		out[index] = clampf(total / float(PROFILE_ANGLES), 0.0, 1.0)
	return out

## Public so a test can force a bake without accumulating heat first.
func rebake(warm_tiles: float) -> void:
	_baked_radius = warm_tiles
	_extent_tiles = warm_tiles + PREVIEW_BAND + EDGE_MARGIN
	var profile: PackedFloat32Array = _sample_profile(warm_tiles)
	_far_alpha = profile[profile.size() - 1]
	var span: float = PREVIEW_BAND + EDGE_MARGIN + INNER_BLEED
	var image := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	var middle: float = float(TEX_SIZE - 1) * 0.5
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			var d: float = Vector2(float(x) - middle, float(y) - middle).length() / middle
			var beyond: float = d * _extent_tiles - warm_tiles + INNER_BLEED
			var alpha: float = 0.0
			if beyond > 0.0:
				var t: float = clampf(beyond / span, 0.0, 1.0) * float(PROFILE_SAMPLES - 1)
				var low: int = int(floor(t))
				var high: int = mini(low + 1, PROFILE_SAMPLES - 1)
				alpha = lerpf(profile[low], profile[high], t - float(low))
			# White with the profile in alpha, so the draw call's modulate can
			# supply both the colour and the night tint without a second pass.
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	_texture = ImageTexture.create_from_image(image)

## Half-width of the baked square, in world pixels.
func baked_extent_px() -> float:
	return _extent_tiles * float(Defs.TILE)

func far_alpha() -> float:
	return _far_alpha

func has_bake() -> bool:
	return _texture != null

func _draw() -> void:
	if sim == null or _texture == null:
		return
	var tile := float(Defs.TILE)
	var core_px: Vector2 = Vector2(sim.core_cell) * tile + Vector2.ONE * tile * 0.5
	var fog: Color = Color(0.94, 0.975, 1.0).lerp(Color(0.62, 0.70, 0.85), night * 0.5)
	var extent: float = baked_extent_px()
	var square := Rect2(core_px - Vector2.ONE * extent, Vector2.ONE * extent * 2.0)
	draw_texture_rect(_texture, square, false, fog)

	# Past the square the fog is uniform, so the rest of the view is flat fills
	# rather than more texture. The square's own border already sits at this
	# alpha, so the seam is invisible.
	var far := Color(fog.r, fog.g, fog.b, _far_alpha)
	var band_top: float = maxf(view_rect.position.y, square.position.y)
	var band_bottom: float = minf(view_rect.end.y, square.end.y)
	if view_rect.position.y < square.position.y:
		draw_rect(Rect2(view_rect.position,
			Vector2(view_rect.size.x, square.position.y - view_rect.position.y)), far)
	if view_rect.end.y > square.end.y:
		draw_rect(Rect2(Vector2(view_rect.position.x, square.end.y),
			Vector2(view_rect.size.x, view_rect.end.y - square.end.y)), far)
	if band_bottom > band_top:
		if view_rect.position.x < square.position.x:
			draw_rect(Rect2(Vector2(view_rect.position.x, band_top),
				Vector2(square.position.x - view_rect.position.x, band_bottom - band_top)), far)
		if view_rect.end.x > square.end.x:
			draw_rect(Rect2(Vector2(square.end.x, band_top),
				Vector2(view_rect.end.x - square.end.x, band_bottom - band_top)), far)
