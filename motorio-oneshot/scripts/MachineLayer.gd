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
			Defs.M_EXCHANGER: _draw_furnace(machine, Vector2(cell) * tile, tile)
			Defs.M_GENERATOR: _draw_generator(machine, Vector2(cell) * tile, tile)
	for cell: Vector2i in sim.machines:
		var machine: Sim.Machine = sim.machines[cell]
		if machine.type != Defs.M_BELT or not _visible(cell, tile):
			continue
		_draw_belt_items(machine, Vector2(cell) * tile, tile)
	_draw_shelter(tile)
	_draw_food_bin(tile)
	_draw_boxes(tile)
	_draw_ground()
	_draw_cats()
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
	var body: Color = Color8(74, 86, 100).lerp(Color8(48, 56, 68), frost)

	draw_circle(c + Vector2(0, 11), 10.0, Color(0.02, 0.04, 0.08, 0.34))
	draw_rect(Rect2(c.x - 13, c.y - 13, 26, 26), Defs.ORE_OUTLINE)
	draw_rect(Rect2(c.x - 11, c.y - 11, 22, 22), body)
	draw_rect(Rect2(c.x - 11, c.y - 11, 22, 2.5), Defs.COL_BELT_RIM.lerp(body, frost))
	# A drill head that only turns while a cat is operating it.
	var spin: float = pulse * (5.0 if machine.operated else 0.0)
	for index in 3:
		var angle: float = spin + TAU * float(index) / 3.0
		draw_line(c, c + Vector2.from_angle(angle) * 7.0,
			Defs.COL_BELT_CHEVRON if machine.operated else Color8(120, 132, 148), 2.0)
	_draw_arrow(c + Vector2(machine.dir) * 15.0, machine.dir, 10.0, Defs.COL_BELT_RIM, 2.5)
	if machine.operated:
		draw_arc(c, 15.0, -PI * 0.5, -PI * 0.5 + TAU * work, 22, Color(1, 1, 1, 0.42), 2.0, true)
	else:
		# Idle machines say so plainly: this is the most common reason a new
		# player sees no output at all.
		var blink: float = 0.45 + sin(pulse * 3.0) * 0.3
		draw_arc(c, 15.0, 0.0, TAU, 28, Color(0.75, 0.78, 0.85, blink), 1.5, true)
	if machine.flash > 0.0:
		draw_circle(c, 17.0 + machine.flash * 12.0, Color(1, 1, 1, machine.flash * 0.5), false, 2.0)
	_draw_stall(machine, c)

## Loose items on the floor. Small, lit and slowly bobbing, so a dropped shard
## reads as "come and get me" rather than as scenery.
func _draw_ground() -> void:
	var tile := float(Defs.TILE)
	for cell: Vector2i in sim.ground:
		if not _visible(cell, tile):
			continue
		var item_type: int = int(sim.ground[cell])
		var at: Vector2 = Vector2(cell) * tile + Vector2.ONE * tile * 0.5
		var bob: float = sin(pulse * 3.0 + float(cell.x + cell.y)) * 1.6
		var colour: Color = Defs.ITEM_COLORS[item_type]
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2(at.x, (at.y + 7.0) / 0.45), 5.0, Color(0.02, 0.04, 0.08, 0.30))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_circle(at + Vector2(0, bob), 7.0, Color(colour.r, colour.g, colour.b, 0.28))
		draw_circle(at + Vector2(0, bob), 4.2, colour)
		draw_circle(at + Vector2(0, bob), 4.2, Defs.ORE_OUTLINE, false, 1.0)

## A generator reads as a lit drum: the glow is tied to whether it is actually
## supplying, so an unfuelled one is visibly dark rather than silently idle.
func _draw_generator(machine: Sim.Machine, px: Vector2, tile: float) -> void:
	var body := Rect2(px + Vector2(4, 4), Vector2(tile - 8.0, tile - 8.0))
	var live: bool = machine.operated
	draw_rect(body, Defs.COL_BELT_BODY)
	draw_rect(body, Defs.machine_color(Defs.M_GENERATOR), false, 2.0)
	var centre: Vector2 = px + Vector2.ONE * tile * 0.5
	var beat: float = 0.6 + sin(pulse * 4.0) * 0.25 if live else 0.18
	draw_circle(centre, tile * 0.22, Color(0.47, 0.75, 0.92, beat))
	draw_circle(centre, tile * 0.11, Color(0.85, 0.96, 1.0, beat))
	var fuel: int = int(machine.buffer.get(Defs.ITEM_ENERGY, 0))
	for index in fuel:
		draw_circle(px + Vector2(6.0 + float(index) * 6.0, tile - 5.0), 2.0,
			Defs.ITEM_COLORS[Defs.ITEM_ENERGY])

## Cats are agents, not tiles: they walk between the shelter, their machine and
## the food bin, so they are drawn from their own positions.
func _draw_cats() -> void:
	for cat: Sim.Cat in sim.cats:
		if cat == sim.carried_cat:
			continue      # drawn in the player's arms by PlayerActor
		if not view_rect.grow(64.0).has_point(cat.pos):
			continue
		var breathe: float = 1.0 + sin(pulse * 2.6 + cat.pos.x * 0.05) * 0.02
		# Eating gets its own motion: a quick repeated dip toward the bowl, so a
		# feeding cat is obviously busy rather than idle.
		var munch: float = 0.0
		if cat.state == Defs.CAT_EATING:
			munch = absf(sin(pulse * 7.0)) * 4.0
			breathe = 1.0 + sin(pulse * 7.0) * 0.05
		var heading: Vector2 = Vector2.DOWN
		if cat.state == Defs.CAT_TO_MINER and sim.machines.has(cat.assigned):
			heading = sim.cell_centre(cat.assigned) - cat.pos
		elif cat.state == Defs.CAT_TO_FOOD:
			heading = sim.cell_centre(sim.food_cell) - cat.pos
		elif cat.state == Defs.CAT_EATING:
			heading = Vector2.DOWN
		var view: Dictionary = Defs.facing_view(Defs.facing_index(heading))
		var size := Vector2(CAT_DRAW / breathe, CAT_DRAW * breathe)
		if bool(view["flip"]):
			size.x = -size.x
		var target := Rect2(cat.pos - Vector2(absf(size.x), size.y) * 0.5 + Vector2(0, -4 + munch), size)
		if bool(view["flip"]):
			target.position.x += absf(size.x)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2(cat.pos.x, (cat.pos.y + 10.0) / 0.45), 8.0, Color(0.02, 0.04, 0.08, 0.32))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_texture_rect_region(CAT_SHEET, target, _cat_region(String(view["view"])), Color.WHITE)
		if cat.carrying >= 0:
			# What the cat is carrying rides above its head, so a line of hauling
			# cats reads as a slow, visible conveyor.
			var load_colour: Color = Defs.ITEM_COLORS[cat.carrying]
			draw_circle(cat.pos + Vector2(0, -22), 5.0, Color(load_colour.r, load_colour.g, load_colour.b, 0.30))
			draw_circle(cat.pos + Vector2(0, -22), 3.2, load_colour)
		if cat.state == Defs.CAT_EATING:
			# Crumbs kicking up from the bowl.
			for crumb in 3:
				var phase: float = fmod(pulse * 2.2 + float(crumb) * 0.33, 1.0)
				var at: Vector2 = cat.pos + Vector2(sin(float(crumb) * 2.1) * 9.0, 6.0 - phase * 9.0)
				draw_circle(at, 1.6 * (1.0 - phase), Color(0.95, 0.82, 0.55, 1.0 - phase))
		# Hunger only appears once it matters, so a healthy crew stays clean.
		if cat.hunger < 0.5:
			var bar := Rect2(cat.pos.x - 11, cat.pos.y - 26, 22, 3)
			draw_rect(bar, Color(0.06, 0.08, 0.12, 0.85))
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * cat.hunger, bar.size.y)),
				Defs.COL_DANGER if cat.hunger <= 0.0 else Defs.COL_BELT_RIM)

## Crates lying in the snow, and the food bin beside the shelter.
func _draw_boxes(tile: float) -> void:
	for cell: Vector2i in sim.cat_boxes:
		var at: Vector2 = Vector2(cell) * tile + Vector2.ONE * tile * 0.5
		if not view_rect.grow(tile).has_point(at):
			continue
		draw_circle(at + Vector2(0, 9), 8.0, Color(0.02, 0.04, 0.08, 0.30))
		draw_rect(Rect2(at.x - 10, at.y - 8, 20, 17), Defs.ORE_OUTLINE)
		draw_rect(Rect2(at.x - 8, at.y - 6, 16, 13), Color8(146, 102, 62))
		draw_rect(Rect2(at.x - 8, at.y - 1, 16, 3), Color8(196, 146, 92))
		draw_circle(at + Vector2(0, -2), 2.6, Defs.COL_CAT_FACE)

func _draw_food_bin(tile: float) -> void:
	var at: Vector2 = Vector2(sim.food_cell) * tile + Vector2.ONE * tile * 0.5
	draw_circle(at + Vector2(0, 10), 10.0, Color(0.02, 0.04, 0.08, 0.30))
	draw_rect(Rect2(at.x - 12, at.y - 9, 24, 19), Defs.ORE_OUTLINE)
	draw_rect(Rect2(at.x - 10, at.y - 7, 20, 15), Color8(84, 96, 112))
	draw_rect(Rect2(at.x - 10, at.y - 7, 20, 3), Defs.COL_BELT_RIM)
	var font := UIFont.FONT
	draw_string(font, at + Vector2(-20, 24), "사료 %d" % sim.food, HORIZONTAL_ALIGNMENT_CENTER, 40.0, 10,
		Defs.COL_TEXT)

func _draw_furnace(machine: Sim.Machine, px: Vector2, tile: float) -> void:
	var c: Vector2 = px + Vector2.ONE * tile * 0.5
	var frost: float = _frost(machine)
	var body: Color = Color8(64, 76, 90).lerp(Color8(44, 52, 62), frost)
	var ready: bool = int(machine.buffer.get(Defs.ITEM_CRYSTAL, 0)) > 0 and int(machine.buffer.get(Defs.ITEM_COPPER, 0)) > 0
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
	_draw_pip(c + Vector2(-6, 12), Defs.ITEM_CRYSTAL, int(machine.buffer.get(Defs.ITEM_CRYSTAL, 0)))
	_draw_pip(c + Vector2(6, 12), Defs.ITEM_COPPER, int(machine.buffer.get(Defs.ITEM_COPPER, 0)))
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
