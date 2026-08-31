extends SceneTree

## Drives the simulation directly, with no rendering, so the core loop is proven
## rather than assumed. Failures accumulate and the exit code is decided once.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_generation()
	_test_build_rules()
	_test_miner_to_core()
	_test_miner_rate()
	_test_belt_transport()
	_test_generator_burns_stone()
	_test_economy_and_warmth()
	_test_frost_throttle()
	_test_blocked_output_preserves_work()
	if failures == 0:
		print("SIM_TEST: PASS")
	quit(failures)

## Miners are inert without an operator, so any test about mining output has to
## staff the machine first.
func _staff(sim: Sim, cell: Vector2i) -> Sim.Cat:
	var cat := Sim.Cat.new()
	cat.assigned = cell
	cat.state = Defs.CAT_WORKING
	cat.pos = sim.cell_centre(cell)
	sim.cats.append(cat)
	return cat

## Most tests are about placement rules and machine behaviour, not about earning
## the tech tree, so this hands them an opened, funded base. The unlock and cost
## rules get their own explicit test.
func _fresh() -> Sim:
	var sim := Sim.new()
	sim.setup(12345)
	_open(sim)
	_power(sim)
	return sim

## A fuelled generator is the whole grid, for any test that needs one.
##
## The cell used to be hardcoded at (6, 6). Adding a heat stone band there turned
## the build into a refusal and the next line into a null dereference -- and the
## test kept going with a grid that had never been energised, still reporting
## PASS. A helper that quietly fails to set up what it promises is the fault this
## file already has a lesson about, so it looks for somewhere it can build and
## says so if it cannot.
func _power(sim: Sim) -> void:
	var cell := Vector2i(9999, 9999)
	for radius in range(4, 14):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				var candidate: Vector2i = sim.core_cell + Vector2i(x, y)
				if cell == Vector2i(9999, 9999) and sim.can_build(Defs.M_GENERATOR, candidate) == "":
					cell = candidate
		if cell != Vector2i(9999, 9999):
			break
	_assert(cell != Vector2i(9999, 9999), "발전기를 세울 자리가 있다")
	_assert(sim.build(Defs.M_GENERATOR, cell, Vector2i.RIGHT), "발전기가 섰다")
	sim.machine_at(cell).buffer[Defs.ITEM_HEATSTONE] = 4

func _open(sim: Sim) -> void:
	sim.note_resource_seen(Defs.ITEM_HEATSTONE)
	# The miner is opened by holding the build gun with stone to pay for one,
	# not by having seen a stone. These tests want it standing.
	sim.unlocked[Defs.M_MINER] = true
	sim.note_resource_seen(Defs.ITEM_COPPER)
	# The generator waits for two materials, so a setup that wants one standing
	# has to hand over both. Copper alone leaves it locked, which is the point.
	sim.note_resource_seen(Defs.ITEM_CORE_PART)
	sim.stock[Defs.ITEM_CRYSTAL] = 500
	sim.stock[Defs.ITEM_HEATSTONE] = 500
	sim.stock[Defs.ITEM_COPPER] = 500

func _test_generation() -> void:
	var sim := _fresh()
	var frost := 0
	var copper := 0
	for cell: Vector2i in sim.ore:
		if sim.ore[cell] == Defs.ITEM_HEATSTONE:
			frost += 1
		else:
			copper += 1
	# Scarcity is the point, but it is scarcity *per band*, not in total: heat
	# stone runs in one small band per step of the base ladder, so the world-wide
	# count is the sum of eight of them. This assertion used to cap it at 20,
	# which was the old single-ring world -- where every seam sat inside the
	# opening circle and no upgrade reached another one.
	_assert(frost >= 6, "frost ore exists in workable but scarce amounts")
	_assert(copper >= 6, "copper ore exists in workable but scarce amounts")
	# Derived from the table rather than written down. The cap was 60 when the
	# ladder stopped at 22 tiles; the ceiling is 100 now and the bands that fill
	# it took the world-wide total past it, which is the table growing and not
	# the density changing. What is worth holding is that no band overfills.
	var budget := 0
	for band: Dictionary in Defs.HEATSTONE_BANDS:
		budget += int(band["patches"]) * int(band["size"])
	_assert(frost <= budget + Defs.STARTER_PATCH_SIZE,
		"열석은 대역에 적힌 양을 넘지 않는다: %d개 (예산 %d)" % [frost, budget])
	_assert(copper < 20, "ore density stays scarce after the reduction")
	# And the opening stays a small field. It is the density near the fire that
	# decides whether finding a seam is an event.
	var near := 0
	for cell: Vector2i in sim.ore:
		if Vector2(cell - sim.core_cell).length() <= Defs.WARM_BASE:
			near += 1
	_assert(near < 14, "시작 반경 안은 여전히 성깁니다: %d개" % near)
	_assert(not sim.ore.has(sim.core_cell), "ore never spawns under the core")

	# Heat stone must be reachable at the opening radius or the first minutes
	# stall. It is what the opening is made of now -- hand-mined and burnt
	# straight in the core -- and crystal, which used to be here, has moved out
	# to the middle of the game.
	var reachable := 0
	var early_crystal := 0
	for cell: Vector2i in sim.ore:
		var distance: float = Vector2(cell).length()
		if sim.ore[cell] == Defs.ITEM_HEATSTONE and distance <= Defs.WARM_BASE:
			reachable += 1
		if sim.ore[cell] == Defs.ITEM_CRYSTAL:
			early_crystal += 1
	_assert(reachable > 0, "some heat stone sits inside the starting warm radius")
	_assert(early_crystal == 0, "and there is no crystal seam anywhere -- it is not a seam")
	# What crystal is instead: a fixed number of pieces lying in the snow, all of
	# them outside the opening circle, and no way to make another.
	_assert(sim.shards.size() == Defs.CRYSTAL_SHARDS,
		"crystal exists as %d loose shards" % Defs.CRYSTAL_SHARDS)
	var near_shard := 0
	for cell: Vector2i in sim.shards:
		if Vector2(cell - sim.core_cell).length() < Defs.CRYSTAL_RING.x:
			near_shard += 1
	_assert(near_shard == 0, "and none of them inside the opening")

	# Ember must NOT be reachable at the start, or the progression has no arc.
	var early_copper := 0
	for cell: Vector2i in sim.ore:
		if sim.ore[cell] == Defs.ITEM_COPPER and Vector2(cell).length() <= Defs.WARM_BASE:
			early_copper += 1
	_assert(early_copper == 0, "copper ore starts outside the warm radius")

	# The opening must be identical every run: a patch south of the core plus a
	# clear two-tile lane to belt through. Otherwise the first minute is a search.
	for offset: Vector2i in Sim.STARTER_PATCH:
		_assert(sim.ore.get(sim.core_cell + offset, -1) == Defs.ITEM_HEATSTONE,
			"guaranteed starter ore exists at %s" % offset)
	for offset: Vector2i in Sim.STARTER_LANE:
		_assert(not sim.ore.has(sim.core_cell + offset),
			"the belt lane home stays clear at %s" % offset)
		_assert(sim.can_build(Defs.M_BELT, sim.core_cell + offset) == "",
			"a belt can always be placed in the starter lane at %s" % offset)

	# A guaranteed seam due north with a clear column home, so the opening never
	# depends on the scatter being kind. It has been copper and then crystal; it
	# is whatever the beat it protects actually needs, and that beat is now the
	# first minutes.
	for offset: Vector2i in Sim.STARTER_COPPER:
		_assert(sim.ore.get(sim.core_cell + offset, -1) == Defs.ITEM_HEATSTONE,
			"guaranteed seam exists at %s" % offset)
	for step in range(1, 9):
		var lane_cell: Vector2i = sim.core_cell + Vector2i(1, -step)
		_assert(sim.can_build(Defs.M_BELT, lane_cell) == "",
			"the copper column home is clear at %s" % lane_cell)
	_assert(Vector2(Sim.STARTER_COPPER[0]).length() > Defs.WARM_BASE,
		"the copper seam starts outside the opening warm radius, so it must be earned")
	_assert(Vector2(Sim.STARTER_COPPER[0]).length() < Defs.WARM_MAX,
		"the copper seam is reachable within a single run")
	sim.free()

	# The opening is deterministic across different world seeds.
	var other := Sim.new()
	other.setup(90210)
	for offset: Vector2i in Sim.STARTER_PATCH:
		_assert(other.ore.get(other.core_cell + offset, -1) == Defs.ITEM_HEATSTONE,
			"the starter patch does not depend on the run seed")
	other.free()

func _test_build_rules() -> void:
	var sim := Sim.new()
	sim.setup(12345)
	var ore_cell: Vector2i = sim.ore.keys()[0]
	var empty := Vector2i(2, 0)

	# Nothing is buildable until the matching resource has been held once. The
	# hotbar is the tech tree, so it starts closed.
	_assert(not sim.is_unlocked(Defs.M_MINER), "the miner starts locked")
	_assert(sim.can_build(Defs.M_MINER, ore_cell) != "", "and cannot be built while locked")
	sim.note_resource_seen(Defs.ITEM_HEATSTONE)
	# The miner is opened by holding the build gun with stone to pay for one,
	# not by having seen a stone. These tests want it standing.
	sim.unlocked[Defs.M_MINER] = true
	# Copper opens the transport line. Power waits for a core part as well, so
	# it arrives with the wreck rather than with the first seam.
	sim.note_resource_seen(Defs.ITEM_COPPER)
	_assert(sim.is_unlocked(Defs.M_MINER), "the miner is open")
	_assert(sim.is_unlocked(Defs.M_BELT), "and copper opens the belt")
	_assert(sim.is_unlocked(Defs.M_SPLITTER), "and the splitter with it")
	_assert(not sim.is_unlocked(Defs.M_GENERATOR),
		"but not the generator -- one of its two materials is still missing")
	# Whichever of the two lands last is the one that opens it, which is why the
	# condition is asked of the run rather than matched against the arrival.
	_assert(sim.note_resource_seen(Defs.ITEM_CORE_PART).has(Defs.M_GENERATOR),
		"the core part opens the generator, and says so once")
	_assert(sim.note_resource_seen(Defs.ITEM_CORE_PART).is_empty(),
		"and a second one opens nothing")

	# Machines are bought with materials out of the base stock.
	sim.stock[Defs.ITEM_CRYSTAL] = 100
	sim.stock[Defs.ITEM_HEATSTONE] = 100
	sim.stock[Defs.ITEM_COPPER] = 100
	_assert(sim.can_build(Defs.M_MINER, ore_cell) == "", "a miner may be placed on ore")
	_assert(sim.can_build(Defs.M_BELT, ore_cell) != "", "a belt may not be placed on ore")
	_assert(sim.can_build(Defs.M_MINER, empty) != "", "a miner may not be placed off ore")
	_assert(sim.can_build(Defs.M_BELT, empty) == "", "a belt may be placed on bare ground")
	_assert(sim.can_build(Defs.M_BELT, sim.core_cell) != "", "nothing may overwrite the core")

	var cost: int = int(Defs.MACHINE_COSTS[Defs.M_BELT][Defs.ITEM_COPPER])
	var before: int = int(sim.stock[Defs.ITEM_COPPER])
	var burnt_before: int = sim.stones_in
	_assert(sim.build(Defs.M_BELT, empty, Vector2i.RIGHT), "building a belt succeeds")
	_assert(int(sim.stock[Defs.ITEM_COPPER]) == before - cost, "building spends materials")
	_assert(sim.stones_in == burnt_before, "and never touches the circle")
	_assert(not sim.build(Defs.M_BELT, empty, Vector2i.RIGHT), "a filled cell rejects a second build")
	_assert(sim.demolish(empty), "a placed machine can be reclaimed")
	_assert(int(sim.stock[Defs.ITEM_COPPER]) > before - cost, "reclaiming refunds part of the cost")
	_assert(not sim.demolish(sim.core_cell), "the core can never be demolished")

	sim.stock[Defs.ITEM_CRYSTAL] = 0
	sim.stock[Defs.ITEM_HEATSTONE] = 0
	sim.stock[Defs.ITEM_COPPER] = 0
	_assert(sim.can_build(Defs.M_GENERATOR, empty) != "", "an unaffordable machine is rejected")
	sim.free()

func _test_miner_to_core() -> void:
	# Miner directly adjacent to the core, pointing at it.
	var sim := Sim.new()
	sim.setup(999)
	var cell := Vector2i(-1, 0)
	sim.ore[cell] = Defs.ITEM_CRYSTAL
	_open(sim)
	_power(sim)
	_assert(sim.build(Defs.M_MINER, cell, Vector2i.RIGHT), "miner placed next to the core")
	_staff(sim, cell)
	var before: int = int(sim.stock[Defs.ITEM_CRYSTAL])
	for step in 200:
		sim.tick(0.1)     # comfortably longer than one mining period
	_assert(int(sim.stock[Defs.ITEM_CRYSTAL]) > before, "a miner pointed at the core banks material")
	_assert(sim.delivered[Defs.ITEM_CRYSTAL] > 0, "delivered crystal is counted")
	sim.free()

func _test_miner_rate() -> void:
	# One cat is deliberately a trickle; the number is load-bearing for balance.
	var sim := Sim.new()
	sim.setup(555)
	_open(sim)
	_power(sim)
	var cell := Vector2i(-1, 0)
	sim.ore[cell] = Defs.ITEM_CRYSTAL
	sim.build(Defs.M_MINER, cell, Vector2i.RIGHT)
	_staff(sim, cell)
	# Derived from the constant, like the wait below it. Fifty ticks used to be
	# "less than the period"; the miner is twice as fast now and five seconds is
	# past it, so the assertion would have been testing the opposite thing.
	for step in int(Defs.MINER_PERIOD / 0.1) - 4:
		sim.tick(0.1)
	_assert(sim.delivered[Defs.ITEM_CRYSTAL] == 0, "a miner produces nothing before its period")
	# Just past it, counting from where the loop above stopped rather than from
	# zero. Both numbers come off the constant: the first version added a whole
	# period to a hardcoded five seconds, which was under the old period and over
	# the new one, so halving the period turned "one ore" into two.
	for step in 8:
		sim.tick(0.1)
	_assert(sim.delivered[Defs.ITEM_CRYSTAL] == 1, "a miner delivers its first ore just after its period")
	sim.free()

func _test_belt_transport() -> void:
	var sim := Sim.new()
	sim.setup(4242)
	_open(sim)
	_power(sim)
	# miner at (-3,0) -> belts at (-2,0) and (-1,0) -> core at (0,0)
	sim.ore[Vector2i(-3, 0)] = Defs.ITEM_CRYSTAL
	_assert(sim.build(Defs.M_MINER, Vector2i(-3, 0), Vector2i.RIGHT), "miner built")
	_staff(sim, Vector2i(-3, 0))
	_assert(sim.build(Defs.M_BELT, Vector2i(-2, 0), Vector2i.RIGHT), "first belt built")
	_assert(sim.build(Defs.M_BELT, Vector2i(-1, 0), Vector2i.RIGHT), "second belt built")
	# Derived from the constants rather than a fixed count: mining one item, then
	# walking it two tiles, both got an order of magnitude slower at different
	# times, and a hardcoded 120 ticks silently stopped covering the journey.
	var journey: float = Defs.MINER_PERIOD + 2.0 / Defs.BELT_SPEED + 2.0
	var saw_item := false
	for step in int(journey / 0.1):
		sim.tick(0.1)
		if sim.items_in_transit() > 0:
			saw_item = true
	_assert(saw_item, "items visibly occupy the belt while travelling")
	_assert(sim.delivered[Defs.ITEM_CRYSTAL] > 0, "a two-tile belt run reaches the core")
	sim.free()

## The generator, which is what the exchanger's rules moved to when it was
## removed in 1.0.8: it ate crystal straight off a belt instead of eating a
## material a second building made out of crystal. Since 1.0.27 it eats heat
## stone, because crystal is no longer in the world at all.
func _test_generator_burns_stone() -> void:
	var sim := Sim.new()
	sim.setup(777)
	_open(sim)
	var gen_cell := Vector2i(-2, 0)
	_assert(sim.build(Defs.M_GENERATOR, gen_cell, Vector2i.RIGHT), "generator built")
	var gen: Sim.Machine = sim.machine_at(gen_cell)
	gen.buffer.clear()
	for step in 40:
		sim.tick(0.1)
	_assert(is_equal_approx(sim.power_capacity, 0.0), "빈 발전기는 전력을 내지 않는다")
	_assert(sim.meter_status(gen).find("연료 없음") >= 0, "그리고 그렇게 말한다")

	# Heat stone from any face, and nothing else. The output-face rule is kept
	# even though this machine emits nothing: it costs nothing to keep and
	# something to remember on the day it does.
	var side_cell: Vector2i = gen_cell + Vector2i.UP
	_assert(sim._push_into(gen_cell, Defs.ITEM_HEATSTONE, side_cell),
		"열석을 받는다")
	_assert(not sim._push_into(gen_cell, Defs.ITEM_COPPER, side_cell),
		"구리는 받지 않는다")
	_assert(not sim._push_into(gen_cell, Defs.ITEM_CRYSTAL, side_cell),
		"수정조각은 더 이상 받지 않는다")

	gen.buffer[Defs.ITEM_HEATSTONE] = 4
	var before: int = int(gen.buffer[Defs.ITEM_HEATSTONE])
	for step in 200:
		sim.tick(0.1)
	_assert(int(gen.buffer[Defs.ITEM_HEATSTONE]) < before, "돌리면 열석을 태운다")
	_assert(sim.power_capacity > 0.0, "그리고 전력이 생긴다")

	# Every place that names the fuel has to name the same one. Five of them read
	# `GENERATOR_FUEL` and cannot drift; the build-list hint is a written
	# sentence and can, so it is compared here rather than trusted. The day the
	# fuel changed, the count that decides capacity kept answering about crystal
	# and the machine burned stone while supplying nothing.
	var fuel_name: String = String(Defs.ITEM_NAMES[Defs.GENERATOR_FUEL])
	_assert(String(Defs.MACHINE_HINTS[Defs.M_GENERATOR]).find(fuel_name) >= 0,
		"건설 목록의 설명이 실제 연료를 말한다")
	_assert(Defs.throughput_line(Defs.M_GENERATOR).find(fuel_name) >= 0,
		"처리량 줄도 같은 연료를 말한다")
	var io_text := ""
	for line: String in Defs.machine_io(Defs.M_GENERATOR):
		io_text += line
	_assert(io_text.find(fuel_name) >= 0, "입력 줄도 같은 연료를 말한다")
	sim.free()

func _test_economy_and_warmth() -> void:
	var sim := _fresh()
	var start_radius: float = sim.warm_radius
	sim.stones_in = 0
	# A delivery banks the material and nothing else. It used to credit heat as
	# well as stock -- the same crystal twice, once on arrival and again when the
	# player fed the stores to the fire -- and the circle grew while she was
	# somewhere else. `test_fire` holds the whole rule; this is the arithmetic.
	sim._deliver(Defs.ITEM_CRYSTAL, sim.core_cell)
	_assert(sim.stones_in == 0, "delivery does not feed the fire")
	_assert(int(sim.stock.get(Defs.ITEM_CRYSTAL, 0)) > 0, "it banks the crystal instead")
	for step in 400:
		sim._deliver(Defs.ITEM_CRYSTAL, sim.core_cell)
	sim.tick(0.016)
	_assert(is_equal_approx(sim.warm_radius, start_radius),
		"and four hundred of them do not move the circle")
	# Energy crystals are not fuel any more, so four hundred of them cannot move
	# the circle at all. Only stones can.
	sim.stock[Defs.ITEM_HEATSTONE] = 0
	_assert(sim.deposit_fuel().is_empty(), "and they cannot be fed to it either")
	sim.stock[Defs.ITEM_HEATSTONE] = int(Defs.BASE_LEVELS[-1]["stones"])
	sim.deposit_fuel()
	sim.tick(0.016)
	_assert(sim.warm_radius > start_radius, "feeding stones to the fire does")
	_assert(sim.warm_radius <= Defs.WARM_MAX, "the warm radius is capped")

	# The circle only ever grows. Nothing spends what it is made of any more --
	# there is no balance to spend, only stones already burnt -- which is why
	# blacking out no longer takes a quarter of anything.
	var radius_before: float = sim.warm_radius
	for step in 60:
		sim.tick(0.016)
	_assert(is_equal_approx(sim.warm_radius, radius_before), "and it never shrinks again")
	sim.free()

func _test_frost_throttle() -> void:
	# Identical belts, one inside the warm radius and one far outside it. After
	# the same elapsed time the frozen belt must have carried its item less far.
	var sim := Sim.new()
	sim.setup(31337)
	_open(sim)
	_power(sim)
	var warm_cell := Vector2i(2, 0)
	var cold_cell := Vector2i(int(Defs.WARM_MAX) + 8, 0)
	_assert(sim.is_warm(warm_cell), "the warm test cell is inside the radius")
	_assert(not sim.is_warm(cold_cell), "the cold test cell is outside the radius")
	_assert(sim.build(Defs.M_BELT, warm_cell, Vector2i.UP), "warm belt built")
	_assert(sim.build(Defs.M_BELT, cold_cell, Vector2i.UP), "cold belt built")

	var warm_belt: Sim.Machine = sim.machine_at(warm_cell)
	var cold_belt: Sim.Machine = sim.machine_at(cold_cell)
	# Facing UP into empty ground, so neither can hand its item off and both
	# simply accumulate travel along their own tile.
	warm_belt.items.append({"type": Defs.ITEM_CRYSTAL, "t": 0.0})
	cold_belt.items.append({"type": Defs.ITEM_CRYSTAL, "t": 0.0})
	for step in 3:
		sim.tick(0.05)
	var warm_t: float = float(warm_belt.items[0]["t"])
	var cold_t: float = float(cold_belt.items[0]["t"])
	_assert(warm_t > cold_t, "a frozen belt moves items more slowly than a warm one")
	_assert(cold_t > 0.0, "a frozen machine still runs rather than stopping dead")
	_assert(cold_t < warm_t * 0.8, "the frost penalty is large enough for the player to feel")
	sim.free()

func _test_blocked_output_preserves_work() -> void:
	var sim := Sim.new()
	sim.setup(2468)
	_open(sim)
	_power(sim)
	# Miner facing empty ground: nothing accepts its output. Kept inside the warm
	# radius so the frost throttle is not a second variable in this test.
	var cell := Vector2i(3, 3)
	sim.ore[cell] = Defs.ITEM_CRYSTAL
	# The output tile is ore as well, so there is nowhere to push and nowhere to
	# drop: a miner only stalls once the floor in front of it is unavailable too.
	sim.ore[cell + Vector2i.RIGHT] = Defs.ITEM_CRYSTAL
	sim.build(Defs.M_MINER, cell, Vector2i.RIGHT)
	_staff(sim, cell)
	var machine: Sim.Machine = sim.machine_at(cell)
	for step in 200:
		sim.tick(0.1)
	_assert(is_equal_approx(machine.progress, Defs.MINER_PERIOD),
		"a blocked miner holds its finished item instead of discarding it")
	_assert(sim.delivered[Defs.ITEM_CRYSTAL] == 0, "a blocked miner delivers nothing")
	_assert(machine.stalled, "a blocked miner reports itself stalled so the player can see it")

	# Give it somewhere to send the ore and the warning must clear on its own.
	# The blocking ore has to go first: a belt may not sit on a seam.
	sim.ore.erase(cell + Vector2i.RIGHT)
	sim.build(Defs.M_BELT, cell + Vector2i.RIGHT, Vector2i.RIGHT)
	for step in 40:
		sim.tick(0.1)
	_assert(not machine.stalled, "the stall warning clears once the output is unblocked")

	# A belt whose head has nowhere to go pours onto the ground in front of it.
	# It used to stop dead at the last tile, so a belt built before the thing it
	# was going to feed did nothing and gave no sign why.
	var dead_end := Vector2i(20, 20)
	sim.build(Defs.M_BELT, dead_end, Vector2i.RIGHT)
	var belt: Sim.Machine = sim.machine_at(dead_end)
	for index in Defs.BELT_CAPACITY:
		belt.items.append({"type": Defs.ITEM_CRYSTAL, "t": 1.0})
	sim.tick(0.2)
	_assert(not belt.stalled, "끝이 열린 벨트는 앞에 쏟아낸다")
	_assert(sim.ground.has(dead_end + Vector2i.RIGHT), "그 칸에 자원이 놓인다")
	# And it does back up once the heap in front is full, which is the state the
	# stall flag is actually for.
	sim.ground_stack[dead_end + Vector2i.RIGHT] = sim.GROUND_STACK_MAX
	# Spaced the way the mover leaves them, so the head really is at the end of
	# the tile. Filling them all at 1.0 does not survive one tick: the spacing
	# rule pulls each item back behind the one ahead of it, and the new head then
	# sits mid-tile with nothing to push.
	belt.items.clear()
	for index in Defs.BELT_CAPACITY:
		belt.items.append({"type": Defs.ITEM_CRYSTAL, "t": 1.0 - float(index) * 0.34})
	sim.tick(0.2)
	_assert(belt.stalled, "쌓을 자리까지 차면 그때 막힌다")
	sim.free()

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("SIM_TEST: FAIL - " + message)
		failures += 1
