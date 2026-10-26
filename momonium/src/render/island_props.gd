class_name IslandProps
extends Node

## Painted props dressing the island (Step 46): bushes, flowers, mossy rocks
## and grass along the rim, a young tree now and then on a back edge, a few
## flowers inside. Like the decals they are derived from the cell -- the same
## island always looks the same -- never enter the simulation and never stand
## on a cell that holds something, so they can never block a building or a
## tap. They are plain sprites in the entity layer, so Momo walks in front of
## and behind them in depth order, and they run no per-frame code.

## [sprite, weight] for a rim cell; trees only on the far edges, where they
## stand behind the island instead of in front of what is on it. Step 52 adds
## the concept's pines, and its crates, barrels, log piles and stumps -- these
## too only on far edges: solid wood in front of a tile reads as a thing
## standing on it.
const RIM := [["prop_bush", 5], ["prop_bush_flowers", 4], ["prop_flowers", 4], ["prop_rocks", 2], ["prop_grass", 3]]
const TREES := [["prop_tree", 3], ["prop_pine", 3], ["prop_pine_small", 2]]
const FAR_GOODS := [["prop_crate", 2], ["prop_barrel", 2], ["prop_logs", 2], ["prop_stump", 1]]
const GOODS_CHANCE := 0.3
const INNER := [["prop_flowers", 3], ["prop_grass", 2]]
const RIM_CHANCE := 0.9
const SECOND_CHANCE := 0.5
const INNER_CHANCE := 0.3
const TREE_CHANCE := 0.35
## How far from the edge a rim prop stands (tile units), so it reads as the
## island's border, not the middle of a buildable tile.
const EDGE_INSET := Vector2(0.1, 0.24)

var layer: EntityLayer
var lib: SpriteLibrary
var _world: WorldSystem
var _sprites: Array[Sprite2D] = []
var _dirty := false


func setup(sim: Simulation, p_layer: EntityLayer, p_lib: SpriteLibrary) -> void:
	_world = sim.system(&"world")
	layer = p_layer
	lib = p_lib
	sim.bus.emitted.connect(_on_event)
	rebuild()


func _on_event(type: StringName, _payload: Dictionary) -> void:
	if type in [&"land_added", &"game_loaded", &"occupancy_changed"] and not _dirty:
		_dirty = true
		rebuild.call_deferred()


func rebuild() -> void:
	_dirty = false
	for s: Sprite2D in _sprites:
		s.queue_free()
	_sprites.clear()
	if not lib.has("prop_bush"):
		return
	for cell: Vector2i in _world.owned_cells():
		if _world.is_occupied(cell):
			continue
		for p: Array in props_for(cell, _open_sides(cell)):
			var s := lib.make_sprite(p[0])
			s.name = "Prop"
			s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			s.flip_h = bool(p[2])
			layer.add_entity(s, p[1])
			_sprites.append(s)


func count() -> int:
	return _sprites.size()


func sprites() -> Array[Sprite2D]:
	return _sprites


## Which sides of `cell` face the sea: up (-y), left (-x), right (+x), down (+y).
func _open_sides(cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d: Vector2i in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
		if not _world.is_owned(cell + d):
			out.append(d)
	return out


## The props a free cell shows: [sprite, logical position, mirrored]. Pure
## function of the cell and its open sides.
static func props_for(cell: Vector2i, open: Array[Vector2i]) -> Array:
	var rng := IslandRenderer._rng(cell, 7)
	var out: Array = []
	if open.is_empty():
		if rng.randf() < INNER_CHANCE:
			out.append([_pick(INNER, rng), Vector2(cell) + Vector2(rng.randf_range(0.25, 0.75), rng.randf_range(0.25, 0.75)), rng.randf() < 0.5])
		return out
	var far: Array[Vector2i] = []
	for d: Vector2i in open:
		if d.x < 0 or d.y < 0:
			far.append(d)
	if not far.is_empty() and rng.randf() < TREE_CHANCE:
		out.append([_pick(TREES, rng), _edge_point(cell, far[rng.randi() % far.size()], rng), rng.randf() < 0.5])
	elif not far.is_empty() and rng.randf() < GOODS_CHANCE:
		out.append([_pick(FAR_GOODS, rng), _edge_point(cell, far[rng.randi() % far.size()], rng), rng.randf() < 0.5])
	var n := 0
	if rng.randf() < RIM_CHANCE:
		n = 2 if rng.randf() < SECOND_CHANCE else 1
	for i in n:
		out.append([_pick(RIM, rng), _edge_point(cell, open[rng.randi() % open.size()], rng), rng.randf() < 0.5])
	return out


## A point just inside the edge of `cell` that faces `side`.
static func _edge_point(cell: Vector2i, side: Vector2i, rng: RandomNumberGenerator) -> Vector2:
	var along := rng.randf_range(0.18, 0.82)
	var inset := rng.randf_range(EDGE_INSET.x, EDGE_INSET.y)
	var local := Vector2(along, along)
	if side.x < 0:
		local.x = inset
	elif side.x > 0:
		local.x = 1.0 - inset
	if side.y < 0:
		local.y = inset
	elif side.y > 0:
		local.y = 1.0 - inset
	return Vector2(cell) + local


static func _pick(table: Array, rng: RandomNumberGenerator) -> String:
	var total := 0
	for row: Array in table:
		total += int(row[1])
	var r := rng.randi_range(1, total)
	for row: Array in table:
		r -= int(row[1])
		if r <= 0:
			return row[0]
	return table[0][0]
