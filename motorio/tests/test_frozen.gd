extends SceneTree

## Cats are found, not bought. This holds the whole rescue: what the map puts
## out there, what carrying one costs, where it has to be put down, and that the
## ice actually turns into an animal.
##
## The crates this replaced were collected by walking over them and spent three
## for one at the shelter door. Nothing of that shape is left, so nothing of the
## old test is either -- what is kept is the arithmetic that made the swap fair:
## one frozen cat where three crates used to be, at a third of the density, so a
## map still supports the same number of workers.

var failures := 0
var main: Node2D = null

func _init() -> void:
	# Main, because Grim only exists inside it: her sprite is a child node in
	# Main.tscn and PlayerActor.new() has no Character to flip.
	main = load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_run()
	main.finish_tutorial()
	_run()

func _run() -> void:
	_test_scatter()
	_test_carry()
	_test_thaw_needs_the_base()
	_test_thaw_wakes_a_cat()
	_test_stages()
	_test_sheet()
	_test_carrying_halves_her_speed()
	if failures == 0:
		print("PASS test_frozen")
	else:
		print("FAIL test_frozen (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _sim(seed_value: int = 1234) -> Sim:
	var sim := Sim.new()
	sim.setup(seed_value)
	return sim

# --- What the map holds ----------------------------------------------------

func _test_scatter() -> void:
	# Many seeds, not one. "This cell is always clear" and "this many always
	# exist" are the two claims a seeded world breaks one run in five, and a
	# single seed is how that goes unnoticed until a player reports it.
	# Not inside the opening circle -- just outside it. The first frozen cat has
	# to be invisible at the seven tiles the base opens with and visible at the
	# nine the third mission takes it to, so that finishing that mission is the
	# moment one appears in ground that was white a second ago. The warm radius
	# growing used to be a number changing in a corner.
	var thin := 0
	var early := 0
	for seed_value in range(200):
		var sim := _sim(seed_value)
		var reachable := 0
		for cell: Vector2i in sim.frozen_cats:
			var distance: float = Vector2(cell - sim.core_cell).length()
			if distance <= Defs.WARM_BASE:
				early += 1
			if distance <= Defs.OPENING_WARM_RADIUS:
				reachable += 1
		if reachable < Defs.STARTER_FROZEN:
			thin += 1
		sim.free()
	_assert(early == 0, "시작 반경 7칸 안에는 한 마리도 없다 (%d마리)" % early)
	_assert(thin == 0, "모든 시드에서 9칸 안에는 있다 (실패 %d)" % thin)

	var sim := _sim()
	_assert(sim.frozen_cats.size() > Defs.STARTER_FROZEN * 3,
		"바깥에도 흩어져 있다 — 더 걷는 것이 일꾼을 산다 (%d개)" % sim.frozen_cats.size())
	# The swap has to be neutral. Three crates made one cat; one frozen cat makes
	# one cat; so the map must hold a third as many of them as it held crates,
	# and the number of cats a run can reach is unchanged.
	var reach: float = Defs.WARM_MAX + 8.0
	var expected: int = int((PI * reach * reach) / Defs.FROZEN_PER_TILES) + Defs.STARTER_FROZEN
	# 냥마을's seven are placed rather than scattered, so they are counted out of
	# a claim about density: the village is a destination with a fixed number of
	# cats in it, and adding it must not read here as the plateau having got
	# richer.
	var scattered := 0
	for cell: Vector2i in sim.frozen_cats:
		if not sim.in_village(cell):
			scattered += 1
	_assert(absi(scattered - expected) <= 2,
		"밀도가 설계값과 맞는다 (%d, 기대 %d)" % [scattered, expected])
	_assert(sim.frozen_cats.size() - scattered == Defs.VILLAGE_FROZEN.size(),
		"그리고 마을 몫은 따로 %d마리" % Defs.VILLAGE_FROZEN.size())
	_assert(is_equal_approx(Defs.FROZEN_PER_TILES, 66.7 * 3.0),
		"상자 밀도의 1/3 — 한 마리가 상자 3개를 대신하므로 총 고양이 수는 그대로")
	for cell: Vector2i in sim.frozen_cats:
		_assert(not sim.ore.has(cell), "광맥 위에는 놓이지 않는다")
		break
	sim.free()

# --- Carrying one ----------------------------------------------------------

func _test_carry() -> void:
	var sim := _sim()
	# Inside the fire. Outside it everything is frozen into the ground, and every
	# frozen cat the world lays down is outside it -- the nearest sits 8.6 tiles
	# out against a reach of 7, which is the whole point of where they are put.
	# Reaching one is the player's problem; carrying one is what this file is
	# about, so the subject is moved to where the rule allows it.
	var cell: Vector2i = sim.core_cell + Vector2i(2, 0)
	sim.frozen_cats.clear()
	sim.frozen_cats[cell] = 0.0

	_assert(not sim.pick_up_frozen(cell + Vector2i(500, 500)), "빈 칸에서는 아무것도 안 든다")
	_assert(sim.pick_up_frozen(cell), "Z 로 얼어붙은 고양이를 든다")
	_assert(not sim.frozen_cats.has(cell), "든 자리에서는 사라진다")
	_assert(sim.carried_frozen, "안고 있는 상태가 된다")
	# A second one, also within reach, so the refusal below is about her arms
	# being full rather than about the fire not getting that far.
	var second: Vector2i = sim.core_cell + Vector2i(-2, 0)
	sim.frozen_cats[second] = 0.0
	_assert(not sim.pick_up_frozen(second), "두 마리는 못 든다")

	# The live-cat verb has to refuse too, or Z on a crowded tile would leave her
	# holding both and the renderer drawing one on top of the other.
	sim.grant_cats(1)
	sim.cats[0].pos = sim.cell_centre(sim.core_cell + Vector2i(3, 3))
	_assert(not sim.pick_up_cat(sim.core_cell + Vector2i(3, 3)),
		"얼음을 안고 있으면 살아있는 고양이는 못 든다")

	var here: Vector2i = sim.core_cell + Vector2i(1, 0)
	_assert(not sim.put_down_frozen(sim.core_cell), "기지 위에는 못 놓는다")
	_assert(sim.put_down_frozen(here), "빈 칸에 놓는다")
	_assert(sim.frozen_cats.has(here) and not sim.carried_frozen, "놓은 자리에 남는다")
	_assert(not sim.put_down_frozen(here), "안고 있지 않으면 놓을 것도 없다")

	sim.carried_frozen = true
	_assert(not sim.put_down_frozen(here), "이미 있는 칸에는 겹쳐 놓지 않는다")
	sim.free()

# --- Where it thaws --------------------------------------------------------

func _test_thaw_needs_the_base() -> void:
	var sim := _sim()
	sim.frozen_cats.clear()
	sim.cats.clear()
	var far: Vector2i = sim.core_cell + Vector2i(int(Defs.THAW_RADIUS) + 1, 0)
	var near: Vector2i = sim.core_cell + Vector2i(int(Defs.THAW_RADIUS), 0)
	sim.frozen_cats[far] = 0.0
	sim.frozen_cats[near] = 0.0
	_assert(not sim.can_thaw(far), "기지에서 %d칸 밖은 녹지 않는다" % (int(Defs.THAW_RADIUS) + 1))
	_assert(sim.can_thaw(near), "%d칸 안이면 녹는다" % int(Defs.THAW_RADIUS))
	# Ticked in steps, the way the game runs it, rather than in one big delta:
	# the check that matters is that the far one never moves at all, and a single
	# huge tick would hide a per-frame guard that only holds for small ones.
	for _step in 60:
		sim.tick(0.1)
	_assert(is_equal_approx(float(sim.frozen_cats.get(far, -1.0)), 0.0),
		"눈밭에 둔 고양이는 6초가 지나도 그대로다")
	_assert(float(sim.frozen_cats.get(near, 0.0)) > 0.4,
		"기지 옆의 고양이는 녹고 있다 (%.2f)" % float(sim.frozen_cats.get(near, 0.0)))
	# Picked up half-melted and put down again: the progress is the cat's, not
	# the tile's, so carrying it across the base must not put the ice back.
	var half: float = float(sim.frozen_cats[near])
	_assert(sim.pick_up_frozen(near), "녹는 중인 고양이도 다시 들 수 있다")
	_assert(sim.put_down_frozen(sim.core_cell + Vector2i(0, -1)), "옆 칸에 다시 놓는다")
	_assert(is_equal_approx(float(sim.frozen_cats[sim.core_cell + Vector2i(0, -1)]), half),
		"옮겨도 녹은 만큼은 그대로다 (%.2f)" % half)
	sim.free()

func _test_thaw_wakes_a_cat() -> void:
	var sim := _sim()
	sim.frozen_cats.clear()
	sim.cats.clear()
	var here: Vector2i = sim.core_cell + Vector2i(0, 2)
	sim.frozen_cats[here] = 0.0
	var seen: Array[int] = []
	var woke_at: Array[Vector2] = []
	sim.cat_thawed.connect(func(total: int, at: Vector2) -> void:
		seen.append(total)
		woke_at.append(at))
	var elapsed: float = 0.0
	while sim.cats.is_empty() and elapsed < Defs.THAW_SECONDS * 3.0:
		sim.tick(0.1)
		elapsed += 0.1
	_assert(sim.cats.size() == 1, "얼음이 녹으면 고양이가 된다")
	_assert(absf(elapsed - Defs.THAW_SECONDS) < 0.5,
		"설계한 시간 안에 (%.1f초, 기대 %.1f초)" % [elapsed, Defs.THAW_SECONDS])
	_assert(sim.frozen_cats.is_empty(), "얼음은 세계에서 사라진다")
	_assert(seen.size() == 1 and seen[0] == 1, "신호가 정확히 한 번, 총 마릿수와 함께 온다")
	_assert(woke_at.size() == 1 and woke_at[0].distance_to(sim.cell_centre(here)) < 1.0,
		"놓아둔 그 자리에서 깨어난다 — 숙소 문앞이 아니라")
	_assert(sim.cats[0].rarity == Defs.RARITY_O, "구조한 고양이는 O 등급")
	_assert(not sim.cats[0].has_job(), "일은 플레이어가 시킨다")
	sim.free()

# --- The four pictures -----------------------------------------------------

func _test_stages() -> void:
	_assert(Sim.frozen_stage(0.0) == 0, "시작은 가장 언 그림")
	_assert(Sim.frozen_stage(0.99) == Defs.FROZEN_STAGES - 1, "끝은 가장 녹은 그림")
	_assert(Sim.frozen_stage(1.5) == Defs.FROZEN_STAGES - 1, "범위를 넘어도 마지막에서 멈춘다")
	_assert(Sim.frozen_stage(-1.0) == 0, "음수도 첫 그림")
	var previous: int = -1
	for step in 100:
		var stage: int = Sim.frozen_stage(float(step) / 100.0)
		if stage < previous:
			_assert(false, "단계는 되돌아가지 않는다")
			return
		previous = stage
	_assert(previous == Defs.FROZEN_STAGES - 1, "네 단계를 모두 지난다")

func _test_sheet() -> void:
	var sheet: Texture2D = MachineLayer.CAT_FREEZE_SHEET
	_assert(sheet != null, "시트가 로드된다")
	_assert(int(sheet.get_height()) == int(MachineLayer.CAT_CELL),
		"셀 높이가 다른 시트와 같다 (%d)" % int(sheet.get_height()))
	_assert(int(sheet.get_width()) == int(MachineLayer.CAT_CELL) * Defs.FROZEN_STAGES,
		"단계 수만큼의 셀이 들어 있다 (%d)" % int(sheet.get_width()))

# --- What it costs to carry ------------------------------------------------

func _test_carrying_halves_her_speed() -> void:
	# Measured by walking her, not by reading the multiplier back. A constant
	# compared against itself proves only that the file is consistent with
	# itself; what matters is how far she actually gets.
	var free_distance: float = _walk(false, false)
	var run_distance: float = _walk(false, true)
	var load_distance: float = _walk(true, false)
	var load_run: float = _walk(true, true)
	_assert(run_distance > free_distance * 1.3, "평소에는 달릴 수 있다")
	var ratio: float = load_distance / maxf(free_distance, 0.001)
	_assert(absf(ratio - Defs.FROZEN_CARRY_SPEED) < 0.05,
		"안고 있으면 절반 속도 (%.2f배)" % ratio)
	_assert(absf(load_run - load_distance) < 1.0,
		"안고 있으면 달리기 키를 눌러도 빨라지지 않는다 (%.1f vs %.1f)"
			% [load_run, load_distance])

## One walk, straight east, from a standstill. Driven through touch_direction
## because that is the one input path a headless test can actually hold down.
##
## Ticked by hand with the engine's own processing switched off, and with no
## `await` in the loop, so exactly one thing is advancing her -- the repository
## has a lesson about a three second animation measuring 2.45 because the engine
## was ticking the same timer alongside the test.
##
## Collision is switched off for the measurement. What is being measured is how
## fast she moves, and a seam five tiles east would otherwise turn a speed test
## into a terrain test that passes or fails with the seed.
func _walk(carrying: bool, sprint: bool) -> float:
	var player: PlayerActor = main.player
	var was_blocked: Callable = player.blocked
	player.set_physics_process(false)
	player.blocked = func(_cell: Vector2i) -> bool: return false
	player.position = Vector2.ZERO
	player.velocity = Vector2.ZERO
	player.warmth = 100.0
	player.locked = false
	player.modal = false
	player.carrying_frozen = carrying
	player.touch_direction = Vector2.RIGHT
	player.touch_sprint = sprint
	for _step in 120:
		player._physics_process(1.0 / 60.0)
	var distance: float = player.position.x
	player.touch_direction = Vector2.ZERO
	player.touch_sprint = false
	player.carrying_frozen = false
	player.blocked = was_blocked
	player.set_physics_process(true)
	return distance
