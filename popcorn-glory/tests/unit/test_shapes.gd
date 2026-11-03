extends "res://tests/framework/test_case.gd"

## Every rounded rectangle the game can ask for is a polygon the renderer can
## triangulate -- the upgrade button's fill is a few pixels high at the start
## of a run, and that sliver failed in the browser (Step 03).


func test_rounded_outlines_have_no_repeated_points() -> void:
	for h: float in [6.0, 6.5, 8.0, 13.0, 40.0, 150.0]:
		for rad: float in [1.0, 3.0, 20.0, 36.0, 200.0]:
			var pts := PopMachineArt.round_rect_points(Rect2(0, 0, 500, h), rad)
			assert_true(pts.size() >= 4, "%s x %s: %d points" % [h, rad, pts.size()])
			var ok := true
			for i in pts.size():
				if pts[i].distance_squared_to(pts[(i + 1) % pts.size()]) <= 0.01:
					ok = false
			assert_true(ok, "h %s rad %s: no repeated neighbours" % [h, rad])
			assert_false(Geometry2D.triangulate_polygon(pts).is_empty(), "h %s rad %s triangulates" % [h, rad])
