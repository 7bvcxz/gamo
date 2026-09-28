extends SceneTree

## Saved and loaded, a post still works the node it worked, and still puts out
## that node's material (World Visual Pass 01).
##
## Three posts -- heat stone, copper, iron -- each with a cat, built the way she
## builds them, written to a save and read back into a fresh game. The save
## carries each rig's target node; the world, regenerated from the seed, has to
## agree with it; and the copper post is run after the load to show that what
## comes out is copper.

const OrePost := preload("res://tests/helpers/ore_post.gd")

var failures := 0
var main: Node2D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	main = load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	_test_round_trip()
	main.clear_save()
	main.free()
	if failures == 0:
		print("PASS test_mining_post_save_load_preserves_target_ore")
	else:
		print("FAIL test_mining_post_save_load_preserves_target_ore (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _test_round_trip() -> void:
	OrePost.fresh(main)
	var sim: Sim = main.sim
	# Real nodes of the world, not ones put down by the test: a load regenerates
	# the ore from the seed, and only generated nodes survive that.
	var picks: Dictionary = {}
	for kind: int in [Defs.ITEM_HEATSTONE, Defs.ITEM_COPPER, Defs.ITEM_IRON]:
		var best := Sim.NONE
		var best_distance := 1e20
		for origin: Vector2i in sim.ore_nodes:
			if int(sim.ore_nodes[origin]) != kind or sim.machine_at(origin) != null:
				continue
			if not sim.footprint_problems(Defs.M_MINER, origin, Vector2i.UP).is_empty():
				continue
			var distance: float = sim.ore_tiles_from_core(origin)
			if distance < best_distance:
				best_distance = distance
				best = origin
		_assert(best != Sim.NONE, "%s 노드가 있다" % Defs.ITEM_NAMES[kind])
		if best == Sim.NONE:
			continue
		_assert(sim.build(Defs.M_MINER, best, Vector2i.UP), "%s 노드에 채굴기를 짓는다" % Defs.ITEM_NAMES[kind])
		sim.grant_cats(1)
		sim.carried_cat = sim.cats[sim.cats.size() - 1]
		sim.place_cat(best)
		picks[kind] = best
	_assert(main.save_game(false), "저장한다")
	var text: String = FileAccess.get_file_as_string(main.slot_path(0))
	_assert(text.contains("\"ore_x\""), "저장 파일에 채굴기의 목표 노드가 적힌다")
	# A different world in between, so nothing survives by accident.
	main._start_run(99)
	_assert(main.load_game(), "불러온다")
	sim = main.sim
	for kind: int in picks:
		var node: Vector2i = picks[kind]
		var post: Sim.Machine = sim.machine_at(node)
		var name: String = Defs.ITEM_NAMES[kind]
		_assert(post != null and Defs.machine_mines(post.type), "%s 채굴기가 돌아온다" % name)
		if post == null:
			continue
		_assert(post.cell == node and post.ore_node == node, "%s 채굴기의 목표 노드가 그대로다" % name)
		_assert(sim.ore_type_at(post.ore_node) == kind, "그 노드는 여전히 %s 다" % name)
		var staffed := false
		for cat: Sim.Cat in sim.cats:
			if cat.assigned == node:
				staffed = true
		_assert(staffed, "%s 채굴기의 고양이도 그대로다" % name)
	# And the copper post, run after the load, puts out copper.
	if picks.has(Defs.ITEM_COPPER):
		var post: Sim.Machine = sim.machine_at(picks[Defs.ITEM_COPPER])
		var out_cell: Vector2i = sim.output_cell(post)
		var out: Dictionary = {}
		main.player.position = sim.core_centre()
		for step in int(50.0 * 30.0):
			main.player.warmth = 100.0
			main._process_play(1.0 / 30.0)
			if sim.ground.has(out_cell):
				out[int(sim.ground[out_cell])] = true
				sim.ground.erase(out_cell)
				sim.ground_stack.erase(out_cell)
		_assert(out.keys() == [Defs.ITEM_COPPER], "불러온 구리 채굴기가 구리만 낸다 (%s)" % str(out.keys()))
