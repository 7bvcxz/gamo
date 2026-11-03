class_name SaveStore
extends RefCounted

## The atelier's progress in this browser or on this machine only
## (user://windup_save.json -- Godot keeps user:// in IndexedDB on the web).
## No account, no server. A save from another schema is ignored, and the game
## starts fresh rather than guessing.

const SCHEMA := 1
const PATH := "user://windup_save.json"

var path: String = PATH


func save(atelier: Atelier, build: String) -> bool:
	var data := {"schema": SCHEMA, "build": build, "saved_unix": int(Time.get_unix_time_from_system()),
		"atelier": atelier.to_dict()}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	return true


## The saved atelier's dictionary, or {} when there is none or it is not ours.
func load_atelier() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	# JSON.new().parse reports a broken file by its return code without
	# logging an engine error (JSON.parse_string logs one).
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	var parsed: Variant = json.data
	if not (parsed is Dictionary) or int((parsed as Dictionary).get("schema", -1)) != SCHEMA:
		return {}
	var a: Variant = (parsed as Dictionary).get("atelier", {})
	return a if a is Dictionary else {}


func clear() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path) if path.begins_with("user://") else path)
