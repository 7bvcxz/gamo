class_name PopSaveStore
extends RefCounted

## The one place this game stores anything (Step 12: the stand's save). Every
## other script is kept from storage by tests/unit/test_isolation.gd.
##
## On the web: this page's localStorage under "popcorn-glory.<name>" --
## synchronous, so it is written before a phone kills a hidden tab. (Godot's
## user:// on the web is one IndexedDB folder for every Godot game of the
## origin and syncs later; Step 01 decided against it.)
## Elsewhere (the editor, headless tests): user://popcorn_glory_<name>.json.

const KEY_PREFIX := "popcorn-glory."
const FILE_PREFIX := "user://popcorn_glory_"


static func _web() -> bool:
	return OS.has_feature("web")


static func read(name: String) -> String:
	if _web():
		var v: Variant = JavaScriptBridge.eval("(function(){try{return localStorage.getItem(%s)}catch(e){return null}})()" % JSON.stringify(KEY_PREFIX + name), true)
		return String(v) if typeof(v) == TYPE_STRING else ""
	var path := FILE_PREFIX + name + ".json"
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


static func write(name: String, text: String) -> bool:
	if _web():
		# 1/0, not true/false: a JS boolean from eval does not compare equal to
		# GDScript's true (app/web.gd prefers_reduced_motion, Step 12).
		var ok: Variant = JavaScriptBridge.eval("(function(){try{localStorage.setItem(%s,%s);return 1}catch(e){return 0}})()" % [JSON.stringify(KEY_PREFIX + name), JSON.stringify(text)], true)
		return ok != null and int(ok) == 1
	var f := FileAccess.open(FILE_PREFIX + name + ".json", FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return true


static func clear(name: String) -> void:
	if _web():
		JavaScriptBridge.eval("(function(){try{localStorage.removeItem(%s)}catch(e){}})()" % JSON.stringify(KEY_PREFIX + name), true)
		return
	var path := FILE_PREFIX + name + ".json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
