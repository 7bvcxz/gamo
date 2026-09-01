extends SceneTree

## The key over Grim's head.
##
## This exists because of what making the objective card unhelpful cost. The
## card says the situation and never a key -- "춥다. 눈 위에 상자가 하나 있다."
## -- and the first play test of the finished opening found the obvious hole:
## she lands on another planet and does not know a single control.
##
## Two rules the tests hold. **Only one prompt at a time**, because two of these
## over her head is a menu and the point is that it is read without reading. And
## **done is read off the world** wherever the world remembers, so a prompt
## cannot go on nagging after the thing was done some other way.

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
	_test_table()
	_test_first_thing_is_moving()
	_test_the_kit()
	_test_learned_from_the_world()
	_test_one_at_a_time()
	_test_quiet_when_not_playing()
	if failures == 0:
		print("PASS test_prompts")
	else:
		print("FAIL test_prompts (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _crash() -> void:
	main.clear_save()
	main._start_run()
	main.state = main.State.PLAY

# --- The table --------------------------------------------------------------

func _test_table() -> void:
	var seen: Dictionary[String, bool] = {}
	for row: Dictionary in Defs.KEY_PROMPTS:
		var id: String = String(row["id"])
		_assert(not seen.has(id), "id 가 겹치지 않는다: %s" % id)
		seen[id] = true
		_assert(not (row["keys"] as Array).is_empty(), "%s 에 키가 있다" % id)
		_assert(String(row["verb"]).strip_edges() != "", "%s 에 동사가 있다" % id)
		_assert(String(row["why"]).strip_edges() != "", "%s 에 이유가 적혀 있다" % id)
		# One word. Two words is a sentence and the card is where sentences go.
		_assert(not String(row["verb"]).contains(" "), "%s 의 동사는 한 마디다" % id)
	_assert(Defs.key_prompt("없는아이디").is_empty(), "없는 id 는 빈 것을 준다")

# --- The first second of the game -------------------------------------------

func _test_first_thing_is_moving() -> void:
	_crash()
	_assert(main.active_prompt() == "MOVE", "떨어지자마자 나오는 것은 이동이다")
	# It is last in the table, and that is not a priority mistake: at the moment
	# she lands nothing else applies, so last still means first on screen.
	var last: String = String(Defs.KEY_PROMPTS[Defs.KEY_PROMPTS.size() - 1]["id"])
	_assert(last == "MOVE", "표의 맨 뒤에 있는데도 그렇다")
	_assert((Defs.key_prompt("MOVE")["keys"] as Array).size() == 4, "화살표 넷을 보여준다")

	# Walking is what teaches it, and it stops once she has walked.
	main.sim.walked = Defs.PROMPT_WALK_LEARNED + 0.1
	_assert(main.active_prompt() != "MOVE", "%.0f칸을 걸으면 사라진다"
		% Defs.PROMPT_WALK_LEARNED)
	main.sim.walked = Defs.PROMPT_WALK_RUN + 0.1
	_assert(main.active_prompt() == "RUN", "조금 더 걸으면 달리기를 알려준다")
	main.sim.learn("RUN")
	_assert(main.active_prompt() != "RUN", "한 번 달리면 그만 말한다")

# --- The kit ----------------------------------------------------------------

func _test_the_kit() -> void:
	_crash()
	main.sim.walked = 99.0
	main.player.position = main.sim.cell_centre(main.sim.kit_cell)
	_assert(main.active_prompt() == "KIT", "상자 옆에 서면 Z 조사")
	_assert(bool(Defs.key_prompt("KIT").get("hold", false)),
		"그리고 누르고 있어야 한다고 말한다")
	# The case unfolds into the base now; what she carries is the shelter kit the
	# fire makes, so the prompt becomes 내려놓기 the moment that is in her hands.
	main.sim.search_kit()
	main.sim.craft_shelter_kit()
	for cell: Vector2i in main.sim.drops.keys():
		main.sim.collect_drop(cell)
	_assert(main.active_prompt() == "PLACE", "주워 들면 내려놓기로 바뀐다")
	main.sim.place_base(main.sim.core_cell)
	main.sim.carried_kit = Defs.KIT_NONE
	main.sim.search_kit()
	for cell: Vector2i in main.sim.drops.keys():
		main.sim.collect_drop(cell)
	main.sim.place_shelter(main.sim.core_cell + Vector2i(-4, 0))
	main.player.position = main.sim.cell_centre(main.sim.kit_cell)
	_assert(main.active_prompt() != "KIT", "상자를 다 뒤지면 다시 말하지 않는다")

# --- The world remembers ----------------------------------------------------

func _test_learned_from_the_world() -> void:
	_crash()
	main.finish_tutorial()
	var sim = main.sim
	sim.walked = 99.0
	sim.learn("TOOL")
	sim.learn("RUN")
	# A frozen cat in reach, with empty hands.
	sim.frozen_cats.clear()
	sim.cats.clear()
	# Standing beside it and looking at it. Z acts on the cell she faces and on
	# no other as of 1.0.7, so the prompt that offers the verb asks the same
	# question the key answers -- offering it for a cat she is merely near is the
	# game telling her to press a key that does nothing.
	var spot: Vector2i = sim.core_cell + Vector2i(3, 0)
	sim.frozen_cats[spot] = 0.0
	main.player.position = sim.cell_centre(spot + Vector2i(-1, 0))
	main.player.facing = Vector2i.RIGHT
	_assert(main.active_prompt() == "FROZEN", "얼어붙은 고양이를 바라보면 안기")
	# Nothing was pressed and no flag was set -- a cat simply exists now, and
	# that is the world answering the question.
	sim.grant_cats(1)
	_assert(main.active_prompt() != "FROZEN",
		"고양이가 한 마리라도 생기면 그 안내는 끝난다")

	# And the one that follows it: a cat with no job, on the cell she is facing.
	sim.frozen_cats.clear()
	sim.cats[0].pos = sim.cell_centre(main.player.facing_cell())
	sim.cats[0].assigned = Vector2i(9999, 9999)
	_assert(main.active_prompt() == "CATLIFT", "일 없는 고양이를 바라보면 안기")
	sim.cats[0].assigned = sim.core_cell + Vector2i(0, 3)
	_assert(main.active_prompt() != "CATLIFT", "일을 시키면 끝난다")

# --- One at a time ----------------------------------------------------------

func _test_one_at_a_time() -> void:
	_crash()
	# Everything true at once: carrying a kit, standing on the box, not yet
	# walked. The table's order decides, and exactly one comes out.
	main.player.position = main.sim.cell_centre(main.sim.kit_cell)
	main.sim.search_kit()
	main.sim.craft_shelter_kit()
	for cell: Vector2i in main.sim.drops.keys():
		main.sim.collect_drop(cell)
	var shown: String = main.active_prompt()
	_assert(shown == "PLACE", "여러 개가 해당돼도 표의 순서가 정한다 (%s)" % shown)
	var wanted := 0
	for row: Dictionary in Defs.KEY_PROMPTS:
		var status: Dictionary = main._prompt_status(String(row["id"]))
		if bool(status["want"]) and not bool(status["done"]):
			wanted += 1
	_assert(wanted > 1, "실제로 여러 개가 해당되는 상황이었다 (%d개)" % wanted)
	_assert(main.active_prompt() == shown, "그래도 나오는 것은 하나다")

# --- Not while something else is on screen ----------------------------------

func _test_quiet_when_not_playing() -> void:
	_crash()
	main.build_menu_open = true
	_assert(main.active_prompt() == "", "창이 열려 있으면 말하지 않는다")
	main.build_menu_open = false
	main.player.locked = true
	_assert(main.active_prompt() == "", "얼어붙어 있을 때도 마찬가지다")
	main.player.locked = false
	main.state = main.State.OPENING
	_assert(main.active_prompt() == "", "컷씬 위에는 뜨지 않는다")
	main.state = main.State.PLAY
	_assert(main.active_prompt() != "", "돌아오면 다시 말한다")
