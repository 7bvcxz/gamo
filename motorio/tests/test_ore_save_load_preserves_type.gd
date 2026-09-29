extends SceneTree

## A saved world comes back with every node where it was and of the kind it was
## (Factory Interaction Pass 01). Ore is not in the save -- the world is rebuilt
## from its seed -- so this is the promise that the rebuild is the same world:
## the whole node table before and after, compared node for node, and a copper
## node dug by hand after the load gives copper.

const OrePost := preload("res://tests/helpers/ore_post.gd")

var failures := 0

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _finish(name: String) -> void:
	if failures == 0:
		print("PASS %s" % name)
	else:
		print("FAIL %s (%d)" % [name, failures])
	quit(failures)

var main: Node2D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	main = load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	for seed_value in [4242, 777, 90210]:
		main.clear_save()
		main._start_run(seed_value)
		main.finish_tutorial()
		main.state = main.State.PLAY
		var before: Dictionary = main.sim.ore_nodes.duplicate()
		_assert(main.save_game(false), "시드 %d: 저장한다" % seed_value)
		main._start_run(seed_value + 1)
		_assert(main.load_game(), "시드 %d: 불러온다" % seed_value)
		var after: Dictionary = main.sim.ore_nodes
		var changed := 0
		for origin: Vector2i in before:
			if int(after.get(origin, -1)) != int(before[origin]):
				changed += 1
		_assert(after.size() == before.size() and changed == 0,
			"시드 %d: 노드 %d개가 같은 자리·같은 종류로 돌아온다 (%d건 다름)" % [seed_value, before.size(), changed])
	# And a copper node of the loaded world, dug by hand, gives copper.
	var sim: Sim = main.sim
	var copper := Sim.NONE
	for origin: Vector2i in sim.ore_nodes:
		if int(sim.ore_nodes[origin]) == Defs.ITEM_COPPER:
			copper = origin
			break
	_assert(copper != Sim.NONE, "불러온 세계에 구리 노드가 있다")
	if copper != Sim.NONE:
		sim.stones_in = 2000
		sim._refresh_radius()
		var stance: Dictionary = OrePost.stances(copper)[0]
		var got: Dictionary = OrePost.swing(main, stance["at"], stance["facing"], Defs.HAND_MINE_PERIOD * 1.6)
		_assert(got.keys() == [Defs.ITEM_COPPER], "불러온 구리 노드를 곡괭이로 캐면 구리다 (%s)" % str(got))
	main.clear_save()
	main.free()
	_finish("test_ore_save_load_preserves_type")
