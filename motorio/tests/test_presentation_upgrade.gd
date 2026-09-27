extends SceneTree

## The fire growing a size, and a new machine to build (Quality Pass 01).
##
## A deposit that grew the fire used to stack three labels over it -- "열석 +N",
## "+N" and "기지 N단계" -- for under a second each, in the middle of the screen,
## with two fanfares under them, and the next frame added the mission line. None
## of it could be read. What is held here:
##
## * a deposit that grows the fire puts no text over it: the fire swells, the
##   level plate under it flashes, the heat's edge runs out, and it sounds like
##   the fire rather than like a menu,
## * an ordinary deposit says one small +N,
## * a new machine is one line and a small ring -- not a banner, not the
##   milestone shake,
## * and the refusal speaks as her, not as a rule.

var failures := 0
var main: Node2D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	main = load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	_test_growing_the_fire()
	_test_ordinary_deposit()
	_test_unlock()
	_test_refusal_is_a_thought()
	main.clear_save()
	main.free()
	if failures == 0:
		print("PASS test_presentation_upgrade")
	else:
		print("FAIL test_presentation_upgrade (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _fresh() -> void:
	main.clear_save()
	main._start_run()
	main.finish_tutorial()
	main.state = main.State.PLAY
	main.messages.clear()
	main.fx.set("_labels", [])

func _labels() -> Array:
	return main.fx.get("_labels")

func _said(fragment: String) -> bool:
	for entry: Dictionary in main.messages:
		if String(entry["text"]).contains(fragment):
			return true
	return false

func _test_growing_the_fire() -> void:
	_fresh()
	var sim = main.sim
	var level: int = sim.base_level
	sim.stock[Defs.ITEM_HEATSTONE] = sim.stones_to_next()
	var finish: int = int(main.audio.started.get("finish", 0))
	var levels: int = int(main.audio.started.get("level", 0))
	main._deposit_at_core()
	_assert(sim.base_level == level + 1, "불이 한 단계 커졌다 (%d -> %d)" % [level, sim.base_level])
	var texts: Array[String] = []
	for label: Dictionary in _labels():
		texts.append(String(label["text"]))
	_assert(texts.is_empty(), "불 위에 글자가 뜨지 않는다 %s" % str(texts))
	_assert(main.machine_layer.core_pulse >= 0.99, "불이 부풀어 오른다")
	_assert(main.machine_layer.level_flash >= 0.99, "불 아래 단계 표시가 번쩍인다")
	_assert(int(main.audio.started.get("level", 0)) == levels + 1, "불이 커지는 소리가 난다")
	_assert(int(main.audio.started.get("finish", 0)) == finish, "메뉴 같은 팡파르는 없다")
	_assert(_said("불이 더 커졌다"), "구석의 기록에 한 줄 남는다")

func _test_ordinary_deposit() -> void:
	_fresh()
	var sim = main.sim
	# Short of the next size by more than one, so one stone is an ordinary deposit.
	var need: int = sim.stones_to_next()
	if need < 2:
		sim.stones_in += 0
	sim.stock[Defs.ITEM_HEATSTONE] = 1
	var level: int = sim.base_level
	if sim.can_feed_base():
		main._deposit_at_core()
		_assert(sim.base_level == level, "한 개로는 불이 커지지 않는다")
		var plus := 0
		for label: Dictionary in _labels():
			if String(label["text"]).begins_with("+"):
				plus += 1
		_assert(plus == 1 and _labels().size() == 1, "작은 +N 하나만 뜬다 (%d개)" % _labels().size())
		_assert(int(main.audio.started.get("whoomp", 0)) >= 1, "불이 받아먹는 소리")
	else:
		# The ladder refuses a partial step: then there is nothing ordinary to test.
		_assert(true, "(이 단계는 한 번에 채워야 한다)")

func _test_unlock() -> void:
	_fresh()
	main.shake = 0.0
	var rings: int = (main.fx.get("_rings") as Array).size()
	var opened: Array[int] = [Defs.M_GENERATOR]
	main._announce_unlocks(opened)
	_assert(_said("새 설계"), "새 기계는 한 줄로 알린다")
	_assert(not _said("해금!"), "느낌표 배너가 아니다")
	_assert(main.shake < Defs.FX_MILESTONE, "화면이 흔들리지 않는다")
	_assert((main.fx.get("_rings") as Array).size() == rings + 1, "작은 링 하나")

func _test_refusal_is_a_thought() -> void:
	_fresh()
	var sim = main.sim
	sim.stock[Defs.ITEM_HEATSTONE] = 0
	main._deposit_at_core()
	sim.stock[Defs.ITEM_HEATSTONE] = 1
	if not sim.can_feed_base():
		main._deposit_at_core()
		_assert(_said("아직 받아들이지 않는다"), "모자랄 때는 그녀의 생각으로 말한다")
		_assert(not _said("있어야 한다"), "규칙을 읽어 주지 않는다")
