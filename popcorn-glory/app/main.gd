class_name PopApp
extends Node

## Popcorn & Glory: the chooser, or one experiment, chosen by the address
## (PopRoute) and kept in it -- opening an experiment puts `#<id>` in the
## address, Back takes it out, the browser's back button and an edited link
## are followed. One experiment at a time, each run from nothing.
##
## Every change to a run goes through here: the view asks (command), the app
## stamps the active time, logs the input, executes it on the rules, and hands
## the resulting events to the session log and back to the view in the same
## frame -- a press shows its pop on the frame it was made.
##
## One thing is stored (Step 12): the stand's progress, through PopSaveStore
## (this page's browser storage under popcorn-glory.*). The experiments A/B/C and
## the settings are never stored.

const VERSION_SETTING := "application/config/version"

var route: Dictionary = {}
var web := PopWeb.new()
var bridge := PopBridge.new()
var economy := PopEconomy.load_default()
var screen := "chooser"
var exp_id := ""
var rules: PopRules
var clock := PopClock.new()
var session := PopSession.new()
var history: Array[Dictionary] = []
var reduced_motion := false
var low_effects := false   ## Step 42: ?fx=low
## Step 14: ?burst=1 turns on the stand's crescendo (off = the stand as it was).
var burst := false
## Step 22: ?seed=N -- a measured session from that seed: a fresh run that is
## neither loaded from nor written to the save.
var seed := -1
## Step 35: ?scene=NAME -- a measured session that starts at a prepared point of the game
## (built through the rules' own commands; neither loaded from nor written to the save).
var scene := ""

var ui: Control
var chooser: PopChooser
var frame: PopFrame
var audio: PopAudio


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.name = "Layer"
	add_child(layer)
	ui = Control.new()
	ui.name = "UI"
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = PopPalette.BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chooser = PopChooser.new()
	chooser.name = "Chooser"
	ui.add_child(chooser)
	chooser.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chooser.chosen.connect(open)
	frame = PopFrame.new()
	frame.name = "Frame"
	ui.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.back_pressed.connect(back)
	frame.restart_pressed.connect(restart)
	frame.buy_pressed.connect(buy)
	frame.auto_pressed.connect(buy_auto)
	frame.denied.connect(func(which: String) -> void:
		if rules != null:
			# Step 20: which offer the card showed (the factory's middle floor sells the station).
			var offer := String(frame.upgrade_button.art_key) if which == "upgrade" else ""
			session.record(clock.now_ms, "denied", {"card": which, "money": rules.money, "offer": offer if offer != "" else "kettle"})
			audio.play("thud", 1.25, -8.0))
	frame.sound_pressed.connect(toggle_sound)
	frame.motion_pressed.connect(toggle_motion)
	frame.log_pressed.connect(download_log)
	frame.recover_pressed.connect(func() -> void: PopWeb.open_page("saves.html"))
	audio = PopAudio.new()
	audio.name = "Audio"
	add_child(audio)
	route = PopRoute.parse(PopWeb.location_hash(), PopWeb.location_search(), OS.get_cmdline_user_args())
	# ?motion=reduce forces it, ?motion=full overrides the system's setting.
	# Step 44: then the player's own choice (the motion button), then the system's setting.
	var saved_motion := PopSaveStore.read("motion").strip_edges()
	if String(route["motion"]) == "reduce":
		reduced_motion = true
	elif String(route["motion"]) == "full":
		reduced_motion = false
	elif saved_motion in ["calm", "full"]:
		reduced_motion = saved_motion == "calm"
	else:
		reduced_motion = PopWeb.prefers_reduced_motion()
	# Calm motion is also the low effects (the fewest pieces); ?fx=low asks for those alone.
	low_effects = String(route.get("fx", "")) == "low" or reduced_motion
	frame.set_motion(reduced_motion)
	frame.dev = bool(route["dev"])
	frame.trial = bool(route["trial"])
	burst = bool(route["burst"])
	seed = int(route.get("seed", -1))
	scene = String(route.get("scene", ""))
	audio.set_muted(not bool(route["sound"]))
	if bool(route["sound"]):
		# Step 43: the player's own choice (the speaker button) is kept; the address wins.
		var lv := String(route.get("sound_level", ""))
		audio.set_level_name(lv if lv != "" else PopSaveStore.read("sound").strip_edges())
	frame.set_sound(audio.level_name())
	if not economy.errors.is_empty():
		push_error("economy.json: %s" % [economy.errors])
	chooser.build(PopRegistry.listed())
	web.attach(_on_hash, func(hidden: bool) -> void:
		if hidden:
			save_now()   # a phone may kill a hidden tab: write first
		clock.set_pause("hidden", hidden)
		audio.set_paused(hidden)   # Step 43: a hidden tab is silent (the beds stop, nothing piles up)
		_has_last = false)   # the time away is not a hitch
	bridge.attach(self)
	get_viewport().size_changed.connect(_fit)
	_fit()
	show_route(String(route["exp"]))


func version() -> String:
	return String(ProjectSettings.get_setting(VERSION_SETTING, "0"))


## A wide window (a desktop browser) shows the portrait layout 1.3 times as
## big: at 1280x800 the 720x1280 canvas would otherwise draw everything at 0.63.
func _fit() -> void:
	var win := get_window()
	if win == null:
		return
	var s := Vector2(win.size)
	var k := 1.3 if s.x > s.y * 1.05 else 1.0
	if not is_equal_approx(win.content_scale_factor, k):
		win.content_scale_factor = k


func show_route(id: String) -> void:
	if id != "" and not PopRegistry.find(id).is_empty():
		_start(id)
	else:
		_show_chooser()


## The screen changes first, the address second: set_route() dispatches a
## hashchange that comes straight back into _on_hash(), and if the screen had
## not changed yet it finished the same run a second time (Step 07: the back
## button recorded every run twice in the browser; headless has no address).
func open(id: String) -> void:
	if PopRegistry.find(id).is_empty():
		return
	_finish_run()
	_start(id)
	PopWeb.set_route(id)


func back() -> void:
	_finish_run()
	_show_chooser()
	PopWeb.set_route("")


## The run's local log with what it was played on (dev mode's log button):
## build, variant, viewport, active time, every line. Nothing is sent anywhere.
func log_document() -> Dictionary:
	var win := get_window()
	return {"game": "popcorn-glory", "version": version(), "variant": exp_id,
		"viewport": [win.size.x, win.size.y] if win else [0, 0], "active_ms": clock.now_ms,
		"summary": summary(), "lines": session.lines}


func download_log() -> void:
	if rules == null:
		return
	PopWeb.download(JSON.stringify(log_document(), "  "), "popcorn-%s-%d.json" % [exp_id, clock.now_ms], "application/json")


## The speaker button: loud -> soft -> off -> loud.
func toggle_sound() -> void:
	audio.next_level()
	frame.set_sound(audio.level_name())
	PopSaveStore.write("sound", audio.level_name())


## Step 44: full motion <-> calm (reduced motion and the low effects), kept like the sound.
func toggle_motion() -> void:
	reduced_motion = not reduced_motion
	low_effects = reduced_motion or String(route.get("fx", "")) == "low"
	frame.set_motion(reduced_motion)
	PopSaveStore.write("motion", "calm" if reduced_motion else "full")
	if screen == "play" and frame.play != null:
		frame.play.reduced_motion = reduced_motion
		if "low_effects" in frame.play:
			frame.play.set("low_effects", low_effects)
		frame.play.queue_redraw()
	if audio:
		audio.play("clink", 1.1 if reduced_motion else 1.3, -12.0)


func restart() -> void:
	if screen != "play":
		return
	_finish_run(false)
	_start(exp_id)


func buy() -> void:
	if rules == null:
		return
	# Step 20: the card may sell another station (the factory's open floor).
	var cmd: Dictionary = frame.play.card_command() if frame.play != null and frame.play.has_method("card_command") else {"type": "buy"}
	var r := rules.execute(cmd)
	session.record(clock.now_ms, "buy", {"ok": bool(r["ok"]), "reason": String(r.get("reason", "")), "what": String(cmd["type"])})
	_flush()
	if bool(r["ok"]):
		save_now()


## The stand's automation card (Step 10).
func buy_auto() -> void:
	if rules == null:
		return
	var r := rules.execute({"type": "buy_auto"})
	session.record(clock.now_ms, "buy_auto", {"ok": bool(r["ok"]), "reason": String(r.get("reason", ""))})
	_flush()
	if bool(r["ok"]):
		save_now()


## A view's request: stamped, logged, executed, shown -- all in this frame.
func on_command(kind: String, cmd: Dictionary) -> void:
	if rules == null:
		return
	if kind == "release" or kind == "shake" or kind == "finish_release":
		# Letting go is part of B's action, not a second input (and so is the
		# stand's shaking while held): the input count stays one per press.
		session.record(clock.now_ms, kind, {})
	else:
		session.record_input(clock.now_ms, kind)
		frame.play.last_input_ms = clock.now_ms
	var r := rules.execute(cmd)
	if not bool(r["ok"]):
		session.record(clock.now_ms, "refused", {"kind": kind, "reason": String(r.get("reason", ""))})
	_flush()
	if kind in ["recipe", "build", "sell_machine", "upgrade_machine", "pause_machine", "pause_floor"] and bool(r["ok"]):
		save_now()   # (Step 26: a machine's lifecycle is kept at once)


func dev_money(amount: int) -> void:
	if rules != null and amount > 0:
		rules.money += amount
		rules.earned += amount
		_flush()


## Step 37: an event now, for the tests (still only one the shop can answer).
func dev_news(id: String) -> Dictionary:
	if rules == null or not rules.has_method("news_force"):
		return {"ok": false}
	var r: Dictionary = rules.news_force(id)
	_flush()
	return r


## Step 38: post a contest now, for the tests (the shop must still meet its needs).
func dev_contest(id: String) -> Dictionary:
	if rules == null or not rules.has_method("contest_force_post"):
		return {"ok": false}
	var r: Dictionary = rules.contest_force_post(id)
	_flush()
	return r


## Step 42: a later factory for the motion tests -- the machines of `plan` ([[type, floor], ...])
## bought through the app's own commands (each floor's next line when it is full), at sign
## `sign`, the packing station at `packer`. Setup, not play (the play tests build by hand).
func dev_build(plan: Array, sign: int, packer: int) -> Dictionary:
	if rules == null or not rules.has_method("floor_full"):
		return {"ok": false}
	rules.sign_tier = maxi(int(rules.sign_tier), 6)
	rules.packer_tier = maxi(int(rules.packer_tier), packer)
	rules.level = maxi(int(rules.level), 6)
	rules.stats["packed"] = maxi(1, int(rules.stats["packed"]))
	rules.stats["sold"] = maxi(1, int(rules.stats["sold"]))
	var before: int = rules.money
	rules.money += 1 << 24
	var built := 0
	for row: Array in plan:
		var fl := String(row[1])
		if rules.floor_full(fl) and int(rules.line_cost(fl)) >= 0:
			on_command("buy_line", {"type": "buy_line", "floor": fl})
		var n: int = rules.machines.size()
		on_command("build", {"type": "build", "machine": String(row[0]), "floor": fl})
		built += rules.machines.size() - n
	rules.sign_tier = maxi(int(rules.sign_tier), sign)
	rules.money = maxi(before, 3000)
	_flush()
	return {"ok": true, "built": built, "machines": rules.machines.size()}


## Step 44 (tests): fills the factory's raw bin with plain lots, counted as made (the
## conservation check still holds), so the hand's next lot waits in the glass.
func dev_fill_bin() -> Dictionary:
	if rules == null or not rules.has_method("bin_cap"):
		return {"ok": false}
	var room: int = int(rules.bin_cap()) - int(rules.bin_portions()) - int(rules.lift_portions()) - int(rules.coating_portions())
	if room > 0:
		(rules.get("bin") as Array).append({"id": rules._new_id(), "recipe": "plain", "quality": 80, "portions": room})
		rules.stats["made_portions"] = int(rules.stats["made_portions"]) + room
	_flush()
	return {"ok": true, "added": maxi(0, room)}


func dev_level(level: int) -> void:
	if rules != null:
		rules.level = clampi(level, 0, rules.max_level())
		_flush()


func dev_advance(ms: int) -> void:
	if rules == null or ms <= 0:
		return
	# In steps no longer than a frame's cap, so time-driven rules see the same
	# sequence a played run would.
	var left := ms
	while left > 0:
		var step := mini(left, 100)
		clock.add_ms(step)
		rules.advance(step)
		_flush()
		left -= step


## The wall time of the last played frame (Time.get_ticks_usec), -1 when none.
## Godot hands _process a delta capped at max_physics_steps_per_frame physics
## steps (8 / 60 s = 0.133 s): a browser hitch longer than that vanished from
## the run, and from B's heat while the finger stayed down (Step 09: a blind
## player held 1.98 s, the game judged 1.16 s). The wall time is used only when
## it is clearly longer (HITCH_S): taking the larger of two noisy measures on
## EVERY frame made the game clock run 4% fast (Step 10's blind runs: 1.04x).
## PopClock still caps one frame at MAX_STEP.
const HITCH_S := 0.05
var _last_us := 0
var _has_last := false


var prof := {}


func _process(delta: float) -> void:
	if screen != "play" or rules == null:
		_has_last = false
		return
	var now_us := Time.get_ticks_usec()
	var wall := float(now_us - _last_us) / 1000000.0 if _has_last else delta
	_last_us = now_us
	_has_last = true
	var added := clock.step(wall if wall - delta > HITCH_S else delta)
	var t0 := Time.get_ticks_usec()
	if added > 0:
		rules.advance(added)
	var t1 := Time.get_ticks_usec()
	_flush()
	var t2 := Time.get_ticks_usec()
	# Step 46: the model's and the flush's share of a frame (ms, moving average; dev render info).
	prof["sim"] = float(prof.get("sim", 0.0)) * 0.95 + float(t1 - t0) / 1000.0 * 0.05
	prof["flush"] = float(prof.get("flush", 0.0)) * 0.95 + float(t2 - t1) / 1000.0 * 0.05
	if _saves() and clock.now_ms - _saved_at_ms >= SAVE_EVERY_MS:
		save_now()


# -- the stand's save (Step 12) ---------------------------------------------

const SAVE_SCHEMA := 1
const SAVE_EVERY_MS := 5000
## Tests use their own names so they never touch a player's save.
var save_prefix := ""
var _saved_at_ms := 0


## A 3-minute trial (?trial=1, the owner's scorecard) neither reads nor writes
## the save: a score is taken from a fresh start, and the real run is untouched.
func _saves() -> bool:
	return screen == "play" and rules != null and not frame.trial and seed < 0 and scene == "" and bool(PopRegistry.find(exp_id).get("save", false)) and rules.has_method("to_save")


func _save_name(id: String) -> String:
	return save_prefix + id + ".v1"


## Step 45: the last good save is copied to "<name>.bak" when it is picked up and
## then once a minute of play (the text written a minute ago, not the one just made).
const BACKUP_EVERY_MS := 60000
var _backup_at_ms := 0
const RESTART_KEEP_MS := 600000
var _restart_keep_ms := 0
var _last_text := ""
## What happened to the save this session (bridge, web/saves.html, tests):
## "from": "main" | "backup" | "fresh" | "none"; "rejected": the reason the main save
## was refused ("" when it was not); "failed_writes": writes that did not hold.
var save_info := {"from": "none", "rejected": "", "backup_rejected": "", "failed_writes": 0}


## Writes the run now: every SAVE_EVERY_MS of play, after a purchase or a
## recipe, when the tab hides and when the player leaves.
func save_now() -> bool:
	if not _saves():
		return false
	_saved_at_ms = clock.now_ms
	var text := PopSaveDoc.encode(exp_id, version(), clock.now_ms, int(Time.get_unix_time_from_system()), rules.call("to_save"))
	var name := _save_name(exp_id)
	if _last_text != "" and clock.now_ms - _backup_at_ms >= BACKUP_EVERY_MS:
		PopSaveStore.write(name + ".bak", _last_text)
		_backup_at_ms = clock.now_ms
	# A write that does not read back whole did not happen (a full quota, a private
	# window): the previous save stays, and the next tick tries again.
	var ok := PopSaveStore.write(name, text) and PopSaveStore.read(name) == text
	if not ok:
		save_info["failed_writes"] = int(save_info["failed_writes"]) + 1
		session.record(clock.now_ms, "save_failed", {"bytes": text.length()})
		return false
	_last_text = text
	return true


## Picks a saved run up if there is one and it is whole (PopSaveDoc, then the rules'
## own from_save, which changes nothing when it refuses). Step 45: a refused save is
## never written over -- it is set aside as "<name>.rejected" first, and the last good
## save ("<name>.bak") is tried; only when both fail does a fresh run start.
func _load_saved(id: String) -> void:
	var name := _save_name(id)
	var text := PopSaveStore.read(name)
	if text == "":
		save_info["from"] = "none"
		return
	var why := _try_load(text, id)
	if why == "":
		save_info["from"] = "main"
		_after_load(text)
		return
	save_info["rejected"] = why
	if PopSaveStore.read(name + ".rejected") != text:
		PopSaveStore.write(name + ".rejected", text)
	session.record(0, "save_rejected", {"bytes": text.length(), "reason": why})
	var backup := PopSaveStore.read(name + ".bak")
	var why_b := _try_load(backup, id) if backup != "" and backup != text else "none"
	if why_b == "":
		save_info["from"] = "backup"
		session.record(clock.now_ms, "restored_backup", {"level": rules.level, "money": rules.money})
		_after_load(backup)
		return
	save_info["backup_rejected"] = why_b
	save_info["from"] = "fresh"


## "" when the text was applied, else why not (nothing applied).
func _try_load(text: String, id: String) -> String:
	var r := PopSaveDoc.decode(text, id)
	if not bool(r["ok"]):
		return String(r["reason"])
	if not bool(rules.call("from_save", r["rules"])):
		return "rules"
	clock.add_ms(maxi(0, int((r["doc"] as Dictionary).get("active_ms", 0))))
	session.record(clock.now_ms, "restored", {"level": rules.level, "money": rules.money, "from": String((r["doc"] as Dictionary).get("version", ""))})
	return ""


func _after_load(text: String) -> void:
	_saved_at_ms = clock.now_ms
	_backup_at_ms = clock.now_ms
	_last_text = text
	# The save the player came back to is the fallback until a minute of new play.
	if PopSaveStore.read(_save_name(exp_id) + ".bak") != text:
		PopSaveStore.write(_save_name(exp_id) + ".bak", text)


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or k.echo:
		return
	if screen == "play" and (k.keycode == KEY_SPACE or k.keycode == KEY_ENTER):
		# The view turns it into its own commands (logged in on_command).
		frame.play.key(k.pressed)
		get_viewport().set_input_as_handled()
	elif screen == "play" and k.pressed and k.keycode == KEY_ESCAPE:
		back()
		get_viewport().set_input_as_handled()


func _flush() -> void:
	var events := rules.drain_events()
	if not events.is_empty():
		session.record_events(events)
		frame.play.on_events(events)
	session.observe(clock.now_ms, rules)
	frame.play.now_ms = clock.now_ms
	frame.refresh(rules, clock.now_ms)


func _start(id: String) -> void:
	var entry := PopRegistry.find(id)
	exp_id = id
	screen = "play"
	if _parked.has(id):
		var p: Dictionary = _parked[id]
		_parked.erase(id)
		rules = p["rules"]
		clock = p["clock"]
		session = p["session"]
		session.record(clock.now_ms, "resumed", {})
	else:
		rules = PopRegistry.make_rules(id, economy)
		clock = PopClock.new()
		session = PopSession.new(id)
		_saved_at_ms = 0
		_last_text = ""
		_backup_at_ms = _restart_keep_ms
		_restart_keep_ms = 0
		save_info = {"from": "none", "rejected": "", "backup_rejected": "", "failed_writes": 0}
		if seed >= 0 and rules.has_method("reseed"):
			rules.reseed(seed)
		elif bool(entry.get("save", false)) and not frame.trial:
			_load_saved(id)
		if scene != "" and rules.has_method("start_scene"):
			rules.start_scene(scene)
	# Step 14: the stand's crescendo is a mode of the address (not of the save);
	# the factory has it always (Step 19), so only entries marked burst_route follow ?burst=1.
	if bool(entry.get("burst_route", false)) and "burst_mode" in rules:
		rules.set("burst_mode", burst)
	clock.set_pause("hidden", web.hidden())
	audio.set_paused(web.hidden())
	var view_script: GDScript = load(String(entry["view"]))
	var view: PopPlayView = view_script.new()
	view.reduced_motion = reduced_motion
	if "low_effects" in view:
		view.set("low_effects", low_effects)
	view.audio = audio
	audio.stop_all()
	view.command.connect(on_command)
	frame.accent = entry["color"]
	frame.has_auto = rules.has_method("auto_offer")
	frame.arms_restart = bool(entry.get("save", false)) and seed < 0 and not frame.trial
	frame.recover_button.visible = String(save_info["rejected"]) != ""
	frame.show_motion = id == "factory"
	frame.wide = bool(entry.get("wide", false))
	frame.set_play(view)
	view.setup(rules)
	chooser.visible = false
	frame.visible = true
	_flush()


## Runs parked by leaving (experiment id -> rules, session, clock): an entry
## with `keep` (the stand) is set aside, not finished, when the player goes
## back or opens another, and picked up again when it is reopened. Step 11: a
## blind player pressed back at 13:20 of the stand, came back, and found
## everything gone -- "the worst moment". Only the restart button starts it
## over. In memory only: a page reload still starts fresh (no save yet).
var _parked: Dictionary = {}


func _finish_run(keep: bool = true) -> void:
	if screen == "play" and rules != null and keep and bool(PopRegistry.find(exp_id).get("keep", false)):
		save_now()
		_parked[exp_id] = {"rules": rules, "session": session, "clock": clock}
		return
	_parked.erase(exp_id)
	if not keep and _saves():
		# Restart (two taps): the run goes, but the factory it was stays in "<name>.bak"
		# for the new run's first RESTART_KEEP_MS of play (web/saves.html undoes it).
		var old := PopSaveStore.read(_save_name(exp_id))
		if old != "":
			PopSaveStore.write(_save_name(exp_id) + ".bak", old)
			_restart_keep_ms = RESTART_KEEP_MS - BACKUP_EVERY_MS
		PopSaveStore.clear(_save_name(exp_id))
	if screen == "play" and rules != null:
		session.reset(clock.now_ms)
		history.append(summary())
		if history.size() > 20:
			history.pop_front()


func _show_chooser() -> void:
	if audio != null:
		audio.stop_all()
	screen = "chooser"
	exp_id = ""
	rules = null
	chooser.visible = true
	frame.visible = false


func _on_hash() -> void:
	var r := PopRoute.parse(PopWeb.location_hash(), PopWeb.location_search(), PackedStringArray())
	var id := String(r["exp"])
	if id == exp_id:
		return
	_finish_run()
	show_route(id)


# -- what the page and the tests can read ---------------------------------

func summary() -> Dictionary:
	if rules == null:
		return {}
	return session.summary(clock.now_ms, rules)


func log_lines() -> Array[Dictionary]:
	return session.lines


func state() -> Dictionary:
	var out := {"version": version(), "screen": screen, "exp": exp_id,
		"window": [get_window().size.x, get_window().size.y] if get_window() else [0, 0],
		"listed": PopRegistry.listed().map(func(e: Dictionary) -> String: return String(e["id"])),
		"history": history.size(), "rects": _rects(), "reduced_motion": reduced_motion, "low_effects": low_effects,
		"save": save_info.duplicate(), "armed_restart": frame.arms_restart}
	# Step 18: what the picture is doing (the factory's journeys), for the tests.
	if screen == "play" and frame.play != null and frame.play.has_method("debug_state"):
		out["view"] = frame.play.call("debug_state")
	if rules != null:
		out["run"] = rules.state()
		out["clock_ms"] = clock.now_ms
		out["paused"] = clock.pause_reasons()
		out["fx"] = {"alive": frame.play.fx.alive, "peak": frame.play.fx.peak, "cap": PopFx.CAP}
	out["sound"] = audio.debug()
	return out


## Window-pixel rectangles [x, y, w, h] of what a test taps.
func _rects() -> Dictionary:
	var out := {}
	var named: Dictionary = {}
	if screen == "play":
		named = {"play": frame.play, "upgrade": frame.upgrade_button, "back": frame.back_button,
			"restart": frame.restart_button, "recover": frame.recover_button, "money": frame.money_view, "sound": frame.sound_button, "motion": frame.motion_button}
	else:
		for t: Dictionary in chooser.tiles:
			named["tile_" + String(t["id"])] = t["button"]
	var xf := get_viewport().get_final_transform()
	if screen == "play" and frame.auto_button.visible:
		named["auto"] = frame.auto_button
	for key: String in named.keys():
		var c: Control = named[key]
		if key in ["motion", "recover"] and not c.visible:
			continue
		var r := xf * c.get_global_rect()
		out[key] = [r.position.x, r.position.y, r.size.x, r.size.y]
	# What the experiment's own picture lets you tap (the stand's shakers).
	if screen == "play" and frame.play.has_method("extra_rects"):
		var extra: Dictionary = frame.play.call("extra_rects")
		for key: String in extra.keys():
			var lr: Rect2 = extra[key]
			var r := xf * Rect2(frame.play.get_global_transform() * lr.position, lr.size)
			out[key] = [r.position.x, r.position.y, r.size.x, r.size.y]
	return out
