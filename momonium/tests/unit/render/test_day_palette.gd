extends "res://tests/framework/test_case.gd"

## Step 56: the day is in the sea -- fresh blue by day, warm peach light at
## sunset, deep navy at night -- changing smoothly, with no sky left in it.

var pal: DayPalette


func before_each() -> void:
	pal = DayPalette.new(GameData.load_default())


func test_the_sea_carries_the_time_of_day() -> void:
	var noon := pal.at(0.3)
	var day: Color = (noon["sea"] as Array)[1]
	assert_true(day.b > day.r + 0.4 and day.g > 0.55, "midday water is fresh blue (%s)" % day.to_html(false))
	var sunset := pal.at(0.62)
	var far: Color = (sunset["sea"] as Array)[0]
	assert_true(far.r > far.b and far.r > 0.85, "sunset: the water reflects warm peach light (%s)" % far.to_html(false))
	var mid: Color = (sunset["sea"] as Array)[1]
	assert_true(mid.b > mid.g, "under it, lavender-blue water (%s)" % mid.to_html(false))
	var night := pal.at(0.86)
	# Far, open and deep water; the shallows by the shore stay a little lighter.
	for i in 3:
		var c: Color = (night["sea"] as Array)[i]
		assert_true(_luma(c) < 0.33 and c.b > c.r + 0.25, "night water is deep navy (%d: %s)" % [i, c.to_html(false)])
	assert_true(_luma((night["ambient"] as Color)) < _luma((noon["ambient"] as Color)), "and the world is lit less")


func test_no_sky_is_left_in_a_look() -> void:
	for p: float in [0.0, 0.3, 0.62, 0.86, 0.97]:
		var look := pal.at(p)
		for gone: String in ["sky", "cloud", "cloud_shade", "stars"]:
			assert_false(look.has(gone), "%.2f: no '%s'" % [p, gone])


func test_colours_change_smoothly_and_wrap() -> void:
	for idx in 4:
		var worst := 0.0
		for i in 2000:
			var a: Color = (pal.at(i / 2000.0)["sea"] as Array)[idx]
			var b: Color = (pal.at((i + 1) / 2000.0)["sea"] as Array)[idx]
			worst = maxf(worst, absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b))
		assert_true(worst < 0.05, "sea %d: no jump between neighbouring moments (worst step %.3f)" % [idx, worst])
		var end: Color = (pal.at(0.99999)["sea"] as Array)[idx]
		var start: Color = (pal.at(0.0)["sea"] as Array)[idx]
		assert_true(absf(end.r - start.r) + absf(end.g - start.g) + absf(end.b - start.b) < 0.01, "sea %d: the end of a day meets the start of the next" % idx)


func test_sun_by_day_moon_by_night() -> void:
	assert_true(pal.sun_elevation(0.3) > 0.9, "sun high around noon")
	assert_true(pal.sun_elevation(0.0) > 0.2, "already up at Day N, 00 s")
	assert_true(pal.sun_elevation(0.85) < 0.0, "sun down at night")
	assert_true(pal.moon_elevation(0.85) > 0.5, "moon up at night")
	assert_true(pal.moon_elevation(0.3) < 0.0, "moon down by day")
	assert_true(pal.sun_across(0.1) < pal.sun_across(0.5), "the sun crosses left to right")


func _luma(c: Color) -> float:
	return c.r * 0.3 + c.g * 0.59 + c.b * 0.11
