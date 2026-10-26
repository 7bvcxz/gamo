extends SceneTree

const ManifestJson := preload("res://tools/art/gen/manifest_json.gd")

## Step 52: the concept's night has lit windows. For each building this finds
## the window glass in its painted source -- small, compact blobs of pale blue
## pixels with their white highlights, framed by something that is not blue
## (a roof's or a dome's glints are rimmed by more blue; a pond is too large)
## -- and writes them as a warm "lit" sprite in the
## same frame (`assets/src/png/lit/<name>.png`, manifest `<name>_lit`, same
## scale and pivots). At night BuildingView lays it over the building.
##
##   godot --headless --path momonium --script res://tools/art/gen/window_lights.gd -- \
##     [--only lab,office] [--debug /abs/dir]

const MIN_PX := 10
## A window is small: larger blobs are roofs, domes, panels, water.
const MAX_PX := 700
const MIN_FILL := 0.3
## How far out (px) the rim is read: past a pane's own dark edge, onto its frame.
const RIM_OUT := 4
const WARM := Color("#ffc256")
const WARM_HI := Color("#ffe6a0")
## Sprites whose panes are painted amber: amber counts as glass there, when
## a dark wooden frame holds it (sand, planks and flowers have none).
const AMBER := ["community_center", "pub", "villa", "school"]
## Sprites with no windows to light (or whose blue glass is not a window).
const SKIP := ["farm", "solar_panel", "wind_turbine", "park", "momo_monument", "lumberyard", "mine", "smelter", "steam_engine"]


func _init() -> void:
	var args := {}
	var raw := OS.get_cmdline_user_args()
	for i in range(0, raw.size() - 1, 2):
		args[raw[i].trim_prefix("--")] = raw[i + 1]
	var path := "res://assets/sprites.json"
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var types: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/buildings.json"))["types"]
	var only: PackedStringArray = String(args.get("only", "")).split(",", false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/src/png/lit"))
	for type: String in types:
		var name := String(types[type].get("sprite", ""))
		if name in SKIP or (not only.is_empty() and not name in only) or not manifest["sprites"].has(name):
			continue
		var spec: Dictionary = manifest["sprites"][name]
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/src/" + String(spec["source"])))
		img.convert(Image.FORMAT_RGBA8)
		var lit := windows(img, name in AMBER)
		var used := lit.get_used_rect()
		var key := name + "_lit"
		if used.size.x == 0:
			# No windows (any more): no sprite, and no file left from a run that found some.
			manifest["sprites"].erase(key)
			DirAccess.remove_absolute(ProjectSettings.globalize_path("res://assets/src/png/lit/%s.png" % name))
			print("window_lights: %s none" % name)
			continue
		var scale := float(spec.get("scale", 1.0))
		lit.get_region(used).save_png(ProjectSettings.globalize_path("res://assets/src/png/lit/%s.png" % name))
		var pivots := {}
		for p: String in spec["pivots"]:
			var v: Array = spec["pivots"][p]
			pivots[p] = [snappedf(float(v[0]) - used.position.x / scale, 0.5), snappedf(float(v[1]) - used.position.y / scale, 0.5)]
		var entry := {"source": "png/lit/%s.png" % name, "scale": scale, "pivots": {"origin": pivots["origin"]}}
		if spec.has("world_scale"):
			entry["world_scale"] = spec["world_scale"]
		manifest["sprites"][key] = entry
		if args.has("debug"):
			# Night-ish: the building dimmed, the lit panes on top.
			var dbg := img.duplicate() as Image
			for y in dbg.get_height():
				for x in dbg.get_width():
					var c := dbg.get_pixel(x, y)
					dbg.set_pixel(x, y, Color(c.r * 0.35, c.g * 0.4, c.b * 0.6, c.a))
			dbg.blend_rect(lit, Rect2i(Vector2i.ZERO, lit.get_size()), Vector2i.ZERO)
			dbg.save_png(String(args["debug"]).path_join(name + ".png"))
		print("window_lights: %s %d px in %s" % [name, _count(lit), used])
	var f := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	f.store_string(ManifestJson.dump(manifest) + "\n")
	f.close()
	quit()


## The lit windows of `img`: same size, transparent but for the glass.
static func windows(img: Image, amber := false) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var glass := PackedByteArray()
	glass.resize(w * h)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if _is_glass(c):
				glass[y * w + x] = 1
			elif amber and _is_amber(c):
				glass[y * w + x] = 2
	# White highlights inside a pane belong to it.
	for pass_i in 2:
		var grown := glass.duplicate()
		for y in range(1, h - 1):
			for x in range(1, w - 1):
				var i := y * w + x
				if glass[i] == 1:
					continue
				var c := img.get_pixel(x, y)
				if c.a > 0.9 and c.r > 0.85 and c.g > 0.88 and c.b > 0.88 and int(glass[i - 1] == 1) + int(glass[i + 1] == 1) + int(glass[i - w] == 1) + int(glass[i + w] == 1) >= 2:
					grown[i] = 1
		glass = grown
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var seen := PackedByteArray()
	seen.resize(w * h)
	for start in w * h:
		if glass[start] == 0 or seen[start] == 1:
			continue
		var blob: Array[int] = []
		var lo := Vector2i(w, h)
		var hi := Vector2i(-1, -1)
		var stack: Array[int] = [start]
		seen[start] = 1
		while not stack.is_empty():
			var i: int = stack.pop_back()
			blob.append(i)
			var x := i % w
			var y := i / w
			lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
			hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
			for j: int in [i - 1, i + 1, i - w, i + w]:
				if j >= 0 and j < w * h and glass[j] == glass[start] and seen[j] == 0:
					seen[j] = 1
					stack.append(j)
		var box := hi - lo + Vector2i.ONE
		var fill := blob.size() / float(box.x * box.y)
		if blob.size() < MIN_PX or blob.size() > MAX_PX or fill < MIN_FILL:
			continue
		# A pane sits in a frame of wood or plaster; a glint on a blue roof or
		# dome sits in more blue. Look at what rims the blob.
		var rim := 0
		var blue_rim := 0
		# A few pixels out, past the pane's own darker edge.
		var members := {}
		for i: int in blob:
			members[i] = true
		for i: int in blob:
			for j: int in [i - RIM_OUT, i + RIM_OUT, i - w * RIM_OUT, i + w * RIM_OUT]:
				if j < 0 or j >= w * h or members.has(j) or glass[j] != 0:
					continue
				var c := img.get_pixel(j % w, j / w)
				if c.a < 0.5:
					continue
				rim += 1
				if c.b > c.r + 0.08 and c.b > 0.35:
					blue_rim += 1
		if rim > 0 and blue_rim > rim * 0.5:
			continue
		if glass[start] == 2 and _dark_rim(img, blob, members) < 0.45:
			continue
		for i: int in blob:
			var c := img.get_pixel(i % w, i / w)
			out.set_pixel(i % w, i / w, WARM_HI if c.r > 0.85 and c.b > 0.85 else WARM)
	return out


## A pane painted lit: warm amber.
static func _is_amber(c: Color) -> bool:
	return c.a >= 0.9 and c.r > 0.9 and c.g > 0.62 and c.g < 0.92 and c.b < 0.55 and c.r - c.b > 0.4


## Share of the pixels just outside `blob` that are dark (a wooden frame).
static func _dark_rim(img: Image, blob: Array[int], members: Dictionary) -> float:
	var w := img.get_width()
	var n := 0
	var dark := 0
	for i: int in blob:
		for j: int in [i - 2, i + 2, i - w * 2, i + w * 2]:
			if j < 0 or j >= w * img.get_height() or members.has(j):
				continue
			var c := img.get_pixel(j % w, j / w)
			if c.a < 0.5:
				continue
			n += 1
			if c.get_luminance() < 0.5:
				dark += 1
	return dark / float(maxi(n, 1))


## Pale window blue. (Amber panes are painted lit already, and amber is also
## sand, planks and flowers -- it is not looked for.)
static func _is_glass(c: Color) -> bool:
	return c.a >= 0.9 and c.b > 0.6 and c.g > 0.55 and c.b - c.r > 0.12 and c.r < 0.8 and c.b >= c.g


static func _count(img: Image) -> int:
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				n += 1
	return n
