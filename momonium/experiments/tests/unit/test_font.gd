extends "res://tests/framework/test_case.gd"

## The Lab draws its text with the game's font (shared/fonts/ui_ko.otf, a
## subset): every character the Lab's code writes must be in it, or it shows
## as a box. (The frame's icons are shapes for this reason.)


func test_every_character_is_in_the_font() -> void:
	var font: FontFile = load("res://shared/fonts/ui_ko.otf")
	var literal := RegEx.create_from_string("\"((?:[^\"\\\\]|\\\\.)*)\"")
	var missing := {}
	var seen := 0
	for path: String in _sources("res://lab") + _sources("res://experiments"):
		# Code for the page and the record, never drawn.
		if path.get_file() in ["bridge.gd", "web.gd", "route.gd", "session.gd"]:
			continue
		for m: RegExMatch in literal.search_all(FileAccess.get_file_as_string(path)):
			var s := m.get_string(1)
			if s.begins_with("res://") or s.contains("%s") and s.length() < 4:
				continue
			for i in s.length():
				var c := s.unicode_at(i)
				if c < 32 or c == 92:
					continue
				seen += 1
				if not font.has_char(c):
					missing[String.chr(c)] = path.get_file()
	assert_true(seen > 500, "the strings were read (%d characters)" % seen)
	assert_eq(missing, {}, "characters the font lacks")


func _sources(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f: String in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub: String in d.get_directories():
		out.append_array(_sources(dir.path_join(sub)))
	return out
