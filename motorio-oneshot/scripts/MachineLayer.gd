extends Node2D
class_name MachineLayer

## Draws machines, the items flowing between them, and the build preview.

## Carried over from Motorio: a 2x2 directional sheet, one frame per facing.
const CAT_SHEET: Texture2D = preload("res://assets/characters/worker_cat_directional.png")
const CAT_FRAME := 627.0
const CAT_DRAW := 44.0

var sim: Sim
var view_rect := Rect2()
var preview_type: int = Defs.M_MINER
var preview_cell := Vector2i.ZERO
var preview_dir := Vector2i.RIGHT
var preview_valid := true
var preview_affordable := true
var show_preview := true
var preview_occupied := false
var pulse: float = 0.0
var night: float = 0.0

var _repaint := 0.0

func _process(delta: float) -> void:
	pulse += delta
	_repaint += delta
	if _repaint < 1.0 / 30.0:
		return
	_repaint = 0.0
	queue_redraw()

func _draw() -> void:
	if sim == null:
		return
	var tile := float(Defs.TILE)
	# Belts first so machines and items always sit above them.
	for cell: Vector2i in sim.machines:
		var machine: Sim.Machine = sim.machines[cell]
		if machine.type != Defs.M_BELT:
			continue
		if not _visible(cell, tile):
			continue
		_draw_belt(machine, Vector2(cell) * tile, tile)
	for cell: Vector2i in sim.machines:
		var machine: Sim.Machine = sim.machines[cell]
		if machine.type == Defs.M_BELT:
			continue
		if not _visible(cell, tile):
			continue
		match machine.type:
			Defs.M_CORE: _draw_core(machine, Vector2(cell) * tile, tile)
			Defs.M_MINER: _draw_miner(machine, Vector2(cell) * tile, tile)
			Defs.M_FURNACE: _draw_furnace(machine, Vector2(cell) * tile, tile)
	for cell: Vector2i in sim.machines:
		var machine: Sim.Machine = sim.machines[cell]
		if machine.type != Defs.M_BELT or not _visible(cell, tile):
			continue
		_draw_belt_items(machine, Vector2(cell) * tile, tile)
	_draw_shelter(tile)
	if show_preview:
		_draw_preview(tile)

## A hut beside the core: the destination the night pushes you toward.
func _draw_shelter(tile: float) -> void:
	var at: Vector2 = Vector2(sim.core_cell) * tile + Defs.SHELTER_OFFSET * tile + Vector2.ONE * tile * 0.5
	var lit: float = 0.35 + night * 0.65
	draw_circle(at + Vector2(0, 12), 15.0, Color(0.02, 0.04, 0.08, 0.34))
	draw_circle(at, 17.0, Color(1.0, 0.62, 0.24, 0.10 + night * 0.22))
	# Timber hut with a lit doorway that grows brighter as the night comes in.
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(-16, 2), at + Vector2(0, -15), at + Vector2(16, 2)]), Color8(96, 58, 44))
	draw_rect(Rect2(at.x - 13, at.y + 1, 26, 14), Color8(74, 46, 36))
	draw_rect(Rect2(at.x - 5, at.y + 4, 10, 11), Color(1.0, 0.72, 0.34, lit))
	draw_rect(Rect2(at.x - 16, at.y - 1, 32, 3), Defs.COL_BELT_RIM.darkened(0.25))
	var font := UIFont.FONT
	draw_string(font, at + Vector2(-20, 30), "숙소", HORIZONTAL_ALIGNMENT_CENTER, 40.0, 10,
		Color(Defs.COL_BELT_RIM.r, Defs.COL_BELT_RIM.g, Defs.COL_BELT_RIM.b, 0.55 + night * 0.4))

func _visible(cell: Vector2i, tile: float) -> bool:
	return view_rect.grow(tile * 2.0).has_point(Vector2(cell) * tile + Vector2.ONE * tile * 0.5)

func _frost(machine: Sim.Machine) -> float:
	return 0.0 if sim.is_warm(machine.cell) else 0.45

func _draw_core(machine: Sim.Machine, px: Vector2, tile: float) -> void:
	var c: Vector2 = px + Vector2.ONE * tile * 0.5
	var beat: float = 1.0 + sin(pulse * 2.2) * 0.05 + machine.flash * 0.5
	# The core is the emotional centre of the run, so it is drawn large enough to
	# outrank the HUD clock in the visual hierarchy.
	draw_circle(c, 52.0 * beat, Color(1.0, 0.67, 0.31, 0.10))
	draw_circle(c, 38.0 * beat, Color(1.0, 0.67, 0.31, 0.16))
	draw_circle(c, 30.0, Defs.COL_MACHINE.darkened(0.4))
	draw_circle(c, 26.0, Defs.COL_CORE_DEEP)
	draw_circle(c, 18.0 * beat, Defs.COL_CORE)
	draw_circle(c, 10.0 * beat, Color("fff0c9"))
	for index in 10:
		var angle: float = TAU * float(index) / 10.0 + pulse * 0.25
		draw_circle(c + Vector2.from_angle(angle) * 33.0, 2.6, Defs.COL_BRASS)
	draw_arc(c, 44.0, 0.0, TAU, 64, Color(1.0, 0.69, 0.36, 0.30 + machine.flash), 2.0, true)

## One arrow shape used by previews and by placed machines, so "which way does
## this face" is answered the same way everywhere.
func _draw_arrow(from: Vector2, dir: Vector2i, length: float, col: Color, width: float = 3.0) -> void:
	var d := Vector2(dir)
	var perp := Vector2(-d.y, d.x)
	var tip: Vector2 = from + d * length
	draw_line(from, tip - d * 5.0, col, width)
	draw_colored_polygon(PackedVector2Array([
		tip, tip - d * 7.0 + perp * 4.5, tip - d * 7.0 - perp * 4.5]), col)

const CAT_VIEW_FRAME := {"front": 0, "back": 1, "left": 2, "right": 3}

func _cat_region(view: String) -> Rect2:
	var index: int = int(CAT_VIEW_FRAME.get(view, 0))
	return Rect2(Vector2(float(index % 2) * CAT_FRAME, float(index / 2) * CAT_FRAME),
		Vector2(CAT_FRAME, CAT_FRAME))

func _draw_miner(machine: Sim.Machine, px: Vector2, tile: float) -> void:
	var c: Vector2 = px + Vector2.ONE * tile * 0.5
	var frost: float = _frost(machine)
	var work: float = clampf(machine.progress / Defs.MINER_PERIOD, 0.0, 1.0)
	# A small breathing squash keeps the worker alive without swapping frames.
	var breathe: float = 1.0 + sin(pulse * 2.6 + float(machine.cell.x)) * 0.02
	var dig: float = sin(pulse * 9.0) * 1.4 * (1.0 - frost)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2(c.x, (c.y + 11.0) / 0.45), 9.0, Color(0.02, 0.04, 0.08, 0.34))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Eight facings from four drawn views: diagonals borrow the front or back view
	# and lean, so north-east and north-west are told apart.
	var facing: int = Defs.facing_index(Vector2(machine.dir))
	var view: Dictionary = Defs.facing_view(facing)
	var lean: float = float(view["lean"])
	var flip: bool = bool(view["flip"])
	var size := Vector2(CAT_DRAW / breathe, CAT_DRAW * breathe)
	if flip:
		size.x = -size.x
	var target := Rect2(c - Vector2(absf(size.x), size.y) * 0.5 + Vector2(lean * 3.0, dig - 3.0), size)
	if flip:
		target.position.x += absf(size.x)
	# Frozen workers desaturate toward the cold instead of being recoloured.
	var tint: Color = Color.WHITE.lerp(Color(0.62, 0.72, 0.95), frost)
	draw_set_transform(c + Vector2(lean * 3.0, 0.0), lean * 0.10, Vector2.ONE)
	draw_texture_rect_region(CAT_SHEET,
		Rect2(target.position - c - Vector2(lean * 3.0, 0.0), target.size),
		_cat_region(String(view["view"])), tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Output direction and a progress arc, so throughput is legible at a glance.
	_draw_arrow(c + Vector2(machine.dir) * 15.0, machine.dir, 10.0, Defs.COL_BELT_RIM, 2.5)
	draw_arc(c, 15.0, -PI * 0.5, -PI * 0.5 + TAU * work, 22, Color(1, 1, 1, 0.42), 2.0, true)
	if machine.flash > 0.0:
		draw_circle(c, 17.0 + machine.flash * 12.0, Color(1, 1, 1, machine.flash * 0.5), false, 2.0)
	_draw_stall(machine, c)

func _draw_furnace(machine: Sim.Machine, px: Vector2, tile: float) -> void:
	var c: Vector2 = px + Vector2.ONE * tile * 0.5
	var frost: float = _frost(machine)
	var body: Color = Color8(64, 76, 90).lerp(Color8(44, 52, 62), frost)
	var ready: bool = int(machine.buffer.get(Defs.ITEM_FROST, 0)) > 0 and int(machine.buffer.get(Defs.ITEM_EMBER, 0)) > 0
	var glow: float = (0.45 + sin(pulse * 6.0) * 0.25) if ready else 0.12

	draw_circle(c + Vector2(0, 9), 11.0, Color(0.02, 0.04, 0.08, 0.32))
	draw_rect(Rect2(c.x - 14, c.y - 14, 28, 28), Defs.ORE_OUTLINE)
	draw_rect(Rect2(c.x - 12, c.y - 12, 24, 24), body.darkened(0.4))
	draw_rect(Rect2(c.x - 10, c.y - 10, 20, 20), body)
	draw_rect(Rect2(c.x - 6, c.y - 4, 12, 10), Color(1.0, 0.55, 0.2, glow))
	draw_rect(Rect2(c.x - 10, c.y - 12, 20, 3), Defs.COL_BELT_RIM.lerp(body, frost * 0.7))
	var tip: Vector2 = c + Vector2(machine.dir) * 15.0
	draw_circle(tip, 2.6, Defs.COL_BRASS)
	_draw_stall(machine, c)
	# Two input pips tell the player exactly what the recipe is still missing.
	_draw_pip(c + Vector2(-6, 12), Defs.ITEM_FROST, int(machine.buffer.get(Defs.ITEM_FROST, 0)))
	_draw_pip(c + Vector2(6, 12), Defs.ITEM_EMBER, int(machine.buffer.get(Defs.ITEM_EMBER, 0)))
	if machine.flash > 0.0:
		draw_circle(c, 16.0 + machine.flash * 14.0, Color(1, 0.9, 0.7, machine.flash * 0.55), false, 2.0)

## A backed-up machine is the single most common way a factory silently stops
## paying. It gets an unmissable pulsing marker rather than nothing at all.
func _draw_stall(machine: Sim.Machine, c: Vector2) -> void:
	if not machine.stalled:
		return
	var beat: float = 0.55 + sin(pulse * 5.0) * 0.45
	var at: Vector2 = c + Vector2(0, -18)
	draw_circle(at, 7.0, Color(0.06, 0.08, 0.12, 0.85))
	draw_circle(at, 6.0, Color(Defs.COL_DANGER.r, Defs.COL_DANGER.g, Defs.COL_DANGER.b, 0.45 + beat * 0.5))
	draw_rect(Rect2(at.x - 1.0, at.y - 3.5, 2.0, 4.5), Color(1, 1, 1, 0.9))
	draw_rect(Rect2(at.x - 1.0, at.y + 2.0, 2.0, 2.0), Color(1, 1, 1, 0.9))

func _draw_pip(at: Vector2, item_type: int, count: int) -> void:
	var col: Color = Defs.ITEM_COLORS[item_type]
	draw_circle(at, 3.4, Color(0.05, 0.07, 0.11, 0.85))
	if count > 0:
		draw_circle(at, 2.4, col)
	else:
		draw_arc(at, 2.4, 0.0, TAU, 10, Color(col.r, col.g, col.b, 0.35), 1.0)

func _draw_belt(machine: Sim.Machine, px: Vector2, tile: float) -> void:
	var c: Vector2 = px + Vector2.ONE * tile * 0.5
	var frost: float = _frost(machine)
	var body: Color = Defs.COL_BELT_BODY if frost <= 0.0 else Defs.COL_BELT_BODY_COLD
	# Glow first so it reads as light spilling out from under the machine.
	draw_circle(c, 19.0, Color(Defs.COL_BELT_GLOW.r, Defs.COL_BELT_GLOW.g, Defs.COL_BELT_GLOW.b,
		0.30 * (1.0 - frost) + 0.05))
	draw_rect(Rect2(px.x + 1, px.y + 1, tile - 2, tile - 2), Defs.ORE_OUTLINE)
	draw_rect(Rect2(px.x + 2, px.y + 2, tile - 4, tile - 4), body)
	# The rim must be lighter than the pool it sits in, or it disappears into it.
	var rim: Color = Defs.COL_BELT_RIM if frost <= 0.0 else Defs.COL_BELT_RIM.lerp(body, 0.6)
	draw_rect(Rect2(px.x + 2, px.y + 2, tile - 4, 2.5), rim)
	draw_rect(Rect2(px.x + 2, px.y + 2, 2.5, tile - 4), Color(rim.r, rim.g, rim.b, 0.6))
	var dir := Vector2(machine.dir)
	var perp := Vector2(-dir.y, dir.x)
	# Scrolling chevrons: the cheapest possible "this is moving" signal.
	for index in 2:
		var offset: float = fmod(pulse * Defs.BELT_SPEED * 0.5 + float(index) * 0.5, 1.0)
		var along: float = (offset - 0.5) * tile
		var head: Vector2 = c + dir * (along + 5.0)
		var tail: Vector2 = c + dir * (along - 2.0)
		var chev: Color = Defs.COL_BELT_CHEVRON if frost <= 0.0 else Defs.COL_FROZEN_CHEVRON
		draw_line(tail + perp * 5.0, head, chev, 2.0)
		draw_line(tail - perp * 5.0, head, chev, 2.0)
	_draw_stall(machine, c)

func _draw_belt_items(machine: Sim.Machine, px: Vector2, tile: float) -> void:
	var c: Vector2 = px + Vector2.ONE * tile * 0.5
	var dir := Vector2(machine.dir)
	for item: Dictionary in machine.items:
		var t: float = float(item["t"])
		var at: Vector2 = c + dir * (t - 0.5) * tile
		var col: Color = Defs.ITEM_COLORS[int(item["type"])]
		# Payloads were too small to see, so a working line looked identical to a
		# broken one. These are deliberately chunky with a dark outline.
		draw_circle(at + Vector2(0, 2), 7.0, Color(0.02, 0.04, 0.08, 0.4))
		draw_circle(at, 6.6, Defs.ORE_OUTLINE)
		draw_circle(at, 5.2, col.darkened(0.3))
		draw_circle(at, 3.8, col)
		draw_circle(at + Vector2(-1.4, -1.4), 1.6, Color(1, 1, 1, 0.7))

func _draw_preview(tile: float) -> void:
	var px: Vector2 = Vector2(preview_cell) * tile
	# A tile that already holds a machine is not an error, it is a reclaim target.
	# Stamping a red box over the player's own building hid the machine and read
	# as a fault.
	if preview_occupied:
		var mark := Color(Defs.COL_TEXT.r, Defs.COL_TEXT.g, Defs.COL_TEXT.b, 0.5 + sin(pulse * 4.0) * 0.12)
		for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
			var origin: Vector2 = px + Vector2(corner.x * (tile - 1.0), corner.y * (tile - 1.0))
			var dx: float = -7.0 if corner.x > 0.0 else 7.0
			var dy: float = -7.0 if corner.y > 0.0 else 7.0
			draw_line(origin, origin + Vector2(dx, 0), mark, 2.0)
			draw_line(origin, origin + Vector2(0, dy), mark, 2.0)
		return
	# Three explicit states. A ghost that is always red teaches nothing.
	var col: Color = Defs.COL_VALID if preview_valid else (
		Color8(150, 160, 180) if not preview_affordable else Defs.COL_DANGER)
	var alpha: float = 0.55 + sin(pulse * 5.0) * 0.12
	draw_rect(Rect2(px.x + 1, px.y + 1, tile - 2, tile - 2), Color(col.r, col.g, col.b, 0.16))
	draw_rect(Rect2(px.x + 1, px.y + 1, tile - 2, tile - 2), Color(col.r, col.g, col.b, alpha), false, 2.0)
	# Direction is the most-missed piece of information when placing: R changes it
	# invisibly unless the preview states it outright.
	var c: Vector2 = px + Vector2.ONE * tile * 0.5
	var arrow := Color(col.r, col.g, col.b, minf(1.0, alpha + 0.3))
	var dir := Vector2(preview_dir)
	draw_circle(c - dir * 12.0, 3.0, Color(arrow.r, arrow.g, arrow.b, 0.55))
	_draw_arrow(c - dir * 6.0, preview_dir, 22.0, arrow, 3.0)
	var font := UIFont.FONT
	draw_string(font, c + dir * 20.0 + Vector2(-14.0, -12.0), "OUT", HORIZONTAL_ALIGNMENT_CENTER, 28.0, 9,
		Color(arrow.r, arrow.g, arrow.b, 0.9))
