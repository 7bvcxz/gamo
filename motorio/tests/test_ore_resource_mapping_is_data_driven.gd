extends SceneTree

## What a seam yields comes from the item table, in one place, and the paths that
## mine do not name a material of their own (Factory Interaction Pass 01).
##
## `Defs.ore_output` is the table's answer (a row with a seam sheet yields
## itself; anything else, nothing). The pickaxe (`Sim.hand_mine`), the post
## (`Sim._tick_miner`) and the cat on a bare node (`Sim._cat_work`) each ask
## `ore_item`, and none of their bodies names an ITEM_ constant -- a fallback
## material in any of them is how a post once made crystal out of nothing.

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

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for id: int in Defs.item_ids():
		var seam: bool = Defs.item_atlas(id) != ""
		_assert(Defs.ore_output(id) == (id if seam else -1), "%s: 표가 산출을 정한다" % Defs.ITEM_NAMES[id])
	var source: String = FileAccess.get_file_as_string("res://scripts/Sim.gd")
	for fn: String in ["hand_mine", "_tick_miner", "_cat_work"]:
		var body: String = _body(source, fn)
		_assert(body != "", "%s 를 찾는다" % fn)
		_assert(body.contains("ore_item("), "%s 는 ore_item 에 묻는다" % fn)
		var regex := RegEx.new()
		regex.compile("ITEM_(?!STONE)[A-Z_]+")
		var named: Array = []
		for m: RegExMatch in regex.search_all(body):
			named.append(m.get_string())
		_assert(named.is_empty(), "%s 는 재료 이름을 직접 부르지 않는다 %s" % [fn, str(named)])
	_finish("test_ore_resource_mapping_is_data_driven")

## A function's body, from its line to the next top-level line.
func _body(source: String, fn: String) -> String:
	var start: int = source.find("func %s(" % fn)
	if start < 0:
		return ""
	var end: int = source.find("\nfunc ", start + 5)
	var text: String = source.substr(start, end - start if end > 0 else -1)
	var lines: PackedStringArray = text.split("\n")
	var code: Array[String] = []
	for line: String in lines:
		if not line.strip_edges().begins_with("#"):
			code.append(line)
	return "\n".join(code)
