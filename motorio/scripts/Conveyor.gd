extends RigidBody2D
class_name ConveyorBlock

const TILE_SIZE := 32.0
const BELT_SPEED := 72.0
const PUSH_FORCE := 1300.0
# The visual outline occupies x/y 13..15, so only the area inside 13 moves items.
const EFFECT_HALF_EXTENT := 13.0
const ARROW_CYCLE := 20.0

@export var direction := Vector2.RIGHT
var animation_offset := 0.0

func _physics_process(delta: float) -> void:
	for body in $Detector.get_overlapping_bodies():
		if body == self:
			continue
		if not overlaps_effect_body(body):
			continue
		if body is RigidBody2D:
			body.apply_central_force(direction * PUSH_FORCE)
		elif body is CharacterBody2D:
			body.move_and_collide(direction * BELT_SPEED * delta)

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if state.linear_velocity.length_squared() < 4.0:
		state.linear_velocity = Vector2.ZERO

func _process(delta: float) -> void:
	animation_offset = fmod(animation_offset + delta * BELT_SPEED, ARROW_CYCLE)
	queue_redraw()

func contains_effect_point(global_point: Vector2) -> bool:
	var local_point := to_local(global_point)
	return abs(local_point.x) < EFFECT_HALF_EXTENT and abs(local_point.y) < EFFECT_HALF_EXTENT

func overlaps_effect_rect(global_center: Vector2, half_extent: Vector2) -> bool:
	var local_center := to_local(global_center)
	return (
		abs(local_center.x) < EFFECT_HALF_EXTENT + half_extent.x
		and abs(local_center.y) < EFFECT_HALF_EXTENT + half_extent.y
	)

func overlaps_effect_body(body: CollisionObject2D) -> bool:
	var half_extent := Vector2.ZERO
	var collision := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision and collision.shape is RectangleShape2D:
		half_extent = (collision.shape as RectangleShape2D).size / 2.0
	return overlaps_effect_rect(body.global_position, half_extent)

func get_arrow_points(index: int) -> PackedVector2Array:
	var x := fmod(index * 10.0 + animation_offset + 8.0, ARROW_CYCLE) - 8.0
	return PackedVector2Array([
		Vector2(x - 3.0, -5.0),
		Vector2(x + 2.0, 0.0),
		Vector2(x - 3.0, 5.0),
	])

func _draw() -> void:
	var tile_rect := Rect2(-TILE_SIZE / 2.0, -TILE_SIZE / 2.0, TILE_SIZE, TILE_SIZE)
	draw_rect(tile_rect, Color("303941"))
	draw_rect(tile_rect.grow(-2.0), Color("59636a"), false, 2.0)

	# Three moving chevrons indicate the belt direction.
	draw_set_transform(Vector2.ZERO, direction.angle())
	for index in range(2):
		draw_polyline(get_arrow_points(index), Color("e0a83d"), 2.5)
	draw_set_transform(Vector2.ZERO)
