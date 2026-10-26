class_name StressIsland
extends RefCounted

## A big, busy island for measuring and for the "large island" demo: a
## side x side square of land, a building on one tile in three -- only the
## four kinds the player places (farm, lumberyard, mine, lab) -- and many
## Momo, each watching its own zone of tiles: one tile, a pair, 2x2, 2x3, 3x3,
## a 3x4 strip, 4x4, or none at all (they roam), zones overlapping. Every Momo
## takes one of the four plain routes. Built with the real commands and the
## same numbers every time, so the result of running it is a fixed point the
## benchmarks compare against (tools/bench/sim_bench.gd).

## The demo's side: big enough to need culling on a phone, small enough to
## start in a moment.
const DEMO_SIDE := 24
const KINDS := ["farm", "lumberyard", "mine", "research"]
const ZONES := [Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3), Vector2i(3, 3), Vector2i(3, 4), Vector2i(4, 4), Vector2i.ZERO]
const ROUTES := ["nearest", "rows", "zigzag", "zone"]


## `momos` < 0: one Momo per nine tiles.
static func build(side: int, momos: int = -1, data: GameData = null) -> Simulation:
	var sim := Simulation.new_game(data)
	var world: WorldSystem = sim.system(&"world")
	for x in side:
		for y in side:
			world.add_land(Vector2i(x, y))
	var bs: BuildingSystem = sim.system(&"buildings")
	var k := 0
	for y in side:
		for x in side:
			if (x + y * 7) % 3 != 0:
				continue
			bs.place_instant(KINDS[k % KINDS.size()], Vector2i(x, y))
			k += 1
	# Far enough along that every Momo may watch 16 tiles.
	(sim.system(&"progression") as ProgressionSystem).add_exp(200000, "stress")
	var research: ResearchSystem = sim.system(&"research")
	for id: String in ["momo_reach", "momo_wide_reach"]:
		# Researched once, as a finished research leaves it.
		research.completed[id] = 0
		research.bought[id] = 1
		research.unlocked[id] = true
	var ms: MomoSystem = sim.system(&"momo")
	var count := maxi(side * side / 9, 4) if momos < 0 else maxi(momos, 1)
	for i in count:
		# The first stands where a new island's Momo used to (Step 53: a new
		# game has none -- this island brings its own, every one of them).
		var id := ms.add_momo(Vector2(0.55, 1.35) if i == 0 else Vector2(float(i % side) + 0.5, float((i * 3) % side) + 0.5))
		var zone: Vector2i = ZONES[i % ZONES.size()]
		# Origins walk the island at a stride that is not a multiple of the
		# zone sizes, so zones overlap here and there.
		var ox := (i * 5) % side
		var oy := ((i * 5) / side * 3 + i % 3) % side
		var cells: Array = []
		for dx in zone.x:
			for dy in zone.y:
				cells.append([mini(ox + dx, side - 1), mini(oy + dy, side - 1)])
		if not cells.is_empty():
			sim.execute({"type": "momo.watch", "momo": id, "cells": cells, "op": "add"})
		sim.execute({"type": "momo.route", "momo": id, "route": ROUTES[i % ROUTES.size()]})
	return sim
