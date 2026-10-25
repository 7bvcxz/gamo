extends RefCounted

## Capture scenario: a 3x3 island with crates and Momo standing on cells in
## front of and behind each other, to check depth order by eye.

func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	var world: WorldSystem = sim.system(&"world")
	for cell: Vector2i in [Vector2i(2, 0), Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)]:
		world.add_land(cell)
	var lib := SpriteLibrary.load_atlas()
	var layer: EntityLayer = main.get("entities")
	for spec: Array in [["prop_crate", Vector2(1.5, 0.5)], ["momo_front", Vector2(1.5, 1.2)], ["prop_crate", Vector2(0.5, 1.5)], ["momo_front", Vector2(2.4, 2.3)], ["prop_crate", Vector2(2.5, 1.5)]]:
		layer.add_entity(lib.make_sprite(spec[0]), spec[1])
	main.call("_layout")
