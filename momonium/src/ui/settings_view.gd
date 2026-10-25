class_name SettingsView
extends VBoxContainer

## Settings: the language (each named in itself), replaying the first-run
## tutorial, and the demo island for later features -- or the way back from
## it. The actions are signals; the composition root carries them out.

signal language_chosen(code: String)
signal replay_tutorial
signal demo_requested
signal leave_demo_requested
signal large_demo_requested
## Screen and help options the composition root applies.
signal option_changed(key: String, value: Variant)
signal save_requested
signal replay_tips

const LANGUAGES := [["en", "English"], ["ko", "한국어"], ["ja", "日本語"], ["zh_CN", "中文"]]

var lang_buttons: Dictionary = {}
var tutorial_button: Button
var demo_button: Button
var demo_note: Label
var large_demo_button: Button
var perf_toggle: CheckButton
var in_demo := false
var version_label: Label
var about_label: Label
## Sound: three volumes, mute, and silence in the background (AudioService).
var audio: AudioService
var sliders: Dictionary = {}
var mute_toggle: CheckButton
var background_toggle: CheckButton
var scale_slider: HSlider
var low_power_toggle: CheckButton
var camera_toggle: CheckButton
var tips_toggle: CheckButton
var effects_toggle: CheckButton
var motion_toggle: CheckButton
var tips_button: Button
var save_button: Button
var save_note: Label
## Where options are read from (the composition root's SettingsStore).
var settings: SettingsStore
const SOUND: PackedStringArray = ["music_volume", "ambience_volume", "sfx_volume"]


func setup(_sim: Simulation, _lib: SpriteLibrary) -> void:
	name = "SettingsView"
	add_theme_constant_override("separation", 12)
	var lang_title := PanelViews.label("", 17, true)
	lang_title.name = "LanguageTitle"
	add_child(lang_title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for pair: Array in LANGUAGES:
		var b := Button.new()
		b.name = "Lang_" + String(pair[0])
		b.text = String(pair[1])
		b.custom_minimum_size = Vector2(0, 52)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		var code := String(pair[0])
		b.pressed.connect(func() -> void: language_chosen.emit(code))
		row.add_child(b)
		lang_buttons[code] = b
	add_child(row)
	tutorial_button = _wide("Tutorial")
	tutorial_button.pressed.connect(func() -> void: replay_tutorial.emit())
	add_child(tutorial_button)
	demo_button = _wide("Demo")
	demo_button.pressed.connect(func() -> void:
		if in_demo:
			leave_demo_requested.emit()
		else:
			demo_requested.emit())
	add_child(demo_button)
	demo_note = PanelViews.label("", 15, true)
	demo_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(demo_note)
	# A big, busy island to see how the game holds up (never saved either).
	large_demo_button = _wide("LargeDemo")
	large_demo_button.pressed.connect(func() -> void: large_demo_requested.emit())
	add_child(large_demo_button)
	# And how hard the game is working, beside it.
	perf_toggle = _toggle("Performance", "perf_overlay")
	var sound_title := PanelViews.label("", 17, true)
	sound_title.name = "SoundTitle"
	add_child(sound_title)
	for key: String in SOUND:
		var r := HBoxContainer.new()
		r.name = "Row_" + key
		r.add_theme_constant_override("separation", 10)
		var l := PanelViews.label("", 16)
		l.name = "Label"
		l.custom_minimum_size = Vector2(110, 0)
		r.add_child(l)
		var s := HSlider.new()
		s.name = "Slider"
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.custom_minimum_size = Vector2(0, 44)
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		s.focus_mode = Control.FOCUS_NONE
		var k := key
		s.value_changed.connect(func(v: float) -> void:
			if audio != null:
				audio.set_setting(k, v))
		r.add_child(s)
		add_child(r)
		sliders[key] = s
	mute_toggle = CheckButton.new()
	mute_toggle.name = "Mute"
	mute_toggle.custom_minimum_size = Vector2(0, 48)
	mute_toggle.focus_mode = Control.FOCUS_NONE
	mute_toggle.toggled.connect(func(on: bool) -> void:
		if audio != null:
			audio.set_setting("muted", on))
	add_child(mute_toggle)
	background_toggle = CheckButton.new()
	background_toggle.name = "Background"
	background_toggle.custom_minimum_size = Vector2(0, 48)
	background_toggle.focus_mode = Control.FOCUS_NONE
	background_toggle.toggled.connect(func(on: bool) -> void:
		if audio != null:
			audio.set_setting("mute_unfocused", on))
	add_child(background_toggle)
	var screen_title := PanelViews.label("", 17, true)
	screen_title.name = "ScreenTitle"
	add_child(screen_title)
	var srow := HBoxContainer.new()
	srow.name = "Row_ui_scale"
	srow.add_theme_constant_override("separation", 10)
	var sl := PanelViews.label("", 16)
	sl.name = "Label"
	sl.custom_minimum_size = Vector2(110, 0)
	srow.add_child(sl)
	scale_slider = HSlider.new()
	scale_slider.name = "Slider"
	scale_slider.min_value = 0.85
	scale_slider.max_value = 1.25
	scale_slider.step = 0.05
	scale_slider.custom_minimum_size = Vector2(0, 44)
	scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	scale_slider.focus_mode = Control.FOCUS_NONE
	# Applied when the finger lets go: the whole screen re-lays itself out.
	scale_slider.drag_ended.connect(func(_changed: bool) -> void: option_changed.emit("ui_scale", scale_slider.value))
	scale_slider.value_changed.connect(func(v: float) -> void:
		if not scale_slider.has_meta("dragging"):
			option_changed.emit("ui_scale", v))
	scale_slider.drag_started.connect(func() -> void: scale_slider.set_meta("dragging", true))
	scale_slider.drag_ended.connect(func(_c: bool) -> void: scale_slider.remove_meta("dragging"))
	srow.add_child(scale_slider)
	add_child(srow)
	low_power_toggle = _toggle("LowPower", "low_power")
	camera_toggle = _toggle("CameraButtons", "camera_buttons")
	tips_toggle = _toggle("Tips", "tips")
	effects_toggle = _toggle("Effects", "effects")
	motion_toggle = _toggle("ReduceMotion", "reduce_motion")
	tips_button = _wide("ReplayTips")
	tips_button.pressed.connect(func() -> void: replay_tips.emit())
	add_child(tips_button)
	save_button = _wide("SaveNow")
	save_button.pressed.connect(func() -> void: save_requested.emit())
	add_child(save_button)
	save_note = PanelViews.label("", 14, true)
	save_note.name = "SaveNote"
	add_child(save_note)
	# About: which build on which platform, and that the island is the
	# player's alone -- no server, no leaderboard, saved on this device.
	var about_title := PanelViews.label("", 17, true)
	about_title.name = "AboutTitle"
	add_child(about_title)
	about_label = PanelViews.label("", 14, true)
	about_label.name = "About"
	about_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(about_label)
	version_label = PanelViews.label("v%s" % ProjectSettings.get_setting("application/config/version", "0"), 14, true)
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(version_label)


## "web", "android", "ios" or "desktop" -- where this build runs.
static func platform() -> String:
	if OS.has_feature("web"):
		return "web"
	if OS.has_feature("android"):
		return "android"
	if OS.has_feature("ios"):
		return "ios"
	return "desktop"


## Solo and local: no server or leaderboard; where the island is kept and
## what would remove it on this platform.
func about_text() -> String:
	var where := "settings.about_storage_web" if platform() == "web" else "settings.about_storage_device"
	return "%s\n%s" % [tr("settings.about_solo"), tr(where)]


func _toggle(node_name: String, key: String) -> CheckButton:
	var t := CheckButton.new()
	t.name = node_name
	t.custom_minimum_size = Vector2(0, 48)
	t.focus_mode = Control.FOCUS_NONE
	t.toggled.connect(func(on: bool) -> void: option_changed.emit(key, on))
	add_child(t)
	return t


func _wide(node_name: String) -> Button:
	var b := Button.new()
	b.name = node_name
	b.custom_minimum_size = Vector2(0, 56)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 19)
	return b


func refresh() -> void:
	(get_node("LanguageTitle") as Label).text = tr("settings.language")
	var current := LocaleService.current()
	for code: String in lang_buttons:
		(lang_buttons[code] as Button).modulate = Color(1.25, 1.2, 0.85) if code == current else Color(1, 1, 1, 0.8)
	tutorial_button.text = tr("settings.tutorial")
	demo_button.text = tr("settings.leave_demo") if in_demo else tr("settings.demo")
	demo_note.text = "" if in_demo else tr("settings.demo_note")
	large_demo_button.visible = not in_demo
	large_demo_button.text = tr("settings.large_demo")
	(get_node("SoundTitle") as Label).text = tr("settings.sound")
	if audio != null:
		for key: String in sliders:
			(get_node("Row_" + key + "/Label") as Label).text = tr("settings." + key)
			(sliders[key] as HSlider).set_value_no_signal(float(audio.settings.get_value(key)))
		mute_toggle.set_pressed_no_signal(bool(audio.settings.get_value("muted")))
		background_toggle.set_pressed_no_signal(bool(audio.settings.get_value("mute_unfocused")))
	mute_toggle.text = tr("settings.muted")
	background_toggle.text = tr("settings.mute_unfocused")
	(get_node("ScreenTitle") as Label).text = tr("settings.screen")
	(get_node("Row_ui_scale/Label") as Label).text = tr("settings.ui_scale")
	low_power_toggle.text = tr("settings.low_power")
	camera_toggle.text = tr("settings.camera_buttons")
	tips_toggle.text = tr("settings.tips")
	effects_toggle.text = tr("settings.effects")
	motion_toggle.text = tr("settings.reduce_motion")
	perf_toggle.text = tr("settings.perf_overlay")
	tips_button.text = tr("settings.replay_tips")
	save_button.text = tr("settings.save_now")
	(get_node("AboutTitle") as Label).text = tr("settings.about")
	about_label.text = about_text()
	version_label.text = tr("settings.about_build").format({"v": ProjectSettings.get_setting("application/config/version", "0"), "p": tr("settings.platform." + platform())})
	if settings != null:
		scale_slider.set_value_no_signal(float(settings.get_value("ui_scale")))
		low_power_toggle.set_pressed_no_signal(bool(settings.get_value("low_power")))
		camera_toggle.set_pressed_no_signal(bool(settings.get_value("camera_buttons")))
		tips_toggle.set_pressed_no_signal(bool(settings.get_value("tips")))
		effects_toggle.set_pressed_no_signal(bool(settings.get_value("effects")))
		motion_toggle.set_pressed_no_signal(bool(settings.get_value("reduce_motion")))
		perf_toggle.set_pressed_no_signal(bool(settings.get_value("perf_overlay")))
