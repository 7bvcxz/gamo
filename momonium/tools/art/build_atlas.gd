extends SceneTree

## Builds assets/atlas/<atlas>.png + .json from assets/sprites.json.
##
##   godot --headless --path momonium --script res://tools/art/build_atlas.gd
##   godot --headless --path momonium --import      # let the editor import the png
##
## Each SVG is rasterised at its `scale`, trimmed to its visible pixels, and
## shelf-packed with padding whose pixels repeat the sprite's edge (so linear
## filtering and mipmaps never sample a neighbour). Pivots are converted from
## SVG units to pixels relative to the trimmed region. The source hash of every
## SVG is written into the json; tests fail when a source changes without a
## rebuild.

const MANIFEST := "res://assets/sprites.json"
const SRC := "res://assets/src/"
const OUT_DIR := "res://assets/atlas/"


func _init() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var art: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/art.json"))
	var max_size: int = int(art["budgets"]["atlas_max_size"])
	var padding: int = int(manifest.get("padding", 2))
	var items: Array[Dictionary] = []
	for name: String in manifest["sprites"]:
		var spec: Dictionary = manifest["sprites"][name]
		var svg := FileAccess.get_file_as_string(SRC + spec["source"])
		var scale: float = float(spec.get("scale", 1.0))
		var image := Image.new()
		var err := image.load_svg_from_string(svg, scale)
		if err != OK:
			push_error("build_atlas: %s failed to rasterise (%d)" % [name, err])
			quit(1)
			return
		image.convert(Image.FORMAT_RGBA8)
		var used := image.get_used_rect()
		var trimmed := image.get_region(used)
		var pivots := {}
		for pivot: String in spec.get("pivots", {}):
			var p: Array = spec["pivots"][pivot]
			pivots[pivot] = [float(p[0]) * scale - used.position.x, float(p[1]) * scale - used.position.y]
		items.append({"name": name, "image": trimmed, "pivots": pivots, "source": spec["source"],
			"sha": svg.sha256_text().substr(0, 16), "world_scale": float(spec.get("world_scale", 1.0))})
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["image"].get_height() > b["image"].get_height() or (a["image"].get_height() == b["image"].get_height() and a["name"] < b["name"]))

	var width := 256
	var layout := {}
	while true:
		layout = _pack(items, width, padding)
		if layout["height"] <= width or width >= max_size:
			break
		width *= 2
	var height := _next_pow2(int(layout["height"]))
	if width > max_size or height > max_size:
		push_error("build_atlas: atlas %dx%d exceeds budget %d" % [width, height, max_size])
		quit(1)
		return
	var atlas := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var out_sprites := {}
	for item: Dictionary in items:
		var pos: Vector2i = layout["positions"][item["name"]]
		var img: Image = item["image"]
		_blit_extruded(atlas, img, pos, padding)
		out_sprites[item["name"]] = {
			"region": [pos.x, pos.y, img.get_width(), img.get_height()],
			"pivots": item["pivots"], "source": item["source"], "source_sha": item["sha"],
			"world_scale": item["world_scale"]}
	var atlas_name: String = manifest.get("atlas", "sprites")
	atlas.save_png(OUT_DIR + atlas_name + ".png")
	var out := {"generated_by": "tools/art/build_atlas.gd", "size": [width, height], "sprites": out_sprites}
	var f := FileAccess.open(OUT_DIR + atlas_name + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  ", true))
	f.close()
	print("build_atlas: %d sprites -> %s%s.png (%dx%d)" % [items.size(), OUT_DIR, atlas_name, width, height])
	quit(0)


func _pack(items: Array[Dictionary], width: int, padding: int) -> Dictionary:
	var x := padding
	var y := padding
	var shelf := 0
	var positions := {}
	for item: Dictionary in items:
		var img: Image = item["image"]
		if x + img.get_width() + padding > width:
			x = padding
			y += shelf + padding * 2
			shelf = 0
		positions[item["name"]] = Vector2i(x, y)
		x += img.get_width() + padding * 2
		shelf = maxi(shelf, img.get_height())
	return {"positions": positions, "height": y + shelf + padding}


func _blit_extruded(atlas: Image, img: Image, pos: Vector2i, padding: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for dy in range(-padding, h + padding):
		for dx in range(-padding, w + padding):
			var sx := clampi(dx, 0, w - 1)
			var sy := clampi(dy, 0, h - 1)
			if dx == sx and dy == sy:
				continue
			var c := img.get_pixel(sx, sy)
			atlas.set_pixel(pos.x + dx, pos.y + dy, Color(c.r, c.g, c.b, 0.0))
	atlas.blit_rect(img, Rect2i(0, 0, w, h), pos)


static func _next_pow2(v: int) -> int:
	var p := 1
	while p < v:
		p *= 2
	return p
