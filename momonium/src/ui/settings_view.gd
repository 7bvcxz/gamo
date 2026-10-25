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
