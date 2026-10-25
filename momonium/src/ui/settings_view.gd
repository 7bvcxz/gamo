class_name SettingsView
extends VBoxContainer

## Settings: the language (each named in itself), replaying the first-run
## tutorial, and the demo island for later features -- or the way back from
## it. The actions are signals; the composition root carries them out.

signal language_chosen(code: String)
signal replay_tutorial
signal demo_requested
signal leave_demo_requested

const LANGUAGES := [["en", "English"], ["ko", "한국어"], ["ja", "日本語"], ["zh_CN", "中文"]]

var lang_buttons: Dictionary = {}
var tutorial_button: Button
var demo_button: Button
var demo_note: Label
var in_demo := false
var version_label: Label
## Sound: three volumes, mute, and silence in the background (AudioService).
var audio: AudioService
var sliders: Dictionary = {}
var mute_toggle: CheckButton
var background_toggle: CheckButton
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
	version_label = PanelViews.label("v%s" % ProjectSettings.get_setting("application/config/version", "0"), 14, true)
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(version_label)


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
	(get_node("SoundTitle") as Label).text = tr("settings.sound")
	if audio != null:
		for key: String in sliders:
			(get_node("Row_" + key + "/Label") as Label).text = tr("settings." + key)
			(sliders[key] as HSlider).set_value_no_signal(float(audio.settings.get_value(key)))
		mute_toggle.set_pressed_no_signal(bool(audio.settings.get_value("muted")))
		background_toggle.set_pressed_no_signal(bool(audio.settings.get_value("mute_unfocused")))
	mute_toggle.text = tr("settings.muted")
	background_toggle.text = tr("settings.mute_unfocused")
