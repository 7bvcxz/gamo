extends SceneTree

## Eight-direction facing is table-driven, so it can be proven without rendering.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# Screen space: +y is south. Index 0 is south and indices run clockwise.
	var cases := {
		Vector2(0, 1): Defs.DIR_S,
		Vector2(1, 1): Defs.DIR_SE,
		Vector2(1, 0): Defs.DIR_E,
		Vector2(1, -1): Defs.DIR_NE,
		Vector2(0, -1): Defs.DIR_N,
		Vector2(-1, -1): Defs.DIR_NW,
		Vector2(-1, 0): Defs.DIR_W,
		Vector2(-1, 1): Defs.DIR_SW,
	}
	for direction: Vector2 in cases:
		_assert(Defs.facing_index(direction) == int(cases[direction]),
			"%s maps to facing %d" % [direction, int(cases[direction])])

	_assert(Defs.facing_index(Vector2.ZERO) == Defs.DIR_S, "a still character faces the camera")
	# Slight wobble must not flicker between neighbours.
	_assert(Defs.facing_index(Vector2(1.0, 0.2)) == Defs.DIR_E, "a small wobble stays on the cardinal")

	# Every facing must resolve to one of the four drawn views, and the two
	# diagonals on each side must not render identically.
	var seen: Dictionary = {}
	for index in 8:
		var view: Dictionary = Defs.facing_view(index)
		_assert(["front", "back", "left", "right"].has(String(view["view"])),
			"facing %d uses a drawn view" % index)
		var key: String = "%s|%s|%.1f" % [view["view"], view["flip"], view["lean"]]
		_assert(not seen.has(key), "facing %d is visually distinct from facing %s" % [index, seen.get(key, -1)])
		seen[key] = index

	_assert(Defs.DIR_VECTORS.size() == 8, "there is a unit vector per facing")
	for index in 8:
		_assert(is_equal_approx((Defs.DIR_VECTORS[index] as Vector2).length(), 1.0),
			"facing vector %d is normalised" % index)
		_assert(Defs.facing_index(Defs.DIR_VECTORS[index]) == index,
			"facing vector %d round-trips back to its own index" % index)

	if failures == 0:
		print("FACING_TEST: PASS")
	quit(failures)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("FACING_TEST: FAIL - " + message)
		failures += 1
