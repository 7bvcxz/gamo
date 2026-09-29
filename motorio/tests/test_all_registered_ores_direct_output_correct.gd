extends SceneTree

## Every seam material in the item table comes out of its own node by hand, and
## nothing else does (Factory Interaction Pass 01). Walks the table, so a seam
## added later is covered by its row. Through Main, the pickaxe held the way she
## holds it, beside a node of another kind.

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
	_assert(seams.size() >= 3, "광맥 재료가 셋 이상 등록돼 있다 (%s)" % str(seams))
	for index in seams.size():
		var kind: int = seams[index]
		var decoy: int = seams[(index + 1) % seams.size()]
		OrePost.fresh(main)
		var node: Vector2i = OrePost.field(main, kind, Vector2i(20, -4), decoy)
		var stance: Dictionary = OrePost.stances(node)[0]
		var got: Dictionary = OrePost.swing(main, stance["at"], stance["facing"], Defs.HAND_MINE_PERIOD * 1.6)
		_assert(got.keys() == [kind], "%s 노드를 곡괭이로 캐면 %s 만 나온다 (%s)"
			% [Defs.ITEM_NAMES[kind], Defs.ITEM_NAMES[kind], str(got)])
		_assert(Defs.ore_output(kind) == kind, "%s 의 산출은 표가 정한다" % Defs.ITEM_NAMES[kind])
	main.clear_save()
	main.free()
	_finish("test_all_registered_ores_direct_output_correct")
