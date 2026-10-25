extends "res://tests/framework/test_case.gd"

var proj: IsoProjection


func before_each() -> void:
	proj = IsoProjection.from_data(GameData.load_default())


func test_view_angle_is_within_spec() -> void:
	assert_between(proj.elevation_deg, 50.0, 60.0, "elevated 50-60 degree view")
	assert_eq(int(proj.tile_height) % 2, 0, "tile height is even, corners land on whole pixels")
	assert_near(proj.tile_height / proj.tile_width, sin(deg_to_rad(proj.elevation_deg)), 0.01, "diamond ratio is sin(elevation)")
	assert_near(proj.height_scale, proj.tile_width / sqrt(2.0) * cos(deg_to_rad(proj.elevation_deg)), 0.001, "vertical foreshortening is cos(elevation)")


func test_screen_and_logical_round_trip() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for i in 200:
		var p := Vector2(rng.randf_range(-500, 500), rng.randf_range(-500, 500))
		var back := proj.to_logical(proj.to_screen(p))
		assert_true(back.distance_to(p) < 0.0001, "round trip %s" % p)


func test_cell_under_its_own_centre() -> void:
	for cell: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-3, 7), Vector2i(40, -12)]:
		assert_eq(proj.cell_at(proj.cell_center(cell)), cell, "cell_at(centre of %s)" % cell)
		var corners := proj.cell_corners(cell)
		# Just inside each corner, towards the centre, is still this cell.
		for c: Vector2 in corners:
			assert_eq(proj.cell_at(c.lerp(proj.cell_center(cell), 0.05)), cell, "near corner of %s" % cell)


func test_neighbours_share_exact_corners() -> void:
	# Seamless adjoining tiles: the shared edge is the same two points, bit for bit.
	var a := proj.cell_corners(Vector2i(2, 3))
	var east := proj.cell_corners(Vector2i(3, 3))
	var south := proj.cell_corners(Vector2i(2, 4))
	assert_eq(a[1], east[0], "east neighbour: my east corner is its north corner")
	assert_eq(a[2], east[3], "east neighbour: my south corner is its west corner")
	assert_eq(a[3], south[0], "south neighbour: my west corner is its north corner")
	assert_eq(a[2], south[1], "south neighbour: my south corner is its east corner")


func test_depth_matches_screen_order() -> void:
	# Nearer cells (larger depth) are lower on screen, so y-sorting by the
	# standing point and sorting by depth agree.
	for a: Vector2i in [Vector2i(0, 0), Vector2i(3, 1), Vector2i(-2, 5)]:
		for b: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(4, 4)]:
			var cell_b := a + b
			assert_true(IsoProjection.depth(cell_b) > IsoProjection.depth(a), "depth grows")
			assert_true(proj.cell_center(cell_b).y > proj.cell_center(a).y, "and so does screen y")
