extends "res://tests/framework/test_case.gd"

## How a run is asked to start: the address on the web, user arguments natively.


func test_query_parses_flags_and_values() -> void:
	var q := RunConfig.parse_query("?fresh=1&seed=7&variant=B&dev")
	assert_eq(q["fresh"], "1", "fresh")
	assert_eq(q["seed"], "7", "seed")
	assert_eq(q["dev"], "true", "bare flag")
	var c := RunConfig.from_pairs(q)
	assert_true(c.fresh, "fresh flag")
	assert_true(c.dev, "dev flag")
	assert_eq(c.seed, 7, "seed value")
	assert_eq(c.variant, "b", "variant lowercased")


func test_args_parse_like_the_query() -> void:
	var a := RunConfig.parse_args(PackedStringArray(["--fresh", "--seed", "3", "--variant", "c", "--smoke"]))
	var c := RunConfig.from_pairs(a)
	assert_true(c.fresh and c.smoke, "flags")
	assert_eq(c.seed, 3, "seed")
	assert_eq(c.variant, "c", "variant")


func test_defaults_and_unknown_values_are_safe() -> void:
	var c := RunConfig.from_pairs(RunConfig.parse_query(""))
	assert_eq(c.seed, RunConfig.DEFAULT_SEED, "default seed")
	assert_eq(c.variant, "base", "default variant")
	assert_false(c.fresh or c.dev or c.smoke, "flags off")
	var bad := RunConfig.from_pairs({"seed": "abc", "variant": "zzz", "fresh": "0"})
	assert_eq(bad.seed, RunConfig.DEFAULT_SEED, "non-numeric seed ignored")
	assert_eq(bad.variant, "base", "unknown variant falls back")
	assert_false(bad.fresh, "0 is false")
