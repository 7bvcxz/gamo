extends SceneTree

## What a node looks like is what it is (Factory Interaction Pass 01).
##
## Displayed type == logical type == what comes out. For every node of forty
## worlds, the sheet the ground draws on each of its cells is the one the item
## table gives its type. And the seam materials can be told apart at all: their
## item colours (every dot, drop, belt item, counter and map mark) and the bodies
## of their seam pictures differ by a clear margin. Heat stone and copper used to
## be (255,122,48) and (252,104,46), with seam pictures of the same red-orange --
## the North Star paints copper as red clusters, so heat stone was what "looked
## like copper".

var failures := 0

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _finish(name: String) -> void:
	if failures == 0:
		print("PASS %s" % name)
	else:
		print("FAIL %s (%d)" % [name, failures])
	quit(failures)

func _seams() -> Array[int]:
	var out: Array[int] = []
	for id: int in Defs.item_ids():
		if Defs.ore_output(id) >= 0:
			out.append(id)
	return out

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var mismatch := 0
	var nodes := 0
	for index in 40:
		var sim := Sim.new()
		sim.setup(5100 + index)
		for origin: Vector2i in sim.ore_nodes:
			nodes += 1
			var type: int = int(sim.ore_nodes[origin])
			var want: String = Defs.item_atlas(type)
			for cell: Vector2i in Sim.ore_cells(origin):
				var atlas: Texture2D = GroundLayer.ore_atlas_at(sim, cell)
				if atlas == null or not atlas.resource_path.ends_with(want):
					mismatch += 1
		sim.free()
	_assert(nodes > 0 and mismatch == 0, "%d개 노드의 모든 칸이 제 종류의 그림으로 그려진다 (%d건 불일치)" % [nodes, mismatch])
	# The seams the world makes: a retired material's colour belongs to saves
	# written before it retired, not to anything on the snow.
	var seams: Array[int] = []
	for id: int in _seams():
		if not Defs.item_retired(id):
			seams.append(id)
	for a in seams.size():
		for b in range(a + 1, seams.size()):
			var ca: Color = Defs.ITEM_COLORS[seams[a]]
			var cb: Color = Defs.ITEM_COLORS[seams[b]]
			var d: float = Vector3(ca.r - cb.r, ca.g - cb.g, ca.b - cb.b).length() * 255.0
			_assert(d >= 60.0, "%s 와 %s 의 색이 구별된다 (거리 %.0f)" % [Defs.ITEM_NAMES[seams[a]], Defs.ITEM_NAMES[seams[b]], d])
	var bodies: Dictionary = {}
	for id: int in seams:
		bodies[id] = _body(Defs.item_atlas(id))
	for a in seams.size():
		for b in range(a + 1, seams.size()):
			var d: float = (bodies[seams[a]] - bodies[seams[b]]).length() * 255.0
			_assert(d >= 25.0, "%s 와 %s 의 광맥 그림 몸통이 구별된다 (거리 %.0f)" % [Defs.ITEM_NAMES[seams[a]], Defs.ITEM_NAMES[seams[b]], d])
	_finish("test_ore_visual_matches_logical_type")

## The mean colour of a seam sheet's mid-dark pixels: the ore's body, not its
## highlights or the neutral ground round it.
func _body(file: String) -> Vector3:
	var image := Image.load_from_file(ProjectSettings.globalize_path("res://assets/tiles/" + file))
	image.convert(Image.FORMAT_RGB8)
	var sum := Vector3.ZERO
	var count := 0
	for y in image.get_height():
		for x in image.get_width():
			var c: Color = image.get_pixel(x, y)
			if c.v > 0.12 and c.v < 0.62:
				sum += Vector3(c.r, c.g, c.b)
				count += 1
	return sum / float(maxi(count, 1))
