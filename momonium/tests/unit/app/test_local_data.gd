extends "res://tests/framework/test_case.gd"

## Step 80: LocalData -- every store Momonium keeps on the device, in one list,
## erased all together or not at all, and nothing else: another game's files
## and keys stay; a store that cannot be removed puts back what went and says
## so.

const SAVE := "user://test_reset_save.json"
const SETTINGS := "user://test_reset_settings.json"
const OTHER := "user://test_reset_other_game.json"


## Web keys in a dictionary (headless has no localStorage), files as they
## are; `fail` names a store whose removal fails.
class FakeIO extends LocalData.IO:
	var web := {}
	var fail := ""

	func has(s: Dictionary) -> bool:
		return web.has(s["name"]) if s["kind"] == "web" else super.has(s)

	func read(s: Dictionary) -> String:
		return String(web.get(s["name"], "")) if s["kind"] == "web" else super.read(s)

	func remove(s: Dictionary) -> bool:
		if String(s["name"]) == fail:
			return false
		if s["kind"] == "web":
			web.erase(s["name"])
			return true
		return super.remove(s)

	func write(s: Dictionary, text: String) -> bool:
		if s["kind"] == "web":
			web[s["name"]] = text
			return true
		return super.write(s, text)


func _put(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func before_each() -> void:
	for suffix: String in ["", ".tmp", ".bak", ".corrupt"]:
		_put(SAVE + suffix, "island" + suffix)
	_put(SETTINGS, "settings")
	_put(OTHER, "another game")


func after_each() -> void:
	for p: String in [SAVE, SAVE + ".tmp", SAVE + ".bak", SAVE + ".corrupt", SETTINGS, OTHER]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _fake() -> FakeIO:
	var io := FakeIO.new()
	io.web = {"momonium_save": "mirror", "momonium_settings": "settings mirror", "motorio_save": "another game", "gamo_site": "x"}
	return io


func test_the_stores_are_this_games_by_name_and_nothing_else() -> void:
	var names: Array = LocalData.stores(SaveService.DEFAULT_PATH, SettingsStore.PATH).map(func(s: Dictionary) -> String: return s["name"])
	assert_eq(names, ["user://momonium_save.json", "user://momonium_save.json.tmp", "user://momonium_save.json.bak", "user://momonium_save.json.corrupt",
		"momonium_save", "user://momonium_settings.json", "momonium_settings"], "the save and its fragments, its mirror, the settings and theirs")
	for n: String in names:
		assert_true(n.begins_with("user://momonium_") or n.begins_with("momonium_"), "%s: Momonium's own, by full name" % n)
		assert_false(n.contains("*") or n == "user://" or n.ends_with("/"), "%s: no pattern, folder or database" % n)
	for n: String in names:
		for word: String in ["purchase", "entitle", "store", "receipt", "sku"]:
			assert_false(n.contains(word), "%s: no purchase record (none is kept on the device)" % n)


func test_reset_erases_every_store_and_nothing_else() -> void:
	var io := _fake()
	var r := LocalData.reset(SAVE, SETTINGS, io)
	assert_true(r["ok"], "reset")
	assert_eq((r["cleared"] as Array).size(), 7, "all seven were there and are gone (%s)" % [r["cleared"]])
	for suffix: String in ["", ".tmp", ".bak", ".corrupt"]:
		assert_false(FileAccess.file_exists(SAVE + suffix), "the save%s is gone" % suffix)
	assert_false(FileAccess.file_exists(SETTINGS), "the settings are gone")
	assert_false(io.web.has("momonium_save") or io.web.has("momonium_settings"), "and both mirrors")
	assert_eq(FileAccess.get_file_as_string(OTHER), "another game", "another game's file is untouched")
	assert_eq(io.web, {"motorio_save": "another game", "gamo_site": "x"}, "and every other key")
	var again := LocalData.reset(SAVE, SETTINGS, io)
	assert_true(again["ok"] and (again["cleared"] as Array).is_empty(), "nothing left: a second reset finds nothing and is fine")


func test_one_store_that_will_not_go_puts_the_rest_back_and_says_so() -> void:
	for failing: String in [SAVE + ".bak", "momonium_settings", SETTINGS]:
		before_each()
		var io := _fake()
		io.fail = failing
		var r := LocalData.reset(SAVE, SETTINGS, io)
		assert_false(r["ok"], "%s will not go: no reset" % failing)
		assert_eq(r["failed"], [failing], "and it says which")
		assert_eq(r["cleared"], [], "nothing claimed cleared")
		for suffix: String in ["", ".tmp", ".bak", ".corrupt"]:
			assert_eq(FileAccess.get_file_as_string(SAVE + suffix), "island" + suffix, "%s: the save%s is back as it was" % [failing, suffix])
		assert_eq(FileAccess.get_file_as_string(SETTINGS), "settings", "%s: the settings too" % failing)
		assert_eq(io.web.get("momonium_save"), "mirror", "%s: and the mirrors" % failing)
		assert_eq(io.web.get("momonium_settings"), "settings mirror", "")
		assert_eq(FileAccess.get_file_as_string(OTHER), "another game", "another game's file never touched")
