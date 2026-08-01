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
	_draw_hand_progress()
	_draw_cats()
	if show_preview:
		_draw_preview(tile)

## A hut beside the core: the destination the night pushes you toward.
## The shelter is the other end of the run from the core: the core is where heat
## comes from, this is where the day survives to. So it is built to the same
## finish -- it sits on its own tile, carries a warm pool of its own, and its
## window is the one light that answers the core across the base.
func _draw_shelter(tile: float) -> void:
	var origin: Vector2 = Vector2(sim.shelter_cell) * tile
	var at: Vector2 = origin + Vector2.ONE * tile * 0.5
	# Firelight rises with the night, which is exactly when the player needs to
	# find this building from across the plateau.
	var lit: float = 0.30 + night * 0.70
	var flicker: float = 1.0 + sin(pulse * 5.3) * 0.06 + sin(pulse * 2.1) * 0.04

	# Warm pool, so it reads as a destination rather than a prop.
	draw_circle(at, 30.0 * flicker, Color(1.0, 0.62, 0.26, 0.05 + night * 0.16))
	draw_circle(at, 20.0 * flicker, Color(1.0, 0.66, 0.30, 0.07 + night * 0.20))
	_shadow(at + Vector2(0, 13), 13.0)

	var wall := Color8(84, 52, 40)
	var wall_lit := Color8(104, 66, 50)
	var roof := Color8(58, 38, 32)
	var roof_lit := Color8(74, 50, 40)
	var trim: Color = Defs.COL_BRASS

	# Body, with the left face a shade lighter so the hut has a light direction
	# instead of reading flat.
	var body := Rect2(at.x - 12.0, at.y - 2.0, 24.0, 16.0)
	draw_rect(body, wall)
	draw_rect(Rect2(body.position, Vector2(body.size.x * 0.42, body.size.y)), wall_lit)
	draw_rect(body, Color(0.02, 0.03, 0.05, 0.55), false, 1.0)

	# Roof: two slopes rather than one triangle, so the ridge catches the light.
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(-15, -1), at + Vector2(0, -15), at + Vector2(0, -1)]), roof_lit)
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(0, -15), at + Vector2(15, -1), at + Vector2(0, -1)]), roof)
	draw_line(at + Vector2(-15, -1), at + Vector2(15, -1), trim.darkened(0.35), 1.6)
	draw_line(at + Vector2(0, -15), at + Vector2(0, -1), Color(0.02, 0.03, 0.05, 0.35), 1.0)

	# The window is the whole point: one warm rectangle that brightens into the
	# night and spills a little onto the snow below the sill.
	var window := Rect2(at.x - 4.0, at.y + 2.0, 8.0, 8.0)
	draw_rect(window.grow(1.5), Color(0.02, 0.03, 0.05, 0.60))
	draw_rect(window, Color(1.0, 0.74, 0.36, lit))
	draw_rect(Rect2(window.position, Vector2(window.size.x, 2.0)),
		Color(1.0, 0.90, 0.62, lit))
	draw_circle(at + Vector2(0, 7), 9.0 * flicker, Color(1.0, 0.70, 0.32, 0.10 * lit))

	# A chimney with smoke, so the building is alive even when nobody is home.
	draw_rect(Rect2(at.x + 6.0, at.y - 15.0, 4.0, 7.0), roof)
	for index in 3:
		var rise: float = fmod(pulse * 0.5 + float(index) * 0.34, 1.0)
		draw_circle(at + Vector2(8.0 + sin(rise * 4.0 + float(index)) * 3.0, -17.0 - rise * 13.0),
			1.4 + rise * 1.8, Color(0.86, 0.88, 0.92, (1.0 - rise) * 0.22))

	var font := UIFont.FONT
	draw_string(font, at + Vector2(-24, 27), "숙소", HORIZONTAL_ALIGNMENT_CENTER, 48.0, 10,
		Color(Defs.COL_BELT_RIM.r, Defs.COL_BELT_RIM.g, Defs.COL_BELT_RIM.b, 0.50 + night * 0.45))

func _visible(cell: Vector2i, tile: float) -> bool:
	return view_rect.grow(tile * 2.0).has_point(Vector2(cell) * tile + Vector2.ONE * tile * 0.5)

func _frost(machine: Sim.Machine) -> float:
	return 0.0 if sim.is_warm(machine.cell) else 0.45

func _draw_core(machine: Sim.Machine, px: Vector2, tile: float) -> void:
	var c: Vector2 = px + Vector2.ONE * tile * 0.5
	var beat: float = 1.0 + sin(pulse * 2.2) * 0.05 + machine.flash * 0.5
	# The core is the emotional centre of the run, so it is drawn large enough to
	# outrank the HUD clock in the visual hierarchy.
	# The core had no shadow, so the one object the whole base points at was the
	# only thing not standing on the ground.
	_shadow(c + Vector2(0, 22), 20.0)
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

## Every object standing on the plateau casts the same shadow: one squash, one
## colour, always at the object's base. Three different shadow styles was the
## single loudest inconsistency in the old world layer.
func _shadow(base: Vector2, radius: float) -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, Defs.SHADOW_SQUASH))
	draw_circle(Vector2(base.x, base.y / Defs.SHADOW_SQUASH), radius, Defs.SHADOW)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Every raised body: one footprint, one outline, light from the top-left.
## Returns the inner rect so each machine can put its own identity inside it.
func _body(centre: Vector2, size: float, base: Color) -> Rect2:
	var rect := Rect2(centre - Vector2.ONE * size * 0.5, Vector2.ONE * size)
	draw_rect(rect.grow(2.0), Defs.OUTLINE)
	draw_rect(rect, base)
	var band: float = Defs.FACE_BAND
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, band)), base.lightened(Defs.FACE_LIGHT))
	draw_rect(Rect2(rect.position, Vector2(band, rect.size.y)), base.lightened(Defs.FACE_LIGHT * 0.55))
	draw_rect(Rect2(rect.position + Vector2(0.0, rect.size.y - band), Vector2(rect.size.x, band)),
		base.darkened(Defs.FACE_DARK))
	draw_rect(Rect2(rect.position + Vector2(rect.size.x - band, 0.0), Vector2(band, rect.size.y)),
		base.darkened(Defs.FACE_DARK * 0.55))
	return rect

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

	_shadow(c + Vector2(0, 12), 11.0)
	var plate: Rect2 = _body(c, Defs.MACHINE_BODY, body)
	# The warm lip is the machine's identity light, drawn over the shared faces.
	draw_rect(Rect2(plate.position, Vector2(plate.size.x, 2.5)),
		Defs.COL_BELT_RIM.lerp(body, frost))
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

## The swing. Ten seconds is a long time to hold a key with nothing to look at,
## so the seam being worked wears a filling arc and shakes a little harder as it
## approaches. Drawn on the seam rather than on the player because the seam is
## what the player is aiming at.
func _draw_hand_progress() -> void:
	if sim.hand_cell == Vector2i(9999, 9999):
		return
	var fraction: float = sim.hand_fraction()
	if fraction <= 0.0:
		return
	var tile := float(Defs.TILE)
	var centre: Vector2 = Vector2(sim.hand_cell) * tile + Vector2.ONE * tile * 0.5
	var jitter: float = fraction * 1.6
	centre += Vector2(randf_range(-jitter, jitter), randf_range(-jitter, jitter))
	var radius: float = tile * 0.52
	# The seam sits on warm amber ground, and an amber arc on amber reads as
	# nothing. Dark track, near-white fill: the contrast has to survive the
	# brightest floor in the game.
	draw_arc(centre, radius, 0.0, TAU, 40, Color(0.02, 0.04, 0.08, 0.72), 6.0)
	draw_arc(centre, radius, -PI * 0.5, -PI * 0.5 + TAU * fraction, 40,
		Color(1.0, 0.97, 0.90, 0.95), 5.0)
	draw_arc(centre, radius, -PI * 0.5, -PI * 0.5 + TAU * fraction, 40,
		Defs.COL_CORE, 2.0)
	# Chips fly off as the swing lands.
	if fraction > 0.75:
		var spark: float = (fraction - 0.75) / 0.25
		for index in 4:
			var angle: float = TAU * float(index) / 4.0 + pulse * 2.0
			draw_circle(centre + Vector2.from_angle(angle) * radius * (0.7 + spark * 0.5),
				2.2, Color(1.0, 0.95, 0.85, spark))

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
		_shadow(at + Vector2(0, 7), 5.0)
		draw_circle(at + Vector2(0, bob), 7.0, Color(colour.r, colour.g, colour.b, 0.28))
		draw_circle(at + Vector2(0, bob), 4.2, colour)
		draw_circle(at + Vector2(0, bob), 4.2, Defs.OUTLINE, false, 1.0)
		# A single highlight, in the same top-left place as every other object.
		draw_circle(at + Vector2(-1.4, bob - 1.4), 1.2, Color(1, 1, 1, 0.55))

## A generator reads as a lit drum: the glow is tied to whether it is actually
## supplying, so an unfuelled one is visibly dark rather than silently idle.
func _draw_generator(machine: Sim.Machine, px: Vector2, tile: float) -> void:
	var centre: Vector2 = px + Vector2.ONE * tile * 0.5
	var live: bool = machine.operated
	var frost: float = _frost(machine)
	var base: Color = Color8(64, 76, 90).lerp(Color8(44, 52, 62), frost)
	_shadow(centre + Vector2(0, 12), 11.0)
	_body(centre, Defs.MACHINE_BODY, base)
	# A lit drum. Cool light, because power is infrastructure rather than warmth,
	# and it beats only while the generator is actually supplying.
	var beat: float = (0.65 + sin(pulse * 4.0) * 0.25) if live else 0.16
	draw_circle(centre, 7.5, Color(0.30, 0.58, 0.78, beat * 0.7))
	draw_circle(centre, 5.0, Color(0.55, 0.82, 0.98, beat))
	draw_circle(centre, 2.2, Color(0.92, 0.99, 1.0, beat))
	draw_circle(centre, 7.5, Defs.OUTLINE, false, 1.0)
	# Fuel sits in the same pip row every other machine uses.
	_draw_pip(centre + Vector2(0, 13), Defs.ITEM_ENERGY, int(machine.buffer.get(Defs.ITEM_ENERGY, 0)))
	_draw_stall(machine, centre)

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
		_shadow(cat.pos + Vector2(0, 10), 8.0)
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
		_shadow(at + Vector2(0, 9), 9.0)
		var crate: Rect2 = _body(at, 17.0, Color8(146, 102, 62))
		# A slatted lid and a pawprint: the crate has to read as "a cat is in
		# here" from a screen away.
		draw_rect(Rect2(crate.position.x, crate.get_center().y - 1.5, crate.size.x, 3.0),
			Color8(196, 146, 92))
		draw_circle(at + Vector2(0, -3), 2.4, Defs.COL_CAT_FACE)
		draw_circle(at + Vector2(-3, -5), 1.1, Defs.COL_CAT_FACE)
		draw_circle(at + Vector2(3, -5), 1.1, Defs.COL_CAT_FACE)

func _draw_food_bin(tile: float) -> void:
	var at: Vector2 = Vector2(sim.food_cell) * tile + Vector2.ONE * tile * 0.5
	_shadow(at + Vector2(0, 10), 10.0)
	var bin: Rect2 = _body(at, 19.0, Color8(84, 96, 112))
	# An open hopper mouth, so the bin reads as something you take from.
	draw_rect(Rect2(bin.position + Vector2(3.0, 3.0), Vector2(bin.size.x - 6.0, 5.0)),
		Color8(46, 54, 66))
	draw_rect(Rect2(bin.position + Vector2(3.0, 3.0), Vector2(bin.size.x - 6.0, 5.0)),
		Defs.OUTLINE, false, 1.0)
	var font := UIFont.FONT
	draw_string(font, at + Vector2(-20, 24), "사료 %d" % sim.food, HORIZONTAL_ALIGNMENT_CENTER, 40.0, 10,
		Defs.COL_TEXT)

func _draw_furnace(machine: Sim.Machine, px: Vector2, tile: float) -> void:
	var c: Vector2 = px + Vector2.ONE * tile * 0.5
	var frost: float = _frost(machine)
	var body: Color = Color8(64, 76, 90).lerp(Color8(44, 52, 62), frost)
	# The recipe is crystal-only. This still asked for copper, left over from the
	# old smelter, so the window never lit no matter how well the line ran.
	var held: int = int(machine.buffer.get(Defs.ITEM_CRYSTAL, 0))
	var ready: bool = held >= Defs.CRYSTAL_COST_ENERGY
	var glow: float = (0.45 + sin(pulse * 6.0) * 0.25) if ready else 0.12

	_shadow(c + Vector2(0, 12), 11.0)
	var plate: Rect2 = _body(c, Defs.MACHINE_BODY, body)
	# A lit conversion window, warm because the light belongs to the factory.
	draw_rect(Rect2(c.x - 6, c.y - 4, 12, 10), Color(1.0, 0.55, 0.2, glow))
	draw_rect(Rect2(c.x - 6, c.y - 4, 12, 10), Defs.OUTLINE, false, 1.0)
	draw_rect(Rect2(plate.position, Vector2(plate.size.x, 2.5)),
		Defs.COL_BELT_RIM.lerp(body, frost * 0.7))
	_draw_arrow(c + Vector2(machine.dir) * 15.0, machine.dir, 9.0, Defs.COL_BRASS, 2.2)
	_draw_stall(machine, c)
	# One pip row for the one input the recipe actually takes.
	_draw_pip(c + Vector2(0, 13), Defs.ITEM_CRYSTAL, held)
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
	draw_rect(Rect2(px.x + 1, px.y + 1, tile - 2, tile - 2), Defs.OUTLINE)
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
