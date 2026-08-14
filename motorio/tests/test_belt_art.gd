extends SceneTree

## Which picture a belt draws, given what feeds it.
##
## Separate from test_belt.gd, which is about belts *moving* -- specifically
## that they move before any generator exists. Two files because they guard
## unrelated things and that one has a standing rule of its own: nothing in it
## may build a generator.
##
## A belt has one stored direction and that is where it sends things. Which way
## things *arrive* is not stored anywhere -- it is read off the neighbours every
## frame -- because laying a belt changes what its neighbour looks like, and
## there is no moment at which anything would remember to go and update it.
##
## That makes it exactly the kind of rule that is right when written and wrong
## three features later, so it is pinned here: every arrangement of feeders, and
## what the layer decides to draw.

const MachineLayerScript := preload("res://scripts/MachineLayer.gd")

var failures := 0

const EAST := Vector2i(1, 0)
const SOUTH := Vector2i(0, 1)
const WEST := Vector2i(-1, 0)
const NORTH := Vector2i(0, -1)

func _init() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_run()
	main.finish_tutorial()

	var sim: Sim = main.sim
	var layer: MachineLayer = main.machine_layer

	_alone(sim, layer)
	_straight(sim, layer)
	_corners(sim, layer)
	_merge(sim, layer)
	_art(layer)

	print("BELT ART: %s" % ("PASS" if failures == 0 else "FAIL %d" % failures))
	quit(failures)

## A belt with nothing behind it draws straight. The head of a line is a real and
## common state -- a miner drops onto it, a cat drops onto it -- and it must not
## look like a corner just because no belt happens to feed it.
func _alone(sim: Sim, layer: MachineLayer) -> void:
	var belt: Sim.Machine = _belt(sim, Vector2i(4, 0), EAST)
	_check(layer._belt_inflow(belt) == EAST, "먹이는 벨트가 없으면 직선")

## Fed from behind: straight, for all four headings, so no direction is special.
func _straight(sim: Sim, layer: MachineLayer) -> void:
	for heading: Vector2i in Defs.STEPS:
		_clear(sim)
		var cell := Vector2i(10, 10)
		var belt: Sim.Machine = _belt(sim, cell, heading)
		_belt(sim, cell - heading, heading)
		_check(layer._belt_inflow(belt) == heading, "%s 뒤에서 들어오면 직선" % heading)

## Fed from a side: a corner, and the inflow reported is the way the item was
## travelling rather than where the feeder sits. Both turns are checked, because
## one of them is the drawing and the other is that drawing mirrored, and a sign
## error would look right in exactly half of all factories.
func _corners(sim: Sim, layer: MachineLayer) -> void:
	for heading: Vector2i in Defs.STEPS:
		for turn: int in [1, -1]:
			_clear(sim)
			var cell := Vector2i(10, 10)
			# Arriving travelling `incoming`, leaving travelling `heading`.
			var incoming := Vector2i(heading.y * turn, -heading.x * turn)
			var belt: Sim.Machine = _belt(sim, cell, heading)
			_belt(sim, cell - incoming, incoming)
			var inflow: Vector2i = layer._belt_inflow(belt)
			_check(inflow == incoming,
				"%s에서 들어와 %s로 나가면 코너 (얻은 값 %s)" % [incoming, heading, inflow])
			# And the handedness the layer will draw it with. Clockwise on screen
			# is `(-y, x)`; the art is drawn for that case and mirrored for the
			# other, so this is the value that decides which.
			var clockwise: bool = Vector2i(-inflow.y, inflow.x) == heading
			_check(clockwise == (turn == 1),
				"%s->%s 의 회전 방향" % [incoming, heading])

## Two lines merging. The straight feeder wins: a corner drawing would say
## everything here came from the side, and the one thing this cell has to
## communicate is which way it sends things on.
func _merge(sim: Sim, layer: MachineLayer) -> void:
	_clear(sim)
	var cell := Vector2i(10, 10)
	var belt: Sim.Machine = _belt(sim, cell, EAST)
	_belt(sim, cell - EAST, EAST)      # from behind
	_belt(sim, cell - SOUTH, SOUTH)    # and from the side
	_check(layer._belt_inflow(belt) == EAST, "합류하면 직선이 이긴다")

	# A neighbour that is a belt but points elsewhere is not a feeder.
	_clear(sim)
	var lone: Sim.Machine = _belt(sim, cell, EAST)
	_belt(sim, cell - SOUTH, NORTH)    # points away from us
	_check(layer._belt_inflow(lone) == EAST, "다른 곳을 보는 이웃은 먹이지 않는다")

## The tiles themselves. Built by tools/sprite/build_belt.py, which proves the
## seams; what this proves is that the files the game loads are the ones it
## built, at the size it expects. A straight tile that quietly became 64 would
## still draw -- blurrier, and nobody would know why.
func _art(layer: MachineLayer) -> void:
	var expected: int = Defs.TILE * 3
	for entry: Array in [
		["belt_straight", MachineLayerScript.BELT_STRAIGHT_ART],
		["belt_corner", MachineLayerScript.BELT_CORNER_ART],
		["splitter", MachineLayerScript.SPLITTER_ART],
	]:
		var texture: Texture2D = entry[1]
		_check(texture.get_width() == expected and texture.get_height() == expected,
			"%s 가 %dpx (얻은 값 %dx%d)"
				% [entry[0], expected, texture.get_width(), texture.get_height()])

	# The seam, from the game's side. The straight tile's two ends have to be the
	# same pixels or a run of belts has a line across it every cell.
	var image: Image = MachineLayerScript.BELT_STRAIGHT_ART.get_image()
	var worst := 0
	for y in image.get_height():
		var left: Color = image.get_pixel(0, y)
		var right: Color = image.get_pixel(image.get_width() - 1, y)
		for channel: int in 4:
			worst = maxi(worst, int(abs(left[channel] - right[channel]) * 255.0))
	_check(worst == 0, "직선 타일의 양 끝이 같다 (최대 차이 %d)" % worst)

func _belt(sim: Sim, cell: Vector2i, dir: Vector2i) -> Sim.Machine:
	sim.machines.erase(cell)
	var machine := Sim.Machine.new()
	machine.type = Defs.M_BELT
	machine.cell = cell
	machine.dir = dir
	sim.machines[cell] = machine
	return machine

func _clear(sim: Sim) -> void:
	for cell: Vector2i in sim.machines.keys():
		if sim.machines[cell].type == Defs.M_BELT:
			sim.machines.erase(cell)

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	print("  FAIL: ", message)
	failures += 1
