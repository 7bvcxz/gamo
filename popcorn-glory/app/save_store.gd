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

## Step 46: the page's store, as a JS object the save is passed to as an argument. Until 0.46
## the whole save was pasted into the source of a `JavaScriptBridge.eval` every 5 s -- each
## save a new script for the browser to compile and keep, and at 44 machines the page's heap
## grew ~60 MB in four minutes with the sound off (evidence/step46/perf/).
static var _js: Variant = null


static func _store() -> Variant:
	if _js == null:
		JavaScriptBridge.eval("window.__popcornStore = window.__popcornStore || {" +
			"read: function (k) { try { return localStorage.getItem(k); } catch (e) { return null; } }," +
			"write: function (k, v) { try { localStorage.setItem(k, v); return 1; } catch (e) { return 0; } }," +
			"remove: function (k) { try { localStorage.removeItem(k); } catch (e) {} return 1; } };", true)
		_js = JavaScriptBridge.get_interface("__popcornStore")
	return _js


static func _web() -> bool:
	return OS.has_feature("web")


static func read(name: String) -> String:
	if _web():
		var v: Variant = _store().read(KEY_PREFIX + name)
		return String(v) if typeof(v) == TYPE_STRING else ""
	var path := FILE_PREFIX + name + ".json"
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


static func write(name: String, text: String) -> bool:
	if _web():
		# 1/0, not true/false: a JS boolean from eval does not compare equal to
		# GDScript's true (app/web.gd prefers_reduced_motion, Step 12).
		var ok: Variant = _store().write(KEY_PREFIX + name, text)
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
		_store().remove(KEY_PREFIX + name)
		return
	var path := FILE_PREFIX + name + ".json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
