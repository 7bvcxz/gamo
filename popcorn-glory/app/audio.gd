class_name PopAudio
extends Node

## Every sound goes through here, on buses declared in default_bus_layout.tres
## (a bus added at run time is silent on the web -- AGENTS.md 2026-10-27):
## SFX for what happens, Ambient for the factory's beds. A small pool of
## players caps how many play at once, and one sound is not restarted more
## often than its gap (a hundred pieces in one eruption are one boom and a
## crackle, not a hundred pops). Muting mutes the buses; `?sound=off` starts
## muted.
##
## Step 43 (design/SOUND.md): every sound has a class --
##   hand     the hand on the kettle (B): its heat, its Perfect Pop, its crescendo
##   reward   a sale, a prize, a reveal
##   event    news, contests, a customer at the door, a card or a button
##   machine  what the machines do by themselves (their pops, the packing, the seal)
## A new sound takes an idle voice, or the oldest voice of a lower class, or of
## its own class; a machine sound never takes a higher class's voice, and at
## most MACHINE_VOICES machine sounds play at once. While the hand holds the
## kettle, and for a moment after a Perfect Pop, machine sounds and the beds
## are ducked: the gold is the one thing that asks for the ear.
## Positional sounds (`play_at`) are panned by where they happen on the screen.
## The beds (`bed`) are looping players on the Ambient bus whose loudness the
## factory's soundscape sets; each is one player and one stream, made once.

const NAMES := ["pop_1", "pop_2", "pop_3", "coin", "upgrade", "sizzle", "ding", "thud", "hiss", "clink", "boom", "crackle", "fanfare",
	# Step 43: the factory's grammar.
	"heat", "rise", "perfect", "mpop", "bloom", "fountain", "belt", "hum", "chug", "murmur",
	"patter", "coat", "seal", "serve", "door", "cash", "news", "reveal", "win"]
## The loops the factory keeps playing (imported with loop on, so no copies are made).
const BEDS := ["hum", "belt", "chug", "murmur"]
## The speaker button steps through these (Step 05 addendum: a volume setting,
## not only mute): loud, soft, calm (Step 43: the reduced-audio option -- no
## beds, no machine chatter, only what the hand does and what it earns), off.
const LEVELS := [{"name": "loud", "db": 0.0}, {"name": "soft", "db": -12.0}, {"name": "calm", "db": -6.0}, {"name": "off", "db": -80.0}]
## Big sounds duck the small ones for DUCK_MS, so a boom or a fanfare is not
## buried under a hundred pops (controlled polyphony, with the pool and the gap).
const DUCKERS := ["boom", "fanfare", "perfect", "fountain", "win", "reveal"]
const DUCK_DB := -8.0
const DUCK_MS := 450
## While the hand holds the kettle: machine sounds and the beds this much lower.
const HOLD_DUCK_DB := -7.0
const POOL := 10
const POOL_2D := 6
const MACHINE_VOICES := 3
## Every sound plays this far under full scale. The files are normalised to
## about -2 dBFS each, and a perfect pop starts three of them at once (pop,
## ding, coin): the sum peaked at 1.91 -- nearly twice full scale -- and the
## browser hard-clips above 1.0, on every perfect, since Step 05 (measured on
## the page's output in Step 12, on the desktop and on a real S23). -8 dB keeps
## that moment near 0.76. The volume button's steps are on top of this.
const HEADROOM_DB := -8.0
const MIN_GAP_MS := 45
## Sounds a busy factory asks for many times a second: their own, longer gaps.
const GAP_MS := {"door": 1200, "cash": 160, "patter": 90, "seal": 160, "serve": 450, "mpop": 110, "coat": 200}
const CLASS := {"hand": 3, "reward": 2, "event": 1, "machine": 0}
const CLASS_OF := {
	"heat": "hand", "rise": "hand", "perfect": "hand", "bloom": "hand", "fountain": "hand", "sizzle": "hand",
	"cash": "reward", "coin": "reward", "win": "reward", "reveal": "reward", "fanfare": "reward", "upgrade": "reward",
	"mpop": "machine", "patter": "machine", "coat": "machine", "seal": "machine",
}
const PAN_STRENGTH := 0.7
const BED_FADE_DB_S := 24.0   ## how fast a bed follows its target (dB a second)
const SILENT_DB := -60.0

var muted := false
var level := 0          # index into LEVELS
var paused := false     # a hidden tab: the beds and the loops stop
var holding := false    # the hand is on the kettle
var _duck_until := 0
var played: Dictionary = {}       # name -> times played (for tests)
var asked: Dictionary = {}        # name -> times asked for (played or not)
var refused: Dictionary = {}      # name -> times refused (gap, class cap, calm, no voice)
var voices_peak := 0
var bed_starts := 0               # how many times a bed player was started (bounded: not per frame)
var loop_copies := 0              # looping copies of one-shot streams made (once each)
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _players_2d: Array[AudioStreamPlayer2D] = []
var _voice_until: Array[int] = []      # per player (central then 2D): ms when its sound ends
var _voice_class: Array[int] = []
var _voice_start: Array[int] = []
var _last_ms: Dictionary = {}
var _loops: Dictionary = {}       # channel -> AudioStreamPlayer
var _loop_streams := {}   # name -> its looping copy, made once
var _beds: Dictionary = {}        # name -> {"player", "db", "target"}


func _ready() -> void:
	for n: String in NAMES:
		var path := "res://assets/audio/%s.ogg" % n
		if ResourceLoader.exists(path):
			_streams[n] = load(path)
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_players.append(p)
	for i in POOL_2D:
		var q := AudioStreamPlayer2D.new()
		q.bus = &"SFX"
		q.max_distance = 1.0e6
		q.attenuation = 0.0001
		q.panning_strength = PAN_STRENGTH
		add_child(q)
		_players_2d.append(q)
	for i in POOL + POOL_2D:
		_voice_until.append(0)
		_voice_class.append(0)
		_voice_start.append(0)
	for b: String in BEDS:
		if not _streams.has(b):
			continue
		var bp := AudioStreamPlayer.new()
		bp.bus = &"Ambient"
		bp.stream = _streams[b]
		bp.volume_db = SILENT_DB
		add_child(bp)
		_beds[b] = {"player": bp, "db": SILENT_DB, "target": SILENT_DB}
	set_level(level)


func set_muted(on: bool) -> void:
	set_level(3 if on else 0)


## 0 loud, 1 soft, 2 calm, 3 off.
func set_level(i: int) -> void:
	level = clampi(i, 0, LEVELS.size() - 1)
	muted = String(LEVELS[level]["name"]) == "off"
	var db := float(LEVELS[level]["db"]) if not muted else 0.0
	for bus_name: StringName in [&"SFX", &"Ambient"]:
		var bus := AudioServer.get_bus_index(bus_name)
		if bus >= 0:
			AudioServer.set_bus_mute(bus, muted or (bus_name == &"Ambient" and calm()))
			AudioServer.set_bus_volume_db(bus, db)


func next_level() -> void:
	set_level((level + 1) % LEVELS.size())


func level_name() -> String:
	return String(LEVELS[level]["name"])


func set_level_name(n: String) -> void:
	for i in LEVELS.size():
		if String(LEVELS[i]["name"]) == n:
			set_level(i)
			return


## The reduced-audio option: no beds, no machine sounds.
func calm() -> bool:
	return level_name() == "calm"


func class_of(name: String) -> int:
	return int(CLASS[String(CLASS_OF.get(name, "event"))])


func play(name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	_play(name, pitch, volume_db, -1.0)


## A sound where it happens: `x` is its place across the screen, 0 left .. 1 right.
func play_at(name: String, x: float, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	_play(name, pitch, volume_db, clampf(x, 0.0, 1.0))


func _refuse(name: String) -> void:
	refused[name] = int(refused.get(name, 0)) + 1


func _play(name: String, pitch: float, volume_db: float, x: float) -> void:
	if not _streams.has(name):
		return
	asked[name] = int(asked.get(name, 0)) + 1
	var cls := class_of(name)
	var machine := cls == int(CLASS["machine"])
	# Off is no sound at all, not sounds at -80 dB: nothing is played, so a muted page does no
	# audio work (each web play copies its sample and adds nodes).
	if muted or (machine and (calm() or paused)):
		_refuse(name)
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_ms.get(name, -100000)) < int(GAP_MS.get(name, MIN_GAP_MS)):
		_refuse(name)
		return
	var v := _voice_for(cls, x >= 0.0, now)
	if v < 0:
		_refuse(name)
		return
	_last_ms[name] = now
	played[name] = int(played.get(name, 0)) + 1
	if name in DUCKERS:
		_duck_until = now + DUCK_MS
	elif now < _duck_until and cls < int(CLASS["hand"]):
		volume_db += DUCK_DB
	if machine and holding:
		volume_db += HOLD_DUCK_DB
	var stream: AudioStream = _streams[name]
	var ps := clampf(pitch, 0.5, 2.0)
	var length_ms := int(stream.get_length() * 1000.0 / ps) + 30
	_voice_until[v] = now + length_ms
	_voice_class[v] = cls
	_voice_start[v] = now
	voices_peak = maxi(voices_peak, voices())
	if v < POOL:
		var p := _players[v]
		p.stream = stream
		p.pitch_scale = ps
		p.volume_db = volume_db + HEADROOM_DB
		p.play()
	else:
		var q := _players_2d[v - POOL]
		var r := get_viewport().get_visible_rect() if is_inside_tree() else Rect2(0, 0, 720, 1280)
		q.global_position = Vector2(r.position.x + r.size.x * x, r.position.y + r.size.y * 0.5)
		q.stream = stream
		q.pitch_scale = ps
		q.volume_db = volume_db + HEADROOM_DB
		q.play()


## Which voice a new sound of class `cls` takes (-1 none): an idle one; else
## the oldest of a lower class; else the oldest of its own class (not for
## machine sounds: they never cut each other off -- they are refused).
func _voice_for(cls: int, positional: bool, now: int) -> int:
	var lo := POOL if positional else 0
	var hi := POOL + POOL_2D if positional else POOL
	if cls == int(CLASS["machine"]):
		var busy := 0
		for i in POOL + POOL_2D:
			if _voice_until[i] > now and _voice_class[i] == cls:
				busy += 1
		if busy >= MACHINE_VOICES:
			return -1
	var best := -1
	var best_key := Vector2i(1 << 30, 1 << 30)
	for i in range(lo, hi):
		if _voice_until[i] <= now:
			return i
		var c := _voice_class[i]
		if c > cls or (c == cls and cls == int(CLASS["machine"])):
			continue
		var key := Vector2i(c, _voice_start[i])   # lowest class first, then the oldest
		if key < best_key:
			best_key = key
			best = i
	return best


## Voices sounding now (by their sounds' lengths, so headless tests count them too).
func voices() -> int:
	var now := Time.get_ticks_msec()
	var n := 0
	for t: int in _voice_until:
		if t > now:
			n += 1
	return n


## A looping sound on its own channel (B's sizzle while heating; Step 43: the
## factory's heat and its anticipation on two channels).
func loop(name: String, on: bool, pitch: float = 1.0, volume_db: float = 0.0, channel: int = 0) -> void:
	var lp: AudioStreamPlayer = _loops.get(channel)
	if not on or paused or muted:
		if lp != null and lp.playing:
			lp.stop()
		return
	if not _streams.has(name):
		return
	if lp == null:
		lp = AudioStreamPlayer.new()
		lp.bus = &"SFX"
		add_child(lp)
		_loops[channel] = lp
	# The looping copy is made once per sound and kept. (Until Step 12 this compared
	# the player's copy with the original -- never equal -- so every frame of
	# heating made a new copy and restarted it: 1,400 'plays' a minute, and on
	# the web each new stream was a newly decoded sample that stayed alive,
	# about 27 MB a hold.) A stream imported with loop on is used as it is.
	if not _loop_streams.has(name):
		var src: AudioStreamOggVorbis = _streams[name]
		if src.loop:
			_loop_streams[name] = src
		else:
			var s: AudioStreamOggVorbis = src.duplicate()
			s.loop = true
			_loop_streams[name] = s
			loop_copies += 1
	if lp.stream != _loop_streams[name]:
		lp.stream = _loop_streams[name]
	lp.pitch_scale = clampf(pitch, 0.5, 2.0)
	var db := volume_db + HEADROOM_DB
	if absf(lp.volume_db - db) > 0.2:
		lp.volume_db = db
	if not lp.playing:
		played[name] = int(played.get(name, 0)) + 1
		lp.play()


## A bed's target loudness in dB (SILENT_DB or below: off). The bed follows it
## smoothly (`_process`); it starts when it becomes audible and stops when it
## has faded out, so a silent factory costs no voice.
func bed(name: String, target_db: float) -> void:
	if _beds.has(name):
		_beds[name]["target"] = target_db


func bed_db(name: String) -> float:
	return float(_beds[name]["db"]) if _beds.has(name) else SILENT_DB


func beds_playing() -> int:
	var n := 0
	for b: String in _beds:
		if (_beds[b]["player"] as AudioStreamPlayer).playing:
			n += 1
	return n


func _process(delta: float) -> void:
	step_beds(delta)


func step_beds(delta: float) -> void:
	var now := Time.get_ticks_msec()
	var duck := (HOLD_DUCK_DB if holding else 0.0) + (DUCK_DB if now < _duck_until else 0.0)
	for b: String in _beds:
		var e: Dictionary = _beds[b]
		var p: AudioStreamPlayer = e["player"]
		var target := float(e["target"]) + duck
		if paused or muted or calm() or float(e["target"]) <= SILENT_DB:
			target = SILENT_DB - 1.0
		var db := float(e["db"])
		var stepdb := BED_FADE_DB_S * clampf(delta, 0.0, 0.25)
		db = minf(target, db + stepdb) if target > db else maxf(target, db - stepdb)
		e["db"] = db
		if paused or muted:
			db = SILENT_DB - 1.0
			e["db"] = db
		if db <= SILENT_DB:
			if p.playing:
				p.stop()
			continue
		if absf(p.volume_db - (db + HEADROOM_DB)) > 0.25:
			p.volume_db = db + HEADROOM_DB
		if not p.playing:
			p.play()
			bed_starts += 1


## A hidden tab (or anything that stops the game's clock for the player): the
## beds and the loops stop at once; they come back when the soundscape asks.
func set_paused(on: bool) -> void:
	paused = on
	if on:
		for lp: AudioStreamPlayer in _loops.values():
			lp.stop()
		step_beds(0.0)


func stop_all() -> void:
	for p: AudioStreamPlayer in _players:
		p.stop()
	for q: AudioStreamPlayer2D in _players_2d:
		q.stop()
	for i in _voice_until.size():
		_voice_until[i] = 0
	for lp: AudioStreamPlayer in _loops.values():
		lp.stop()
	for b: String in _beds:
		_beds[b]["target"] = SILENT_DB
		_beds[b]["db"] = SILENT_DB
		(_beds[b]["player"] as AudioStreamPlayer).stop()


func debug() -> Dictionary:
	var beds := {}
	for b: String in _beds:
		beds[b] = {"db": snappedf(float(_beds[b]["db"]), 0.1), "target": snappedf(float(_beds[b]["target"]), 0.1), "playing": (_beds[b]["player"] as AudioStreamPlayer).playing}
	return {"muted": muted, "level": level_name(), "calm": calm(), "paused": paused, "holding": holding, "played": played.duplicate(),
		"asked": asked.duplicate(), "refused": refused.duplicate(), "voices": voices(), "voices_peak": voices_peak,
		"beds": beds, "beds_playing": beds_playing(), "bed_starts": bed_starts, "loop_copies": loop_copies}
