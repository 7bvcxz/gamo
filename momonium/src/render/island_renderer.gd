class_name IslandRenderer
extends Node2D

## Draws owned land as an elevated 2.5D island: textured grass tops with their
## 1x1 boundaries, a grass lip over each exposed edge, dirt-and-stone cliff
## faces down to the water, a shallow-water halo and foam where cliff meets sea.
##
## Everything is projected through the one IsoProjection, and textures are
## mapped in logical tile space (not screen space) -- the grass on cell (3, 4)
## continues the grass on (2, 4) exactly, whatever the camera does.
##
## Painter's order: cells are drawn nearest-last (depth x+y, then x), each one
## face-then-top, because a back cell's cliff can reach down behind a front
## cell's top. Decorations are derived from the cell here and never enter the
## simulation, so a flower can never block a building.

## Grass texture repeats once every this many tiles.
const GRASS_TILES_PER_TEXTURE := 2.0
const STONE_TILES_PER_TEXTURE := 2.0
## Fraction of the cliff that is dirt; the rest is stone blocks.
const DIRT_FRACTION := 0.32
## The lit side faces down-left (light from the upper left, as in the art).
const LEFT_FACE_LIGHT := 1.0
const RIGHT_FACE_LIGHT := 0.78

var _world: WorldSystem
var _proj: IsoProjection
var _grass_tex: Texture2D
var _dirt_tex: Texture2D
var _stone_tex: Texture2D
var _rim: Color
var _shallow: Color
var _boundary := Color(0.25, 0.45, 0.12, 0.28)
var _boundary_light := Color(1, 1, 0.8, 0.22)
## Cells currently hidden from decoration (occupied by something).
var _occupied: Dictionary = {}
var _order: Array[Vector2i] = []


func setup(sim: Simulation, projection: IsoProjection) -> void:
	_world = sim.system(&"world")
	_proj = projection
	_grass_tex = load("res://assets/textures/grass.png")
	_dirt_tex = load("res://assets/textures/dirt.png")
	_stone_tex = load("res://assets/textures/stone.png")
	_rim = sim.data.color("grass_rim")
	_shallow = sim.data.color("sea_day", 3)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sim.bus.emitted.connect(_on_event)
	_rebuild()


func _on_event(type: StringName, _payload: Dictionary) -> void:
	if type in [&"land_added", &"game_loaded", &"occupancy_changed"]:
		_rebuild()


## The order cells are painted in: farthest first.
func paint_order() -> Array[Vector2i]:
	return _order


## Cliff faces show only below the two near edges (+x and +y) where the
## neighbour is sea; far edges are hidden behind the top, inner edges by land.
func is_face_visible(cell: Vector2i, direction: Vector2i) -> bool:
	return (direction == Vector2i(1, 0) or direction == Vector2i(0, 1)) and not _world.is_owned(cell + direction)


func visible_face_count() -> int:
	var n := 0
	for cell: Vector2i in _order:
		n += int(is_face_visible(cell, Vector2i(1, 0))) + int(is_face_visible(cell, Vector2i(0, 1)))
	return n


## The decorations a cell would show: [kind, logical position]. Pure function
## of the cell, so the same cell always looks the same.
static func decals_for(cell: Vector2i) -> Array:
	var rng := _rng(cell, 3)
	var out: Array = []
	for i in rng.randi_range(0, 3):
		var at := Vector2(cell) + Vector2(rng.randf_range(0.18, 0.82), rng.randf_range(0.18, 0.82))
		out.append([rng.randi_range(0, 2), at])
	return out


func _rebuild() -> void:
	_order = _world.owned_cells()
	_order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := IsoProjection.depth(a)
		var db := IsoProjection.depth(b)
		return da < db or (da == db and a.x < b.x))
	_occupied = _world.occupancy.duplicate()
	queue_redraw()


func _draw() -> void:
	if _world == null:
		return
	var water_z := -_proj.cliff_height
	# Shallow water and foam halo, under everything.
	for cell: Vector2i in _order:
		_draw_shallows(cell, water_z)
	for cell: Vector2i in _order:
		var east_open := is_face_visible(cell, Vector2i(1, 0))
		var south_open := is_face_visible(cell, Vector2i(0, 1))
		if east_open:
			_draw_face(cell, Vector2(cell.x + 1, cell.y), Vector2(cell.x + 1, cell.y + 1), RIGHT_FACE_LIGHT, float(cell.y))
		if south_open:
			_draw_face(cell, Vector2(cell.x, cell.y + 1), Vector2(cell.x + 1, cell.y + 1), LEFT_FACE_LIGHT, float(cell.x))
		_draw_top(cell)
		_draw_rims(cell, east_open, south_open)
		if not _occupied.has(cell):
			_draw_decals(cell)


func _draw_top(cell: Vector2i) -> void:
	var corners := _proj.cell_corners(cell)
	var c := Vector2(cell)
	var s := 1.0 / GRASS_TILES_PER_TEXTURE
	var uvs := PackedVector2Array([c * s, (c + Vector2(1, 0)) * s, (c + Vector2(1, 1)) * s, (c + Vector2(0, 1)) * s])
	draw_polygon(corners, PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]), uvs, _grass_tex)
	# The 1x1 boundary: a soft dark line on the far edges and a light one on the
	# near edges reads as a shallow bevel rather than a drawn grid.
	draw_line(corners[3], corners[0], _boundary, 1.6, true)
	draw_line(corners[0], corners[1], _boundary, 1.6, true)
	draw_line(corners[1], corners[2], _boundary_light, 1.2, true)
	draw_line(corners[2], corners[3], _boundary_light, 1.2, true)


## One vertical cliff face hanging below the logical edge a-b. `u0` is where
## along the coast this face starts, so blocks line up across neighbours.
func _draw_face(_cell: Vector2i, a: Vector2, b: Vector2, light: float, u0: float) -> void:
	var top_a := _proj.to_screen(a)
	var top_b := _proj.to_screen(b)
	var depth := _proj.cliff_height * _proj.height_scale
	var dirt_h := depth * DIRT_FRACTION
	var tint := Color(light, light, light)
	var su := 1.0 / STONE_TILES_PER_TEXTURE
	var u_a := u0 * su
	var u_b := (u0 + 1.0) * su
	# Dirt band.
	var dirt := PackedVector2Array([top_a, top_b, top_b + Vector2(0, dirt_h), top_a + Vector2(0, dirt_h)])
	draw_polygon(dirt, PackedColorArray([tint, tint, tint, tint]),
		PackedVector2Array([Vector2(u_a, 0), Vector2(u_b, 0), Vector2(u_b, 0.5), Vector2(u_a, 0.5)]), _dirt_tex)
	# Stone blocks, darkening towards the water.
	var deep := Color(light * 0.82, light * 0.84, light * 0.9)
	var stone := PackedVector2Array([top_a + Vector2(0, dirt_h), top_b + Vector2(0, dirt_h), top_b + Vector2(0, depth), top_a + Vector2(0, depth)])
	var v1 := (depth - dirt_h) / (_proj.tile_width / sqrt(2.0)) * 2.0 * su
	draw_polygon(stone, PackedColorArray([tint, tint, deep, deep]),
		PackedVector2Array([Vector2(u_a, 0), Vector2(u_b, 0), Vector2(u_b, v1), Vector2(u_a, v1)]), _stone_tex)
	# Foam where the cliff meets the sea.
	draw_line(top_a + Vector2(0, depth), top_b + Vector2(0, depth), Color(1, 1, 1, 0.85), 3.0, true)
	draw_line(top_a + Vector2(0, depth + 3), top_b + Vector2(0, depth + 3), Color(1, 1, 1, 0.35), 4.0, true)


## A lighter grass lip spilling a few pixels over each exposed near edge, and a
## thin highlight on exposed far edges.
func _draw_rims(cell: Vector2i, east_open: bool, south_open: bool) -> void:
	var corners := _proj.cell_corners(cell)
	var lip := 7.0
	if east_open:
		_lip(corners[1], corners[2], lip, cell)
	if south_open:
		_lip(corners[3], corners[2], lip, cell)
	if not _world.is_owned(cell + Vector2i(-1, 0)):
		draw_line(corners[3], corners[0], _rim, 2.2, true)
	if not _world.is_owned(cell + Vector2i(0, -1)):
		draw_line(corners[0], corners[1], _rim, 2.2, true)


func _lip(a: Vector2, b: Vector2, depth: float, cell: Vector2i) -> void:
	var pts := PackedVector2Array([a, b])
	var steps := 8
	var rng := _rng(cell, 7)
	for i in range(steps, -1, -1):
		var t := float(i) / steps
		var wobble := depth * (0.55 + 0.45 * rng.randf())
		pts.append(a.lerp(b, t) + Vector2(0, wobble))
	draw_colored_polygon(pts, _rim)


## Shallow water fading out from the island: three widening rings of the
## shallow colour, each fainter, so the edge reads as depth rather than a plate.
func _draw_shallows(cell: Vector2i, water_z: float) -> void:
	var centre := _proj.cell_center(cell, water_z)
	var corners := _proj.cell_corners(cell, water_z)
	for ring: Array in [[1.55, 0.14], [1.38, 0.18], [1.2, 0.26]]:
		var halo := PackedVector2Array()
		for c: Vector2 in corners:
			halo.append(centre + (c - centre) * float(ring[0]))
		draw_colored_polygon(halo, Color(_shallow, float(ring[1])))


## Flowers and tufts: derived from the cell, deterministic, purely visual.
func _draw_decals(cell: Vector2i) -> void:
	for decal: Array in decals_for(cell):
		var p := _proj.to_screen(decal[1])
		match int(decal[0]):
			0:
				for k in 5:
					var ang := TAU * k / 5.0
					draw_circle(p + Vector2(cos(ang), sin(ang) * 0.7) * 2.6, 1.9, Color("#ffffff"))
				draw_circle(p, 1.5, Color("#ffd34d"))
			1:
				draw_circle(p, 2.2, Color("#ffd34d"))
				draw_circle(p + Vector2(4, 1), 1.8, Color("#fff4b0"))
			_:
				for k in 3:
					draw_line(p + Vector2(k * 2 - 2, 0), p + Vector2(k * 3 - 3, -5), Color("#5f9e2c"), 1.4, true)


## Deterministic per-cell randomness. A proper integer mixer: a multiply-xor
## of coordinates modulo a small number repeats on a fixed period, which shows
## up as stripes of identical decoration across a large island.
static func _rng(cell: Vector2i, salt: int) -> RandomNumberGenerator:
	var h := (cell.x * 0x27d4eb2d) ^ (cell.y * 0x165667b1) ^ (salt * 0x9e3779b9)
	h = (h ^ (h >> 15)) * 0x2c1b3c6d
	h = (h ^ (h >> 12)) * 0x297a2d39
	h ^= h >> 15
	var rng := RandomNumberGenerator.new()
	rng.seed = h & 0x7fffffffffffffff
	return rng
