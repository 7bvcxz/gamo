extends SceneTree

## Where a post's output leaves and where its cat stands are two different
## places (World Visual Pass 01).
##
## The output anchor is the cell of the post's front edge in line with its
## anchor; what it makes goes out into the cell past it (`output_cell`). The cat
## stands on the post at its work anchor. Neither is the other in any
## direction, the cat's body is never on the output cell, and with the cat at
## work the output keeps flowing -- a worker standing in its own doorway would
## be a post that stops itself.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for type: int in Defs.MINER_MACHINES:
		for dir: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			_test(type, dir)
	if failures == 0:
		print("PASS test_output_anchor_is_separate_from_cat_work_anchor")
	else:
		print("FAIL test_output_anchor_is_separate_from_cat_work_anchor (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _test(type: int, dir: Vector2i) -> void:
	var label: String = "%s %s" % [Defs.MACHINE_NAMES[type], dir]
	var sim := Sim.new()
	sim.setup(4242)
	sim.clear_ore()
	sim.cats.clear()
	var node: Vector2i = sim.core_cell + Vector2i(30, 10)
	var area := Rect2i(node - Vector2i(6, 6), Vector2i(14, 14))
	for props: Dictionary in [sim.frozen_cats, sim.debris, sim.village]:
		for key: Vector2i in props.keys():
			if sim.prop_rect(key).intersects(area):
				props.erase(key)
	for cell: Vector2i in Grid.cells_in(area):
		sim.mined_rocks[Grid.tile_of(cell)] = true
	sim.put_ore(node, Defs.ITEM_HEATSTONE)
	var post := Sim.Machine.new()
	post.type = type
	post.cell = node
	post.dir = dir
	sim.add_machine(post)
	var rect: Rect2i = sim.machine_rect(post)
	var anchor: Vector2i = sim.output_anchor(post)
	var out: Vector2i = sim.output_cell(post)
	_assert(rect.has_point(anchor), "%s: 출력 앵커는 발자국의 칸이다" % label)
	_assert(anchor + dir == out and not rect.has_point(out), "%s: 출구는 그 칸 바로 앞, 발자국 밖이다" % label)
	var feet: Vector2 = sim.work_point(node)
	var torso: Vector2 = sim.post_stand(node)
	_assert(sim.cell_of(feet) != anchor and sim.cell_of(torso) != anchor,
		"%s: 고양이가 출력 앵커 칸을 차지하지 않는다" % label)
	_assert(sim.cell_of(feet) != out and sim.cell_of(torso) != out, "%s: 고양이는 출구 칸에 서지 않는다" % label)
	# At work, the output flows.
	var cat := Sim.Cat.new()
	cat.assigned = node
	cat.state = Defs.CAT_WORKING
	cat.pos = torso
	sim.cats.append(cat)
	var made := 0
	# A cat works at its own pace (rarity, hunger), well under the rated one.
	for step in int(sim.machine_period(post) * 8.0 / 0.1):
		sim.tick(0.1)
		if sim.ground.has(out):
			made += sim.ground_count(out)
			sim.ground.erase(out)
			sim.ground_stack.erase(out)
	_assert(made >= 2, "%s: 고양이가 일하는 동안 출구로 광석이 나온다 (%d개)" % [label, made])
	_assert(cat.state == Defs.CAT_WORKING and cat.pos.distance_to(torso) < 0.5,
		"%s: 고양이는 그동안 제자리에 있다" % label)
	sim.free()
