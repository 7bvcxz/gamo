extends SceneTree

## The energy torch: the only way to see anything outside the fire.
##
## The rule it exists to enforce is that exploring costs something. The fog used
## to keep a nine tile preview band past the frontier, so walking further was
## free and the next ore field advertised itself; now past the circle is white
## and a torch buys two tiles of it for thirty seconds.
##
## Thirty seconds of *carrying*, which is the part worth pinning: a torch that
## burned down while it sat in her pack would make the number a countdown that
## starts when you craft it rather than a distance you can travel.

var failures := 0
var main: Node2D = null

func _init() -> void:
	main = load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_run()
	main.finish_tutorial()
	main.state = main.State.PLAY
	_run()

func _run() -> void:
	_test_crafting()
	_test_lighting()
	_test_burns_only_in_hand()
	_test_the_light()
	_test_base_window()
	_test_save()
	if failures == 0:
		print("PASS test_torch")
	else:
		print("FAIL test_torch (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _cost() -> int:
	return int(Defs.TORCH_COST[Defs.ITEM_HEATSTONE])

# --- Made at the fire -------------------------------------------------------

func _test_crafting() -> void:
	var sim = main.sim
	sim.torches = 0
	sim.torch_left = 0.0
	sim.stock[Defs.ITEM_HEATSTONE] = 0
	_assert(not sim.can_craft_torch(), "재료가 없으면 만들 수 없다")
	_assert(not sim.craft_torch(), "그리고 실제로 안 만들어진다")

	sim.stock[Defs.ITEM_HEATSTONE] = _cost() - 1
	_assert(not sim.craft_torch(), "하나 모자라도 안 된다")
	sim.stock[Defs.ITEM_HEATSTONE] = _cost() * 2
	_assert(sim.craft_torch(), "재료가 있으면 만든다")
	_assert(sim.torches == 1, "하나 생긴다")
	_assert(int(sim.stock[Defs.ITEM_HEATSTONE]) == _cost(), "재료가 그만큼 줄어든다")
	# The fuel a torch is made of is fuel the fire did not get. That is the trade
	# the middle of the opening is made of, so the cost has to be the same stuff.
	_assert(Defs.TORCH_COST.has(Defs.ITEM_HEATSTONE), "횃불은 불과 같은 연료를 먹는다")

# --- Taking one out ---------------------------------------------------------

func _test_lighting() -> void:
	var sim = main.sim
	sim.torches = 0
	sim.torch_left = 0.0
	main.tool_index = main.TOOLS.find(main.TOOL_TORCH)
	_assert(main.tool_index >= 0, "횃불 슬롯이 있다")
	main._on_tool_selected()
	_assert(sim.torch_left <= 0.0, "없으면 켜지지 않는다")
	_assert(not main.holding_torch(), "그래서 들고 있는 것도 아니다")

	sim.torches = 2
	main._on_tool_selected()
	_assert(sim.torches == 1, "하나를 꺼낸다")
	_assert(is_equal_approx(sim.torch_left, Defs.TORCH_SECONDS),
		"%.0f초짜리다" % Defs.TORCH_SECONDS)
	_assert(main.holding_torch(), "이제 들고 있다")
	# Selecting the slot again must not spend a second one on top of the one
	# already alight.
	main._on_tool_selected()
	_assert(sim.torches == 1, "이미 켜져 있으면 하나 더 쓰지 않는다")

# --- Thirty seconds of carrying ---------------------------------------------

func _test_burns_only_in_hand() -> void:
	var sim = main.sim
	sim.torches = 1
	sim.torch_left = 0.0
	main.tool_index = main.TOOLS.find(main.TOOL_TORCH)
	main._on_tool_selected()
	var lit: float = sim.torch_left

	# Put it away and wait. Nothing should happen -- the thirty seconds are a
	# distance she can travel, not a fuse lit at the fire.
	main.tool_index = main.TOOLS.find(main.TOOL_PICKAXE)
	for _step in 600:
		main._update_torch(1.0 / 60.0)
	_assert(is_equal_approx(sim.torch_left, lit),
		"주머니 안에서는 타지 않는다 (%.1f초)" % sim.torch_left)

	# And out again, which must not cost another torch.
	var spare: int = sim.torches
	main.tool_index = main.TOOLS.find(main.TOOL_TORCH)
	main._on_tool_selected()
	_assert(sim.torches == spare, "다시 꺼내도 새 것을 쓰지 않는다")

	# Burn it down, ticked in sixtieths the way the game does.
	var elapsed: float = 0.0
	while sim.torch_left > 0.0 and elapsed < Defs.TORCH_SECONDS * 3.0:
		main._update_torch(1.0 / 60.0)
		elapsed += 1.0 / 60.0
	_assert(absf(elapsed - lit) < 0.1, "들고 있으면 %.0f초 만에 꺼진다 (%.1f)" % [lit, elapsed])
	_assert(not main.holding_torch(), "꺼지면 들고 있는 것이 아니다")

# --- What it opens ----------------------------------------------------------

func _test_the_light() -> void:
	var sim = main.sim
	var fog = main.cold_fog
	_assert(fog != null, "안개 레이어가 있다")
	if fog == null:
		return
	# No torch, no hole. The radius is what the shader reads, so zero is the
	# whole switch -- and a hole that survived the torch going out would be the
	# player exploring for free.
	sim.torches = 0
	sim.torch_left = 0.0
	main.tool_index = main.TOOLS.find(main.TOOL_TORCH)
	main._update_torch_light()
	_assert(is_zero_approx(fog.torch_radius), "횃불이 없으면 구멍도 없다")

	sim.torches = 1
	main._on_tool_selected()
	main._update_torch_light()
	_assert(fog.torch_radius > 0.0, "들면 구멍이 생긴다 (%.0fpx)" % fog.torch_radius)
	# World pixels, and the same number on both layers. The first version put the
	# fog's hole in viewport pixels and the game stretches its canvas from a
	# 960x540 base, so the hole opened somewhere Grim was not -- and what it
	# revealed was the unlit ground, which is dark navy.
	var expected: float = Defs.TORCH_SIGHT * float(Defs.TILE)
	_assert(absf(fog.torch_radius - expected) < 0.01, "구멍은 %.0f칸이다" % Defs.TORCH_SIGHT)
	_assert(fog.torch_at.distance_to(main.player.global_position) < 0.01,
		"구멍이 주인공을 따라다닌다")
	var ground = main.ground_layer
	_assert(absf(ground.torch_radius - fog.torch_radius) < 0.01,
		"땅에 켜지는 불빛과 안개의 구멍이 같은 크기다")
	_assert(ground.torch_at.distance_to(fog.torch_at) < 0.01, "그리고 같은 자리다")

	# Put it away: the light goes with it, even though the torch is not spent.
	main.tool_index = main.TOOLS.find(main.TOOL_PICKAXE)
	main._update_torch_light()
	_assert(is_zero_approx(fog.torch_radius), "집어넣으면 구멍도 사라진다")
	_assert(is_zero_approx(main.ground_layer.torch_radius), "불빛도 함께 꺼진다")
	_assert(main.sim.torch_left > 0.0, "그래도 횃불은 남아 있다")

# --- The fire's window ------------------------------------------------------

func _test_base_window() -> void:
	var sim = main.sim
	main.base_menu_open = false
	sim.stock[Defs.ITEM_HEATSTONE] = _cost()
	var before_heat: int = sim.heat
	# Facing the core is what opens it, and what she was carrying goes in on the
	# way -- walking up to the fire means both of those things.
	main.player.position = sim.cell_centre(sim.core_cell + Vector2i(0, 1))
	main.player.facing = Vector2i.UP
	main._primary_action()
	_assert(main.base_menu_open, "기지를 보고 Z 를 누르면 창이 열린다")
	_assert(main.modal_open(), "창이 열려 있는 동안 주인공은 입력을 받지 않는다")
	# Opening it must not spend anything. The first version deposited on open,
	# and since a torch is made of the same heat stone the fire burns, every
	# visit ended with a red cost and nothing to pay it with.
	_assert(sim.heat == before_heat, "여는 것만으로는 아무것도 쓰지 않는다")
	_assert(int(sim.stock.get(Defs.ITEM_HEATSTONE, 0)) == _cost(),
		"들고 있던 연료도 그대로다")

	var rows: Array[Dictionary] = main.base_rows()
	_assert(rows.size() == Defs.BASE_CRAFTS.size() + 1,
		"연료가 있으면 투입 줄이 하나 늘어난다 (%d줄)" % rows.size())
	_assert(String(rows[0]["kind"]) == "fuel", "그 줄이 맨 위다")

	# Craft first, deposit second: the window shows both and the player chooses.
	var torches: int = sim.torches
	main.menu_index = 1
	main._base_menu_confirm()
	_assert(sim.torches == torches + 1, "제작 줄을 고르면 만들어진다")
	_assert(int(sim.stock.get(Defs.ITEM_HEATSTONE, 0)) == 0, "재료가 나간다")
	_assert(main.base_rows().size() == Defs.BASE_CRAFTS.size(),
		"연료가 떨어지면 투입 줄이 사라진다")
	sim.stock[Defs.ITEM_HEATSTONE] = 4
	main.menu_index = 0
	main._base_menu_confirm()
	_assert(sim.heat > before_heat, "투입 줄을 고르면 불에 들어간다")
	_assert(main.menu_index == 0, "줄이 사라져도 커서가 엉뚱한 곳에 남지 않는다")
	main.close_base_menu()
	_assert(not main.base_menu_open and not main.modal_open(), "닫으면 조작이 돌아온다")

func _test_save() -> void:
	var sim = main.sim
	sim.torches = 3
	sim.torch_left = 12.5
	_assert(main.save_game(false), "저장된다")
	sim.torches = 0
	sim.torch_left = 0.0
	_assert(main.load_game(), "불러온다")
	_assert(main.sim.torches == 3, "만들어 둔 횃불이 살아난다")
	_assert(absf(main.sim.torch_left - 12.5) < 0.1, "타다 만 것도 그만큼 남아 있다")
	main.clear_save()
