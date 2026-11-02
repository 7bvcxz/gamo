class_name LabIso
extends RefCounted

## Logical square tiles -> screen, the game's projection (momonium
## src/render/projection.gd, the same numbers): 45 degrees of yaw, 50 degrees
## of elevation, a 128-pixel tile drawn as a diamond 98 pixels tall. Cell
## (x, y) covers logical [x, x+1) x [y, y+1); logical (0, 0) is screen (0, 0);
## +x runs down-right, +y down-left.

var tile_width: float
var tile_height: float
## Screen pixels per tile-edge of height.
var height_scale: float
## How far the cliffs drop, in tile edges.
var cliff_height: float


func _init(p_tile_width: float = 128.0, p_elevation_deg: float = 50.0, p_cliff_height: float = 0.62) -> void:
	tile_width = p_tile_width
	var elev := deg_to_rad(p_elevation_deg)
	tile_height = roundf(p_tile_width * sin(elev) / 2.0) * 2.0
	height_scale = (p_tile_width / sqrt(2.0)) * cos(elev)
	cliff_height = p_cliff_height


func to_screen(logical: Vector2, z: float = 0.0) -> Vector2:
	return Vector2((logical.x - logical.y) * tile_width * 0.5,
		(logical.x + logical.y) * tile_height * 0.5 - z * height_scale)


func to_logical(screen: Vector2) -> Vector2:
	var a := screen.x / (tile_width * 0.5)
	var b := screen.y / (tile_height * 0.5)
	return Vector2((a + b) * 0.5, (b - a) * 0.5)


func cell_center(cell: Vector2i, z: float = 0.0) -> Vector2:
	return to_screen(Vector2(cell) + Vector2(0.5, 0.5), z)


## Top-face corners: north, east, south, west.
func cell_corners(cell: Vector2i, z: float = 0.0) -> PackedVector2Array:
	var c := Vector2(cell)
	return PackedVector2Array([
		to_screen(c, z), to_screen(c + Vector2(1, 0), z),
		to_screen(c + Vector2(1, 1), z), to_screen(c + Vector2(0, 1), z)])


## How many pixels the cliff drops.
func drop() -> float:
	return cliff_height * height_scale
