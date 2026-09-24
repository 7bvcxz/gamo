extends SceneTree

## Important things arriving in her hands (1.0.42).
##
## A tool made at the fire, an energy core out of a wreck: the thing pops out of
## where it was made, hangs a beat, is pulled to her faster as it comes, and lands
## with a spark and a chime -- and the slot it belongs to appears and lights up as
## it lands. The logic does not wait for any of it: the tool is hers and in her
## hand the frame the make ends, exactly as before, so nothing that reads the
## world is held up by an animation. Common things -- stones, copper, the dozens
## a minute -- never get this; they keep the quick stream they always had.

var failures := 0
var main: Node2D = null

func _init() -> void:
	main = load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	_run()

func _run() -> void:
	_test_pickaxe_acquisition_effect()
	_test_pickaxe_slot_activates_after_acquisition()
	_test_important_item_uses_acquisition_presentation()
	_test_common_resource_does_not_use_large_presentation()
	main.clear_save()
	if failures == 0:
		print("PASS test_acquisition")
	else:
		print("FAIL test_acquisition (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _craft_index(id: String) -> int:
	for index in Defs.BASE_CRAFTS.size():
		if String(Defs.BASE_CRAFTS[index]["id"]) == id:
			return index
	return -1

func _run_seconds(seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		var step: float = minf(1.0 / 30.0, left)
		main._process_play(step)
		left -= step

## The fire lit and the hut up, so the pickaxe is on the list.
func _ready_for_pickaxe() -> void:
	main.clear_save()
	main._start_run()
	main.state = main.State.PLAY
	main.sim.search_kit()
	main.sim.shelter_placed = true
	main.sim.shelter_cell = main.sim.core_cell + Defs.SHELTER_CELL
	main.fx.clear_flights()
	main.messages.clear()

func _messages_contain(fragment: String) -> bool:
	for entry: Dictionary in main.messages:
		if String(entry["text"]).contains(fragment):
			return true
	return false

# --- test_pickaxe_acquisition_effect ---------------------------------------------

func _test_pickaxe_acquisition_effect() -> void:
	_ready_for_pickaxe()
	var fx = main.fx
	main.craft_selected(_craft_index("pickaxe"))
	_assert(fx.flights() == 0, "만드는 동안에는 아무것도 날지 않는다")
	_run_seconds(3.1)
	_assert(fx.flights() == 1, "다 되면 곡괭이가 불에서 나온다")
	# The flight, beat by beat: it starts at the fire, pops up and grows, hangs,
	# then is pulled to her and shrinks into her.
	var flight: Dictionary = (fx.get("_flights") as Array)[0]
	var fire: Vector2 = main.sim.cell_centre(main.sim.core_cell)
	_assert(Vector2(flight["from"]).distance_to(fire) < 1.0, "불에서 출발한다")
	flight["t"] = 0.0
	var start: Array = fx.flight_pose(flight)
	flight["t"] = fx.ACQUIRE_POP
	var popped: Array = fx.flight_pose(flight)
	_assert(Vector2(popped[0]).y < Vector2(start[0]).y - 10.0, "위로 튀어 오른다")
	_assert(float(popped[1]) > float(start[1]), "튀어 오르며 커진다")
	flight["t"] = fx.ACQUIRE_POP + fx.ACQUIRE_HOVER * 0.5
	var hover: Array = fx.flight_pose(flight)
	_assert(Vector2(hover[0]).distance_to(Vector2(popped[0])) < 4.0, "잠깐 머문다")
	var chest: Vector2 = main.player.position + fx.ACQUIRE_CHEST
	var gaps: Array[float] = []
	for k: float in [0.25, 0.5, 0.75, 1.0]:
		flight["t"] = fx.ACQUIRE_POP + fx.ACQUIRE_HOVER + fx.ACQUIRE_FLY * k
		gaps.append(Vector2(fx.flight_pose(flight)[0]).distance_to(chest))
	_assert(gaps[0] > gaps[1] and gaps[1] > gaps[2] and gaps[2] > gaps[3],
		"그녀에게 다가간다: %s" % str(gaps))
	_assert((gaps[0] - gaps[1]) < (gaps[2] - gaps[3]), "가까워질수록 빨라진다")
	_assert(gaps[3] < 1.0, "그녀에게 닿는다")
	var total: float = fx.acquire_seconds()
	_assert(total >= 0.6 and total <= 1.0, "빠르다: %.2f초" % total)
	# Landing: gone from the air, a spark at her, the line said, the slot lit.
	flight["t"] = 0.0
	var rings_before: int = (fx.get("_rings") as Array).size()
	fx.advance_flights(total + 0.01)
	_assert(fx.flights() == 0, "닿으면 사라진다")
	_assert((fx.get("_rings") as Array).size() > rings_before, "닿는 자리에 불꽃이 인다")
	_assert(_messages_contain("곡괭이"), "그 순간 곡괭이가 들어왔다고 말한다")
	_assert(main.hud.slot_pulse_left(main.TOOLS.find(main.TOOL_PICKAXE)) > 0.9,
		"1번 칸이 반짝인다")
	# And the sounds are the small bright ones, in the bank.
	var audio_src: String = FileAccess.get_file_as_string("res://scripts/Audio.gd")
	for name: String in ["tick", "pop", "chime"]:
		_assert(audio_src.contains("\"%s\": preload" % name), "%s 소리가 있다" % name)

# --- test_pickaxe_slot_activates_after_acquisition -------------------------------

func _test_pickaxe_slot_activates_after_acquisition() -> void:
	_ready_for_pickaxe()
	var hud = main.hud
	var slot: int = main.TOOLS.find(main.TOOL_PICKAXE)
	_assert(not main.tool_unlocked(main.TOOL_PICKAXE), "처음에는 곡괭이 칸이 없다")
	main.craft_selected(_craft_index("pickaxe"))
	_run_seconds(3.1)
	# The logic landed with the make: hers, in her hand, Z already digs.
	_assert(main.tool_unlocked(main.TOOL_PICKAXE), "제작이 끝나면 칸은 이미 그녀의 것이다")
	_assert(main.holding_pickaxe(), "그리고 손에 들려 있다 (로직은 기다리지 않는다)")
	# But the slot is drawn when the pickaxe reaches her.
	_assert(not hud.slot_shown(slot), "날아오는 동안 칸은 비어 있다")
	main.fx.advance_flights(main.fx.acquire_seconds() + 0.01)
	_assert(hud.slot_shown(slot), "닿으면 1번 칸이 나타난다")
	_assert(hud.slot_pulse_left(slot) > 0.9, "그리고 짧게 강조된다")
	hud._process(hud.SLOT_PULSE + 0.05)
	_assert(hud.slot_pulse_left(slot) == 0.0, "강조는 잠깐이다")
	# A second torch does not blank a slot she is already using.
	main.sim.torches = 1
	var level: Dictionary = Defs.BASE_LEVELS[2]
	main.sim.stones_in = int(level["stones"])
	main.sim._refresh_radius()
	main.sim.stock[Defs.ITEM_HEATSTONE] = 10
	var torch_slot: int = main.TOOLS.find(main.TOOL_TORCH)
	_assert(hud.slot_shown(torch_slot), "횃불 칸이 이미 있다")
	main.craft_selected(_craft_index("torch"))
	_assert(hud.slot_shown(torch_slot), "두 번째 횃불은 있는 칸을 비우지 않는다")
	main.fx.clear_flights()

# --- test_important_item_uses_acquisition_presentation ---------------------------

func _test_important_item_uses_acquisition_presentation() -> void:
	# The registry says what is important; nothing else decides.
	_assert(Defs.item_presentation(Defs.ITEM_ENERGY_CORE) == Defs.PRESENT_IMPORTANT,
		"에너지 코어는 중요한 것이다")
	for craft: Dictionary in Defs.BASE_CRAFTS:
		var id: String = String(craft["id"])
		var hand: bool = id in ["pickaxe", "gun", "torch"]
		_assert((String(craft.get("landing", "")) == "hand") == hand,
			"%s 는 %s" % [id, "손으로 날아온다" if hand else "눈 위에 놓인다"])
	# The gun, through the same flight as the pickaxe.
	main.clear_save()
	main._start_run()
	main.state = main.State.PLAY
	main.sim.search_kit()
	main.sim.note_resource_seen(Defs.ITEM_COPPER)
	main.sim.held_items[Defs.ITEM_COPPER] = true
	main.fx.clear_flights()
	main.craft_selected(_craft_index("gun"))
	_run_seconds(3.1)
	_assert(main.fx.flights() == 1, "건설총도 불에서 날아온다")
	main.fx.clear_flights()
	# An energy core out of a wreck: the first piece always has one.
	main.finish_tutorial()
	main.fx.clear_flights()
	var cell: Vector2i = main.player.facing_cell()
	main.sim.ore.erase(cell)
	main.sim.debris[cell] = 1
	main.mine_held = true
	var left: float = Defs.DEBRIS_SEARCH_SECONDS + 0.3
	while left > 0.0 and main.sim.debris.has(cell):
		main._update_debris(0.1)
		left -= 0.1
	main.mine_held = false
	_assert(not main.sim.debris.has(cell), "잔해가 분해됐다")
	_assert(int(main.sim.stock.get(Defs.ITEM_ENERGY_CORE, 0)) > 0, "에너지 코어가 들어왔다")
	_assert(main.fx.flights() == 1, "에너지 코어 하나만 그녀에게 날아온다")
	main.fx.clear_flights()

# --- test_common_resource_does_not_use_large_presentation -------------------------

func _test_common_resource_does_not_use_large_presentation() -> void:
	for item_type: int in [Defs.ITEM_HEATSTONE, Defs.ITEM_COPPER, Defs.ITEM_IRON,
			Defs.ITEM_IRON_PLATE, Defs.ITEM_COPPER_WIRE]:
		_assert(Defs.item_presentation(item_type) == Defs.PRESENT_COMMON,
			"%s 는 평범한 것이다" % Defs.item_name(item_type))
	main.clear_save()
	main._start_run()
	main.state = main.State.PLAY
	main.finish_tutorial()
	main.fx.clear_flights()
	# Stones by the handful: into the fire, with the stream, and nothing flies.
	main.sim.stock[Defs.ITEM_HEATSTONE] = 30
	main._deposit_at_core()
	_assert(main.fx.flights() == 0, "열석을 불에 넣어도 획득 연출은 없다")
	main.sim._gain(Defs.ITEM_COPPER, 12)
	_assert(main.fx.flights() == 0, "구리 열두 개가 들어와도 없다")
	# A kit comes out of the fire onto the snow, not into her hands.
	main.clear_save()
	main._start_run()
	main.state = main.State.PLAY
	main.sim.search_kit()
	main.fx.clear_flights()
	main.craft_selected(_craft_index("shelter"))
	_run_seconds(3.1)
	_assert(main.fx.flights() == 0, "숙소 키트는 날아오지 않고 눈 위에 놓인다")
	_assert(main.craft_done("shelter"), "그래도 만들어졌다")
