extends SceneTree

## Every material the registry calls a seam yields itself -- by post, by a cat
## on the bare node, and by her pickaxe -- and nothing else yields anything
## (World Visual Pass 01).
##
## Walks the item table rather than a list written here, so a seam added later
## is covered by adding its row. A node of a type that is not a seam, and a post
## with no node under it, produce nothing at all: the old tick fell back to
## crystal, a machine inventing its own output.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var seams: Array[int] = []
	for id: int in Defs.item_ids():
		if Defs.ore_output(id) >= 0:
			seams.append(id)
	_assert(seams.has(Defs.ITEM_HEATSTONE) and seams.has(Defs.ITEM_COPPER)
		and seams.has(Defs.ITEM_IRON), "열석·구리·철은 광맥 재료다 (%s)" % str(seams))
	for tier: int in Defs.ORE_TIERS:
		_assert(seams.has(tier), "광맥 사다리의 %s 도 광맥 재료다" % Defs.ITEM_NAMES[tier])
	for id: int in Defs.item_ids():
		var seam: bool = Defs.item_atlas(id) != ""
		_assert((Defs.ore_output(id) == id) == seam,
			"%s: 광맥 그림이 있으면 자기 자신을, 없으면 아무것도 내지 않는다" % Defs.ITEM_NAMES[id])
	_assert(Defs.ore_output(-1) == -1, "광맥이 없는 곳은 아무것도 내지 않는다")
	for id: int in seams:
		_test_every_way(id)
	_test_nothing_from_nothing()
	if failures == 0:
		print("PASS test_all_registered_ores_output_correct_item")
	else:
		print("FAIL test_all_registered_ores_output_correct_item (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _sim() -> Sim:
	var sim := Sim.new()
	sim.setup(777)
	sim.clear_ore()
	sim.cats.clear()
	sim.stones_in = 400
	sim._refresh_radius()
	return sim

const NODE := Vector2i(14, -6)

func _test_every_way(id: int) -> void:
	var name: String = Defs.ITEM_NAMES[id]
	# A post of every kind.
	for type: int in Defs.MINER_MACHINES:
		var sim := _sim()
		var node: Vector2i = sim.core_cell + NODE
		sim.put_ore(node, id)
		var post := Sim.Machine.new()
		post.type = type
		post.cell = node
		post.dir = Vector2i.UP
		sim.add_machine(post)
		var out: Vector2i = sim.output_cell(post)
		var got: Dictionary = {}
		for step in 1200:
			post.operated = true
			sim._tick_miner(post, 0.1)
			if sim.ground.has(out):
				got[int(sim.ground[out])] = true
				sim.ground.erase(out)
				sim.ground_stack.erase(out)
		_assert(got.keys() == [id], "%s 위 %s: %s 만 낸다 (%s)"
			% [name, Defs.MACHINE_NAMES[type], name, str(got.keys())])
		sim.free()
	# A cat on the bare node, and her pickaxe on any of its cells.
	var sim := _sim()
	var node: Vector2i = sim.core_cell + NODE
	sim.put_ore(node, id)
	var cat := Sim.Cat.new()
	cat.assigned = node
	cat.state = Defs.CAT_WORKING
	cat.pos = sim.post_stand(node)
	sim.cats.append(cat)
	for step in 400:
		sim._cat_work(cat, 0.1)
		if cat.state != Defs.CAT_WORKING:
			break
	_assert(cat.carrying == id, "%s: 고양이가 맨 노드에서 %s 를 캐 나른다 (%d)" % [name, name, cat.carrying])
	for cell: Vector2i in Sim.ore_cells(node):
		var got: int = -1
		for swing in 400:
			got = sim.hand_mine(cell, 0.05)
			if got >= 0:
				break
		_assert(got == id, "%s: 노드의 %s 칸을 곡괭이로 캐면 %s (%d)" % [name, cell - node, name, got])
	sim.free()

func _test_nothing_from_nothing() -> void:
	var sim := _sim()
	var node: Vector2i = sim.core_cell + NODE
	# A post whose node has gone from under it (a world that changed around a
	# save, say) stops. It does not make something up.
	sim.put_ore(node, Defs.ITEM_COPPER)
	var post := Sim.Machine.new()
	post.type = Defs.M_MINER
	post.cell = node
	post.dir = Vector2i.UP
	sim.add_machine(post)
	sim.erase_ore_at(node)
	var out: Vector2i = sim.output_cell(post)
	for step in 600:
		post.operated = true
		sim._tick_miner(post, 0.1)
	_assert(not sim.ground.has(out), "광맥이 없는 채굴기는 아무것도 내지 않는다")
	_assert(post.stalled, "그리고 멈춰 있다고 말한다")
	# A node of a type that is not a seam material yields nothing either.
	sim.put_ore(node, Defs.ITEM_STONE)
	_assert(sim.ore_item(node) == -1, "광맥 재료가 아닌 종류의 노드는 아무것도 내지 않는다")
	sim.free()
