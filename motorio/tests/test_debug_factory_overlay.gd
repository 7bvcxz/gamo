extends SceneTree

## The factory debug overlay says what the simulation says (Factory Interaction
## Pass 01): for a post on each registered ore, the node it is aimed at, that
## node's type and the item it will put out agree with each other and with the
## sheet the ground draws there; the overlay's footprint and ports are the
## machine's; and the ` key turns it on and off without an error in the draw.

const Factory := preload("res://tests/helpers/factory.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_data()
	await _test_key()
	if failures == 0:
		print("PASS test_debug_factory_overlay")
	else:
		print("FAIL test_debug_factory_overlay (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)


func _test_data() -> void:
	var sim: Sim = Factory.world()
	var index := 0
	for id: int in range(Defs.ITEM_NAMES.size()):
		if Defs.ore_output(id) < 0 or Defs.item_retired(id):
			continue
		var node: Vector2i = Factory.at(sim, Vector2i(2 + index * 5, 2))
		index += 1
		sim.put_ore(node, id)
		var post: Sim.Machine = Factory.put(sim, Defs.M_MINER, node, Vector2i.DOWN)
		_assert(post != null, "%s 노드에 채굴장" % Defs.item_name(id))
		if post == null:
			continue
		var info: Dictionary = sim.machine_debug(post)
		_assert(info["ore_node"] == node and int(info["ore_id"]) == Sim.ore_node_id(node), "겨눈 노드")
		_assert(int(info["ore_type"]) == id, "노드 종류 = %s" % Defs.item_name(id))
		_assert(int(info["expected_output"]) == Defs.ore_output(id), "나올 것 = 표의 산출")
		var atlas: Texture2D = GroundLayer.ore_atlas_at(sim, node)
		_assert(atlas != null and atlas.resource_path.ends_with(Defs.item_atlas(id)), "그려지는 시트 = 종류의 시트")
		_assert(info["footprint"] == sim.machine_rect(post) and info["ports"] == sim.machine_ports(post),
			"발자국과 포트는 기계의 것")
		_assert(Rect2(Grid.rect_px(info["footprint"])).has_point(info["work_point"]), "고양이 자리는 발자국 안")
	sim.free()

func _test_key() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_run(5150)
	main.finish_tutorial()
	main.state = main.State.PLAY
	_assert(not main.machine_layer.debug_overlay, "처음에는 꺼져 있다")
	var event := InputEventKey.new()
	event.keycode = KEY_QUOTELEFT
	event.physical_keycode = KEY_QUOTELEFT
	event.pressed = true
	main._unhandled_input(event)
	_assert(main.machine_layer.debug_overlay, "` 로 켠다")
	main.machine_layer.queue_redraw()
	await process_frame
	await process_frame
	main._unhandled_input(event)
	_assert(not main.machine_layer.debug_overlay, "다시 누르면 끈다")
	main.clear_save()
	main.free()
