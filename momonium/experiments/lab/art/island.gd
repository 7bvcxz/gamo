class_name LabIsland
extends Node2D

## A small island in the game's look, drawn from a set of cells: grass tops
## (the game's grass texture, two tiles to a repeat), dirt-and-stone cliffs on
## every exposed near edge (the near-right faces darker: light from the upper
## left), a lighter grass lip over each cliff and a soft bevel between cells.
## A simplified momonium src/render/island_renderer.gd -- no banks, lamps or
## decals. New cells can rise out of the sea (`add_cells(..., true)`).
##
## Local (0, 0) is logical (0, 0); place the node where that should be.

const GRASS := preload("res://shared/textures/grass.png")
const CLIFF := preload("res://shared/textures/cliff.png")
const GRASS_TILES_PER_TEXTURE := 2.0
const CLIFF_TILES_PER_TEXTURE := 2.0
const LEFT_FACE_LIGHT := 1.0
const RIGHT_FACE_LIGHT := 0.78
const LIP_DEPTH := 7.0
const LIP_TINT := Color(1.12, 1.14, 0.86)
const BOUNDARY_DARK := Color(0.25, 0.45, 0.12, 0.28)
const BOUNDARY_LIGHT := Color(1, 1, 0.8, 0.22)
const RIM := Color(0.78, 0.91, 0.42, 0.9)
## How long a new cell takes to rise out of the sea.
const RISE_SECONDS := 0.6

var iso := LabIso.new()
## cell -> how far it has risen (1 = in place).
var cells: Dictionary = {}
var reduced_motion := false
## Cells drawn as a sandy path on the grass.
var paths: Dictionary = {}
## Cells that are not land yet, drawn as a pale outline (an upgrade's teaser).
var ghost_cells: Dictionary = {}
var ghost_alpha := 0.38:
	set(v):
		if not is_equal_approx(v, ghost_alpha):
			ghost_alpha = v
			if not ghost_cells.is_empty():
				queue_redraw()
const PATH := Color("#e2c992")
const PATH_EDGE := Color("#c7a96b")

signal changed


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func set_cells(list: Array) -> void:
	cells.clear()
	for c: Vector2i in list:
		cells[c] = 1.0
	queue_redraw()
	changed.emit()


## Adds cells; with `animate` they rise out of the sea over RISE_SECONDS
## (at once with reduced motion).
func add_cells(list: Array, animate: bool = true) -> void:
	var rising: Array[Vector2i] = []
	for c: Vector2i in list:
		if cells.has(c):
			continue
		cells[c] = 0.0 if animate and not reduced_motion else 1.0
		if animate and not reduced_motion:
			rising.append(c)
	if not rising.is_empty():
		var tw := create_tween()
		tw.tween_method(func(t: float) -> void:
			for c: Vector2i in rising:
				if cells.has(c):
					cells[c] = t
			queue_redraw(), 0.0, 1.0, RISE_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	queue_redraw()
	changed.emit()


func has_cell(c: Vector2i) -> bool:
	return cells.has(c)


func cell_list() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Vector2i in cells:
		out.append(c)
	return out


## Bounds of the land in logical cells.
func bounds() -> Rect2i:
	if cells.is_empty():
		return Rect2i()
	var r := Rect2i(cells.keys()[0], Vector2i.ONE)
	for c: Vector2i in cells:
		r = r.merge(Rect2i(c, Vector2i.ONE))
	return r


## Where the island's drawing reaches, in local pixels (tops and cliffs).
func screen_bounds() -> Rect2:
	if cells.is_empty():
		return Rect2()
	var r := Rect2(iso.cell_center(cells.keys()[0]), Vector2.ZERO)
	for c: Vector2i in cells:
		for p: Vector2 in iso.cell_corners(c):
			r = r.expand(p)
			r = r.expand(p + Vector2(0, iso.drop()))
	return r


func _sorted() -> Array[Vector2i]:
	var list := cell_list()
	list.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x + a.y < b.x + b.y if a.x + a.y != b.x + b.y else a.x < b.x)
	return list


func _draw() -> void:
	var list := _sorted()
	var drop := Vector2(0, iso.drop())
	var su := 1.0 / CLIFF_TILES_PER_TEXTURE
	# Cliffs, far to near.
	for c: Vector2i in list:
		var k: float = cells[c]
		var off := _offset(k)
		var a := clampf(k * 1.6, 0.0, 1.0)
		var faces: Array = []
		if not _solid(c + Vector2i(1, 0)):
			faces.append([Vector2(c.x + 1, c.y), Vector2(c.x + 1, c.y + 1), RIGHT_FACE_LIGHT, float(c.y)])
		if not _solid(c + Vector2i(0, 1)):
			faces.append([Vector2(c.x, c.y + 1), Vector2(c.x + 1, c.y + 1), LEFT_FACE_LIGHT, float(c.x)])
		for f: Array in faces:
			var ta := iso.to_screen(f[0]) + off
			var tc := iso.to_screen(f[1]) + off
			var light: float = f[2]
			var u0: float = f[3]
			var lit := Color(light, light, light, a)
			var deep := Color(light * 0.8, light * 0.83, light * 0.9, a)
			draw_polygon(PackedVector2Array([ta, tc, tc + drop, ta + drop]),
				PackedColorArray([lit, lit, deep, deep]),
				PackedVector2Array([Vector2(u0 * su, 0), Vector2((u0 + 1.0) * su, 0), Vector2((u0 + 1.0) * su, 1), Vector2(u0 * su, 1)]),
				CLIFF)
	# Tops, then lips and bevels.
	var gs := 1.0 / GRASS_TILES_PER_TEXTURE
	for c: Vector2i in list:
		var k: float = cells[c]
		var off := _offset(k)
		var a := clampf(k * 1.6, 0.0, 1.0)
		var corners := iso.cell_corners(c)
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		var logical := [Vector2(c), Vector2(c) + Vector2(1, 0), Vector2(c) + Vector2(1, 1), Vector2(c) + Vector2(0, 1)]
		for i in 4:
			pts.append(corners[i] + off)
			uvs.append((logical[i] as Vector2) * gs)
		var col := Color(1, 1, 1, a)
		draw_polygon(pts, PackedColorArray([col, col, col, col]), uvs, GRASS)
		if a < 0.99:
			continue
		draw_line(pts[3], pts[0], BOUNDARY_DARK, 1.6)
		draw_line(pts[0], pts[1], BOUNDARY_DARK, 1.6)
		draw_line(pts[1], pts[2], BOUNDARY_LIGHT, 1.2)
		draw_line(pts[2], pts[3], BOUNDARY_LIGHT, 1.2)
		if not _solid(c + Vector2i(-1, 0)):
			draw_line(pts[3], pts[0], RIM, 2.2)
		if not _solid(c + Vector2i(0, -1)):
			draw_line(pts[0], pts[1], RIM, 2.2)
		if not _solid(c + Vector2i(1, 0)):
			_lip(pts[1], pts[2], logical[1], logical[2])
		if not _solid(c + Vector2i(0, 1)):
			_lip(pts[3], pts[2], logical[3], logical[2])
	_overlays()


## The sandy path on a cell and the ghost of land to come.
func _overlays() -> void:
	for c: Vector2i in paths:
		if not _solid(c):
			continue
		var pts := iso.cell_corners(c)
		var mid := iso.cell_center(c)
		var inset := PackedVector2Array()
		for p: Vector2 in pts:
			inset.append(mid + (p - mid) * 0.62)
		draw_colored_polygon(inset, PATH)
		inset.append(inset[0])
		draw_polyline(inset, PATH_EDGE, 2.0, true)
	for c: Vector2i in ghost_cells:
		if cells.has(c):
			continue
		var pts := iso.cell_corners(c)
		draw_colored_polygon(pts, Color(1, 1, 1, ghost_alpha * 0.45))
		pts.append(pts[0])
		draw_polyline(pts, Color(1, 1, 1, minf(1.0, ghost_alpha * 1.6)), 3.0, true)


## A lighter grass lip spilling over an exposed near edge.
func _lip(p0: Vector2, p1: Vector2, l0: Vector2, l1: Vector2) -> void:
	var s := 1.0 / GRASS_TILES_PER_TEXTURE
	var d := Vector2(0, LIP_DEPTH)
	draw_polygon(PackedVector2Array([p0, p1, p1 + d, p0 + d]),
		PackedColorArray([LIP_TINT, LIP_TINT, LIP_TINT, LIP_TINT]),
		PackedVector2Array([l0 * s, l1 * s, l1 * s + Vector2(0, 0.02), l0 * s + Vector2(0, 0.02)]),
		GRASS)


## A cell that has fully risen hides the cliff of the cell behind it.
func _solid(c: Vector2i) -> bool:
	return cells.has(c) and float(cells[c]) >= 0.99


## A rising cell comes up from below the waterline.
func _offset(k: float) -> Vector2:
	return Vector2(0, (1.0 - clampf(k, 0.0, 1.2)) * iso.drop() * 1.6)
