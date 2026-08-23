extends SceneTree

## Wreckage from the ship she came down in.
##
## Three promises, and the first two are about where it is not: nothing inside
## eleven tiles, exactly one piece on the eleventh ring, and a thin scatter past
## twelve. The first two are the kind of guarantee this repository has watched
## fail one run in five -- the world is different every seed and most seeds are
## fine -- so they are checked across two hundred of them rather than one.
##
## The third promise is about what comes out, and the one that matters there is
## the first piece: twenty percent is a fair rate for a plateau covered in
## wreckage and a terrible one for the piece that has to teach the player that
## core parts exist at all.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_where_it_is()
	_test_the_first_ring_holds()
	_test_taking_one_apart()
	_test_before_copper()
	_test_the_first_piece()
	_test_the_rate()
	_test_out_of_reach()
	await _test_the_debug_key()
	if failures == 0:
		print("DEBRIS_TEST: PASS")
	else:
		print("DEBRIS_TEST: FAIL (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

## The key that lays all five out in front of her. Pinned because a debug tool
## that quietly stops working is a tool that makes checking cost a playthrough
## again -- and this repository has already spent a session hunting a bug that
## was the harness rather than the game.
func _test_the_debug_key() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main._start_run()
	main.state = main.State.PLAY
	main.sim.debris.clear()
	main.debug_debris()
	_assert(main.sim.debris.size() == Defs.DEBRIS_SHAPES,
		"디버그 키가 다섯 조각을 놓는다 (%d개)" % main.sim.debris.size())
	var shapes: Dictionary[int, bool] = {}
	var near := true
	for cell: Vector2i in main.sim.debris:
		shapes[int(main.sim.debris[cell])] = true
		if main.player.cell().distance_to(cell) > 4.0:
			near = false
	_assert(shapes.size() == Defs.DEBRIS_SHAPES, "다섯 모양이 전부 있다")
	_assert(near, "전부 주인공 바로 옆이다")
	main.queue_free()

func _ring(sim: Sim, cell: Vector2i) -> float:
	return Vector2(cell - sim.core_cell).length()

func _test_where_it_is() -> void:
	var sim := Sim.new()
	sim.setup(20260818)
	var inside := 0
	var far := 0
	var shapes: Dictionary[int, bool] = {}
	for cell: Vector2i in sim.debris:
		var distance: float = _ring(sim, cell)
		if distance < Defs.DEBRIS_FIRST_RING - 0.5:
			inside += 1
		if distance >= Defs.DEBRIS_START_RING:
			far += 1
		shapes[int(sim.debris[cell])] = true
	_assert(inside == 0, "10칸 안에는 한 조각도 없다 (%d개)" % inside)
	_assert(far >= 5, "12칸 밖에 흩어져 있다 (%d개)" % far)
	# The whole point of five pictures is that a field of wreckage does not
	# repeat. One seed drawing three of them would be five prompts paid for and
	# three used.
	# A dozen pieces and five shapes: any one world can miss a shape by chance, so
	# the promise is checked across seeds rather than inside one.
	var seen: Dictionary[int, bool] = {}
	for index in 12:
		var other := Sim.new()
		other.setup(61000 + index)
		for cell: Vector2i in other.debris:
			seen[int(other.debris[cell])] = true
		other.free()
	_assert(seen.size() == Defs.DEBRIS_SHAPES,
		"다섯 모양이 전부 쓰인다 (%d종)" % seen.size())
	_assert(shapes.size() >= 3, "한 회차에도 여러 모양이 섞인다 (%d종)" % shapes.size())
	# Sparse, not a carpet. The density is the difference between "walk out and
	# find something" and "walk out and stand in a scrapyard".
	var reach: float = Defs.WARM_MAX + 8.0
	var area: float = PI * (reach * reach - Defs.DEBRIS_START_RING * Defs.DEBRIS_START_RING)
	var per: float = area / float(sim.debris.size())
	_assert(per >= 140.0 and per <= 280.0, "조각 하나당 %.0f칸 (목표 200)" % per)
	sim.free()

## The guarantee, across two hundred worlds. Exactly one, and on the ring rather
## than near it -- rounding a circle onto a grid puts some of its cells a little
## inside, and a piece at 10.6 is inside the zone the rule says is empty.
func _test_the_first_ring_holds() -> void:
	var worst := 0
	var missing := 0
	var too_close := 0
	for index in 200:
		var sim := Sim.new()
		sim.setup(41000 + index)
		var on_ring := 0
		for cell: Vector2i in sim.debris:
			var distance: float = _ring(sim, cell)
			if roundi(distance) == int(Defs.DEBRIS_FIRST_RING):
				on_ring += 1
			if distance < Defs.DEBRIS_FIRST_RING - 0.5:
				too_close += 1
		if on_ring == 0:
			missing += 1
		worst = maxi(worst, on_ring)
		sim.free()
	_assert(missing == 0, "200회차 모두 11칸에 조각이 있다 (없는 회차 %d)" % missing)
	_assert(worst == 1, "그리고 딱 하나다 (가장 많은 회차 %d개)" % worst)
	_assert(too_close == 0, "10칸 안으로는 한 조각도 새지 않는다 (%d건)" % too_close)

func _test_taking_one_apart() -> void:
	var sim := Sim.new()
	sim.setup(20260818)
	var cell: Vector2i = sim.debris.keys()[0]
	# Inside the fire, so reach is not what this case is about.
	sim.debris.erase(cell)
	var near: Vector2i = sim.core_cell + Vector2i(2, 0)
	sim.debris[near] = 0
	_assert(not sim.search_debris(near, Defs.DEBRIS_SEARCH_SECONDS * 0.5),
		"절반으로는 안 뜯긴다")
	sim.cancel_debris()
	_assert(sim.debris_progress == 0.0, "손을 떼면 처음부터다")
	_assert(sim.search_debris(near, Defs.DEBRIS_SEARCH_SECONDS), "끝까지 누르면 열린다")
	# The wreck pays in the world's own seams: a few of the best the ladder has,
	# and a pile of the rung under it.
	#
	# The best she has *reached*, not the best that exists. A player who has never
	# held copper does not know the word, and a crate of it out of the first wreck
	# names a material the world has not shown her yet.
	var top: int = Defs.ORE_TIERS[Defs.ORE_TIERS.size() - 1]
	var below: int = Defs.ORE_TIERS[maxi(Defs.ORE_TIERS.size() - 2, 0)]
	sim.collected[top] = 1
	var before: int = int(sim.stock.get(top, 0))
	var found: Dictionary = sim.open_debris(near)
	_assert(not sim.debris.has(near), "뜯은 조각은 사라진다")
	_assert(int(sim.stock.get(top, 0)) > before, "재료가 실제로 들어온다")
	_assert(int(found[top]) >= Defs.DEBRIS_HIGH.x and int(found[top]) <= Defs.DEBRIS_HIGH.y,
		"%s 2~5개 (%d)" % [Defs.ITEM_SHORT[top], int(found[top])])
	_assert(int(found[below]) >= Defs.DEBRIS_LOW.x and int(found[below]) <= Defs.DEBRIS_LOW.y,
		"%s 5~10개 (%d)" % [Defs.ITEM_SHORT[below], int(found[below])])
	# And it is the top of the ladder rather than a resource of the wreck's own.
	# A second economy beside the seams is a second thing to balance.
	_assert(top != below, "두 등급은 서로 다른 자원이다")
	for item_type: int in found:
		_assert(item_type in Defs.ORE_TIERS or item_type == Defs.ITEM_CORE_PART,
			"잔해는 광맥 자원과 코어부품만 준다 (%s)" % Defs.ITEM_SHORT[item_type])
	_assert(sim.open_debris(near).is_empty(), "없는 조각은 아무것도 주지 않는다")
	sim.free()

## And before she has held any, the same wreck is heat and nothing else.
func _test_before_copper() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	var cell: Vector2i = sim.core_cell + Vector2i(2, 0)
	sim.debris[cell] = 0
	sim.debris_searched = 1   # past the guaranteed core part, so only the seams show
	_assert(int(sim.collected.get(Defs.ITEM_COPPER, 0)) == 0, "구리를 캔 적이 없고")
	var found: Dictionary = sim.open_debris(cell)
	_assert(not found.has(Defs.ITEM_COPPER), "잔해에서 구리가 나오지 않는다")
	_assert(int(found.get(Defs.ITEM_HEATSTONE, 0)) >= Defs.DEBRIS_HIGH.x + Defs.DEBRIS_LOW.x,
		"두 줄이 모두 열석으로 나온다: %d" % int(found.get(Defs.ITEM_HEATSTONE, 0)))
	# And the moment she has held one, the wreck starts paying in it.
	sim.collected[Defs.ITEM_COPPER] = 1
	var second: Vector2i = sim.core_cell + Vector2i(3, 0)
	sim.debris[second] = 0
	_assert(sim.open_debris(second).has(Defs.ITEM_COPPER), "한 번 캐고 나면 구리가 나온다")
	sim.free()

## Every world's first piece carries a core part. Checked over many seeds
## because the roll is seeded and one seed proves nothing about a probability.
func _test_the_first_piece() -> void:
	var without := 0
	for index in 60:
		var sim := Sim.new()
		sim.setup(52000 + index)
		var cell: Vector2i = sim.core_cell + Vector2i(2, 0)
		sim.debris[cell] = 0
		var found: Dictionary = sim.open_debris(cell)
		if int(found.get(Defs.ITEM_CORE_PART, 0)) != 1:
			without += 1
		sim.free()
	_assert(without == 0, "첫 조각은 60회차 모두 코어부품 1개를 준다 (%d회 실패)" % without)

## And after the first, a quarter of them: one in five gives one, one in twenty
## gives two. Measured over a few thousand pieces, with a band wide enough that
## it fails on a wrong rate rather than on a bad afternoon.
func _test_the_rate() -> void:
	var sim := Sim.new()
	sim.setup(20260818)
	var cell: Vector2i = sim.core_cell + Vector2i(2, 0)
	sim.debris[cell] = 0
	sim.open_debris(cell)
	var ones := 0
	var twos := 0
	var rounds := 4000
	for index in rounds:
		sim.debris[cell] = 0
		var got: int = int(sim.open_debris(cell).get(Defs.ITEM_CORE_PART, 0))
		if got == 1:
			ones += 1
		elif got == 2:
			twos += 1
	var one_rate: float = float(ones) / float(rounds)
	var two_rate: float = float(twos) / float(rounds)
	_assert(absf(one_rate - Defs.DEBRIS_CORE_ONE) < 0.03, "1개 확률 %.1f%% (목표 20%%)" % (one_rate * 100.0))
	_assert(absf(two_rate - Defs.DEBRIS_CORE_TWO) < 0.02, "2개 확률 %.1f%% (목표 5%%)" % (two_rate * 100.0))
	sim.free()

## And it obeys the rule everything else out there obeys: past the fire, with no
## torch in hand, the ground has not let go of it either.
func _test_out_of_reach() -> void:
	var sim := Sim.new()
	sim.setup(20260818)
	var far: Vector2i = sim.core_cell + Vector2i(int(sim.warm_radius) + 4, 0)
	sim.debris[far] = 0
	_assert(not sim.search_debris(far, 99.0), "온기 밖에서는 뜯을 수 없다")
	_assert(sim.open_debris(far).is_empty(), "아무것도 나오지 않는다")
	sim.torch_lit = true
	_assert(sim.search_debris(far, Defs.DEBRIS_SEARCH_SECONDS), "횃불을 들면 뜯을 수 있다")
	_assert(not sim.open_debris(far).is_empty(), "재료가 나온다")
	sim.free()
