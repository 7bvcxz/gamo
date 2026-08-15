extends SceneTree

## The fog is baked into one radial texture instead of rasterising ~230 circles
## a frame. These pin the properties the bake has to preserve: a clear hole
## inside the warm radius, a monotonic ramp across the preview band, a border
## that matches the flat fill drawn beyond it, and a rebake that only fires when
## the radius has actually moved.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	var fog: ColdFog = main.cold_fog

	_assert(fog.has_bake(), "the fog bakes itself on the first frame")

	# --- The strength ramp is unchanged -----------------------------------------
	var warm: float = main.sim.warm_radius
	_assert(is_equal_approx(fog.fog_strength(warm), 0.0), "the warm edge is clear")
	_assert(is_equal_approx(fog.fog_strength(warm - 3.0), 0.0), "and so is everything inside it")
	_assert(is_equal_approx(fog.fog_strength(warm + ColdFog.PREVIEW_BAND), 1.0),
		"the preview band ends at full strength")
	_assert(fog.fog_strength(warm + ColdFog.PREVIEW_BAND * 0.5) > 0.4,
		"and is partway across at its midpoint")

	# --- The baked texture ------------------------------------------------------
	fog.rebake(warm)
	var image: Image = fog._texture.get_image()
	var size: int = image.get_width()
	var middle: float = float(size - 1) * 0.5
	_assert(size == ColdFog.TEX_SIZE, "the bake is the expected size")

	# A hole the player can see out of: everything inside the warm radius must be
	# fully transparent, or the fog would be covering the factory.
	var extent: float = fog.baked_extent_px() / float(Defs.TILE)
	var alpha_at := func(tiles: float) -> float:
		var d: float = clampf(tiles / extent, 0.0, 1.0) * middle
		return image.get_pixel(int(round(middle + d)), int(round(middle))).a
	_assert(alpha_at.call(0.0) <= 0.01, "the core is clear of fog")
	_assert(alpha_at.call(warm * 0.5) <= 0.01, "the middle of the warm pool is clear")
	_assert(alpha_at.call(warm - 3.0) <= 0.02, "and so is the ground well inside the edge")
	# The old field's puffs were 2.9 tiles wide and only skipped by their centre,
	# so they bled inward past the edge. That soft lip is part of the look.
	_assert(alpha_at.call(warm - 0.3) > 0.05, "the hole's edge is feathered, not cut")
	_assert(alpha_at.call(warm - 0.3) < alpha_at.call(warm + 1.0),
		"and it thickens outward across that lip")
	# There is no preview band any more. The nine tiles past the frontier used to
	# stay readable so the next ore field was visible and worth walking to; as of
	# 0.20.70 what is out there is found by carrying a light into it, and the fog
	# closes within a couple of tiles of the edge.
	_assert(alpha_at.call(warm + ColdFog.PREVIEW_BAND + 1.0) > 0.90,
		"the fog closes just past the edge (%.2f)"
			% alpha_at.call(warm + ColdFog.PREVIEW_BAND + 1.0))
	_assert(alpha_at.call(warm + 8.0) > 0.95,
		"and further out there is nothing to see at all (%.2f)" % alpha_at.call(warm + 8.0))

	# Past the rim it may only thicken, or the fog would read as concentric bands.
	var previous: float = -1.0
	for step in 30:
		var tiles: float = warm + 3.0 + (extent - warm - 3.0) * float(step) / 29.0
		var alpha: float = alpha_at.call(tiles)
		_assert(alpha >= previous - 0.02, "alpha does not fall going outward at %.1f tiles" % tiles)
		previous = alpha
	_assert(previous > 0.85, "the outermost sample is dense fog")

	# The quad's border has to match the flat fill drawn past it, or the seam
	# would show as a square outline around the core.
	var border: float = image.get_pixel(size - 1, int(round(middle))).a
	_assert(absf(border - fog.far_alpha()) < 0.03,
		"the texture border matches the far fill: %.3f vs %.3f" % [border, fog.far_alpha()])
	_assert(fog.far_alpha() > 0.85, "far fog is dense")

	# --- Rebaking ---------------------------------------------------------------
	# Rebaking is the one cost this design adds, so it must not fire on every
	# delivery. The radius has to actually travel first.
	var before: float = fog._baked_radius
	main.sim.warm_radius = before + ColdFog.REBAKE_STEP * 0.5
	fog._process(0.016)
	_assert(is_equal_approx(fog._baked_radius, before), "a small radius change does not rebake")
	main.sim.warm_radius = before + ColdFog.REBAKE_STEP * 1.5
	fog._process(0.016)
	_assert(not is_equal_approx(fog._baked_radius, before), "a real radius change does rebake")

	# Growing the radius must grow the hole, not just redraw the same picture.
	fog.rebake(8.0)
	var small_extent: float = fog.baked_extent_px()
	var small_hole: float = _hole_radius(fog._texture.get_image(), small_extent)
	fog.rebake(18.0)
	var big_hole: float = _hole_radius(fog._texture.get_image(), fog.baked_extent_px())
	_assert(big_hole > small_hole + 5.0 * float(Defs.TILE),
		"a larger warm radius clears a larger hole: %.0f -> %.0f px" % [small_hole, big_hole])
	_assert(fog.baked_extent_px() > small_extent,
		"and the baked square grows with it")

	# The hitch has to stay small enough not to be felt mid-run.
	var started: int = Time.get_ticks_usec()
	fog.rebake(14.0)
	var elapsed_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
	_assert(elapsed_ms < 45.0, "a rebake costs %.1f ms, under the 45 ms budget" % elapsed_ms)
	print("FOG_TEST: rebake took %.1f ms" % elapsed_ms)

	if failures == 0:
		print("FOG_TEST: PASS")
	quit(failures)

## Distance from the centre at which the fog first becomes visible, in world px.
func _hole_radius(image: Image, extent_px: float) -> float:
	var size: int = image.get_width()
	var middle: float = float(size - 1) * 0.5
	for step in int(middle):
		if image.get_pixel(int(middle) + step, int(middle)).a > 0.02:
			return float(step) / middle * extent_px
	return extent_px

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("FOG_TEST: FAIL - " + message)
		failures += 1
