extends SceneTree

## Turns Windup's generated source art (art/raw/, from tools/art/gen_art.sh)
## into what the game loads (assets/art/). Godot's Image API only: this
## machine has no Pillow, and the tool that makes the shipped art should run
## wherever the game runs.
##
##   godot --headless --path windup --script res://tools/art/build_art.gd -- --green   # reference canvases
##   godot --headless --path windup --script res://tools/art/build_art.gd              # raw -> assets
##
## Each step is here for a reason the Gamo repository already paid for
## (AGENTS.md lessons, motorio/tools/art/key_buildings.gd):
## * key on "how much greener than anything else", not one colour -- generated
##   green is near (0, 255, 0) but never exact;
## * despill the edge, drop specks, bleed colour into clear pixels before a
##   resize so the edge does not average with green;
## * a storyboard's frames share ONE scale and one foot line -- a frame fitted
##   to its own box changes size from frame to frame (the 2026-08-09 lesson);
## * stored at the size the game draws, so the pack stays small.

const RAW := "res://art/raw/"
const REF := "res://art/ref/"
const OUT := "res://assets/art/"

## The backdrop fills the 1280x720 design rectangle and the expand margin.
const BACKDROP_SIZE := Vector2i(1440, 960)
## The key's stored diameter (drawn at ~220 px in the design rectangle).
const KEY_SIZE := 256
## A doll frame cell; the tallest pose fills TALLEST px of it.
const DOLL_CELL := Vector2i(200, 240)
const DOLL_TALLEST := 228


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var failures := 0
	if args.has("--green"):
		failures += _green()
	else:
		failures += _backdrop()
		failures += _key()
		failures += _doll_wake()
	quit(failures)


# --- reference canvases -------------------------------------------------------

func _green() -> int:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REF))
	var bad := 0
	for size: Vector2i in [Vector2i(1536, 1024), Vector2i(1024, 1024)]:
		var img := Image.create(size.x, size.y, false, Image.FORMAT_RGB8)
		img.fill(Color8(0, 255, 0))
		var path := ProjectSettings.globalize_path(REF + "green_%dx%d.png" % [size.x, size.y])
		var err := img.save_png(path)
		print("ART: green %s -> %d" % [path, err])
		bad += 1 if err != OK else 0
	return bad


# --- the three assets -----------------------------------------------------------

func _backdrop() -> int:
	var img := _load_raw("backdrop")
	if img == null:
		return 1
	img.convert(Image.FORMAT_RGB8)
	# Cover: scale to fill BACKDROP_SIZE, crop the overflow evenly.
	var s := maxf(float(BACKDROP_SIZE.x) / img.get_width(), float(BACKDROP_SIZE.y) / img.get_height())
	img.resize(ceili(img.get_width() * s), ceili(img.get_height() * s), Image.INTERPOLATE_LANCZOS)
	var off := (Vector2i(img.get_width(), img.get_height()) - BACKDROP_SIZE) / 2
	var out := img.get_region(Rect2i(off, BACKDROP_SIZE))
	return _save(out, "backdrop.webp", true, 0.82)


func _key() -> int:
	var img := _load_raw("key")
	if img == null:
		return 1
	_prepare(img)
	var body := _opaque_rect(img, 0.5)
	if body.size == Vector2i.ZERO:
		print("ART: key has no body after keying")
		return 1
	# Square around the body's centre, so the sprite turns about its middle.
	var side := maxi(body.size.x, body.size.y)
	var centre := body.get_center()
	var square := Image.create(side, side, false, Image.FORMAT_RGBA8)
	square.blit_rect(img, Rect2i(centre - Vector2i(side, side) / 2, Vector2i(side, side)), Vector2i.ZERO)
	square.fix_alpha_edges()
	square.resize(KEY_SIZE, KEY_SIZE, Image.INTERPOLATE_LANCZOS)
	return _save(square, "key.webp", false, 0.9)


## The storyboard: N poses in a row on green -> one strip of equal cells, all
## at one scale, feet on one line, plus a JSON describing the strip.
func _doll_wake() -> int:
	var img := _load_raw("doll_wake")
	if img == null:
		return 1
	_prepare(img)
	var figures := _split_columns(img)
	if figures.size() < 2:
		print("ART: doll_wake split into %d figures, expected the storyboard's poses" % figures.size())
		return 1
	var tallest := 0
	for r: Rect2i in figures:
		tallest = maxi(tallest, r.size.y)
	var scale := float(DOLL_TALLEST) / tallest
	var sheet := Image.create(DOLL_CELL.x * figures.size(), DOLL_CELL.y, false, Image.FORMAT_RGBA8)
	var frames: Array = []
	for i in figures.size():
		var r: Rect2i = figures[i]
		var part := img.get_region(r)
		part.fix_alpha_edges()
		var w := maxi(1, roundi(r.size.x * scale))
		var h := maxi(1, roundi(r.size.y * scale))
		part.resize(w, h, Image.INTERPOLATE_LANCZOS)
		if w > DOLL_CELL.x:
			print("ART: doll frame %d is %d px wide, wider than the %d px cell" % [i, w, DOLL_CELL.x])
			return 1
		# Feet on the cell's bottom line (2 px margin), centred horizontally.
		var at := Vector2i(i * DOLL_CELL.x + (DOLL_CELL.x - w) / 2, DOLL_CELL.y - 2 - h)
		sheet.blit_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), at)
		frames.append({"source": [r.position.x, r.position.y, r.size.x, r.size.y], "size": [w, h]})
	var bad := _save(sheet, "doll_wake.webp", false, 0.9)
	var meta := {
		"frames": figures.size(),
		"cell": [DOLL_CELL.x, DOLL_CELL.y],
		"foot": [DOLL_CELL.x / 2, DOLL_CELL.y - 2],
		"scale": snappedf(scale, 0.0001),
		"poses": ["asleep", "stirring", "awake", "stretch"].slice(0, figures.size()),
		"detail": frames,
	}
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT + "doll_wake.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "  ") + "\n")
	f.close()
	return bad


# --- helpers ----------------------------------------------------------------------

func _load_raw(name: String) -> Image:
	var path := ProjectSettings.globalize_path(RAW + name + ".png")
	var img := Image.load_from_file(path)
	if img == null:
		print("ART: missing %s (windup/tools/art/gen_art.sh --go %s)" % [path, name])
	return img


func _save(img: Image, file: String, lossy: bool, quality: float) -> int:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var path := ProjectSettings.globalize_path(OUT + file)
	var err := img.save_webp(path, lossy, quality)
	print("ART: %s %dx%d %s -> %d bytes (err %d)" % [file, img.get_width(), img.get_height(),
		"lossy" if lossy else "lossless", FileAccess.get_file_as_bytes(path).size(), err])
	return 1 if err != OK else 0


func _prepare(img: Image) -> void:
	img.convert(Image.FORMAT_RGBA8)
	_key_green(img)
	_despeckle(img)


static func _key_green(image: Image) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var c: Color = image.get_pixel(x, y)
			var green: float = c.g - maxf(c.r, c.b)
			var alpha := 1.0
			if green > 0.28:
				alpha = 0.0
			elif green > 0.08:
				alpha = 1.0 - (green - 0.08) / 0.20
			if alpha < 1.0 or green > 0.02:
				c.g = minf(c.g, maxf(c.r, c.b) * 1.02)
			c.a = alpha
			image.set_pixel(x, y, c)


## Keeps islands of at least 2% of the largest one (a figure's separate
## pieces, like a raised hand, survive; generation specks do not).
static func _despeckle(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var label := PackedInt32Array()
	label.resize(w * h)
	label.fill(-1)
	var sizes: Array[int] = []
	for start in w * h:
		if label[start] != -1 or image.get_pixel(start % w, start / w).a < 0.5:
			continue
		var id := sizes.size()
		var count := 0
		var stack: Array[int] = [start]
		label[start] = id
		while not stack.is_empty():
			var at: int = stack.pop_back()
			count += 1
			var ax := at % w
			var ay := at / w
			for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := ax + step.x
				var ny := ay + step.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var next := ny * w + nx
				if label[next] == -1 and image.get_pixel(nx, ny).a >= 0.5:
					label[next] = id
					stack.append(next)
		sizes.append(count)
	var largest := 0
	for count: int in sizes:
		largest = maxi(largest, count)
	for index in w * h:
		var id := label[index]
		if id >= 0 and sizes[id] < largest * 0.02:
			var c := image.get_pixel(index % w, index / w)
			c.a = 0.0
			image.set_pixel(index % w, index / w, c)


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


## Splits a row of figures at empty columns. Gaps narrower than 1.5% of the
## width do not split (a gap between an arm and a body is not a new figure);
## pieces narrower than 4% of the width are dropped.
static func _split_columns(image: Image) -> Array[Rect2i]:
	var w := image.get_width()
	var h := image.get_height()
	var filled := PackedByteArray()
	filled.resize(w)
	for x in w:
		for y in h:
			if image.get_pixel(x, y).a >= 0.5:
				filled[x] = 1
				break
	var spans: Array[Vector2i] = []
	var start := -1
	var gap := 0
	var min_gap := maxi(4, int(w * 0.015))
	for x in w + 1:
		var on := x < w and filled[x] == 1
		if on:
			if start < 0:
				start = x
			gap = 0
		elif start >= 0:
			gap += 1
			if gap >= min_gap or x == w:
				spans.append(Vector2i(start, x - gap + 1))
				start = -1
				gap = 0
	var out: Array[Rect2i] = []
	for s: Vector2i in spans:
		if s.y - s.x < w * 0.04:
			continue
		var top := h
		var bottom := -1
		for x in range(s.x, s.y):
			for y in h:
				if image.get_pixel(x, y).a >= 0.5:
					top = mini(top, y)
					bottom = maxi(bottom, y)
		out.append(Rect2i(s.x, top, s.y - s.x, bottom - top + 1))
	return out
