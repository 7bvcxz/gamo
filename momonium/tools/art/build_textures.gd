extends SceneTree

## Generates the tileable ground textures from fixed seeds and the palette in
## data/art.json. Deterministic: the same seed and palette give the same bytes,
## so a texture is regenerated rather than hand-edited.
##
##   godot --headless --path momonium --script res://tools/art/build_textures.gd
##
## grass.png  256x256  wraps in both directions (island top, mapped in tile space)
## dirt.png   256x64   wraps horizontally (the band under the grass rim)
## stone.png  256x128  wraps horizontally and vertically (cliff blocks)
## cliff.png  256x128  wraps horizontally: dirt, stone and wet line in one face
##
## A painted source in assets/src/png/textures/<name>.png (Step 46) takes the
## place of the procedural grass or cliff, at 512 px, and adds clouds.png
## (the sky's painted cloud band).

const OUT := "res://assets/textures/"
const SIZE := 256

var palette: Dictionary


func _init() -> void:
	var art: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/art.json"))
	palette = art["palette"]
	var painted_grass := _painted("grass")
	var painted_cliff := _painted("cliff")
	var painted_clouds := _painted("clouds")
	_save(_painted_grass(painted_grass) if painted_grass != null else _grass(), "grass")
	_save(_dirt(), "dirt")
	_save(_stone(), "stone")
	_save(_painted_cliff(painted_cliff) if painted_cliff != null else _cliff(), "cliff")
	if painted_clouds != null:
		_save(_painted_clouds(painted_clouds), "clouds")
	quit(0)


# --- painted sources (Step 46) ------------------------------------------------
# A painted image in assets/src/png/textures/ replaces the procedural texture
# of the same name. It is made to tile here, so the source stays exactly what
# was painted and the texture is still rebuilt rather than hand-edited.

const PAINTED := "res://assets/src/png/textures/"
const PAINTED_SIZE := 512


func _painted(name: String) -> Image:
	var path := PAINTED + name + ".png"
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	img.convert(Image.FORMAT_RGBA8)
	return img


func _painted_grass(src: Image) -> Image:
	var img := src.duplicate() as Image
	img.resize(PAINTED_SIZE, PAINTED_SIZE, Image.INTERPOLATE_LANCZOS)
	_flatten_light(img, 0.85)
	return seamless(seamless(img, true), false)


## The cliff face: the painted strip cropped to 2:1 (soil on top, stones
## below), tiled left to right, with the wet line where it meets the water.
func _painted_cliff(src: Image) -> Image:
	var w := src.get_width()
	var h := mini(src.get_height(), w / 2)
	var img := src.get_region(Rect2i(0, (src.get_height() - h) / 2, w, h))
	img.resize(PAINTED_SIZE, PAINTED_SIZE / 2, Image.INTERPOLATE_LANCZOS)
	_flatten_light(img, 0.6)
	img = seamless(img, true)
	var hh := img.get_height()
	for y in range(hh - 6, hh):
		for x in img.get_width():
			img.set_pixel(x, y, img.get_pixel(x, y).lerp(Color(1, 1, 1), 0.55 if y >= hh - 3 else 0.3))
	return img


## Cloud band for the sky shader: already keyed (r = how sunlit, a = cover);
## only made to tile left to right.
func _painted_clouds(src: Image) -> Image:
	var img := src.duplicate() as Image
	img.resize(PAINTED_SIZE, int(float(PAINTED_SIZE) * src.get_height() / src.get_width()), Image.INTERPOLATE_LANCZOS)
	return seamless(img, true)


## Takes out the painting's broad light (a vignette, a brighter corner) so
## the repeat of a tiled texture cannot be seen as a pattern of light patches.
static func _flatten_light(img: Image, strength: float) -> void:
	var low := img.duplicate() as Image
	low.resize(4, 4, Image.INTERPOLATE_BILINEAR)
	var mean := Color(0, 0, 0, 0)
	for y in 4:
		for x in 4:
			mean += low.get_pixel(x, y) / 16.0
	low.resize(img.get_width(), img.get_height(), Image.INTERPOLATE_BILINEAR)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var d := (mean - low.get_pixel(x, y)) * strength
			img.set_pixel(x, y, Color(clampf(c.r + d.r, 0, 1), clampf(c.g + d.g, 0, 1), clampf(c.b + d.b, 0, 1), c.a))


## Makes an image wrap along one axis: a copy shifted by half the size wraps
## exactly where the original has its seam, so near the edges the shifted
## copy is shown and in the middle the original, with a soft blend between.
static func seamless(img: Image, horizontal: bool) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var t := absf(float(x) - w / 2.0) / (w / 2.0) if horizontal else absf(float(y) - h / 2.0) / (h / 2.0)
			var k := smoothstep(0.35, 1.0, t)
			var shifted := img.get_pixel((x + w / 2) % w, y) if horizontal else img.get_pixel(x, (y + h / 2) % h)
			out.set_pixel(x, y, img.get_pixel(x, y).lerp(shifted, k))
	return out


func _c(key: String, i: int = 0) -> Color:
	var v: Variant = palette[key]
	return Color.html(v[i] if typeof(v) == TYPE_ARRAY else v)


func _noise(seed_value: int, freq: float, w: int, h: int) -> Image:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = freq
	n.fractal_octaves = 3
	return n.get_seamless_image(w, h, false, false, 0.2, true)


func _grass() -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var broad := _noise(11, 0.012, SIZE, SIZE)
	var fine := _noise(12, 0.08, SIZE, SIZE)
	var light := _c("grass", 0)
	var mid := _c("grass", 1)
	var dark := _c("grass", 2)
	for y in SIZE:
		for x in SIZE:
			var b := broad.get_pixel(x, y).r
			var f := fine.get_pixel(x, y).r
			var t := clampf(b * 0.75 + f * 0.35 - 0.05, 0.0, 1.0)
			var col := light.lerp(mid, smoothstep(0.25, 0.6, t)).lerp(dark, smoothstep(0.6, 0.95, t))
			img.set_pixel(x, y, col)
	# Blades: short strokes, wrapped at the edges so the tile stays seamless.
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var blade_light := _c("grass_rim")
	for i in 900:
		var x := rng.randi_range(0, SIZE - 1)
		var y := rng.randi_range(0, SIZE - 1)
		var length := rng.randi_range(2, 4)
		var tone := blade_light if rng.randf() < 0.6 else dark.darkened(0.15)
		for k in length:
			var px := posmod(x + (1 if k == length - 1 and rng.randf() < 0.5 else 0), SIZE)
			var py := posmod(y - k, SIZE)
			img.set_pixel(px, py, img.get_pixel(px, py).lerp(tone, 0.55))
	return img


func _dirt() -> Image:
	var h := 64
	var img := Image.create(SIZE, h, false, Image.FORMAT_RGBA8)
	var n := _noise(21, 0.05, SIZE, h)
	var top := _c("dirt", 0)
	var bottom := _c("dirt", 1)
	for y in h:
		for x in SIZE:
			var t := float(y) / float(h - 1)
			var col := top.lerp(bottom, t * 0.8).lerp(bottom.darkened(0.2), n.get_pixel(x, y).r * 0.35)
			img.set_pixel(x, y, col)
	var rng := RandomNumberGenerator.new()
	rng.seed = 22
	for i in 120:
		var x := rng.randi_range(0, SIZE - 1)
		var y := rng.randi_range(2, h - 3)
		var c := img.get_pixel(x, y).lightened(0.18)
		for dx in 2:
			img.set_pixel(posmod(x + dx, SIZE), y, c)
	return img


func _stone() -> Image:
	var w := SIZE
	var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var n := _noise(31, 0.06, w, h)
	var mortar := _c("stone", 2).darkened(0.25)
	img.fill(mortar)
	var rng := RandomNumberGenerator.new()
	rng.seed = 32
	var block_w := 64
	var block_h := 32
	for row in h / block_h:
		var offset := 0 if row % 2 == 0 else block_w / 2
		for col in range(-1, w / block_w + 1):
			var x0 := col * block_w + offset
			var base := _c("stone", 0).lerp(_c("stone", 1), rng.randf() * 0.8)
			for y in range(row * block_h + 2, (row + 1) * block_h - 1):
				for x in range(x0 + 2, x0 + block_w - 1):
					var px := posmod(x, w)
					var v := float(y - row * block_h) / float(block_h)
					var col_c := base.lightened(0.12 * (1.0 - v * 2.5) if v < 0.4 else 0.0).darkened(0.18 * maxf(0.0, v - 0.7) * 3.0)
					col_c = col_c.lerp(_c("stone", 2), n.get_pixel(px, y).r * 0.22)
					img.set_pixel(px, y, col_c)
	return img


## One texture for a whole cliff face, top to bottom: dirt band, stone blocks,
## and the wet line where it meets the water. One texture means one mesh, so
## faces can be drawn strictly far-to-near in a single draw call.
func _cliff() -> Image:
	var w := SIZE
	var h := 128
	var dirt := _dirt()
	var stone := _stone()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var dirt_h := int(h * 0.32)
	for y in h:
		for x in w:
			var c: Color
			if y < dirt_h:
				c = dirt.get_pixel(x, int(float(y) / dirt_h * (dirt.get_height() - 1)))
			else:
				c = stone.get_pixel(x, int(float(y - dirt_h) / (h - dirt_h) * (stone.get_height() - 1)))
			if y >= h - 4:
				c = c.lerp(Color(1, 1, 1), 0.55 if y >= h - 2 else 0.3)
			img.set_pixel(x, y, c)
	return img


func _save(img: Image, name: String) -> void:
	var path := OUT + name + ".png"
	img.save_png(path)
	print("build_textures: %s %dx%d" % [path, img.get_width(), img.get_height()])
