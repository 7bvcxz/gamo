extends RefCounted

## Base for every Momonium test file. A test file extends this script by path
## (no class_name -- tests are excluded from the export, and a global class
## whose file is missing from the pack is an error waiting to happen).
##
## Each `func test_*()` is one case. It may `await`. A case fails when any
## assertion fails or when the engine logs a script error while it runs -- a
## GDScript runtime error only ends the function it happened in, so without the
## second rule a crashed case would read as a passing one.

var failures: Array[String] = []
var checks: int = 0
## The SceneTree the runner is using; integration tests add scenes to its root.
var tree: SceneTree


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func fail(message: String) -> void:
	failures.append(message + _where())


func assert_true(value: bool, message: String = "expected true") -> void:
	checks += 1
	if not value:
		fail(message)


func assert_false(value: bool, message: String = "expected false") -> void:
	checks += 1
	if value:
		fail(message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	checks += 1
	if typeof(actual) != typeof(expected) and not (_is_number(actual) and _is_number(expected)):
		fail("%s: expected %s (%s) but got %s (%s)" % [message, var_to_str(expected), type_string(typeof(expected)), var_to_str(actual), type_string(typeof(actual))])
	elif actual != expected:
		fail("%s: expected %s but got %s" % [message, var_to_str(expected), var_to_str(actual)])


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	checks += 1
	if actual == unexpected:
		fail("%s: did not expect %s" % [message, var_to_str(actual)])


func assert_near(actual: float, expected: float, tolerance: float, message: String = "") -> void:
	checks += 1
	if absf(actual - expected) > tolerance:
		fail("%s: expected %f +- %f but got %f" % [message, expected, tolerance, actual])


func assert_between(actual: float, low: float, high: float, message: String = "") -> void:
	checks += 1
	if actual < low or actual > high:
		fail("%s: expected %f in [%f, %f]" % [message, actual, low, high])


func assert_has(container: Variant, item: Variant, message: String = "") -> void:
	checks += 1
	if not container.has(item):
		fail("%s: %s not found" % [message, var_to_str(item)])


func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


func _where() -> String:
	# The first frame outside this file is the assertion's caller.
	for frame: Dictionary in get_stack():
		var source: String = frame.get("source", "")
		if not source.ends_with("test_case.gd"):
			return "  (%s:%d)" % [source.get_file(), frame.get("line", 0)]
	return ""
