class_name WebStorage
extends RefCounted

## The browser's localStorage, as a synchronous second copy of the save.
##
## Godot's web build keeps user:// in memory and copies it to IndexedDB on the
## frame after a file is written -- asynchronously, and only while frames run.
## A tab closed (or hidden, which stops frames) right after a save can lose
## it. localStorage writes are synchronous, so the same text is mirrored there
## and the newer of the two is opened. Elsewhere this does nothing.


static func available() -> bool:
	return OS.has_feature("web")


static func set_item(key: String, text: String) -> bool:
	if not available():
		return false
	var storage: JavaScriptObject = JavaScriptBridge.get_interface("localStorage")
	if storage == null:
		return false
	storage.setItem(key, text)
	return true


static func get_item(key: String) -> String:
	if not available():
		return ""
	var storage: JavaScriptObject = JavaScriptBridge.get_interface("localStorage")
	if storage == null:
		return ""
	var v: Variant = storage.getItem(key)
	return String(v) if typeof(v) == TYPE_STRING else ""
