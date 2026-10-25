extends "res://tests/framework/test_case.gd"

## Every word the game shows exists in English, Korean, Japanese and
## Simplified Chinese: each row of the table complete, each key the code asks
## for and each name the data gives present.

const LANGS := ["en", "ko", "ja", "zh_CN"]


func _rows() -> Dictionary:
	var f := FileAccess.open("res://data/i18n/ui.csv", FileAccess.READ)
	var head := f.get_csv_line()
	var out := {}
	while not f.eof_reached():
		var r := f.get_csv_line()
		if r.size() >= 1 and r[0] != "":
			out[r[0]] = r
	assert_eq(Array(head), ["keys"] + LANGS, "four languages")
	return out


func test_every_row_has_all_four() -> void:
	var missing: Array = []
	var rows := _rows()
	for k: String in rows:
		var r: PackedStringArray = rows[k]
		if r.size() < 5:
			missing.append(k)
			continue
		for i in range(1, 5):
			if r[i].strip_edges() == "":
				missing.append("%s/%s" % [k, LANGS[i - 1]])
	assert_eq(missing, [], "no empty translation")


func test_every_key_the_code_asks_for() -> void:
	var rows := _rows()
	var re := RegEx.create_from_string("(?:tr|translate)\\(\"([a-z0-9_.]+)\"\\)")
	var missing: Array = []
	var found := 0
	for path: String in _scripts("res://src"):
		for m: RegExMatch in re.search_all(FileAccess.get_file_as_string(path)):
			found += 1
			if not rows.has(m.get_string(1)):
				missing.append("%s in %s" % [m.get_string(1), path])
	assert_true(found > 150, "the scan really reads the code (%d keys)" % found)
	assert_eq(missing, [], "every tr() key is in the table")


func test_every_name_the_data_gives() -> void:
	var rows := _rows()
	var missing: Array = []
	var key := RegEx.create_from_string("^[a-z0-9_]+(\\.[a-z0-9_]+)+$")
	var seen := [0]
	for file: String in ["buildings", "research", "items", "letters", "recipes"]:
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % file))
		_walk(data, rows, key, missing, file, seen)
	assert_true(int(seen[0]) > 100, "the walk really reads the data (%d names)" % seen[0])
	assert_eq(missing, [], "every name and description in the data is translated")


func _walk(o: Variant, rows: Dictionary, key: RegEx, missing: Array, file: String, seen: Array) -> void:
	if typeof(o) == TYPE_DICTIONARY:
		for k: Variant in o:
			var v: Variant = o[k]
			if String(k) in ["name", "desc", "label", "title", "body", "sender", "text"] and typeof(v) == TYPE_STRING and key.search(v) != null:
				seen[0] = int(seen[0]) + 1
				if not rows.has(v):
					missing.append("%s: %s" % [file, v])
			_walk(v, rows, key, missing, file, seen)
	elif typeof(o) == TYPE_ARRAY:
		for v: Variant in o:
			_walk(v, rows, key, missing, file, seen)


func _scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	for f: String in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for sub: String in d.get_directories():
		out.append_array(_scripts(dir + "/" + sub))
	return out
