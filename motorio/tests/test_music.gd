extends SceneTree
## The sequencer, and which screen asks for which score.
##
## None of this can be checked by looking at the game. A screenshot has no sound
## in it, and the two failures that matter here are both silent: a score that
## restarts every frame because it finished while its screen was still up, and a
## note struck twice because a loop reset its clock instead of wrapping it.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	const Music := preload("res://scripts/Music.gd")
	# No _ready(): without a voice pool the sequencer still keeps time, and a
	# node added to root from _init() is not really in the tree, so every play()
	# would log an engine error. The timing is what is being checked here.
	var music: Node = Music.new()

	# Scores are walked front to back, so the notes have to be in order.
	for name: String in Music.SCORES:
		var score: Dictionary = Music.SCORES[name]
		var previous: float = -1.0
		for note: Array in score["notes"]:
			_assert(float(note[0]) >= previous, "%s 악보가 박자 순으로 정렬돼 있다" % name)
			previous = float(note[0])
			_assert(float(note[0]) < float(score["bars"]),
				"%s 의 음표가 길이 안에 있다" % name)
			_assert(float(note[2]) > 0.0 and float(note[2]) <= 1.0,
				"%s 의 세기가 0~1 범위" % name)

	# A loop wraps rather than resetting: run the title score for two full passes
	# and count the strikes. Resetting the clock to zero on each wrap loses
	# whatever the frame overshot by, which at low frame rates drops notes.
	var title: Dictionary = Music.SCORES["title"]
	var length: float = float(title["bars"]) * Music.BEAT
	var per_pass: int = int(title["notes"].size())
	music.play_score("title")
	# Stopping just short of each wrap keeps the count exact: a run that overruns
	# by a frame has started the next pass and the number means nothing.
	_run_for(music, length - 0.05, 0.037)
	_assert(music.strikes == per_pass,
		"한 바퀴에 음표가 정확히 한 번씩 울린다 (%d/%d)" % [music.strikes, per_pass])
	_run_for(music, length, 0.037)
	_assert(music.strikes == per_pass * 2,
		"두 바퀴째도 정확히 한 번씩 (%d/%d)" % [music.strikes, per_pass * 2])
	_assert(music.is_playing_score("title"), "반복 악보는 계속 재생된다")

	# A one-shot stops on its own, and asking again while the same screen is up
	# does not restart it. This is the failure the request/playing split exists
	# for -- a caller driven from the state says "play result" every frame.
	music.stop()
	music.strikes = 0
	music.play_score("result")
	var result: Dictionary = Music.SCORES["result"]
	_run_for(music, float(result["bars"]) * Music.BEAT + 0.2, 0.037)
	_assert(not music.is_playing_score("result"), "한 번짜리 악보는 스스로 끝난다")
	var once: int = music.strikes
	_assert(once == int(result["notes"].size()), "한 바퀴만 울렸다 (%d)" % once)
	# Keep asking, as the summary screen would.
	for index in 40:
		music.play_score("result")
		music._process(0.037)
	_assert(music.strikes == once, "화면이 그대로면 다시 시작하지 않는다 (%d)" % music.strikes)

	# Moving to another screen clears the request, so coming back replays it.
	music.stop()
	music.play_score("result")
	music._process(0.001)
	_assert(music.strikes > once, "다른 화면을 거쳐 오면 다시 울린다")

	music.free()

	# And the wiring: which screen asks for which score, and which room. Driven
	# from the state every frame through the audio manager, so this is checked on
	# a real Main rather than by reading the table.
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	_assert(main.music.requested_score() == "title", "타이틀 화면이 타이틀 곡을 부른다")
	main._start_run()
	main.finish_tutorial()
	main.state = main.State.PLAY
	main._update_ambience(0.016)
	_assert(main.music.requested_score() == "", "플레이 중에는 곡이 없다")
	# The shelter is the one room the game plays music in, and it does it while
	# the state is still PLAY -- the score follows the place, not the screen.
	main.open_room()
	main._update_ambience(0.016)
	_assert(main.music.requested_score() == "home", "숙소에서는 숙소 곡이 흐른다")
	# And a card on screen is louder than a room: she falls asleep in there and
	# the summary has its own score.
	main._finish_run()
	main._update_ambience(0.016)
	_assert(main.music.requested_score() == "result", "정산 화면이 정산 곡을 부른다")
	main.close_room()
	main.state = main.State.PLAY
	main._update_ambience(0.016)
	_assert(main.music.requested_score() == "", "밖으로 나오면 다시 조용해진다")
	main.clear_save()
	main.queue_free()

	if failures == 0:
		print("MUSIC_TEST: PASS")
	quit(failures)

func _run_for(music: Node, seconds: float, step: float) -> void:
	var elapsed: float = 0.0
	while elapsed < seconds:
		music._process(step)
		elapsed += step

func _assert(condition: bool, message: String) -> void:
	if not condition:
		print("  FAIL: ", message)
		failures += 1
