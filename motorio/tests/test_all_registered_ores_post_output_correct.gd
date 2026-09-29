extends SceneTree

## Every seam material in the item table comes out of a mining post built on its
## node, and nothing else does -- for every kind of rig (Factory Interaction
## Pass 01). Built through the gun the way she builds it, beside a node of
## another kind, with a cat at work in the running game.

const OrePost := preload("res://tests/helpers/ore_post.gd")

var failures := 0
var main: Node2D

func _initialize() -> void:
	call_deferred("_run")

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

func _main() -> void:
	main = load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame

## Every material the item table calls a seam (a row with a seam sheet).
func _seams() -> Array[int]:
	var out: Array[int] = []
	for id: int in Defs.item_ids():
		if Defs.ore_output(id) >= 0:
			out.append(id)
	return out

func _run() -> void:
	await _main()
	var seams: Array[int] = _seams()
	for index in seams.size():
		var kind: int = seams[index]
		var decoy: int = seams[(index + 1) % seams.size()]
		for type: int in Defs.MINER_MACHINES:
			OrePost.fresh(main)
			var node: Vector2i = OrePost.field(main, kind, Vector2i(20, -4), decoy)
			var run: Dictionary = OrePost.run_post(main, node, type, 80.0)
			var label: String = "%s 위 %s" % [Defs.ITEM_NAMES[kind], Defs.MACHINE_NAMES[type]]
			_assert(bool(run["built"]) and run["anchor"] == node, "%s: 그 노드에 선다" % label)
			var out: Dictionary = run["out"]
			_assert(out.keys() == [kind], "%s: %s 만 나온다 (%s)" % [label, Defs.ITEM_NAMES[kind], str(out)])
	main.clear_save()
	main.free()
	_finish("test_all_registered_ores_post_output_correct")
