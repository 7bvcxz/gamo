extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	for character in ["한", "글", "체", "온", "고", "양", "이"]:
		_assert(UIFont.FONT.has_char(character.unicode_at(0)), "embedded font contains '%s'" % character)
	_assert(main.tutorial_title() == "정비공 이동", "quick start title is Korean")
	_assert(main.tutorial_detail().contains("오른쪽 이동 휠"), "mobile movement help is Korean")
	_assert(main.quest_title() == "1  첫 상자 납품", "campaign title is Korean")
	_assert(main.quest_detail().contains("금색 투입구"), "campaign instructions are Korean")
	_assert((main.get_node("UI/SurvivalStatus") as Label).text.contains("체온"), "survival status is Korean")
	_assert(not (main.tutorial_title() + main.tutorial_detail() + main.quest_title() + main.quest_detail()).contains("�"), "descriptions contain no replacement glyph")
	if failures == 0:
		print("KOREAN_UI_TEST: PASS")
	quit(failures)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("KOREAN_UI_TEST: FAIL - " + message)
		failures += 1
