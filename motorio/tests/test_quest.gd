extends SceneTree

## The quest list, as contracts.
##
## The point of this file is the one in the design brief: there must not be a
## second progression system. Mission state lives in three places -- the opening
## enum, the open/done latch pair, and the tables that hold the sentences -- and
## `quests()` is a projection over those three, not a copy of them. So most of
## what is asserted here is agreement: change the world, and the quest list has
## already changed, because there was nothing to keep in step.

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
	_test_quest_hud_hidden_when_empty()
	_test_quest_hud_shows_active_quest()
	_test_quest_window_toggle_q()
	_test_quest_window_lists_active_and_completed()
	_test_quest_complete_check_visible_for_two_seconds()
	_test_quest_completion_is_persisted()
	_test_esc_quest_closes_before_settings()
	_test_progress_has_one_source()
	if failures == 0:
		print("PASS test_quest")
	else:
		print("FAIL test_quest (%d)" % failures)
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

func _ids(rows: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for row: Dictionary in rows:
		out.append(String(row["id"]))
	return out

# --- test_quest_hud_hidden_when_empty ----------------------------------------

## An empty panel is worse than no panel, and this corner has learned that twice.
func _test_quest_hud_hidden_when_empty() -> void:
	_crash()
	main.mission = main.Mission.DONE
	main.missions_open.clear()
	main.missions_done.clear()
	# Jumping the enum finishes both opening quests, and finishing one raises the
	# tick -- correctly. Wait it out: what is being asserted here is the quiet
	# state after everything is done, not the moment it becomes done.
	for _step in int(Defs.QUEST_FLASH_SECONDS * 30.0) + 6:
		main._process_play(1.0 / 30.0)
	_assert(main.active_quests().is_empty(), "진행 중인 임무가 없다")
	_assert(main.hud.quest_hud_text() == "", "그러면 줄도 없다")
	_assert(main.hud.quest_hud_rect().size.y == 0.0,
		"빈 판을 남기지 않는다 (높이 %.1f)" % main.hud.quest_hud_rect().size.y)

# --- test_quest_hud_shows_active_quest ---------------------------------------

func _test_quest_hud_shows_active_quest() -> void:
	_crash()
	main.mission = main.Mission.BASE
	main.quest_done_flash = 0.0
	var active: Array[Dictionary] = main.active_quests()
	var want: Array[String] = ["Q-KIT"]
	_assert(_ids(active) == want,
		"오프닝의 첫 임무 하나가 열려 있다: %s" % str(_ids(active)))
	_assert(main.hud.quest_hud_text() == String(active[0]["title"]),
		"줄이 그 임무를 말한다")
	_assert(main.hud.quest_hud_rect().size.y > 0.0, "그리고 자리를 차지한다")
	# Under the ledger, and the goal card below it -- the column is stacked
	# through one function, so a third panel cannot be forgotten by three callers.
	var quest: Rect2 = main.hud.quest_hud_rect()
	# Under whatever is actually drawn above it. The ledger is not drawn while it
	# has no rows, so at the very start the line sits directly under the bars --
	# asking for the ledger's rect there would be asking about a panel nobody can
	# see.
	var above: float = main.hud.status_rect().end.y
	if not main.hud.resource_rows().is_empty():
		above = main.hud.resource_rect().end.y
	_assert(quest.position.y >= above, "위에 그려진 것 바로 아래에 있다")
	_assert(main.hud.left_column_bottom() >= quest.end.y,
		"컬럼의 바닥이 임무 줄을 포함한다")
	_assert(main.hud.goal_top() >= quest.end.y, "목표 카드가 그 아래로 밀린다")

# --- test_quest_window_toggle_q ----------------------------------------------

func _test_quest_window_toggle_q() -> void:
	_crash()
	_assert(not main.quest_open, "처음에는 닫혀 있다")
	_assert(main.toggle_quests(), "Q 가 연다")
	_assert(main.quest_open, "열렸다")
	_assert(main.toggle_quests(), "Q 가 다시 닫는다")
	_assert(not main.quest_open, "닫혔다")
	# And it is a window like the others: opening one closes the rest.
	main.toggle_quests()
	main.toggle_log()
	_assert(not main.quest_open, "기록을 열면 임무 창이 닫힌다")
	main.toggle_quests()
	_assert(not main.log_open, "임무를 열면 기록이 닫힌다")
	main.close_windows()

# --- test_quest_window_lists_active_and_completed ----------------------------

func _test_quest_window_lists_active_and_completed() -> void:
	_crash()
	main.mission = main.Mission.SURVIVE
	main._process_play(1.0 / 30.0)
	_assert(_ids(main.done_quests()).has("Q-KIT"), "지나온 것은 완료로 간다")
	_assert(_ids(main.active_quests()).has("Q-SHELTER"), "지금 것은 진행 중이다")
	_assert(not _ids(main.done_quests()).has("Q-SHELTER"), "두 목록은 겹치지 않는다")
	for row: Dictionary in main.quests():
		_assert(String(row["title"]).strip_edges() != "",
			"%s 에 읽을 문장이 있다" % String(row["id"]))
	# Finished quests read in the past tense; a checklist still phrased as
	# instructions reads as work outstanding.
	for row: Dictionary in main.done_quests():
		_assert(String(row["title"]).ends_with("다"),
			"완료한 임무는 지난 일로 적힌다: %s" % String(row["title"]))
	# Newest first.
	main.mission = main.Mission.DONE
	main._process_play(1.0 / 30.0)
	var order: Array[String] = _ids(main.done_quests())
	_assert(order.size() >= 2, "둘 이상 완료됐다: %s" % str(order))
	_assert(order[0] == "Q-SHELTER", "가장 최근 것이 위에 온다: %s" % str(order))

# --- test_quest_complete_check_visible_for_two_seconds -----------------------

func _test_quest_complete_check_visible_for_two_seconds() -> void:
	_crash()
	main.mission = main.Mission.BASE
	main._process_play(1.0 / 30.0)
	var before: String = main.hud.quest_hud_text()
	main.mission = main.Mission.SURVIVE
	main._process_play(1.0 / 30.0)
	_assert(main.quest_done_flash > 0.0, "완료하면 표시가 선다")
	_assert(main.hud.quest_hud_text() != before, "줄이 완료한 임무로 바뀐다")
	_assert(main.hud.quest_hud_text() == "눈 위의 상자를 조사했다",
		"완료 문장이다: %s" % main.hud.quest_hud_text())
	# Roughly two seconds, and then the next quest takes the line back.
	var left: float = Defs.QUEST_FLASH_SECONDS
	_assert(absf(main.quest_done_flash - left) < 0.2,
		"약 %.0f초 머문다 (%.2f)" % [left, main.quest_done_flash])
	for _step in int(left * 30.0) + 4:
		main._process_play(1.0 / 30.0)
	_assert(main.quest_done_flash == 0.0, "그 뒤 사라진다")
	_assert(main.hud.quest_hud_text() == String(main.active_quests()[0]["title"]),
		"그리고 다음 임무가 그 자리에 온다")

# --- test_quest_completion_is_persisted --------------------------------------

func _test_quest_completion_is_persisted() -> void:
	_crash()
	main.mission = main.Mission.DONE
	main._process_play(1.0 / 30.0)
	var done_before: Array[String] = _ids(main.done_quests())
	_assert(done_before.size() >= 2, "완료 이력이 있다")
	_assert(main.save_game(false), "저장된다")
	main._start_run()
	_assert(main.done_quests().is_empty(), "새 회차는 이력이 비어 있다")
	_assert(main.load_game(), "불러온다")
	_assert(_ids(main.done_quests()) == done_before,
		"완료 이력과 순서가 세이브를 건너온다: %s" % str(_ids(main.done_quests())))
	main.clear_save()

# --- test_esc_quest_closes_before_settings -----------------------------------

## Overlay before panel. Esc in front of an open window closes the window and
## does not also open settings behind it.
func _test_esc_quest_closes_before_settings() -> void:
	_crash()
	main.toggle_quests()
	_assert(main.quest_open, "임무 창이 열려 있다")
	main.escape_pressed()
	_assert(not main.quest_open, "Esc 가 임무 창을 닫는다")
	_assert(main.state != main.State.SETTINGS, "설정은 아직 열리지 않는다")
	main.escape_pressed()
	_assert(main.state == main.State.SETTINGS, "다시 누르면 설정이 열린다")
	main.close_settings()
	main.state = main.State.PLAY

# --- test_progress_has_one_source --------------------------------------------

## The "2 / 3" the player reads and the number the code computes have to be the
## same number. They were not: the fire's window recomputed it inline from `sim`
## while `fuel_progress()` sat here correct and unread.
func _test_progress_has_one_source() -> void:
	_crash()
	main.finish_tutorial()
	main.sim.stones_in = 0
	main._update_missions()
	main._update_quest_log(0.0)
	var rows: Array[Dictionary] = main.active_quests()
	var found := false
	for row: Dictionary in rows:
		if String(row["id"]) != "BASE2":
			continue
		found = true
		var pair: Array[int] = main.upgrade_progress()
		_assert(int(row["current"]) == pair[0] and int(row["target"]) == pair[1],
			"임무의 진행도가 upgrade_progress 와 같은 수다: %d/%d" %
			[int(row["current"]), int(row["target"])])
		_assert(int(row["target"]) == Defs.OPENING_STONES,
			"그 수는 %d 다" % Defs.OPENING_STONES)
	_assert(found, "기지 강화가 임무 목록에 있다")
	# And the count never rides inside the sentence: mission text may not carry a
	# digit, which is what makes a separate progress field necessary at all.
	for row: Dictionary in main.quests():
		for digit: String in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]:
			_assert(not String(row["title"]).contains(digit),
				"임무 문장에 숫자가 없다: %s" % String(row["title"]))
