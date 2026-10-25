extends SceneTree

## Step 46: turns a generated image (the object redrawn on chroma green) into
## a transparent sprite source in the SVG frame it was rendered from.
##
## Background is what is reachable from the border through key-green pixels
## (a flood fill), plus any pixel too pure a green to be painted grass -- so a
## yellow-green lawn inside the object stays opaque however green it is. Pixels
## next to the background are unmixed from the key (observed = a*obj +
## (1-a)*green), which gives soft edges without a green fringe. The frame
## region is then cut out and resized to frame x `--px` (texels per frame
## unit, the sprite's atlas `scale`), so the manifest's pivots still land on
## the same places. The drawing is first fitted onto the input's footprint
## (width and bottom tip) since the model moves and resizes what it redraws.
##
##   godot --headless --path momonium --script res://tools/art/gen/key_output.gd -- \
##     --in /abs/farm_out.png --frame /abs/farm_in.png.frame.json --out res://assets/src/png/farm.png [--px <manifest scale>]


func _init() -> void:
	var args := _args()
	var img := Image.load_from_file(args["in"])
	img.convert(Image.FORMAT_RGBA8)
	var frame: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args["frame"]))
	key(img)
	# The model never puts the object exactly where it was asked to: fit the
	# drawing's width and bottom tip (the ground) onto the input's, in the
	# input canvas.
	var input := Image.load_from_file(args["frame"].trim_suffix(".frame.json"))
	input.convert(Image.FORMAT_RGBA8)
	var want := box(input, false)
	var got := box(img, true)
	var s := float(want.size.x) / float(got.size.x)
	var src := img.get_region(got.grow(6).intersection(Rect2i(Vector2i.ZERO, img.get_size())))
	var src_origin := got.grow(6).intersection(Rect2i(Vector2i.ZERO, img.get_size())).position
	src.resize(maxi(1, int(round(src.get_width() * s))), maxi(1, int(round(src.get_height() * s))), Image.INTERPOLATE_LANCZOS)
	var placed := Image.create(input.get_width(), input.get_height(), false, Image.FORMAT_RGBA8)
	var foot_got := Vector2(got.position.x + got.size.x / 2.0, got.end.y)
	var foot_want := Vector2(want.position.x + want.size.x / 2.0, want.end.y)
	var at := foot_want - (foot_got - Vector2(src_origin)) * s
	placed.blit_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), Vector2i(roundi(at.x), roundi(at.y)))
	print("key_output: fit x%.3f, input box %s, drawing box %s" % [s, want, got])
	var r := Rect2i(int(frame["x"]), int(frame["y"]),
		int(round(float(frame["frame_w"]) * float(frame["scale"]))), int(round(float(frame["frame_h"]) * float(frame["scale"]))))
	var cut := placed.get_region(r)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites.json"))
	var px := float(args.get("px", str(manifest["sprites"][frame["sprite"]].get("scale", 2.0))))
	cut.resize(int(round(float(frame["frame_w"]) * px)), int(round(float(frame["frame_h"]) * px)), Image.INTERPOLATE_LANCZOS)
	var out := String(args["out"])
	var path := ProjectSettings.globalize_path(out) if out.begins_with("res://") else out
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	cut.save_png(path)
	print("key_output: %s -> %s %dx%d" % [args["in"].get_file(), out, cut.get_width(), cut.get_height()])
	quit()


## The drawing's box, ignoring specks under 5 px (an input render may carry
## stray template pixels): a pixel counts when it and its neighbours two
## pixels away are all drawn. `alpha` reads transparency, else the key.
static func box(img: Image, alpha: bool) -> Rect2i:
	var w := img.get_width()
	var h := img.get_height()
	var lo := Vector2i(w, h)
	var hi := Vector2i(-1, -1)
	for y in range(2, h - 2):
		for x in range(2, w - 2):
			if not (_drawn(img, x, y, alpha) and _drawn(img, x - 2, y, alpha) and _drawn(img, x + 2, y, alpha) and _drawn(img, x, y - 2, alpha) and _drawn(img, x, y + 2, alpha)):
				continue
			lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
			hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	return Rect2i(lo - Vector2i(2, 2), hi - lo + Vector2i(5, 5))


static func _drawn(img: Image, x: int, y: int, alpha: bool) -> bool:
	var c := img.get_pixel(x, y)
	return c.a > 0.5 if alpha else not keyish(c)


static func spill(c: Color) -> float:
	return c.g - maxf(c.r, c.b)


## A pixel the background may pass through: clearly the key, not a lawn.
static func keyish(c: Color) -> bool:
	return spill(c) > 0.5 and c.r < 0.5 and c.b < 0.5


## Unmistakably the key wherever it is (holes inside a canopy).
static func pure_key(c: Color) -> bool:
	return spill(c) > 0.8 and c.r < 0.2 and c.b < 0.2


static func key(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var bg := PackedByteArray()
	bg.resize(w * h)
	var stack: Array[int] = []
	for x in w:
		stack.append(x)
		stack.append((h - 1) * w + x)
	for y in h:
		stack.append(y * w)
		stack.append(y * w + w - 1)
	while not stack.is_empty():
		var i: int = stack.pop_back()
		if bg[i] == 1:
			continue
		var c := img.get_pixel(i % w, i / w)
		if not keyish(c):
			continue
		bg[i] = 1
		var x := i % w
		var y := i / w
		if x > 0: stack.append(i - 1)
		if x < w - 1: stack.append(i + 1)
		if y > 0: stack.append(i - w)
		if y < h - 1: stack.append(i + w)
	for i in w * h:
		if bg[i] == 0 and pure_key(img.get_pixel(i % w, i / w)):
			bg[i] = 1
	for y in h:
		for x in w:
			var i := y * w + x
			if bg[i] == 1:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			if not _touches(bg, w, h, x, y, 2):
				continue
			# Edge: unmix the key. Assume the object itself has no green spill,
			# so the spill seen is the key showing through.
			var c := img.get_pixel(x, y)
			var a := clampf(1.0 - maxf(spill(c), 0.0) / 0.9, 0.0, 1.0)
			if a <= 0.02:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var o := Color(clampf(c.r / a, 0, 1), clampf((c.g - (1.0 - a)) / a, 0, 1), clampf(c.b / a, 0, 1), a)
			img.set_pixel(x, y, o)


static func _touches(bg: PackedByteArray, w: int, h: int, x: int, y: int, r: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var xx := x + dx
			var yy := y + dy
			if xx >= 0 and yy >= 0 and xx < w and yy < h and bg[yy * w + xx] == 1:
				return true
	return false


func _args() -> Dictionary:
	var raw := OS.get_cmdline_user_args()
	var out := {}
	var i := 0
	while i < raw.size():
		out[raw[i].trim_prefix("--")] = raw[i + 1] if i + 1 < raw.size() else ""
		i += 2
	return out
