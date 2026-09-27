extends SceneTree

## One language for everything in the world that takes a moment, and the tool
## that comes out of it (Quality Pass 01).
##
## * Her swing at a seam used to be drawn by hand beside the shared ring; it is
##   the shared ring now, in its high-contrast variant.
## * A frozen cat thawing by the fire was the one wait with nothing closing over
##   it -- the meltwater spreads, but does not say how long. It wears the ring.
## * The crafted pickaxe: into her hand at once, the flight and the chime, and
##   the mark over the nearest seam -- which only the old pickaxe off the snow
##   ever set, so the one made at the fire never showed where to use it.
## * And crafting says nothing in the middle of the screen (test_workbench holds
##   the rest of that).

var failures := 0
var main: Node2D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	main = load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	_test_hand_ring_is_the_shared_ring()
	_test_thaw_wears_the_ring()
	_test_pickaxe_from_the_fire()
	main.clear_save()
	main.free()
	if failures == 0:
		print("PASS test_presentation_progress")
	else:
		print("FAIL test_presentation_progress (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)

func _body_of(source: String, header: String) -> String:
	var start: int = source.find(header)
	if start < 0:
		return ""
	var next: int = source.find("\nfunc ", start + header.length())
	return source.substr(start, (next if next > 0 else source.length()) - start)

func _test_hand_ring_is_the_shared_ring() -> void:
	var layer: String = FileAccess.get_file_as_string("res://scripts/MachineLayer.gd")
	var hand: String = _body_of(layer, "func _draw_hand_progress")
	_assert(hand.contains("WorldProgress.draw_strong"), "곡괭이 진행은 공용 링을 지난다")
	_assert(not hand.contains("draw_arc("), "손으로 그린 호가 남아 있지 않다")

func _test_thaw_wears_the_ring() -> void:
	main.clear_save()
	main._start_run()
	main.finish_tutorial()
	main.state = main.State.PLAY
	var sim = main.sim
	var layer = main.machine_layer
	# Beside the base, where the fire reaches it.
	var near: Vector2i = sim.core_cell + Vector2i(0, 6)
	sim.frozen_cats[near] = 0.0
	_assert(not layer.thaw_ring_visible(near), "녹기 전에는 링이 없다")
	for step in 60:
		sim.tick(0.1)
	var progress: float = float(sim.frozen_cats.get(near, 0.0))
	_assert(progress > 0.0, "불 옆의 얼음은 녹는다 (%.2f)" % progress)
	_assert(layer.thaw_ring_visible(near), "녹는 동안 링이 닫혀 간다")
	# Far out in the cold: no ring, because nothing is happening.
	var far: Vector2i = sim.core_cell + Vector2i(120, 0)
	sim.frozen_cats[far] = 0.0
	for step in 10:
		sim.tick(0.1)
	_assert(not layer.thaw_ring_visible(far), "추운 곳의 얼음에는 링이 없다")

func _craft_index(id: String) -> int:
	for index in Defs.BASE_CRAFTS.size():
		if String(Defs.BASE_CRAFTS[index]["id"]) == id:
			return index
	return -1

func _test_pickaxe_from_the_fire() -> void:
	main.clear_save()
	main._start_run()
	main.state = main.State.PLAY
	main.sim.search_kit()
	main.sim.shelter_placed = true
	main.sim.shelter_cell = main.sim.core_cell + Defs.SHELTER_CELL
	main.fx.clear_flights()
	main.messages.clear()
	main.pickaxe_hint_until = 0.0
	var chimes: int = int(main.audio.started.get("chime", 0))
	main.craft_selected(_craft_index("pickaxe"))
	# While the fire works, the middle of the screen is empty.
	_assert(main.craft_progress() >= 0.0, "불 위에서 만들어진다")
	var left := 3.2
	while left > 0.0:
		main._process_play(1.0 / 30.0)
		left -= 1.0 / 30.0
	_assert(main.holding_pickaxe(), "다 되는 순간 곡괭이가 손에 있다")
	_assert(main.pickaxe_hint_until > 0.0, "그리고 가장 가까운 광맥에 표시가 선다")
	_assert(main.fx.flights() == 1, "곡괭이가 불에서 그녀에게 날아온다")
	for step in 40:
		main.fx._process(1.0 / 30.0)
	_assert(int(main.audio.started.get("chime", 0)) > chimes, "닿으면 작고 밝은 차임이 울린다")
	_assert(main.hud.slot_pulse_left(main.TOOLS.find(main.TOOL_PICKAXE)) > 0.0, "1번 칸이 반짝인다")
