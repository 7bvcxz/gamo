extends "res://tests/framework/test_case.gd"

## The decision memo (Step 101, DECISION.md) keeps its promises: it is marked
## unapproved, lays out the three ways forward, leaves every owner choice
## unticked, separates C's and E's possible next steps, says what is shared
## and what never is, and points to the pages where both tracks stay playable.
## (A test cannot judge the recommendation; it can hold the memo to not
## deciding on the owner's behalf.)

const MEMO := "res://DECISION.md"


func _memo() -> String:
	return FileAccess.get_file_as_string(MEMO)


func test_it_is_marked_unapproved() -> void:
	var m := _memo()
	assert_true(m.length() > 2000, "the memo is there")
	assert_true(m.contains("**상태: 승인 대기 (UNAPPROVED).**"), "unapproved, at the top")
	assert_true(m.find("승인 대기") < 400, "before anything else")


func test_three_ways_and_no_choice_made() -> void:
	var m := _memo()
	for way: String in ["A. 두 개의 독립 게임", "B. 둘 다 살리고 하나를 첫 출시 후보로", "C. 하나로 합치기"]:
		assert_true(m.contains(way), "the option: " + way)
	var checkpoint := m.substr(m.find("## 승인 확인"))
	assert_eq(checkpoint.count("- [ ]"), 3, "three choices for the owner")
	assert_false(m.contains("- [x]") or m.contains("- [X]"), "none ticked on the owner's behalf")
	assert_true(m.contains("(승인 아님)"), "the preference says it is not an approval")


func test_human_judgments_stay_pending() -> void:
	var m := _memo()
	assert_true(m.contains("15분·30분 점수: **없음.**"), "no human 15/30-minute scores claimed")
	assert_true(m.contains("사람의 점수를 지어내지 않았다"), "and says it invented none")
	assert_true(m.contains("**예측**"), "forecasts are labelled as such")


func test_separate_next_steps_and_a_shared_toolkit_boundary() -> void:
	var m := _memo()
	for n in range(1, 6):
		assert_true(m.contains("**C-%d " % n), "C step %d" % n)
		assert_true(m.contains("**E-%d " % n), "E step %d" % n)
	assert_true(m.contains("게임마다 따로(절대 공유하지 않음)"), "what is never shared")
	for never: String in ["config/name", "저장 형식", "배포 폴더", "결제"]:
		assert_true(m.substr(m.find("## 5.")).contains(never), "kept per game: " + never)


func test_links_to_where_both_tracks_stay_playable() -> void:
	var m := _memo()
	for page: String in ["momonium-experiments/", "play15.html", "report30.html", "tracks.html", "compare.html"]:
		assert_true(m.contains("https://7bvcxz.github.io/gamo/momonium-experiments/" + page.trim_prefix("momonium-experiments/")), "links " + page)
	for id: String in ["rock", "rock-plus", "tycoon", "tycoon-plus"]:
		assert_true(LabRegistry.routable(id), "%s still opens in the Lab" % id)
