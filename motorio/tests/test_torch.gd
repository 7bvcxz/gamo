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
	_test_it_keeps_her_warm()
	_test_base_window()
	_test_edge_and_hint()
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

	# Choosing the slot takes it out and nothing more. It used to light itself,
	# so a player who pressed 3 to see what it was had burned thirty seconds
	# before deciding whether to walk anywhere.
	sim.torches = 2
	main._on_tool_selected()
	_assert(sim.torches == 2, "고르는 것만으로는 쓰이지 않고")
	_assert(sim.torch_left <= 0.0, "불도 붙지 않는다")
	# Z is the match.
	main._primary_action()
	_assert(sim.torches == 1, "Z 를 누르면 하나를 꺼내 불을 붙인다")
	_assert(is_equal_approx(sim.torch_left, Defs.TORCH_SECONDS),
		"%.0f초짜리다" % Defs.TORCH_SECONDS)
	_assert(main.holding_torch(), "이제 불이 붙어 있다")
	# And pressing it again must not spend a second one on top of the first.
	main._primary_action()
	_assert(sim.torches == 1, "이미 켜져 있으면 하나 더 쓰지 않는다")

# --- Thirty seconds of carrying ---------------------------------------------

## Once lit it keeps burning, whatever is in her hands.
##
## It used to burn only while the slot was selected, which made the torch a thing
## you switched on and off: the fog opened and closed as she changed tools, and
## thirty seconds meant thirty seconds of not doing anything else. Now it is a
## fire she set, and it goes out when it goes out.
func _test_burns_only_in_hand() -> void:
	var sim = main.sim
	sim.torches = 1
	sim.torch_left = 0.0
	main.tool_index = main.TOOLS.find(main.TOOL_TORCH)
	main._on_tool_selected()
	main._primary_action()
	var lit: float = sim.torch_left
	_assert(lit > 0.0, "불을 붙였고")

	# Switch to the pickaxe and wait: it burns down anyway, and she is free to
	# use the seconds for something.
	main.tool_index = main.TOOLS.find(main.TOOL_PICKAXE)
	for _step in 60:
		main._update_torch(1.0 / 60.0)
	_assert(sim.torch_left < lit - 0.9,
		"곡괭이를 들어도 계속 탄다 (%.1f초)" % sim.torch_left)
	_assert(main.holding_torch(), "그리고 여전히 불이 붙어 있다")

	# Burn it down, ticked in sixtieths the way the game does.
	var elapsed: float = 1.0
	while sim.torch_left > 0.0 and elapsed < Defs.TORCH_SECONDS * 3.0:
		main._update_torch(1.0 / 60.0)
		elapsed += 1.0 / 60.0
	_assert(absf(elapsed - lit) < 0.1, "%.0f초 만에 꺼진다 (%.1f)" % [lit, elapsed])
	_assert(not main.holding_torch(), "꺼지면 불이 없다")

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
	main._primary_action()
	main._update_torch_light()
	_assert(fog.torch_radius > 0.0, "불을 붙이면 구멍이 생긴다 (%.0fpx)" % fog.torch_radius)
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

	# Change tools and the hole stays: it is a fire she lit, not a lamp she is
	# holding. What puts it out is the thirty seconds running out.
	main.tool_index = main.TOOLS.find(main.TOOL_PICKAXE)
	main._update_torch_light()
	_assert(fog.torch_radius > 0.0, "곡괭이를 들어도 구멍은 남는다")
	main.sim.torch_left = 0.0
	main._update_torch_light()
	_assert(is_zero_approx(fog.torch_radius), "꺼지면 구멍도 사라진다")
	_assert(is_zero_approx(main.ground_layer.torch_radius), "불빛도 함께 꺼진다")

# --- The fire's window ------------------------------------------------------

## A lit torch is a fire she is carrying. Without this it showed her a place she
## could not stay in: two tiles of visible snow and thirteen degrees a second.
func _test_it_keeps_her_warm() -> void:
	var sim = main.sim
	sim.torches = 1
	sim.torch_left = 0.0
	# Well outside the circle, where the cold is at its full rate.
	main.player.position = sim.cell_centre(sim.core_cell + Vector2i(30, 0))
	main.player.warmth = 80.0
	_assert(not sim.is_warm(main.player.cell()), "온기 밖에 서 있다")

	main.tool_index = main.TOOLS.find(main.TOOL_PICKAXE)
	for _step in 60:
		main._update_warmth(1.0 / 60.0)
	_assert(main.player.warmth < 79.0, "횃불이 없으면 떨어진다 (%.1f)" % main.player.warmth)

	main.player.warmth = 80.0
	main.tool_index = main.TOOLS.find(main.TOOL_TORCH)
	main._on_tool_selected()
	main._primary_action()
	_assert(main.holding_torch(), "횃불에 불을 붙였다")
	for _step in 60:
		main._update_warmth(1.0 / 60.0)
	_assert(is_equal_approx(main.player.warmth, 80.0),
		"타는 동안은 줄지 않는다 (%.1f)" % main.player.warmth)

	# And the moment it goes out, the cold is back -- the two stop together
	# because they are the same thirty seconds.
	sim.torch_left = 0.0
	for _step in 60:
		main._update_warmth(1.0 / 60.0)
	_assert(main.player.warmth < 79.0, "꺼지면 다시 떨어진다 (%.1f)" % main.player.warmth)
	main.player.warmth = 100.0
	main.player.position = sim.cell_centre(sim.core_cell)

func _test_base_window() -> void:
	var sim = main.sim
	# Not with the torch out: Z means "light it" while that slot is selected, and
	# the section above leaves it selected. The pickaxe is what she walks up to
	# the fire holding.
	main.tool_index = main.TOOLS.find(main.TOOL_PICKAXE)
	main.base_menu_open = false
	sim.stock[Defs.ITEM_HEATSTONE] = _cost()
	var before_stones: int = sim.stones_in
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
	_assert(sim.stones_in == before_stones, "여는 것만으로는 아무것도 쓰지 않는다")
	_assert(int(sim.stock.get(Defs.ITEM_HEATSTONE, 0)) == _cost(),
		"들고 있던 연료도 그대로다")

	# At 3단계, where the torch is. Below that this window is one line -- the
	# upgrade -- and the torch these cases are about does not exist yet.
	#
	# One recipe, not both: the list opens a rung at a time as of 1.0.26, and the
	# bin waits for the fourth. So the count is "the fuel row plus whatever this
	# rung has unlocked" rather than the whole table.
	sim.stones_in = int(Defs.BASE_LEVELS[2]["stones"])
	sim._refresh_radius()
	var rows: Array[Dictionary] = main.base_rows()
	var open_here := 1
	for craft: Dictionary in Defs.BASE_CRAFTS:
		if Defs.base_level_shown(sim.base_level) >= int(craft["level"]):
			open_here += 1
	_assert(rows.size() == open_here,
		"투입 줄은 언제나 있다 (%d줄, 기대 %d줄)" % [rows.size(), open_here])
	_assert(String(rows[0]["kind"]) == "fuel", "그 줄이 맨 위다")

	# Craft first, deposit second: the window shows both and the player chooses.
	var torches: int = sim.torches
	main.menu_index = 1
	main._base_menu_confirm()
	_assert(sim.torches == torches + 1, "제작 줄을 고르면 만들어진다")
	_assert(int(sim.stock.get(Defs.ITEM_HEATSTONE, 0)) == 0, "재료가 나간다")
	_assert(main.base_rows().size() == open_here, "연료가 떨어져도 줄은 남는다")
	# And below 3단계 the window is the upgrade alone.
	var kept: int = sim.stones_in
	sim.stones_in = 0
	sim._refresh_radius()
	_assert(main.base_rows().size() == 1, "3단계 전에는 기지 강화 한 줄뿐이다")
	sim.stones_in = kept
	sim._refresh_radius()
	sim.stock[Defs.ITEM_HEATSTONE] = maxi(4, sim.stones_to_next())
	main.menu_index = 0
	main._base_menu_confirm()
	_assert(sim.stones_in > before_stones, "투입 줄을 고르면 불에 들어간다")
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

## The block at the fourth step's edge, and the hint that goes with it.
##
## The scene the design wants: she walks to something she can see, is told the
## ground has not let go of it, and the game says once -- three times at most --
## that a torch would do. After she has melted one it never says it again.
func _test_edge_and_hint() -> void:
	var sim = main.sim
	_assert(sim.edge_frozen != Vector2i(9999, 9999), "경계선 고양이가 있다")
	var ring: float = sim._ring_distance(sim.edge_frozen)
	# The third circle, not the fourth. Three is the rung where the fire's window
	# grows a craft list, so it is the first moment a torch is a thing she can
	# have -- and a hint about a torch a rung before the torch exists is a hint
	# about nothing.
	var third: float = float(Defs.BASE_LEVELS[2]["radius"])
	_assert(ring > third, "3단계 온기(%.0f칸) 바로 밖이다: %.1f칸" % [third, ring])
	_assert(ring < third + 2.0, "그러나 손이 닿을 만큼 가깝다: %.1f칸" % ring)
	# And the next rung reaches it, which is what makes it a promise rather than
	# a wall: a torch now, or one more step of the fire.
	_assert(ring < float(Defs.BASE_LEVELS[3]["radius"]),
		"다음 단계는 그것을 품는다: %.1f칸" % ring)
	_assert(sim.frozen_cats.has(sim.edge_frozen), "그 칸에 얼음이 있다")

	# The hint: three times, and then never.
	sim.torch_hints = 0
	sim.learned.erase("THAWED")
	for attempt in 5:
		main.frozen_said = 0.0
		main._say_frozen(sim.edge_frozen)
	_assert(sim.torch_hints == Defs.TORCH_HINTS_MAX,
		"횃불 안내는 %d번까지만 나온다 (%d)" % [Defs.TORCH_HINTS_MAX, sim.torch_hints])

	# And not at all once she has melted something.
	sim.torch_hints = 0
	sim.learn("THAWED")
	main.frozen_said = 0.0
	main._say_frozen(sim.edge_frozen)
	_assert(sim.torch_hints == 0, "한 번이라도 녹여 봤으면 다시 말하지 않는다")
	sim.learned.erase("THAWED")
