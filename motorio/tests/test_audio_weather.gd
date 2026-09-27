extends SceneTree

## The weather you hear, the opening's sound, and the cold (Quality Pass 01).
##
## Three playtest complaints, each held here by a number:
##
## * "브금이라기보다 굉음이 계속 반복된다" -- the wind bed was 26-150 Hz. Its low
##   end is measured off the file on disk, so a rebuilt wind that drifts back
##   down fails here rather than in someone's ears.
## * "얼어붙을 때 반복되는 괴음" -- the cold was a looping shimmer. Cold is now a
##   breath now and then and a crackle of ice when it gets worse; what is held
##   is that it never comes every second or two.
## * The opening -- one cue a panel, no score under the story, and nothing of it
##   left playing into the snow.

var failures := 0

const Audio := preload("res://scripts/Audio.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_wind_has_no_drone()
	await _test_cold_does_not_spam()
	await _test_gusts()
	await _test_day_and_night()
	await _test_opening()
	if failures == 0:
		print("PASS test_audio_weather")
	else:
		print("FAIL test_audio_weather (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

## 16-bit PCM straight from the source file. The imported resource is
## compressed, and a test that decodes that as PCM measures its own decoder.
func _pcm(path: String) -> PackedFloat32Array:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var out := PackedFloat32Array()
	var at := 12
	while at + 8 <= bytes.size():
		var id: String = bytes.slice(at, at + 4).get_string_from_ascii()
		var size: int = bytes.decode_u32(at + 4)
		if id == "data":
			var count: int = size / 2
			out.resize(count)
			for i in count:
				out[i] = float(bytes.decode_s16(at + 8 + i * 2)) / 32768.0
			return out
		at += 8 + size + (size % 2)
	return out

## The share of a signal's energy below `cutoff`, through a second-order
## low-pass -- the same measure tools/audio_audit.py uses.
func _low_share(samples: PackedFloat32Array, cutoff: float) -> float:
	var w0: float = TAU * cutoff / 22050.0
	var alpha: float = sin(w0) / (2.0 * 0.7071)
	var c: float = cos(w0)
	var a0: float = 1.0 + alpha
	var b0: float = (1.0 - c) / 2.0 / a0
	var b1: float = (1.0 - c) / a0
	var a1: float = -2.0 * c / a0
	var a2: float = (1.0 - alpha) / a0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	var low := 0.0
	var total := 0.0
	for x: float in samples:
		var y: float = b0 * x + b1 * x1 + b0 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		low += y * y
		total += x * x
	return low / maxf(total, 1e-9)

func _test_wind_has_no_drone() -> void:
	for name: String in ["wind", "cold"]:
		var samples: PackedFloat32Array = _pcm("res://assets/sfx/%s.wav" % name)
		_assert(samples.size() > 22050, "%s 를 읽었다 (%d 샘플)" % [name, samples.size()])
		var below150: float = _low_share(samples, 150.0)
		var below100: float = _low_share(samples, 100.0)
		# The old wind: 84% and 62%.
		_assert(below150 < 0.35, "%s 의 150Hz 아래가 35%% 미만이다 (%.0f%%)" % [name, below150 * 100.0])
		_assert(below100 < 0.15, "%s 의 100Hz 아래가 15%% 미만이다 (%.0f%%)" % [name, below100 * 100.0])
		# The loop closes: last sample and first are neighbours.
		_assert(absf(samples[samples.size() - 1] - samples[0]) < 0.08,
			"%s 의 루프 이음새가 튀지 않는다" % name)
	# The loop is the whole file. It was set to the compressed data's byte count
	# over two -- a fifth of the file under QOA -- so the old wind looped every
	# 1.5 seconds with a jump at the seam, whatever the recipe said.
	for name: String in Audio.BEDS:
		var stream: AudioStreamWAV = Audio.BEDS[name]
		var frames: int = Audio.loop_frames(stream)
		_assert(absi(frames - int(stream.get_length() * stream.mix_rate)) <= 1,
			"%s 는 파일 끝에서 돈다 (%d 프레임, %.2f초)" % [name, frames, float(frames) / stream.mix_rate])
		# The weather is heard all day, so its loops have to be long; the room's
		# are heard for a night and under a lullaby.
		if name == "wind" or name == "cold":
			_assert(float(frames) / stream.mix_rate > 10.0,
				"%s 의 한 바퀴는 10초가 넘는다 (%.2f초)" % [name, float(frames) / stream.mix_rate])
	var live: Node = Audio.new()
	root.add_child(live)
	await process_frame
	for name: String in Audio.BEDS:
		var bed: AudioStreamWAV = Audio.BEDS[name]
		_assert(bed.loop_end == Audio.loop_frames(bed) and bed.loop_mode == AudioStreamWAV.LOOP_FORWARD,
			"%s 베드의 실제 루프 끝이 파일 끝이다 (%d)" % [name, bed.loop_end])
	live.free()
	# Two loops that do not divide: the pair lines up again only after minutes.
	var wind: float = (Audio.BEDS["wind"] as AudioStream).get_length()
	var cold: float = (Audio.BEDS["cold"] as AudioStream).get_length()
	_assert(not is_equal_approx(fmod(wind, cold), 0.0) and not is_equal_approx(fmod(cold, wind), 0.0),
		"바람과 냉기 루프의 길이가 서로 나누어떨어지지 않는다 (%.1f / %.1f)" % [wind, cold])

func _audio() -> Node:
	var audio: Node = Audio.new()
	root.add_child(audio)
	await process_frame
	return audio

## A minute in the worst cold, stepped the way the game steps it.
func _run_cold(audio: Node, exposure: float, seconds: float) -> void:
	var dt := 0.05
	for step in int(seconds / dt):
		audio.advance(dt)
		audio.apply("play", Zone.FIELD, exposure, 0.3, dt)

func _test_cold_does_not_spam() -> void:
	var audio: Node = await _audio()
	_run_cold(audio, 0.95, 60.0)
	var breaths: int = int(audio.started.get("breath", 0))
	_assert(breaths >= 8 and breaths <= 14,
		"위험한 추위 1분에 숨이 8~14번이다 — 1~2초마다가 아니다 (%d)" % breaths)
	var shortest := INF
	for gap: float in audio.breath_gaps:
		shortest = minf(shortest, gap)
	_assert(shortest >= 4.4, "숨 사이는 가장 짧아도 4.4초다 (%.1f)" % shortest)
	_assert(int(audio.started.get("frost", 0)) == 1, "얼음 소리는 추위가 한 단계 깊어질 때 한 번이다")
	# Warm again: silence.
	var before: int = int(audio.started.get("breath", 0))
	_run_cold(audio, 0.1, 30.0)
	_assert(int(audio.started.get("breath", 0)) == before, "따뜻하면 숨소리가 없다")
	# And a middling cold breathes less often than the worst.
	audio.breath_gaps.clear()
	_run_cold(audio, 0.5, 60.0)
	var mild: int = int(audio.started.get("breath", 0)) - before
	_assert(mild >= 4 and mild < breaths, "덜 추우면 덜 자주 (%d < %d)" % [mild, breaths])
	_assert(int(audio.started.get("frost", 0)) == 2, "다시 추워질 때 얼음 소리가 한 번 더 난다")
	# Indoors: none of it.
	var inside: int = int(audio.started.get("breath", 0))
	var dt := 0.05
	for step in 400:
		audio.advance(dt)
		audio.apply("play", Zone.HOME, 0.95, 0.3, dt)
	_assert(int(audio.started.get("breath", 0)) == inside, "숙소 안에서는 추위 소리가 없다")
	audio.free()

func _test_gusts() -> void:
	var audio: Node = await _audio()
	var dt := 0.05
	for step in int(120.0 / dt):
		audio.advance(dt)
		audio.apply("play", Zone.FIELD, 0.0, 0.3, dt)
	_assert(audio.gusts >= 6 and audio.gusts <= 18,
		"낮 2분에 돌풍이 무작위로 6~18번 온다 (%d)" % audio.gusts)
	var outside: int = audio.gusts
	for step in int(60.0 / dt):
		audio.advance(dt)
		audio.apply("play", Zone.HOME, 0.0, 0.3, dt)
	_assert(audio.gusts == outside, "숙소 안에는 돌풍이 없다")
	audio.free()

func _settle(audio: Node, day: float) -> void:
	for step in 120:
		audio.advance(0.05)
		audio.apply("play", Zone.FIELD, 0.0, day, 0.05)

func _test_day_and_night() -> void:
	_assert(Audio.evening_of(0.3) == 0.0, "한낮은 저녁이 아니다")
	_assert(Audio.evening_of(1.0) == 1.0, "하루 끝은 밤이다")
	var audio: Node = await _audio()
	_settle(audio, 0.3)
	var day: float = audio.bed_level("wind")
	_settle(audio, 1.0)
	var night: float = audio.bed_level("wind")
	_assert(absf(day - Audio.WIND_DAY) < 0.03, "낮에는 가벼운 바람 (%.2f)" % day)
	_assert(night > day + 0.1, "밤에는 조금 더 센 바람 (%.2f > %.2f)" % [night, day])
	audio.free()

## The real opening, driven through Main: every panel plays its own cue once,
## no score runs under the story, and nothing is left playing once she is in
## the snow.
func _test_opening() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_new_run()
	var audio: Node = main.audio
	var dt := 1.0 / 30.0
	var frames: int = int(Defs.cutscene_panel_seconds() * float(Defs.CUTSCENE_PANELS.size()) / dt) + 30
	var scored := false
	for step in frames:
		if main.state != main.State.OPENING:
			break
		main._process(dt)
		if main.music.requested_score() != "":
			scored = true
	_assert(main.state != main.State.OPENING, "오프닝이 끝난다")
	_assert(not scored, "이야기 밑에는 곡이 없다")
	for index in Defs.CUTSCENE_PANELS.size():
		var name: String = String(Defs.CUTSCENE_PANELS[index].get("cue", ""))
		if name.is_empty():
			continue
		_assert(int(audio.started.get("cue_" + name, 0)) == 1,
			"%d번째 장면의 소리(%s)가 한 번 울린다" % [index + 1, name])
	for step in 60:
		main._process(dt)
	_assert(not (audio.get("_cue") as AudioStreamPlayer).playing, "눈밭에 내려오면 이야기 소리는 멎어 있다")
	_assert(main.music.requested_score() == "", "게임이 시작되면 곡이 이어지지 않는다")
	main.clear_save()
	main.free()
