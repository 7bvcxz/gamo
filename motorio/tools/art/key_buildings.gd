extends SceneTree

## Keys the generated building candidates and fits each to its footprint
## (World Visual Pass 01).
##
##     godot --headless --path motorio --script res://tools/art/key_buildings.gd -- [names...]
##
## Reads tools/art/raw/<name>.png (gen_buildings.py), writes the table's `out`.
## The half of gen_objects.py + build_objects.py that needed Pillow, in Godot's
## Image API, because the art is what the game ships and the tool that makes it
## should run on any machine that runs the game.
##
## The steps, each for a reason this repository has already paid for:
## * Key on "how much greener than it is anything else", not a colour distance:
##   the generated green is near (2, 250, 3) but never exactly (0, 255, 0).
## * Despill the edge: a keyed edge keeps a green fringe that the snow shows up.
## * Drop specks: generated backgrounds carry islands of colour a few pixels
##   across, and a picture fitted to its bounding box is fitted to them too.
## * Fit the body, not the canvas, into the square the building covers, with a
##   hair of margin: `test_building_visual_inside_footprint` measures the opaque
##   pixels against the footprint the game draws it on.
## * Bleed colour into the clear pixels before the resize (`fix_alpha_edges`),
##   so the downscale does not average the edge with whatever green was there.

const RAW := "res://tools/art/raw/"
## name -> [output, stored size in pixels, margin as a fraction of the size]
const TABLE := {
	"base": ["res://assets/objects/core.png", 256, 0.015],
	"shelter": ["res://assets/objects/shelter.png", 128, 0.02],
	"miner": ["res://assets/objects/miner.png", 96, 0.02],
	"miner_mk2": ["res://assets/objects/miner_mk2.png", 96, 0.02],
	"generator": ["res://assets/objects/generator.png", 96, 0.03],
	"manufacturer": ["res://assets/objects/manufacturer.png", 96, 0.03],
	"assembler": ["res://assets/objects/assembler.png", 96, 0.03],
	"food_bin": ["res://assets/objects/food_bin.png", 96, 0.04],
}

func _initialize() -> void:
	var names: Array = OS.get_cmdline_user_args()
	if names.is_empty():
		names = TABLE.keys()
	var failures := 0
	for name: String in names:
		if not TABLE.has(name):
			print("KEY: unknown %s" % name)
			failures += 1
			continue
		var path: String = ProjectSettings.globalize_path(RAW + name + ".png")
		var image := Image.load_from_file(path)
		if image == null:
			print("KEY: missing %s" % path)
			failures += 1
			continue
		image.convert(Image.FORMAT_RGBA8)
		_key(image)
		_despeckle(image)
		var used: Rect2i = _opaque_rect(image, 0.5)
		var row: Array = TABLE[name]
		var out: Image = _fit(image, used, int(row[1]), float(row[2]))
		# KEY_OUT, when set, is a folder to write into instead of the game's
		# assets -- for looking before adopting.
		var target: String = ProjectSettings.globalize_path(String(row[0]))
		if OS.get_environment("KEY_OUT") != "":
			target = OS.get_environment("KEY_OUT").path_join(String(row[0]).get_file())
		var error: int = out.save_png(target)
		print("KEY: %s -> %s %dpx (body %s) %d" % [name, row[0], int(row[1]), used.size, error])
		failures += 1 if error != OK else 0
	quit(failures)

static func _key(image: Image) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var c: Color = image.get_pixel(x, y)
			var green: float = c.g - maxf(c.r, c.b)
			var alpha: float = 1.0
			if green > 0.28:
				alpha = 0.0
			elif green > 0.08:
				alpha = 1.0 - (green - 0.08) / 0.20
			if alpha < 1.0 or green > 0.02:
				# Despill: no pixel on the edge is greener than it is red or blue.
				c.g = minf(c.g, maxf(c.r, c.b) * 1.02)
			c.a = alpha
			image.set_pixel(x, y, c)

## Keeps connected islands of at least 3% of the largest one's area.
static func _despeckle(image: Image) -> void:
	var w: int = image.get_width()
	var h: int = image.get_height()
	var label := PackedInt32Array()
	label.resize(w * h)
	label.fill(-1)
	var sizes: Array[int] = []
	for start in w * h:
		if label[start] != -1 or image.get_pixel(start % w, start / w).a < 0.5:
			continue
		var id: int = sizes.size()
		var count := 0
		var stack: Array[int] = [start]
		label[start] = id
		while not stack.is_empty():
			var at: int = stack.pop_back()
			count += 1
			var ax: int = at % w
			var ay: int = at / w
			for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = ax + step.x
				var ny: int = ay + step.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var next: int = ny * w + nx
				if label[next] == -1 and image.get_pixel(nx, ny).a >= 0.5:
					label[next] = id
					stack.append(next)
		sizes.append(count)
	var largest := 0
	for count: int in sizes:
		largest = maxi(largest, count)
	for index in w * h:
		var id: int = label[index]
		var keep: bool = id >= 0 and sizes[id] >= largest * 0.03
		if id >= 0 and not keep:
			var c: Color = image.get_pixel(index % w, index / w)
			c.a = 0.0
			image.set_pixel(index % w, index / w, c)
	# Faint pixels not touching a kept island (the keyed halo of a dropped speck).
	for y in h:
		for x in w:
			var c: Color = image.get_pixel(x, y)
			if c.a > 0.0 and c.a < 0.5:
				var near := false
				for dy in range(-2, 3):
					for dx in range(-2, 3):
						var nx: int = x + dx
						var ny: int = y + dy
						if nx >= 0 and ny >= 0 and nx < w and ny < h and label[ny * w + nx] >= 0 \
								and sizes[label[ny * w + nx]] >= largest * 0.03:
							near = true
				if not near:
					c.a = 0.0
					image.set_pixel(x, y, c)

static func _opaque_rect(image: Image, threshold: float) -> Rect2i:
	var low := Vector2i(image.get_width(), image.get_height())
	var high := Vector2i(-1, -1)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a >= threshold:
				low = Vector2i(mini(low.x, x), mini(low.y, y))
				high = Vector2i(maxi(high.x, x), maxi(high.y, y))
	if high.x < 0:
		return Rect2i()
	return Rect2i(low, high - low + Vector2i.ONE)

## The body, scaled so its larger side spans the square less the margins and
## centred in it.
static func _fit(image: Image, used: Rect2i, size: int, margin: float) -> Image:
	var body: Image = image.get_region(used)
	body.fix_alpha_edges()
	var span: float = float(size) * (1.0 - 2.0 * margin)
	var scale: float = span / float(maxi(used.size.x, used.size.y))
	var target := Vector2i(maxi(1, roundi(float(used.size.x) * scale)),
		maxi(1, roundi(float(used.size.y) * scale)))
	body.resize(target.x, target.y, Image.INTERPOLATE_LANCZOS)
	var out := Image.create(size, size, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	var at := Vector2i((size - target.x) / 2, (size - target.y) / 2)
	out.blit_rect(body, Rect2i(Vector2i.ZERO, target), at)
	return out
