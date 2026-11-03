extends SceneTree

## Builds assets/atlas/sprites.png + sprites.json from the hand-written SVGs in
## art_src/ (art_src/sprites.json lists them).
##
##   godot --headless --path popcorn-glory --script res://tools/build_atlas.gd
##   godot --headless --path popcorn-glory --import     # let the editor import the png
##
## Each SVG is rasterised at its `scale`, trimmed to its visible pixels and
## shelf-packed; the padding repeats each sprite's edge pixels so linear
## filtering and mipmaps never sample a neighbour (momonium's way). Each
## region keeps its source's sha so a test fails when an SVG changes without a
## rebuild. Godot's own SVG rasteriser does the drawing: no other tool is
## needed (this machine has no ImageMagick, Inkscape or Pillow).

const MANIFEST := "res://art_src/sprites.json"
const SRC := "res://art_src/"
const OUT_PNG := "res://assets/atlas/sprites.png"
const OUT_JSON := "res://assets/atlas/sprites.json"
const WIDTH := 256


func _init() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var pad := int(manifest.get("padding", 2))
	var items: Array[Dictionary] = []
	for name: String in manifest["sprites"]:
		var spec: Dictionary = manifest["sprites"][name]
		var svg := FileAccess.get_file_as_string(SRC + String(spec["source"]))
		var image := Image.new()
		if svg == "" or image.load_svg_from_string(svg, float(spec.get("scale", 1.0))) != OK:
			push_error("build_atlas: %s does not rasterise" % name)
			quit(1)
			return
		image.convert(Image.FORMAT_RGBA8)
		var used := image.get_used_rect()
		items.append({"name": name, "image": image.get_region(used), "sha": svg.sha256_text().substr(0, 16),
			"source": spec["source"], "full": [image.get_width(), image.get_height()], "trim": [used.position.x, used.position.y]})
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["image"].get_height() > b["image"].get_height() or (a["image"].get_height() == b["image"].get_height() and a["name"] < b["name"]))
	# Shelf packing.
	var x := 0
	var y := 0
	var shelf := 0
	for it: Dictionary in items:
		var img: Image = it["image"]
		var w := img.get_width() + pad * 2
		var h := img.get_height() + pad * 2
		if x + w > WIDTH:
			x = 0
			y += shelf
			shelf = 0
		it["at"] = Vector2i(x + pad, y + pad)
		x += w
		shelf = maxi(shelf, h)
	var height := y + shelf
	var pot := 1
	while pot < height:
		pot *= 2
	var atlas := Image.create(WIDTH, pot, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))
	var regions := {}
	for it: Dictionary in items:
		var img: Image = it["image"]
		var at: Vector2i = it["at"]
		atlas.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at)
		_extrude(atlas, Rect2i(at, img.get_size()), pad)
		regions[it["name"]] = {"rect": [at.x, at.y, img.get_width(), img.get_height()], "source": it["source"], "sha": it["sha"]}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/atlas"))
	var err := atlas.save_png(ProjectSettings.globalize_path(OUT_PNG))
	var f := FileAccess.open(OUT_JSON, FileAccess.WRITE)
	f.store_string(JSON.stringify({"_doc": "Made by tools/build_atlas.gd from art_src/. Do not edit by hand.", "size": [WIDTH, pot], "regions": regions}, "  ", false))
	f.close()
	print("build_atlas: %d sprites -> %s (%dx%d) err=%d" % [items.size(), OUT_PNG, WIDTH, pot, err])
	quit(0 if err == OK else 1)


## Repeat the outermost pixels of `r` outwards by `pad` on every side.
func _extrude(img: Image, r: Rect2i, pad: int) -> void:
	for i in range(1, pad + 1):
		for xx in range(r.position.x, r.end.x):
			img.set_pixel(xx, r.position.y - i, img.get_pixel(xx, r.position.y))
			img.set_pixel(xx, r.end.y - 1 + i, img.get_pixel(xx, r.end.y - 1))
		for yy in range(r.position.y - pad, r.end.y + pad):
			img.set_pixel(r.position.x - i, yy, img.get_pixel(r.position.x, yy))
			img.set_pixel(r.end.x - 1 + i, yy, img.get_pixel(r.end.x - 1, yy))
