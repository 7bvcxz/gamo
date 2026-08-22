extends SceneTree

## Z acts on the cell she is facing, and on no other.
##
## Both of the things it can pick up used to be found by searching a circle
## around the target -- 0.9 of a tile for a cat, a tile and a half for the prompt
## that offers the verb. A cat is a body moving between cells rather than a thing
## sitting in one, so a cat walking diagonally past came inside that circle and
## was scooped up instead of whatever she was actually looking at. The player
## sees a cat on the diagonal and a seam in front, presses Z, and gets the cat.
##
## The kit is the one exception and it is deliberate: there is exactly one of it
## in the world, nothing within three tiles it could be confused with, and
## requiring the correct facing there once cost a browser run that walked to the
## case, held Z and watched nothing happen because the last arrow was Down.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_cats_are_on_a_cell()
	_test_the_facing_cell_only()
	await _test_the_prompt_agrees()
	await _test_ice_outranks_the_pickaxe()
	if failures == 0:
		print("REACH: PASS")
	else:
		print("REACH: FAIL (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _world() -> Sim:
	var sim := Sim.new()
	sim.setup(4242)
	sim.frozen_cats.clear()
	sim.debris.clear()
	return sim

func _test_cats_are_on_a_cell() -> void:
	var sim := _world()
	sim.grant_cats(1)
	var here: Vector2i = sim.core_cell + Vector2i(3, 3)
	var cat: Sim.Cat = sim.cats[0]
	cat.pos = sim.cell_centre(here)
	_assert(sim.cat_on(here) == cat, "선 칸에서는 찾힌다")
	for step: Vector2i in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
			Vector2i(1, 0), Vector2i(0, 1)]:
		_assert(sim.cat_on(here + step) == null,
			"옆칸 %s 에서는 찾히지 않는다" % str(step))
	# And the edge case the radius was hiding: a cat that has stepped most of the
	# way out of its cell still belongs to the cell it is in, not to the one it
	# is nearly in.
	cat.pos = sim.cell_centre(here) + Vector2(float(Defs.TILE) * 0.45, 0.0)
	_assert(sim.cat_on(here) == cat, "칸 가장자리까지 걸어가도 그 칸이다")
	_assert(sim.cat_on(here + Vector2i(1, 0)) == null, "다음 칸은 아직 아니다")
	sim.free()

func _test_the_facing_cell_only() -> void:
	var sim := _world()
	sim.grant_cats(1)
	var facing: Vector2i = sim.core_cell + Vector2i(3, 0)
	var diagonal: Vector2i = facing + Vector2i(0, 1)
	sim.cats[0].pos = sim.cell_centre(diagonal)
	_assert(not sim.is_liftable(facing), "대각선의 고양이는 앞칸의 것이 아니다")
	_assert(not sim.pick_up_cat(facing), "그래서 앞칸으로 잡히지 않는다")
	_assert(sim.carried_cat == null, "빈손 그대로다")
	_assert(sim.pick_up_cat(diagonal), "그 고양이가 선 칸을 보면 잡힌다")
	sim.free()

## The prompt over her head and the key have to agree. A hint that offers a verb
## the key refuses is worse than no hint: it is the game telling her to press a
## key that does nothing.
func _test_the_prompt_agrees() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main._start_run()
	main.state = main.State.PLAY
	main.sim.frozen_cats.clear()
	main.sim.grant_cats(1)
	var here: Vector2i = main.sim.core_cell + Vector2i(4, 0)
	main.player.position = main.sim.cell_centre(here)
	main.player.facing = Vector2i.RIGHT
	var facing: Vector2i = main.player.facing_cell()
	# A cat one step to the side of the cell she is facing.
	main.sim.cats[0].pos = main.sim.cell_centre(facing + Vector2i(0, 1))
	_assert(not main._idle_cat_within_reach(), "옆에 있는 고양이는 안내하지 않는다")
	main.sim.cats[0].pos = main.sim.cell_centre(facing)
	_assert(main._idle_cat_within_reach(), "앞칸에 서면 안내한다")
	_assert(main.sim.pick_up_cat(facing), "그리고 그때 실제로 잡힌다")
	main.clear_save()
	main.free()

## The block of ice wins, whatever is in her hands.
##
## A seam with a block standing on it used to answer the pickaxe: mining beat
## lifting, on the same reasoning that keeps a cat from being scooped off a seam
## the player is working. But a block does not wander past -- it is the one thing
## on this map that turns into a worker, and someone who walks up to one and
## presses Z has said exactly what they mean.
func _test_ice_outranks_the_pickaxe() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	main.clear_save()
	main._start_run()
	main.finish_tutorial()
	main.state = main.State.PLAY
	var sim = main.sim
	# A seam she could mine, with a block of ice on top of it, right in front.
	var cell: Vector2i = sim.core_cell + Vector2i(2, 0)
	sim.machines.erase(cell)
	sim.ore[cell] = Defs.ITEM_HEATSTONE
	sim.frozen_cats[cell] = 0.0
	sim.thawed[cell] = true
	main.player.position = sim.cell_centre(cell + Vector2i(-1, 0))
	main.player.facing = Vector2i(1, 0)
	main.tool_index = main.TOOLS.find(main.TOOL_PICKAXE)
	_assert(main.holding_pickaxe(), "곡괭이를 들고 있고")
	_assert(sim.can_hand_mine(cell), "그 칸은 캘 수 있는 광맥이며")
	main._primary_action()
	_assert(sim.carried_frozen, "그래도 Z는 얼음을 든다")
	_assert(sim.frozen_cats.is_empty() or not sim.frozen_cats.has(cell),
		"얼음은 그 칸에서 사라진다")
	main.clear_save()
	main.free()
