extends SceneTree

## Step 46: turns a painted cloud band on flat magenta into the sky's cloud
## source: r = how sunlit (the shader blends the time of day's cloud shade to
## cloud colour by it), a = cover. Clouds are white to blue-grey and never
## magenta, so the unmix observed = a*cloud + (1-a)*magenta is exact enough
## without a flood fill.
##
##   godot --headless --path momonium --script res://tools/art/gen/key_clouds.gd -- \
##     --in /abs/clouds_out.png --out res://assets/src/png/textures/clouds.png


func _init() -> void:
	var args := {}
	var raw := OS.get_cmdline_user_args()
	for i in range(0, raw.size() - 1, 2):
		args[raw[i].trim_prefix("--")] = raw[i + 1]
	var img := Image.load_from_file(args["in"])
	img.convert(Image.FORMAT_RGBA8)
	var lo := 1.0
	var hi := 0.0
	var lum := PackedFloat32Array()
	lum.resize(img.get_width() * img.get_height())
	var alpha := PackedFloat32Array()
	alpha.resize(lum.size())
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var m := minf(c.r, c.b) - c.g
			var a := clampf(1.0 - m / 0.85, 0.0, 1.0)
			var i := y * img.get_width() + x
			alpha[i] = a
			if a < 0.03:
				continue
			var o := Color(clampf((c.r - (1.0 - a)) / a, 0, 1), clampf(c.g / a, 0, 1), clampf((c.b - (1.0 - a)) / a, 0, 1))
			lum[i] = o.r * 0.3 + o.g * 0.59 + o.b * 0.11
			if a > 0.9:
				lo = minf(lo, lum[i])
				hi = maxf(hi, lum[i])
	# Spread the cloud's own light over 0..1: the shader decides the colours.
	var out := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	for i in lum.size():
		var l := clampf((lum[i] - lo) / maxf(hi - lo, 0.01), 0.0, 1.0)
		out.set_pixel(i % img.get_width(), i / img.get_width(), Color(l, l, l, alpha[i]))
	var path := ProjectSettings.globalize_path(args["out"])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	out.save_png(path)
	print("key_clouds: %s %dx%d light %.2f..%.2f" % [args["out"], out.get_width(), out.get_height(), lo, hi])
	quit()
