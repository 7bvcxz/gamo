class_name IslandRenderer
extends Node2D

## Draws owned land as an elevated 2.5D island: textured grass tops with their
## 1x1 boundaries, a grass lip over each exposed edge and dirt-and-stone cliff
## faces down to the water. Shallows and moving foam belong to the ocean.
##
## The island is baked into three meshes whenever land or occupancy changes,
## and each frame draws just those three -- whatever the island's size:
##   faces    cliff texture, every visible face, far to near
##   tops     grass texture, every top and its lip, far to near
##   overlay  untextured: 1x1 boundaries and decorations
## Faces go before tops because a top can only ever cover a face that is
## farther away, and within each mesh triangles are emitted far-to-near, which
## is the painter's order inside one draw call. (A per-cell immediate-mode
## version drew the same picture at 1.9 fps for a 30x30 island.)
##
## Textures are mapped in logical tile space, not screen space, so the grass on
## (3, 4) continues the grass on (2, 4) exactly, wherever the camera is.
## Decorations are derived from the cell and never enter the simulation, so a
## flower can never block a building.

const GRASS_TILES_PER_TEXTURE := 2.0
const CLIFF_TILES_PER_TEXTURE := 2.0
## The lit side faces down-left (light from the upper left, as in the art).
const LEFT_FACE_LIGHT := 1.0
const RIGHT_FACE_LIGHT := 0.78
const LIP_DEPTH := 7.0
const LIP_STEPS := 8
const LIP_TINT := Color(1.12, 1.14, 0.86)
const BOUNDARY_DARK := Color(0.25, 0.45, 0.12, 0.28)
const BOUNDARY_LIGHT := Color(1, 1, 0.8, 0.22)

var _world: WorldSystem
var _proj: IsoProjection
var _grass_tex: Texture2D
var _cliff_tex: Texture2D
var _order: Array[Vector2i] = []
var faces_mesh := ArrayMesh.new()
var tops_mesh := ArrayMesh.new()
var overlay_mesh := ArrayMesh.new()
var last_build_ms := 0.0


func setup(sim: Simulation, projection: IsoProjection) -> void:
	_world = sim.system(&"world")
	_proj = projection
	_grass_tex = load("res://assets/textures/grass.png")
	_cliff_tex = load("res://assets/textures/cliff.png")
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sim.bus.emitted.connect(_on_event)
	rebuild()


## Changes are coalesced: many cells bought or built in one frame (a load, a
## blueprint) cost one rebuild, at the start of the next frame.
func _on_event(type: StringName, _payload: Dictionary) -> void:
	if type in [&"land_added", &"game_loaded", &"occupancy_changed"] and not _dirty:
		_dirty = true
		rebuild.call_deferred()


var _dirty := false


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


func rebuild() -> void:
	_dirty = false
	var t0 := Time.get_ticks_usec()
	_order = _world.owned_cells()
	_order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := IsoProjection.depth(a)
		var db := IsoProjection.depth(b)
		return da < db or (da == db and a.x < b.x))
	var faces := _Batch.new()
	var tops := _Batch.new()
	var overlay := _Batch.new()
	for cell: Vector2i in _order:
		var east_open := is_face_visible(cell, Vector2i(1, 0))
		var south_open := is_face_visible(cell, Vector2i(0, 1))
		if east_open:
			_face(faces, Vector2(cell.x + 1, cell.y), Vector2(cell.x + 1, cell.y + 1), RIGHT_FACE_LIGHT, float(cell.y))
		if south_open:
			_face(faces, Vector2(cell.x, cell.y + 1), Vector2(cell.x + 1, cell.y + 1), LEFT_FACE_LIGHT, float(cell.x))
		_top(tops, cell)
		var corners := _proj.cell_corners(cell)
		if east_open:
			_lip(tops, corners[1], corners[2], cell)
		if south_open:
			_lip(tops, corners[3], corners[2], cell)
		_boundaries(overlay, cell, corners)
		if not _world.is_occupied(cell):
			_decals(overlay, cell)
	faces.commit(faces_mesh)
	tops.commit(tops_mesh)
	overlay.commit(overlay_mesh)
	last_build_ms = (Time.get_ticks_usec() - t0) / 1000.0
	queue_redraw()


func _draw() -> void:
	draw_mesh(faces_mesh, _cliff_tex)
	draw_mesh(tops_mesh, _grass_tex)
	draw_mesh(overlay_mesh, null)


# --- geometry ---------------------------------------------------------------------

func _top(b: _Batch, cell: Vector2i) -> void:
	var corners := _proj.cell_corners(cell)
	var c := Vector2(cell)
	var s := 1.0 / GRASS_TILES_PER_TEXTURE
	b.quad(corners, PackedVector2Array([c * s, (c + Vector2(1, 0)) * s, (c + Vector2(1, 1)) * s, (c + Vector2(0, 1)) * s]),
		[Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])


## One vertical cliff face hanging below the logical edge a-b. `u0` is where
## along the coast this face starts, so blocks line up across neighbours.
func _face(b: _Batch, a: Vector2, c: Vector2, light: float, u0: float) -> void:
	var top_a := _proj.to_screen(a)
	var top_c := _proj.to_screen(c)
	var down := Vector2(0, _proj.cliff_height * _proj.height_scale)
	var su := 1.0 / CLIFF_TILES_PER_TEXTURE
	var lit := Color(light, light, light)
	var deep := Color(light * 0.8, light * 0.83, light * 0.9)
	b.quad(PackedVector2Array([top_a, top_c, top_c + down, top_a + down]),
		PackedVector2Array([Vector2(u0 * su, 0), Vector2((u0 + 1.0) * su, 0), Vector2((u0 + 1.0) * su, 1), Vector2(u0 * su, 1)]),
		[lit, lit, deep, deep])


## A lighter grass lip spilling a few pixels over an exposed near edge. Drawn
## with the grass texture so it reads as the same turf, just catching light.
func _lip(b: _Batch, a: Vector2, c: Vector2, cell: Vector2i) -> void:
	var rng := _rng(cell, 7 + int(a.x * 13.0))
	var la := _proj.to_logical(a)
	var lc := _proj.to_logical(c)
	var s := 1.0 / GRASS_TILES_PER_TEXTURE
	for i in LIP_STEPS:
		var t0 := float(i) / LIP_STEPS
		var t1 := float(i + 1) / LIP_STEPS
		var p0 := a.lerp(c, t0)
		var p1 := a.lerp(c, t1)
		var d0 := LIP_DEPTH * (0.55 + 0.45 * rng.randf())
		var d1 := LIP_DEPTH * (0.55 + 0.45 * rng.randf())
		var u0 := la.lerp(lc, t0) * s
		var u1 := la.lerp(lc, t1) * s
		b.quad(PackedVector2Array([p0, p1, p1 + Vector2(0, d1), p0 + Vector2(0, d0)]),
			PackedVector2Array([u0, u1, u1 + Vector2(0, 0.02), u0 + Vector2(0, 0.02)]),
			[LIP_TINT, LIP_TINT, LIP_TINT, LIP_TINT])


## The 1x1 boundary: a soft dark line on the far edges and a light one on the
## near edges reads as a shallow bevel rather than a drawn grid.
func _boundaries(b: _Batch, cell: Vector2i, corners: PackedVector2Array) -> void:
	b.line(corners[3], corners[0], 1.6, BOUNDARY_DARK)
	b.line(corners[0], corners[1], 1.6, BOUNDARY_DARK)
	b.line(corners[1], corners[2], 1.2, BOUNDARY_LIGHT)
	b.line(corners[2], corners[3], 1.2, BOUNDARY_LIGHT)
	var rim := Color(0.78, 0.91, 0.42, 0.9)
	if not _world.is_owned(cell + Vector2i(-1, 0)):
		b.line(corners[3], corners[0], 2.2, rim)
	if not _world.is_owned(cell + Vector2i(0, -1)):
		b.line(corners[0], corners[1], 2.2, rim)


## Flowers and tufts: derived from the cell, deterministic, purely visual.
func _decals(b: _Batch, cell: Vector2i) -> void:
	for decal: Array in decals_for(cell):
		var p := _proj.to_screen(decal[1])
		match int(decal[0]):
			0:
				for k in 5:
					var ang := TAU * k / 5.0
					b.disc(p + Vector2(cos(ang), sin(ang) * 0.7) * 2.6, 1.9, Color("#ffffff"), 5)
				b.disc(p, 1.4, Color("#ffd34d"), 5)
			1:
				b.disc(p, 2.2, Color("#ffd34d"), 6)
				b.disc(p + Vector2(4, 1), 1.8, Color("#fff4b0"), 5)
			_:
				for k in 3:
					b.line(p + Vector2(k * 2 - 2, 0), p + Vector2(k * 3 - 3, -5), 1.3, Color("#5f9e2c"))


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


## Accumulates triangles for one mesh surface.
class _Batch:
	var verts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()

	func quad(p: PackedVector2Array, uv: PackedVector2Array, c: Array) -> void:
		for i: int in [0, 1, 2, 0, 2, 3]:
			verts.append(p[i])
			uvs.append(uv[i])
			colors.append(c[i])

	func line(a: Vector2, b: Vector2, width: float, color: Color) -> void:
		var n := (b - a).orthogonal().normalized() * width * 0.5
		quad(PackedVector2Array([a + n, b + n, b - n, a - n]), PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]), [color, color, color, color])

	func disc(centre: Vector2, radius: float, color: Color, sides: int) -> void:
		for i in sides:
			var a0 := TAU * i / sides
			var a1 := TAU * (i + 1) / sides
			verts.append_array(PackedVector2Array([centre, centre + Vector2(cos(a0), sin(a0)) * radius, centre + Vector2(cos(a1), sin(a1)) * radius]))
			uvs.append_array(PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]))
			colors.append_array(PackedColorArray([color, color, color]))

	func commit(mesh: ArrayMesh) -> void:
		mesh.clear_surfaces()
		if verts.is_empty():
			return
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_COLOR] = colors
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
