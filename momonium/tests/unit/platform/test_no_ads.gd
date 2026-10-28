extends "res://tests/framework/test_case.gd"

## Step 75: Remove Ads is a catalog entry, and the game shows no ads -- no
## ad SDK or network in the code, the web pages or the Android export, no
## advertising ID permission, no plugin. The words below never appear outside
## the shop's own honest lines ("no ads").

const AD_WORDS: Array[String] = ["admob", "googlesyndication", "doubleclick", "adsbygoogle", "googleadservices", "unityads", "applovin",
	"ironsource", "adcolony", "chartboost", "vungle", "rewarded", "interstitial", "advertising_id", "ad_id", "adservices", "gma_sdk"]


func _files(dir: String, exts: Array[String], out: Array[String]) -> void:
	for f: String in DirAccess.get_files_at(dir):
		if exts.has(f.get_extension()):
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		if not d.begins_with("."):
			_files(dir.path_join(d), exts, out)


func test_no_ad_network_in_the_code_or_the_pages() -> void:
	var files: Array[String] = []
	_files("res://src", ["gd"] as Array[String], files)
	_files("res://web", ["html", "js"] as Array[String], files)
	files.append("res://project.godot")
	files.append("res://export_presets.cfg")
	assert_true(files.size() > 50, "the code, the pages and the presets (%d files)" % files.size())
	for path: String in files:
		var text := FileAccess.get_file_as_string(path).to_lower()
		for w: String in AD_WORDS:
			assert_false(text.contains(w), "%s mentions %s" % [path, w])


func test_the_android_export_asks_for_no_ad_id_and_loads_no_plugin() -> void:
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://export_presets.cfg"), OK, "the presets")
	var android := ""
	for section: String in cfg.get_sections():
		if section.ends_with(".options") or not cfg.has_section_key(section, "platform"):
			continue
		if String(cfg.get_value(section, "platform")) == "Android":
			android = section
	assert_ne(android, "", "an Android preset")
	var options := android + ".options"
	assert_eq(Array(cfg.get_value(options, "permissions/custom_permissions", PackedStringArray())), [], "no extra permissions")
	for key: String in cfg.get_section_keys(options):
		if key.begins_with("permissions/") and key != "permissions/custom_permissions":
			assert_false(bool(cfg.get_value(options, key)), "%s is off" % key)
		if key.begins_with("plugins/"):
			assert_false(bool(cfg.get_value(options, key)), "%s is off" % key)
	assert_false(DirAccess.dir_exists_absolute("res://android/plugins"), "no Android plugins folder")
	assert_false(DirAccess.dir_exists_absolute("res://addons"), "no editor add-ons (an ad SDK arrives as one)")
