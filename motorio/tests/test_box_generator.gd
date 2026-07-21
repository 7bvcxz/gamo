extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var stage := Node2D.new()
	root.add_child(stage)
	var generator := load("res://scenes/BoxGenerator.tscn").instantiate() as BoxGenerator
	generator.position = Vector2(200, 200)
	generator.direction = Vector2.RIGHT
	stage.add_child(generator)
	await physics_frame
	_assert(generator.freeze and generator.is_in_group("solid"), "generator is an immovable Solid")
	_assert(generator.is_in_group("pickup_block") and not generator.is_in_group("fixed"), "generator can be picked up again")
	var body_shape := generator.get_node("CollisionShape2D").shape as RectangleShape2D
	_assert(body_shape.size == Vector2(62, 30), "generator occupies a 2x1 footprint")
	_assert(generator.input_position() == Vector2(152, 200), "mineral input is one cell behind the machine")
	_assert(generator.output_position() == Vector2(248, 200), "box output is one cell ahead of the machine")

	var blocker := load("res://scenes/PushTile.tscn").instantiate() as RigidBody2D
	blocker.position = generator.output_position()
	stage.add_child(blocker)
	for index in range(3):
		var resource := load("res://scenes/MinedResource.tscn").instantiate() as RigidBody2D
		resource.position = generator.input_position() + Vector2(index - 1, 0)
		stage.add_child(resource)
	await physics_frame
	await physics_frame
	_assert(generator.stored_minerals == 0 and generator.pending_boxes == 1, "three rear minerals queue one box")
	_assert(_stage_boxes(stage).size() == 1, "blocked output does not create an overlapping box")
	blocker.queue_free()
	await physics_frame
	await physics_frame
	var boxes := _stage_boxes(stage)
	_assert(boxes.size() == 1, "queued box appears when the front becomes free")
	if boxes.size() == 1:
		_assert((boxes[0] as RigidBody2D).position.distance_to(generator.output_position()) < 0.1, "box is produced at the front output")
	_assert(generator.pending_boxes == 0, "successful output clears the pending box")

	if failures == 0:
		print("BOX_GENERATOR_TEST: PASS")
	quit(failures)

func _stage_boxes(stage: Node2D) -> Array:
	return get_nodes_in_group("box_block").filter(func(node): return node.get_parent() == stage and not node.is_queued_for_deletion())

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("BOX_GENERATOR_TEST: FAIL - " + message)
		failures += 1
