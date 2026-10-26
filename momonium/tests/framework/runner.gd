extends SceneTree

## Runs Momonium's GDScript tests in one Godot process.
##
##   godot --headless --path momonium --script res://tests/framework/runner.gd -- \
##     [--suite unit|integration|e2e|all] [--filter text]
##
## Prefer tools/test.sh, which also fails the run on anything the engine prints
## after the runner has finished (leaked objects at exit).
##
## Exit code is the number of failed cases (capped at 255). Errors the engine
## logs while a case runs are captured through a Logger and fail that case: a
## GDScript runtime error ends only the current function, and a suite that
## counts assertions alone reads a crashed case as a pass.

const SUITES := ["unit", "integration"]


class CaptureLogger extends Logger:
	var errors: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		var text := rationale if rationale != "" else code
		errors.append("%s (%s:%d in %s)" % [text, file.get_file(), line, function])

	func _log_message(_message: String, _error: bool) -> void:
		pass


var _logger := CaptureLogger.new()


func _init() -> void:
	# Main must not load or overwrite a real save while tests run: a stale
	# save from one test would be the next test's starting world.
	Engine.set_meta("momonium_no_save", true)
	OS.add_logger(_logger)
	_run.call_deferred()


func _run() -> void:
	var args := _parse_args()
	var suites: Array = SUITES if args.get("suite", "all") == "all" else [args["suite"]]
	var filter: String = args.get("filter", "")
	var files: Array[String] = []
	for suite: String in suites:
		_collect("res://tests/%s" % suite, files)
	files.sort()

	var passed := 0
	var failed: Array[String] = []
	var checks := 0
	var started := Time.get_ticks_msec()
	for path: String in files:
		_logger.errors.clear()
		var script: Script = load(path)
		if script == null or not script.can_instantiate():
			failed.append("%s: does not load %s" % [path, _logger.errors])
			print("FAIL %s (load) %s" % [path, _logger.errors])
			continue
		for method: Dictionary in script.get_script_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			var id := "%s::%s" % [path.trim_prefix("res://tests/"), name]
			if filter != "" and not id.contains(filter):
				continue
			var case: RefCounted = script.new()
			case.set("tree", self)
			_logger.errors.clear()
			await case.call("before_each")
			await case.call(name)
			await case.call("after_each")
			checks += int(case.get("checks"))
			var problems: Array = case.get("failures").duplicate()
			for error: String in _logger.errors:
				problems.append("engine error: " + error)
			if problems.is_empty():
				passed += 1
				print("ok   %s" % id)
			else:
				failed.append(id)
				print("FAIL %s" % id)
				for problem: String in problems:
					print("       %s" % problem)
	var elapsed := (Time.get_ticks_msec() - started) / 1000.0
	print("")
	print("%d passed, %d failed, %d checks, %d files, %.1fs" % [passed, failed.size(), checks, files.size(), elapsed])
	if passed == 0 and failed.is_empty():
		print("FAIL no tests ran")
		quit(1)
		return
	# A freed player's sound is let go on the audio thread's next mix: quitting
	# in the same frame reported the music and the last sounds as leaked, now
	# and then, by timing alone (Step 50).
	for i in 3:
		await process_frame
	await create_timer(0.25).timeout
	OS.remove_logger(_logger)
	quit(mini(failed.size(), 255))


func _collect(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_collect(dir_path.path_join(sub), out)
	for file: String in dir.get_files():
		if file.begins_with("test_") and file.ends_with(".gd"):
			out.append(dir_path.path_join(file))


func _parse_args() -> Dictionary:
	var out := {}
	var raw := OS.get_cmdline_user_args()
	var i := 0
	while i < raw.size():
		if raw[i].begins_with("--"):
			var value: String = raw[i + 1] if i + 1 < raw.size() and not raw[i + 1].begins_with("--") else "true"
			out[raw[i].trim_prefix("--")] = value
			i += 2 if value != "true" else 1
		else:
			i += 1
	return out
