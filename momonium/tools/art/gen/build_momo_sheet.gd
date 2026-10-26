extends SceneTree

## Step 51: the keyed Momo poses (assets/src/png/momo/*.webp) -> one 5x5
## sheet of equal cells and its map, the runtime's only Momo picture.
##
## Every cell is the same character at the same size. A cell's `fit` says
## how: "height" (the default: an upright pose, fur curl to feet, fitted to
## `stand_height`), "head" (something rises above the head -- a pickaxe -- or
## the body is not upright: the width of the head and the ears hanging beside
## it, matched to its view's standing anchor) or "width" (lying down: the
## whole pose fitted to `width`). `adjust` scales the result. (Fitting every
## pose by its head band made a walk pulse: a swinging ear or a raised paw
## widens that band by up to 10%.) A cell is placed so its head is centred and its lowest point
## touches the ground line, `foot` px above the cell's bottom -- the pivot,
## the same for all 25.
##
##   godot --headless --path momonium --script res://tools/art/gen/build_momo_sheet.gd -- \
##     [--cells res://assets/src/png/momo/cells.json] [--out res://assets/momo/momo_sheet]

const HEAD_BAND := Vector2(0.18, 0.45)


func _init() -> void:
	var args := {"cells": "res://assets/src/png/momo/cells.json", "out": "res://assets/momo/momo_sheet"}
	var raw := OS.get_cmdline_user_args()
	for i in range(0, raw.size() - 1, 2):
		args[raw[i].trim_prefix("--")] = raw[i + 1]
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(String(args["cells"])))
	var cell := int(cfg["cell"])
	var cols := int(cfg["cols"])
	var rows := int(cfg["rows"])
	var foot := int(cfg["foot"])
	var stand := float(cfg["stand_height"])
	var dir := String(args["cells"]).get_base_dir()
	var sheet := Image.create(cell * cols, cell * rows, false, Image.FORMAT_RGBA8)
	# The anchors first: they set each view's head width in cell pixels.
	var head_target := {}
	var by_name := {}
	for c: Dictionary in cfg["cells"]:
		by_name[String(c["name"])] = c
	for view: String in cfg["anchors"]:
		var a: Dictionary = by_name[String(cfg["anchors"][view])]
		var img := _load(dir, a)
		var s := stand / float(img.get_height())
		head_target[view] = head(img).x * s
	var out_cells: Array = []
	print("%-14s %-5s %7s %7s %7s" % ["cell", "fit", "scale", "head", "height"])
	for c: Dictionary in cfg["cells"]:
		var img := _load(dir, c)
		var view := String(c["view"])
		var fit := String(c.get("fit", "height"))
		var h := head(img)
		var s := stand / float(img.get_height())
		if fit == "head":
			s = float(head_target[view]) / h.x
		elif fit == "width":
			s = float(c["width"]) / float(img.get_width())
		s *= float(c.get("adjust", 1.0))
		var w2 := maxi(1, roundi(img.get_width() * s))
		var h2 := maxi(1, roundi(img.get_height() * s))
		img.resize(w2, h2, Image.INTERPOLATE_LANCZOS)
		# Upright: the head over the pivot (it stays put while the feet step).
		# Lying down (`align: box`): the whole body over it.
		var head_x := h.y * s if String(c.get("align", "head")) == "head" else w2 / 2.0
		var origin := Vector2i(int(c["col"]) * cell, int(c["row"]) * cell)
		var at := Vector2i(roundi(cell / 2.0 - head_x), cell - foot - h2)
		if at.x < 0 or at.y < 0 or at.x + w2 > cell or at.y + h2 > cell:
			push_error("cell %s does not fit: %dx%d at %s" % [c["name"], w2, h2, at])
		var src := Rect2i(Vector2i.ZERO, Vector2i(w2, h2))
		sheet.blend_rect(img, src, origin + at)
		print("%-14s %-5s %7.4f %7.1f %7d" % [c["name"], fit, s, h.x * s, h2])
		out_cells.append({"name": c["name"], "row": c["row"], "col": c["col"], "view": view,
			"state": c["state"], "frame": int(c.get("frame", 0)), "box": [at.x, at.y, w2, h2]})
	var base := String(args["out"])
	var png := ProjectSettings.globalize_path(base + ".png")
	DirAccess.make_dir_recursive_absolute(png.get_base_dir())
	sheet.save_png(png)
	var meta := {
		"_doc": "Momo's sprite sheet (Step 51, design/MOMO_SPRITES.md): equal cells, rows x cols; each cell holds one pose of the same Momo, its feet on the pivot (cell x, cell y from the cell's top-left). `animations` name the cells a state plays in order at `fps`; a left-facing view is the same cell mirrored. Built by tools/art/gen/build_momo_sheet.gd from assets/src/png/momo/.",
		"cell": [cell, cell], "cols": cols, "rows": rows, "pivot": [cell / 2, cell - foot], "stand_height": stand,
		"cells": out_cells, "animations": cfg["animations"],
	}
	# The portrait the panels use (atlas sprite `momo_front`): the front
	# standing cell in the 200x220 frame the old drawing had, feet at
	# (100, 210), so every icon keeps its anchors.
	var front: Dictionary = by_name[String(cfg["anchors"]["front"])]
	var portrait := sheet.get_region(Rect2i(int(front["col"]) * cell + cell / 2 - 100, int(front["row"]) * cell + cell - foot - 210, 200, 220))
	portrait.save_png(ProjectSettings.globalize_path(String(cfg.get("portrait", "res://assets/src/png/momo_front.png"))))
	var f := FileAccess.open(ProjectSettings.globalize_path(base + ".json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "  ", false) + "\n")
	f.close()
	print("build_momo_sheet: %s.png %dx%d, %d cells" % [base, sheet.get_width(), sheet.get_height(), out_cells.size()])
	quit()


func _load(dir: String, c: Dictionary) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(dir.path_join(String(c["src"]))))
	img.convert(Image.FORMAT_RGBA8)
	return img


## (width, centre x) of the widest opaque row in the head band -- the head
## and the ears hanging beside it, in every upright pose.
static func head(img: Image) -> Vector2:
	var h := img.get_height()
	var best := Vector2(1, img.get_width() / 2.0)
	for y in range(int(h * HEAD_BAND.x), int(h * HEAD_BAND.y)):
		var lo := -1
		var hi := -1
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				if lo < 0:
					lo = x
				hi = x
		if lo >= 0 and hi - lo + 1 > best.x:
			best = Vector2(hi - lo + 1, (lo + hi + 1) / 2.0)
	return best
