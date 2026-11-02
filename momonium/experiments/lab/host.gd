class_name LabHost
extends Control

## The frame around one experiment: Back to the experiments, Restart, the
## sound switch, the one visible resource and the one button; in dev mode the
## play clock and the run report. It owns the run: a fresh experiment and a
## fresh LabSession on every start, both thrown away on Restart or Back (their
## summaries kept in `finished` for the report, in memory only).
##
## Play time only moves while the page is visible and focused: `set_pause`
## with a reason ("hidden", "focus") pauses the tree under the frame -- the
## experiment, its flourishes and the sound -- and nothing is caught up
## afterwards; one frame never advances more than MAX_STEP.

const MAX_STEP := 0.25
const TOP_UI := 200.0
const BOTTOM_UI := 210.0

signal back_requested

var exp_id := ""
var version := ""
var dev := false
var reduced_motion := false
var audio: LabAudio
var experiment: LabExperiment
var session: LabSession
var finished: Array[Dictionary] = []
var paused_reasons: Dictionary = {}
var runs := 0
## Play seconds a real second (dev hook `dev_time_scale`): 0 leaves the clock
## to explicit steps, so a test can tap at an exact rate of play time.
var time_scale := 1.0

var stage: Control
var fx: LabFx
var chrome: Control
var back_button: LabIconButton
var restart_button: LabIconButton
var sound_button: LabIconButton
var report_button: LabIconButton
var title_label: Label
var resource_box: PanelContainer
var resource_icon: TextureRect
var resource_value: Label
var resource_rate: Label
var action_button: Button
var action_icon: TextureRect
var action_label: Label
var action_cost: Label
var action_coin: TextureRect
var clock_label: Label
var pause_overlay: Control
var report_panel: PanelContainer
var report_text: Label
var report_buttons: Dictionary = {}

var _shown_value := -1.0
var _last_info: Dictionary = {}


func setup(p_id: String, p_version: String, p_audio: LabAudio, p_dev: bool, p_reduced: bool) -> void:
	exp_id = p_id
	version = p_version
	audio = p_audio
	dev = p_dev
	reduced_motion = p_reduced


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	stage = Control.new()
	stage.name = "Stage"
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.process_mode = Node.PROCESS_MODE_PAUSABLE
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	_build_chrome()
	start()


func _exit_tree() -> void:
	if get_tree() != null:
		get_tree().paused = false


## A new run: a new experiment, a new session.
func start() -> void:
	runs += 1
	session = LabSession.new(exp_id, version, Time.get_unix_time_from_system())
	var script: GDScript = load(LabRegistry.script_path(exp_id))
	experiment = script.new() as LabExperiment
	experiment.name = "Experiment"
	experiment.session = session
	experiment.audio = audio
	experiment.reduced_motion = reduced_motion
	experiment.set_meta("lab_id", exp_id)
	experiment.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx = LabFx.new()
	fx.name = "Fx"
	fx.reduced_motion = reduced_motion
	experiment.fx = fx
	stage.add_child(experiment)
	stage.add_child(fx)
	experiment.action_changed.connect(_refresh_action)
	_shown_value = -1.0
	_refresh()
	_refresh_action()
	if audio != null:
		audio.start_ambience()


## Throws the run away and starts again from nothing.
func restart() -> void:
	finished.append(session.summary())
	for c: Node in stage.get_children():
		stage.remove_child(c)
		c.queue_free()
	experiment = null
	fx = null
	start()


## Advances play time (the frame calls it every frame; tests and the dev
## hooks call it to skip ahead -- in MAX_STEP pieces, as frames would).
func step(dt: float) -> void:
	var left := dt
	while left > 0.0:
		var d := minf(left, MAX_STEP)
		session.advance(d)
		experiment.tick(d)
		left -= d


func _process(delta: float) -> void:
	if is_paused() or experiment == null:
		return
	if time_scale > 0.0:
		step(minf(delta, MAX_STEP) * time_scale)
	_refresh()


func set_pause(reason: String, on: bool) -> void:
	var was := is_paused()
	if on:
		paused_reasons[reason] = true
		session.paused(reason)
	elif paused_reasons.has(reason):
		paused_reasons.erase(reason)
		session.resumed(reason)
	var now := is_paused()
	if now != was:
		get_tree().paused = now
	pause_overlay.visible = now


func is_paused() -> bool:
	return not paused_reasons.is_empty()


func press_action() -> void:
	if is_paused() or experiment == null:
		return
	var info := experiment.action_info()
	if info.is_empty():
		return
	if not bool(info.get("affordable", true)):
		session.action("button_refused")
		if audio != null:
			audio.play("refuse", 1.0, -4.0)
		if not reduced_motion:
			var home := action_button.position.x
			var tw := action_button.create_tween()
			for i in 4:
				tw.tween_property(action_button, "position:x", home + (10.0 if i % 2 == 0 else -10.0) * (1.0 - i / 4.0), 0.04)
			tw.tween_property(action_button, "position:x", home, 0.04)
		return
	session.action("button")
	experiment.do_action()
	_refresh()
	_refresh_action()


## Anchors `c` by `preset` and puts it at `r` measured from those anchors,
## whatever size the parent has right now.
static func place(c: Control, preset: Control.LayoutPreset, r: Rect2) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = r.position.x
	c.offset_top = r.position.y
	c.offset_right = r.position.x + r.size.x
	c.offset_bottom = r.position.y + r.size.y


func play_rect() -> Rect2:
	return Rect2(0, TOP_UI, size.x, maxf(100.0, size.y - TOP_UI - BOTTOM_UI))


# --- the frame ----------------------------------------------------------------------

func _build_chrome() -> void:
	chrome = Control.new()
	chrome.name = "Chrome"
	chrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chrome)

	back_button = LabIconButton.make("back")
	back_button.name = "Back"
	back_button.position = Vector2(24, 24)
	back_button.pressed.connect(func() -> void: back_requested.emit())
	chrome.add_child(back_button)

	title_label = LabStyle.label(LabRegistry.label(exp_id), 28, Color.WHITE, 8)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	place(title_label, Control.PRESET_CENTER_TOP, Rect2(-150, 42, 300, 50))
	chrome.add_child(title_label)

	restart_button = LabIconButton.make("restart")
	restart_button.name = "Restart"
	place(restart_button, Control.PRESET_TOP_RIGHT, Rect2(-24 - 88, 24, 88, 88))
	restart_button.pressed.connect(restart)
	chrome.add_child(restart_button)

	sound_button = LabIconButton.make("mute" if audio != null and audio.muted else "sound", 72)
	sound_button.name = "Sound"
	place(sound_button, Control.PRESET_TOP_LEFT, Rect2(24 + 88 + 12, 32, 72, 72))
	sound_button.pressed.connect(func() -> void:
		if audio != null:
			audio.muted = not audio.muted
			sound_button.set_icon("mute" if audio.muted else "sound"))
	chrome.add_child(sound_button)

	resource_box = PanelContainer.new()
	resource_box.name = "Resource"
	resource_box.add_theme_stylebox_override("panel", LabStyle.box(Color(1, 1, 1, 0.94), 40))
	resource_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resource_icon = TextureRect.new()
	resource_icon.custom_minimum_size = Vector2(56, 56)
	resource_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	resource_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	resource_icon.texture = LabAtlas.texture("icon_coin")
	resource_value = LabStyle.label("0", 48, LabStyle.INK)
	resource_rate = LabStyle.label("", 26, Color("#4f8a5c"))
	resource_rate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(resource_icon)
	row.add_child(resource_value)
	row.add_child(resource_rate)
	resource_box.add_child(row)
	chrome.add_child(resource_box)

	action_button = Button.new()
	action_button.name = "Action"
	LabStyle.button(action_button, LabStyle.LEAF, 40)
	action_button.custom_minimum_size = Vector2(560, 128)
	place(action_button, Control.PRESET_CENTER_BOTTOM, Rect2(-280, -128 - 48, 560, 128))
	action_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	action_button.pressed.connect(press_action)
	var inner := HBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 14)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_icon = TextureRect.new()
	action_icon.custom_minimum_size = Vector2(76, 76)
	action_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	action_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	action_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_label = LabStyle.label("", 40, Color.WHITE, 6)
	action_coin = TextureRect.new()
	action_coin.custom_minimum_size = Vector2(44, 44)
	action_coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	action_coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	action_coin.texture = LabAtlas.texture("icon_coin")
	action_coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_cost = LabStyle.label("", 40, Color.WHITE, 6)
	for n: Control in [action_icon, action_label, action_coin, action_cost]:
		n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		inner.add_child(n)
	action_button.add_child(inner)
	chrome.add_child(action_button)

	clock_label = LabStyle.label("0:00", 28, Color.WHITE, 6)
	clock_label.name = "Clock"
	clock_label.position = Vector2(28, 124)
	clock_label.visible = dev
	chrome.add_child(clock_label)
	report_button = LabIconButton.make("report", 64)
	report_button.name = "Report"
	report_button.position = Vector2(110, 116)
	report_button.visible = dev
	report_button.pressed.connect(toggle_report)
	chrome.add_child(report_button)

	_build_pause()
	_build_report()


func _build_pause() -> void:
	pause_overlay = ColorRect.new()
	pause_overlay.name = "Paused"
	(pause_overlay as ColorRect).color = Color(0.04, 0.1, 0.16, 0.55)
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.visible = false
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var play := LabIconButton.make("play", 160)
	place(play, Control.PRESET_CENTER, Rect2(-80, -80, 160, 160))
	play.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_overlay.add_child(play)
	# A tap means the player is back: the window has focus again.
	pause_overlay.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			set_pause("focus", false))
	add_child(pause_overlay)


func _build_report() -> void:
	report_panel = PanelContainer.new()
	report_panel.name = "ReportPanel"
	report_panel.add_theme_stylebox_override("panel", LabStyle.box(LabStyle.CREAM, 32))
	report_panel.custom_minimum_size = Vector2(620, 0)
	report_panel.visible = false
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	report_text = LabStyle.label("", 26)
	report_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report_text.custom_minimum_size = Vector2(580, 0)
	col.add_child(LabStyle.label("Run report (local only)", 32))
	col.add_child(report_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	for spec: Array in [["JSON", func() -> void: LabWeb.download(session.to_json(), session.file_stem() + ".json", "application/json")],
			["CSV", func() -> void: LabWeb.download(session.to_csv(), session.file_stem() + ".csv", "text/csv")],
			["Close", toggle_report]]:
		var b := Button.new()
		b.text = String(spec[0])
		LabStyle.button(b, LabStyle.LEAF if spec[0] != "Close" else LabStyle.MUTED, 30)
		b.custom_minimum_size = Vector2(180, 80)
		b.pressed.connect(spec[1])
		row.add_child(b)
		report_buttons["report_" + String(spec[0]).to_lower()] = b
	col.add_child(row)
	report_panel.add_child(col)
	add_child(report_panel)


func toggle_report() -> void:
	report_panel.visible = not report_panel.visible
	if report_panel.visible:
		report_text.text = report_lines()
		report_panel.reset_size()
		report_panel.position = (size - report_panel.size) * 0.5


## The headline numbers of this run, as the report panel shows them.
func report_lines() -> String:
	var s := session.summary()
	var lines: Array[String] = [
		"%s  ·  play %s  ·  engaged %s" % [LabRegistry.label(exp_id), _clock(float(s["active_seconds"])), _clock(float(s["engaged_seconds"]))],
		"actions %d  ·  upgrades %d  ·  first upgrade %s" % [int(s["actions"]), (s["upgrades"] as Array).size(), "-" if s["first_upgrade_s"] == null else "%ss" % str(s["first_upgrade_s"])],
		"idle %ss (longest %ss)  ·  pauses %d" % [str(s["idle_seconds"]), str(s["longest_idle_s"]), int(s["pauses"])],
	]
	for k: String in s["metrics"]:
		lines.append("%s: %s" % [k, str(s["metrics"][k])])
	if finished.size() > 0:
		lines.append("earlier runs this visit: %d" % finished.size())
	return "\n".join(lines)


func _refresh() -> void:
	if experiment == null:
		return
	var h := experiment.hud()
	resource_box.visible = not h.is_empty()
	if not h.is_empty():
		var v := float(h.get("value", 0))
		if v != _shown_value:
			_shown_value = v
			resource_value.text = _short(v)
		var rate := float(h.get("rate", 0.0))
		resource_rate.text = ("+%s/s" % _short_rate(rate)) if rate > 0.0 else ""
		var icon := String(h.get("icon", "icon_coin"))
		if LabAtlas.has(icon):
			resource_icon.texture = LabAtlas.texture(icon)
		resource_box.reset_size()
		resource_box.position = Vector2((size.x - resource_box.size.x) * 0.5, 112)
		if fx != null:
			fx.coin_target = fx.get_global_transform().affine_inverse() * (resource_icon.get_global_rect().get_center())
	if clock_label.visible:
		clock_label.text = _clock(session.active_ms / 1000.0)
	var info := experiment.action_info()
	if info.get("affordable") != _last_info.get("affordable") or info.get("cost") != _last_info.get("cost") or info.get("label") != _last_info.get("label") or info.get("icon") != _last_info.get("icon") or info.get("tint") != _last_info.get("tint"):
		_refresh_action()


func _refresh_action() -> void:
	if experiment == null:
		return
	var info := experiment.action_info()
	_last_info = info.duplicate()
	action_button.visible = not info.is_empty()
	if info.is_empty():
		return
	action_label.text = String(info.get("label", ""))
	var cost := int(info.get("cost", -1))
	action_coin.visible = cost >= 0
	action_cost.visible = cost >= 0
	action_cost.text = _short(cost)
	var icon := String(info.get("icon", ""))
	var tex: Texture2D = info.get("texture")
	action_icon.visible = tex != null or (icon != "" and LabAtlas.has(icon))
	if tex != null:
		action_icon.texture = tex
	elif action_icon.visible:
		action_icon.texture = LabAtlas.texture(icon)
	action_icon.modulate = info.get("tint", Color.WHITE)
	var ok := bool(info.get("affordable", true))
	LabStyle.button(action_button, LabStyle.LEAF if ok else Color("#9aa7a0"), 40)
	action_button.modulate = Color.WHITE


static func _short(v: float) -> String:
	if v >= 1.0e9:
		return "%.1fB" % (v / 1.0e9)
	if v >= 1.0e6:
		return "%.1fM" % (v / 1.0e6)
	if v >= 1.0e4:
		return "%.1fK" % (v / 1.0e3)
	return str(int(floor(v)))


static func _short_rate(v: float) -> String:
	if v >= 10.0:
		return _short(v)
	return ("%.1f" % v).trim_suffix(".0")


static func _clock(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [s / 60, s % 60]


# --- for tests and window.funlab ------------------------------------------------------------------

## Where the frame's controls are, in canvas pixels.
func rects() -> Dictionary:
	var out := {}
	var pairs: Array = [["back", back_button], ["restart", restart_button], ["sound", sound_button], ["action", action_button], ["report", report_button], ["resource", resource_box]]
	for k: String in report_buttons:
		pairs.append([k, report_buttons[k]])
	for pair: Array in pairs:
		var c: Control = pair[1]
		if c.is_visible_in_tree():
			var r := c.get_global_rect()
			out[pair[0]] = [r.position.x, r.position.y, r.size.x, r.size.y]
	return out


func state() -> Dictionary:
	return {
		"id": exp_id,
		"playable": LabRegistry.playable(exp_id),
		"runs": runs,
		"paused": is_paused(),
		"paused_reasons": paused_reasons.keys(),
		"hud": experiment.hud() if experiment != null else {},
		"action": experiment.action_info() if experiment != null else {},
		"experiment": experiment.state() if experiment != null else {},
		"session": session.summary() if session != null else {},
		"finished": finished.size(),
		"muted": audio.muted if audio != null else false,
		"reduced_motion": reduced_motion,
		"rects": rects(),
	}
