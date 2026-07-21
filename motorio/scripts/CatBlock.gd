extends RigidBody2D
class_name CatBlock

const TILE_SIZE := 32.0
const RESOURCE_SCENE := preload("res://scenes/MinedResource.tscn")

@export var direction := Vector2.RIGHT
@export var active_on_ready := true

func _ready() -> void:
	add_to_group("pickup_block")
	queue_redraw()
	if active_on_ready:
		call_deferred("_mine_front_mineral")

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if state.linear_velocity.length_squared() < 4.0:
		state.linear_velocity = Vector2.ZERO

func _mine_front_mineral() -> void:
	var target := global_position + direction * TILE_SIZE
	var mineral: MineralBlock = null
	for node in get_tree().get_nodes_in_group("mineral_block"):
		var candidate := node as MineralBlock
		if candidate and candidate.global_position.distance_to(target) < 18.0:
			mineral = candidate
			break
	if mineral == null:
		return
	mineral.queue_free()
	var resource := RESOURCE_SCENE.instantiate() as StaticBody2D
	resource.global_position = global_position - direction * 24.0
	get_parent().add_child(resource)

func _draw() -> void:
	var rect := Rect2(Vector2.ONE * -16.0, Vector2.ONE * 32.0)
	draw_rect(rect, Color("d99a56"))
	draw_rect(rect.grow(-2.0), Color("f0c47a"), false, 2.0)
	draw_set_transform(Vector2.ZERO, direction.angle())
	draw_polygon(PackedVector2Array([Vector2(12, 0), Vector2(4, -6), Vector2(4, 6)]), PackedColorArray([Color("70452f")]))
	draw_circle(Vector2(-3, 0), 8.0, Color("fff0cf"))
	draw_polygon(PackedVector2Array([Vector2(-8, -6), Vector2(-4, -13), Vector2(0, -6)]), PackedColorArray([Color("fff0cf")]))
	draw_polygon(PackedVector2Array([Vector2(-8, 6), Vector2(-4, 13), Vector2(0, 6)]), PackedColorArray([Color("fff0cf")]))
	draw_circle(Vector2(-1, -3), 1.5, Color("382c2a"))
	draw_circle(Vector2(-1, 3), 1.5, Color("382c2a"))
	draw_set_transform(Vector2.ZERO)
