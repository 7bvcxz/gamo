extends SceneTree

## The opening: seven panels, three of which shake, once per new run.
##
## What this is really guarding is the join between the table and the files. The
## panels, their shake and their line live in one row each so they cannot go out
## of step with each other -- but they can still go out of step with what is on
## disk, and a cutscene that preloads a picture nobody exported is a game that
## does not start.

## The script rather than the node: cutscene_rect is static and takes the
## screen size, so nothing here needs a HUD that has been laid out.
const HUDScript := preload("res://scripts/HUD.gd")

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
	_test_plays_once()
	_test_timing()
	_test_shake()
	_test_caption(main)
	_test_skip()
	if failures == 0:
		print("PASS test_cutscene")
	else:
		print("FAIL test_cutscene (%d)" % failures)
	quit(failures)


# --- The caption ---------------------------------------------------------------

func _test_caption(main: Node2D) -> void:
	var hud: Node = main.hud
	for index in Defs.CUTSCENE_PANELS.size():
		var panel: Dictionary = Defs.CUTSCENE_PANELS[index]
		var line: String = String(panel["line"])
		var lines: Array[Dictionary] = Defs.cutscene_runs(index)
		# One or two lines: a single clause says what the picture already says,
		# and three is a page.
		_assert(lines.size() >= 1 and lines.size() <= 2,
			"%d장은 한두 줄이다: %d줄" % [index + 1, lines.size()])
		# The runs put the sentence back together exactly. A splitter that drops a
		# character shows up as a missing particle, which reads as a typo.
		var rebuilt := ""
		for row: Dictionary in lines:
			for run: Dictionary in row["runs"]:
				rebuilt += String(run["text"])
		_assert(rebuilt == line.replace("\n", ""),
			"%d장의 조각을 이으면 원문이다" % (index + 1))
		# Every marked word is actually found in the line, or it is a word the
		# player will never see move.
		var marked: Array = panel.get("hot", [])
		_assert(not marked.is_empty(), "%d장에 강조할 낱말이 있다" % (index + 1))
		for word: String in marked:
			_assert(line.contains(String(word)),
				"%d장의 강조 '%s'가 문장 안에 있다" % [index + 1, word])
		var hot_runs := 0
		for row: Dictionary in lines:
			for run: Dictionary in row["runs"]:
				if bool(run["hot"]):
					hot_runs += 1
		_assert(hot_runs == marked.size(),
			"%d장에서 표시한 만큼만 강조된다: %d/%d" % [index + 1, hot_runs, marked.size()])

	# Two marked words never move together, or the line reads as sliding rather
	# than as the words shaking.
	var a: Vector2 = Defs.cutscene_word_shake(0, 1.37)
	var b: Vector2 = Defs.cutscene_word_shake(1, 1.37)
	_assert(a.distance_to(b) > 0.2, "낱말마다 따로 흔들린다: %s vs %s" % [str(a), str(b)])
	_assert(Defs.cutscene_word_shake(0, 1.37) == a, "같은 시각에는 같은 자리다")
	_assert(a.length() <= Defs.CUTSCENE_HOT_SHAKE * 1.01,
		"흔들림이 정해진 폭을 넘지 않는다: %.2f" % a.length())

	# And it fits. Measured in the faces it will be drawn in -- the display face
	# is wider than the body face, so a line measured in the wrong one comes out
	# off-centre by exactly the difference and can run off the edge.
	for shape: Vector2 in [Vector2(960, 540), Vector2(1280, 720), Vector2(390, 844),
			Vector2(844, 390)]:
		hud.size = shape
		for index in Defs.CUTSCENE_PANELS.size():
			var point: int = int(hud.call("cutscene_text_size", index))
			var width: float = hud.call("cutscene_text_width", index, point)
			_assert(width <= shape.x,
				"%.0fx%.0f 화면에서 %d장 문구가 넘치지 않는다: %.0f / %.0f (%dpt)"
					% [shape.x, shape.y, index + 1, width, shape.x, point])
			_assert(point >= 10, "%.0f 폭에서도 읽을 만한 크기다: %dpt" % [shape.x, point])

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

# --- The table and the files ------------------------------------------------

func _test_table() -> void:
	var panels: Array[Dictionary] = Defs.CUTSCENE_PANELS
	_assert(panels.size() >= 6 and panels.size() <= 8,
		"6~8장 사이다 (%d장)" % panels.size())
	# The directory, not a written-out count. A panel added to assets and not to
	# the table is a picture nobody sees; the other way round does not parse.
	var directory := DirAccess.open("res://assets/cutscene")
	_assert(directory != null, "assets/cutscene 를 열 수 있다")
	var on_disk := 0
	if directory != null:
		for file: String in directory.get_files():
			if file.ends_with(".webp"):
				on_disk += 1
	_assert(on_disk == panels.size(),
		"파일 수와 표가 같다 (파일 %d, 표 %d)" % [on_disk, panels.size()])
	var shaken := 0
	for index in panels.size():
		var panel: Dictionary = panels[index]
		_assert(panel["art"] != null, "%d번 그림이 로드된다" % (index + 1))
		_assert(String(panel["line"]).strip_edges() != "", "%d번 대사가 있다" % (index + 1))
		if float(panel["shake"]) > 0.0:
			shaken += 1
	_assert(shaken >= 1 and shaken < panels.size(),
		"흔들리는 장면은 일부다 (%d/%d) — 계속 흔들리면 흔들림이 아니다"
			% [shaken, panels.size()])

# --- When it plays ----------------------------------------------------------

func _test_plays_once() -> void:
	main.resumed = false
	main.state = main.State.TITLE
	main._leave_title()
	_assert(main.state == main.State.OPENING, "새 게임은 컷씬으로 들어간다")
	_assert(main.cutscene_panel == 0, "첫 장부터")

	# A player who closed the tab mid-run does not need to be told again that
	# Earth is gone.
	main.resumed = true
	main.state = main.State.TITLE
	main._leave_title()
	_assert(main.state == main.State.PLAY, "이어하기는 컷씬을 건너뛴다")
	main.resumed = false

# --- Timing -----------------------------------------------------------------

func _test_timing() -> void:
	main.state = main.State.OPENING
	main.cutscene_panel = 0
	main.cutscene_time = 0.0
	var span: float = Defs.cutscene_panel_seconds()
	_assert(span > 3.0 and span < 8.0, "한 장이 %.1f초" % span)
	# Ticked synchronously, with no yield: the engine's own _process would run
	# the same clock and the measurement would come out short.
	var elapsed: float = 0.0
	var guard := 0
	while main.state == main.State.OPENING and guard < 100000:
		main._process_cutscene(1.0 / 60.0)
		elapsed += 1.0 / 60.0
		guard += 1
	var expected: float = span * float(Defs.CUTSCENE_PANELS.size())
	_assert(main.state == main.State.PLAY, "끝나면 게임이 시작된다")
	_assert(absf(elapsed - expected) < 0.5,
		"전체 %.1f초 (기대 %.1f초)" % [elapsed, expected])
	# Half a minute or so. Longer than this and a player who wants to play is
	# watching a slideshow; shorter and there is no time to read a line.
	_assert(expected > 20.0 and expected < 45.0, "오프닝 전체가 %.0f초" % expected)

# --- Shake ------------------------------------------------------------------

func _test_shake() -> void:
	var panels: Array[Dictionary] = Defs.CUTSCENE_PANELS
	var loud: int = -1
	var calm: int = -1
	for index in panels.size():
		if float(panels[index]["shake"]) > 0.0 and loud < 0:
			loud = index
		if is_equal_approx(float(panels[index]["shake"]), 0.0) and calm < 0:
			calm = index
	_assert(loud >= 0 and calm >= 0, "흔들리는 장면과 가만한 장면이 둘 다 있다")
	if loud < 0 or calm < 0:
		return
	_assert(Defs.cutscene_shake(calm, 0.5) == Vector2.ZERO, "가만한 장면은 움직이지 않는다")
	var early: Vector2 = Defs.cutscene_shake(loud, 0.20)
	var late: Vector2 = Defs.cutscene_shake(loud, Defs.cutscene_panel_seconds() - 0.05)
	_assert(early.length() > 0.5, "충격이 오는 순간에는 실제로 움직인다 (%.2f)" % early.length())
	_assert(late.length() < early.length(), "그리고 잦아든다")
	# Deterministic, or the test above is measuring noise.
	_assert(Defs.cutscene_shake(loud, 0.20) == early, "같은 시각이면 같은 값이다")
	# Bounded: a picture that leaves the screen is not a shake, it is a fault.
	var worst: float = 0.0
	for step in 400:
		var offset: Vector2 = Defs.cutscene_shake(loud, float(step) * 0.01)
		worst = maxf(worst, offset.length())
	_assert(worst < 20.0, "화면 밖으로 나가지 않는다 (최대 %.1f px)" % worst)
	_assert(Defs.cutscene_shake(-1, 0.5) == Vector2.ZERO, "범위 밖 인덱스는 0이다")
	_assert(Defs.cutscene_shake(panels.size(), 0.5) == Vector2.ZERO, "위쪽 범위도")

	# The picture has to cover the screen at every instant of every panel. At
	# exactly 16:9 a covering fit is the screen exactly, so a shake of any size
	# slides it off an edge unless the fit is grown to allow for it -- and the
	# black bar it leaves would run down the side of the frame the shake exists
	# to make feel solid.
	var screens: Array[Vector2] = [
		Vector2(1280, 720),      # the shape the panels were cut to
		Vector2(1920, 1080),
		Vector2(390, 844),       # a phone held upright
		Vector2(1024, 768),      # taller than 16:9
	]
	var uncovered := 0
	for screen: Vector2 in screens:
		for index in panels.size():
			for step in 120:
				var elapsed: float = float(step) * Defs.cutscene_panel_seconds() / 120.0
				var rect: Rect2 = HUDScript.cutscene_rect(screen, index, elapsed)
				if not rect.encloses(Rect2(Vector2.ZERO, screen)):
					uncovered += 1
	_assert(uncovered == 0, "모든 화면비·모든 순간에 화면을 덮는다 (%d건 실패)" % uncovered)

# --- Getting out of it ------------------------------------------------------

func _test_skip() -> void:
	main.state = main.State.OPENING
	main.cutscene_panel = 0
	main.cutscene_time = 2.0
	main._advance_cutscene()
	_assert(main.cutscene_panel == 1 and is_equal_approx(main.cutscene_time, 0.0),
		"넘기면 다음 장이 처음부터")
	_assert(main.state == main.State.OPENING, "아직 컷씬 안이다")
	main._end_cutscene()
	_assert(main.state == main.State.PLAY, "건너뛰면 바로 게임이다")
	# Advancing off the end is the same as skipping, rather than an index that
	# walks past the table.
	main.state = main.State.OPENING
	main.cutscene_panel = Defs.CUTSCENE_PANELS.size() - 1
	main._advance_cutscene()
	_assert(main.state == main.State.PLAY, "마지막 장 다음은 게임이다")
