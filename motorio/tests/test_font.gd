extends SceneTree

## Note: this scans the whole source file, comments included. A Korean word in a
## comment is not drawn and does not need a glyph, but it fails here anyway --
## which is why code comments in this project are written in English. Narrowing
## the scan to string literals would need a GDScript parser that understands
## where a `#` is a comment and where it is a colour; being strict costs one
## rule and no parser.

## The UI font is a subset, so it can be missing a character.
##
## The full Noto Sans CJK collection was 16.3 MB of an 18.2 MB pack -- ninety
## percent of a mobile download spent on Japanese and Chinese glyphs this game
## never draws. Cutting it to the characters actually used took it to 90 KB, and
## bought exactly one new failure mode: write a new caption, forget to rebuild
## the font, and a player sees tofu boxes.
##
## So this walks every string the scripts can draw and asks the font whether it
## has the glyph. It is the reason the subset is safe to keep.
##
##   NODE_PATH=/tmp/fonttool/node_modules node motorio/tools/build_font.cjs

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var font: Font = UIFont.FONT
	_assert(font != null, "the UI font loads")
	if font == null:
		quit(1)
		return

	var sources: Array[String] = []
	_gather("res://scripts", sources)
	_gather("res://scenes", sources)
	_assert(sources.size() > 5, "found the game's source files: %d" % sources.size())

	# Every non-ASCII character in the sources, with where it came from, so a
	# failure names the file to look in rather than just the character.
	var origin: Dictionary = {}
	for path: String in sources:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var text: String = file.get_as_text()
		file.close()
		for index in text.length():
			var code: int = text.unicode_at(index)
			# Latin-1 and below is covered by any font. Everything past it is a
			# glyph this subset had to be told to keep.
			if code > 0x7e and not origin.has(code):
				origin[code] = path.get_file()

	var missing: Array[String] = []
	for code: int in origin:
		if not font.has_char(code):
			missing.append("%s (U+%04X, %s)" % [String.chr(code), code, origin[code]])
	_assert(missing.is_empty(),
		"the font carries every character the scripts draw. Missing %d: %s"
		% [missing.size(), ", ".join(missing.slice(0, 12))])
	print("FONT_TEST: %d non-ASCII characters checked" % origin.size())

	# A subset that lost its Hangul entirely would still pass an empty-diff check,
	# so pin a few characters the UI cannot do without.
	for sample: String in ["열", "온", "기", "밤", "숙", "소", "채", "굴", "분", "가", "동", "중"]:
		_assert(font.has_char(sample.unicode_at(0)), "the font can draw '%s'" % sample)

	# And that it is still small. This is the whole point of the exercise; a
	# rebuild that quietly went back to the full collection would restore the
	# four-minute mobile load without breaking anything else.
	var size: int = _file_size("res://assets/ui-font.otf")
	_assert(size > 0, "the font file exists on disk")
	_assert(size < 1_500_000, "and is still a subset rather than the full collection: %d bytes" % size)
	print("FONT_TEST: ui-font.otf is %d bytes" % size)

	if failures == 0:
		print("FONT_TEST: PASS")
	quit(failures)

func _file_size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	var size: int = file.get_length()
	file.close()
	return size

func _gather(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var path: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			_gather(path, out)
		elif entry.ends_with(".gd") or entry.ends_with(".tscn"):
			out.append(path)
		entry = dir.get_next()
	dir.list_dir_end()

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("FONT_TEST: FAIL - " + message)
		failures += 1
