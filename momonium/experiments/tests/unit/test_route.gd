extends "res://tests/framework/test_case.gd"

## The address decides the screen: nothing is the launcher, `#<id>` one
## experiment's direct link (what a reload keeps), the query adds dev mode,
## reduced motion and muted sound; the command line says the same off the web.


func test_the_bare_address_is_the_launcher() -> void:
	var r := LabRoute.parse("", "")
	assert_eq(r["exp"], "", "launcher")
	assert_false(bool(r["dev"]), "not dev")
	assert_true(bool(r["sound"]), "sound on")


func test_a_hash_is_a_direct_link() -> void:
	for id: String in LabRegistry.ids():
		assert_eq(LabRoute.parse("#" + id, "")["exp"], id, "#" + id)
	assert_eq(LabRoute.parse("#/Island", "")["exp"], "island", "a slash and capitals are forgiven")
	assert_eq(LabRoute.parse("", "?exp=rock")["exp"], "rock", "?exp= works too")
	assert_eq(LabRoute.parse("#tree", "?exp=rock")["exp"], "tree", "the hash wins")


func test_an_unknown_link_falls_back_to_the_launcher() -> void:
	var r := LabRoute.parse("#momonium", "")
	assert_eq(r["exp"], "", "launcher")
	assert_eq(r["unknown"], "momonium", "remembers what was asked")


func test_query_options() -> void:
	var r := LabRoute.parse("#island", "?dev=1&motion=reduce&sound=off")
	assert_true(bool(r["dev"]), "dev")
	assert_eq(r["motion"], "reduce", "reduced motion")
	assert_false(bool(r["sound"]), "muted")
	assert_false(bool(LabRoute.parse("", "?dev=0")["dev"]), "dev=0 is off")
	assert_true(bool(LabRoute.parse("", "?dev")["dev"]), "a bare ?dev is on")


func test_command_line() -> void:
	var r := LabRoute.parse("", "", PackedStringArray(["--out", "/tmp/x.png", "--exp", "rock", "--dev", "--motion", "reduce", "--mute"]))
	assert_eq(r["exp"], "rock", "--exp")
	assert_true(bool(r["dev"]), "--dev")
	assert_eq(r["motion"], "reduce", "--motion")
	assert_false(bool(r["sound"]), "--mute")
