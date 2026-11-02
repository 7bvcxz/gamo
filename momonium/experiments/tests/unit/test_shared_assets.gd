extends "res://tests/framework/test_case.gd"

## shared/ holds copies of the game's own files (tools/sync_shared.sh). Each
## must be byte-identical to its source in momonium/ and imported the same
## way; nothing unlisted may sit there.


func _manifest() -> Dictionary:
	return (JSON.parse_string(FileAccess.get_file_as_string("res://shared/MANIFEST.json")) as Dictionary)["files"]


func _game() -> String:
	return ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()


func test_every_copy_matches_its_source() -> void:
	var files := _manifest()
	assert_true(files.size() >= 20, "the manifest lists the copies (%d)" % files.size())
	for dst: String in files:
		var src := _game().path_join(String(files[dst]))
		assert_true(FileAccess.file_exists(src), "%s's source %s exists" % [dst, src])
		var a := FileAccess.get_file_as_bytes("res://" + dst)
		var b := FileAccess.get_file_as_bytes(src)
		assert_true(a.size() > 0, dst + " was read")
		assert_eq(a.size(), b.size(), dst + ": same size as the game's (run tools/sync_shared.sh)")
		assert_true(a == b, dst + ": same bytes as the game's (run tools/sync_shared.sh)")


func test_copies_import_like_their_sources() -> void:
	var files := _manifest()
	for dst: String in files:
		var src := _game().path_join(String(files[dst])) + ".import"
		if not FileAccess.file_exists(src):
			continue
		assert_eq(_params("res://" + dst + ".import"), _params(src), dst + ": the game's import settings")


func test_nothing_unlisted() -> void:
	var files := _manifest()
	var stray: Array[String] = []
	for path: String in _walk("res://shared"):
		var rel := path.trim_prefix("res://")
		if rel == "shared/MANIFEST.json" or rel.ends_with(".import") or rel.ends_with(".uid"):
			continue
		if not files.has(rel):
			stray.append(rel)
	assert_eq(stray, [] as Array[String], "every file in shared/ is a listed copy")


func _params(path: String) -> String:
	var text := FileAccess.get_file_as_string(path)
	var at := text.find("[params]")
	return text.substr(at) if at >= 0 else ""


func _walk(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	for f: String in d.get_files():
		out.append(dir.path_join(f))
	for sub: String in d.get_directories():
		out.append_array(_walk(dir.path_join(sub)))
	return out
