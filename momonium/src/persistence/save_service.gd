class_name SaveService
extends RefCounted

## Writes and reads a Simulation save as JSON.
##
## Writes are atomic: the new save goes to "<path>.tmp" and is then renamed over
## the old one, so a crash or a closed tab mid-write leaves the previous save
## intact instead of half a file. Versioning, migration and offline catch-up
## build on this in Step 24.

const DEFAULT_PATH := "user://momonium_save.json"


static func encode(sim: Simulation) -> String:
	return JSON.stringify(sim.save_state(), "", false)


## A JSON instance rather than JSON.parse_string: the static helper logs an
## engine error on bad input, and a damaged save is an expected case, not a bug.
static func decode(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data


static func write(sim: Simulation, path: String = DEFAULT_PATH) -> Error:
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(encode(sim))
	file.close()
	return DirAccess.rename_absolute(tmp, path)


## The saved state, or {} if there is none or it cannot be read.
static func read(path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	return decode(FileAccess.get_file_as_string(path))
