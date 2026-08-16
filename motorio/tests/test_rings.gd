extends SceneTree

## The base ladder has to pay for itself.
##
## Every upgrade is bought with heat stone, so a step that reaches no new heat
## stone makes the next step further away than the one before it. Heat stone
## used to live in a single ring from 3 to 6 -- inside the opening circle -- and
## counted across forty seeds, radius 13 and radius 15 held exactly the same
## seams as radius 11. The third upgrade cost 15 heat stone and the fourth cost
## 27, and neither returned any. "Why upgrade the base" had no answer because
## there was none.
##
## Nothing in the code was wrong; the world simply had nothing in it past the
## first circle. That is not visible from any one seed and not visible from
## reading either, so it is counted here across many.

var failures := 0
const SEEDS := 40

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var radii: Array[float] = []
	for level in Defs.BASE_LEVELS:
		radii.append(float(level["radius"]))

	var heat := {}
	var rich := {}
	var copper := {}
	var belt_buildable := 0
	for index in SEEDS:
		var sim := Sim.new()
		sim.setup(7000 + index)
		for r: float in radii:
			var key := str(r)
			heat[key] = int(heat.get(key, 0))
			rich[key] = int(rich.get(key, 0))
			copper[key] = int(copper.get(key, 0))
			for cell: Vector2i in sim.ore:
				if Vector2(cell - sim.core_cell).length() > r:
					continue
				match int(sim.ore[cell]):
					Defs.ITEM_HEATSTONE:
						heat[key] += 1
						if int(sim.purity.get(cell, 0)) > Defs.PURITY_NORMAL:
							rich[key] += 1
					Defs.ITEM_COPPER:
						copper[key] += 1
		if int(copper[str(radii[4])]) >= int(Defs.MACHINE_COSTS[Defs.M_BELT][Defs.ITEM_COPPER]):
			belt_buildable += 1
		sim.free()

	# --- Every step reaches more than the one before ---------------------------
	for index in range(1, radii.size()):
		var here: float = float(heat[str(radii[index])]) / float(SEEDS)
		var before: float = float(heat[str(radii[index - 1])]) / float(SEEDS)
		_assert(here > before + 1.0,
			"%d단계(%.0f칸)가 열석 광맥을 더 준다: %.1f → %.1f"
				% [index, radii[index], before, here])

	# --- And the grades exist ---------------------------------------------------
	# "Distance buys richness" is stated in Defs and was true of nothing: no heat
	# stone seam in any world was ever above 보통, because the grade line is at 11
	# and no heat stone reached it.
	_assert(float(rich[str(radii[3])]) / float(SEEDS) > 1.0,
		"3단계에서 풍부 이상 열석이 나온다: %.1f개" % (float(rich[str(radii[3])]) / float(SEEDS)))

	# --- Copper opens on the fourth upgrade, and opens all the way --------------
	# Not "on average". The card says the fourth circle is where copper is; a
	# promise kept in most runs is a different game for the rest of them.
	_assert(copper[str(radii[3])] == 0,
		"3단계 안에는 구리가 없다: %d개" % int(copper[str(radii[3])]))
	_assert(belt_buildable == SEEDS,
		"4단계에서 벨트를 지을 만큼 구리가 있다: %d/%d회차" % [belt_buildable, SEEDS])

	if failures == 0:
		print("RINGS: PASS")
	else:
		print("RINGS: FAIL (%d)" % failures)
	quit(failures)

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		print("  FAIL %s" % label)
