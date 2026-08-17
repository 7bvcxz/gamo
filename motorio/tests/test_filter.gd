extends SceneTree

## How the character art is sampled, which is not a preference.
##
## The project draws everything NEAREST, which is right for tiles laid out one
## texel per pixel and wrong for everything else. Grim is a 128 cell drawn at
## half scale; through the camera zoom and the canvas stretch that lands on 0.30
## to 1.07 screen pixels per source texel depending on the zoom -- never 1, and
## never the same twice, because the zoom is a slider.
##
## NEAREST at 0.6 keeps three source columns in five and throws the rest away,
## and *which* three it keeps moves with her sub-pixel position. Measured on the
## real sheet at the real ratio: sliding the phase through one pixel makes the
## silhouette 0.70 pixels wider and narrower with NEAREST and 0.18 with linear.
## On screen that is a character trembling sideways while she runs and a
## staircase crawling along her edge.
##
## None of that is visible to an assertion, so what is pinned here is the
## arithmetic that causes it and the settings that answer it.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_no_zoom_is_one_to_one()
	await _test_sprites_average()
	_test_sheets_carry_mipmaps()
	if failures == 0:
		print("FILTER: PASS")
	else:
		print("FILTER: FAIL (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

# --- There is no zoom at which the art lands on whole pixels -------------------

func _test_no_zoom_is_one_to_one() -> void:
	# The stretch is whatever window the player has; 960x540 into a 1280 window is
	# the common desktop case and is not a whole number either.
	var stretches: Array[float] = [1.0, 1280.0 / 960.0, 1920.0 / 960.0]
	var aligned := 0
	var total := 0
	for stretch: float in stretches:
		var steps := 21
		for index in steps:
			var game_scale: float = lerpf(Defs.GAME_SCALE_MIN, Defs.GAME_SCALE_MAX,
				float(index) / float(steps - 1))
			var ratio: float = PlayerActor.SPRITE_SCALE * game_scale * stretch
			total += 1
			if absf(ratio - roundf(ratio)) < 0.02:
				aligned += 1
	# Not "never": a 1920 window at game_scale 1.0 lands on exactly 1:1, and the
	# first version of this assertion claimed otherwise and failed. The point is
	# that it cannot be relied on -- the zoom is a slider and the window is the
	# player's, so almost every position the pair can take is a fraction.
	_assert(float(aligned) / float(total) < 0.1,
		"배율 조합의 %d/%d 만 픽셀에 맞아떨어진다 — 나머지는 전부 분수다" % [aligned, total])
	# And at the default it is a hard minification, which is the case NEAREST is
	# worst at: more source texels than destination pixels, so it is choosing
	# which ones to keep.
	var default_ratio: float = PlayerActor.SPRITE_SCALE * Defs.GAME_SCALE_DEFAULT_DESKTOP
	_assert(default_ratio < 0.75,
		"기본 배율에서는 축소다: 소스 1픽셀 = %.2f 화면픽셀" % default_ratio)

# --- So they average rather than choose ---------------------------------------

func _test_sprites_average() -> void:
	_assert(PlayerActor.SOFT_FILTER == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,
		"캐릭터는 평균을 내서 그린다")
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	_assert(main.player.character.texture_filter == PlayerActor.SOFT_FILTER,
		"Grim의 스프라이트에 실제로 걸려 있다")
	_assert(main.player.carry_layer.texture_filter == PlayerActor.SOFT_FILTER,
		"품에 안은 것에도 걸려 있다 — 안긴 고양이와 서 있는 고양이가 달라 보이면 안 된다")
	main.clear_save()
	main.free()

# --- And the mipmaps exist ----------------------------------------------------

func _test_sheets_carry_mipmaps() -> void:
	# LINEAR_WITH_MIPMAPS on a texture imported without them silently falls back
	# to plain linear, which is better than nothing and not what was asked for.
	var missing: Array[String] = []
	var checked := 0
	for name: String in DirAccess.get_files_at("res://assets/characters"):
		if not name.ends_with(".png"):
			continue
		checked += 1
		var config := ConfigFile.new()
		if config.load("res://assets/characters/%s.import" % name) != OK:
			missing.append(name)
			continue
		if not bool(config.get_value("params", "mipmaps/generate", false)):
			missing.append(name)
	_assert(checked > 0, "캐릭터 시트를 %d장 찾았다" % checked)
	_assert(missing.is_empty(), "전부 밉맵과 함께 임포트됐다: 빠진 것 %s" % str(missing))
