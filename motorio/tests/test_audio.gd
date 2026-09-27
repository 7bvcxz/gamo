extends SceneTree
## The sound bank and the files on disk have to be the same set.
##
## They are maintained in two places -- BANK and BEDS in Audio.gd, SOUNDS and
## BEDS in tools/build_sfx.py -- and this repository has been bitten three times
## by a list kept by hand in two places. A preload of a missing file is caught at
## parse time, but the other direction is silent: a sound the builder writes and
## nothing plays just sits in the export adding bytes, and a name renamed in one
## place and not the other is a sound that stops happening without anything
## failing.

var failures := 0

func _init() -> void:
	# The constants are read off the script rather than off an instance. Making
	# one and calling _ready() starts the looping beds, and a node added to root
	# from _init() is not in the tree yet -- so it plays nothing and logs two
	# engine errors on the way past. Nothing here needs a running mixer.
	const Audio := preload("res://scripts/Audio.gd")

	# Referenced by file, not by sound name: a sound is a list of takes since
	# Quality Pass 01, and `pick` is five files none of which is called pick.wav.
	var referenced: Dictionary[String, bool] = {}
	for name: String in Audio.BANK:
		var takes: Array = Audio.BANK[name]
		_assert(not takes.is_empty(), "%s 에 테이크가 하나 이상 있다" % name)
		for stream: AudioStream in takes:
			_assert(stream != null, "%s 뱅크에 스트림이 있다" % name)
			if stream != null:
				referenced[stream.resource_path] = true
		_assert(Audio.VOLUMES.has(name), "%s 에 볼륨이 지정돼 있다" % name)
		# Every sound is mixed somewhere real -- a bus name that is not in the
		# layout would quietly fall back to Master and escape every mix.
		_assert(Audio.BUS_OF.has(name), "%s 에 버스가 지정돼 있다" % name)
		_assert(AudioServer.get_bus_index(String(Audio.BUS_OF.get(name, ""))) >= 0,
			"%s 의 버스 %s 가 레이아웃에 있다" % [name, Audio.BUS_OF.get(name, "")])
	for name: String in Audio.BEDS:
		_assert(Audio.BEDS[name] != null, "%s 베드에 스트림이 있다" % name)
		if Audio.BEDS[name] != null:
			referenced[(Audio.BEDS[name] as Resource).resource_path] = true
		_assert(Audio.BED_CEILING.has(name), "%s 에 베드 상한이 지정돼 있다" % name)
		_assert(AudioServer.get_bus_index(String(Audio.BED_BUS.get(name, ""))) >= 0,
			"%s 베드의 버스가 레이아웃에 있다" % name)

	# The music sampler holds one more, outside the effects bank.
	const Music := preload("res://scripts/Music.gd")
	_assert(Music.NOTE != null, "음악 샘플이 있다")
	referenced[(Music.NOTE as Resource).resource_path] = true
	for path: String in Audio.extra_streams():
		referenced[path] = true

	# Nothing on disk that nobody plays -- in the folder or under it.
	var files: Array[String] = []
	_collect("res://assets/sfx", files)
	_assert(not files.is_empty(), "assets/sfx 를 열 수 있다")
	for path: String in files:
		_assert(referenced.has(path),
			"%s 를 재생하는 곳이 있다 (Audio.gd 뱅크나 Music.gd 에 없으면 파일을 지운다)" % path)

	# Every sound the builder makes is 22050Hz mono, and the beds are the only
	# long ones. A one-shot that grew to a second is a one-shot that overlaps
	# itself, which the voice pool cannot fix.
	for name: String in Audio.BANK:
		for stream: AudioStreamWAV in Audio.BANK[name]:
			_assert(stream.mix_rate == 22050, "%s 는 22050Hz" % name)
			_assert(stream.stereo == false, "%s 는 모노" % name)
			var seconds: float = stream.get_length()
			_assert(seconds > 0.0 and seconds <= 0.75,
				"%s 길이 %.3f초는 한 방 소리 범위 안" % [name, seconds])

	# Footsteps: the only sound that plays continuously, so it is the one where a
	# wrong level or a wrong cadence is not a detail. Two frames of the eight put
	# a boot down, and one sound per cycle would be a limp.
	_assert(Audio.BANK.has("step") and Audio.BANK.has("step_run"), "발소리 두 개가 뱅크에 있다")
	_assert(PlayerActor.STEP_FRAMES.size() == 2,
		"한 주기에 발이 두 번 닿는다 (%d)" % PlayerActor.STEP_FRAMES.size())
	for frame: int in PlayerActor.STEP_FRAMES:
		_assert(frame >= 0 and frame < PlayerActor.FRAMES,
			"발 닿는 프레임이 시트 안에 있다: %d" % frame)
	_assert(PlayerActor.STEP_FRAMES[0] != PlayerActor.STEP_FRAMES[1],
		"두 프레임이 서로 다르다")
	# Quieter than everything else, because it repeats four times a second while
	# every other sound is an event.
	var loudest: float = -99.0
	for name: String in Audio.VOLUMES:
		if name == "step" or name == "step_run":
			continue
		loudest = maxf(loudest, float(Audio.VOLUMES[name]))
	_assert(float(Audio.VOLUMES["step"]) < loudest - 6.0,
		"걷기 소리가 다른 어떤 소리보다 충분히 작다 (%.0f vs %.0f)"
		% [float(Audio.VOLUMES["step"]), loudest])
	_assert(float(Audio.VOLUMES["step_run"]) >= float(Audio.VOLUMES["step"]),
		"달릴 때가 걸을 때보다 작지 않다")

	if failures == 0:
		print("AUDIO_TEST: PASS")
	quit(failures)


func _collect(folder: String, into: Array[String]) -> void:
	var directory := DirAccess.open(folder)
	if directory == null:
		return
	for file: String in directory.get_files():
		if file.ends_with(".wav") or file.ends_with(".ogg"):
			into.append(folder.path_join(file))
	for sub: String in directory.get_directories():
		_collect(folder.path_join(sub), into)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		print("  FAIL: ", message)
		failures += 1
