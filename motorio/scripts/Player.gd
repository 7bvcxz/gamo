extends CharacterBody2D

const SPEED := 220.0
const RADIUS := 11.0
const PUSH_FORCE := 2200.0

var world_bounds := Rect2()
var facing := Vector2.DOWN
var walk_phase := 0.0

func _ready() -> void:
	queue_redraw()

func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if not direction.is_zero_approx():
		facing = direction.normalized()
		walk_phase += delta * 12.0
	else:
		walk_phase = 0.0
	velocity = direction * SPEED
	move_and_slide()
	_push_rigid_bodies()
	queue_redraw()

	# Keep the complete character inside the 100 × 100 tile world.
	position.x = clamp(position.x, world_bounds.position.x + RADIUS, world_bounds.end.x - RADIUS)
	position.y = clamp(position.y, world_bounds.position.y + RADIUS, world_bounds.end.y - RADIUS)

func _push_rigid_bodies() -> void:
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		var body := collision.get_collider() as RigidBody2D
		if body:
			body.apply_central_force(-collision.get_normal() * PUSH_FORCE)

func _draw() -> void:
	var walking := not velocity.is_zero_approx()
	var step: float = sin(walk_phase) * 2.5 if walking else 0.0
	var bob: float = abs(sin(walk_phase)) * 1.2 if walking else 0.0
	var body_origin := Vector2(0, -2.0 - bob)

	# Isometric-style ground shadow and alternating feet, all inside one tile.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2(0, 15), 10.0, Color(0.02, 0.03, 0.025, 0.45))
	draw_set_transform(Vector2.ZERO)
	draw_line(Vector2(-4 + step, 5), Vector2(-5 + step, 11), Color("283746"), 4.0)
	draw_line(Vector2(4 - step, 5), Vector2(5 - step, 11), Color("283746"), 4.0)

	# Body, head and a bright visor indicating the current facing direction.
	draw_circle(body_origin + Vector2(0, 2), 9.0, Color("d59a32"))
	draw_circle(body_origin + Vector2(0, -6), 7.0, Color("f2b84b"))
	var visor_center := body_origin + Vector2(0, -6) + facing * 3.0
	draw_circle(visor_center, 3.0, Color("8ed3d8"))
	draw_arc(body_origin + Vector2(0, -6), 7.0, 0.0, TAU, 20, Color("fff0ad"), 1.5)
