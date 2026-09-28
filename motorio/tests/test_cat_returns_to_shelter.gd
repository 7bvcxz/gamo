extends SceneTree

## At night every cat walks home to the hut -- the four by four one -- and gets
## there (World Visual Pass 01).
##
## Cats at work on posts south and east of the fire, and one idle by the bin,
## are sent home at nightfall. Every one reaches the doorstep and goes to sleep
## inside the limit, none crosses the hut's sixteen cells, the base or anyone
## else's post on the way, and the doorstep they gather at is outside the hut.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_home()
	if failures == 0:
		print("PASS test_cat_returns_to_shelter")
	else:
		print("FAIL test_cat_returns_to_shelter (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _test_home() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	sim.cats.clear()
	for type: int in Defs.MINER_MACHINES:
		sim.unlocked[type] = true
	sim.stock[Defs.ITEM_HEATSTONE] = 500
	sim.stock[Defs.ITEM_COPPER] = 500
	var posts: Array[Vector2i] = []
	for offset: Vector2i in Sim.STARTER_PATCH:
		var node: Vector2i = sim.core_cell + offset
		if sim.build(Defs.M_MINER, node, Vector2i.UP):
			posts.append(node)
	_assert(posts.size() == Sim.STARTER_PATCH.size(), "시작 노드 셋에 채굴기가 선다")
	sim.grant_cats(posts.size() + 1)
	for index in posts.size():
		var cat: Sim.Cat = sim.cats[index]
		cat.assigned = posts[index]
		cat.state = Defs.CAT_WORKING
		cat.pos = sim.post_stand(posts[index])
	# One loose by the bin.
	sim.cats[posts.size()].pos = Grid.rect_centre(sim.food_rect()) + Vector2(-24.0, 12.0)
	sim.send_cats_home()
	var hut: Rect2 = Grid.rect_px(sim.shelter_rect()).grow(-0.5)
	var base: Rect2 = Grid.rect_px(sim.base_rect()).grow(-0.5)
	var trespass := 0
	var elapsed := 0.0
	var home := 0
	while elapsed < 60.0:
		sim.tick(0.05)
		elapsed += 0.05
		home = 0
		for cat: Sim.Cat in sim.cats:
			if cat.state == Defs.CAT_ASLEEP:
				home += 1
			if hut.has_point(cat.pos) or base.has_point(cat.pos):
				trespass += 1
			for node: Vector2i in posts:
				if node != cat.assigned and Grid.rect_px(Sim.ore_rect(node)).grow(-0.5).has_point(cat.pos):
					trespass += 1
		if home == sim.cats.size():
			break
	_assert(home == sim.cats.size(), "고양이 %d마리가 모두 숙소로 돌아가 잔다 (%d, %.0f초)"
		% [sim.cats.size(), home, elapsed])
	_assert(trespass == 0, "오는 길에 숙소·기지·남의 채굴기를 통과하지 않는다 (%d)" % trespass)
	var door: Vector2 = sim.shelter_doorstep()
	_assert(not hut.has_point(door), "모이는 문간은 숙소 밖이다")
	for cat: Sim.Cat in sim.cats:
		_assert(cat.pos.distance_to(door) < Grid.px(1.5), "문간에 모였다 (%.0fpx)" % cat.pos.distance_to(door))
	sim.free()
