class_name SettingsStore
extends RefCounted

## The player's own preferences, apart from the island: chosen language and
## whether the first-run tutorial has been seen. Kept in
## user://momonium_settings.json and, on the web, mirrored to localStorage
## (synchronous, survives a tab closed at once). Under tests (Engine meta
## "momonium_no_save") it lives in memory only.

const PATH := "user://momonium_settings.json"
const MIRROR_KEY := "momonium_settings"

var values := {"language": "", "tutorial_done": false}
var persistent := true


var path := PATH


static func open() -> SettingsStore:
	var s := SettingsStore.new()
	s.persistent = not Engine.has_meta("momonium_no_save")
	if Engine.has_meta("momonium_settings_path"):
		s.path = String(Engine.get_meta("momonium_settings_path"))
	if s.persistent:
		var text := WebStorage.get_item(MIRROR_KEY)
		if text == "" and FileAccess.file_exists(s.path):
			text = FileAccess.get_file_as_string(s.path)
		var json := JSON.new()
		if text != "" and json.parse(text) == OK and typeof(json.data) == TYPE_DICTIONARY:
			for k: String in s.values:
				if (json.data as Dictionary).has(k):
					s.values[k] = json.data[k]
	return s


func get_value(key: String) -> Variant:
	return values.get(key)


func set_value(key: String, value: Variant) -> void:
	values[key] = value
	if not persistent:
		return
	var text := JSON.stringify(values)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()
	WebStorage.set_item(MIRROR_KEY, text)
