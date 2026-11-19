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
## Step 45: each save has two neighbours under the same prefix -- "<name>.bak" (the
## last good save, the fallback) and "<name>.rejected" (a save this build refused,
## set aside instead of overwritten). web/saves.html reads and restores them.

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
	# Step 45: whole or not at all -- the text goes to a side file, then takes the
	# save's name in one rename (a killed process leaves the old save, not half of
	# a new one). localStorage.setItem above is already all-or-nothing per key.
	var path := FILE_PREFIX + name + ".json"
	var tmp := FILE_PREFIX + name + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	if FileAccess.get_file_as_string(tmp) != text:
		DirAccess.remove_absolute(tmp)
		return false
	return DirAccess.rename_absolute(tmp, path) == OK


static func clear(name: String) -> void:
	if _web():
		JavaScriptBridge.eval("(function(){try{localStorage.removeItem(%s)}catch(e){}})()" % JSON.stringify(KEY_PREFIX + name), true)
		return
	var path := FILE_PREFIX + name + ".json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
