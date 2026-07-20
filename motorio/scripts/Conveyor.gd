extends RigidBody2D
class_name ConveyorBlock

const TILE_SIZE := 32.0
const BELT_SPEED := 72.0
const PUSH_FORCE := 1300.0

@export var direction := Vector2.RIGHT
var animation_offset := 0.0

func _physics_process(delta: float) -> void:
	for body in $Detector.get_overlapping_bodies():
		if body == self:
			continue
		if body is RigidBody2D:
			body.apply_central_force(direction * PUSH_FORCE)
		elif body is CharacterBody2D:
			body.move_and_collide(direction * BELT_SPEED * delta)

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if state.linear_velocity.length_squared() < 4.0:
		state.linear_velocity = Vector2.ZERO

func _process(delta: float) -> void:
	animation_offset = fmod(animation_offset + delta * BELT_SPEED, 12.0)
	queue_redraw()

func _draw() -> void:
	var tile_rect := Rect2(-TILE_SIZE / 2.0, -TILE_SIZE / 2.0, TILE_SIZE, TILE_SIZE)
	draw_rect(tile_rect, Color("303941"))
	draw_rect(tile_rect.grow(-2.0), Color("59636a"), false, 2.0)

	# Three moving chevrons indicate the belt direction.
	draw_set_transform(Vector2.ZERO, direction.angle())
	for index in range(-2, 3):
		var x := -12.0 + index * 12.0 + animation_offset
		if x > 16.0:
			x -= 48.0
		var arrow := PackedVector2Array([
			Vector2(x - 4, -6), Vector2(x + 3, 0), Vector2(x - 4, 6)
		])
		draw_polyline(arrow, Color("e0a83d"), 3.0)
	draw_set_transform(Vector2.ZERO)
