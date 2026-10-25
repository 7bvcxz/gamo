extends "res://tests/framework/test_case.gd"

## Every UI string exists in every language, keeps its placeholders, and every
## character it uses is in that language's bundled font.

const LANGS := ["en", "ko", "ja", "zh_CN"]


func _rows() -> Array:
	var rows: Array = []
	for file: String in DirAccess.get_files_at("res://data/i18n"):
		if not file.ends_with(".csv"):
			continue
		var f := FileAccess.open("res://data/i18n/" + file, FileAccess.READ)
		var header := f.get_csv_line()
		while not f.eof_reached():
			var line := f.get_csv_line()
			if line.size() < 2 or line[0] == "":
				continue
			var row := {"key": line[0]}
			for i in range(1, header.size()):
				row[header[i]] = line[i] if i < line.size() else ""
			rows.append(row)
	return rows


func test_every_key_has_every_language() -> void:
	var rows := _rows()
	assert_true(rows.size() >= 10, "found the UI strings (%d)" % rows.size())
	for row: Dictionary in rows:
		for lang: String in LANGS:
			assert_true(String(row.get(lang, "")).strip_edges() != "", "%s has a %s translation" % [row["key"], lang])


func test_placeholders_match_across_languages() -> void:
	var regex := RegEx.create_from_string("%0?\\d*[ds]")
	for row: Dictionary in _rows():
		var expected := regex.search_all(row["en"]).size()
		for lang: String in LANGS:
			assert_eq(regex.search_all(row[lang]).size(), expected, "%s keeps its %d placeholders in %s" % [row["key"], expected, lang])


func test_fonts_carry_every_character() -> void:
	for row: Dictionary in _rows():
		for pair: Array in [["ko", "res://assets/fonts/ui_ko.otf"], ["ja", "res://assets/fonts/ui_ja.otf"], ["zh_CN", "res://assets/fonts/ui_zh.otf"]]:
			var font: FontFile = load(pair[1])
			# Line breaks (letters are several lines) are layout, not glyphs.
			for ch: String in String(row[pair[0]]).replace("\n", ""):
				assert_true(font.has_char(ch.unicode_at(0)), "%s font draws '%s' (%s) -- run tools/fonts/build_fonts.mjs" % [pair[0], ch, row["key"]])
			for ch: String in String(row["en"]).replace("\n", ""):
				assert_true(font.has_char(ch.unicode_at(0)), "%s font draws English '%s'" % [pair[0], ch])


## Text written straight into UI code (symbols like "›") must be drawable
## too. The web has no system fonts: a glyph missing from our subsets is an
## empty box there even though the desktop shows it -- the "✕" of every close
## button was exactly that until Step 20.
func test_ui_code_literals_have_glyphs() -> void:
	var fonts: Array[FontFile] = []
	for path: String in ["res://assets/fonts/ui_ko.otf", "res://assets/fonts/ui_ja.otf", "res://assets/fonts/ui_zh.otf"]:
		fonts.append(load(path))
	var literal := RegEx.create_from_string('"([^"\\\\]|\\\\.)*"')
	var checked := 0
	for dir: String in ["res://src/ui", "res://src/render", "res://src/actors", "res://src/app"]:
		for file: String in DirAccess.get_files_at(dir):
			if not file.ends_with(".gd"):
				continue
			for line: String in FileAccess.get_file_as_string(dir + "/" + file).split("\n"):
				if line.strip_edges().begins_with("#"):
					continue
				for m: RegExMatch in literal.search_all(line):
					for ch: String in m.get_string():
						if ch.unicode_at(0) < 128:
							continue
						checked += 1
						var drawn := fonts.any(func(f: FontFile) -> bool: return f.has_char(ch.unicode_at(0)))
						assert_true(drawn, "'%s' in %s/%s is in a UI font" % [ch, dir, file])
	assert_true(checked > 0, "found symbols to check (%d)" % checked)


func test_translation_server_has_the_tables() -> void:
	var before := TranslationServer.get_locale()
	for pair: Array in [["en", "Research"], ["ko", "연구"], ["ja", "研究"], ["zh_CN", "研究"]]:
		LocaleService.apply(pair[0])
		assert_eq(String(TranslationServer.translate("hud.research")), pair[1], "hud.research in %s" % pair[0])
	TranslationServer.set_locale(before)


func test_os_locale_detection() -> void:
	assert_eq(LocaleService.detect("ko_KR"), "ko", "Korean")
	assert_eq(LocaleService.detect("ja_JP"), "ja", "Japanese")
	assert_eq(LocaleService.detect("zh_Hans_CN"), "zh_CN", "Simplified Chinese")
	assert_eq(LocaleService.detect("de_DE"), "en", "anything else falls back to English")


func test_each_language_leads_with_its_own_face() -> void:
	var ja: FontFile = LocaleService.font_for("ja")
	var zh: FontFile = LocaleService.font_for("zh_CN")
	assert_eq(ja.fallbacks.size(), 2, "two fallbacks")
	assert_ne(ja.data.size(), zh.data.size(), "Japanese and Chinese use different faces")
