extends SceneTree
## Mining moved from its own key onto the tool slot, and the two things that can
## go wrong are both invisible.
##
## The first is that Z now means several things and which one it means depends on
## what is in her hands: with the gun it builds, with the pickaxe it swings, and
## with a cat in her arms it puts the cat down whichever tool is selected. The
## second is the release: mining is a hold, and letting go used to run the tap
## action -- so mining the seam beside the shelter put her to bed.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_run()
	main.finish_tutorial()
	main.state = main.State.PLAY
	await process_frame

	_assert(main.TOOLS.size() == 3, "도구가 셋이다 — 곡괭이, 건설총, 횃불")
	# The pickaxe is slot one. It used to be the gun, from when the game began
	# with a factory standing -- which made slot one a tool she could not use for
	# the first ten minutes.
	main.sim.note_resource_seen(Defs.ITEM_HEATSTONE)
	# The miner is opened by holding the build gun with stone to pay for one,
	# not by having seen a stone. These tests want it standing.
	main.sim.unlocked[Defs.M_MINER] = true
	main.tool_index = main.TOOLS.find(main.TOOL_PICKAXE)
	_assert(main.tool_index == 0, "곡괭이가 1번이다")
	_assert(main.holding_pickaxe() and not main.holding_build_gun(), "1번은 곡괭이")
	main.tool_index = main.TOOLS.find(main.TOOL_BUILD_GUN)
	_assert(main.holding_build_gun() and not main.holding_pickaxe(), "2번은 건설총")

	# Put a seam where she is facing, and make sure she is facing it.
	var seam: Vector2i = main.player.facing_cell()
	main.sim.ore[seam] = Defs.ITEM_CRYSTAL
	main.sim.machines.erase(seam)

	# The gun does not mine, however long Z is held.
	main.tool_index = main.TOOLS.find(main.TOOL_BUILD_GUN)
	main.mine_held = true
	main.player.mining = 0.0
	main._update_hand_mining(0.5)
	_assert(is_equal_approx(main.player.mining, 0.0), "건설총으로는 캐지지 않는다")
	_assert(not main.mine_swung, "건설총이면 스윙도 없다")

	# The pickaxe does.
	main.tool_index = main.TOOLS.find(main.TOOL_PICKAXE)
	main._update_hand_mining(0.5)
	_assert(main.player.mining > 0.0, "곡괭이로는 캐진다")
	_assert(main.mine_swung, "곡괭이 스윙이 기록된다")

	# Ten seconds of it produces one, on the ground rather than in a pocket.
	var before: int = main.sim.ground.size()
	for step in 24:
		main._update_hand_mining(0.5)
	_assert(main.sim.ground.size() > before, "충분히 캐면 바닥에 자원이 떨어진다")

	# Letting go of the seam stops it, and the swing frame resets so the impact
	# sound cannot fire from a stale value on the next seam.
	main.mine_held = false
	main._update_hand_mining(0.1)
	_assert(is_equal_approx(main.player.mining, 0.0), "손을 떼면 멈춘다")
	_assert(int(main.last_mine_frame) == -1, "스윙 프레임이 초기화된다")

	# The block that used to sit here asserted that holding Z with the gun turned
	# the ghost. That behaviour went in 1.0.25 and the assertion stayed, so this
	# file failed on every run for four versions while describing a feature the
	# game does not have. "Z never turns anything" now lives in `test_flow`,
	# beside the R that does -- one place, where the two can be read together.

	# The swing runs at the walk's rate, which is twice the rate the clips were
	# filmed at. That is the decision, not an oversight: the source loops repeat
	# every 1.4 to 1.7 seconds, and a swing that slow reads as somebody with time
	# on their hands rather than as a woman digging heat out of the ground before
	# dark. It was halved for being frantic once and doubled back on 2026-08-22.
	#
	# This assertion said the opposite until 2026-08-31, and had been failing
	# every run since the day the speed changed -- nine days and four releases,
	# because nothing runs this suite to completion except a person deciding to.
	# Written as a band rather than an equality so the number still cannot move
	# without somebody choosing to move it.
	_assert(is_equal_approx(PlayerActor.MINE_FPS, PlayerActor.FPS),
		"채굴은 걷기와 같은 속도로 재생된다")
	var swing: float = float(PlayerActor.FRAMES) / PlayerActor.MINE_FPS
	_assert(swing > 0.7 and swing < 0.95, "스윙 한 번이 0.7~0.95초 (%.2f초)" % swing)
	_assert(PlayerActor.MINE_IMPACT_FRAME >= 0
		and PlayerActor.MINE_IMPACT_FRAME < PlayerActor.FRAMES,
		"충돌 프레임이 시트 안에 있다")

	# --- A passing cat does not eat the swing ----------------------------------
	# Z lifts cats before it swings, and a cat hauling crystal to the core walks
	# over the seams all day. Standing at a seam with the pickaxe out and pressing
	# Z used to hand you the cat -- and carrying one cancels mining, so the press
	# cost progress and gave nothing.
	var bare_sim = main.sim
	var bare := Vector2i(9999, 9999)
	for cell: Vector2i in bare_sim.ore:
		if not bare_sim.machines.has(cell) and not bare_sim.is_structure(cell + Vector2i(0, 1)):
			bare = cell
			break
	_assert(bare != Vector2i(9999, 9999), "맨 광맥이 하나 있다")
	bare_sim.cats.clear()
	var passer = bare_sim.Cat.new()
	passer.pos = bare_sim.cell_centre(bare)
	bare_sim.cats.append(passer)
	main.player.position = bare_sim.cell_centre(bare + Vector2i(0, 1))
	main.player.facing = Vector2i.UP
	main.tool_index = main.TOOL_PICKAXE
	main._primary_action()
	_assert(bare_sim.carried_cat == null, "곡괭이로 광맥을 볼 때 Z는 고양이를 들지 않는다")
	main.mine_held = true
	main._update_hand_mining(0.2)
	_assert(main.player.mining > 0.0, "그리고 실제로 곡괭이질이 시작된다")
	main.mine_held = false

	# Standing on a seam mines it. Ore is terrain now, so walking at one puts you
	# on top of it rather than stopping you in front -- which is what the game
	# asks a new player to do first, and what silently stopped working when ore
	# became walkable.
	bare_sim.cats.clear()
	main.player.position = bare_sim.cell_centre(bare)
	main.player.facing = Vector2i.UP
	_assert(not bare_sim.ore.has(main.player.facing_cell()),
		"바라보는 칸에는 광맥이 없다")
	main.tool_index = main.TOOL_PICKAXE
	main.mine_held = true
	main.player.mining = 0.0
	main._update_hand_mining(0.2)
	_assert(main.player.mining > 0.0, "광맥 위에 서서 캘 수 있다")
	main.mine_held = false

	# And facing still wins, so a player standing on one seam can reach across to
	# the next one deliberately.
	var neighbour: Vector2i = Vector2i(9999, 9999)
	for cell: Vector2i in bare_sim.ore:
		if cell != bare and not bare_sim.machines.has(cell):
			neighbour = cell
			break
	if neighbour != Vector2i(9999, 9999):
		main.player.position = bare_sim.cell_centre(neighbour - (neighbour - bare).sign())
		main.player.facing = (neighbour - bare).sign()
		if bare_sim.ore.has(main.player.facing_cell()):
			_assert(main._hand_target() == main.player.facing_cell(),
				"바라보는 광맥이 발밑보다 우선한다")

	# Back to the state the next section expects. Two sections sharing one
	# instance is how a passing test starts depending on the order it happens to
	# run in, and this file has been bitten by exactly that before.
	bare_sim.cats.clear()
	bare_sim.cats.append(passer)
	main.player.position = bare_sim.cell_centre(bare + Vector2i(0, 1))
	main.player.facing = Vector2i.UP

	# But taking a cat off a miner still has to work, and that cat is standing on
	# ore as well -- the miner was built onto the seam.
	bare_sim.unlocked[Defs.M_MINER] = true
	bare_sim.stock[Defs.ITEM_CRYSTAL] = 500
	bare_sim.stock[Defs.ITEM_HEATSTONE] = 500
	_assert(bare_sim.build(Defs.M_MINER, bare, Vector2i(0, -1)), "광맥 위에 채굴기를 세운다")
	passer.pos = bare_sim.cell_centre(bare)
	main._primary_action()
	_assert(bare_sim.carried_cat == passer, "채굴기 위의 고양이는 곡괭이를 들고도 안을 수 있다")
	main._primary_action()

	main.queue_free()
	if failures == 0:
		print("PICKAXE_TEST: PASS")
	quit(failures)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		print("  FAIL: ", message)
		failures += 1
