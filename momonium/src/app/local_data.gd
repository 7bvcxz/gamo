class_name LocalData
extends RefCounted

## Step 80: everything Momonium keeps on this device, in one list, and the one
## way to erase it (Settings > Advanced > Reset All Data, design/RESET80.md):
##
##   the island save (SaveService) and its write fragments -- `.tmp`, `.bak`,
##   `.corrupt`; its localStorage mirror on the web; the settings (language,
##   tutorial seen, tips seen, sound, screen) and their mirror.
##
## Only these names: user:// on the web is one IndexedDB store for every game
## on the origin and localStorage is shared too, so nothing is wiped by
## pattern, database or prefix -- other games' data and the engine's caches
## are never touched. No purchase is kept here (PremiumStore reads verified
## store records only; there are none yet), so a reset can neither revoke nor
## grant one.
##
## All or nothing: what is there is read first; if any store cannot be
## removed, those already removed are written back, and the result says what
## failed -- a reset is never claimed half done.

## The stores for a save at `save_path` and settings at `settings_path`:
## [{kind: "file" | "web", name}].
static func stores(save_path: String, settings_path: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for suffix: String in ["", ".tmp", ".bak", ".corrupt"]:
		out.append({"kind": "file", "name": save_path + suffix})
	out.append({"kind": "web", "name": SaveService.MIRROR_KEY})
	out.append({"kind": "file", "name": settings_path})
	out.append({"kind": "web", "name": SettingsStore.MIRROR_KEY})
	return out


## Erases every store, or none. {ok, cleared: [names], failed: [names],
## restored: [names]} -- `cleared` lists what was there and is gone.
static func reset(save_path: String, settings_path: String, io: IO = null) -> Dictionary:
	var store_io := io if io != null else IO.new()
	var held: Array[Dictionary] = []
	for s: Dictionary in stores(save_path, settings_path):
		if store_io.has(s):
			held.append({"store": s, "text": store_io.read(s)})
	var cleared: Array[String] = []
	var failed: Array[String] = []
	for h: Dictionary in held:
		var s: Dictionary = h["store"]
		if store_io.remove(s) and not store_io.has(s):
			cleared.append(String(s["name"]))
		else:
			failed.append(String(s["name"]))
	if failed.is_empty():
		return {"ok": true, "cleared": cleared, "failed": failed, "restored": []}
	# Put back what went: the island and its settings as they were.
	var restored: Array[String] = []
	for h: Dictionary in held:
		var s: Dictionary = h["store"]
		if cleared.has(String(s["name"])) and store_io.write(s, String(h["text"])):
			restored.append(String(s["name"]))
	return {"ok": false, "cleared": [], "failed": failed, "restored": restored}


## Reading, removing and writing a store: files through the engine, web keys
## through localStorage. A test replaces it to make a store fail.
class IO:
	func has(s: Dictionary) -> bool:
		if s["kind"] == "web":
			return WebStorage.has_item(String(s["name"]))
		return FileAccess.file_exists(String(s["name"]))

	func read(s: Dictionary) -> String:
		if s["kind"] == "web":
			return WebStorage.get_item(String(s["name"]))
		return FileAccess.get_file_as_string(String(s["name"]))

	func remove(s: Dictionary) -> bool:
		if s["kind"] == "web":
			return WebStorage.remove_item(String(s["name"]))
		return DirAccess.remove_absolute(String(s["name"])) == OK

	func write(s: Dictionary, text: String) -> bool:
		if s["kind"] == "web":
			return WebStorage.set_item(String(s["name"]), text)
		var f := FileAccess.open(String(s["name"]), FileAccess.WRITE)
		if f == null:
			return false
		f.store_string(text)
		f.close()
		return true
