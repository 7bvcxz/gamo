extends "res://tests/framework/test_case.gd"

## The address decides the screen: `#stub`, `?dev=1`, `?sound=off`, and the
## command line off the web.


func test_hash_and_query() -> void:
	var r := PopRoute.parse("#stub", "?dev=1&sound=off&motion=reduce", PackedStringArray())
	assert_eq(String(r["exp"]), "stub", "exp")
	assert_true(bool(r["dev"]), "dev")
	assert_false(bool(r["sound"]), "sound off")
	assert_eq(String(r["motion"]), "reduce", "motion")


func test_empty_address_is_the_chooser() -> void:
	var r := PopRoute.parse("", "", PackedStringArray())
	assert_eq(String(r["exp"]), "", "no exp")
	assert_false(bool(r["dev"]), "no dev")
	assert_true(bool(r["sound"]), "sound on")


func test_command_line() -> void:
	var r := PopRoute.parse("", "", PackedStringArray(["--suite", "all", "--exp", "stub", "--dev"]))
	assert_eq(String(r["exp"]), "stub", "exp from args")
	assert_true(bool(r["dev"]), "dev from args")
