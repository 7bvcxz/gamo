extends SceneTree

## A cat sent to a post walks onto it and works it from there (World Visual
## Pass 01). It used to stand outside a four by four, against its back wall.
##
## The post is solid to everyone -- she cannot walk through it, and no cat may
## cross it -- except to the one cat assigned to it, which may step onto its own
## work spot. So: the cat arrives on the spot (`post_stand`), whichever way the
## post faces and from whichever side it comes; the only footprint cell its body
## ever enters is the spot's own; it never crosses another post, the base or the
## hut; and it walks there -- no step longer than its speed allows.

var failures := 0

const SITE := Vector2i(30, 10)
const DT := 0.05

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_each_facing()
	_test_crowded_row()
	_test_from_the_hut()
	if failures == 0:
		print("PASS test_cat_can_enter_post_work_position")
	else:
		print("FAIL test_cat_can_enter_post_work_position (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _sim() -> Sim:
	var sim := Sim.new()
	sim.setup(4242)
	sim.cats.clear()
	sim.unlocked[Defs.M_MINER] = true
	for item: int in [Defs.ITEM_HEATSTONE, Defs.ITEM_COPPER]:
		sim.stock[item] = 5000
	return sim

func _clear(sim: Sim, rect: Rect2i) -> void:
	for cell: Vector2i in Grid.cells_in(rect):
		sim.erase_ore_at(cell)
	for props: Dictionary in [sim.frozen_cats, sim.debris, sim.village]:
		for origin: Vector2i in props.keys():
			if sim.prop_rect(origin).intersects(rect):
				props.erase(origin)
	sim._grid_dirty = true

## Puts a cat down at `from` with a job at `node` and runs the sim until it is
## working. Returns {seconds (-1 if never), foreign: ticks inside someone else's
## footprint, own_cells: footprint cells of its own post its body entered,
## longest: the longest single step, at: where it ended}.
func _send(sim: Sim, node: Vector2i, from: Vector2, rects: Array[Rect2i]) -> Dictionary:
	var cat := Sim.Cat.new()
	cat.pos = from
	cat.assigned = node
	cat.state = Defs.CAT_TO_MINER
	sim.cats.append(cat)
	var own: Rect2i = sim.machine_rect(sim.machine_at(node))
	var foreign := 0
	var own_cells: Dictionary = {}
	var longest := 0.0
	var elapsed := 0.0
	var last: Vector2 = cat.pos
	while elapsed < 120.0:
		sim.tick(DT)
		elapsed += DT
		longest = maxf(longest, cat.pos.distance_to(last))
		last = cat.pos
		for rect: Rect2i in rects:
			if rect != own and Grid.rect_px(rect).grow(-0.5).has_point(cat.pos):
				foreign += 1
		var here: Vector2i = sim.cell_of(cat.pos)
		if own.has_point(here):
			own_cells[here] = true
		if cat.state == Defs.CAT_WORKING:
			break
	return {"seconds": elapsed if cat.state == Defs.CAT_WORKING else -1.0,
		"foreign": foreign, "own_cells": own_cells, "longest": longest, "at": cat.pos}

func _check_trip(sim: Sim, node: Vector2i, trip: Dictionary, label: String) -> void:
	var spot: Vector2 = sim.post_stand(node)
	_assert(float(trip["seconds"]) > 0.0, "%s: 고양이가 채굴기 위 자리에 가서 일을 시작한다 (%.1f초)"
		% [label, float(trip["seconds"])])
	_assert((trip["at"] as Vector2).distance_to(spot) < 0.5, "%s: 일하는 자리에 정확히 선다" % label)
	_assert(int(trip["foreign"]) == 0, "%s: 다른 건물은 통과하지 않는다 (%d)" % [label, int(trip["foreign"])])
	var own_cells: Dictionary = trip["own_cells"]
	_assert(own_cells.keys() == [sim.cell_of(spot)],
		"%s: 제 채굴기에서는 일하는 자리의 칸에만 들어선다 (%s)" % [label, str(own_cells.keys())])
	_assert(float(trip["longest"]) <= Defs.CAT_SPEED * DT + 0.01,
		"%s: 순간이동 없이 걸어 들어간다 (한 틱 최대 %.2fpx)" % [label, float(trip["longest"])])

func _test_each_facing() -> void:
	var headings: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
	for dir: Vector2i in headings:
		for side: Vector2i in headings:
			var sim := _sim()
			var node: Vector2i = sim.core_cell + SITE
			_clear(sim, Rect2i(node - Vector2i(12, 12), Vector2i(25, 25)))
			sim.put_ore(node, Defs.ITEM_HEATSTONE)
			sim.build(Defs.M_MINER, node, dir)
			var rect: Rect2i = sim.machine_rect(sim.machine_at(node))
			_assert(Grid.rect_px(rect).has_point(sim.post_stand(node) + Vector2(0.0, Defs.CAT_FOOT_DROP)),
				"%s 향: 일하는 자리(발)는 채굴기 위다" % dir)
			var from: Vector2 = Grid.rect_centre(rect) + Vector2(side) * 90.0
			var trip: Dictionary = _send(sim, node, from, [rect] as Array[Rect2i])
			_check_trip(sim, node, trip, "%s 향, %s 쪽에서" % [dir, side])
			sim.free()

## Posts shoulder to shoulder on a row of nodes: every one is reached, and no
## cat walks over a neighbour on the way to its own.
func _test_crowded_row() -> void:
	var sim := _sim()
	var origin: Vector2i = sim.core_cell + SITE
	_clear(sim, Rect2i(origin - Vector2i(12, 12), Vector2i(Defs.ORE_PITCH * 5 + 24, 25)))
	var nodes: Array[Vector2i] = []
	var rects: Array[Rect2i] = []
	for index in 5:
		var node: Vector2i = origin + Vector2i(index * Defs.ORE_PITCH, 0)
		sim.put_ore(node, Defs.ITEM_HEATSTONE)
		sim.build(Defs.M_MINER, node, Vector2i.DOWN)
		nodes.append(node)
		rects.append(sim.machine_rect(sim.machine_at(node)))
	var spots: Dictionary = {}
	for node: Vector2i in nodes:
		spots[sim.cell_of(sim.post_stand(node))] = true
	_assert(spots.size() == nodes.size(), "다섯 채굴기의 일하는 자리가 서로 다르다")
	var middle: Vector2i = nodes[2]
	var trip: Dictionary = _send(sim, middle, Grid.rect_centre(rects[2]) + Vector2(0.0, 90.0), rects)
	_check_trip(sim, middle, trip, "가운데 채굴기")
	sim.free()

## The real morning: every cat leaves the hut's doorstep for its own post.
func _test_from_the_hut() -> void:
	var sim := _sim()
	var nodes: Array[Vector2i] = []
	for offset: Vector2i in Sim.STARTER_PATCH:
		var node: Vector2i = sim.core_cell + offset
		if sim.can_build(Defs.M_MINER, node, Vector2i.UP) == "":
			sim.build(Defs.M_MINER, node, Vector2i.UP)
			nodes.append(node)
	_assert(nodes.size() == Sim.STARTER_PATCH.size(), "시작 노드 셋에 모두 채굴기가 선다")
	sim.grant_cats(nodes.size())
	for index in nodes.size():
		sim.cats[index].assigned = nodes[index]
	sim.dispatch_cats()
	var fixed: Array[Rect2i] = [sim.base_rect(), sim.shelter_rect()]
	var elapsed := 0.0
	var working := 0
	var trespass := 0
	while elapsed < 90.0:
		sim.tick(DT)
		elapsed += DT
		working = 0
		for cat: Sim.Cat in sim.cats:
			if cat.state == Defs.CAT_WORKING:
				working += 1
			for rect: Rect2i in fixed:
				if Grid.rect_px(rect).grow(-0.5).has_point(cat.pos):
					trespass += 1
			for node: Vector2i in nodes:
				if node == cat.assigned:
					continue
				if Grid.rect_px(Sim.ore_rect(node)).grow(-0.5).has_point(cat.pos):
					trespass += 1
		if working == nodes.size():
			break
	_assert(working == nodes.size(), "아침에 모두 제 채굴기 위에 올라 일한다 (%d/%d, %.0f초)"
		% [working, nodes.size(), elapsed])
	_assert(trespass == 0, "숙소·기지·남의 채굴기를 통과한 고양이가 없다 (%d)" % trespass)
	for cat: Sim.Cat in sim.cats:
		var feet: Vector2 = cat.pos + Vector2(0.0, Defs.CAT_FOOT_DROP)
		_assert(Grid.rect_px(Sim.ore_rect(cat.assigned)).has_point(feet), "고양이의 발이 제 채굴기 위에 있다")
	sim.free()
