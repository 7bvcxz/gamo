class_name BuildingView
extends Node2D

## One building on the island: its sprite standing on its footprint, a soft
## highlight on the ground when selected, and a ring above it while it works
## (filling) or cools down (emptying). Reads its building record every frame;
## owns no game state.

const RING_RADIUS := 13.0
const RING_WIDTH := 4.0

var id := 0
var buildings: BuildingSystem
var projection: IsoProjection
var selected := false:
	set(value):
		selected = value
		queue_redraw()
var sprite: Sprite2D
var ring: Node2D
var _top := Vector2(0, -60)
var _bounce := 0.0
var _shake := 0.0


func setup(p_id: int, p_buildings: BuildingSystem, p_projection: IsoProjection, lib: SpriteLibrary) -> void:
	id = p_id
	buildings = p_buildings
	projection = p_projection
	name = "Building_%d" % id
	var b := buildings.get_building(id)
	var sprite_name: String = buildings.type_def(b).get("sprite", "")
	sprite = lib.make_sprite(sprite_name) if lib.has(sprite_name) else Sprite2D.new()
	add_child(sprite)
	if lib.has(sprite_name):
		_top = (lib.pivot(sprite_name, "top") - lib.pivot(sprite_name, "origin")) * lib.world_scale(sprite_name)
	ring = Node2D.new()
	ring.z_index = 5
	ring.draw.connect(_draw_ring)
	add_child(ring)


## World-space rectangle a tap can land on.
func hit_rect() -> Rect2:
	if sprite.texture == null:
		return Rect2(position - Vector2(30, 30), Vector2(60, 60))
	var r := sprite.region_rect
	var s := sprite.scale
	return Rect2(position + sprite.offset * s, r.size * s)


func pulse() -> void:
	_bounce = 1.0


func refuse() -> void:
	_shake = 1.0


func _process(delta: float) -> void:
	_bounce = maxf(0.0, _bounce - delta * 4.0)
	_shake = maxf(0.0, _shake - delta * 3.5)
	var k := sin(_bounce * PI) * 0.08
	var base := sprite.scale.x if sprite.scale.x > 0 else 1.0
	sprite.position = Vector2(sin(_shake * 40.0) * 3.0 * _shake, -k * 20.0)
	ring.queue_redraw()


func _draw() -> void:
	if not selected:
		return
	var b := buildings.get_building(id)
	for cell: Vector2i in buildings.cells_of(b):
		var c := projection.cell_corners(cell)
		var local := PackedVector2Array()
		for p: Vector2 in c:
			local.append(p - position)
		var loop := local.duplicate()
		loop.append(local[0])
		draw_colored_polygon(local, Color(1, 0.95, 0.6, 0.18))
		draw_polyline(loop, Color(1, 0.93, 0.45, 0.95), 3.0, true)


func _draw_ring() -> void:
	var b := buildings.get_building(id)
	if b.is_empty():
		return
	var centre := _top + Vector2(0, -18)
	match String(b["state"]):
		BuildingSystem.WORKING:
			var p := buildings.progress(b)
			ring.draw_circle(centre, RING_RADIUS + 3, Color(0.09, 0.25, 0.47, 0.55))
			ring.draw_arc(centre, RING_RADIUS, 0, TAU, 32, Color(1, 1, 1, 0.25), RING_WIDTH, true)
			ring.draw_arc(centre, RING_RADIUS, -PI / 2, -PI / 2 + TAU * p, 32, Color("#9be15d"), RING_WIDTH, true)
		BuildingSystem.COOLDOWN:
			var total := maxf(float(int(b["ready_at"]) - int(b["task_end"])), 1.0)
			var left := float(buildings.remaining_ms(b)) / total
			ring.draw_circle(centre, RING_RADIUS + 3, Color(0.09, 0.25, 0.47, 0.45))
			ring.draw_arc(centre, RING_RADIUS, -PI / 2, -PI / 2 + TAU * left, 32, Color(0.75, 0.85, 1.0, 0.8), RING_WIDTH, true)
