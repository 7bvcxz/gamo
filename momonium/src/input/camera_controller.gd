class_name CameraController
extends Node

## Owns the world camera: pan, zoom about a point, limits, and conversions
## between screen (viewport) and world coordinates.
##
## Limits grow with the island. The camera centre stays within the island's
## projected bounds plus a margin, so the island can never be lost off-screen,
## and zoom runs from "the whole island with room around it" to "one tile fills
## most of the width" -- both derived from the island, so a 2x2 start and a
## thousand-cell island get sensible ranges without new constants.

signal changed

## Island centre on screen, as a fraction of height: below the sky band.
const ISLAND_SCREEN_Y := 0.68
## Default framing: the island takes this much of the width (phones) or height.
const FIT_WIDTH := 0.74
const FIT_HEIGHT := 0.46
## Zoom limits relative to the default framing of the current island.
const MIN_ZOOM_OF_FIT := 0.45
## Closest zoom: one tile spans this fraction of the screen width.
const MAX_TILE_SCREEN_FRACTION := 0.8
const MARGIN_TILES := 1.5

var camera: Camera2D
var projection: IsoProjection
var world: WorldSystem
var fit_zoom := 1.0


func setup(p_camera: Camera2D, p_projection: IsoProjection, p_world: WorldSystem) -> void:
	camera = p_camera
	projection = p_projection
	world = p_world


func viewport_size() -> Vector2:
	return camera.get_viewport_rect().size


## Island bounds on screen (world pixels), cliffs included.
func island_rect() -> Rect2:
	var b := world.bounds()
	var pts := PackedVector2Array()
	for cell: Vector2i in [b.position, b.end - Vector2i.ONE, Vector2i(b.position.x, b.end.y - 1), Vector2i(b.end.x - 1, b.position.y)]:
		pts.append_array(projection.cell_corners(cell))
	var rect := Rect2(pts[0], Vector2.ZERO)
	for p: Vector2 in pts:
		rect = rect.expand(p)
	return rect.grow_side(SIDE_BOTTOM, projection.cliff_height * projection.height_scale)


## Frames the whole island below the sky band.
func frame_island() -> void:
	var size := viewport_size()
	var rect := island_rect()
	fit_zoom = clampf(minf(size.x * FIT_WIDTH / maxf(rect.size.x, 1.0), size.y * FIT_HEIGHT / maxf(rect.size.y, 1.0)), 0.05, 8.0)
	camera.zoom = Vector2(fit_zoom, fit_zoom)
	camera.position = rect.get_center() - Vector2(0, (ISLAND_SCREEN_Y - 0.5) * size.y / fit_zoom)
	_clamp()
	changed.emit()


## The window changed shape (rotation, browser bars): keep what the player was
## looking at, but recompute the limits and clamp into them. Re-framing here
## would undo their pan every time a mobile browser shows its address bar.
func on_resize() -> void:
	var size := viewport_size()
	var rect := island_rect()
	fit_zoom = clampf(minf(size.x * FIT_WIDTH / maxf(rect.size.x, 1.0), size.y * FIT_HEIGHT / maxf(rect.size.y, 1.0)), 0.05, 8.0)
	var z := clampf(camera.zoom.x, min_zoom(), max_zoom())
	camera.zoom = Vector2(z, z)
	_clamp()
	changed.emit()


func min_zoom() -> float:
	return fit_zoom * MIN_ZOOM_OF_FIT


func max_zoom() -> float:
	return maxf(viewport_size().x * MAX_TILE_SCREEN_FRACTION / projection.tile_width, fit_zoom)


func zoom_level() -> float:
	return camera.zoom.x


# --- conversions ----------------------------------------------------------------

func screen_to_world(screen: Vector2) -> Vector2:
	return camera.get_canvas_transform().affine_inverse() * screen


func world_to_screen(world_pos: Vector2) -> Vector2:
	return camera.get_canvas_transform() * world_pos


func screen_to_cell(screen: Vector2) -> Vector2i:
	return projection.cell_at(screen_to_world(screen))


# --- moves ----------------------------------------------------------------------

## Moves the view by a screen-space drag: the ground follows the finger.
func pan_screen(delta: Vector2) -> void:
	camera.position -= delta / camera.zoom.x
	_clamp()
	changed.emit()


## Multiplies zoom by `factor`, keeping the world point under `screen_point`
## where it is (pinch midpoint, mouse cursor).
func zoom_at(factor: float, screen_point: Vector2) -> void:
	var before := screen_to_world(screen_point)
	var z := clampf(camera.zoom.x * factor, min_zoom(), max_zoom())
	camera.zoom = Vector2(z, z)
	camera.force_update_scroll()
	var after := screen_to_world(screen_point)
	camera.position += before - after
	_clamp()
	changed.emit()


func _clamp() -> void:
	var margin := projection.tile_width * MARGIN_TILES
	var limit := island_rect().grow(margin)
	# The island's centre is shown below the sky band, so the camera centre that
	# frames it sits above it by that offset; allow for that in the limits.
	var offset := (ISLAND_SCREEN_Y - 0.5) * viewport_size().y / camera.zoom.x
	limit.position.y -= offset
	camera.position = Vector2(clampf(camera.position.x, limit.position.x, limit.end.x),
		clampf(camera.position.y, limit.position.y, limit.end.y))
	camera.force_update_scroll()
