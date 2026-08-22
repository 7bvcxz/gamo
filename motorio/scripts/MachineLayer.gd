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
## A cat still in its ice, in four stages, most frozen first. Not an animation:
## the game holds one of these four while the ice goes, and what follows the last
## one is the ordinary cat sheet. Built by tools/sprite/build_freeze.py from a
## generated melt, which is why the cat does not shift between stages -- one
## transform is shared by all four and the tool fails if the cap moves.
const CAT_FREEZE_SHEET: Texture2D = preload("res://assets/characters/cat_freeze_4.png")
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
## The case in the snow, and the two things that come out of it. Three pictures
## rather than one because the whole opening is "there is a box, and what was in
## it becomes the fire and the hut" -- one drawn grey rectangle for all three
## states said none of that.
## The five pieces of the ship. Held in an array rather than five constants
## because the world stores which shape a piece is as a number, and a number that
## has to be turned into a name by a match statement is a sixth shape waiting to
## be forgotten.
const DEBRIS_ART: Array[Texture2D] = [
	preload("res://assets/objects/debris1.png"),
	preload("res://assets/objects/debris2.png"),
	preload("res://assets/objects/debris3.png"),
	preload("res://assets/objects/debris4.png"),
	preload("res://assets/objects/debris5.png"),
]
const DEBRIS_DRAW := 30.0
const PICKAXE_ART: Texture2D = preload("res://assets/objects/pickaxe.png")
const PICKAXE_DRAW := 26.0
const KIT_ART: Texture2D = preload("res://assets/objects/kit.png")
const KIT_BASE_ART: Texture2D = preload("res://assets/objects/kit_base.png")
const KIT_SHELTER_ART: Texture2D = preload("res://assets/objects/kit_shelter.png")
const KIT_DRAW := 32.0
const KIT_OPEN_DRAW := 26.0

## Which open case she is holding. Asked here so the world layer and the player
## cannot come to disagree about what is in her arms.
static func kit_art(kind: int) -> Texture2D:
	return KIT_BASE_ART if kind == Defs.KIT_BASE else KIT_SHELTER_ART
const MINER_ART: Texture2D = preload("res://assets/objects/miner.png")
const GENERATOR_ART: Texture2D = preload("res://assets/objects/generator.png")
## The transport pieces. All three are one cross-section swept along a path by
## tools/sprite/build_belt.py, and they are drawn in one canonical orientation --
## travelling east, and for the corner turning from east to south -- then rotated
## and mirrored here. Because every arm meets its tile edge square, the edge is
## that cross-section, so any two of these that meet match exactly rather than
## nearly. The tool checks it: placed tiles, touching pixels, maximum difference
## zero.
const BELT_STRAIGHT_ART: Texture2D = preload("res://assets/objects/belt_straight.png")
const BELT_CORNER_ART: Texture2D = preload("res://assets/objects/belt_corner.png")
const SPLITTER_ART: Texture2D = preload("res://assets/objects/splitter.png")
## 2.7 tiles across. Written as the multiple rather than as 86.4, because the
## number that matters is how many cells of the world it covers.
## The drill a cat holds while it works, and how far it travels. Tied to the work
## sheet's own frame rather than to the clock, so the tool comes down when the
## animal does instead of beside it.
const CAT_TOOL_ART: Texture2D = preload("res://assets/objects/cat_tool.png")
## 냥마을 and the board that points at it. Sizes live in build_objects.py's
## ADOPTED table beside the art; these are the same numbers, named here so the
## draw call reads as a drawing rather than as arithmetic.
const SIGN_ART: Texture2D = preload("res://assets/objects/signpost.png")
const SIGN_DRAW := 30.0
const VILLAGE_ART: Array[Texture2D] = [
	preload("res://assets/objects/village_house.png"),
	preload("res://assets/objects/village_well.png"),
	preload("res://assets/objects/village_fire.png"),
	preload("res://assets/objects/village_gate.png"),
]
const VILLAGE_DRAW: Array[float] = [38.0, 30.0, 32.0, 40.0]
## How brightly the board is saying its line, 0 to 1. Pushed by Main, which owns
## the fade, because whether she is still standing at it is a question about the
## player and this layer only draws.
var sign_label: float = 0.0
const SIGN_TEXT := 11
## 0.7 of what it was. At thirty pixels the drill was as wide as the cat holding
## it, which reads as a machine standing in front of the animal rather than a
## tool in its paws. Re-cut at this size too, so the pixels are the ones the game
## draws rather than a larger sheet thrown away at the edge.
const CAT_TOOL_DRAW := 21.0
const CAT_TOOL_BOB := 0.875
## How many times the drill goes up and down per turn of the work animation.
const CAT_TOOL_BEATS := 2.0

## Every one-tile machine drawn from a texture: miner, exchanger, generator. One
## number rather than three, because they stand side by side on the same snow and
## a difference between them reads as a difference in importance.
const MACHINE_ART_DRAW := 36.0

## One tile, as of 0.20.79. It has always *been* one cell -- one machine that
## blocks one tile -- and the picture was 2.7 of them, hanging over the tiles
## its neighbours are built on and over the input mouth beside it.
const CORE_DRAW := 1.0 * float(Defs.TILE)
## 2.2 tiles. Same form as the core's, for the same reason: the number that
## matters is how many cells of the world the building covers.
## Also one tile now, for the same reason: `is_structure` blocks exactly the
## one cell it stands on and the drawing claimed five.
const SHELTER_DRAW := 1.0 * float(Defs.TILE)
const FOOD_BIN_DRAW := 36.0

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
## The feet, relative to the cat's world position. The number lives in Defs
## because the simulation places cats by their feet and would otherwise be
## guessing at a constant the drawing owns.
const CAT_GROUND := Defs.CAT_FOOT_DROP
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
## Where the output arrow starts and how long it is, measured from the machine
## centre outward.
##
## Fifteen put it on the worker's chest. Outlining it there helped -- cream on a
## cream cat had been reading as part of the animal -- but a mark drawn across a
## face is still a mark competing with a face, and the thing it has to answer is
## "which way does this send its output", instantly. Twenty-six clears the head
## of a cat standing on the machine, which is measured: the cat is drawn about
## twenty-five pixels above the cell centre at its crown.
const MINER_ARROW_LIFT := 26.0
const MINER_ARROW_LENGTH := 12.0

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

## The furniture, painted where the room is. Drawn from this layer because the
## cats and Grim are nodes above it: they walk in front of a sofa, not through
## the picture of one.
const ROOM_ART := {
	Defs.ROOM_FIREPLACE: preload("res://assets/room/fireplace.png"),
	Defs.ROOM_BED: preload("res://assets/room/bed.png"),
	Defs.ROOM_SOFA_LEFT: preload("res://assets/room/sofa.png"),
	Defs.ROOM_SOFA_RIGHT: preload("res://assets/room/sofa.png"),
	Defs.ROOM_DOOR: preload("res://assets/room/door.png"),
}

func _draw() -> void:
	if sim == null:
		return
	var tile := float(Defs.TILE)
	if sim.indoors:
		_draw_room_pieces(tile)
		_marks_layer.queue_redraw()
		return
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
			Defs.M_GENERATOR: _draw_generator(machine, Vector2(cell) * tile, tile)
			Defs.M_SPLITTER: _draw_splitter(machine, Vector2(cell) * tile, tile)
	for cell: Vector2i in sim.machines:
		var machine: Sim.Machine = sim.machines[cell]
		if machine.type != Defs.M_BELT or not _visible(cell, tile):
			continue
		_draw_belt_items(machine, Vector2(cell) * tile, tile)
	_draw_shelter(tile)
	_draw_food_bin(tile)
	_draw_kit(tile)
	_draw_drops(tile)
	_draw_pickaxe_hint(tile)
	_draw_shards(tile)
	_draw_no_shelter(tile)
	_draw_village(tile)
	_draw_debris(tile)
	_draw_frozen(tile)
	_draw_thaw(tile)
	_draw_ground()
	_draw_hand_progress()
	_draw_meter_marker(tile)
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
	if not sim.shelter_placed:
		return
	var origin: Vector2 = Vector2(sim.shelter_cell) * tile
	var at: Vector2 = origin + Vector2.ONE * tile * 0.5
	# Firelight rises with the night, which is exactly when the player needs to
	# find this building from across the plateau.
	var lit: float = 0.30 + night * 0.70
	var flicker: float = 1.0 + sin(pulse * 5.3) * 0.06 + sin(pulse * 2.1) * 0.04

	# Warm pool, so it reads as a destination rather than a prop.
	draw_circle(at, 22.0 * flicker, Color(1.0, 0.62, 0.26, 0.05 + night * 0.16))
	draw_circle(at, 14.0 * flicker, Color(1.0, 0.66, 0.30, 0.07 + night * 0.20))
	_shadow(at + Vector2(0, 6), 8.0)

	_object_art(SHELTER_ART, at, SHELTER_DRAW)
	# Firelight on the snow around it, which the picture cannot do: the hut has to
	# get brighter as the night comes on, and that is the signal telling the
	# player where to be.
	draw_circle(at + Vector2(0, 3), 5.0 * flicker, Color(1.0, 0.70, 0.32, 0.10 * lit))
	_draw_shelter_occupied(at, flicker)

	# Smoke, so the building is alive even when nobody is home. The chimney it
	# rises from is in the picture now; this is only what comes out of it.
	for index in 3:
		var rise: float = fmod(pulse * 0.5 + float(index) * 0.34, 1.0)
		draw_circle(at + Vector2(5.0 + sin(rise * 4.0 + float(index)) * 2.0, -9.0 - rise * 10.0),
			1.0 + rise * 1.4, Color(0.86, 0.88, 0.92, (1.0 - rise) * 0.22))

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
	# Sized against a hut drawn at 2.2 tiles. The halo may stay bigger than the
	# building -- light does -- but a 52 pixel one around a 32 pixel hut is a
	# lamp with no lamp in it.
	draw_circle(at, 30.0 * flicker, Color(1.0, 0.72, 0.34, 0.09 * glow))
	draw_circle(at, 18.0 * flicker, Color(1.0, 0.78, 0.42, 0.13 * glow))
	# The count rides on the wedge rather than on four silhouettes: one sleeper is
	# a glow under the door, four is the hut spilling light onto the snow.
	var crowd: float = 0.55 + 0.45 * clampf(float(shelter_sleepers), 1.0, 4.0) / 4.0
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(-4, 7), at + Vector2(4, 7),
		at + Vector2(12, 22), at + Vector2(-12, 22)]),
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

## What the tile in front of her is, when she has asked.
##
## This used to be a plate that followed her around: face a seam and a rate
## appeared over it, face a machine and its throughput did. The numbers were the
## right numbers and the panel was the wrong place for them -- a readout nobody
## asked for, on screen whenever she happened to be standing near anything, over
## the tile she is about to build on.
##
## The same numbers are still one key away: `C` pins the meter panel to a
## machine, which is a readout the player opened. This one is gone.
##
## `focus_cell` stays, because the cell she is facing is what the placement ghost
## and the mining ring are drawn from.

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
	_shadow(c + Vector2(0, 8), 8.0)
	# The heat it throws stays procedural -- it has to breathe with `beat` and
	# brighten when something is delivered, and a still picture does neither.
	# The light it throws stays wider than the building -- that is what a fire
	# does -- but it was sized against a 2.7 tile drawing and reached most of
	# the base on its own.
	draw_circle(c, 34.0 * beat, Color(1.0, 0.67, 0.31, 0.10))
	draw_circle(c, 24.0 * beat, Color(1.0, 0.67, 0.31, 0.16))
	# Fixed size. The beat used to scale the drawing, which was fine when the
	# drawing was four concentric circles and reads as the building itself
	# breathing now -- a machine that grows and shrinks looks broken, not alive.
	# The heat it throws still pulses; the machine does not.
	_object_art(CORE_ART, c, CORE_DRAW)
	draw_arc(c, 22.0, 0.0, TAU, 48, Color(1.0, 0.69, 0.36, 0.30 + machine.flash), 2.0, true)

## One sprite, centred on a cell. Top-down art has no feet, so unlike the cats --
## which stand on a fixed ground line -- these hang off the middle of the tile.
func _object_art(texture: Texture2D, centre: Vector2, size: float,
		tint: Color = Color.WHITE) -> void:
	draw_texture_rect(texture, Rect2(centre - Vector2.ONE * size * 0.5,
		Vector2.ONE * size), false, tint)

## A cell-filling tile, turned to face a direction and optionally mirrored.
##
## The transport art is drawn once, travelling east, and every other orientation
## is this transform. Drawing four rotations into the atlas instead would mean
## four chances for one of them to be regenerated and left behind, and rotation
## by right angles costs a NEAREST filter nothing.
func _tile_art(texture: Texture2D, px: Vector2, tile: float, facing: Vector2i,
		mirror: bool = false, tint: Color = Color.WHITE) -> void:
	var centre: Vector2 = px + Vector2.ONE * tile * 0.5
	draw_set_transform(centre, Vector2(facing).angle(),
		Vector2(1.0, -1.0 if mirror else 1.0))
	draw_texture_rect(texture, Rect2(-Vector2.ONE * tile * 0.5,
		Vector2.ONE * tile), false, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## The direction items arrive travelling in, which is what decides whether a belt
## is drawn straight or turning.
##
## Read off the neighbours rather than stored, so it cannot go stale: a belt laid
## down beside an existing one changes what that one looks like, and there is no
## moment to remember to update. A belt with nothing feeding it draws straight,
## which is also what the head of a line should look like.
##
## Straight wins over turning when both are present. Two lines merging is real
## and common, and of the two pictures the straight one is the one that says
## which way this cell sends things -- a corner would claim the merge came only
## from the side.
func _belt_inflow(machine: Sim.Machine) -> Vector2i:
	var out: Vector2i = machine.dir
	var found: Vector2i = out
	for step: Vector2i in Defs.STEPS:
		var feeder: Sim.Machine = sim.machines.get(machine.cell - step)
		if feeder == null or feeder.type != Defs.M_BELT or feeder.dir != step:
			continue
		if step == out:
			return out
		found = step
	return found

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
## Which way a machine sends what it makes. Outlined, always.
##
## The miner's arrow was outlined when it moved above the cats -- cream on snow
## reads as a mark, cream on a cream cat reads as a party hat -- and the
## exchanger's was left plain underneath them, which is the same drawing with
## both of that arrow's problems. One function now, so a third machine with an
## output cannot get a third answer.
func _draw_output_arrow(on: CanvasItem, centre: Vector2, dir: Vector2i, lift: float,
		length: float) -> void:
	var tail: Vector2 = centre + Vector2(dir) * lift
	_draw_arrow(on, tail, dir, length, Defs.OUTLINE, 5.0)
	_draw_arrow(on, tail, dir, length, Defs.COL_BELT_RIM, 2.5)

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
	_object_art(MINER_ART, c, MACHINE_ART_DRAW, Color.WHITE.lerp(Defs.COL_FROST_TINT, frost))
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
	# The same swept cross-section the belts are made of, as a T: in from behind,
	# out to both sides. So a splitter joins its belts rather than interrupting
	# them, which is the whole reason it is built from the same profile.
	_tile_art(SPLITTER_ART, px, tile, machine.dir, false,
		Color.WHITE.lerp(Defs.COL_FROST_TINT, frost))
	# Only the two lanes it actually feeds, and the one that is next is bright, so
	# the alternation is visible rather than inferred.
	var sides: Array[Vector2i] = sim.splitter_outputs(machine)
	for index in sides.size():
		var dir := Vector2(sides[index])
		var next: bool = index == machine.next_out
		var lane: Color = edge if next else Color(edge.r, edge.g, edge.b, 0.32)
		draw_line(c + dir * 4.0, c + dir * 13.0, lane, 3.0 if next else 2.0)
	# The dim stub that used to show where input is expected is gone: the art has
	# an arm there now, reaching the cell edge to meet the belt that feeds it, and
	# a painted hint on top of a real one reads as two different claims.
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
		# A pile says how deep it is. Belts pour onto bare ground now, so a tile
		# at the end of a line is a heap rather than a bead, and one bead where
		# there are nine things is the screen lying about the state of the world.
		var count: int = sim.ground_count(cell)
		if count <= 1:
			continue
		# Two shoulders behind the bead, so the shape reads as more than one from
		# further away than the number can be read at.
		draw_circle(at + Vector2(-4.0, bob + 1.6), GROUND_ITEM_RADIUS * 0.72, colour)
		draw_circle(at + Vector2(-4.0, bob + 1.6), GROUND_ITEM_RADIUS * 0.72,
			Defs.OUTLINE, false, 1.0)
		draw_circle(at + Vector2(4.0, bob + 1.6), GROUND_ITEM_RADIUS * 0.72, colour)
		draw_circle(at + Vector2(4.0, bob + 1.6), GROUND_ITEM_RADIUS * 0.72,
			Defs.OUTLINE, false, 1.0)
		var label: String = str(count)
		var width: float = UIFont.FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT,
			-1, 10).x
		draw_string(UIFont.FONT, at + Vector2(-width * 0.5 + 1.0, bob - 8.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Defs.OUTLINE)
		draw_string(UIFont.FONT, at + Vector2(-width * 0.5, bob - 9.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.92))

## A generator reads as a lit drum: the glow is tied to whether it is actually
## supplying, so an unfuelled one is visibly dark rather than silently idle.
func _draw_generator(machine: Sim.Machine, px: Vector2, tile: float) -> void:
	var centre: Vector2 = px + Vector2.ONE * tile * 0.5
	var live: bool = machine.operated
	var frost: float = _frost(machine)
	_shadow(centre + Vector2(0, 12), 11.0)
	_object_art(GENERATOR_ART, centre, MACHINE_ART_DRAW,
		Color.WHITE.lerp(Defs.COL_FROST_TINT, frost))
	# The port the art already has, lit from behind and beating only while the
	# generator is actually supplying. Cool light, because power is
	# infrastructure rather than warmth.
	var beat: float = (0.65 + sin(pulse * 4.0) * 0.25) if live else 0.16
	draw_circle(centre + Vector2(0.0, 1.0), 6.0, Color(0.55, 0.82, 0.98, beat * 0.75))
	draw_circle(centre + Vector2(0.0, 1.0), 2.4, Color(0.92, 0.99, 1.0, beat))
	# Fuel sits in the same pip row every other machine uses.
	_draw_pip(centre + Vector2(0, 13), Defs.ITEM_CRYSTAL, int(machine.buffer.get(Defs.ITEM_CRYSTAL, 0)))

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

## Crystal lying in the snow. There is a fixed number of these in a world and no
## way to make another, so each one has to be worth walking to -- a slow glint
## that catches the eye across the fog is the whole job.
##
## Drawn small and inset, the way everything that lies flat on the ground is.
## Crystal used to be a seam and seams stand up; a shard does not.
func _draw_shards(tile: float) -> void:
	for cell: Vector2i in sim.shards:
		var at: Vector2 = Vector2(cell) * tile + Vector2.ONE * tile * 0.5
		if not view_rect.grow(tile).has_point(at):
			continue
		var colour: Color = Defs.ITEM_COLORS[Defs.ITEM_CRYSTAL]
		# A phase per cell, so a field of them does not blink in unison.
		var phase: float = float(cell.x * 7 + cell.y * 13) * 0.7
		var glint: float = maxf(0.0, sin(pulse * 1.6 + phase))
		draw_circle(at, 7.0, Color(colour.r, colour.g, colour.b, 0.10 + 0.10 * glint))
		# Three shards out of the snow, biggest in the middle.
		for index in 3:
			var lean: float = (float(index) - 1.0) * 3.4
			var tall: float = 6.5 if index == 1 else 4.2
			draw_colored_polygon(PackedVector2Array([
				at + Vector2(lean - 2.0, 3.0), at + Vector2(lean + 2.0, 3.0),
				at + Vector2(lean + 0.4, 3.0 - tall)]), Defs.ORE_OUTLINE)
			draw_colored_polygon(PackedVector2Array([
				at + Vector2(lean - 1.3, 2.4), at + Vector2(lean + 1.3, 2.4),
				at + Vector2(lean + 0.3, 2.4 - tall * 0.82)]), colour)
		if glint > 0.92:
			draw_circle(at + Vector2(0.4, -2.0), 1.8 + (glint - 0.92) * 12.0,
				Color(1, 1, 1, (glint - 0.92) * 9.0))

## The survival kit that came down with her. A scuffed metal case in the snow,
## with the parachute lines still on it, and a slow pulse while there is
## anything left inside -- it is the only thing on the map in the first minute
## and it has to say "come here" without a label.
## Which seam the pickaxe is pointing at, and whether it is pointing at all.
## Handed in by Main, like everything else this layer needs to know about the run.
var pickaxe_hint := Vector2i(9999, 9999)

## What fell out of the case, lying on the snow.
##
## Drawn with the same art the player will see in their hands or in the row, so
## the thing on the ground and the thing they end up with are the same object.
func _draw_drops(tile: float) -> void:
	for cell: Vector2i in sim.drops:
		var at: Vector2 = Vector2(cell) * tile + Vector2.ONE * tile * 0.5
		if not view_rect.grow(tile).has_point(at):
			continue
		var kind: int = int(sim.drops[cell])
		# A slow bob and a halo: two small objects in a white field, and the whole
		# opening depends on the player noticing them.
		var lift: float = sin(pulse * 2.4 + float(cell.x)) * 2.0
		draw_circle(at, 13.0, Color(1.0, 0.72, 0.34, 0.10))
		_shadow(at + Vector2(0, 8), 8.0)
		match kind:
			Sim.DROP_KIT_BASE:
				_object_art(KIT_BASE_ART, at + Vector2(0, lift), KIT_OPEN_DRAW)
			Sim.DROP_KIT_SHELTER:
				_object_art(KIT_SHELTER_ART, at + Vector2(0, lift), KIT_OPEN_DRAW)
			Sim.DROP_GUN:
				Icons.draw_machine(self, Rect2(at + Vector2(-11.0, -11.0 + lift),
					Vector2(22.0, 22.0)), Defs.M_MINER)
			Sim.DROP_PICKAXE:
				# Painted rather than drawn in code. It lay in the snow beside a
				# painted case as a grey wedge on a brown stick, which is how the
				# one tool the opening turns on came to look like a placeholder.
				_object_art(PICKAXE_ART, at + Vector2(0, lift), PICKAXE_DRAW)

## The pickaxe, over the nearest seam, for a few seconds after she picks it up.
##
## The game already tells her which key it is. This says where to point it, and
## it does it by pointing rather than by another sentence -- a seam is a shape in
## the snow that a new player has no reason to read as a resource.
func _draw_pickaxe_hint(tile: float) -> void:
	if pickaxe_hint == Vector2i(9999, 9999):
		return
	var at: Vector2 = Vector2(pickaxe_hint) * tile + Vector2.ONE * tile * 0.5
	if not view_rect.grow(tile).has_point(at):
		return
	var bob: float = sin(pulse * 3.2) * 3.0
	draw_circle(at, 15.0, Color(1.0, 0.72, 0.34, 0.10 + 0.06 * sin(pulse * 3.2)))
	# The same picture as the one lying in the snow. This hint points at the seam
	# she should swing at, and pointing with a different drawing of the tool is
	# how a player ends up looking for a second object.
	# A third of the one lying in the snow. This one is a pointer sitting above a
	# seam rather than an object on the ground, and at full size it covered the
	# thing it was pointing at.
	_object_art(PICKAXE_ART, at + Vector2(0.0, -18.0 + bob), PICKAXE_DRAW / 3.0)

func _draw_kit(tile: float) -> void:
	if sim.kit_cell == Vector2i(9999, 9999) or sim.kit_searched >= 2:
		return
	var at: Vector2 = Vector2(sim.kit_cell) * tile + Vector2.ONE * tile * 0.5
	if not view_rect.grow(tile).has_point(at):
		return
	var breathe: float = 0.5 + 0.5 * sin(pulse * 2.2)
	draw_circle(at, 22.0, Color(1.0, 0.72, 0.36, 0.05 + 0.07 * breathe))
	_shadow(at + Vector2(0, 8), 11.0)
	_object_art(KIT_ART, at, KIT_DRAW)
	# Searching it. The same ring hand mining uses, because it is the same verb:
	# hold the key and watch a circle close.
	if sim.kit_progress > 0.0:
		draw_arc(at, 16.0, 0.0, TAU, 32, Color(0.02, 0.04, 0.08, 0.55), 3.0)
		draw_arc(at, 16.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(sim.kit_progress, 0.0, 1.0),
			32, Defs.COL_CORE, 3.0, true)

## The ground letting go, under whatever is standing on it. The same ring hand
## mining and the kit use, in the fire's colour rather than the ice's, because
## what is filling is heat arriving and not time passing.
func _draw_thaw(tile: float) -> void:
	if sim.thaw_progress <= 0.0:
		return
	var at: Vector2 = Vector2(sim.thaw_cell) * tile + Vector2.ONE * tile * 0.5
	if not view_rect.grow(tile).has_point(at):
		return
	draw_arc(at, 16.0, 0.0, TAU, 32, Color(0.02, 0.04, 0.08, 0.55), 3.0)
	draw_arc(at, 16.0, -PI * 0.5, -PI * 0.5 + TAU * sim.thaw_fraction(), 32,
		Defs.COL_CORE, 3.0, true)

## Where the hut cannot go, while she is holding it.
##
## The rule is that it must stand clear of the fire, and until now that rule
## existed only as a refusal at the moment of pressing Z: she walked to the
## middle of the circle -- which is the obvious place to put the thing that keeps
## her warm -- and the key did nothing. A rule the player can see before they act
## costs nothing to obey.
##
## Only while the hut is in her arms. A permanent red patch round the fire would
## be a warning about a thing that is not happening.
func _draw_no_shelter(tile: float) -> void:
	if sim.carried_kit != Defs.KIT_SHELTER or not sim.base_placed or sim.shelter_placed:
		return
	var reach: int = int(ceil(Defs.SHELTER_CLEARANCE))
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var cell: Vector2i = sim.core_cell + Vector2i(dx, dy)
			if not sim.shelter_too_close(cell):
				continue
			var at: Vector2 = Vector2(cell) * tile
			if not view_rect.grow(tile).has_point(at + Vector2.ONE * tile * 0.5):
				continue
			draw_rect(Rect2(at, Vector2.ONE * tile),
				Color(Defs.COL_DANGER.r, Defs.COL_DANGER.g, Defs.COL_DANGER.b, 0.16))

## The wreckage, and the ring closing on whichever piece is being taken apart.
##
## The same ring the case and the seam use. Three different verbs now watch the
## same circle fill, which is the point: the game has one idea of "hold the key
## and wait", and a fourth thing that did it differently would be a fourth thing
## to learn.
## The village and its signpost.
##
## Drawn before the ice, so a block standing in front of a house is in front of
## it: everything out here is a picture of a solid thing on a snow field, and the
## order they are painted in is the only depth this view has.
##
## The fire flickers on the same clock as every other flame in the game rather
## than on one of its own -- two fires breathing out of step read as two
## different kinds of fire.
func _draw_village(tile: float) -> void:
	if sim.sign_cell != Vector2i(9999, 9999):
		var post: Vector2 = Vector2(sim.sign_cell) * tile + Vector2.ONE * tile * 0.5
		if view_rect.grow(tile).has_point(post):
			_shadow(post + Vector2(0, 9), 8.0)
			_object_art(SIGN_ART, post, SIGN_DRAW)
			_draw_sign_label(post)
	for cell: Vector2i in sim.village:
		var at: Vector2 = Vector2(cell) * tile + Vector2.ONE * tile * 0.5
		if not view_rect.grow(tile * 2.0).has_point(at):
			continue
		var piece: int = int(sim.village[cell])
		if piece < 0 or piece >= VILLAGE_ART.size():
			continue
		_shadow(at + Vector2(0, 10), 12.0)
		_object_art(VILLAGE_ART[piece], at, VILLAGE_DRAW[piece])
		if piece != Defs.VILLAGE_FIRE:
			continue
		# Somebody keeps this lit. It is the only warm light out here and it is
		# what makes the square read as a place rather than as ruins.
		var beat: float = 1.0 + sin(pulse * 2.4) * 0.06
		draw_circle(at, 26.0 * beat, Color(1.0, 0.66, 0.30, 0.10))
		draw_circle(at, 15.0 * beat, Color(1.0, 0.72, 0.36, 0.13))

## What the board says, on a plate above it.
##
## Drawn in the world rather than on the HUD: it belongs to the post, and a line
## about a place that follows the camera is a line about the screen. The plate is
## the same idea as the key caps over her head -- this sits over snow, over fog
## and over the amber pool, and has to be legible on all three.
func _draw_sign_label(post: Vector2) -> void:
	if sign_label <= 0.01:
		return
	var fade: float = clampf(sign_label, 0.0, 1.0)
	var font: Font = UIFont.FONT
	var width: float = font.get_string_size(Defs.SIGN_LINE,
		HORIZONTAL_ALIGNMENT_LEFT, -1, SIGN_TEXT).x
	var box := Rect2(post.x - width * 0.5 - 7.0, post.y - 40.0,
		width + 14.0, float(SIGN_TEXT) + 9.0)
	draw_rect(box, Color(0.04, 0.05, 0.09, 0.78 * fade))
	draw_rect(box, Color(Defs.COL_CORE.r, Defs.COL_CORE.g, Defs.COL_CORE.b,
		0.55 * fade), false, 1.0)
	draw_string(font, Vector2(box.position.x + 7.0, box.end.y - 6.0),
		Defs.SIGN_LINE, HORIZONTAL_ALIGNMENT_LEFT, -1, SIGN_TEXT,
		Color(Defs.COL_TEXT.r, Defs.COL_TEXT.g, Defs.COL_TEXT.b, fade))

func _draw_debris(tile: float) -> void:
	for cell: Vector2i in sim.debris:
		var at: Vector2 = Vector2(cell) * tile + Vector2.ONE * tile * 0.5
		if not view_rect.grow(tile).has_point(at):
			continue
		_shadow(at + Vector2(0, 8), 10.0)
		var shape: int = clampi(int(sim.debris[cell]), 0, DEBRIS_ART.size() - 1)
		_object_art(DEBRIS_ART[shape], at, DEBRIS_DRAW)
		if cell == sim.debris_cell and sim.debris_progress > 0.0:
			draw_arc(at, 16.0, 0.0, TAU, 32, Color(0.02, 0.04, 0.08, 0.55), 3.0)
			draw_arc(at, 16.0, -PI * 0.5,
				-PI * 0.5 + TAU * clampf(sim.debris_progress, 0.0, 1.0),
				32, Defs.COL_CORE, 3.0, true)

## The cats still in the ice. Drawn from the same rect a walking cat is drawn
## from, so the one that wakes up stands exactly where the block was: the last
## frozen stage and the first standing frame have to be the same animal in the
## same place, and computing that here separately is what let the carried cat
## drift off its anchor for a release.
func _draw_frozen(tile: float) -> void:
	for cell: Vector2i in sim.frozen_cats:
		# Its cell plus however far it has slid out of it. A block on a belt is
		# between two cells for most of the crossing, and drawing it on the grid
		# would make the belt look like it teleports its cargo one tile at a time.
		var at: Vector2 = sim.frozen_at(cell)
		if not view_rect.grow(tile).has_point(at):
			continue
		var progress: float = sim.frozen_cats[cell]
		# Meltwater, under the block and under its shadow. It is the only thing
		# on screen that says the ice is going: the four stages are three seconds
		# apart, and between them a player who has just put a cat down would have
		# nothing at all to look at.
		if progress > 0.0:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, Defs.SHADOW_SQUASH))
			draw_circle(Vector2(at.x, (at.y + 10.0) / Defs.SHADOW_SQUASH),
				7.0 + 9.0 * progress, Color(Defs.COL_ICE, 0.16 + 0.24 * progress))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_shadow(at + Vector2(0, 9), 9.0)
		var block: Rect2 = cat_rect(at, 1.0, false, 0.0)
		var stage: int = Sim.frozen_stage(progress)
		var region := Rect2(float(stage) * CAT_CELL, 0.0, CAT_CELL, CAT_CELL)
		draw_texture_rect_region(CAT_FREEZE_SHEET, block, region, Color.WHITE)

func _draw_food_bin(tile: float) -> void:
	if not sim.food_placed:
		return
	var at: Vector2 = Vector2(sim.food_cell) * tile + Vector2.ONE * tile * 0.5
	_shadow(at + Vector2(0, 10), 10.0)
	_object_art(FOOD_BIN_ART, at, FOOD_BIN_DRAW)
	# The count is drawn after the animals -- see _draw_machine_marks.


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
		# Every machine that produces something says where it goes, over the cats
		# and outlined. A cat is nearly sixty pixels tall standing on the centre
		# these are measured from, so an arrow drawn underneath is invisible in
		# exactly the case where the machine is running.
		if machine.type == Defs.M_MINER:
			_draw_output_arrow(on, centre, machine.dir, MINER_ARROW_LIFT, MINER_ARROW_LENGTH)
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
## The number belongs to the bin, so it is asked as one question rather than
## checked inside the paint -- a test can read a predicate and cannot read a
## `return` in the middle of a draw call.
func shows_food_count() -> bool:
	return sim != null and sim.food_placed

func _draw_food_count(on: CanvasItem, tile: float) -> void:
	# No bin, no number. The bin stopped being placed at the start in 0.20.74 --
	# a feeding station standing on the map four days before a cat gets hungry is
	# an answer parked next to a problem that has not happened -- but this drew
	# `sim.food` at `sim.food_cell` regardless, so a bare 200 floated in the snow
	# southwest of the base with nothing under it to say what it counted.
	if not shows_food_count():
		return
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
	# A warm pool under the machine, kept well inside the cell now that the art
	# has its own edges. At 19 it reached past them, so a run of belts was a line
	# of overlapping orange discs on the snow rather than a lit machine.
	draw_circle(c, 13.0, Color(Defs.COL_BELT_GLOW.r, Defs.COL_BELT_GLOW.g, Defs.COL_BELT_GLOW.b,
		0.16 * (1.0 - frost) + 0.03))
	var tint: Color = Color.WHITE.lerp(Defs.COL_FROST_TINT, frost)
	var inflow: Vector2i = _belt_inflow(machine)
	if inflow == machine.dir:
		_tile_art(BELT_STRAIGHT_ART, px, tile, machine.dir, false, tint)
	else:
		# The drawn corner turns clockwise on screen. A belt that turns the other
		# way is the same picture mirrored across the way it travels, which the
		# transform does for free -- and a second corner drawing would be a second
		# thing to keep in step with the first.
		var clockwise: bool = Vector2i(-inflow.y, inflow.x) == machine.dir
		_tile_art(BELT_CORNER_ART, px, tile, inflow, not clockwise, tint)
	var dir := Vector2(machine.dir)
	var perp := Vector2(-dir.y, dir.x)
	# Scrolling chevrons: the cheapest possible "this is moving" signal.
	#
	# Half the size they were and half as opaque. They were drawn for a plain
	# dark rectangle, and against one they were the only thing on the belt; over
	# art with rails and bolts the same marks covered all of it, so a run read as
	# arrows painted on a road rather than as a surface going somewhere. What has
	# to be visible is that it moves -- and movement is legible at an opacity a
	# static mark would disappear at.
	var grade: float = float(Defs.BELT_TIERS[machine.tier]["speed"])
	for index in 2:
		var offset: float = fmod(pulse * Defs.BELT_SPEED * grade * 0.5 + float(index) * 0.5, 1.0)
		var along: float = (offset - 0.5) * tile
		var head: Vector2 = c + dir * (along + 2.5)
		var tail: Vector2 = c + dir * (along - 1.0)
		var chev: Color = Defs.COL_BELT_CHEVRON if frost <= 0.0 else Defs.COL_FROZEN_CHEVRON
		chev = Color(chev.r, chev.g, chev.b, chev.a * 0.55)
		draw_line(tail + perp * 3.0, head, chev, 1.4)
		draw_line(tail - perp * 3.0, head, chev, 1.4)

func _draw_belt_items(machine: Sim.Machine, px: Vector2, tile: float) -> void:
	var c: Vector2 = px + Vector2.ONE * tile * 0.5
	var dir := Vector2(machine.dir)
	# On a corner the first half of the cell belongs to the way the item came in,
	# so a crystal follows the belt round instead of cutting across the elbow and
	# leaving the surface it is supposed to be riding on.
	var entry := Vector2(_belt_inflow(machine))
	for item: Dictionary in machine.items:
		var t: float = float(item["t"])
		var at: Vector2 = c + (entry if t < 0.5 else dir) * (t - 0.5) * tile
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


## One painting per piece, fitted to the cells it stands on and standing on the
## bottom of them.
func _draw_room_pieces(tile: float) -> void:
	for piece: Dictionary in Defs.ROOM_PIECES:
		var art: Texture2D = ROOM_ART.get(int(piece["id"]), null)
		if art == null:
			continue
		var origin: Vector2 = Vector2(Defs.room_to_world(piece["cell"])) * tile
		var rect := Rect2(origin, Vector2(piece["size"]) * tile)
		var scale: float = minf(rect.size.x / float(art.get_width()),
			rect.size.y / float(art.get_height()))
		var drawn := Vector2(float(art.get_width()), float(art.get_height())) * scale
		var at := Vector2(rect.get_center().x - drawn.x * 0.5, rect.end.y - drawn.y)
		_shadow(Vector2(rect.get_center().x, rect.end.y - 3.0), drawn.x * 0.42)
		draw_texture_rect(art, Rect2(at, drawn), false)
