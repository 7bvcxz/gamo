extends SceneTree

## Outside the fire's reach, everything is frozen into the ground.
##
## The point is not the refusal, it is what the refusal makes the player want.
## The warm radius used to decide the fog and her body temperature and nothing
## else, so the only reason to widen it was "I can walk further". Now it decides
## what she is allowed to have, and the nearest frozen cat lies 8.6 tiles out --
## visible through the two-tile preview band from the first minute, and 1.6 tiles
## short of her reach.
##
## No exceptions: mining, picking up off the ground or a belt, the things out of
## the case, a live cat and a frozen one all ask the same question.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_rule()
	_test_torch_opens_it()
	_test_lifting_needs_the_ground()
	_test_before_the_fire()
	_test_the_cat_out_there()
	if failures == 0:
		print("FROZEN_REACH: PASS")
	else:
		print("FROZEN_REACH: FAIL (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

## A world with the fire already standing, which is what `setup` leaves behind --
## the crash is what takes it away again. Handing her a kit and calling
## `place_base` on top of that does nothing except leave the kit in her arms,
## and `hands_full()` then refuses every pick-up for the rest of the file.
func _lit() -> Sim:
	var sim := Sim.new()
	sim.setup(4242)
	return sim

## A cell well outside the fire, in a direction with nothing built on it.
func _far(sim: Sim) -> Vector2i:
	return sim.core_cell + Vector2i(0, int(sim.warm_radius) + 4)

func _test_rule() -> void:
	var sim := _lit()
	var near: Vector2i = sim.core_cell + Vector2i(1, 1)
	var far: Vector2i = _far(sim)
	_assert(sim.can_touch(near), "불 안쪽은 만질 수 있다")
	_assert(not sim.can_touch(far), "불 밖은 만질 수 없다")

	# Every way of acquiring something asks the same question. Checked one by one
	# because "the rule applies to all of them" is a claim about all of them, and
	# this repository has a record of that kind of rule written into nine
	# handlers with six of them missing it.
	sim.ore[far] = Defs.ITEM_HEATSTONE
	_assert(not sim.can_hand_mine(far), "밖의 광맥은 캘 수 없다")
	_assert(sim.hand_mine(far, 99.0) < 0, "쳐도 아무것도 안 나온다")
	sim.ore.erase(far)

	sim.mined_rocks[far] = true
	sim.drop_item(far, Defs.ITEM_STONE)
	_assert(sim.collect_ground_at(far) < 0, "밖의 바닥 자원은 못 줍는다")
	sim.shards[far] = true
	_assert(not sim.collect_shard_at(far), "밖의 수정조각도 못 줍는다")
	sim.drops[far] = Sim.DROP_PICKAXE
	_assert(sim.collect_drop(far) < 0, "상자에서 나온 것도 밖에서는 못 줍는다")
	sim.frozen_cats[far] = 0.0
	_assert(not sim.pick_up_frozen(far), "얼어붙은 고양이도 밖에서는 못 든다 — 예외는 없다")
	sim.grant_cats(1)
	sim.cats[0].pos = sim.cell_centre(far)
	_assert(not sim.pick_up_cat(far), "살아 있는 고양이도 마찬가지다")

	# And the same things inside the circle are hers.
	var inside: Vector2i = sim.core_cell + Vector2i(2, 0)
	sim.ore.erase(inside)
	sim.mined_rocks[inside] = true
	sim.frozen_cats[inside] = 0.0
	_assert(sim.pick_up_frozen(inside), "온기 안에서는 들 수 있다")
	sim.carried_frozen = false
	sim.drops[inside] = Sim.DROP_PICKAXE
	_assert(sim.collect_drop(inside) == Sim.DROP_PICKAXE, "안쪽 물건은 주워진다")
	sim.free()

## Carrying the heat out there is the other way to make a cell yours.
##
## Without this the rule is a queue behind the base ladder: the only answer to
## "that is out of reach" would be "upgrade the fire", and the torch -- which
## already keeps her warm out there -- would answer nothing.
func _test_torch_opens_it() -> void:
	var sim := _lit()
	var far: Vector2i = _far(sim)
	sim.ore[far] = Defs.ITEM_HEATSTONE
	_assert(not sim.can_hand_mine(far), "횃불이 없으면 밖의 광맥은 그대로다")
	sim.torch_lit = true
	_assert(sim.can_touch(far), "횃불을 들면 만질 수 있다")
	_assert(sim.can_hand_mine(far), "밖의 광맥도 캘 수 있다")
	sim.ore.erase(far)
	sim.mined_rocks[far] = true
	sim.drop_item(far, Defs.ITEM_STONE)
	_assert(sim.collect_ground_at(far) >= 0, "바닥에 떨어진 것도 주워진다")
	sim.free()

## But what has to be carried is frozen into the ground, and the torch has to
## spend five seconds on the ground before the ground lets go.
##
## The split is the whole point of the change: reaching is free once she is
## carrying fire, taking something away with her is not.
func _test_lifting_needs_the_ground() -> void:
	var sim := _lit()
	var far: Vector2i = _far(sim)
	sim.torch_lit = true
	sim.frozen_cats[far] = 0.0
	_assert(sim.can_touch(far), "횃불이 있으니 닿기는 한다")
	_assert(not sim.can_lift(far), "그래도 아직 들 수는 없다")
	_assert(not sim.pick_up_frozen(far), "들려고 해도 안 들린다")

	# Half the time buys nothing. The five seconds are the price, not a bar that
	# remembers how close she got and gives it away anyway.
	_assert(not sim.thaw_ground(far, Defs.THAW_GROUND_SECONDS * 0.5), "절반으로는 안 끝난다")
	_assert(not sim.can_lift(far), "절반에서는 여전히 못 든다")
	sim.cancel_thaw()
	_assert(sim.thaw_fraction() == 0.0, "손을 떼면 처음부터다")
	_assert(not sim.thaw_ground(far, Defs.THAW_GROUND_SECONDS * 0.9), "다시 시작한다")
	_assert(not sim.can_lift(far), "0.9초 모자라면 못 든다")

	_assert(sim.thaw_ground(far, Defs.THAW_GROUND_SECONDS), "이어서 채우면 끝난다")
	_assert(sim.can_lift(far), "녹은 자리는 들 수 있다")
	_assert(sim.pick_up_frozen(far), "실제로 들린다")

	# And it stays melted. Five seconds is work, and a reload or a walk back that
	# undid it would be a theft.
	sim.carried_frozen = false
	sim.frozen_cats[far] = 0.0
	sim.torch_lit = false
	_assert(sim.can_lift(far), "횃불이 꺼져도 녹인 자리는 녹은 채다")

	# A live cat asks exactly the same question, on a cell of its own.
	var other: Vector2i = far + Vector2i(3, 0)
	sim.torch_lit = true
	sim.grant_cats(1)
	sim.cats[0].pos = sim.cell_centre(other)
	_assert(sim.is_liftable(other), "고양이가 서 있는 칸은 들 수 있는 칸이다")
	_assert(not sim.pick_up_cat(other), "고양이도 녹이기 전에는 못 든다")
	_assert(sim.thaw_ground(other, Defs.THAW_GROUND_SECONDS), "녹인다")
	_assert(sim.pick_up_cat(other), "그러면 안긴다")
	sim.free()

## Melted ground survives a save, for the same reason it survives the torch
## going out.
func _test_before_the_fire() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	# `setup` leaves the core standing; the crash is what takes it away, and that
	# is the state the first minute is actually in.
	sim.begin_crash()
	_assert(not sim.base_placed, "아직 기지가 없다")
	# The rule is off until there is a fire. In the first minute there is no
	# reach and no crafting either, so a refusal then is a wall with no door.
	_assert(sim.can_touch(sim.core_cell + Vector2i(0, 30)),
		"기지가 서기 전에는 어디든 만질 수 있다")
	sim.carried_kit = Defs.KIT_BASE
	sim.place_base(sim.core_cell)
	_assert(not sim.can_touch(sim.core_cell + Vector2i(0, 30)),
		"불을 피우는 순간부터 규칙이 생긴다")
	sim.free()

func _test_the_cat_out_there() -> void:
	# The arrangement the whole idea rests on: something worth having, close
	# enough to see through the preview band, and out of reach.
	var seen := 0
	var reachable := 0
	for index in 40:
		var sim := Sim.new()
		sim.setup(3000 + index)
		sim.carried_kit = Defs.KIT_BASE
		sim.place_base(sim.core_cell)
		var nearest := 99.0
		for cell: Vector2i in sim.frozen_cats:
			nearest = minf(nearest, Vector2(cell - sim.core_cell).length())
		if nearest <= sim.warm_radius + ColdFog.PREVIEW_BAND:
			seen += 1
		if nearest <= sim.warm_radius:
			reachable += 1
		sim.free()
	_assert(seen >= 30, "거의 모든 회차에서 얼어붙은 고양이가 처음부터 보인다: %d/40" % seen)
	_assert(reachable <= 8, "그리고 대부분은 아직 닿지 않는다: 닿는 회차 %d/40" % reachable)
