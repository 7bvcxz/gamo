class_name IsoProjection
extends RefCounted

## Logical square tiles -> screen (world pixels), and back.
##
## The camera looks at the ground from 45 degrees of yaw and `elevation`
## degrees above the horizon, so a square tile is drawn as a diamond whose
## height is `tile_width * sin(elevation)`, and a vertical metre is drawn
## `cos(elevation)` as tall as a horizontal one. Every renderer, the input
## router and the camera use this one object, which is what keeps tiles,
## buildings, Momo and taps on the same grid.
##
## Cell (x, y) covers logical [x, x+1) x [y, y+1). Logical (0, 0) -- the north
## corner of cell (0, 0) -- is screen (0, 0). +x runs down-right, +y down-left.

var tile_width: float
var tile_height: float
## Screen pixels per tile-edge of height (z = 1.0 is as high as a tile is wide).
var height_scale: float
var cliff_height: float
var elevation_deg: float


func _init(p_tile_width: float = 128.0, p_elevation_deg: float = 50.0, p_cliff_height: float = 0.62) -> void:
	tile_width = p_tile_width
	elevation_deg = p_elevation_deg
	var elev := deg_to_rad(p_elevation_deg)
	# Even so that every corner (x +- w/2, y +- h/2) is a whole pixel.
	tile_height = roundf(p_tile_width * sin(elev) / 2.0) * 2.0
	height_scale = (p_tile_width / sqrt(2.0)) * cos(elev)
	cliff_height = p_cliff_height


static func from_data(data: GameData) -> IsoProjection:
	return IsoProjection.new(
		data.get_float("art", "projection.tile_width", 128.0),
		data.get_float("art", "projection.elevation_deg", 50.0),
		data.get_float("art", "projection.cliff_height", 0.62))


## Logical ground point (tile units, z up in tile-edge units) -> screen.
func to_screen(logical: Vector2, z: float = 0.0) -> Vector2:
	return Vector2((logical.x - logical.y) * tile_width * 0.5,
		(logical.x + logical.y) * tile_height * 0.5 - z * height_scale)


## Screen -> logical ground point on the z = 0 plane.
func to_logical(screen: Vector2) -> Vector2:
	var a := screen.x / (tile_width * 0.5)
	var b := screen.y / (tile_height * 0.5)
	return Vector2((a + b) * 0.5, (b - a) * 0.5)


## The cell under a screen point on the ground plane.
func cell_at(screen: Vector2) -> Vector2i:
	var l := to_logical(screen)
	return Vector2i(floori(l.x), floori(l.y))


## Centre of a cell's top face.
func cell_center(cell: Vector2i, z: float = 0.0) -> Vector2:
	return to_screen(Vector2(cell) + Vector2(0.5, 0.5), z)


## Top-face corners in order north, east, south, west.
func cell_corners(cell: Vector2i, z: float = 0.0) -> PackedVector2Array:
	var c := Vector2(cell)
	return PackedVector2Array([
		to_screen(c, z), to_screen(c + Vector2(1, 0), z),
		to_screen(c + Vector2(1, 1), z), to_screen(c + Vector2(0, 1), z)])


## Painter's order key for things standing on cells: larger is nearer.
static func depth(cell: Vector2i) -> int:
	return cell.x + cell.y
