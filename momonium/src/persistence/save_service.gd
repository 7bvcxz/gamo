class_name SaveService
extends RefCounted

## Writes and reads a Simulation save as JSON, safely.
##
## The file is an envelope: {format, schema, saved_unix, checksum, state}
## where `state` is the simulation's state as a JSON string and `checksum` its
## SHA-256 -- a truncated or edited file is recognised, not half-loaded.
##
## Writes are atomic: the new save goes to "<path>.tmp"; the current save is
## kept as "<path>.bak"; then the new one is renamed into place. A crash at any
## point leaves a complete save in one of the two. Reading tries the save, then
## the backup; a damaged file is kept as "<path>.corrupt" for inspection,
## never silently overwritten. A save from a newer game version is refused and
## left alone (`too_new`), so opening an old build cannot destroy it.

const DEFAULT_PATH := "user://momonium_save.json"
const FORMAT := "momonium"


static func encode(sim: Simulation, saved_unix: int = int(Time.get_unix_time_from_system())) -> String:
	var state := JSON.stringify(sim.save_state(), "", false)
	return JSON.stringify({"format": FORMAT, "schema": Simulation.SAVE_SCHEMA, "saved_unix": saved_unix,
		"checksum": state.sha256_text(), "state": state}, "", false)


## A JSON instance rather than JSON.parse_string: the static helper logs an
## engine error on bad input, and a damaged save is an expected case, not a bug.
static func _parse(text: String) -> Variant:
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data


## Reads a save's text: {status: ok | corrupt | too_new, state, saved_unix}.
## A bare state from before the envelope (schema 1) is accepted with no time.
static func decode(text: String) -> Dictionary:
	var data: Variant = _parse(text)
	if typeof(data) != TYPE_DICTIONARY:
		return {"status": "corrupt", "why": "not json"}
	var env: Dictionary = data
	var state: Dictionary
	var saved_unix := 0
	if env.get("format", "") == FORMAT:
		if typeof(env.get("state")) != TYPE_STRING or String(env["state"]).sha256_text() != String(env.get("checksum", "")):
			return {"status": "corrupt", "why": "checksum"}
		var inner: Variant = _parse(String(env["state"]))
		if typeof(inner) != TYPE_DICTIONARY:
			return {"status": "corrupt", "why": "state"}
		state = inner
		saved_unix = int(env.get("saved_unix", 0))
		if int(env.get("schema", 0)) > Simulation.SAVE_SCHEMA:
			return {"status": "too_new", "schema": int(env["schema"])}
	elif env.has("systems") and env.has("clock"):
		state = env
	else:
		return {"status": "corrupt", "why": "format"}
	if int(state.get("schema", 1)) > Simulation.SAVE_SCHEMA:
		return {"status": "too_new", "schema": int(state.get("schema", 1))}
	var migrated := SaveMigration.migrate(state)
	if migrated.is_empty():
		return {"status": "corrupt", "why": "migration"}
	return {"status": "ok", "state": migrated, "saved_unix": saved_unix}


static func write(sim: Simulation, path: String = DEFAULT_PATH, saved_unix: int = int(Time.get_unix_time_from_system())) -> Error:
	return write_text(encode(sim, saved_unix), path)


## Writes already-encoded save text (so the same text can also go elsewhere).
static func write_text(text: String, path: String = DEFAULT_PATH) -> Error:
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.remove_absolute(path + ".bak")
		var err := DirAccess.rename_absolute(path, path + ".bak")
		if err != OK:
			return err
	return DirAccess.rename_absolute(tmp, path)


## {status: ok | backup | missing | corrupt | too_new, state, saved_unix}.
## `backup` means the save was damaged and the previous one was used.
static func load_save(path: String = DEFAULT_PATH) -> Dictionary:
	var main_exists := FileAccess.file_exists(path)
	var bak_exists := FileAccess.file_exists(path + ".bak")
	if not main_exists and not bak_exists:
		return {"status": "missing"}
	if main_exists:
		var r := decode(FileAccess.get_file_as_string(path))
		if r["status"] == "ok" or r["status"] == "too_new":
			return r
		_keep_corrupt(path)
	if bak_exists:
		var b := decode(FileAccess.get_file_as_string(path + ".bak"))
		if b["status"] == "ok":
			b["status"] = "backup"
			return b
	return {"status": "corrupt"}


static func _keep_corrupt(path: String) -> void:
	if FileAccess.file_exists(path + ".corrupt"):
		DirAccess.remove_absolute(path + ".corrupt")
	DirAccess.copy_absolute(path, path + ".corrupt")


## Of two load results, the one to open: a readable one over an unreadable
## one, and of two readable ones the more recently saved.
static func newest(a: Dictionary, b: Dictionary) -> Dictionary:
	var a_ok := String(a.get("status", "")) in ["ok", "backup"]
	var b_ok := String(b.get("status", "")) in ["ok", "backup"]
	if a_ok and b_ok:
		return b if int(b.get("saved_unix", 0)) > int(a.get("saved_unix", 0)) else a
	if b_ok and not a_ok and String(a.get("status", "")) != "too_new":
		return b
	return a


## The saved state, or {} if there is none or it cannot be read.
static func read(path: String = DEFAULT_PATH) -> Dictionary:
	var r := load_save(path)
	return r.get("state", {}) if r["status"] in ["ok", "backup"] else {}
