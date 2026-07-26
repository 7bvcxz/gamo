extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await physics_frame

	var smelter := load("res://scenes/Smelter.tscn").instantiate() as Smelter
	smelter.direction = Vector2.RIGHT
	smelter.position = main.base.position + Vector2.RIGHT * main.TILE_SIZE * 40.0
	main.add_child(smelter)
	await physics_frame

	_assert(smelter.is_in_group("solid") and smelter.is_in_group("pickup_block"), "smelter is a retrievable Solid like other machines")
	_assert(smelter.freeze, "placed smelter does not get pushed around")
	var body_shape := (smelter.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	_assert(body_shape.size == Vector2(62, 30), "smelter occupies a two-by-one tile footprint")
	_assert(smelter.input_position().distance_to(smelter.output_position()) > main.TILE_SIZE * 2.0, "smelter takes input behind and emits ahead")

	# Two minerals plus one coal make exactly one plate.
	_feed(smelter, "mined_resource")
	_assert(not smelter.is_smelting(), "one mineral alone does not start a smelt")
	_feed(smelter, "mined_resource")
	_feed(smelter, "resource_coal")
	_assert(smelter.is_smelting(), "two minerals and one coal start a smelt")
	_assert(smelter.stored_minerals == 0 and smelter.stored_coal == 0, "starting a batch consumes its inputs")

	smelter.call("_physics_process", Smelter.SMELT_SECONDS + 0.1)
	await physics_frame
	var plates: Array[Node] = get_nodes_in_group("resource_plate")
	_assert(plates.size() == 1, "a finished smelt emits exactly one plate")
	var plate := plates[0] as WorldResource
	_assert(plate.resource_type == "plate" and plate.is_in_group("world_resource"), "the plate is a transportable world resource")
	_assert(plate.position.distance_to(smelter.output_position()) < 1.0, "the plate appears at the smelter output")

	# The base counts plates like any other refined resource.
	main.call("_on_base_resource_received", plate, "plate")
	_assert(main.resource_counts["plate"] == 1, "delivered plates accumulate at the base")
	_assert(main.economy_ui.RESOURCE_ORDER.has("plate"), "plates appear in the resource HUD")

	# The chain has a purpose: the last base upgrade needs plates.
	main.base_level = 6
	var final_cost: Dictionary = main.base_upgrade_cost()
	_assert(final_cost.has("plate"), "the final base upgrade consumes smelted plates")

	# Recipe wiring.
	var smelter_index: int = main.fabricator_recipe_count() - 1
	_assert(main.recipe_label(smelter_index) == "제련소", "the smelter is craftable at the base")
	_assert(main.recipe_unlock_level(smelter_index) == 5, "the smelter unlocks once coal is reachable")
	var crafted := main.call("_create_recipe_block", smelter_index) as RigidBody2D
	_assert(crafted is Smelter, "crafting the smelter recipe produces a smelter, not a facility")
	crafted.free()

	# Save and restore keeps a placed smelter and its buffered inputs.
	smelter.stored_minerals = 1
	smelter.stored_coal = 1
	var entry: Dictionary = main.call("_serialize_world_object", smelter)
	_assert(entry.get("type", "") == "smelter" and entry.get("coal", 0) == 1, "smelter state serializes its coal buffer")
	var restored := main.call("_create_saved_world_object", entry) as RigidBody2D
	_assert(restored is Smelter and (restored as Smelter).stored_coal == 1, "restoring a save rebuilds the smelter buffers")
	restored.free()

	if failures == 0:
		print("SMELTER_TEST: PASS")
	quit(failures)

func _feed(smelter: Smelter, group_name: String) -> void:
	var resource := RigidBody2D.new()
	resource.add_to_group(group_name)
	root.add_child(resource)
	smelter.call("_on_resource_entered", resource)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("SMELTER_TEST: FAIL - " + message)
		failures += 1
