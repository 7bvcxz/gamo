extends SceneTree

## A cat working a post is drawn on top of it (World Visual Pass 01).
##
## The cat stands on the post now, so the order the two are painted in is the
## difference between a cat at work and a machine with a cat-shaped hole in it.
## The contract, in the running scene: the cats' layer is above the machines',
## the working cat's feet are on its post, it holds the drill, and its shadow
## is still above the machine it stands on (a shadow under the post is a cat
## floating in front of it).

var failures := 0
var main: Node2D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	main = load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	await _test_contract()
	main.clear_save()
	main.free()
	if failures == 0:
		print("PASS test_cat_work_layering_contract")
	else:
		print("FAIL test_cat_work_layering_contract (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _z(node: Node) -> int:
	var z := 0
	var at: Node = node
	while at != null and at is CanvasItem:
		z += (at as CanvasItem).z_index
		if not (at as CanvasItem).z_as_relative:
			break
		at = at.get_parent()
	return z

func _test_contract() -> void:
	main.clear_save()
	main._start_run()
	main.finish_tutorial()
	main.state = main.State.PLAY
	var sim: Sim = main.sim
	var node: Vector2i = sim.core_cell + Sim.STARTER_PATCH[1]
	_assert(sim.build(Defs.M_MINER, node, Vector2i.UP) or sim.machine_at(node) != null
		or _force_post(sim, node), "시작 노드에 채굴기가 선다")
	sim.cats.clear()
	sim.grant_cats(1)
	sim.carried_cat = sim.cats[0]
	_assert(sim.place_cat(node), "고양이를 채굴기에 둔다")
	var cat: Sim.Cat = sim.cats[0]
	_assert(cat.state == Defs.CAT_WORKING, "고양이가 일한다")
	for step in 3:
		main._process_play(1.0 / 30.0)
		await process_frame
	var machines: Node = main.get_node("Machines")
	var cats: Node = main.get_node("Cats")
	_assert(_z(cats) > _z(machines), "고양이 층(z %d)이 설비 층(z %d) 위다" % [_z(cats), _z(machines)])
	var feet: Vector2 = cat.pos + Vector2(0.0, Defs.CAT_FOOT_DROP)
	_assert(Grid.rect_px(sim.machine_rect(sim.machine_at(node))).has_point(feet), "일하는 고양이의 발이 채굴기 위다")
	_assert(sim.cat_has_tool(cat), "그리고 드릴을 든다")
	var view: CatView = null
	for child: Node in cats.get_children():
		if child is CatView and (child as CatView).cat == cat:
			view = child
	_assert(view != null and view.visible, "그 고양이가 화면에 그려진다")
	if view != null:
		_assert(_z(view._shadow) > _z(machines), "고양이 그림자도 채굴기 위에 깔린다 (z %d > %d)"
			% [_z(view._shadow), _z(machines)])
		_assert(view.position.distance_to(cat.pos) < 1.0, "그림이 고양이 자리에 있다")

func _force_post(sim: Sim, node: Vector2i) -> bool:
	var post := Sim.Machine.new()
	post.type = Defs.M_MINER
	post.cell = node
	post.dir = Vector2i.UP
	sim.add_machine(post)
	return true
