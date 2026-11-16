extends "res://tests/framework/test_case.gd"

## Step 15: the factory's design tokens (art/tokens.gd) are one consistent layout.

func test_the_bands_stack_without_gaps_or_overlaps() -> void:
	var bands: Array[Vector2] = [Vector2(0.0, PopTokens.BAR_H), PopTokens.TOP_FLOOR, PopTokens.MID_FLOOR, PopTokens.LOW_FLOOR, PopTokens.CARD]
	for i in bands.size():
		assert_true(bands[i].y > bands[i].x, "band %d has height" % i)
		if i > 0:
			assert_near(bands[i].x, bands[i - 1].y, 0.0001, "band %d starts where %d ends" % [i, i - 1])
	assert_near(bands[-1].y, 1.0, 0.0001, "the card ends at the bottom")
	assert_true(PopTokens.LOW_FLOOR.y - PopTokens.LOW_FLOOR.x >= 0.3, "the kitchen (the hand's floor) is the tallest")


func test_type_and_lines_keep_their_order() -> void:
	for fs: int in [PopTokens.TEXT_MONEY, PopTokens.TEXT_PRICE, PopTokens.TEXT_DELTA]:
		assert_true(fs >= PopTokens.TEXT_MIN, "no number under the minimum")
	assert_true(PopTokens.LINE_HERO > PopTokens.LINE_MACHINE and PopTokens.LINE_MACHINE > PopTokens.LINE_PART, "the hand's machine is the boldest")
	assert_true(PopTokens.R_FLOOR > PopTokens.R_MACHINE and PopTokens.R_MACHINE > PopTokens.R_PART, "bigger things are rounder")
	for k: String in ["run", "starved", "blocked", "unpaid", "off"]:
		assert_true(PopTokens.STATE_SHAPES.has(k), "state %s has a shape, not only a colour" % k)


func test_floor_rects_fit_the_canvas() -> void:
	var s := Vector2(720, 1280)
	var prev_end := 0.0
	for b: Vector2 in [PopTokens.TOP_FLOOR, PopTokens.MID_FLOOR, PopTokens.LOW_FLOOR]:
		var r := PopTokens.floor_rect(b, s)
		assert_true(r.position.x >= 0.0 and r.end.x <= s.x, "inside the width")
		assert_true(r.position.y >= prev_end, "below the floor above")
		prev_end = r.end.y
