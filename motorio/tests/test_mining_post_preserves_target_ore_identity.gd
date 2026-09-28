extends SceneTree

## A post names the node it works, and building it changes nothing about the
## node (World Visual Pass 01).
##
## The post's target is explicit (`Machine.ore_node`), is the node's origin, and
## is what every one of the post's cells answers for. The ore stays in the world
## under it -- same type, same purity, all four cells -- and comes back exactly as
## it was when the post is taken down. A cat put on any cell of the post is put
## on that node, and a rig swapped for the other one works the same node.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for kind: int in [Defs.ITEM_HEATSTONE, Defs.ITEM_COPPER, Defs.ITEM_IRON]:
		_test_kind(kind)
	if failures == 0:
		print("PASS test_mining_post_preserves_target_ore_identity")
	else:
		print("FAIL test_mining_post_preserves_target_ore_identity (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _test_kind(kind: int) -> void:
	var name: String = Defs.ITEM_NAMES[kind]
	var sim := Sim.new()
	sim.setup(5150)
	for type: int in Defs.MINER_MACHINES:
		sim.unlocked[type] = true
	for item: int in [Defs.ITEM_HEATSTONE, Defs.ITEM_COPPER, Defs.ITEM_IRON,
			Defs.ITEM_IRON_PLATE, Defs.ITEM_COPPER_WIRE, Defs.ITEM_ELECTRIC_MOTOR]:
		sim.stock[item] = 500
	sim.stones_in = 400
	sim._refresh_radius()
	var node: Vector2i = sim.core_cell + Vector2i(20, -4)
	var area := Rect2i(node - Vector2i(6, 6), Vector2i(14, 14))
	for cell: Vector2i in Grid.cells_in(area):
		sim.erase_ore_at(cell)
		sim.mined_rocks[Grid.tile_of(cell)] = true
	for props: Dictionary in [sim.frozen_cats, sim.debris, sim.village]:
		for key: Vector2i in props.keys():
			if sim.prop_rect(key).intersects(area):
				props.erase(key)
	sim.put_ore(node, kind)
	sim._assign_purity()
	var purity: int = sim.purity_of(node)
	_assert(sim.build(Defs.M_MINER, node, Vector2i.RIGHT), "%s: 노드에 채굴기를 짓는다 (%s)"
		% [name, sim.can_build(Defs.M_MINER, node, Vector2i.RIGHT)])
	var post: Sim.Machine = sim.machine_at(node)
	_assert(post != null and post.ore_node == node and post.cell == node,
		"%s: 채굴기의 목표 노드는 노드의 원점이다" % name)
	var agree := 0
	for cell: Vector2i in Grid.cells_in(sim.machine_rect(post)):
		if sim.machine_at(cell) == post and sim.post_anchor(cell) == node \
				and sim.ore_origin_at(cell) == node and sim.ore_type_at(cell) == kind:
			agree += 1
	_assert(agree == 4, "%s: 채굴기의 네 칸이 모두 같은 노드·같은 종류를 가리킨다 (%d)" % [name, agree])
	_assert(sim.ore_nodes.get(node, -1) == kind and sim.ore_errors().is_empty(),
		"%s: 채굴기 밑의 광맥 자료가 그대로다" % name)
	var rates: Dictionary = sim.design_rates(post)["out"]
	_assert(rates.keys() == [kind], "%s: 설계 산출도 그 노드의 재료다 (%s)" % [name, str(rates.keys())])
	# A cat put down on the post's far corner works this node.
	sim.cats.clear()
	sim.grant_cats(1)
	sim.carried_cat = sim.cats[0]
	var corner: Vector2i = sim.machine_rect(post).end - Vector2i.ONE
	_assert(sim.place_cat(corner), "%s: 채굴기의 모서리 칸에 고양이를 둔다" % name)
	_assert(sim.cats[0].assigned == node, "%s: 그 고양이는 그 노드에 배정된다" % name)
	# Taken down: the node is exactly as it was.
	_assert(sim.demolish(corner), "%s: 채굴기를 회수한다" % name)
	_assert(sim.ore_nodes.get(node, -1) == kind and sim.purity_of(node) == purity
		and sim.ore_errors().is_empty(), "%s: 회수해도 노드는 그대로다" % name)
	# The other rig on the same node works the same node.
	_assert(sim.build(Defs.M_MINER_MK2, node, Vector2i.DOWN), "%s: Mk.2 를 같은 노드에 짓는다" % name)
	var mk2: Sim.Machine = sim.machine_at(node)
	_assert(mk2 != null and mk2.ore_node == node and sim.ore_item(mk2.ore_node) == kind,
		"%s: Mk.2 도 같은 노드를 목표로 한다" % name)
	sim.free()
