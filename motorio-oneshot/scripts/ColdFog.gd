extends Node2D
class_name ColdFog

## World-space fog hiding everything outside the warm radius, carried over from
## Motorio. Two lessons from that project are baked in: the ring just past the
## frontier stays readable so the next ore field is visible and worth walking to,
## and the fog is never dense enough to make exploration impossible.

const PREVIEW_BAND := 9.0
## Heavy overlap: at low alpha, sparse puffs read as separate bubbles rather
## than as weather. Radius well above spacing is what makes it merge.
const PUFF_SPACING := 1.7
const PUFF_RADIUS := 2.9

var sim: Sim
var view_rect := Rect2()
var night: float = 0.0

func _process(_delta: float) -> void:
	queue_redraw()

## 0 at the warm edge, 1 once past the preview band.
func fog_strength(distance_tiles: float) -> float:
	if sim == null:
		return 0.0
	var beyond: float = distance_tiles - sim.warm_radius
	if beyond <= 0.0:
		return 0.0
	return clampf(beyond / PREVIEW_BAND, 0.0, 1.0)

func fog_alpha_for_cell(cell: Vector2i) -> float:
	if sim == null:
		return 0.0
	var strength: float = fog_strength(Vector2(cell - sim.core_cell).length())
	if strength <= 0.0:
		return 0.0
	return 0.16 + strength * 0.72

func _draw() -> void:
	if sim == null:
		return
	var tile := float(Defs.TILE)
	var core_px: Vector2 = Vector2(sim.core_cell) * tile + Vector2.ONE * tile * 0.5
	var warm_px: float = sim.warm_radius * tile
	var spacing: float = tile * PUFF_SPACING
	var radius: float = tile * PUFF_RADIUS
	# Overlapping puffs rather than rows: rectangular banding was the giveaway
	# that made the original look like a mask instead of weather.
	var start := Vector2i(((view_rect.position - Vector2.ONE * spacing) / spacing).floor())
	var end := Vector2i(((view_rect.end + Vector2.ONE * spacing) / spacing).ceil())
	var fog: Color = Color(0.94, 0.975, 1.0).lerp(Color(0.62, 0.70, 0.85), night * 0.5)
	for gy in range(start.y, end.y + 1):
		for gx in range(start.x, end.x + 1):
			var wobble := Vector2(sin(float(gy * 7 + gx)) * 18.0, cos(float(gx * 5 - gy)) * 14.0)
			var at := Vector2(float(gx) * spacing, float(gy) * spacing) + wobble
			var distance: float = at.distance_to(core_px)
			if distance <= warm_px + radius * 0.42:
				continue
			var strength: float = fog_strength(distance / tile)
			draw_circle(at, radius, Color(fog.r, fog.g, fog.b, 0.07 + strength * 0.30))
	# A soft scalloped bank marks the frontier itself.
	var puffs: int = maxi(28, int(TAU * warm_px / (tile * 1.6)))
	for index in puffs:
		var angle: float = TAU * float(index) / float(puffs)
		var jitter: float = sin(float(index) * 2.17) * 9.0 + cos(float(index) * 0.73) * 6.0
		var at: Vector2 = core_px + Vector2.from_angle(angle) * (warm_px + tile * 1.1 + jitter)
		var size: float = tile * (1.2 + 0.2 * sin(float(index) * 1.91))
		draw_circle(at, size * 1.3, Color(fog.r, fog.g, fog.b, 0.16))
		draw_circle(at, size, Color(fog.r, fog.g, fog.b, 0.5))
