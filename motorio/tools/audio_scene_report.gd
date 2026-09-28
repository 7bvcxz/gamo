extends SceneTree

## What each scene sounds like, as numbers (Quality Pass 01).
##
## Nobody on this side of the screen can listen, so the questions a playtest asks
## -- too loud? too much low end? a loop you can hear? the same sound over and
## over? -- are asked of what the audio manager is actually doing, frame by
## frame, through the real game: which beds are up and how far, which sounds
## start and how often, how many play at once, and an estimate of the level and
## the low-frequency share of the whole mix, from each playing file's measured
## RMS and low end (read from the source WAVs, like test_audio_weather).
##
##   godot --headless --path motorio --script res://tools/audio_scene_report.gd [-- --out report.md]
##
## Headless is enough: nothing here is drawn.
const Audio := preload("res://scripts/Audio.gd")

var main: Node2D
var audio: Node
var out_path := ""
var _file_stats: Dictionary = {}
var rows: Array[String] = []

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out":
			out_path = args[i + 1]
	_run.call_deferred()

# --- Measuring the files -----------------------------------------------------------

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

## [rms as linear power, share of energy below 150 Hz] for a stream's file.
func _stats(stream: AudioStream) -> Array:
	if stream == null:
		return [0.0, 0.0]
	var path: String = stream.resource_path
	if _file_stats.has(path):
		return _file_stats[path]
	var samples: PackedFloat32Array = _pcm(path)
	var w0: float = TAU * 150.0 / 22050.0
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
	var power: float = total / maxf(1.0, float(samples.size()))
	var result: Array = [power, low / maxf(total, 1e-12)]
	_file_stats[path] = result
	return result

# --- Sampling a frame ----------------------------------------------------------------

func _bus_gain(bus: String) -> float:
	var gain: float = audio.bus_level(bus)
	# Sub-buses also go through their parent.
	if bus in ["Machine", "Character", "Environment"]:
		gain *= audio.bus_level("SFX")
	return gain

## Estimated mix power (linear) and its low-frequency power, this frame.
func _frame_power() -> Array:
	var power := 0.0
	var low := 0.0
	for voice: Dictionary in audio.get("_flat") + audio.get("_world"):
		if float(voice["ends"]) <= audio.clock:
			continue
		var player: Node = voice["player"]
		var stream: AudioStream = player.get("stream")
		var s: Array = _stats(stream)
		var gain: float = db_to_linear(float(player.get("volume_db"))) * _bus_gain(String(player.get("bus")))
		var p: float = float(s[0]) * gain * gain
		power += p
		low += p * float(s[1])
	for name: String in Audio.BEDS:
		var level: float = audio.bed_level(name)
		if level <= 0.02:
			continue
		var db: float = lerpf(Audio.BED_FLOOR, float(Audio.BED_CEILING[name]), level)
		var s: Array = _stats(Audio.BEDS[name])
		var gain: float = db_to_linear(db) * _bus_gain(String(Audio.BED_BUS[name]))
		var p: float = float(s[0]) * gain * gain
		power += p
		low += p * float(s[1])
	var gust: AudioStreamPlayer = audio.get("_gust")
	if audio.clock < float(audio.get("_gust_ends")) and gust.stream != null:
		var s: Array = _stats(gust.stream)
		var gain: float = db_to_linear(gust.volume_db) * _bus_gain("Ambient")
		power += float(s[0]) * gain * gain
		low += float(s[0]) * gain * gain * float(s[1])
	for kind: String in Audio.EMITTERS:
		for voice: Dictionary in audio.get("_emitters").get(kind, []):
			if not voice["on"]:
				continue
			var player: AudioStreamPlayer2D = voice["player"]
			var s: Array = _stats(player.stream)
			var gain: float = db_to_linear(player.volume_db) * _bus_gain(String(Audio.EMITTERS[kind]["bus"]))
			power += float(s[0]) * gain * gain
			low += float(s[0]) * gain * gain * float(s[1])
	return [power, low]

func _sounding() -> int:
	var count := 0
	for voice: Dictionary in audio.get("_flat") + audio.get("_world"):
		if float(voice["ends"]) > audio.clock:
			count += 1
	return count

## Runs `seconds` of the game with `step` called before each frame, and adds a row.
func _scene(label: String, seconds: float, step: Callable = Callable()) -> void:
	var dt := 1.0 / 30.0
	# A second to settle: the beds ease, and the last scene's fade is not this one's.
	for frame in 30:
		if step.is_valid():
			step.call(0.0)
		main._process(dt)
		audio.advance(dt)
	var before: Dictionary = audio.started.duplicate()
	var gusts_before: int = audio.gusts
	var sum := 0.0
	var peak := 0.0
	var low := 0.0
	var loudest_count := 0
	var frames: int = int(seconds / dt)
	var beds_seen: Dictionary = {}
	var scores: Dictionary = {}
	for frame in frames:
		if step.is_valid():
			step.call(frame * dt)
		main._process(dt)
		audio.advance(dt)
		var p: Array = _frame_power()
		sum += float(p[0])
		low += float(p[1])
		peak = maxf(peak, float(p[0]))
		loudest_count = maxi(loudest_count, _sounding())
		for name: String in Audio.BEDS:
			beds_seen[name] = maxf(float(beds_seen.get(name, 0.0)), audio.bed_level(name))
		var score: String = main.music.requested_score()
		scores[score] = int(scores.get(score, 0)) + 1
	var mean_db: float = linear_to_db(sqrt(sum / float(frames))) if sum > 0.0 else -99.0
	var peak_db: float = linear_to_db(sqrt(peak)) if peak > 0.0 else -99.0
	var low_share: float = low / sum if sum > 0.0 else 0.0
	var starts: Array = []
	for name: String in audio.started:
		var n: int = int(audio.started[name]) - int(before.get(name, 0))
		if n > 0:
			starts.append([n, name])
	starts.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
	var top: Array[String] = []
	for index in mini(4, starts.size()):
		top.append("%s ×%d" % [starts[index][1], int(starts[index][0])])
	var beds: Array[String] = []
	for name: String in beds_seen:
		if float(beds_seen[name]) > 0.05:
			beds.append("%s %.2f" % [name, float(beds_seen[name])])
	rows.append("| %s | %.0f | %.1f | %.1f | %.0f%% | %d | %s | %s | %s |" % [label, seconds,
		mean_db, peak_db, low_share * 100.0, loudest_count,
		", ".join(top) if not top.is_empty() else "-", ", ".join(beds) if not beds.is_empty() else "-",
		_main_score(scores) + ("" if audio.gusts == gusts_before else " · 돌풍 %d" % (audio.gusts - gusts_before))])
	print(rows[-1])

func _main_score(scores: Dictionary) -> String:
	var best := ""
	var most := -1
	for name: String in scores:
		if int(scores[name]) > most:
			most = int(scores[name])
			best = name
	return best if best != "" else "-"

# --- The scenes ------------------------------------------------------------------------

func _fresh_play() -> void:
	main.clear_save()
	main._start_run()
	main.finish_tutorial()
	main.state = main.State.PLAY
	main.player.warmth = 100.0
	main.player.position = main.sim.core_centre() + Vector2(0.0, Grid.px(3.0))

## Cats at work on real seams -- the nearest bare ones -- so the simulation keeps
## them working rather than sending them back to idle.
func _working_cats(count: int) -> void:
	var sim = main.sim
	var seams: Array = []
	for cell: Vector2i in sim.ore_nodes:
		if sim.machine_at(cell) == null:
			seams.append(cell)
	seams.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Vector2(a - sim.core_cell).length() < Vector2(b - sim.core_cell).length())
	for index in mini(count, seams.size()):
		var cat := Sim.Cat.new()
		cat.assigned = seams[index]
		cat.pos = sim.post_stand(seams[index])
		cat.state = Defs.CAT_WORKING
		cat.hunger = 1.0
		sim.cats.append(cat)

func _run() -> void:
	main = load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	audio = main.audio
	main.process_mode = Node.PROCESS_MODE_DISABLED   # one source of ticks

	main.clear_save()
	main._start_new_run()
	_scene("오프닝 (컷신 7장)", Defs.cutscene_panel_seconds() * float(Defs.CUTSCENE_PANELS.size()))
	main._end_cutscene()
	_scene("추락 직후 (깨어나기 + 체온 40)", 5.0)

	_fresh_play()
	_scene("평소의 낮 (기지 옆)", 30.0)

	_fresh_play()
	main.player.position = main.sim.core_centre() + Vector2(Grid.px(30.0), 0.0)
	_scene("추위 (온기 밖, 체온 30 고정)", 30.0, func(_t: float) -> void:
		main.player.warmth = 30.0
		main.collapse_timer = -1.0)

	_fresh_play()
	_scene("채굴 (곡괭이 10초)", 10.0, func(t: float) -> void:
		# One swing lands every eight frames of a ten-frame-a-second sheet.
		if int(round(t * 30.0)) % 24 == 0:
			main.audio.play("pick"))

	_fresh_play()
	_working_cats(6)
	_scene("고양이 채굴 ×6", 30.0)

	_fresh_play()
	_working_cats(12)
	var gens: Array = []
	for index in 4:
		var generator := Sim.Machine.new()
		generator.type = Defs.M_GENERATOR
		generator.cell = main.sim.core_cell + Vector2i(10 + index * 3, 10)
		generator.operated = true
		main.sim.add_machine(generator)
	_scene("공장 ×16 (고양이 12 + 발전기 4, 배달·제조 사건)", 30.0, func(t: float) -> void:
		# Twelve rigs at a five-second period, and a belt into the core.
		if int(t * 30.0) % 13 == 0:
			main._on_machine_worked(main.sim.core_cell + Vector2i(6, 6), Defs.M_MINER)
		if int(t * 30.0) % 20 == 0:
			main._on_item_delivered(Defs.ITEM_HEATSTONE, main.sim.core_cell))

	_fresh_play()
	main.player.position = main.shelter_doorstep()
	for index in 3:
		var cat := Sim.Cat.new()
		cat.pos = main.shelter_doorstep()
		main.sim.cats.append(cat)
	main.open_room()
	_scene("숙소 안 (고양이 3)", 20.0, func(_t: float) -> void:
		main._on_item_delivered(Defs.ITEM_HEATSTONE, main.sim.core_cell))

	_fresh_play()
	main.time_left = Defs.NIGHT_SECONDS - 2.0
	_scene("밤 (밖, 기지 옆)", 20.0)

	main.player.position = main.shelter_doorstep()
	main.open_room()
	main.player.position = main.room_sleep_point()
	main.room_sleeping = true
	main.player.locked = true
	_scene("잠들기 → 아침", 12.0)

	var header := "| 장면 | 초 | 평균 dBFS(추정) | 최대 dBFS | 150Hz 아래 | 동시 최대 | 많이 시작한 소리 | 베드(최대) | 곡·돌풍 |\n|---|---|---|---|---|---|---|---|---|\n"
	var text: String = header + "\n".join(rows) + "\n"
	if out_path != "":
		var file := FileAccess.open(out_path, FileAccess.WRITE)
		file.store_string(text)
	main.clear_save()
	quit(0)
