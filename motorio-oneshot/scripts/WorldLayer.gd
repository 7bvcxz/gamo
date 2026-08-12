extends Node2D
class_name WorldLayer

## Draws terrain, the warmth pool and ore. Everything is culled to the camera
## rectangle so the cost is bound to the screen, not to the size of the map.

var sim: Sim
var view_rect := Rect2()
var night: float = 0.0        ## 0 = dusk, 1 = deep night
var pulse: float = 0.0

var _repaint := 0.0

func _process(delta: float) -> void:
	pulse += delta
	_repaint += delta
	if _repaint >= 1.0 / 24.0:
		_repaint = 0.0
		queue_redraw()

func set_view(rect: Rect2) -> void:
	view_rect = rect

func _draw() -> void:
	if sim == null:
		return
	var tile := float(Defs.TILE)
	var core_px: Vector2 = Vector2(sim.core_cell) * tile + Vector2.ONE * tile * 0.5
	var warm_px: float = sim.warm_radius * tile

	# Ground and warm pool are drawn by GroundLayer beneath this one; here we
	# only add what animates: the frontier, the grid and the ore.
	var edge_alpha: float = 0.85 + sin(pulse * 1.6) * 0.10
	draw_arc(core_px, warm_px - 5.0, 0.0, TAU, 48, Color(1.0, 0.69, 0.36, 0.22), 10.0, false)
	draw_arc(core_px, warm_px, 0.0, TAU, 72, Color(1.0, 0.69, 0.36, edge_alpha), 3.0, true)

	# The grid used to be drawn here as faint lines. The ground is painted tiles
	# now, one per cell, and each carries its own outline at exactly this pitch --
	# so the lines landed on top of the tile edges and the floor read as two grids
	# fighting, one soft and one ruled. What the lines were for, judging alignment
	# when a player stops to look, is what the tile edges do.
	_draw_ore(tile)

func _draw_ore(tile: float) -> void:
	for cell: Vector2i in sim.ore:
		var px: Vector2 = Vector2(cell) * tile
		if not view_rect.has_point(px + Vector2.ONE * tile * 0.5):
			continue
		var item_type: int = sim.ore[cell]
		var base: Color = Defs.ITEM_COLORS[item_type]
		var centre: Vector2 = px + Vector2.ONE * tile * 0.5
		var warm: bool = sim.is_warm(cell)
		var tint: Color = base if warm else base.lerp(Defs.COL_SNOW_COLD, 0.18)

		# Crystal is a floor tile now, drawn by GroundLayer with the rest of the
		# terrain, so only what the tile cannot say is drawn here: how rich the
		# seam is, and the glint that pulls the eye to one the player cannot
		# reach yet. Copper has no sheet and still gets the painted shard.
		if item_type != Defs.ITEM_CRYSTAL:
			_draw_shard(centre, tint, item_type, warm)
		else:
			_draw_sparkle(cell, centre, tint)
		_draw_purity(cell, centre, tint)
		if not warm:
			# A slow glint pulls the eye toward ore the player cannot reach yet.
			var glint: float = maxf(0.0, sin(pulse * 0.8 + float(cell.x + cell.y)))
			if glint > 0.9:
				draw_circle(centre + Vector2(-3, -5), 2.4, Color(1, 1, 1, (glint - 0.9) * 5.0))

func _draw_shard(centre: Vector2, tint: Color, item_type: int, warm: bool) -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, Defs.SHADOW_SQUASH))
		draw_circle(Vector2(centre.x, (centre.y + 8.0) / Defs.SHADOW_SQUASH), 10.0, Defs.SHADOW)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# A dark outline keeps the silhouette on both the amber ground and the
		# night, so ore never depends on the terrain for contrast.
		var outline := PackedVector2Array([
			centre + Vector2(-10, 7), centre + Vector2(-5, -9),
			centre + Vector2(4, -8), centre + Vector2(10, 2), centre + Vector2(8, 9)])
		draw_colored_polygon(outline, Defs.OUTLINE)
		var shard := PackedVector2Array([
			centre + Vector2(-9, 6), centre + Vector2(-4, -8),
			centre + Vector2(2, -3), centre + Vector2(0, 8)])
		draw_colored_polygon(shard, tint.darkened(0.28))
		var shard2 := PackedVector2Array([
			centre + Vector2(0, 8), centre + Vector2(3, -6),
			centre + Vector2(9, 1), centre + Vector2(7, 8)])
		draw_colored_polygon(shard2, tint)
		draw_line(centre + Vector2(-4, -7), centre + Vector2(-1, 2), tint.lightened(0.5), 1.5)
		# A bright inner core keeps ore readable on the amber pool as well as the
		# night; ember previously shared a hue band with the warm ground.
		if item_type == Defs.ITEM_COPPER:
			draw_circle(centre + Vector2(1, -1), 3.0, Defs.COPPER_CORE)
		draw_circle(centre + Vector2(3, -3), 1.8, Color(1, 1, 1, 0.7 if warm else 0.5))

## A slow catch of light in the middle of a seam.
##
## The tile is a still picture and a crystal that never moves reads as a stain on
## the floor, so the one thing it cannot do for itself is done here. Offset by
## the cell rather than shared, or a field of seams blinks in unison and stops
## looking like light and starts looking like a warning.
func _draw_sparkle(cell: Vector2i, centre: Vector2, tint: Color) -> void:
	var phase: float = pulse * 1.3 + float(cell.x) * 1.7 + float(cell.y) * 2.9
	var wave: float = sin(phase)
	if wave <= 0.0:
		return
	var strength: float = wave * wave        # squared, so it is dark most of the time
	draw_circle(centre, 3.0 + strength * 3.5, Color(1, 1, 1, 0.10 * strength))
	draw_circle(centre, 1.6 + strength * 1.4,
		Color(1, 1, 1, 0.30 * strength).lerp(tint.lightened(0.6), 0.35))

## Richness is drawn, not just tracked: extra shards and a brighter heart, so
## "that one is worth the walk" is readable from across the plateau. It sits over
## whichever way the seam itself is drawn, because purity is a number about the
## cell rather than a thing in the picture.
func _draw_purity(cell: Vector2i, centre: Vector2, tint: Color) -> void:
	var grade: int = sim.purity_of(cell)
	if grade <= 0:
		return
	for index in grade:
		var angle: float = -1.1 + float(index) * 0.9
		draw_circle(centre + Vector2.from_angle(angle) * 9.0, 2.2, tint.lightened(0.35))
		draw_circle(centre + Vector2.from_angle(angle) * 9.0, 2.2, Defs.OUTLINE, false, 1.0)
	draw_circle(centre, 2.0 + float(grade) * 0.8,
		Color(1, 1, 1, 0.35 + float(grade) * 0.2))
