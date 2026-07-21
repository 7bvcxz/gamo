extends RigidBody2D
class_name CatBlock

const TILE_SIZE := 32.0
const MINE_INTERVAL := 3.0
const SPARK_DURATION := 0.45
const RESOURCE_SCENE := preload("res://scenes/MinedResource.tscn")

@export var direction := Vector2.RIGHT
@export var active_on_ready := true
var mine_elapsed := 0.0
var spark_remaining := 0.0

func _ready() -> void:
	add_to_group("pickup_block")
	add_to_group("solid")
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not active_on_ready:
		return
	mine_elapsed += delta
	if spark_remaining > 0.0:
		spark_remaining = maxf(0.0, spark_remaining - delta)
		queue_redraw()
	while mine_elapsed >= MINE_INTERVAL:
		mine_elapsed -= MINE_INTERVAL
		spark_remaining = SPARK_DURATION
		_mine_front_mineral()
		queue_redraw()

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
	var resource := RESOURCE_SCENE.instantiate() as RigidBody2D
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
	if spark_remaining > 0.0:
		var spark_center := direction * TILE_SIZE
		var pulse := 1.0 + spark_remaining / SPARK_DURATION
		draw_circle(spark_center, 3.0 * pulse, Color(0.75, 1.0, 0.9, 0.85), false, 2.0)
		for angle_index in range(4):
			var ray := Vector2.from_angle(angle_index * PI / 2.0) * 8.0 * pulse
			draw_line(spark_center - ray * 0.35, spark_center + ray, Color("d5fff0"), 2.0)
