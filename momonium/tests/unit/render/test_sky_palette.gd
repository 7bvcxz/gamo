extends "res://tests/framework/test_case.gd"

var pal: SkyPalette


func before_each() -> void:
	pal = SkyPalette.new(GameData.load_default())


func test_looks_match_their_keyframes() -> void:
	var noon := pal.at(0.3)
	assert_eq((noon["sky"] as Array)[0], Color("#2693f8"), "midday sky is the day look")
	assert_eq(noon["stars"], 0.0, "no stars by day")
	var night := pal.at(0.86)
	assert_eq(night["stars"], 1.0, "stars at night")
	assert_true(_luma((night["sky"] as Array)[0]) < 0.15, "night sky is dark")
	var sunset := pal.at(0.62)
	var h: Color = (sunset["sky"] as Array)[2]
	assert_true(h.r > h.b, "sunset horizon is warm")


func test_colours_change_smoothly_and_wrap() -> void:
	var worst := 0.0
	for i in 2000:
		var a: Color = (pal.at(i / 2000.0)["sky"] as Array)[0]
		var b: Color = (pal.at((i + 1) / 2000.0)["sky"] as Array)[0]
		worst = maxf(worst, absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b))
	assert_true(worst < 0.05, "no jump between neighbouring moments (worst step %.3f)" % worst)
	var end: Color = (pal.at(0.99999)["sky"] as Array)[0]
	var start: Color = (pal.at(0.0)["sky"] as Array)[0]
	assert_true(absf(end.r - start.r) + absf(end.g - start.g) + absf(end.b - start.b) < 0.01, "the end of a day meets the start of the next")


func test_sun_by_day_moon_by_night() -> void:
	assert_true(pal.sun_elevation(0.3) > 0.9, "sun high around noon")
	assert_true(pal.sun_elevation(0.0) > 0.2, "already up at Day N, 00 s")
	assert_true(pal.sun_elevation(0.85) < 0.0, "sun down at night")
	assert_true(pal.moon_elevation(0.85) > 0.5, "moon up at night")
	assert_true(pal.moon_elevation(0.3) < 0.0, "moon down by day")
	assert_true(pal.sun_across(0.1) < pal.sun_across(0.5), "the sun crosses left to right")


func _luma(c: Color) -> float:
	return c.r * 0.3 + c.g * 0.59 + c.b * 0.11
