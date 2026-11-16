extends SceneTree

## Rasterizes SVG files with Godot's own SVG renderer (ThorVG, as tools/build_atlas.gd does) --
## there is no other SVG rasterizer on this machine. Step 15: the mood boards and mockups.
##   godot --headless --path popcorn-glory --script res://tools/render_svg.gd -- <in.svg> <out.png> [scale]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var fails := 0
	var i := 0
	while i + 1 < args.size():
		var src := args[i]
		var out := args[i + 1]
		var scale := 1.0
		i += 2
		if i < args.size() and args[i].is_valid_float():
			scale = float(args[i])
			i += 1
		var img := Image.new()
		var err := img.load_svg_from_string(FileAccess.get_file_as_string(src), scale)
		if err != OK or img.save_png(out) != OK:
			print("FAIL ", src)
			fails += 1
		else:
			print("ok ", out, " ", img.get_size())
	quit(fails)
