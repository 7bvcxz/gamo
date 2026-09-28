extends SceneTree

## Takes the snow out of the seam tiles (World Visual Pass 01).
##
##     godot --headless --path motorio --script res://tools/art/build_ore_tiles.gd
##
## Each seam sheet (heatstone_6, copper_6, iron_6, crystal_6) was painted as a
## whole floor tile: the ore in the middle of its own patch of snow. Laid on the
## old floor that patch matched; on the new snow it is a pale square with an
## edge round it -- a node drawn as a tile, which is the look this pass removes.
##
## The ground pass draws multiplied, so white is "no change". This divides each
## tile by its own snow -- the median of its border pixels -- so the snow comes
## out white and vanishes over the ground, while the ore, its shadow and its
## scattered chips keep their colour relative to the snow they were painted on.
## GroundLayer then draws the ground under the node too and the ore over it.
##
## Idempotent: a tile already divided has a white border, and dividing by white
## changes nothing.

const SHEETS := ["res://assets/tiles/heatstone_6.png", "res://assets/tiles/copper_6.png",
	"res://assets/tiles/iron_6.png", "res://assets/tiles/crystal_6.png"]
const TILE := 64
const RIM := 6.0

func _initialize() -> void:
	var failures := 0
	for path: String in SHEETS:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image == null:
			failures += 1
			continue
		image.convert(Image.FORMAT_RGB8)
		for ty in image.get_height() / TILE:
			for tx in image.get_width() / TILE:
				_divide(image, Rect2i(tx * TILE, ty * TILE, TILE, TILE))
		var error: int = image.save_png(ProjectSettings.globalize_path(path))
		print("ORE TILES: %s %d" % [path, error])
		failures += 1 if error != OK else 0
	quit(failures)

static func _divide(image: Image, rect: Rect2i) -> void:
	var rs: Array[float] = []
	var gs: Array[float] = []
	var bs: Array[float] = []
	for i in rect.size.x:
		for edge: Vector2i in [Vector2i(i, 0), Vector2i(i, rect.size.y - 1), Vector2i(0, i),
				Vector2i(rect.size.x - 1, i), Vector2i(i, 1), Vector2i(i, rect.size.y - 2),
				Vector2i(1, i), Vector2i(rect.size.x - 2, i)]:
			var c: Color = image.get_pixelv(rect.position + edge)
			rs.append(c.r)
			gs.append(c.g)
			bs.append(c.b)
	rs.sort()
	gs.sort()
	bs.sort()
	var snow := Color(rs[rs.size() / 2], gs[gs.size() / 2], bs[bs.size() / 2])
	for y in rect.size.y:
		for x in rect.size.x:
			var at: Vector2i = rect.position + Vector2i(x, y)
			var c: Color = image.get_pixelv(at)
			var divided := Color(
				clampf(c.r / maxf(snow.r, 0.01), 0.0, 1.0),
				clampf(c.g / maxf(snow.g, 0.01), 0.0, 1.0),
				clampf(c.b / maxf(snow.b, 0.01), 0.0, 1.0))
			# The painted rim the old floor tiles all had (the grid drawn on the
			# snow) faded out: white at the edge, the picture six pixels in.
			var inside: float = float(mini(mini(x, rect.size.x - 1 - x), mini(y, rect.size.y - 1 - y)))
			var t: float = clampf(inside / RIM, 0.0, 1.0)
			image.set_pixelv(at, Color.WHITE.lerp(divided, t * t * (3.0 - 2.0 * t)))
