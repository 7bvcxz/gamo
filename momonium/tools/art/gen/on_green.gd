extends SceneTree

## Step 66: a keyed source (transparent) placed on a square of pure chroma
## green -- the input an image model redraws from. A reference with any other
## background makes the model invent one, which the key cannot take out
## (AGENTS.md, 2026-08-06): every input is the same mode and the same green.
## The sprite is scaled to `--height` px and stands with its lowest pixel on
## `--bottom`, centred on `--x`; the rest of the canvas is headroom for what
## the pose raises.
##
##   godot --headless --path momonium --script res://tools/art/gen/on_green.gd -- \
##     --in res://assets/src/png/momo/front_idle.webp --out /abs/in.png [--size 1024] [--height 560] [--x 512] [--bottom 968]

const GREEN := Color(0, 1, 0)


func _init() -> void:
	var args := {"size": "1024", "height": "560", "x": "512", "bottom": "968"}
	var raw := OS.get_cmdline_user_args()
	for i in range(0, raw.size() - 1, 2):
		args[raw[i].trim_prefix("--")] = raw[i + 1]
	var src := Image.load_from_file(ProjectSettings.globalize_path(String(args["in"])))
	src.convert(Image.FORMAT_RGBA8)
	var h := int(args["height"])
	var w := maxi(1, roundi(src.get_width() * float(h) / src.get_height()))
	src.resize(w, h, Image.INTERPOLATE_LANCZOS)
	var size := int(args["size"])
	var out := Image.create(size, size, false, Image.FORMAT_RGBA8)
	out.fill(GREEN)
	out.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), Vector2i(int(args["x"]) - w / 2, int(args["bottom"]) - h))
	out.convert(Image.FORMAT_RGB8)
	out.save_png(String(args["out"]))
	print("on_green: %s %dx%d at (%d, %d)" % [args["out"], w, h, int(args["x"]) - w / 2, int(args["bottom"]) - h])
	quit()
