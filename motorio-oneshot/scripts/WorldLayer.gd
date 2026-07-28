extends Node2D
class_name WorldLayer

## Draws terrain, the warmth pool and ore. Everything is culled to the camera
## rectangle so the cost is bound to the screen, not to the size of the map.

var sim: Sim
var view_rect := Rect2()
var night: float = 0.0        ## 0 = dusk, 1 = deep night
var pulse: float = 0.0

func _process(delta: float) -> void:
	pulse += delta
	queue_redraw()

func set_view(rect: Rect2) -> void:
	view_rect = rect

func _draw() -> void:
	if sim == null:
		return
	var tile := float(Defs.TILE)
	var core_px: Vector2 = Vector2(sim.core_cell) * tile + Vector2.ONE * tile * 0.5
	var warm_px: float = sim.warm_radius * tile

	# Ground. Two flat fills plus a radial warmth pool reads cleaner than a
	# noisy texture and keeps the palette disciplined.
	var cold := Defs.COL_SNOW_COLD.lerp(Defs.COL_VOID, night * 0.55)
	draw_rect(view_rect, cold)

	var rings := 26
	for index in range(rings, 0, -1):
		var f: float = float(index) / float(rings)
		var radius: float = warm_px * f
		var glow: float = pow(1.0 - f, 1.6)
		var warm := Defs.COL_SNOW_WARM.lerp(Defs.COL_CORE, glow * 0.30)
		warm = cold.lerp(warm, clampf(1.0 - f * 0.92, 0.0, 1.0))
		draw_circle(core_px, radius, Color(warm.r, warm.g, warm.b, 1.0))

	# The frontier line: the single most important readability element, because
	# it is the boundary between "my factory runs fast" and "everything slows".
	var edge_alpha: float = 0.55 + sin(pulse * 1.6) * 0.10
	draw_arc(core_px, warm_px, 0.0, TAU, 96, Color(Defs.COL_CORE.r, Defs.COL_CORE.g, Defs.COL_CORE.b, edge_alpha), 2.0, true)
	draw_arc(core_px, warm_px - 3.0, 0.0, TAU, 96, Color(1, 1, 1, 0.10), 4.0, true)

	_draw_grid(tile)
	_draw_ore(tile)

func _draw_grid(tile: float) -> void:
	var start := Vector2i((view_rect.position / tile).floor())
	var end := Vector2i((view_rect.end / tile).ceil())
	var grid := Color(Defs.COL_GRID.r, Defs.COL_GRID.g, Defs.COL_GRID.b, 0.20)
	for x in range(start.x, end.x + 1):
		var px: float = float(x) * tile
		draw_line(Vector2(px, view_rect.position.y), Vector2(px, view_rect.end.y), grid, 1.0)
	for y in range(start.y, end.y + 1):
		var py: float = float(y) * tile
		draw_line(Vector2(view_rect.position.x, py), Vector2(view_rect.end.x, py), grid, 1.0)

func _draw_ore(tile: float) -> void:
	for cell: Vector2i in sim.ore:
		var px: Vector2 = Vector2(cell) * tile
		if not view_rect.has_point(px + Vector2.ONE * tile * 0.5):
			continue
		var item_type: int = sim.ore[cell]
		var base: Color = Defs.ITEM_COLORS[item_type]
		var centre: Vector2 = px + Vector2.ONE * tile * 0.5
		var warm: bool = sim.is_warm(cell)
		var tint: Color = base if warm else base.lerp(Defs.COL_SNOW_COLD, 0.45)

		draw_circle(centre + Vector2(0, 3), 11.0, Color(0.02, 0.04, 0.08, 0.30))
		# Faceted crystal: three shards give a readable silhouette at 32px.
		var shard := PackedVector2Array([
			centre + Vector2(-9, 6), centre + Vector2(-4, -8),
			centre + Vector2(2, -3), centre + Vector2(0, 8)])
		draw_colored_polygon(shard, tint.darkened(0.28))
		var shard2 := PackedVector2Array([
			centre + Vector2(0, 8), centre + Vector2(3, -6),
			centre + Vector2(9, 1), centre + Vector2(7, 8)])
		draw_colored_polygon(shard2, tint)
		draw_line(centre + Vector2(-4, -7), centre + Vector2(-1, 2), tint.lightened(0.5), 1.5)
		if warm:
			draw_circle(centre + Vector2(3, -3), 1.8, Color(1, 1, 1, 0.55))
