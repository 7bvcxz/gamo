extends Node2D
class_name MachineLayer

## Draws machines, the items flowing between them, and the build preview.

## Carried over from Motorio: a 2x2 directional sheet, one frame per facing.
## cat_org, animated. The previous sheet was four still drawings in a 2x2 grid,
## one per direction, so a cat crossing the map slid along without moving its
## legs. These come out of tools/sprite normalised the same way the player's do:
## uniform 128 cells, one shared scale, the feet on a fixed anchor.
const CAT_IDLE_SHEET: Texture2D = preload("res://assets/characters/cat_idle_s.png")
const CAT_WALK_SHEET: Texture2D = preload("res://assets/characters/cat_walk_s.png")
const CAT_WALK_E_SHEET: Texture2D = preload("res://assets/characters/cat_walk_e.png")
const CAT_WALK_N_SHEET: Texture2D = preload("res://assets/characters/cat_walk_n.png")
## Eating and working, both front-facing only. A cat at the bowl faces it, and a
## cat at a miner is drawn in front of the machine the game draws itself -- there
## is no second angle either of them is ever seen from.
const CAT_EAT_SHEET: Texture2D = preload("res://assets/characters/cat_eat_s.png")
const CAT_WORK_SHEET: Texture2D = preload("res://assets/characters/cat_work_s.png")
## Adopted object art, drawn from directly above.
##
## These replace bodies that were drawn in code. What is drawn over them is
## still drawn: the stall marker, the work arc, the warm pools, the night glow.
## A picture says what a thing is; it cannot say what the thing is doing, and
## every one of those overlays exists because a player could not tell.
##
## Each file is stored at twice the size it is drawn at, matching the ground:
## the snow atlas is 64 and lands on a 32 cell. The project filters with NEAREST,
## so a texture stored far larger than it is drawn discards most of its pixels at
## a hard edge.
const CORE_ART: Texture2D = preload("res://assets/objects/core.png")
const SHELTER_ART: Texture2D = preload("res://assets/objects/shelter.png")
const FOOD_BIN_ART: Texture2D = preload("res://assets/objects/food_bin.png")
const MINER_ART: Texture2D = preload("res://assets/objects/miner.png")
## 2.7 tiles across. Written as the multiple rather than as 86.4, because the
## number that matters is how many cells of the world it covers.
## The drill a cat holds while it works, and how far it travels. Tied to the work
## sheet's own frame rather than to the clock, so the tool comes down when the
## animal does instead of beside it.
const CAT_TOOL_ART: Texture2D = preload("res://assets/objects/cat_tool.png")
const CAT_TOOL_DRAW := 30.0
const CAT_TOOL_BOB := 3.5

const CORE_DRAW := 2.7 * float(Defs.TILE)
## 2.2 tiles. Same form as the core's, for the same reason: the number that
## matters is how many cells of the world the building covers.
const SHELTER_DRAW := 2.2 * float(Defs.TILE)
const FOOD_BIN_DRAW := 36.0
const MINER_DRAW := 36.0

const CAT_CELL := 128.0
const CAT_FRAMES := 8
const CAT_FPS := 10.0
## Drawn a little smaller than Grim, who is one 128 cell at half scale -- so her
## cell covers 64 world pixels and a cat covers nine tenths of that. Written as
## the arithmetic rather than as 57.6, because the number that matters is the
## ratio and it should survive the player's cell changing.
const CAT_DRAW := PlayerActor.CELL * PlayerActor.SPRITE_SCALE * 0.9
## Where the feet and the top of the head sit inside the cell, as fractions of
## it. The sheets are normalised to the character128 cell, whose foot anchor is
## at y=104 of 128 and whose body starts around y=36. Everything hung off the
## cat -- its shadow, its load, its hunger bar -- is positioned from these, so
## changing CAT_DRAW moves them all together instead of leaving the cat standing
## beside its own shadow.
const CAT_FOOT_FRACTION := 104.0 / 128.0
const CAT_HEAD_FRACTION := 36.0 / 128.0
## The feet, relative to the cat's world position.
const CAT_GROUND := 10.0
## What hangs over a cat, and how high.
##
## Both used to be higher: the bar at 14 above the head and the load at 7, which
## overlapped each other by a pixel and, worse, put the bar squarely inside the
## item lying on the tile above. That is not a coincidence to be nudged around --
## a miner facing north drops into the cell above it, and its worker's gauge hung
## in exactly that cell. The recommended arrangement guaranteed the collision.
##
## So the bar hugs the head, below anything the next tile can hold, and the load
## rides above the bar. test_animation holds both gaps.
const CAT_BAR_LIFT := 5.0
const CAT_BAR_SIZE := Vector2(22.0, 3.0)
const CAT_LOAD_LIFT := 13.0
const CAT_LOAD_RADIUS := 5.0
## A loose item on the ground: how big it draws and how far it bobs. Constants
## because the cat layout above is measured against them.
const GROUND_ITEM_RADIUS := 4.2
const GROUND_ITEM_BOB := 1.6
## The miner's output arrow, measured from the machine centre outwards.
##
## Three things stack over a working miner -- whatever lies on the next tile, the
## worker's gauge, and this -- inside about sixteen pixels, so they cannot all be
## given clear air. Pulling the arrow down to 11 to clear the gauge put it inside
## the cat's head, where its outline read as a second pair of eyes and it stopped
## being an arrow at all; an output direction that is not recognisable is the
## thing this arrow was moved above the cats to fix in the first place. At 15 its
## tip touches the top of the gauge by about two pixels and both stay perfectly
## legible, which is the trade worth making. The test bounds that contact.
const MINER_ARROW_LIFT := 15.0
const MINER_ARROW_LENGTH := 10.0

var sim: Sim
var view_rect := Rect2()
var preview_type: int = Defs.M_MINER
var preview_cell := Vector2i.ZERO
var preview_dir := Vector2i.RIGHT
var preview_valid := true
## Which machine the player is facing, for the rate readout.
var focus_cell := Vector2i(9999, 9999)
## Which machine the throughput panel is pinned to. Marked in the world as well
## as in the panel, because the panel is on the far side of the screen and a
## reading with no visible subject is easy to attribute to the wrong machine.
var meter_cell := Vector2i(9999, 9999)
## 0 while the hut is just a building, 1 while it is full and lit for the night.
var shelter_glow: float = 0.0
## How many are inside, player included. Decides how many shadows go on the wall.
var shelter_sleepers: int = 1

var preview_affordable := true
var show_preview := true
var preview_occupied := false
var pulse: float = 0.0
var night: float = 0.0

var _repaint := 0.0

## What a machine says about itself, drawn above the animals working it.
##
## This used to be the last thing in _draw(), which put it above the cats because
## they were drawn in the same function. Cats are their own nodes now, so the
## order has to be a z_index rather than a line number -- and it has to hold: the
## stall marker and the output arrow are the two readouts a player needs exactly
## when a cat is standing on the machine, and both have already been found hidden
## underneath one.
const MARKS_Z := 4
var _marks_layer: Node2D

func _ready() -> void:
	_marks_layer = Node2D.new()
	_marks_layer.z_index = MARKS_Z
	_marks_layer.draw.connect(_draw_marks_layer)
	add_child(_marks_layer)

func _draw_marks_layer() -> void:
	if sim == null:
		return
	var tile := float(Defs.TILE)
	_draw_machine_marks(_marks_layer, tile)
	if show_preview:
		_draw_preview(_marks_layer, tile)

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
			Defs.M_SPLITTER: _draw_splitter(machine, Vector2(cell) * tile, tile)
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
	_draw_meter_marker(tile)
	_draw_focus_readout()
	# Cats are not drawn here any more. They are nodes under Main/Cats at a z
	# between this layer and _marks_layer, so what is left in this function is
	# the factory itself.
	_marks_layer.queue_redraw()

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

	_object_art(SHELTER_ART, at, SHELTER_DRAW)
	# Firelight on the snow around it, which the picture cannot do: the hut has to
	# get brighter as the night comes on, and that is the signal telling the
	# player where to be.
	draw_circle(at + Vector2(0, 7), 9.0 * flicker, Color(1.0, 0.70, 0.32, 0.10 * lit))
	_draw_shelter_occupied(at, flicker)

	# Smoke, so the building is alive even when nobody is home. The chimney it
	# rises from is in the picture now; this is only what comes out of it.
	for index in 3:
		var rise: float = fmod(pulse * 0.5 + float(index) * 0.34, 1.0)
		draw_circle(at + Vector2(8.0 + sin(rise * 4.0 + float(index)) * 3.0, -17.0 - rise * 13.0),
			1.4 + rise * 1.8, Color(0.86, 0.88, 0.92, (1.0 - rise) * 0.22))

	# No caption. A snowed-in hut with a lit window and smoke on its chimney does
	# not need the word 숙소 written under it, and the label was a leftover from
	# when the building was two rectangles.

## The hut with everyone inside it. Nobody is drawn in the world during the night
## sequence, so this is the only place the player can see that the workforce made
## it home: the wall becomes a lit screen and their shadows move on it.
##
## Drawn on the wall rather than only inside the window because at one tile across
## an 8px window can hold about two pixels of anything. The whole front face is
## the lantern screen.
## Light escaping the hut once someone is inside.
##
## The wall panel and the silhouettes on it are gone with the wall: this roof is
## seen from directly above and there is no face to throw them onto. What is left
## is on the ground, where a top-down view can still show it -- the halo and the
## wedge under the door -- and the wedge carries the count instead, brightening
## with each sleeper. Weaker than four separate shadows, and the honest option:
## drawing silhouettes onto a roof would say something the picture denies.
func _draw_shelter_occupied(at: Vector2, flicker: float) -> void:
	if shelter_glow <= 0.0:
		return
	var glow: float = clampf(shelter_glow, 0.0, 1.0)

	# Light escaping the building: a halo on the hut, and a wedge thrown forward
	# onto the snow from under the door.
	draw_circle(at, 52.0 * flicker, Color(1.0, 0.72, 0.34, 0.09 * glow))
	draw_circle(at, 30.0 * flicker, Color(1.0, 0.78, 0.42, 0.13 * glow))
	# The count rides on the wedge rather than on four silhouettes: one sleeper is
	# a glow under the door, four is the hut spilling light onto the snow.
	var crowd: float = 0.55 + 0.45 * clampf(float(shelter_sleepers), 1.0, 4.0) / 4.0
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(-7, 13), at + Vector2(7, 13),
		at + Vector2(20, 36), at + Vector2(-20, 36)]),
		Color(1.0, 0.80, 0.46, 0.16 * glow * crowd * flicker))

func _draw_meter_marker(tile: float) -> void:
	if meter_cell == Vector2i(9999, 9999):
		return
	var machine: Sim.Machine = sim.machine_at(meter_cell)
	if machine == null:
		return
	var origin: Vector2 = Vector2(meter_cell) * tile
	var span: Vector2 = Vector2(tile, tile)
	if machine.type == Defs.M_CORE:
		origin -= Vector2(tile, tile)
		span = Vector2(tile * 3.0, tile * 3.0)
	var box := Rect2(origin - Vector2(3, 3), span + Vector2(6, 6))
	var arm: float = tile * 0.34
	var glow: float = 0.55 + sin(pulse * 4.0) * 0.25
	var col := Color(Defs.COL_CORE.r, Defs.COL_CORE.g, Defs.COL_CORE.b, glow)
	var corners: Array[Vector2] = [
		box.position,
		box.position + Vector2(box.size.x, 0.0),
		box.position + Vector2(0.0, box.size.y),
		box.position + box.size,
	]
	var steps: Array[Vector2] = [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]
	for index in corners.size():
		var at: Vector2 = corners[index]
		var step: Vector2 = steps[index]
		draw_line(at, at + Vector2(arm * step.x, 0.0), col, 2.0)
		draw_line(at, at + Vector2(0.0, arm * step.y), col, 2.0)

## The machine the player is standing in front of states its own rate. Numbers
## the player cannot see cannot be planned around, which turns ratio design into
## trial and error -- and ratio design is the point of the genre.
func _draw_focus_readout() -> void:
	if focus_cell == Vector2i(9999, 9999):
		return
	var machine: Sim.Machine = sim.machine_at(focus_cell)
	var name := ""
	var line := ""
	if machine != null:
		name = Defs.MACHINE_NAMES[machine.type]
		line = Defs.throughput_line(machine.type)
		# A miner reports what this particular seam gives it, not the generic
		# rate: the whole point of purity is that seams differ.
		if machine.type == Defs.M_BELT:
			line = "%s · 칸당 %.1f초 · %.0f/분" % [Defs.BELT_TIERS[machine.tier]["name"],
				1.0 / Defs.belt_speed(machine.tier),
				Defs.belt_speed(machine.tier) / 0.34 * 60.0]
		if machine.type == Defs.M_EXCHANGER:
			line = "%s · %s" % [Defs.RECIPES[machine.recipe]["name"],
				Defs.recipe_line(machine.recipe)]
			if sim.recipe_unlocked(Defs.RECIPE_ALLOY):
				name += "   F 제법 전환"
		if machine.type == Defs.M_MINER and sim.ore.has(focus_cell):
			var grade: int = sim.purity_of(focus_cell)
			line = "%s 광맥 · %.0f/분" % [Defs.PURITY_NAMES[grade],
				Defs.per_minute(sim.seam_period(focus_cell))]
	elif sim.ore.has(focus_cell):
		var grade: int = sim.purity_of(focus_cell)
		name = "%s %s 광맥" % [Defs.PURITY_NAMES[grade], Defs.ITEM_NAMES[int(sim.ore[focus_cell])]]
		line = "채굴기 설치 시 %.0f/분" % Defs.per_minute(sim.seam_period(focus_cell))
	if line == "":
		return
	var tile := float(Defs.TILE)
	var at: Vector2 = Vector2(focus_cell) * tile + Vector2(tile * 0.5, -6.0)
	var font: Font = UIFont.FONT
	var width: float = maxf(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x,
		font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x) + 12.0
	var box := Rect2(at + Vector2(-width * 0.5, -24.0), Vector2(width, 24.0))
	draw_rect(box, Color(Defs.COL_PANEL.r, Defs.COL_PANEL.g, Defs.COL_PANEL.b, 0.92))
	draw_rect(box, Color(Defs.COL_CORE.r, Defs.COL_CORE.g, Defs.COL_CORE.b, 0.45), false, 1.0)
	draw_string(font, box.position + Vector2(6, 10), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
		Defs.COL_TEXT)
	draw_string(font, box.position + Vector2(6, 20), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
		Defs.COL_CORE)

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
	# The heat it throws stays procedural -- it has to breathe with `beat` and
	# brighten when something is delivered, and a still picture does neither.
	draw_circle(c, 52.0 * beat, Color(1.0, 0.67, 0.31, 0.10))
	draw_circle(c, 38.0 * beat, Color(1.0, 0.67, 0.31, 0.16))
	# Fixed size. The beat used to scale the drawing, which was fine when the
	# drawing was four concentric circles and reads as the building itself
	# breathing now -- a machine that grows and shrinks looks broken, not alive.
	# The heat it throws still pulses; the machine does not.
	_object_art(CORE_ART, c, CORE_DRAW)
	draw_arc(c, 44.0, 0.0, TAU, 64, Color(1.0, 0.69, 0.36, 0.30 + machine.flash), 2.0, true)

## One sprite, centred on a cell. Top-down art has no feet, so unlike the cats --
## which stand on a fixed ground line -- these hang off the middle of the tile.
func _object_art(texture: Texture2D, centre: Vector2, size: float,
		tint: Color = Color.WHITE) -> void:
	draw_texture_rect(texture, Rect2(centre - Vector2.ONE * size * 0.5,
		Vector2.ONE * size), false, tint)

## Every object standing on the plateau casts the same shadow: one squash, one
## colour, always at the object's base. Three different shadow styles was the
## single loudest inconsistency in the old world layer.
func _shadow(base: Vector2, radius: float) -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, Defs.SHADOW_SQUASH))
	draw_circle(Vector2(base.x, base.y / Defs.SHADOW_SQUASH), radius, Defs.SHADOW)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Every raised body: one footprint, one outline, light from the top-left.
## Returns the inner rect so each machine can put its own identity inside it.
func _body(centre: Vector2, size: float, base: Color, edge: Color = Color(0, 0, 0, 0)) -> Rect2:
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
	# Identity rim. Three machines now share one footprint, so the silhouette can
	# no longer tell them apart; the rim does it instead. Drawn *inside* the black
	# outline rather than replacing it, so the shared silhouette rule survives.
	if edge.a > 0.0:
		draw_rect(rect, edge, false, 2.0)
	return rect

## One arrow shape used by previews and by placed machines, so "which way does
## this face" is answered the same way everywhere.
func _draw_arrow(on: CanvasItem, from: Vector2, dir: Vector2i, length: float, col: Color, width: float = 3.0) -> void:
	var d := Vector2(dir)
	var perp := Vector2(-d.y, d.x)
	var tip: Vector2 = from + d * length
	on.draw_line(from, tip - d * 5.0, col, width)
	on.draw_colored_polygon(PackedVector2Array([
		tip, tip - d * 7.0 + perp * 4.5, tip - d * 7.0 - perp * 4.5]), col)

func _draw_miner(machine: Sim.Machine, px: Vector2, tile: float) -> void:
	var c: Vector2 = px + Vector2.ONE * tile * 0.5
	var frost: float = _frost(machine)
	var work: float = clampf(machine.progress / Defs.MINER_PERIOD, 0.0, 1.0)

	_shadow(c + Vector2(0, 12), 11.0)
	# Cold machines go blue rather than dark: the tint is the same signal the
	# painted body carried, applied to the picture instead of mixed into it.
	_object_art(MINER_ART, c, MINER_DRAW, Color.WHITE.lerp(Color(0.60, 0.70, 0.86), frost))
	# The output arrow is drawn after the cats, not here -- see _draw_machine_marks.
	if machine.operated:
		draw_arc(c, 15.0, -PI * 0.5, -PI * 0.5 + TAU * work, 22, Color(1, 1, 1, 0.42), 2.0, true)
	else:
		# Idle machines say so plainly: this is the most common reason a new
		# player sees no output at all.
		var blink: float = 0.45 + sin(pulse * 3.0) * 0.3
		draw_arc(c, 15.0, 0.0, TAU, 28, Color(0.75, 0.78, 0.85, blink), 1.5, true)
	if machine.flash > 0.0:
		draw_circle(c, 17.0 + machine.flash * 12.0, Color(1, 1, 1, machine.flash * 0.5), false, 2.0)

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

## A splitter is a floor piece like the belt -- items pass over it, so it must
## not look like something you walk around. Four lit lanes out of a dark hub, and
## the lane it will feed next is the bright one, so the round-robin is visible
## rather than inferred.
func _draw_splitter(machine: Sim.Machine, px: Vector2, tile: float) -> void:
	var c: Vector2 = px + Vector2.ONE * tile * 0.5
	var frost: float = _frost(machine)
	var base: Color = Defs.COL_BELT_BODY if frost <= 0.0 else Defs.COL_BELT_BODY_COLD
	var edge: Color = Defs.machine_color(Defs.M_SPLITTER)
	draw_rect(Rect2(px.x + 1, px.y + 1, tile - 2, tile - 2), Defs.OUTLINE)
	draw_rect(Rect2(px.x + 2, px.y + 2, tile - 4, tile - 4), base)
	draw_rect(Rect2(px.x + 2, px.y + 2, tile - 4, tile - 4), edge, false, 2.0)
	# Only the two lanes it actually feeds, and the one that is next is bright, so
	# the alternation is visible rather than inferred.
	var sides: Array[Vector2i] = sim.splitter_outputs(machine)
	for index in sides.size():
		var dir := Vector2(sides[index])
		var next: bool = index == machine.next_out
		var lane: Color = edge if next else Color(edge.r, edge.g, edge.b, 0.32)
		draw_line(c + dir * 4.0, c + dir * 13.0, lane, 3.0 if next else 2.0)
	# And a dim stub showing where input is expected.
	draw_line(c - Vector2(machine.dir) * 13.0, c - Vector2(machine.dir) * 5.0,
		Color(edge.r, edge.g, edge.b, 0.20), 2.0)
	draw_circle(c, 5.0, base.darkened(0.35))
	draw_circle(c, 5.0, Defs.OUTLINE, false, 1.0)
	for entry: Dictionary in machine.items:
		draw_circle(c, 2.6, Defs.ITEM_COLORS[int(entry["type"])])
		break
	# Grade pips on the rim, so an upgraded belt is legible without selecting it.
	for index in machine.tier:
		draw_circle(px + Vector2(6.0 + float(index) * 5.0, tile - 4.0), 1.7, Defs.COL_BELT_RIM)

## Loose items on the floor. Small, lit and slowly bobbing, so a dropped shard
## reads as "come and get me" rather than as scenery.
func _draw_ground() -> void:
	var tile := float(Defs.TILE)
	for cell: Vector2i in sim.ground:
		if not _visible(cell, tile):
			continue
		var item_type: int = int(sim.ground[cell])
		var at: Vector2 = Vector2(cell) * tile + Vector2.ONE * tile * 0.5
		var bob: float = sin(pulse * 3.0 + float(cell.x + cell.y)) * GROUND_ITEM_BOB
		var colour: Color = Defs.ITEM_COLORS[item_type]
		_shadow(at + Vector2(0, 7), 5.0)
		draw_circle(at + Vector2(0, bob), 7.0, Color(colour.r, colour.g, colour.b, 0.28))
		draw_circle(at + Vector2(0, bob), GROUND_ITEM_RADIUS, colour)
		draw_circle(at + Vector2(0, bob), GROUND_ITEM_RADIUS, Defs.OUTLINE, false, 1.0)
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
	_body(centre, Defs.MACHINE_BODY, base, Defs.machine_color(Defs.M_GENERATOR))
	# A lit drum. Cool light, because power is infrastructure rather than warmth,
	# and it beats only while the generator is actually supplying.
	var beat: float = (0.65 + sin(pulse * 4.0) * 0.25) if live else 0.16
	draw_circle(centre, 7.5, Color(0.30, 0.58, 0.78, beat * 0.7))
	draw_circle(centre, 5.0, Color(0.55, 0.82, 0.98, beat))
	draw_circle(centre, 2.2, Color(0.92, 0.99, 1.0, beat))
	draw_circle(centre, 7.5, Defs.OUTLINE, false, 1.0)
	# Fuel sits in the same pip row every other machine uses.
	_draw_pip(centre + Vector2(0, 13), Defs.ITEM_ENERGY, int(machine.buffer.get(Defs.ITEM_ENERGY, 0)))

## Cats are agents, not tiles: they walk between the shelter, their machine and
## the food bin, so they are drawn from their own positions.
## Where a cat's sprite goes on screen, given where the cat is.
##
## One function because there are two callers -- this layer for the cats on the
## ground, PlayerActor for the one in her arms -- and while they each did their
## own arithmetic they disagreed. The arms kept a centre offset tuned when a cat
## was drawn 44 pixels tall; the ground had moved to anchoring on the feet at
## 57.6. Anchoring on the feet is the part that matters: `breathe` scales the
## sprite every frame, and a cat anchored by its middle lifts off its own shadow
## every time it inhales.
##
## `dip` is the chewing motion, which is the one thing allowed to move the cat
## off its shadow, because it is a cat leaning down to a bowl.
static func cat_rect(at: Vector2, breathe: float, flip: bool, dip: float) -> Rect2:
	var size := Vector2(CAT_DRAW / breathe, CAT_DRAW * breathe)
	if flip:
		size.x = -size.x
	var rect := Rect2(at.x - absf(size.x) * 0.5,
		at.y + CAT_GROUND - CAT_FOOT_FRACTION * size.y + dip, size.x, size.y)
	if flip:
		rect.position.x += absf(size.x)
	return rect

## The top of the cat's head, for whatever hangs above it.
static func cat_body_rect(rect: Rect2) -> Rect2:
	var box: Rect2 = rect.abs()
	var top: float = box.position.y + CAT_HEAD_FRACTION * box.size.y
	var bottom: float = box.position.y + CAT_FOOT_FRACTION * box.size.y
	var width: float = box.size.x * 0.62
	return Rect2(box.get_center().x - width * 0.5, top, width, bottom - top)

## Breathing, and which frame is showing. Both read the cat's own constant offset
## and the clock, and neither reads where the cat is standing -- see Cat.phase for
## what happened when they did. Exposed so the thing that matters can be measured
## rather than looked at: a walking cat's gauge must not move against its shadow.
static func cat_breathe(cat: Sim.Cat, time: float) -> float:
	return 1.0 + sin(time * 2.6 + cat.phase * TAU) * 0.02

static func cat_frame(cat: Sim.Cat, time: float) -> int:
	return int(time * CAT_FPS + cat.phase * float(CAT_FRAMES)) % CAT_FRAMES

## The hunger gauge and the carried load, from the same rect as everything else.
## Exposed rather than written inline so the gaps between them, and between them
## and the tile above, can be measured instead of eyeballed.
static func cat_sheet(state: int, heading: Vector2, walking: bool) -> Array:
	# Standing still gets the idle sheet; anything with somewhere to be walks. A
	# cat that has arrived and is working should not keep striding on the spot,
	# and one crossing the map should not glide.
	# The two sheets that are neither walking nor standing. Both are front-facing
	# only, so neither reads the heading.
	if state == Defs.CAT_EATING:
		return [CAT_EAT_SHEET, false]
	if state == Defs.CAT_WORKING:
		return [CAT_WORK_SHEET, false]
	# Asked rather than derived from the state, because a loitering cat is walking
	# while its state says idle. Deriving it here is what this table was written
	# to stop: two of the five travelling states were missing from a list like
	# this one and those cats crossed the map with their legs still.
	if not walking:
		return [CAT_IDLE_SHEET, false]
	if absf(heading.x) >= absf(heading.y):
		return [CAT_WALK_E_SHEET, heading.x < 0.0]
	if heading.y < 0.0:
		return [CAT_WALK_N_SHEET, false]
	return [CAT_WALK_SHEET, false]

func _draw_boxes(tile: float) -> void:
	for cell: Vector2i in sim.cat_boxes:
		var at: Vector2 = Vector2(cell) * tile + Vector2.ONE * tile * 0.5
		if not view_rect.grow(tile).has_point(at):
			continue
		_shadow(at + Vector2(0, 9), 9.0)
		# Ears break the square silhouette. A pawprint on a brown box read as a
		# food bin from a screen away; a shape with ears cannot be mistaken.
		draw_colored_polygon(PackedVector2Array([
			at + Vector2(-7, -8), at + Vector2(-4, -13), at + Vector2(-1, -8)]), Defs.OUTLINE)
		draw_colored_polygon(PackedVector2Array([
			at + Vector2(7, -8), at + Vector2(4, -13), at + Vector2(1, -8)]), Defs.OUTLINE)
		var crate: Rect2 = _body(at, 17.0, Color8(146, 102, 62))
		draw_rect(Rect2(crate.position.x, crate.get_center().y - 1.5, crate.size.x, 3.0),
			Color8(196, 146, 92))
		draw_circle(at + Vector2(0, -2), 2.2, Defs.COL_CAT_FACE)

func _draw_food_bin(tile: float) -> void:
	var at: Vector2 = Vector2(sim.food_cell) * tile + Vector2.ONE * tile * 0.5
	_shadow(at + Vector2(0, 10), 10.0)
	_object_art(FOOD_BIN_ART, at, FOOD_BIN_DRAW)
	# The count is drawn after the animals -- see _draw_machine_marks.

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
	var plate: Rect2 = _body(c, Defs.MACHINE_BODY, body, Defs.machine_color(Defs.M_EXCHANGER))
	# A lit conversion window, warm because the light belongs to the factory.
	draw_rect(Rect2(c.x - 6, c.y - 4, 12, 10), Color(1.0, 0.55, 0.2, glow))
	draw_rect(Rect2(c.x - 6, c.y - 4, 12, 10), Defs.OUTLINE, false, 1.0)
	draw_rect(Rect2(plate.position, Vector2(plate.size.x, 2.5)),
		Defs.COL_BELT_RIM.lerp(body, frost * 0.7))
	_draw_arrow(self, c + Vector2(machine.dir) * 15.0, machine.dir, 9.0, Defs.COL_BRASS, 2.2)
	# A copper stud marks the alloy recipe, so two exchangers side by side on
	# different recipes are told apart without selecting either.
	if machine.recipe != Defs.RECIPE_PLAIN:
		draw_circle(c + Vector2(0, -9), 2.4, Defs.ITEM_COLORS[Defs.ITEM_COPPER])
		draw_circle(c + Vector2(0, -9), 2.4, Defs.OUTLINE, false, 1.0)
	# One pip row for the one input the recipe actually takes.
	_draw_pip(c + Vector2(0, 13), Defs.ITEM_CRYSTAL, held)
	if machine.flash > 0.0:
		draw_circle(c, 16.0 + machine.flash * 14.0, Color(1, 0.9, 0.7, machine.flash * 0.55), false, 2.0)

## Every stalled machine, drawn after the cats.
##
## The marker used to go up inside each machine's own drawing, which put it
## underneath the cat standing on it -- and a miner only stalls while it is
## running, which is to say while a cat is standing on it. The one thing telling
## a player their miner is dead was hidden by the animal that makes it work. Two
## miners on adjacent seams produced nothing for six minutes in a playtest and
## the screen said so nowhere.
## The miner's output arrow is here for the same reason. It sits fifteen pixels
## from the centre in the direction of travel, and a cat is nearly sixty pixels
## tall standing on that centre -- so a north-facing miner's arrow was entirely
## behind its worker. Which way a miner points is the difference between a
## factory and two machines emitting into each other, and it was invisible in
## exactly the case where a miner is running.
func _draw_machine_marks(on: CanvasItem, tile: float) -> void:
	_draw_food_count(on, tile)
	for cell: Vector2i in sim.machines:
		var machine: Sim.Machine = sim.machines[cell]
		if not _visible(cell, tile):
			continue
		var centre: Vector2 = Vector2(cell) * tile + Vector2.ONE * tile * 0.5
		if machine.type == Defs.M_MINER:
			# Outlined, because it is now drawn over the cat rather than under it.
			# Cream on snow read as a mark; cream on a cream cat read as a party
			# hat, and an output direction that looks like part of the animal is
			# not much better than one hidden behind it.
			var tail: Vector2 = centre + Vector2(machine.dir) * MINER_ARROW_LIFT
			_draw_arrow(on, tail, machine.dir, MINER_ARROW_LENGTH, Defs.OUTLINE, 5.0)
			_draw_arrow(on, tail, machine.dir, MINER_ARROW_LENGTH, Defs.COL_BELT_RIM, 2.5)
		if machine.stalled:
			_draw_stall(on, machine, centre)

## How much food is left, over the bin, with no word in front of it: what the
## number counts is obvious from the crate of fish it is sitting on.
##
## Drawn here rather than with the bin because a crate lands on the tile above it
## and the cats queue in front, and both are drawn later -- so the number was
## painted and then covered.
##
## No plate behind it. It is outlined instead, which is what keeps it readable on
## snow, on wood and on a cat depending on the minute: an outline belongs to the
## glyphs, so nothing is painted over the world to carry it.
func _draw_food_count(on: CanvasItem, tile: float) -> void:
	var at: Vector2 = Vector2(sim.food_cell) * tile + Vector2.ONE * tile * 0.5
	if not view_rect.grow(tile * 2.0).has_point(at):
		return
	var label: String = str(sim.food)
	var font: Font = UIFont.FONT
	var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10).x
	var origin := Vector2(at.x - width * 0.5, at.y - FOOD_BIN_DRAW * 0.5 - 3.0)
	on.draw_string_outline(font, origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, 3,
		Color(0.04, 0.05, 0.08, 0.85))
	on.draw_string(font, origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Defs.COL_TEXT)

## A backed-up machine is the single most common way a factory silently stops
## paying. It gets an unmissable pulsing marker rather than nothing at all.
func _draw_stall(on: CanvasItem, machine: Sim.Machine, c: Vector2) -> void:
	if not machine.stalled:
		return
	var beat: float = 0.55 + sin(pulse * 5.0) * 0.45
	var at: Vector2 = c + Vector2(0, -18)
	on.draw_circle(at, 7.0, Color(0.06, 0.08, 0.12, 0.85))
	on.draw_circle(at, 6.0, Color(Defs.COL_DANGER.r, Defs.COL_DANGER.g, Defs.COL_DANGER.b, 0.45 + beat * 0.5))
	on.draw_rect(Rect2(at.x - 1.0, at.y - 3.5, 2.0, 4.5), Color(1, 1, 1, 0.9))
	on.draw_rect(Rect2(at.x - 1.0, at.y + 2.0, 2.0, 2.0), Color(1, 1, 1, 0.9))

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
	var grade: float = float(Defs.BELT_TIERS[machine.tier]["speed"])
	for index in 2:
		var offset: float = fmod(pulse * Defs.BELT_SPEED * grade * 0.5 + float(index) * 0.5, 1.0)
		var along: float = (offset - 0.5) * tile
		var head: Vector2 = c + dir * (along + 5.0)
		var tail: Vector2 = c + dir * (along - 2.0)
		var chev: Color = Defs.COL_BELT_CHEVRON if frost <= 0.0 else Defs.COL_FROZEN_CHEVRON
		draw_line(tail + perp * 5.0, head, chev, 2.0)
		draw_line(tail - perp * 5.0, head, chev, 2.0)

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

func _draw_preview(on: CanvasItem, tile: float) -> void:
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
			on.draw_line(origin, origin + Vector2(dx, 0), mark, 2.0)
			on.draw_line(origin, origin + Vector2(0, dy), mark, 2.0)
		return
	# Three explicit states. A ghost that is always red teaches nothing.
	var col: Color = Defs.COL_VALID if preview_valid else (
		Color8(150, 160, 180) if not preview_affordable else Defs.COL_DANGER)
	var alpha: float = 0.55 + sin(pulse * 5.0) * 0.12
	on.draw_rect(Rect2(px.x + 1, px.y + 1, tile - 2, tile - 2), Color(col.r, col.g, col.b, 0.16))
	on.draw_rect(Rect2(px.x + 1, px.y + 1, tile - 2, tile - 2), Color(col.r, col.g, col.b, alpha), false, 2.0)
	# Direction is the most-missed piece of information when placing: R changes it
	# invisibly unless the preview states it outright.
	var c: Vector2 = px + Vector2.ONE * tile * 0.5
	var arrow := Color(col.r, col.g, col.b, minf(1.0, alpha + 0.3))
	var dir := Vector2(preview_dir)
	on.draw_circle(c - dir * 12.0, 3.0, Color(arrow.r, arrow.g, arrow.b, 0.55))
	_draw_arrow(on, c - dir * 6.0, preview_dir, 22.0, arrow, 3.0)
	var font := UIFont.FONT
	on.draw_string(font, c + dir * 20.0 + Vector2(-14.0, -12.0), "OUT", HORIZONTAL_ALIGNMENT_CENTER, 28.0, 9,
		Color(arrow.r, arrow.g, arrow.b, 0.9))
