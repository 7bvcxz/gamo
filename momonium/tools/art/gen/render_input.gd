extends SceneTree

## Step 46: renders a sprite's whole SVG frame (its viewBox, not the trimmed
## region) centred on a square chroma-green canvas -- the input an image model
## redraws in the concept style. The frame's place on the canvas is written
## beside it (<out>.frame.json) so key_output.gd can map the result back into
## the same frame, keeping every pivot valid.
##
##   godot --headless --path momonium --script res://tools/art/gen/render_input.gd -- \
##     --sprite farm --out /abs/farm_in.png [--size 1024] [--fill 0.82] [--headroom <frame units>]

const GREEN := Color(0, 1, 0)


func _init() -> void:
	var args := _args()
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites.json"))
	var spec: Dictionary = manifest["sprites"][args["sprite"]]
	var size := int(args.get("size", "1024"))
	var fill := float(args.get("fill", "0.82"))
	# Step 52: `--headroom` frame units of empty space above the frame, for a
	# redraw taller than the old drawing (the pivots move down by as much).
	var head := float(args.get("headroom", "0"))
	var img := Image.new()
	var box: Rect2
	var s: float
	if String(spec["source"]).ends_with(".png"):
		# A painted source (Step 46) is the frame at the sprite's `scale`.
		img = Image.load_from_file(ProjectSettings.globalize_path("res://assets/src/" + spec["source"]))
		var k := float(spec.get("scale", 1.0))
		box = Rect2(0, 0, img.get_width() / k, img.get_height() / k)
		s = size * fill / maxf(box.size.x, box.size.y + head)
		img.resize(maxi(1, roundi(box.size.x * s)), maxi(1, roundi(box.size.y * s)), Image.INTERPOLATE_LANCZOS)
	else:
		var svg := FileAccess.get_file_as_string("res://assets/src/" + spec["source"])
		box = _viewbox(svg)
		s = size * fill / maxf(box.size.x, box.size.y + head)
		img.load_svg_from_string(svg, s)
	img.convert(Image.FORMAT_RGBA8)
	var canvas := Image.create(size, size, false, Image.FORMAT_RGBA8)
	canvas.fill(GREEN)
	var full_h := (box.size.y + head) * s
	var top := int((size - full_h) / 2.0)
	var at := Vector2i(int((size - img.get_width()) / 2.0), top + roundi(head * s))
	canvas.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at)
	canvas.save_png(args["out"])
	var frame := {"sprite": args["sprite"], "canvas": size, "x": at.x, "y": top, "scale": s,
		"frame_w": box.size.x, "frame_h": box.size.y + head, "headroom": head}
	var f := FileAccess.open(args["out"] + ".frame.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(frame))
	print("render_input: %s %s scale %.3f at %s" % [args["sprite"], args["out"], s, at])
	quit()


static func _viewbox(svg: String) -> Rect2:
	var m := RegEx.create_from_string("viewBox=\"([\\d.\\-]+)[ ,]+([\\d.\\-]+)[ ,]+([\\d.]+)[ ,]+([\\d.]+)\"").search(svg)
	if m != null:
		return Rect2(float(m.get_string(1)), float(m.get_string(2)), float(m.get_string(3)), float(m.get_string(4)))
	var w := RegEx.create_from_string("width=\"([\\d.]+)").search(svg)
	var h := RegEx.create_from_string("height=\"([\\d.]+)").search(svg)
	return Rect2(0, 0, float(w.get_string(1)), float(h.get_string(1)))


func _args() -> Dictionary:
	var raw := OS.get_cmdline_user_args()
	var out := {}
	var i := 0
	while i < raw.size():
		out[raw[i].trim_prefix("--")] = raw[i + 1] if i + 1 < raw.size() else ""
		i += 2
	return out
