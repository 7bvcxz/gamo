extends "res://tests/framework/test_case.gd"

## Step 62: the loading screen lives in the export's own shell (web/shell.html)
## and the index page template, so every export keeps it. The shared
## deploy-web.sh rewrites four lines of the shell for the runner by matching
## their text: each must be there once, and nowhere else (a comment quoting
## one was rewritten too). The splash fetches nothing: its Momo is inline,
## small, and no other host is named.

const SHELL := "res://web/shell.html"
const LOADER := "res://web/index-loader.html"


func _shell() -> String:
	return FileAccess.get_file_as_string(SHELL)


func test_the_web_export_uses_the_momonium_shell() -> void:
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://export_presets.cfg"), OK, "presets read")
	var found := false
	for section: String in cfg.get_sections():
		if section.ends_with(".options") and cfg.has_section_key(section, "html/custom_html_shell"):
			var preset := section.trim_suffix(".options")
			if String(cfg.get_value(preset, "platform", "")) == "Web":
				assert_eq(String(cfg.get_value(section, "html/custom_html_shell")), SHELL, "the Web preset's shell")
				found = true
	assert_true(found, "a Web preset")


func test_the_lines_deploy_web_rewrites_are_there_once() -> void:
	var s := _shell()
	for line: String in ["const engine = new Engine(GODOT_CONFIG);", "\t\tengine.startGame({", "\t\t}).then(() => {", "\t\t\tsetStatusMode('hidden');"]:
		assert_eq(s.count(line), 1, "once: %s" % line.strip_edges())
	assert_eq(s.count("engine.startGame"), 1, "the start is named nowhere else")
	assert_eq(s.count("new Engine"), 1, "nor the engine")
	assert_eq(s.count("engine.init(GODOT_CONFIG.executable)"), 0, "the runner's own line is not pre-written")
	for ph: String in ["$GODOT_URL", "$GODOT_CONFIG", "$GODOT_THREADS_ENABLED", "$GODOT_HEAD_INCLUDE"]:
		assert_true(s.contains(ph), "Godot fills %s" % ph)


func test_the_splash_is_one_block_shared_with_the_index_page() -> void:
	var s := _shell()
	for m: String in ["<!--splash:begin-->", "<!--splash:end-->", "<!--splash-markup:begin-->", "<!--splash-markup:end-->"]:
		assert_eq(s.count(m), 1, m)
	var loader := FileAccess.get_file_as_string(LOADER)
	for m: String in ["<!--SPLASH-STYLE-->", "<!--SPLASH-MARKUP-->", "__RUNNER_PAGE__", "__PACK_NAME__", "__PACK_SIZE__"]:
		assert_true(loader.contains(m), "the index page has %s" % m)
	assert_true(s.contains("window.MomoSplash.started()"), "the runner tells the splash when the engine has started")
	assert_true(s.contains("window.MomoSplash.fail("), "and when it failed")


func test_the_splash_fetches_nothing() -> void:
	var s := _shell()
	var a := s.find("/*momo:begin*/url(data:image/webp;base64,")
	var b := s.find(")/*momo:end*/")
	assert_true(a >= 0 and b > a, "the Momo is inline (tools/web/splash_art.gd)")
	assert_true(b - a < 16000, "and small (%d characters)" % (b - a))
	for word: String in ["http://", "https://", "@import", "fonts.googleapis"]:
		assert_false(s.contains(word), "no other host: %s" % word)
	for lang: String in ["en:", "ko:", "ja:", "zh:"]:
		assert_true(s.contains("\t\t" + lang), "words in %s" % lang)
	assert_true(s.contains("prefers-reduced-motion"), "reduced motion stills it")


## Step 74: the loading screen counts real bytes from the first download --
## the loader's progress hook is on the config before the engine exists (the
## runner's block, inserted before the engine line, comes after it) -- and
## times the start with the monotonic clock from the first page.
func test_the_percent_comes_from_the_loader_from_the_first_byte() -> void:
	var s := _shell()
	var hook := s.find("GODOT_CONFIG.onProgress = function")
	assert_true(hook > 0, "the loader's progress goes to the splash")
	assert_true(hook > s.find("const GODOT_THREADS_ENABLED") and hook < s.find("const engine = new Engine(GODOT_CONFIG);"), "set before the engine is made")
	assert_true(s.contains("Math.floor((own / size) * 100)"), "a share of this phase's own bytes")
	assert_false(s.contains("setInterval"), "nothing counts by the clock")
	assert_true(s.contains("Math.min(99,"), "never 100% while the game is still busy")
	assert_true(s.contains("performance.now()") and s.contains("performance.timeOrigin"), "timed with the monotonic clock")
	var loader := FileAccess.get_file_as_string(LOADER)
	assert_true(loader.contains("\"t0\"") and loader.contains("performance.timeOrigin"), "the index page passes when it started")


func test_the_words_are_there_in_every_language() -> void:
	var s := _shell()
	for code: String in ["en:", "ko:", "ja:", "zh:"]:
		assert_true(s.contains("\t\t" + code + " { line:"), "%s words" % code)
	assert_eq(s.count("loaded: '"), 4, "a 'loaded in' line in four languages")
	assert_eq(s.count("{s}"), 5, "each with the seconds (and the line that fills them in)")
	assert_eq(s.count("load: ['"), 4, "the per-phase percentages in four languages")


func test_the_bar_is_the_number_at_once() -> void:
	var s := _shell()
	var a := s.find("#momo-splash .bar i {")
	var b := s.find("}", a)
	assert_true(a > 0, "the bar's fill")
	assert_false(s.substr(a, b - a).contains("transition"), "no easing: never a bar that disagrees with its number")
