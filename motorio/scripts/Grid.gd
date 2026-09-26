extends RefCounted
class_name Grid

## The one place a cell becomes pixels, and pixels become a cell.
##
## Grid v2 (Step 1, 2026-09-26) halved the cell: what was one 32 pixel cell is
## now a block of two by two 16 pixel ones, so the same world holds four times
## as many. The direction did not change -- it is the same orthogonal grid, rows
## and columns square to the screen, never a diamond.
##
## Two units come out of that, and they are not the same thing:
##
##   cell   the build grid, `CELL` pixels. Machines, seams, belts, the path grid,
##          collision and every coordinate in the save are cells.
##   tile   a distance, `TILE` pixels -- the size a cell used to be. Every radius,
##          ring, band and reach in `Defs` is written in tiles, which is why not
##          one balance number moved when the grid did: the warm circle is still
##          seven tiles, and seven tiles is fourteen cells.
##
## `Defs.TILE` used to be both. `* Defs.TILE` meant "one cell in pixels" in some
## places and "a distance of one" in others, and nothing in the source said
## which -- so it was deleted rather than redefined, every use became a compile
## error, and each one was decided by hand. Nothing else multiplies by a cell
## size: if a script needs pixels for a cell, it asks here.

## Cells per tile, along each axis.
const SCALE := 1
## Pixels in one tile of distance. Fixed: this is the unit the world is measured
## in, and it is what every number in Defs was tuned against.
const TILE := 32
## Pixels in one cell of the build grid.
const CELL := TILE / SCALE

## "No explicit anchor", for `footprint`.
const AUTO := Vector2i(-9999, -9999)

# --- Cells and pixels ------------------------------------------------------------

## The top-left pixel of a cell.
static func origin(cell: Vector2i) -> Vector2:
	return Vector2(cell) * float(CELL)

## The middle of a cell.
static func centre(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * float(CELL)

## Which cell a point is in. Floor, not truncation: the world has negative
## coordinates and -0.5 truncates to the cell on the wrong side of the origin.
static func cell_at(point: Vector2) -> Vector2i:
	return Vector2i((point / float(CELL)).floor())

static func rect_px(rect: Rect2i) -> Rect2:
	return Rect2(Vector2(rect.position) * float(CELL), Vector2(rect.size) * float(CELL))

static func rect_centre(rect: Rect2i) -> Vector2:
	return (Vector2(rect.position) + Vector2(rect.size) * 0.5) * float(CELL)

## Every cell of a rectangle, row by row.
static func cells_in(rect: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			out.append(Vector2i(x, y))
	return out

# --- Distances -------------------------------------------------------------------

## A distance in tiles, in pixels.
static func px(tiles_distance: float) -> float:
	return tiles_distance * float(TILE)

## A distance in pixels, in tiles.
static func tiles(px_distance: float) -> float:
	return px_distance / float(TILE)

## A distance in tiles, counted in cells.
static func cells(tiles_distance: float) -> float:
	return tiles_distance * float(SCALE)

# --- Tiles as places -------------------------------------------------------------
## Some things are still laid out a tile at a time: the world generator places
## frozen cats, wreckage and the village on the tile lattice it always used, so
## that every distance promise it keeps is kept in the same world space. These
## are the only conversions between the two lattices.

## The top-left cell of a tile.
static func from_tile(tile: Vector2i) -> Vector2i:
	return tile * SCALE

## The tile a cell belongs to. Floor division, for the same reason as `cell_at`.
static func tile_of(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / float(SCALE)), floori(float(cell.y) / float(SCALE)))

## The cells one tile covers.
static func tile_rect(tile: Vector2i) -> Rect2i:
	return Rect2i(tile * SCALE, Vector2i.ONE * SCALE)

static func tile_centre(tile: Vector2i) -> Vector2:
	return (Vector2(tile) + Vector2(0.5, 0.5)) * float(TILE)

# --- Footprints ------------------------------------------------------------------
## A building is an anchor cell, a size and a facing. The anchor is the cell that
## names it -- the key it is stored under, the seam a mining post works -- and the
## footprint is every cell it covers.

## The size once turned to face `dir`. Sizes are written facing east; north and
## south lie the other way, so a 4x6 building turned a quarter is 6x4.
static func rotated(size: Vector2i, dir: Vector2i) -> Vector2i:
	return Vector2i(size.y, size.x) if dir.y != 0 else size

## Where the anchor sits inside a footprint of this size when nothing says
## otherwise: the top-left of the middle two-by-two for even sizes, the middle
## for odd ones. A rule, not a centre -- an even footprint has no middle cell.
static func default_anchor(size: Vector2i) -> Vector2i:
	return Vector2i((size.x - 1) / 2, (size.y - 1) / 2)

## An explicit anchor position, turned with the building. Local coordinates are
## written for the east-facing footprint.
static func rotate_local(local: Vector2i, size: Vector2i, dir: Vector2i) -> Vector2i:
	if dir == Vector2i.DOWN:
		return Vector2i(size.y - 1 - local.y, local.x)
	if dir == Vector2i.LEFT:
		return Vector2i(size.x - 1 - local.x, size.y - 1 - local.y)
	if dir == Vector2i.UP:
		return Vector2i(local.y, size.x - 1 - local.x)
	return local

## The cells a building covers, as a rectangle.
##
## Without an explicit `local` the anchor goes where `default_anchor` puts it in
## the *turned* footprint, so a square building covers the same cells whichever
## way it faces -- turning it changes where its output goes and nothing else,
## which is what R has always done.
static func footprint(anchor: Vector2i, size: Vector2i, dir: Vector2i = Vector2i.RIGHT,
		local: Vector2i = AUTO) -> Rect2i:
	var turned: Vector2i = rotated(size, dir)
	var at: Vector2i = default_anchor(turned) if local == AUTO else rotate_local(local, size, dir)
	return Rect2i(anchor - at, turned)

## Where a building's output goes: the cell just past its front edge, in line
## with the anchor. For a mining post that is the seam's own row, so what comes
## out comes out in line with what went in.
static func front_cell(rect: Rect2i, dir: Vector2i, anchor: Vector2i) -> Vector2i:
	if dir == Vector2i.LEFT:
		return Vector2i(rect.position.x - 1, anchor.y)
	if dir == Vector2i.DOWN:
		return Vector2i(anchor.x, rect.end.y)
	if dir == Vector2i.UP:
		return Vector2i(anchor.x, rect.position.y - 1)
	return Vector2i(rect.end.x, anchor.y)

## The cells touching a rectangle's four sides, corners excluded -- the places
## something can stand against it.
static func edge_cells(rect: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in range(rect.position.x, rect.end.x):
		out.append(Vector2i(x, rect.position.y - 1))
		out.append(Vector2i(x, rect.end.y))
	for y in range(rect.position.y, rect.end.y):
		out.append(Vector2i(rect.position.x - 1, y))
		out.append(Vector2i(rect.end.x, y))
	return out

## Chebyshev distance between two cells: how many king's steps apart they are.
static func steps(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

# --- What she can reach ----------------------------------------------------------

## The cells in front of someone standing at `point` and facing `facing`, nearest
## first.
##
## "The cell in front of her" was a tile across and a tile deep. A cell is half
## that now, and asking only the next cell would have halved every reach in the
## game -- the ice she walks up to, the fire, the seam. So the probe covers the
## same ground the old front cell did: `SCALE` cells deep and `SCALE` lanes wide,
## her own lane and the one on the side she is standing toward.
static func probe(point: Vector2, facing: Vector2i, depth: int = SCALE) -> Array[Vector2i]:
	var here: Vector2i = cell_at(point)
	var out: Array[Vector2i] = []
	if facing == Vector2i.ZERO:
		return out
	var side := Vector2i.ZERO
	if SCALE > 1:
		var offset: Vector2 = point - centre(here)
		if facing.x != 0:
			side = Vector2i(0, 1 if offset.y >= 0.0 else -1)
		else:
			side = Vector2i(1 if offset.x >= 0.0 else -1, 0)
	for k in range(1, depth + 1):
		out.append(here + facing * k)
		if side != Vector2i.ZERO:
			out.append(here + facing * k + side)
	return out

## A rectangle of `size` cells laid down in front of someone at `point` facing
## `facing`: its near edge is the next cell over, and across her line it covers
## her own lane, then the lane she is standing toward, then outward either side.
## This is where a building she is carrying or aiming goes -- the same ground
## `probe` reaches, grown to the building's size.
static func ahead(point: Vector2, facing: Vector2i, size: Vector2i) -> Rect2i:
	var here: Vector2i = cell_at(point)
	var offset: Vector2 = point - centre(here)
	if facing.x != 0:
		var top: int = here.y - _lead(size.y, offset.y)
		var left: int = here.x + 1 if facing.x > 0 else here.x - size.x
		return Rect2i(Vector2i(left, top), size)
	var start: int = here.x - _lead(size.x, offset.x)
	var near: int = here.y + 1 if facing.y > 0 else here.y - size.y
	return Rect2i(Vector2i(start, near), size)

## How many lanes of a span of `lanes` lie before hers: even spans lean toward
## the side she is standing on, odd ones centre on her.
static func _lead(lanes: int, offset: float) -> int:
	if lanes % 2 == 1:
		return (lanes - 1) / 2
	return lanes / 2 if offset < 0.0 else lanes / 2 - 1

## The tile-sized block of cells around a point, nearest first -- what "the
## ground she is standing on" was when a cell was a tile.
static func near_block(point: Vector2) -> Array[Vector2i]:
	var start := Vector2i((point / float(CELL) - Vector2.ONE * (float(SCALE - 1) * 0.5)).floor())
	var out: Array[Vector2i] = []
	for y in SCALE:
		for x in SCALE:
			out.append(start + Vector2i(x, y))
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return centre(a).distance_squared_to(point) < centre(b).distance_squared_to(point))
	return out
