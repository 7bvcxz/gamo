extends "res://tests/framework/test_case.gd"

## The local run record: play time, actions, upgrades with their times, idle
## intervals (before the first action too), the three-minute snapshot, and
## the JSON / CSV a tester downloads. Nothing is written anywhere.


func test_play_time_and_actions() -> void:
	var s := LabSession.new("island", "0.86.0")
	s.advance(2.0)
	s.action("button")
	s.advance(1.5)
	s.action("tap", {"x": 3})
	s.action("tap")
	assert_near(s.active_ms, 3500.0, 0.01, "play time")
	assert_eq(s.action_count(), 3, "three actions")
	assert_eq(s.counts, {"button": 1, "tap": 2}, "by kind")
	assert_eq(s.events[1]["x"], 3, "details kept")
	assert_eq(s.events[1]["t_ms"], 3500, "when")


func test_idle_intervals() -> void:
	var s := LabSession.new("rock")
	s.advance(7.0)
	s.action("tap")
	assert_eq(s.idle, [[0, 7000]], "seven seconds before the first tap is idle")
	s.advance(3.0)
	s.action("tap")
	assert_eq(s.idle.size(), 1, "three seconds is not")
	s.advance(12.0)
	assert_eq(s.idle_intervals(), [[0, 7000], [10000, 22000]], "the open interval counts at the end")
	var sum := s.summary()
	assert_eq(sum["idle_seconds"], 19.0, "idle total")
	assert_eq(sum["engaged_seconds"], 3.0, "engaged = play - idle")
	assert_eq(sum["longest_idle_s"], 12.0, "longest")


func test_upgrades_and_milestones() -> void:
	var s := LabSession.new("tree")
	s.advance(14.0)
	s.action("button")
	s.upgrade(1, 10)
	s.advance(20.0)
	s.action("button")
	s.upgrade(2, 25, {"shape": "branching"})
	s.milestone("canopy")
	var sum := s.summary()
	assert_eq(sum["first_upgrade_s"], 14.0, "time to the first upgrade")
	assert_eq(sum["seconds_between_upgrades"], [14.0, 20.0], "gaps")
	assert_eq((sum["upgrades"] as Array)[1]["shape"], "branching", "details")
	assert_eq((sum["milestones"] as Array)[0]["name"], "canopy", "milestone")
	assert_eq(sum["actions"], 2, "an upgrade is not counted again as an action")


func test_three_minute_snapshot_is_frozen() -> void:
	var s := LabSession.new("island")
	s.metric("level", 1)
	for i in 179:
		s.advance(1.0)
	assert_eq(s.summary()["at_3min"], null, "not yet")
	s.metric("level", 4)
	s.advance(1.0)
	var at: Dictionary = s.summary()["at_3min"]
	assert_eq(at["active_seconds"], 180.0, "taken at 3:00")
	assert_eq(at["metrics"]["level"], 4, "the numbers then")
	s.metric("level", 9)
	s.advance(60.0)
	assert_eq(s.summary()["at_3min"]["metrics"]["level"], 4, "and kept as it was")
	assert_eq(s.summary()["metrics"]["level"], 9, "while the run goes on")


func test_fifteen_and_thirty_minute_snapshots() -> void:
	# Step 94: the C/E tracks' longer sessions keep the protocol's checkpoints.
	var s := LabSession.new("rock-plus")
	s.metric("rock", 1)
	for i in 899:
		s.advance(1.0)
	assert_true(s.summary()["at_3min"] != null, "3:00 is in")
	assert_eq(s.summary()["at_15min"], null, "15:00 not yet")
	s.metric("rock", 12)
	s.advance(1.0)
	var at: Dictionary = s.summary()["at_15min"]
	assert_eq(at["active_seconds"], 900.0, "taken at 15:00")
	assert_eq(at["metrics"]["rock"], 12, "the numbers then")
	assert_true(at.has("fps"), "with the frame rate then")
	s.advance(900.0)
	assert_eq(s.summary()["at_30min"]["active_seconds"], 1800.0, "and at 30:00")
	assert_eq(s.summary()["at_15min"]["metrics"]["rock"], 12, "each kept as it was")


func test_actions_per_minute_and_the_longest_wait() -> void:
	var s := LabSession.new("rock", "", 0.0)
	s.variant = "hold"
	s.run = 2
	for i in 3:
		s.action("hit")
	s.advance(61.0)
	s.action("hit")
	s.upgrade(1, 20)
	s.advance(130.0)
	var sum := s.summary()
	assert_eq(sum["actions_per_minute"], [3, 1, 0, 0], "three in minute 0, one in minute 1, none since (up to 3:11)")
	assert_eq(sum["longest_upgrade_wait_s"], 130.0, "the wait still open is the longest (130 s > the first 61 s)")
	assert_eq(sum["variant"], "hold", "which alternative")
	assert_eq(sum["run"], 2, "which run of the visit")


func test_pauses_are_recorded() -> void:
	var s := LabSession.new("island")
	s.paused("hidden")
	s.resumed("hidden")
	assert_eq(s.pauses, 1, "one pause")
	assert_eq(s.events[0]["kind"], "pause", "logged")
	assert_eq(s.events[1]["reason"], "hidden", "with its reason")


func test_json_and_csv() -> void:
	var s := LabSession.new("rock", "0.86.0", 1793000000.0)
	s.advance(5.5)
	s.action("tap", {"damage": 3})
	s.upgrade(1, 15, {"note": "a, b"})
	s.metric("rocks", 2)
	var parsed: Variant = JSON.parse_string(s.to_json())
	assert_true(parsed is Dictionary, "the JSON parses")
	assert_eq((parsed as Dictionary)["experiment"], "rock", "names the experiment")
	assert_eq((parsed as Dictionary)["metrics"]["rocks"], 2.0, "metrics")
	var csv := s.to_csv()
	var lines := csv.strip_edges().split("\n")
	assert_eq(lines[0], "t_seconds,kind,detail", "header")
	assert_eq(lines[1], "5.5,tap,damage=3", "an action row")
	assert_true(lines[2].begins_with("5.5,upgrade,\""), "a detail with a comma is quoted: %s" % lines[2])
	assert_true(csv.contains("summary,active_seconds=5.5"), "the summary rows")
	assert_true(csv.contains("metric,rocks=2"), "the metric rows")
	assert_true(s.file_stem().begins_with("funlab-rock-"), "file name: %s" % s.file_stem())


func test_nothing_is_written() -> void:
	var before := _user_files()
	var s := LabSession.new("island")
	s.advance(3.0)
	s.action("tap")
	s.to_json()
	s.to_csv()
	LabWeb.download(s.to_csv(), "x.csv", "text/csv")
	assert_eq(_user_files(), before, "user:// unchanged")


func _user_files() -> Array:
	var out: Array = []
	var d := DirAccess.open("user://")
	if d == null:
		return out
	for f: String in d.get_files():
		out.append(f)
	return out
