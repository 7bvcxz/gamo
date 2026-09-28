extends Node
class_name Sim

## Pure simulation: the grid, machines, item flow and economy.
## It owns no rendering and no input, which keeps it testable headlessly and
## lets the view layers stay dumb. Items are plain data rather than physics
## bodies so that a few hundred of them cost almost nothing.

signal fuel_added(count: int, cell: Vector2i, item_type: int)
## Something arrived at the core and was put in the stores. Separate from
## `fuel_added` because arriving and being burned stopped being the same event.
signal item_delivered(item_type: int, cell: Vector2i)
## A recipe finished a cycle. Emitted per output item, so a recipe that makes
## three sends three -- the caller decides whether that is three sounds or one.
signal recipe_produced(cell: Vector2i, item_type: int, amount: int)
## A mining rig put an item out. Only the sound listens: the item itself is on
## the belt and the rig's flash already says so on screen.
signal machine_worked(cell: Vector2i, type: int)
signal machine_built(cell: Vector2i, type: int)
signal machine_removed(cell: Vector2i, type: int)
signal build_rejected(reason: String, cell: Vector2i)
signal warmth_changed(radius: float)
signal cat_adopted(total: int)
signal cat_thawed(total: int, at: Vector2)
## The base reaching the next step of BASE_LEVELS.
signal base_upgraded(level: int, radius: float)

## A cat worker. Miners cannot run without one standing at them, so the number
## of cats -- not the amount of heat -- is what gates automation.
## "Nothing here." The sentinel every cell-valued field already used.
const NONE := Vector2i(9999, 9999)

class Cat extends RefCounted:
	var pos := Vector2.ZERO
	## Which way the cat is drawn facing. Maintained by _step_toward, so it is
	## whatever direction the cat last actually moved in. It used to be derived
	## at draw time from a chain of "if the state is this, the goal is that",
	## which had to list every travelling state and did not: two of the five were
	## missing and those cats walked wherever they liked while facing front.
	var heading := Vector2.DOWN
	var state: int = Defs.CAT_IDLE
	var assigned := Vector2i(9999, 9999)   ## the miner cell this cat works
	## Hauling: which loose item it is going for, and what it is carrying.
	var haul_target := Vector2i(9999, 9999)
	## Which way it is strolling while idle, and how long the current pause or
	## stroll has left. Zero means standing.
	## How long the current pause has left. Strolling is not a flag: an idle cat
	## with a route is strolling, which is one fewer thing that can disagree with
	## where the animal actually is.
	var wander_timer: float = 0.0
	## Seconds before this cat has come through the shelter door. Zero means it
	## is already in the room. Not saved: it is a second and a half of an evening
	## and never a fact about the world.
	var entering: float = 0.0
	## And seconds before it wakes up in the morning. The evening is a queue at
	## the door; the morning is the opposite shape -- everyone is already there,
	## asleep where they dropped, and they get up one at a time.
	var waking: float = 0.0
	## The route being walked and the goal it was built for. Cats path around the
	## things Grim cannot walk through, so a straight line is no longer a plan.
	var path: Array[Vector2] = []
	var path_goal := Vector2(1e20, 1e20)
	var carrying: int = -1
	## How far through digging a bare seam this cat is, 0..1. Not saved: a stone
	## half dug when the tab closed is a second of work, and a saved field is
	## a schema every future change has to carry.
	var dig: float = 0.0
	## A constant, and the reason it is stored rather than derived from where the
	## cat happens to be standing.
	##
	## Two cats side by side must not breathe and step in unison, so the animation
	## needs an offset per animal. That offset used to be the cat's x position,
	## which made it change as the cat walked: breathing scales the sprite,
	## anything hanging over the cat is positioned from the scaled height, and the
	## shadow is not scaled at all -- so a cat crossing the map had its hunger bar
	## drifting against its own shadow, and its walk frames advancing by position
	## as well as by time. An offset that moves is not an offset.
	var phase: float = 0.0
	var hunger: float = 1.0
	var eat_timer: float = 0.0
	## Which grade this cat is. Everything adopted out of a crate is an O, so the
	## default is what the game produced before the gacha existed.
	var rarity: int = Defs.RARITY_O

	func has_job() -> bool:
		return assigned != Vector2i(9999, 9999)

	## Whether the walk sheet should be playing. A strolling cat is walking even
	## though its state is idle, and without this it slides across the snow with
	## its legs still -- the exact failure the sheet tables were built to end.
	func is_walking() -> bool:
		return state in Defs.CAT_WALKING_STATES or not path.is_empty()

class Machine extends RefCounted:
	## Splitters only: which output to try first, and where the last item came
	## from so it is never sent straight back.
	var next_out: int = 0
	var source := Vector2i(9999, 9999)
	## Belts only: which speed grade this one is.
	var tier: int = 0
	var type: int = Defs.M_BELT
	var cell: Vector2i = Vector2i.ZERO
	var dir: Vector2i = Vector2i.RIGHT
	var progress: float = 0.0
	var flash: float = 0.0
	## True when this machine has finished work it cannot hand on. Surfacing it is
	## the only way a player can tell a mis-aimed belt line from a working one.
	var stalled: bool = false
	## Belts: [{ "type": int, "t": float }] ordered from the front of the tile.
	var items: Array[Dictionary] = []
	## Furnace input buffer keyed by item type.
	var buffer: Dictionary = {}
	## Finished output the machine has not managed to hand on yet, keyed by item
	## type. A recipe that makes three at once cannot put all three on one belt
	## tile in the same instant, and the remainder is owed rather than lost.
	##
	## Was `pending: int` from the exchanger era: written to the save, read by
	## nothing, and unable to say *what* was owed. Made a dictionary in 1.0.32,
	## when a shared recipe tick finally needed the thing its comment described.
	var outbox: Dictionary = {}
	## Which recipe this machine is running, by key. Empty means "whatever this
	## type starts on" -- which is what a save written before machines could
	## choose says, and what a machine built before the player has chosen
	## anything says. `Sim.recipe_of` is the only thing that resolves it.
	var recipe_key: String = ""
	## Miners only run while a cat is standing here.
	var operated: bool = false
	## Rigs only: the ore node this one works, by the node's origin -- its
	## identity. Always the rig's own anchor, since a rig stands exactly over its
	## node, but held as its own fact and saved as one: what a post puts out is
	## asked of this, never worked out from where the post happens to be.
	var ore_node: Vector2i = Vector2i(9999, 9999)
	## What this machine has actually moved, in items, kept in two buckets so the
	## readout averages over a window instead of reporting the gap between two
	## cycles. Rolled over rather than accumulated forever, so a machine that was
	## starved an hour ago does not drag its current reading down.
	var meter_in: Dictionary = {}
	var meter_out: Dictionary = {}
	var meter_in_old: Dictionary = {}
	var meter_out_old: Dictionary = {}
	var meter_span: float = 0.0
	var meter_span_old: float = 0.0

## Ore, as nodes (World Visual Pass 01, 2026-09-28).
##
## A node is two cells by two -- a tile -- and it is one thing: one identity, one
## material, one post. Its identity is its top-left cell, the origin, and that is
## the key here. It was a single cell until this pass, stored per cell, and every
## question about a seam was `ore.has(cell)`; asked of a node that answer is right
## for one cell in four and silently wrong for the other three. So the old name is
## gone rather than redefined -- every use had to be decided again, the way
## `Defs.TILE` was -- and the only ways in are the functions under "Ore nodes".
var ore_nodes: Dictionary[Vector2i, int] = {}
## Every cell a node covers -> that node's origin. Written only by `put_ore` and
## `erase_ore_at`, so it cannot disagree with `ore_nodes`.
var _ore_cell: Dictionary[Vector2i, Vector2i] = {}
## Per-node richness, keyed by origin like `ore_nodes`.
var purity: Dictionary[Vector2i, int] = {}
var machines: Dictionary[Vector2i, Machine] = {}
var core_cell := Vector2i.ZERO

var cats: Array[Cat] = []
## Frozen cats lying in the world: cell -> how far the ice has gone, 0..1.
## A value rather than a set because thawing happens where the cat was put down
## and the progress has to survive a save.
## Crystal, lying where the world put it. A set rather than a count per cell:
## one piece to a tile, so finding one is finding a place rather than a pile.
## Boulders the player has broken. The field itself is infinite and generated
## from the coordinates rather than stored, so what has to be remembered is not
## where the rocks are but which ones are gone.
var mined_rocks: Dictionary[Vector2i, bool] = {}
var shards: Dictionary[Vector2i, bool] = {}
var frozen_cats: Dictionary[Vector2i, float] = {}
## 냥마을, and the sign that says where it is.
##
## Derived from the fire's cell and a table of offsets, so neither is saved: a
## place that is in the same spot in every run is not run state. What *is* saved
## is the seven blocks of ice in it, because those can be carried away.
## The block of ice at the fourth step's edge, and how many times the game has
## suggested a torch at one. Both saved: the hint is a thing that happened to
## this player, and a hint that starts over on load is a hint that never stops.
var edge_frozen := Vector2i(9999, 9999)
var torch_hints: int = 0
var sign_cell := Vector2i(9999, 9999)
var village: Dictionary[Vector2i, int] = {}
var village_rect := Rect2i()
## Tracks in the snow between the two. The value is only which of the two marks
## to draw; what matters is the key.
var trail: Dictionary[Vector2i, int] = {}
## Whether Grim has one in her arms. A bool rather than an object because a
## frozen cat has no state of its own until it is on the ground -- it is not a
## Cat yet, and pretending it is would mean a Cat that must be excluded from
## every loop that walks the crew. That exclusion is exactly the bug this
## repository already has a lesson about.
var carried_frozen: bool = false
## How far the ice on the carried one had already gone. Picking a thawing cat up
## to move it one tile must not put the ice back.
var carried_frozen_thaw: float = 0.0
## The emergency kit she is carrying, if any: KIT_BASE or KIT_SHELTER.
var carried_kit: int = Defs.KIT_NONE

## --- Before there is a base -------------------------------------------------
## The run starts at a crash site with nothing built. These say what is standing
## and what is not; every drawing and every rule that assumed a base reads them.
##
## Defaulted to "already built" so that `setup()` produces exactly the world it
## always did. The crash is something Main asks for, which keeps every test that
## wants an ordinary world writing exactly what it wrote before.
var base_placed := true
var shelter_placed := true
## The food bin is not part of the shelter kit. It used to appear with it, which
## put a feeding station on the map four days before any cat was hungry -- a
## solution standing next to a problem that had not happened. It is made at the
## fire, when a cat working at a third speed makes the player ask why.
var food_placed := false
## The survival kit lying in the snow, and how many times it has been searched.
## Two searches: the base, then the pickaxe and the shelter.
var kit_cell := Vector2i(9999, 9999)
## Whether the hidden route's landmarks (냥마을, its sign, the footprints)
## generate at all. Off on the main path; saved, so a run that has seen the
## village keeps it.
var story_enabled: bool = Defs.STORY_ON_MAIN_PATH
var kit_searched: int = 0
## How far through the current search she is, 0..1. Lives here rather than on
## the orchestrator because the thing that draws the ring reads the world, and a
## number the drawing cannot see is a number the drawing has to be told twice.
var kit_progress: float = 0.0
## Torches made and not yet lit, and how long is left on the one in her hand.
##
## Two numbers rather than a list of torches with their own timers, because only
## one can ever be alight: `torch_left` is the burn remaining on that one, and it
## survives putting the torch away. Lighting only spends from the pack when
## there is nothing left burning.
var torches: int = 0
var torch_left: float = 0.0

## --- What she has been shown ------------------------------------------------
## Which key prompts are done with. Most of them are answered by the world --
## the kit has been searched, a cat exists, a machine is standing -- and only
## the few with no trace in the world are recorded here, because a flag set at
## the moment of an action is a flag that can be missed when the action happens
## some other way.
var learned: Dictionary[String, bool] = {}
## How far she has walked, in tiles. The one prompt that cannot be answered by
## looking at the world: moving leaves nothing behind.
var walked: float = 0.0

func learn(id: String) -> void:
	learned[id] = true

func has_learned(id: String) -> bool:
	return bool(learned.get(id, false))
## Which step of BASE_LEVELS the base is on. Kept beside the radius so the thing
## that changed can be announced -- an upgrade is an event, and the previous
## arrangement had nothing to fire on because the radius moved every few seconds
## by a hundredth of a tile.
var base_level: int = 0
## The cat currently in the player's arms. Cats are placed on machines by hand;
## there is no automatic assignment, so the player decides who works where.
var carried_cat: Cat = null
var food: int = Defs.FOOD_START
var shelter_cell := Vector2i.ZERO
var food_cell := Vector2i.ZERO
## Coins, spent one per pull at the slot machine. Nothing else in the game reads
## them, which is why they are a plain counter rather than a `stock` entry: the
## materials in `stock` are all things a belt can carry.
var coins: int = 0
## The gacha's own generator, seeded from the run. Separate from world
## generation on purpose -- a pull must not depend on how much terrain has been
## rolled since -- and seeded rather than global so a test can ask for a
## thousand pulls and get the same thousand every time.
var gacha_rng := RandomNumberGenerator.new()
## Loitering. Its own stream, seeded from the run, so a strolling cat does not
## consume draws the slot machine is counting on and a replay of a seed looks the
## same twice.
var wander_rng := RandomNumberGenerator.new()

## Where a cat may walk.
##
## They used to walk in straight lines through everything, which nobody saw while
## ore was the only obstacle and ore was walkable. The core, the hut, the food bin
## and every miner stop Grim, and a cat crossing the base walked through the
## middle of all four.
##
## Bounded rather than unbounded: every route is inside the base and its ring of
## seams, and a grid covering the whole procedural world would be mostly cells no
## one ever asks about.
##
## In tiles, so the grid covers the same ground whatever the cell size is.
const PATH_RADIUS := 48
var _grid := AStarGrid2D.new()
var _grid_dirty := true

## Heat stones put into the fire, ever. The base level is a function of this and
## of nothing else, which is the whole of the resource economy the circle has.
##
## There used to be a second number called heat: stones went in, heat came out at
## five apiece, and the ladder was written in heat. It was a currency with one
## thing to buy, no way to spend it wrong, and a conversion the player had to do
## in their head to read any of it.
var stones_in: int = 0
var delivered: Dictionary[int, int] = {}
## Materials banked at the base. Machines are bought out of this, so hauling is
## what funds construction rather than a separate abstract currency.
var stock: Dictionary[int, int] = {}
## Loose items lying in the world, one per cell. A miner with nowhere to push
## drops here, hand mining drops here, and cats carry from here to the base.
var ground: Dictionary[Vector2i, int] = {}
## How many are on each occupied tile. Absent means one -- a separate map rather
## than a change to `ground`'s type, so every reader that only wants to know what
## is lying there keeps working.
var ground_stack: Dictionary[Vector2i, int] = {}
## Which machines the player has earned. Seeing a resource for the first time is
## what opens its line, so the hotbar grows as the world does.
var unlocked: Dictionary[int, bool] = {}
## Power is a rate. Capacity is what running generators sustain; draw is what
## powered machines ask for. Neither is ever stored.
var power_capacity: float = 0.0
var power_draw: float = 0.0
## Income per material, in items per minute, averaged over a slow window.
## Per minute rather than per second because everything else the game quotes is
## per minute -- a miner is 6/min, and the same figure written as 0.10/s is the
## same information in a form nobody can plan against.
## Only gains count: spending copper on a machine is not negative production, and
## a resource row that dipped below zero every time the player built something
## would be reporting on the wrong thing.
var gain_rate: Dictionary[int, float] = {}
var _gain_accum: Dictionary[int, float] = {}
var _rate_clock: float = 0.0
## A second of production at a time, kept for this long and averaged whole.
## Production is not continuous: two staffed miners are a steady twelve a minute,
## which is one crystal every five seconds, so a one second window reads 60 on
## the second one lands and 0 on the four after it. Smoothing that only spread
## the spike -- the panel swung between 0.1 and 20 while nothing about the
## factory changed. A number that never settles cannot be read as income, and
## the player has no other way to tell whether a machine is worth building.
const RATE_WINDOW := 20.0
var _rate_history: Array[Dictionary] = []
## Where the player is currently swinging, and how far through the swing.
var hand_cell := Vector2i(9999, 9999)
var hand_progress: float = 0.0
var warm_radius: float = Defs.WARM_BASE

var _cached_radius := -1.0

## --- Persistence ----------------------------------------------------------
## Terrain is not stored: it is regenerated from the seed, so the save only has
## to carry what the player changed. That keeps the file small and means a
## world-generation tweak cannot corrupt an existing save's geometry.
## --- What the player has seen ---------------------------------------------
## Which parts of the world the map is allowed to show.
##
## Kept as chunks rather than cells: the map is a few hundred pixels across, so
## it cannot resolve a single cell anyway, and a run that walks a few thousand
## cells would otherwise keep a few thousand dictionary entries to draw forty
## squares from.
##
## In tiles, so a chunk covers the same ground it always did -- and the chunk
## numbers a save carries still name the same squares of the world after the
## grid went finer.
const EXPLORED_CHUNK := 2

var explored: Dictionary[Vector2i, bool] = {}

static func chunk_of(cell: Vector2i) -> Vector2i:
	# Floor division, not integer division: the world has negative coordinates
	# and -1 / 2 truncates toward zero, which folds two different chunks either
	# side of the origin into one.
	var span: float = float(EXPLORED_CHUNK * Grid.SCALE)
	return Vector2i(floori(float(cell.x) / span), floori(float(cell.y) / span))

## Everything within `radius` cells of here has been seen.
##
## Circular rather than square, because the fog is telling the player how far
## they can see and sight is not a box. Called every frame with the player's
## cell, so it does the least work it can: the loop is over a radius of about
## ten, and marking a chunk that is already marked costs a dictionary write.
##
## `radius` is in tiles and the walk is a tile at a time: a chunk is two tiles
## across, so stepping by cells would mark every chunk four times over for
## nothing.
func mark_explored(centre: Vector2i, radius: int) -> void:
	var span: int = radius
	for dy in range(-span, span + 1):
		for dx in range(-span, span + 1):
			if dx * dx + dy * dy > radius * radius:
				continue
			explored[chunk_of(centre + Vector2i(dx, dy) * Grid.SCALE)] = true

func is_explored(cell: Vector2i) -> bool:
	return explored.has(chunk_of(cell))

func to_save() -> Dictionary:
	var machine_rows: Array = []
	for cell: Vector2i in machines:
		var machine: Machine = machines[cell]
		if machine.type == Defs.M_CORE:
			continue
		machine_rows.append({
			"x": cell.x, "y": cell.y, "type": machine.type,
			"dx": machine.dir.x, "dy": machine.dir.y,
			"progress": machine.progress, "items": machine.items.duplicate(true),
			"buffer": machine.buffer.duplicate(true),
			"outbox": machine.outbox.duplicate(true),
			"recipe": machine.recipe_key,
			"tier": machine.tier,
		})
		if Defs.machine_mines(machine.type):
			machine_rows[machine_rows.size() - 1]["ore_x"] = machine.ore_node.x
			machine_rows[machine_rows.size() - 1]["ore_y"] = machine.ore_node.y
	var cat_rows: Array = []
	for cat: Cat in cats:
		cat_rows.append({
			"px": cat.pos.x, "py": cat.pos.y, "state": cat.state,
			"ax": cat.assigned.x, "ay": cat.assigned.y,
			"hunger": cat.hunger, "eat": cat.eat_timer,
			"rarity": cat.rarity,
		})
	var mined_rows := PackedInt32Array()
	for cell: Vector2i in mined_rocks:
		mined_rows.append(cell.x)
		mined_rows.append(cell.y)
	var shard_rows := PackedInt32Array()
	for cell: Vector2i in shards:
		shard_rows.append(cell.x)
		shard_rows.append(cell.y)
	var frozen_rows: Array = []
	for cell: Vector2i in frozen_cats:
		frozen_rows.append([cell.x, cell.y, frozen_cats[cell]])
	var delivered_rows: Dictionary = {}
	for key: int in delivered:
		delivered_rows[str(key)] = int(delivered[key])
	var stock_rows: Dictionary = {}
	for key: int in stock:
		stock_rows[str(key)] = int(stock[key])
	var ground_rows: Array = []
	for cell: Vector2i in ground:
		ground_rows.append([cell.x, cell.y, int(ground[cell]), ground_count(cell)])
	var unlocked_rows: Array = []
	for key: int in unlocked:
		if bool(unlocked[key]):
			unlocked_rows.append(int(key))
	# Flat pairs rather than a dictionary of vectors: ConfigFile writes this as
	# one array of numbers instead of several thousand "Vector2i(x, y)" strings.
	var seen := PackedInt32Array()
	for chunk: Vector2i in explored:
		seen.append(chunk.x)
		seen.append(chunk.y)
	return {
		"explored": seen,
		"stones_in": stones_in, "delivered": delivered_rows,
		"belt_fed": delivered_by_belt,
		"drops": _drop_rows(), "has_gun": has_gun, "has_pickaxe": has_pickaxe,
		"gun_dropped": gun_dropped, "collected": _collected_rows(),
		"last_recipe": last_recipe.duplicate(true),
		"thawed": _thawed_rows(),
		"debris": _debris_rows(), "debris_searched": debris_searched,
		"machines": machine_rows, "cats": cat_rows, "frozen": frozen_rows,
		"carried_frozen": carried_frozen, "carried_frozen_thaw": carried_frozen_thaw,
		# The opening. Saved because it is thirteen minutes of the game and a run
		# reloaded into the middle of it with a base that never existed is not a
		# run, and because `core_cell` moves when the base goes down -- restoring
		# a world around the wrong centre would put the shelter, the fog and the
		# ore rings in different places than the ones on screen.
		"base_placed": base_placed, "shelter_placed": shelter_placed,
		"food_placed": food_placed,
		"carried_kit": carried_kit, "kit_searched": kit_searched,
		"torches": torches, "torch_left": torch_left, "power_ever": power_ever,
		"story_enabled": story_enabled,
		"learned": learned.keys(), "walked": walked, "torch_hints": torch_hints,
		"shards": shard_rows, "mined_rocks": mined_rows,
		"kit_x": kit_cell.x, "kit_y": kit_cell.y,
		# All three cells, rather than the core plus arithmetic: the player picks
		# where the hut goes, so it is not derivable from where the fire is.
		"core_x": core_cell.x, "core_y": core_cell.y,
		"shelter_x": shelter_cell.x, "shelter_y": shelter_cell.y,
		"food_x": food_cell.x, "food_y": food_cell.y,
		"food": food, "coins": coins,
		"stock": stock_rows, "ground": ground_rows, "unlocked": unlocked_rows,
	}

func from_save(data: Dictionary) -> void:
	# Absent in saves written before the map existed, and that is fine: a run
	# reloaded from one of those starts with only the base revealed and fills in
	# again as it is walked. Adding this without moving SAVE_SCHEMA is deliberate
	# -- a schema bump throws away every save anyone is in the middle of, and a
	# missing key that reads as "nothing explored yet" costs a player nothing.
	explored.clear()
	var seen: PackedInt32Array = data.get("explored", PackedInt32Array())
	for index in range(0, seen.size() - 1, 2):
		explored[Vector2i(seen[index], seen[index + 1])] = true
	stones_in = int(data.get("stones_in", 0))
	delivered_by_belt = bool(data.get("belt_fed", false))
	has_gun = bool(data.get("has_gun", false))
	has_pickaxe = bool(data.get("has_pickaxe", false))
	gun_dropped = bool(data.get("gun_dropped", false))
	collected.clear()
	for row in data.get("collected", []):
		collected[int(row[0])] = int(row[1])
	# What has been held is derived rather than stored: a lifetime total above
	# zero is the same fact, and a save written before this existed answers it
	# correctly without a schema bump.
	last_recipe = (data.get("last_recipe", {}) as Dictionary).duplicate(true)
	held_items.clear()
	for item_type: int in collected:
		if int(collected[item_type]) > 0:
			held_items[item_type] = true
	pending_unlocks.clear()
	thawed.clear()
	for row in data.get("thawed", []):
		thawed[Vector2i(int(row[0]), int(row[1]))] = true
	# Saved as a map rather than regenerated from the seed: the pieces that are
	# gone are gone, and a world rebuilt from its seed would put every one of
	# them back.
	debris.clear()
	for row in data.get("debris", []):
		debris[Vector2i(int(row[0]), int(row[1]))] = int(row[2])
	debris_searched = int(data.get("debris_searched", 0))
	cancel_debris()
	drops.clear()
	for row in data.get("drops", []):
		drops[Vector2i(int(row[0]), int(row[1]))] = int(row[2])
	var delivered_rows: Dictionary = data.get("delivered", {})
	for key: String in delivered_rows:
		delivered[int(key)] = int(delivered_rows[key])
	food = int(data.get("food", Defs.FOOD_START))
	# Defaulted rather than required, so a save written before the slot machine
	# existed loads as a run that has simply never pulled.
	coins = int(data.get("coins", 0))
	var stock_rows: Dictionary = data.get("stock", {})
	for key: String in stock_rows:
		stock[int(key)] = int(stock_rows[key])
	ground.clear()
	for row: Array in data.get("ground", []):
		var ground_cell := Vector2i(int(row[0]), int(row[1]))
		ground[ground_cell] = int(row[2])
		ground_stack[ground_cell] = int(row[3]) if row.size() > 3 else 1
	unlocked.clear()
	for type: int in data.get("unlocked", []):
		unlocked[int(type)] = true

	for row: Dictionary in data.get("machines", []):
		var cell := Vector2i(int(row["x"]), int(row["y"]))
		var machine := Machine.new()
		machine.type = int(row["type"])
		machine.cell = cell
		machine.dir = Vector2i(int(row["dx"]), int(row["dy"]))
		machine.progress = float(row.get("progress", 0.0))
		machine.buffer = (row.get("buffer", {}) as Dictionary).duplicate(true)
		# A save written before 1.0.32 carries `pending`, which was an int and was
		# always 0 -- nothing ever set it. There is nothing to migrate, only a
		# key to stop reading.
		machine.outbox = (row.get("outbox", {}) as Dictionary).duplicate(true)
		machine.recipe_key = String(row.get("recipe", ""))
		machine.tier = int(row.get("tier", 0))
		if row.has("ore_x"):
			machine.ore_node = Vector2i(int(row["ore_x"]), int(row["ore_y"]))
		for item: Dictionary in row.get("items", []):
			machine.items.append({"type": int(item["type"]), "t": float(item["t"])})
		add_machine(machine)

	mined_rocks.clear()
	var mined_flat: PackedInt32Array = data.get("mined_rocks", PackedInt32Array())
	for index in range(0, mined_flat.size() - 1, 2):
		mined_rocks[Vector2i(mined_flat[index], mined_flat[index + 1])] = true
	shards.clear()
	var shard_flat: PackedInt32Array = data.get("shards", PackedInt32Array())
	for index in range(0, shard_flat.size() - 1, 2):
		shards[Vector2i(shard_flat[index], shard_flat[index + 1])] = true
	frozen_cats.clear()
	for row: Array in data.get("frozen", []):
		frozen_cats[Vector2i(int(row[0]), int(row[1]))] = float(row[2])
	carried_frozen = bool(data.get("carried_frozen", false))
	carried_frozen_thaw = float(data.get("carried_frozen_thaw", 0.0))
	core_cell = Vector2i(int(data.get("core_x", core_cell.x)),
		int(data.get("core_y", core_cell.y)))
	base_placed = bool(data.get("base_placed", true))
	shelter_placed = bool(data.get("shelter_placed", true))
	food_placed = bool(data.get("food_placed", false))
	carried_kit = int(data.get("carried_kit", Defs.KIT_NONE))
	kit_searched = mini(int(data.get("kit_searched", 1)), 1)
	torches = int(data.get("torches", 0))
	power_ever = bool(data.get("power_ever", false))
	if bool(data.get("story_enabled", false)) and not story_enabled:
		story_enabled = true
		_generate_village()
	torch_left = float(data.get("torch_left", 0.0))
	learned.clear()
	torch_hints = int(data.get("torch_hints", 0))
	for id: String in data.get("learned", []):
		learned[id] = true
	walked = float(data.get("walked", 0.0))
	kit_progress = 0.0
	kit_cell = Vector2i(int(data.get("kit_x", 9999)), int(data.get("kit_y", 9999)))
	shelter_cell = Vector2i(int(data.get("shelter_x", shelter_cell.x)),
		int(data.get("shelter_y", shelter_cell.y)))
	food_cell = Vector2i(int(data.get("food_x", food_cell.x)),
		int(data.get("food_y", food_cell.y)))
	base_level = Defs.base_level(stones_in)
	warm_radius = Defs.warm_radius(stones_in) if base_placed else Defs.CRASH_SIGHT
	_cached_radius = warm_radius
	_grid_dirty = true

	cats.clear()
	for row: Dictionary in data.get("cats", []):
		var cat := Cat.new()
		cat.phase = _next_phase()
		cat.pos = Vector2(float(row["px"]), float(row["py"]))
		cat.state = int(row.get("state", Defs.CAT_IDLE))
		cat.assigned = Vector2i(int(row["ax"]), int(row["ay"]))
		cat.hunger = float(row.get("hunger", 1.0))
		cat.eat_timer = float(row.get("eat", 0.0))
		cat.rarity = int(row.get("rarity", Defs.RARITY_O))
		cats.append(cat)
	_refresh_radius()
	shown_radius = warm_radius

func setup(seed_value: int) -> void:
	# A new world is outdoors. 처음부터 from the settings panel while she stood in
	# the shelter carried `indoors` into the new run, and the plateau's ground --
	# which is not drawn indoors -- came up as a black disc under the fire
	# (found by tools/presentation_capture.gd, Quality Pass 01).
	indoors = false
	_grid_dirty = true
	clear_ore()
	machines.clear()
	# The base is on the map from the first frame. A player who opens the map
	# before walking anywhere should see where they are, not a black square --
	# the fog is there to make exploring worth something, not to hide the start.
	explored.clear()
	stones_in = 0
	delivered_by_belt = false
	drops.clear()
	has_gun = false
	has_pickaxe = false
	gun_dropped = false
	last_recipe.clear()
	collected.clear()
	held_items.clear()
	pending_unlocks.clear()
	thawed.clear()
	cancel_thaw()
	delivered = {Defs.ITEM_CRYSTAL: 0, Defs.ITEM_COPPER: 0, Defs.ITEM_HEATSTONE: 0}
	stock = {Defs.ITEM_CRYSTAL: 0, Defs.ITEM_COPPER: 0, Defs.ITEM_HEATSTONE: 0}
	ground.clear()
	ground_stack.clear()
	unlocked.clear()
	power_capacity = 0.0
	power_draw = 0.0
	_grid_dirty = true
	# Or a new run opens quoting the income of the one before it, for as long as
	# the window takes to roll over.
	_rate_history.clear()
	_gain_accum.clear()
	gain_rate.clear()
	_rate_clock = 0.0
	warm_radius = Defs.WARM_BASE
	# Seed the cache so the opening frame does not announce a radius that has
	# not actually changed yet.
	_cached_radius = warm_radius
	shown_radius = warm_radius
	# The anchor every ring in this world is measured from, pinned before a
	# single seam is placed. `core_cell` moves during the opening -- it is where
	# she is until the case unfolds -- and a second `setup()` on the same Sim
	# used to generate the whole world around wherever it had been left.
	core_cell = Vector2i.ZERO
	var core := Machine.new()
	core.type = Defs.M_CORE
	core.cell = core_cell
	add_machine(core)
	mark_explored(core_cell, Defs.BASE_REVEAL_RADIUS)
	cats.clear()
	shards.clear()
	mined_rocks.clear()
	torches = 0
	torch_left = 0.0
	torch_hints = 0
	edge_frozen = Vector2i(9999, 9999)
	learned.clear()
	walked = 0.0
	frozen_cats.clear()
	frozen_offset.clear()
	debris.clear()
	debris_searched = 0
	cancel_debris()
	debris_rng.seed = seed_value ^ 0xC2B2AE35
	base_level = 0
	power_ever = false
	carried_frozen = false
	carried_frozen_thaw = 0.0
	carried_kit = Defs.KIT_NONE
	kit_searched = 0
	kit_cell = Vector2i(9999, 9999)
	base_placed = true
	shelter_placed = true
	food_placed = false
	carried_cat = null
	coins = 0
	# Derived from the run seed rather than randomised, so replaying a seed
	# replays the pulls too. Shifted off the world seed so two sims that generate
	# the same terrain do not also hand out the same first cat.
	gacha_rng.seed = seed_value ^ 0x9E3779B9
	wander_rng.seed = seed_value ^ 0x85EBCA6B
	food = Defs.FOOD_START
	shelter_cell = core_cell + Defs.SHELTER_CELL
	food_cell = shelter_cell + Defs.FOOD_CELL
	_generate_ore(seed_value)
	_generate_shards(seed_value)
	_generate_frozen_cats(seed_value)
	_generate_debris(seed_value)
	# Last, so that clearing its square out is clearing out everything: a seam
	# rolled into the village square is a seam standing in someone's house, and
	# the shelter doorstep taught this repository that reserving a cell before
	# the scatter runs reserves nothing.
	_generate_village()

## Cells kept clear so the guaranteed opening always has a belt route home.
## A single row, not a block: a square patch would put ore directly in front of
## the miner's output and the guaranteed opening would dead-end.
##
## In build cells from the core's anchor (Grid v2). Three seams in a row under
## four tiles south of the fire, a mining post's width apart, so each can carry a
## post of its own. The posts' top row is three cells below the base, which
## leaves a lane two cells -- a tile -- tall between them.
##
## A tile, because she has to walk it. It was two tiles when the base was one;
## at one cell (the first Grid v2 layout) the lane was sixteen pixels against a
## body of eighteen, so she could neither walk between the fire and its first
## posts nor reach the middle of the lane to lay the belt home.
const STARTER_PATCH: Array[Vector2i] = [Vector2i(-3, 8), Vector2i(1, 8), Vector2i(5, 8)]
## That lane: the two cells above each starter seam's post. A post facing north
## pours into the lower one; the two under the base hand straight in, the third
## turns one cell west first.
const STARTER_LANE: Array[Vector2i] = [Vector2i(-3, 5), Vector2i(-3, 6), Vector2i(1, 5),
	Vector2i(1, 6), Vector2i(5, 5), Vector2i(5, 6)]
## A guaranteed ember seam due north, just outside the opening warm radius, with
## a clear column back to the core. Without it the alloy recipe -- the design's
## payoff -- depends on where the scatter happened to drop ember, which made the
## mid-game beat unreliable and left the headline mechanic unreachable in a
## five-minute run.
const STARTER_COPPER: Array[Vector2i] = [Vector2i(1, -17), Vector2i(-3, -17), Vector2i(5, -17)]
## The column kept clear between that seam's post and the base, in cells.
const STARTER_COLUMN := Rect2i(Vector2i(0, -14), Vector2i(3, 11))

# --- Ore nodes -------------------------------------------------------------------
## The one way into the ore. Every question anything asks about a seam -- is
## there one here, which one, what is it, what does it give -- is one of these,
## so no caller works a material out from a cell, a colour or a tile.

## Whether any node covers this cell.
func has_ore(cell: Vector2i) -> bool:
	return _ore_cell.has(cell)

## The node covering this cell, as its origin (its identity), or NONE.
func ore_origin_at(cell: Vector2i) -> Vector2i:
	return _ore_cell.get(cell, NONE)

## The ore type of the node covering this cell, or -1.
func ore_type_at(cell: Vector2i) -> int:
	var origin: Vector2i = _ore_cell.get(cell, NONE)
	return int(ore_nodes[origin]) if origin != NONE else -1

## What working the node covering this cell yields, by hand, by a cat or by a
## post: the registry's answer for its type (`Defs.ore_output`), or -1.
func ore_item(cell: Vector2i) -> int:
	return Defs.ore_output(ore_type_at(cell))

## The cells of the node whose origin this is.
static func ore_rect(origin: Vector2i) -> Rect2i:
	return Rect2i(origin, Defs.ORE_NODE_SIZE)

static func ore_cells(origin: Vector2i) -> Array[Vector2i]:
	return Grid.cells_in(ore_rect(origin))

## The middle of the node covering this cell, in world pixels.
func ore_centre(cell: Vector2i) -> Vector2:
	return Grid.rect_centre(ore_rect(ore_origin_at(cell)))

## How far a node with its origin here is from the fire, in tiles.
##
## Measured at the origin cell, not at the node's middle a third of a tile away.
## The origin is where the seam was when a seam was one cell, and every ring,
## band and purity grade was placed by measuring there: measure anywhere else and
## the generator walks a different path and a saved run's world comes back
## different under its posts.
func ore_tiles_from_core(origin: Vector2i) -> float:
	return tiles_from_core(origin)

## Puts a node down with its origin on `origin`, taking away any node it would
## overlap. The only writer of `ore_nodes` besides `erase_ore_at`.
func put_ore(origin: Vector2i, type: int) -> void:
	for cell: Vector2i in ore_cells(origin):
		erase_ore_at(cell)
	ore_nodes[origin] = type
	for cell: Vector2i in ore_cells(origin):
		_ore_cell[cell] = origin

## Takes away the whole node covering this cell -- never a quarter of one.
## Returns whether there was one.
func erase_ore_at(cell: Vector2i) -> bool:
	var origin: Vector2i = _ore_cell.get(cell, NONE)
	if origin == NONE:
		return false
	for covered: Vector2i in ore_cells(origin):
		_ore_cell.erase(covered)
	ore_nodes.erase(origin)
	purity.erase(origin)
	return true

func clear_ore() -> void:
	ore_nodes.clear()
	_ore_cell.clear()
	purity.clear()

## Everything wrong with the ore, as sentences: a node missing a cell, a cell
## pointing at a node that is not there, two nodes overlapping.
func ore_errors() -> Array[String]:
	var problems: Array[String] = []
	for origin: Vector2i in ore_nodes:
		for cell: Vector2i in ore_cells(origin):
			if _ore_cell.get(cell, NONE) != origin:
				problems.append("node %s: cell %s belongs to %s" % [origin, cell, _ore_cell.get(cell, NONE)])
	for cell: Vector2i in _ore_cell:
		var origin: Vector2i = _ore_cell[cell]
		if not ore_nodes.has(origin) or not ore_rect(origin).has_point(cell):
			problems.append("cell %s points at %s, which does not cover it" % [cell, origin])
	if _ore_cell.size() != ore_nodes.size() * Defs.ORE_NODE_SIZE.x * Defs.ORE_NODE_SIZE.y:
		problems.append("%d cells for %d nodes" % [_ore_cell.size(), ore_nodes.size()])
	return problems

func _generate_ore(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# A guaranteed first patch just south of the core. The opening minute should
	# be about learning the miner-belt-core sentence, not about searching.
	for offset: Vector2i in STARTER_PATCH:
		put_ore(core_cell + offset, Defs.ITEM_HEATSTONE)
	# Ore is deliberately scarce: a fifth of the earlier density. Finding a seam
	# should be an event, and a single miner should be worth protecting. Heat
	# stone is the exception -- it is what the opening is made of, so there is
	# more of it and all of it is close.
	for band: Dictionary in Defs.HEATSTONE_BANDS:
		_scatter_ore(rng, Defs.ITEM_HEATSTONE, band["ring"], int(band["patches"]), int(band["size"]))
	# One copper patch pinned to the edge of the fourth circle, then the scatter
	# for everything past it.
	_pin_patch(rng, Defs.ITEM_COPPER, Defs.FIRST_COPPER_BAND, Defs.FIRST_COPPER_SIZE)
	_scatter_ore(rng, Defs.ITEM_COPPER, Defs.COPPER_RING, 3, 2)
	# Iron, three rungs further out. Pinned for the same reason copper is: the
	# manufacturer is the next thing the game has to offer and a seed that puts
	# no iron inside the circle is a run that cannot reach it.
	_pin_patch(rng, Defs.ITEM_IRON, Defs.FIRST_IRON_BAND, Defs.FIRST_IRON_SIZE)
	_scatter_ore(rng, Defs.ITEM_IRON, Defs.IRON_RING, 3, 2)
	# A guaranteed heat stone seam due north with a clear column home, so the
	# opening never depends on the scatter being kind. It used to be copper, then
	# crystal; it is the resource the beat it protects actually needs, and that
	# beat is now the first minutes. Whatever the scatter left too close to it
	# goes, so it keeps the spacing every seam has.
	for offset: Vector2i in STARTER_COPPER:
		var cell: Vector2i = core_cell + offset
		for near: Vector2i in ore_nodes.keys():
			if Grid.steps(near, cell) < Defs.ORE_PITCH:
				erase_ore_at(near)
		put_ore(cell, Defs.ITEM_HEATSTONE)
	# The base, its surroundings, the shelter, its doorstep and the food bin are
	# cleared last, after every scatter. Ore blocks building, and the doorstep is
	# where they are put down every single morning: a seam rolled onto it woke
	# them up standing inside a wall. It showed up as a test failing one run in
	# five, which is the shape a seeded world bug always takes -- the map is
	# different every run and most maps are fine.
	for origin: Vector2i in ore_nodes.keys():
		if _node_reserved(origin):
			erase_ore_at(origin)
	_assign_purity()

## Distance buys richness. The seams beside the base are ordinary; the ones out
## past the frontier are worth the walk. This is what stops the map from being a
## uniform field where one seam is as good as any other.
func _assign_purity() -> void:
	purity.clear()
	for origin: Vector2i in ore_nodes:
		var distance: float = _ring_distance(origin)
		if distance >= Defs.PURITY_PURE_RING:
			purity[origin] = Defs.PURITY_PURE
		elif distance >= Defs.PURITY_RICH_RING:
			purity[origin] = Defs.PURITY_RICH
		else:
			purity[origin] = Defs.PURITY_NORMAL

## A patch at a named distance, in a direction the seed picks. Used where the
## design says "this resource opens at this upgrade": leaving it to the scatter
## makes that a probability rather than a promise, and the player who rolls the
## other way is playing a different game from the one the card describes.
func _pin_patch(rng: RandomNumberGenerator, item_type: int, band: Vector2, size: int) -> void:
	var radius: float = (band.x + band.y) * 0.5
	var angle: float = rng.randf() * TAU
	var origin: Vector2i = _cell_toward(angle, radius)
	# Every seam of the patch inside the band, not just its origin: a cluster
	# grown from a cell on the line puts about half of itself on the far side of
	# it, which is how "copper opens at the fourth upgrade" came out as three
	# seams in five runs and a stray seam inside the third circle.
	#
	# Gathered and sorted rather than random-walked. A walk that only ever steps
	# one cell from its origin has nine cells to work with, and when some of them
	# are taken or out of band it simply runs out of tries -- which is a promise
	# that keeps itself in 58 runs out of 60, and the two it drops are the two
	# where the player is told copper is there and it is not.
	#
	# The whole band, not a box round the origin. Seams stand a post apart since
	# Grid v2 and a thin band (the first copper's is 1.4 tiles) with the Lv4 heat
	# stone already in it could leave a box short of room -- 1 seed in 200 got
	# three seams of four. Sorted by distance from the origin, so the patch still
	# forms where the seed pointed; it just never runs out of band.
	var reach: int = int(ceil(Grid.cells(band.y))) + 1
	var centre: Vector2i = core_cell
	var candidates: Array[Vector2i] = []
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var cell: Vector2i = centre + Vector2i(dx, dy)
			var distance: float = _ring_distance(cell)
			if distance < band.x or distance > band.y:
				continue
			if ore_nodes.has(cell) or _ore_reserved(cell) or base_rect().has_point(cell):
				continue
			candidates.append(cell)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Vector2(a - origin).length_squared() < Vector2(b - origin).length_squared())
	var placed := 0
	for cell: Vector2i in candidates:
		if placed >= size:
			break
		if not _ore_spaced(cell):
			continue
		put_ore(cell, item_type)
		placed += 1

## Where no seam may be: the base and a margin round it, the hut and its
## doorstep, the bin, and the lanes the opening's belts run along.
##
## The walks ask it of a node's origin, exactly as they asked it of a one-cell
## seam, so a world generates the same nodes from the same seed it generated
## seams from before nodes existed -- a saved run's posts come back on their
## nodes. What a node's other three cells reach into is settled once every
## random draw is done (`_node_reserved`, in the last pass of `_generate_ore`),
## where taking a node away cannot change where the next one goes.
func _node_reserved(origin: Vector2i) -> bool:
	for cell: Vector2i in ore_cells(origin):
		if _ore_reserved(cell):
			return true
	return false

func _ore_reserved(cell: Vector2i) -> bool:
	if base_rect().grow(2).has_point(cell):
		return true
	if shelter_rect().grow(1).has_point(cell) or food_rect().has_point(cell):
		return true
	if STARTER_COLUMN.has_point(cell - core_cell):
		return true
	return STARTER_LANE.has(cell - core_cell)

## Whether a node with its origin here would keep every other node a lane away.
## Origins at least ORE_PITCH apart leave two cells between two nodes, whichever
## way they lie -- and no node can overlap another.
func _ore_spaced(origin: Vector2i) -> bool:
	var reach: int = Defs.ORE_PITCH - 1
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			if ore_nodes.has(origin + Vector2i(dx, dy)):
				return false
	return true

## The cell a distance in tiles and a direction away from the fire lands on.
func _cell_toward(angle: float, radius_tiles: float) -> Vector2i:
	return Grid.cell_at(core_centre() + Vector2.from_angle(angle) * Grid.px(radius_tiles))

## Ore arrives in patches so the player reads them as destinations rather than
## noise, and so a single miner placement decision matters.
func _scatter_ore(rng: RandomNumberGenerator, item_type: int, ring: Vector2, patches: int, size: int) -> void:
	for index in patches:
		var angle: float = TAU * (float(index) + rng.randf() * 0.6) / float(patches)
		var radius: float = rng.randf_range(ring.x, ring.y)
		var origin: Vector2i = _cell_toward(angle, radius)
		var placed := 0
		var cursor := origin
		var attempts := 0
		# The same walk as ever, in steps of a post's width: every seam of the
		# patch lands on a lattice four cells apart, so each can take a post.
		while placed < size and attempts < size * 12:
			attempts += 1
			if not ore_nodes.has(cursor) and _ring_distance(cursor) >= ring.x - 1.0 \
					and not _ore_reserved(cursor) and _ore_spaced(cursor):
				put_ore(cursor, item_type)
				placed += 1
			cursor = origin + Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1)) \
				* Defs.ORE_PITCH * (1 + placed / 3)

## Crystal, scattered once and never again. Placed after the ore so a piece
## never lands on a seam -- a shard under a miner is a shard nobody can reach.
func _generate_shards(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 5501
	var core_tile: Vector2i = Grid.tile_of(core_cell)
	var attempts := 0
	while shards.size() < Defs.CRYSTAL_SHARDS and attempts < Defs.CRYSTAL_SHARDS * 40:
		attempts += 1
		var angle: float = rng.randf() * TAU
		var radius: float = lerpf(Defs.CRYSTAL_RING.x, Defs.CRYSTAL_RING.y, sqrt(rng.randf()))
		var tile := core_tile + Vector2i(roundi(cos(angle) * radius), roundi(sin(angle) * radius))
		var cell: Vector2i = Grid.from_tile(tile)
		if shards.has(cell) or _tile_ore(tile) or _tile_machine(tile) or tile == core_tile:
			continue
		shards[cell] = true

## Frozen cats lie where they fell, about one per two hundred tiles, plus a
## guaranteed one inside the opening warm radius so the first cat is always
## reachable. Walking further is what buys more workers -- and now the walk back
## is at half speed, which is what makes the distance a decision.
##
## Deliberately the same shape as the crate scatter it replaced, seeded the same
## way: a map generated from a given seed puts its cats in the same places the
## crates would have grouped into.
func _generate_frozen_cats(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 7717
	# Laid out a tile at a time, with the same draws as ever: every distance
	# this function promises is a promise about the world, and the world did not
	# change size when the grid got finer. Each block is stored under the
	# top-left cell of its tile.
	var core_tile: Vector2i = Grid.tile_of(core_cell)
	for index in Defs.STARTER_FROZEN:
		var tile: Vector2i = _starter_frozen_tile(index)
		if tile != core_tile:
			frozen_cats[Grid.from_tile(tile)] = 0.0
	# The one at the fourth step's edge, before the scatter so nothing else can
	# take that cell. Fixed, like every landmark here: it is a scene the design
	# means to happen, not a place the seed might put something.
	_place_edge_frozen()
	# And the Lv3 pair, in the 9.4..10.6 ring the third circle opens. Seed picks
	# the directions so the world does not look stamped; the count is the
	# promise. Opposite-ish angles, so they read as two finds rather than one.
	var second_angle: float = rng.randf() * TAU
	for index in Defs.SECOND_RING_CATS:
		var placed := false
		for try in 24:
			var angle: float = second_angle + TAU * float(index) / float(Defs.SECOND_RING_CATS) \
				+ float(try % 8) * 0.11
			var ring: float = Defs.SECOND_RING.x \
				+ (Defs.SECOND_RING.y - Defs.SECOND_RING.x) * float(try / 8) * 0.5
			var tile := core_tile + Vector2i(roundi(cos(angle) * ring), roundi(sin(angle) * ring))
			if _tile_frozen(tile) or _tile_ore(tile) or _tile_machine(tile):
				continue
			if tile == core_tile or _tile_building(tile):
				continue
			var distance: float = Vector2(tile - core_tile).length()
			if distance < Defs.SECOND_RING.x or distance > Defs.SECOND_RING.y:
				continue
			frozen_cats[Grid.from_tile(tile)] = 0.0
			placed = true
			break
		if not placed:
			# Last resort keeps the promise: the exact ring cell in the raw
			# direction, cleared. A promise that keeps itself in 58 runs out of
			# 60 drops the two runs where it was made.
			var angle: float = second_angle + TAU * float(index) / float(Defs.SECOND_RING_CATS)
			var tile := core_tile + Vector2i(roundi(cos(angle) * 10.0), roundi(sin(angle) * 10.0))
			for cell: Vector2i in Grid.cells_in(Grid.tile_rect(tile)):
				erase_ore_at(cell)
			frozen_cats[Grid.from_tile(tile)] = 0.0
	var reach: float = Defs.WARM_MAX + 8.0
	var target: int = int((PI * reach * reach) / Defs.FROZEN_PER_TILES)
	var attempts := 0
	while frozen_cats.size() < target + Defs.STARTER_FROZEN and attempts < target * 30:
		attempts += 1
		var angle: float = rng.randf() * TAU
		var radius: float = sqrt(rng.randf()) * reach
		var tile := core_tile + Vector2i(roundi(cos(angle) * radius), roundi(sin(angle) * radius))
		if _tile_frozen(tile) or _tile_ore(tile) or _tile_machine(tile):
			continue
		if Vector2(tile - core_tile).length() < Defs.FROZEN_SCATTER_MIN:
			continue
		frozen_cats[Grid.from_tile(tile)] = 0.0

# --- The generator's tile lattice ---------------------------------------------
## Questions the placement of tile-sized things asks about a whole tile.

func _tile_ore(tile: Vector2i) -> bool:
	for cell: Vector2i in Grid.cells_in(Grid.tile_rect(tile)):
		if has_ore(cell):
			return true
	return false

func _tile_frozen(tile: Vector2i) -> bool:
	for cell: Vector2i in Grid.cells_in(Grid.tile_rect(tile)):
		if frozen_key(cell) != NONE:
			return true
	return false

func _tile_machine(tile: Vector2i) -> bool:
	for cell: Vector2i in Grid.cells_in(Grid.tile_rect(tile)):
		if machine_at(cell) != null:
			return true
	return false

func _tile_structure(tile: Vector2i) -> bool:
	for cell: Vector2i in Grid.cells_in(Grid.tile_rect(tile)):
		if is_structure(cell):
			return true
	return false

## The base, the hut or the bin covers any of it.
func _tile_building(tile: Vector2i) -> bool:
	var rect: Rect2i = Grid.tile_rect(tile)
	return rect.intersects(base_rect()) or rect.intersects(shelter_rect()) \
		or rect.intersects(food_rect())

## The village, the sign, and the tracks between them.
##
## Fixed coordinates, like every other landmark in this world: the fire decides
## where it is and nothing rolls for it. A place a player can be told about has
## to be in the same spot for every player who is told.
func _generate_village() -> void:
	village.clear()
	trail.clear()
	# Hidden from the main path (2026-09-01). The factory is the game and the
	# story is a secret: the sign stood 19.8 cells out -- inside the 18~21
	# minute stretch -- and pointed the golden path's last act somewhere else.
	# Nothing is deleted: flip `story_enabled` before setup() and every house,
	# frozen villager, signpost and footprint generates exactly as before.
	# `debug_village` flips it for a look.
	if not story_enabled:
		sign_cell = NONE
		village_rect = Rect2i()
		return
	# Laid out in tiles, like every landmark: the offsets in Defs are tiles.
	var core_tile: Vector2i = Grid.tile_of(core_cell)
	var sign_tile: Vector2i = core_tile + Defs.SIGN_OFFSET
	sign_cell = Grid.from_tile(sign_tile)
	var origin: Vector2i = core_tile + Defs.VILLAGE_OFFSET \
		- Vector2i(Defs.VILLAGE_CELLS.x / 2, Defs.VILLAGE_CELLS.y / 2)
	village_rect = Rect2i(Grid.from_tile(origin), Defs.VILLAGE_CELLS * Grid.SCALE)
	# Emptied first. Ore, wreckage and the scattered ice all landed here before
	# anyone decided this square was a village, and a house with a seam under it
	# is a house nobody can walk into.
	for cell: Vector2i in Grid.cells_in(village_rect):
		erase_ore_at(cell)
		shards.erase(cell)
	for y in Defs.VILLAGE_CELLS.y:
		for x in Defs.VILLAGE_CELLS.x:
			var at: Vector2i = Grid.from_tile(origin + Vector2i(x, y))
			debris.erase(at)
			frozen_cats.erase(at)
	for cell: Vector2i in Grid.cells_in(Grid.tile_rect(sign_tile)):
		erase_ore_at(cell)
	debris.erase(sign_cell)
	frozen_cats.erase(sign_cell)
	for piece: Dictionary in Defs.VILLAGE_PIECES:
		village[Grid.from_tile(origin + Vector2i(piece["cell"]))] = int(piece["id"])
	for local: Vector2i in Defs.VILLAGE_FROZEN:
		frozen_cats[Grid.from_tile(origin + local)] = 0.0
	_trace_trail(sign_tile, origin + _village_gate_local())

func _village_gate_local() -> Vector2i:
	for piece: Dictionary in Defs.VILLAGE_PIECES:
		if int(piece["id"]) == Defs.VILLAGE_GATE:
			return Vector2i(piece["cell"])
	return Vector2i(Defs.VILLAGE_CELLS.x / 2, Defs.VILLAGE_CELLS.y - 1)

## Footprints, not a road. The line wanders a cell either side so it reads as
## something that was walked rather than built, and the wander is a hash of the
## row so the same world always has the same path -- a trail that reshuffled
## every time it was drawn would shimmer.
func _trace_trail(from: Vector2i, to: Vector2i) -> void:
	# In tiles: a footprint is a stride apart whatever the grid is doing. Each
	# mark is stored under the top-left cell of its tile.
	var steps: int = absi(to.y - from.y)
	var x: int = from.x
	for step in range(1, steps + 1):
		var y: int = from.y - step
		# A walk rather than a function of the row. The first version picked the
		# offset from a hash of `y`, which is a wander on paper and on the ground
		# was a set of marks that jumped two cells sideways between rows -- and a
		# footprint two cells from the last one is not a footprint, it is a
		# second path. One step at a time, never more than a cell off the line.
		x += posmod(y * 73856093 + step * 19349663, 3) - 1
		x = clampi(x, from.x - 1, from.x + 1)
		var tile := Vector2i(x, y)
		var cell: Vector2i = Grid.from_tile(tile)
		if village.has(cell):
			continue
		trail[cell] = posmod(y, 2)
		# Whatever the scatter put on the path comes off it. The tracks are the
		# one thing in the fog that says "this way", and a boulder standing on
		# them is the sentence with a word missing.
		for covered: Vector2i in Grid.cells_in(Grid.tile_rect(tile)):
			erase_ore_at(covered)
		debris.erase(cell)

## Whether a cell is inside the village square at all.
func in_village(cell: Vector2i) -> bool:
	return village_rect.has_point(cell)

## What is standing on a cell, or -1. Asked by the drawing, the collision and the
## belt, so that "is there a house here" has one answer.
func village_piece(cell: Vector2i) -> int:
	var key: Vector2i = village_key(cell)
	return int(village.get(key, -1)) if key != NONE else -1

## The block that sits just past the fourth circle.
##
## Searched outward by half a cell if the exact spot is taken, but never inward:
## being *outside* the radius is the whole point, and one cell nearer would make
## it a cat she picks up without noticing there was anything to notice.
func _place_edge_frozen() -> void:
	var core_tile: Vector2i = Grid.tile_of(core_cell)
	for step in 24:
		var radius: float = Defs.EDGE_FROZEN_RING + float(step / 8) * 0.5
		var angle: float = Defs.EDGE_FROZEN_ANGLE + TAU * float(step % 8) / 8.0
		var tile := core_tile + Vector2i(roundi(cos(angle) * radius),
			roundi(sin(angle) * radius))
		if tile == core_tile or _tile_ore(tile) or _tile_frozen(tile):
			continue
		if _tile_structure(tile) or _tile_building(tile):
			continue
		# Past the third circle and inside the fourth, checked rather than
		# expected: the first candidate always was, but a node is a tile across
		# now and takes that tile more often, and the next angle's rounding can
		# land a tenth of a tile inside the circle the hint is about.
		var ring: float = _ring_distance(Grid.from_tile(tile))
		if ring <= float(Defs.BASE_LEVELS[2]["radius"]) or ring >= float(Defs.BASE_LEVELS[3]["radius"]):
			continue
		frozen_cats[Grid.from_tile(tile)] = 0.0
		edge_frozen = Grid.from_tile(tile)
		return

## Blocks of ice riding the belts.
##
## Grim slides on a belt and so does everything the belt carries, and a block of
## ice standing on one used to be the exception -- which reads as the belt
## running underneath it rather than as the belt being unable to move it. It is
## the heaviest thing a player can put down, so it travels at the same speed as
## everything else and simply stops when the next cell is taken.
func _tick_frozen_drift(delta: float) -> void:
	if frozen_cats.is_empty():
		return
	for cell: Vector2i in frozen_cats.keys():
		var drift: Vector2 = _prop_drift(cell)
		if drift == Vector2.ZERO:
			frozen_offset.erase(cell)
			continue
		var step := Vector2i(signi(int(round(drift.x))), signi(int(round(drift.y))))
		var ahead: Vector2i = cell + step
		# Whatever is standing there stops it. Checked before moving rather than
		# after, because a block that has already been written into the next cell
		# has overwritten whatever was in it. Only the cells it would newly
		# cover: the block is a tile across and mostly overlaps itself.
		var blocked := false
		var from: Rect2i = prop_rect(cell)
		for covered: Vector2i in Grid.cells_in(prop_rect(ahead)):
			if not from.has_point(covered) and not _frozen_may_enter(covered):
				blocked = true
				break
		if blocked:
			frozen_offset.erase(cell)
			continue
		var offset: Vector2 = frozen_offset.get(cell, Vector2.ZERO)
		offset += drift * delta
		if offset.length() < float(Grid.CELL):
			frozen_offset[cell] = offset
			continue
		# Over the line: the block belongs to the next cell now, and what is left
		# of the offset carries on there so the slide does not stutter at every
		# boundary.
		frozen_offset.erase(cell)
		frozen_cats[ahead] = frozen_cats[cell]
		frozen_cats.erase(cell)
		if thawed.has(cell):
			thawed[ahead] = true
		frozen_offset[ahead] = offset - Vector2(step) * float(Grid.CELL)

## Which way the belts under a block drag it. The block is a tile across and
## a belt is a cell, so it is whichever belt under it is found first -- in
## reading order, so the answer does not change from frame to frame.
func _prop_drift(origin: Vector2i) -> Vector2:
	for covered: Vector2i in Grid.cells_in(prop_rect(origin)):
		var drift: Vector2 = belt_drift(covered)
		if drift != Vector2.ZERO:
			return drift
	return Vector2.ZERO

## Where a sliding block is allowed to go. Anything solid stops it, and so does
## the fire itself -- a block pushed into the core would be a cat fed to it.
func _frozen_may_enter(cell: Vector2i) -> bool:
	if frozen_key(cell) != NONE or debris_key(cell) != NONE or has_ore(cell):
		return false
	var piece: int = village_piece(cell)
	if piece >= 0 and not Defs.village_walkable(piece):
		return false
	if is_sign(cell) or is_kit(cell):
		return false
	if is_base(cell) or in_shelter(cell) or in_food_bin(cell):
		return false
	var machine: Machine = machine_at(cell)
	return machine == null or machine.type in Defs.WALKABLE_MACHINES

## Where a block of ice is actually drawn, which is its cell plus however far it
## has slid out of it.
func frozen_at(cell: Vector2i) -> Vector2:
	return prop_centre(cell) + frozen_offset.get(cell, Vector2.ZERO)

## The middle of the room, in world pixels.
func room_centre() -> Vector2:
	return Grid.origin(Defs.room_to_world(Vector2i.ZERO)) \
		+ Vector2(Defs.ROOM_CELLS) * float(Grid.TILE) * 0.5

## Everyone goes in. The cats keep whatever they were doing in their heads --
## `assigned` survives the night, which is the thing the player set -- but they
## are awake and strolling in here, because that is what a cat with no job does
## anywhere else in this game.
## `arriving` is the evening: she opens the door and the crew files in behind
## her. The morning is the same room from the inside -- nobody arrives, everybody
## is already asleep on the floor -- and passing false is what says so. It used
## to be one path, which is why the morning began with cats pouring out of the
## front door of the room they had slept in.
func enter_room(at: Vector2i, arriving: bool = true) -> void:
	indoors = true
	_grid_dirty = true
	if not arriving:
		_settle_sleepers()
		return
	# In through the door, one at a time, rather than already spread across the
	# floor. They were placed on their spots the instant she stepped inside,
	# which reads as a room that was always full -- and the cats had been out on
	# the plateau a second earlier. Each waits a beat longer than the last and
	# then walks in from the doorway.
	var door: Vector2 = Defs.room_centre(Defs.room_door_cell())
	for index in cats.size():
		var cat: Cat = cats[index]
		cat.state = Defs.CAT_IDLE
		cat.path.clear()
		cat.wander_timer = wander_rng.randf_range(0.1, 0.6)
		cat.entering = Defs.ROOM_ENTER_GAP * float(index)
		cat.pos = door

## Morning, from inside. Everyone is where they slept -- spread across the floor
## rather than stacked on the mat -- and each gets up on its own second, between
## one and four, so the room comes awake instead of switching on.
func _settle_sleepers() -> void:
	for index in cats.size():
		var cat: Cat = cats[index]
		cat.entering = 0.0
		cat.path.clear()
		cat.state = Defs.CAT_ASLEEP
		cat.waking = wander_rng.randf_range(Defs.ROOM_WAKE_MIN, Defs.ROOM_WAKE_MAX)
		cat.wander_timer = wander_rng.randf_range(0.1, 0.8)
		var spot: Vector2i = Defs.ROOM_CAT_SPOTS[index % Defs.ROOM_CAT_SPOTS.size()]
		cat.pos = Defs.room_centre(spot)

## And out. Whatever they were assigned to is where they head.
## Out of the room. `wake` is false during the night rest (Quality Pass 01):
## she may go back out into the dark, but the crew stays in -- asleep in the
## hut, where the morning (`rouse_cats`) finds them. Waking them here sent every
## cat with a post back to work for the rest of the night the moment she opened
## the door.
func leave_room(at: Vector2, wake: bool = true) -> void:
	indoors = false
	_grid_dirty = true
	for cat: Cat in cats:
		cat.entering = 0.0
		cat.waking = 0.0
	if wake:
		wake_cats(at)
		return
	for cat: Cat in cats:
		if cat == carried_cat:
			continue
		cat.path.clear()
		cat.path_goal = Vector2(1e20, 1e20)
		cat.pos = shelter_centre()
		cat.state = Defs.CAT_ASLEEP

## Everyone drops where they are and sleeps, on the frame she lies down.
func sleep_cats() -> void:
	for cat: Cat in cats:
		# Whoever was still on the doorstep is in: she is going to bed, and a cat
		# left mid-entrance would be a cat that never arrives.
		cat.entering = 0.0
		cat.waking = 0.0
		cat.state = Defs.CAT_ASLEEP
		cat.path.clear()

## Wreckage, from the eleventh ring outward.
##
## The first piece is placed on its ring by walking round it rather than by
## taking one cell and hoping: the cell can hold a seam or a frozen cat, and
## "the guaranteed piece did not fit" is a run where the rule the whole feature
## rests on is quietly untrue. This repository has the same lesson written down
## from the day three starting crates became one frozen cat.
func _generate_debris(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 5501
	var core_tile: Vector2i = Grid.tile_of(core_cell)
	var base_angle: float = rng.randf() * TAU
	for step in 96:
		var angle: float = base_angle + TAU * float(step) / 96.0
		var tile := core_tile + Vector2i(
			roundi(cos(angle) * Defs.DEBRIS_FIRST_RING),
			roundi(sin(angle) * Defs.DEBRIS_FIRST_RING))
		# On the ring, not merely near it. Rounding a circle onto a grid puts
		# some of its cells a little in and a little out, and a piece that lands
		# at 10.6 is inside the empty zone the rule promises.
		if roundi(Vector2(tile - core_tile).length()) != int(Defs.DEBRIS_FIRST_RING):
			continue
		if not _debris_free(tile):
			continue
		debris[Grid.from_tile(tile)] = rng.randi_range(0, Defs.DEBRIS_SHAPES - 1)
		break
	var reach: float = Defs.WARM_MAX + 8.0
	var inner: float = Defs.DEBRIS_START_RING
	var target: int = int(PI * (reach * reach - inner * inner) / Defs.DEBRIS_PER_TILES)
	var attempts := 0
	# A cap on the tries as well as on the count. An unbounded search for a free
	# cell is how world generation hung once already.
	while debris.size() < target + 1 and attempts < target * 30:
		attempts += 1
		var angle: float = rng.randf() * TAU
		# sqrt so the points spread evenly over the disc rather than crowding
		# the middle, which here is the edge of the empty zone.
		var radius: float = sqrt(rng.randf()) * reach
		var tile := core_tile + Vector2i(roundi(cos(angle) * radius), roundi(sin(angle) * radius))
		if Vector2(tile - core_tile).length() < inner or not _debris_free(tile):
			continue
		debris[Grid.from_tile(tile)] = rng.randi_range(0, Defs.DEBRIS_SHAPES - 1)

## Somewhere a piece can lie without covering something else that matters. A
## tile, since pieces are laid out a tile at a time.
func _debris_free(tile: Vector2i) -> bool:
	var cell: Vector2i = Grid.from_tile(tile)
	if debris.has(cell) or _tile_ore(tile) or _tile_machine(tile) or _tile_frozen(tile):
		return false
	for covered: Vector2i in Grid.cells_in(Grid.tile_rect(tile)):
		if shards.has(covered) or has_rock(covered):
			return false
	return tile != Grid.tile_of(core_cell) and not _tile_building(tile)

## Taking one apart. Held, like the case and like a seam.
func search_debris(cell: Vector2i, delta: float) -> bool:
	var key: Vector2i = debris_key(cell)
	if key == NONE or not can_touch(cell):
		cancel_debris()
		return false
	cell = key
	if cell != debris_cell:
		debris_cell = cell
		debris_progress = 0.0
	debris_progress += delta / Defs.DEBRIS_SEARCH_SECONDS
	return debris_progress >= 1.0

func cancel_debris() -> void:
	debris_cell = Vector2i(9999, 9999)
	debris_progress = 0.0

## What comes out, item -> count, and the piece is gone. Empty when there was
## nothing there to open.
##
## The first piece always carries a core part. Twenty percent is a fair rate for
## a plateau covered in wreckage and a terrible one for the piece that has to
## teach the player that core parts exist -- four players in five would walk away
## from the guaranteed piece having learned that debris contains scrap.
func open_debris(cell: Vector2i) -> Dictionary:
	var key: Vector2i = debris_key(cell)
	if key == NONE or not can_touch(cell):
		return {}
	var first: bool = debris_searched == 0
	debris.erase(key)
	debris_searched += 1
	cancel_debris()
	# The top of the seam ladder and the rung under it. When the ladder is one
	# rung long -- which it is not today, but a list of two is a list that can
	# become a list of one -- both lines land on the same resource and are added
	# rather than one of them silently going missing.
	# The top of the seam ladder she has actually reached, not the top of the
	# list. A player who has never held copper does not know the word, and a case
	# of it out of the first wreck names a material the world has not shown her
	# yet -- the same leak that took "구리가 있는 곳까지" off the mission card.
	var reached: int = Defs.ORE_TIERS.size() - 1
	while reached > 0 and int(collected.get(Defs.ORE_TIERS[reached], 0)) <= 0:
		reached -= 1
	var top: int = Defs.ORE_TIERS[reached]
	# The rung under it, and it has to pass the same test. With two rungs the one
	# below was always heat stone and always held, so this was safe by accident;
	# with three, a player who walked out to iron without ever picking up copper
	# gets a case of a material the world has not named for her -- the exact leak
	# the paragraph above is about.
	var under: int = maxi(reached - 1, 0)
	while under > 0 and int(collected.get(Defs.ORE_TIERS[under], 0)) <= 0:
		under -= 1
	var below: int = Defs.ORE_TIERS[under]
	var out: Dictionary = {}
	out[top] = debris_rng.randi_range(Defs.DEBRIS_HIGH.x, Defs.DEBRIS_HIGH.y)
	out[below] = int(out.get(below, 0)) \
		+ debris_rng.randi_range(Defs.DEBRIS_LOW.x, Defs.DEBRIS_LOW.y)
	var cores: int = 1 if first else 0
	if not first:
		var roll: float = debris_rng.randf()
		if roll < Defs.DEBRIS_CORE_TWO:
			cores = 2
		elif roll < Defs.DEBRIS_CORE_TWO + Defs.DEBRIS_CORE_ONE:
			cores = 1
	if cores > 0:
		out[Defs.ITEM_ENERGY_CORE] = cores
	for item_type: int in out:
		_gain(item_type, int(out[item_type]))
	return out

## The one frozen cat that has to be inside the opening warm radius, wherever
## the terrain left room. Walks the ring from its nominal angle rather than
## taking that one cell or giving up: the cell can hold a seam, the shelter or a
## previous starter, and "no cat within reach" is a run that cannot begin.
func _starter_frozen_tile(index: int) -> Vector2i:
	var core_tile: Vector2i = Grid.tile_of(core_cell)
	var base_angle: float = TAU * float(index) / float(Defs.STARTER_FROZEN) + 0.6
	for step in 48:
		# Out from the nominal ring in half-tile rings, all the way round each.
		var radius: float = Defs.FROZEN_MIN_RING + float(step / 16) * 0.5
		var angle: float = base_angle + TAU * float(step % 16) / 16.0
		var tile := core_tile + Vector2i(roundi(cos(angle) * radius), roundi(sin(angle) * radius))
		if tile == core_tile or _tile_ore(tile) or _tile_frozen(tile):
			continue
		if _tile_structure(tile) or _tile_building(tile):
			continue
		return tile
	return core_tile

## Whether a boulder is standing on this cell.
##
## The field is a pure function of the coordinates -- one clump seeded per block,
## grown to fill its own concavities -- so there is nothing to generate and
## nothing to store except which ones have been broken. Only the blocks within
## reach can claim a cell, and a clump of twelve cannot travel further than one
## block from its seed.
##
## Laid out a tile at a time: the field is a function of tile coordinates, and
## every cell of a boulder tile answers for the whole boulder. `mined_rocks`
## remembers broken ones by tile for the same reason.
func has_rock(cell: Vector2i) -> bool:
	if not Defs.ROCK_FIELD:
		return false
	var rock_tile: Vector2i = Grid.tile_of(cell)
	if mined_rocks.has(rock_tile) or has_ore(cell) or machine_at(cell) != null:
		return false
	# Rock is procedural, so it exists under every cell in the world that the
	# generator did not empty -- and the generator's dictionaries are the only
	# thing it *can* empty. The village square and its footpath are cleared here
	# instead, which is the same answer given in the one place that decides it.
	if in_village(cell) or trail.has(Grid.from_tile(rock_tile)) or is_sign(cell):
		return false
	var block := Vector2i(floori(float(rock_tile.x) / float(Defs.ROCK_BLOCK)),
		floori(float(rock_tile.y) / float(Defs.ROCK_BLOCK)))
	for by in range(block.y - Defs.ROCK_REACH, block.y + Defs.ROCK_REACH + 1):
		for bx in range(block.x - Defs.ROCK_REACH, block.x + Defs.ROCK_REACH + 1):
			if rock_tile in Defs.rock_clump(Vector2i(bx, by)):
				return true
	return false

## --- Tile attributes ------------------------------------------------------
## Buildings carry STRUCTURE; terrain does not. Keeping this as a lookup rather
## than a stored grid means adding an attribute later is one branch here, not a
## migration of every save.
func tile_attributes(cell: Vector2i) -> int:
	var attrs: int = Defs.ATTR_NONE
	# Ore used to be a structure and is terrain now: a seam is a tile you walk
	# over, drawn with the floor rather than standing on it.
	#
	# A machine takes its place. Building onto a seam is the game's central
	# placement and a machine is a solid object once it is there, so the cell
	# stops being walkable at the moment it stops being bare ground.
	#
	# Belts and splitters are the exceptions and they are named in Defs, not
	# here, so that the question "can I walk on this" has one answer in one place
	# -- and so a machine added later blocks until someone decides otherwise.
	var machine: Machine = machine_at(cell)
	if machine != null and machine.type not in Defs.WALKABLE_MACHINES:
		attrs |= Defs.ATTR_STRUCTURE
	# Inside the hut. The floor is open, the furniture is solid and everything
	# past the four walls is wall -- so the same mover that walks her round a
	# miner keeps her in the room, and the same pathing keeps the cats off the
	# sofa. There is nothing here that knows it is indoors except this branch.
	if indoors or Defs.in_room(cell):
		if not Defs.in_room(cell) or not Defs.room_walkable(Defs.world_to_room(cell)):
			return Defs.ATTR_STRUCTURE
		return Defs.ATTR_NONE
	# A block of ice with a cat in it, and a piece of the ship. Both are objects
	# standing on the snow that the player used to walk straight through, which
	# is the one thing a picture of a solid thing must never allow -- and out
	# past the fire, where neither can be touched yet, walking through them was
	# also the answer to a wall the design had just put up.
	#
	# Cats are unaffected: they path by position rather than by this, and a cat
	# that cannot walk over a piece of wreckage is a cat that gets stuck behind
	# one on its way home.
	if frozen_key(cell) != NONE or debris_key(cell) != NONE:
		attrs |= Defs.ATTR_STRUCTURE
	# Somebody's house, the well, the fire they sit round. Buildings on the grid
	# like every other building; the gate is the exception and it is the whole
	# point of a gate.
	var piece: int = village_piece(cell)
	if piece >= 0 and not Defs.village_walkable(piece):
		attrs |= Defs.ATTR_STRUCTURE
	# And the board, for the same reason the ice and the wreckage are solid: it
	# is a post driven into the ground, and walking through the picture of one is
	# the single thing a picture of a solid object must never allow.
	if is_sign(cell):
		attrs |= Defs.ATTR_STRUCTURE
	# The case she wakes up beside, for the same reason as the ice and the
	# wreckage: it is a metal box sitting on the snow, drawn as one, and she used
	# to walk through the middle of it. It is also the first object in the game,
	# so what it teaches about solid things is what she will assume about all of
	# them.
	if is_kit(cell):
		attrs |= Defs.ATTR_STRUCTURE
	# The shelter is a building on the grid, not a decal painted over it.
	if in_shelter(cell):
		attrs |= Defs.ATTR_STRUCTURE
	# So is the food bin. It is a box of fish standing in the snow and the player
	# walked straight through it, which is the one thing a picture of a solid
	# object must never let you do. Cats are unaffected: they path by position,
	# not by this, and they have to be able to reach the bowl.
	if in_food_bin(cell):
		attrs |= Defs.ATTR_STRUCTURE
	return attrs

func has_attribute(cell: Vector2i, attribute: int) -> bool:
	return (tile_attributes(cell) & attribute) != 0

func is_structure(cell: Vector2i) -> bool:
	return has_attribute(cell, Defs.ATTR_STRUCTURE)

## Structures stop the player's body. Machines do not: the player walks over
## belts and stands on their own miners.
func blocks_player(cell: Vector2i) -> bool:
	return is_structure(cell)

## How far a cell is from the fire, in tiles -- the unit every ring, band and
## radius is written in.
func _ring_distance(cell: Vector2i) -> float:
	return tiles_from_core(cell)

func tiles_from_core(cell: Vector2i) -> float:
	return Grid.tiles(Grid.centre(cell).distance_to(core_centre()))

func tiles_from_core_at(point: Vector2) -> float:
	return Grid.tiles(point.distance_to(core_centre()))

## Where the fire is, in world pixels. The middle of the base, which every ring
## in the world is measured from and every warm circle is drawn around.
##
## The base's footprint centre -- eight cells across, so the middle is a corner
## between four cells, exactly where the middle of the tile it grew from was.
func core_centre() -> Vector2:
	return Grid.rect_centre(base_rect())

## Whether a lit torch is in her hand this frame. Set by Main, which is the only
## thing that knows what she is holding.
##
## The fire's reach is one way to make a cell touchable and carrying heat out to
## it is the other -- and the second one is what stops exploration from being a
## queue behind the base ladder.
var torch_lit := false

## True while everyone is inside the hut. The room is a place on the grid, so
## this is what tells the world not to draw snow around it and the cats to
## stroll around the fireplace rather than set off for the base.
var indoors := false

## Pieces of the ship, cell -> which of the five shapes. Shape is stored rather
## than derived from the cell so that a piece cannot change what it looks like
## when the numbers behind the world do.
## How far a block of ice has slid within its cell, in pixels. Only ever along
## the belt under it, and only for the blocks that are on one.
##
## Kept beside `frozen_cats` rather than inside it because that map's value is
## the thaw and is written into every save; a second map that is not saved says
## exactly what it is -- a block halfway between two cells is a moment, not a
## fact about the world.
var frozen_offset: Dictionary = {}

var debris: Dictionary = {}
## How many have been taken apart. The first one is the one that is guaranteed to
## carry a core part, so this is a count and not a flag.
var debris_searched: int = 0
var debris_cell := Vector2i(9999, 9999)
var debris_progress: float = 0.0
## Seeded off the run so a replayed seed disassembles to the same materials.
## Separate from the world generator, which has already finished by then.
var debris_rng := RandomNumberGenerator.new()

## Cells whose ground has been thawed out with a torch. Saved, because five
## seconds spent on a cell is work and a reload that undid it would be a theft.
var thawed: Dictionary = {}
var thaw_cell := Vector2i(9999, 9999)
var thaw_progress: float = 0.0

## Things that go into her arms rather than into the stores.
##
## The torch alone opens everything that is *taken* -- swung at, walked over,
## lifted off a belt. What has to be carried is different: it is frozen into the
## ground where it lies, and the ground is what the five seconds are spent on.
func is_liftable(cell: Vector2i) -> bool:
	return frozen_key(cell) != NONE or cat_on(cell) != null

## The cat standing on a cell, or null.
##
## The cell it is on, not the cell it is nearest. Both of the things Z can pick
## up used to be found by searching a radius round the target, and a cat is a
## body moving between cells rather than a thing sitting in one -- so a cat
## walking diagonally past came within reach of the cell in front of her and was
## scooped up instead of whatever she was actually facing.
func cat_on(cell: Vector2i) -> Cat:
	for cat: Cat in cats:
		if cat != carried_cat and cell_of(cat.pos) == cell:
			return cat
	return null

## Whether what is on this cell can be picked up and carried.
##
## A torch does not answer this one. It makes the cell reachable; the ground
## still has to be melted, and that is five seconds standing over it.
func can_lift(cell: Vector2i) -> bool:
	# Nothing is frozen to the floor of a heated room. Both of the rules below
	# are about the fire's reach, and the shelter is six hundred cells outside
	# it -- so out here they answered "out of reach" about a room with a hearth
	# in it, and a cat sitting on the rug could not be picked up.
	if Defs.in_room(cell):
		return true
	# A block of ice is asked about as a whole: its middle is what is warm or
	# not, and the thaw is remembered under its origin.
	var key: Vector2i = frozen_key(cell)
	if key != NONE:
		return not base_placed or is_warm_at(prop_centre(key)) \
			or bool(thawed.get(key, false))
	return not base_placed or is_warm(cell) or bool(thawed.get(cell, false))

## Melting the ground under something, a frame at a time. True on the frame it
## finishes. The caller decides whether the conditions still hold -- a torch in
## her hand, standing there -- because those are hers to know, not the world's.
func thaw_ground(cell: Vector2i, delta: float) -> bool:
	if can_lift(cell):
		thaw_progress = 0.0
		thaw_cell = Vector2i(9999, 9999)
		return false
	# The ground under the block, not whichever of its cells she happened to face.
	var key: Vector2i = frozen_key(cell)
	if key != NONE:
		cell = key
	if cell != thaw_cell:
		thaw_cell = cell
		thaw_progress = 0.0
	thaw_progress += delta
	if thaw_progress < Defs.THAW_GROUND_SECONDS:
		return false
	thawed[cell] = true
	thaw_progress = 0.0
	thaw_cell = Vector2i(9999, 9999)
	return true

func cancel_thaw() -> void:
	thaw_progress = 0.0
	thaw_cell = Vector2i(9999, 9999)

func thaw_fraction() -> float:
	return clampf(thaw_progress / Defs.THAW_GROUND_SECONDS, 0.0, 1.0)

## Whether the player can take what is on this cell.
##
## Outside the fire's reach everything is frozen into the ground: it can be seen
## and walked to and not had. One predicate rather than a check at each verb,
## because "the rule applies to every way of acquiring something" is a claim
## about all of them -- and this repository has a record of exactly that kind of
## rule written into nine handlers with six of them missing it.
##
## Before the base is placed there is no reach and no crafting either, so the
## rule is off: a refusal in the first minute is a wall with no door in it.
func can_touch(cell: Vector2i) -> bool:
	if Defs.in_room(cell):
		return true
	return not base_placed or is_warm_at(touch_point(cell)) or torch_lit

## Where the fire's reach is measured for whatever is on a cell. A thing a tile
## across is in reach or not as a whole -- its middle decides -- so the cell of
## it she happens to be facing cannot change the answer.
func touch_point(cell: Vector2i) -> Vector2:
	for props: Dictionary in [frozen_cats, debris, village]:
		var key: Vector2i = prop_key(props, cell)
		if key != NONE:
			return prop_centre(key)
	# A node is a tile across too, and one thing: all four cells are in reach or
	# none are, measured where its distance is (`ore_tiles_from_core`).
	if has_ore(cell):
		return Grid.centre(ore_origin_at(cell))
	return Grid.centre(cell)

## How far a tile-sized thing stored under `origin` is from the fire, in tiles.
func prop_tiles_from_core(origin: Vector2i) -> float:
	return tiles_from_core_at(prop_centre(origin))

func is_warm(cell: Vector2i) -> bool:
	return base_placed and _ring_distance(cell) <= warm_radius

## The same, for a point: a thing a tile across is warm when its middle is.
func is_warm_at(point: Vector2) -> bool:
	return base_placed and tiles_from_core_at(point) <= warm_radius

## Whether Grim is already carrying something. Asked in one place because there
## are three things she can be holding and only one pair of arms -- and because
## the last time a rule like this was written per case, six of nine handlers
## were missing it.
func hands_full() -> bool:
	return carried_cat != null or carried_frozen or carried_kit != Defs.KIT_NONE

## --- The crash --------------------------------------------------------------
## Takes the base back off the map. Everything else the world generated stays
## exactly where it is: the ore, the frozen cats and the fog are all placed
## around this point, and this point does not move.
func begin_crash() -> void:
	remove_machine(core_cell)
	base_placed = false
	shelter_placed = false
	food_placed = false
	carried_kit = Defs.KIT_NONE
	kit_searched = 0
	# The case lies on the world anchor and she lands one walk short of it.
	#
	# It is the case that becomes the base, so the anchor has to be the case's
	# own cell: every ring promise out there -- the Lv2 cat at 8.5, the copper
	# band, the wreck ring -- is measured from where the fire ends up, and the
	# first version of this unfolded two cells over and put the "out of reach
	# until Lv2" cat inside the first circle in all two hundred seeds.
	#
	# Until it unfolds, `core_cell` is simply where she is. Four layers draw the
	# lit circle around it, and centring that circle on the case instead would
	# stand her in the fog at its rim on the first frame of the game.
	kit_cell = core_cell
	core_cell = kit_cell - Defs.KIT_OFFSET * Grid.SCALE
	warm_radius = Defs.CRASH_SIGHT
	_cached_radius = warm_radius
	shown_radius = warm_radius
	explored.clear()
	mark_explored(core_cell, int(Defs.CRASH_SIGHT))
	_grid_dirty = true

## Puts the emergency base down. The base is the centre of everything the world
## already has -- the warm radius, the shelter's spot, the food bin's -- so
## moving it moves those with it, and nothing else notices because two tiles is
## smaller than any distance the generator cares about.
func place_base(cell: Vector2i) -> bool:
	if base_placed or carried_kit != Defs.KIT_BASE:
		return false
	if Grid.tiles(Grid.centre(cell).distance_to(core_centre())) > Defs.BASE_PLACE_RADIUS:
		return false
	# The case she is carrying the base out of is not in its own way: a base four
	# tiles across put down beside it covers it, and the case goes.
	# Seams give way too, the way they do under the case unfolding: the base is
	# four tiles across and would otherwise be refused by any seam the scatter
	# left within two tiles of wherever she is standing.
	var problems: Dictionary = rect_problems(Defs.machine_footprint(Defs.M_CORE, cell))
	for blocked: Vector2i in problems.keys():
		if is_kit(blocked) or (has_ore(blocked) and machine_at(blocked) == null):
			problems.erase(blocked)
	if not problems.is_empty():
		return false
	core_cell = cell
	if kit_cell != NONE and prop_rect(kit_cell).intersects(base_rect()):
		kit_cell = NONE
	_clear_under(base_rect())
	shelter_cell = core_cell + Defs.SHELTER_CELL
	food_cell = shelter_cell + Defs.FOOD_CELL
	var core := Machine.new()
	core.type = Defs.M_CORE
	core.cell = core_cell
	add_machine(core)
	base_placed = true
	carried_kit = Defs.KIT_NONE
	_grid_dirty = true
	_refresh_radius()
	mark_explored(core_cell, Defs.BASE_REVEAL_RADIUS)
	return true

## And the shelter, which is where she sleeps and where the cats go at night. It
## has to stand clear of the base -- a hut built against the fire is a hut that
## teaches nothing about the fire.
## Too close to the fire to put the hut down. The world layer paints these cells
## red while she is carrying it, and both read the same function: a rule drawn
## from one place and enforced from another is a rule that drifts.
##
## Measured between the two footprints rather than between two cells: the gap of
## bare ground between the hut and the base has to be at least SHELTER_CLEARANCE
## tiles, less the tile a building always was.
func shelter_too_close(cell: Vector2i) -> bool:
	var gap: int = Grid.SCALE * int(Defs.SHELTER_CLEARANCE - 1.0)
	return Grid.footprint(cell, Defs.SHELTER_SIZE).intersects(base_rect().grow(gap))

## Whether a hut with its anchor here would stand in warm ground -- judged at
## the middle of its footprint, which is where the door and the fire inside are.
func shelter_warm(cell: Vector2i) -> bool:
	return tiles_from_core_at(Grid.rect_centre(Grid.footprint(cell, Defs.SHELTER_SIZE))) \
		<= warm_radius

## Every cell of a hut with its anchor here that refuses it, and why. The one
## rule the placement, the refusal line and the red cells under the carried hut
## all read.
func shelter_problems(cell: Vector2i, body: Array[Vector2i] = []) -> Dictionary:
	var rect: Rect2i = Grid.footprint(cell, Defs.SHELTER_SIZE)
	var out: Dictionary = rect_problems(rect, NONE, body)
	var gap: int = Grid.SCALE * int(Defs.SHELTER_CLEARANCE - 1.0)
	var band: Rect2i = base_rect().grow(gap)
	var warm: bool = shelter_warm(cell)
	for covered: Vector2i in Grid.cells_in(rect):
		if out.has(covered):
			continue
		if band.has_point(covered):
			out[covered] = "불에 너무 가깝습니다"
		elif not warm:
			out[covered] = "불이 닿지 않습니다"
	return out

func place_shelter(cell: Vector2i) -> bool:
	if shelter_placed or carried_kit != Defs.KIT_SHELTER:
		return false
	if not base_placed:
		return false
	if shelter_too_close(cell) or not shelter_warm(cell):
		return false
	if not shelter_problems(cell).is_empty():
		return false
	shelter_cell = cell
	food_cell = cell + Defs.FOOD_CELL
	shelter_placed = true
	carried_kit = Defs.KIT_NONE
	_grid_dirty = true
	return true

## Searching the kit. Returns what came out, or KIT_NONE if there was nothing
## left in it or her arms were already full.
## --- What comes out of the case ---------------------------------------------
## Searching it puts its contents on the snow rather than into her hands.
##
## It used to hand the kit straight over, which meant the first thing the game
## ever gave the player arrived as a word in the corner of the screen. Two
## objects lying in the snow are two things to walk over and pick up, and picking
## a thing up is how you find out what it is.
const DROP_KIT_BASE := 0
const DROP_KIT_SHELTER := 1
const DROP_GUN := 2
const DROP_PICKAXE := 3
const DROP_FOOD_BIN := 4
const DROP_NAMES := ["긴급기지키트", "긴급숙소키트", "건물건설총", "곡괭이", "사료 상자"]

## What each search turns out. The gun before the pickaxe on purpose: the fire is
## the first thing that has to exist, and a pickaxe with nowhere to put what it
## digs is a tool with no verb.
## The first search gives her the fire and nothing else. It used to hand over the
## build gun at the same time, which put a tool she cannot use for another ten
## minutes -- there is nothing to build and nothing to build it with -- next to
## the one object the opening is actually about. Two things on the snow means
## choosing which to walk to, and one of the two was a distraction.
## What the case used to hold, kept as history: the base kit (now the case
## unfolds into the base itself) and the shelter kit and pickaxe (now made at the
## fire). The DROP_* constants stay -- the shelter kit still lands on the snow,
## out of the fire's craft list rather than out of the case.

var drops: Dictionary = {}
## Picked up rather than granted. The slots used to open on `kit_searched`, so
## the tools existed the moment the lid was lifted whether or not she had touched
## them.
var has_gun := false
var has_pickaxe := false
## Whether the fire has already handed the gun over, so a second upgrade does
## not put a second one on the snow.
var gun_dropped := false
## The cell she is standing in, pushed here by Main every frame. Nothing this
## file tips onto the snow lands on it.
##
## "Beside the case, nearest the fire" is right until she is standing between the
## two, which is most of the time -- she walks out from the crash site, so the
## cell on the fire's side of the case is the cell she is in. It landed under her
## and was picked up on the frame it appeared, which is the exact thing dropping
## it away from her was chosen to avoid. The same is true of the gun the fire
## hands over and of the bin she has just made.
var drop_from := Vector2i(9999, 9999)
## Lifetime totals per material, gains only. Saved, because the morning report
## subtracts yesterday's reading from today's.
var collected: Dictionary = {}

## Every material that has ever passed through her hands this run.
##
## Separate from `collected`, which is a ledger of amounts, and from `stock`,
## which goes back down the moment she builds: an unlock condition asks a
## question about the run, not about the pack. Derived from `collected` when a
## save is loaded, so it needs no schema of its own.
var held_items: Dictionary[int, bool] = {}

## Machines whose condition came true and have not been said out loud yet.
var pending_unlocks: Array[int] = []
## Whether the grid has ever supplied anything. The belt's unlock token reads
## this; saved, because "power has flowed here" is a fact about the run.
var power_ever := false

## The last recipe the player chose, per machine type. A second manufacturer
## starts on what the first one was set to, because a player who just decided
## this base makes wire did not decide it once -- and a machine that always
## starts on plates reads as a plate press with a menu bolted on.
##
## Saved: it is a decision, and decisions survive closing the game.
var last_recipe: Dictionary = {}

## Whether the case will open again.
##
## The second search waits for the fire. Both are available from the first frame
## otherwise, and a player who searched twice before lighting anything was
## standing in the snow holding a shelter and a pickaxe with nowhere to put
## either -- the opening is one sentence at a time, and the fire is the first.
##
## One predicate, because three places ask: the search itself, the reach test
## that decides whether Z means the case at all, and the prompt that offers it.
func can_search_kit() -> bool:
	return kit_searched == 0 and not base_placed

## Finishing the search unfolds the emergency base out of the case, on the spot.
##
## Nothing drops and nothing is carried: the golden path's first beat is the case
## becoming the fire, not an errand between the two. The case's cell is where the
## core stands, so the centre of the world moves those two tiles with it -- the
## same move a player used to make by hand, inside the same tolerance.
## Returns what came out, which is now always nothing; the callers that care ask
## `base_placed` instead.
func search_kit() -> Array[int]:
	var out: Array[int] = []
	if not can_search_kit():
		return out
	kit_searched = 1
	deploy_base()
	return out

## The emergency base, unfolded out of the case, on the case's own cell.
##
## The box does not stay standing beside the fire: it *is* the fire. One object
## on the snow becomes one object on the snow, and the player who walked to it
## and held Z watches the thing they walked to open up rather than watching a
## second building appear somewhere behind them.
##
## That cell is the world anchor (`begin_crash` put the case there), so the ring
## promises hold without anything moving.
## `place_base` remains the hand-placed door for tests and debug worlds.
func deploy_base() -> void:
	if base_placed:
		return
	core_cell = kit_cell
	# Everything under the footprint gives way. The world keeps the ground here
	# clear, but the base is eight cells across and the case was two: nothing the
	# player can have put down near the case may end up inside the fire.
	_clear_under(base_rect())
	shelter_cell = core_cell + Defs.SHELTER_CELL
	food_cell = shelter_cell + Defs.FOOD_CELL
	var core := Machine.new()
	core.type = Defs.M_CORE
	core.cell = core_cell
	core.flash = 0.6
	add_machine(core)
	base_placed = true
	carried_kit = Defs.KIT_NONE
	_grid_dirty = true
	_refresh_radius()
	mark_explored(core_cell, Defs.BASE_REVEAL_RADIUS)
	# And the case is gone. Nothing draws it and nothing blocks on it: it did
	# not sit down beside the base, it turned into it.
	kit_cell = Vector2i(9999, 9999)

## A point near `at` where a body `radius` across stands clear of everything
## solid -- the nearest cell centre that works, searched outward. Used when a
## building appears around someone: the case unfolding into a base four tiles
## across, with her standing beside it.
func clear_point(at: Vector2, radius: float) -> Vector2:
	if _body_clear(at, radius):
		return at
	var here: Vector2i = Grid.cell_at(at)
	for ring in range(1, 32):
		var best := Vector2(1e20, 1e20)
		var best_distance: float = 1e20
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var point: Vector2 = Grid.centre(here + Vector2i(dx, dy))
				if not _body_clear(point, radius):
					continue
				var distance: float = point.distance_squared_to(at)
				if distance < best_distance:
					best_distance = distance
					best = point
		if best.x < 1e19:
			return best
	return at

## Where a cat fanned out across a doorstep actually stands: there, if that is
## ground, or the nearest cell that is. Eight cats thirty pixels apart are two
## hundred pixels of doorstep, wider than the hut, and the ends of the fan used
## to land in whatever was built beside it.
func _clear_spot(at: Vector2) -> Vector2:
	if not blocks_player(cell_of(at)):
		return at
	return clear_point(at, 1.0)

func _body_clear(at: Vector2, radius: float) -> bool:
	var low: Vector2i = Grid.cell_at(at - Vector2(radius, radius))
	var high: Vector2i = Grid.cell_at(at + Vector2(radius, radius))
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			if blocks_player(Vector2i(x, y)):
				return false
	return true

## Everything lying where the base is about to stand. The case was a tile and
## the base is four tiles across, so the ground it opens onto is not the ground
## the case was on -- a stone dropped beside the case, or a block of ice set down
## next to it, would end up inside the fire.
func _clear_under(rect: Rect2i) -> void:
	for cell: Vector2i in Grid.cells_in(rect):
		erase_ore_at(cell)
		ground.erase(cell)
		ground_stack.erase(cell)
		drops.erase(cell)
		shards.erase(cell)
		var machine: Machine = machine_at(cell)
		if machine != null and machine.type != Defs.M_CORE:
			remove_machine(cell)
	for props: Dictionary in [frozen_cats, debris]:
		for origin: Vector2i in props.keys():
			if prop_rect(origin).intersects(rect):
				props.erase(origin)

## Below the case, and then outward. Below because that is where the player is
## looking -- she has to stand south of it to face it -- and outward because a
## seam or a rock under the case is not a reason for the game to swallow the one
## thing the opening is about.
## Cells cannot go into a ConfigFile as keys, so both maps travel as rows.
func _collected_rows() -> Array:
	var rows: Array = []
	for item_type: int in collected:
		rows.append([item_type, int(collected[item_type])])
	return rows

func _debris_rows() -> Array:
	var rows: Array = []
	for cell: Vector2i in debris:
		rows.append([cell.x, cell.y, int(debris[cell])])
	return rows

func _thawed_rows() -> Array:
	var rows: Array = []
	for cell: Vector2i in thawed:
		rows.append([cell.x, cell.y])
	return rows

func _drop_rows() -> Array:
	var rows: Array = []
	for cell: Vector2i in drops:
		rows.append([cell.x, cell.y, int(drops[cell])])
	return rows

## The build gun, handed over by the fire once it has grown a step.
##
## It used to fall out of the case at the start, ten minutes before there was
## anything to build or anything to build it with. Tying it to the first upgrade
## puts it where the player has just learned what the fire is for -- and it
## arrives as a thing on the snow to walk over, like everything else in the
## opening, rather than as a slot that quietly appears in the hotbar.
func drop_gun_at_base() -> bool:
	if has_gun or gun_dropped or not base_placed:
		return false
	var cell: Vector2i = _free_near(core_cell)
	if cell == Vector2i(9999, 9999):
		return false
	drops[cell] = DROP_GUN
	gun_dropped = true
	return true

## A cell beside a given one with nothing on it, searched outward.
func _free_near(origin: Vector2i) -> Vector2i:
	# Wide enough to get out from under the base, which is eight cells across and
	# centred on the core's anchor.
	for ring in range(1, 6 + Defs.machine_size(Defs.M_CORE).x):
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var cell: Vector2i = origin + Vector2i(dx, dy)
				if cell == drop_from:
					continue
				if drops.has(cell) or is_structure(cell) or has_ore(cell) or has_rock(cell):
					continue
				return cell
	return Vector2i(9999, 9999)

## The nearest anchor to `origin` whose footprint of `size` a rule says nothing
## against -- `problems` is a function of the anchor answering cell -> reason,
## `rect_problems` over the footprint when none is given. Searched outward.
func free_anchor_near(origin: Vector2i, size: Vector2i, problems: Callable = Callable()) -> Vector2i:
	for ring in range(0, 24):
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var anchor: Vector2i = origin + Vector2i(dx, dy)
				var found: Dictionary = problems.call(anchor) if problems.is_valid() \
					else rect_problems(Grid.footprint(anchor, size))
				if found.is_empty():
					return anchor
	return NONE

## Walking over one. Returns what was taken, or -1.
func collect_drop(cell: Vector2i) -> int:
	if not drops.has(cell) or not can_touch(cell):
		return -1
	var kind: int = int(drops[cell])
	match kind:
		DROP_KIT_BASE, DROP_KIT_SHELTER, DROP_FOOD_BIN:
			# Both hands, so a kit cannot be scooped up while carrying a cat.
			if hands_full():
				return -1
			match kind:
				DROP_KIT_BASE: carried_kit = Defs.KIT_BASE
				DROP_KIT_SHELTER: carried_kit = Defs.KIT_SHELTER
				_: carried_kit = Defs.KIT_FOOD
		DROP_GUN:
			has_gun = true
		DROP_PICKAXE:
			has_pickaxe = true
	drops.erase(cell)
	return kind

## --- Frozen cats ----------------------------------------------------------
## Picked up by hand, not by walking over. The crates were collected by walking
## because they were an errand; this is a body Grim decides to carry, and the
## decision has to be a press.
func pick_up_frozen(cell: Vector2i) -> bool:
	if hands_full() or not can_lift(cell):
		return false
	var key: Vector2i = frozen_key(cell)
	if key == NONE:
		return false
	carried_frozen_thaw = frozen_cats[key]
	frozen_cats.erase(key)
	frozen_offset.erase(key)
	carried_frozen = true
	return true

## Putting one down. Anywhere is allowed -- she can set it on the snow and come
## back for it -- but only near the core does the ice start to go.
##
## `cell` is the block's origin: it covers a tile from there, and every cell of
## it has to be free.
func put_down_frozen(cell: Vector2i) -> bool:
	if not carried_frozen:
		return false
	for covered: Vector2i in Grid.cells_in(prop_rect(cell)):
		if frozen_key(covered) != NONE or is_structure(covered) or not in_world(covered):
			return false
	frozen_cats[cell] = carried_frozen_thaw
	carried_frozen = false
	carried_frozen_thaw = 0.0
	return true

## Near the fire, and nowhere else. Measured from the core rather than from the
## warm radius on purpose: the radius grows to twenty-two tiles, and a cat that
## thawed anywhere inside it would remove the walk home entirely by the third
## upgrade.
##
## Measured to the base's walls since Grid v2. THAW_RADIUS was two tiles from the
## middle of a fire one tile across -- a tile and a half past its edge -- and
## the base is four tiles across now: two tiles from its middle is inside it.
## So "near the fire" is the same tile and a half, from where the fire's walls
## actually are.
func can_thaw(cell: Vector2i) -> bool:
	var key: Vector2i = frozen_key(cell)
	var at: Vector2 = prop_centre(key) if key != NONE else Grid.centre(cell)
	return tiles_from_base_at(at) <= Defs.THAW_RADIUS - 0.5

## How far a point is from the base's walls, in tiles. Zero inside it.
func tiles_from_base_at(point: Vector2) -> float:
	var span: Rect2 = Grid.rect_px(base_rect())
	var nearest := Vector2(clampf(point.x, span.position.x, span.end.x),
		clampf(point.y, span.position.y, span.end.y))
	return Grid.tiles(point.distance_to(nearest))

## Which of the four pictures a given progress shows. The last stage is held
## until the ice is gone rather than reached at three quarters, so the final
## picture is the one the cat wakes out of.
static func frozen_stage(progress: float) -> int:
	return clampi(int(progress * float(Defs.FROZEN_STAGES)), 0, Defs.FROZEN_STAGES - 1)

## The ice going, for every frozen cat standing near the core. A cat left out on
## the snow does not thaw and does not re-freeze either: its progress simply
## stops, so carrying a half-melted one the rest of the way home works.
func _tick_thaw(delta: float) -> void:
	var woken: Array[Vector2i] = []
	for cell: Vector2i in frozen_cats:
		if not can_thaw(cell):
			continue
		var progress: float = frozen_cats[cell] + delta / Defs.THAW_SECONDS
		if progress >= 1.0:
			woken.append(cell)
		else:
			frozen_cats[cell] = progress
	for cell: Vector2i in woken:
		frozen_cats.erase(cell)
		_wake_cat(cell)

## A cat wakes where it thawed, not on the shelter doorstep. It is standing in
## the place the player chose to put it, which is the whole point of having
## carried it there.
func _wake_cat(cell: Vector2i) -> void:
	var cat := Cat.new()
	cat.phase = _next_phase()
	cat.rarity = Defs.RARITY_O
	cat.pos = prop_centre(cell)
	cats.append(cat)
	cat_thawed.emit(cats.size(), cat.pos)
	cat_adopted.emit(cats.size())

## --- The torch --------------------------------------------------------------
## Made at the fire, out of the fuel the fire runs on.
func can_craft_torch() -> bool:
	for item_type: int in Defs.TORCH_COST:
		if int(stock.get(item_type, 0)) < int(Defs.TORCH_COST[item_type]):
			return false
	return true

## The bin, made and tipped out beside the fire.
##
## It used to appear beside the hut the instant it was paid for, on the grounds
## that there was one sensible spot for it and choosing between identical tiles
## is a decision with no content. That was true of the tile and false of the
## thing: everything else in this game is an object that lands on the snow and is
## carried to where it goes -- the case, the fire, the hut, the gun -- and a
## building that materialises out of a menu is the only one that is a number
## changing. Cats walk to this thing all day, so where it stands is a real
## decision by the tenth minute anyway.
func craft_food_bin() -> bool:
	if not base_placed or food_placed or bin_in_hand() or not can_craft("food_bin"):
		return false
	var cell: Vector2i = _free_near(core_cell)
	if cell == Vector2i(9999, 9999):
		return false
	_spend("food_bin")
	drops[cell] = DROP_FOOD_BIN
	return true

## Whether one is already made and not yet standing: in her arms or lying on the
## snow. Without this the window sells a second one to a player who has not put
## the first down, and the material goes with no second bin to show for it.
func bin_in_hand() -> bool:
	if carried_kit == Defs.KIT_FOOD:
		return true
	for cell: Vector2i in drops:
		if int(drops[cell]) == DROP_FOOD_BIN:
			return true
	return false

## And putting it down. Anywhere she can reach and nothing is standing: the cats
## path to it, so a bin on the far side of the fog is a bin they walk to through
## the cold.
func place_food_bin(cell: Vector2i) -> bool:
	if carried_kit != Defs.KIT_FOOD or food_placed:
		return false
	if not food_problems(cell).is_empty():
		return false
	food_cell = cell
	food_placed = true
	carried_kit = Defs.KIT_NONE
	_grid_dirty = true
	return true

## The bin's footprint with its anchor here, cell by cell: somewhere she can
## reach, with nothing standing on it.
func food_problems(cell: Vector2i, body: Array[Vector2i] = []) -> Dictionary:
	var rect: Rect2i = Grid.footprint(cell, Defs.FOOD_BIN_SIZE)
	var out: Dictionary = rect_problems(rect, NONE, body)
	for covered: Vector2i in Grid.cells_in(rect):
		if not out.has(covered) and not can_touch(covered):
			out[covered] = "불이 닿지 않습니다"
	return out

## Whether a recipe can be paid for, by id.
func can_craft(id: String) -> bool:
	for row: Dictionary in Defs.BASE_CRAFTS:
		if String(row["id"]) != id:
			continue
		for item_type: int in row["cost"]:
			if int(stock.get(item_type, 0)) < int(row["cost"][item_type]):
				return false
		return true
	return false

func _spend(id: String) -> void:
	for row: Dictionary in Defs.BASE_CRAFTS:
		if String(row["id"]) != id:
			continue
		for item_type: int in row["cost"]:
			stock[item_type] = int(stock.get(item_type, 0)) - int(row["cost"][item_type])
		return

## The shelter kit, made at the fire and tipped out beside it. Free, and the
## first thing the player ever places by hand -- the craft makes the object, the
## object lands on the snow, and carrying it to a spot is the placement lesson.
func craft_shelter_kit() -> bool:
	if not base_placed or shelter_placed or carried_kit == Defs.KIT_SHELTER:
		return false
	for cell: Vector2i in drops:
		if int(drops[cell]) == DROP_KIT_SHELTER:
			return false
	var cell: Vector2i = _free_near(core_cell)
	if cell == Vector2i(9999, 9999):
		return false
	drops[cell] = DROP_KIT_SHELTER
	return true

## The pickaxe, absorbed rather than dropped. A tool with one owner and no
## placement decision has nothing to teach by lying on the snow -- what matters
## is that it appears *in her hand*, in slot 1, the moment it is done.
func craft_pickaxe() -> bool:
	if not base_placed or has_pickaxe:
		return false
	has_pickaxe = true
	return true

## The build gun, absorbed like the pickaxe. Free; what pays for it is the
## copper that opened the row.
func craft_build_gun() -> bool:
	if not base_placed or has_gun:
		return false
	has_gun = true
	return true

func craft_torch() -> bool:
	if not base_placed or not can_craft_torch():
		return false
	for item_type: int in Defs.TORCH_COST:
		stock[item_type] = int(stock.get(item_type, 0)) - int(Defs.TORCH_COST[item_type])
	torches += 1
	return true

## Taking one out. Only spends a torch if nothing is still burning -- putting one
## away and taking it out again must not cost anything.
func light_torch() -> bool:
	if torch_left > 0.0:
		return true
	if torches <= 0:
		return false
	torches -= 1
	torch_left = Defs.TORCH_SECONDS
	return true

## Burning, which only happens while it is in her hand.
func burn_torch(delta: float) -> void:
	torch_left = maxf(0.0, torch_left - delta)

## Everything in the base's store that will burn, into the fire.
##
## Materials stay where they are. `stock` *is* the base's ledger -- it is what
## machines are bought out of -- so crystal and copper are already in the base
## the moment they are picked up, and taking them away to "deliver" them would
## be spending them on nothing. What has to be handed over is fuel, which is the
## only thing the core does anything with.
##
## Returns what went in, keyed by item, so the effect can draw it.
func deposit_fuel() -> Dictionary:
	var moved: Dictionary = {}
	if not base_placed:
		return moved
	# Stones, and only stones. The energy crystal used to count as fuel too, which
	# made "how many more do I need" a question with two answers and no way to
	# ask it.
	#
	# One step's worth, and the rest stays in the pack.
	#
	# It used to take everything she was carrying, on the grounds that tipping a
	# pack into a fire leaves no change. What that meant in play was that five
	# hundred stones bought four rungs of the ladder in a single keypress: the
	# circle jumped from seven cells to thirty and the player never saw the
	# decision that was being made for them. The ladder is the game's pacing, and
	# a press that climbs an unpredictable number of rungs is not a decision.
	#
	# At the top of the ladder there is no next step, and there the fire does
	# take whatever it is given -- the stones have nowhere else to go.
	var want: int = stones_to_next()
	var count: int = int(stock.get(Defs.ITEM_HEATSTONE, 0))
	if want > 0:
		count = mini(count, want)
	if count <= 0:
		return moved
	moved[Defs.ITEM_HEATSTONE] = count
	stock[Defs.ITEM_HEATSTONE] = int(stock.get(Defs.ITEM_HEATSTONE, 0)) - count
	delivered[Defs.ITEM_HEATSTONE] = int(delivered.get(Defs.ITEM_HEATSTONE, 0)) + count
	stones_in += count
	var core: Machine = machines.get(core_cell, null)
	if core != null:
		core.flash = 0.6
	_refresh_radius()
	fuel_added.emit(count, core_cell, Defs.ITEM_HEATSTONE)
	return moved

## What the next step of the circle still wants, in stones. Zero at the top of
## the ladder, which is the one case where the fire takes whatever it is given.
func stones_to_next() -> int:
	var next_level: Dictionary = Defs.next_base_level(stones_in)
	if next_level.is_empty():
		return 0
	return maxi(0, int(next_level["stones"]) - stones_in)

## Whether the fire can be fed to the next step right now. False while she is
## short, because a fire that swallows two of the three stones it needs has taken
## the material and given nothing -- and the player cannot see where it went.
func can_feed_base() -> bool:
	if not base_placed:
		return false
	var want: int = stones_to_next()
	var have: int = int(stock.get(Defs.ITEM_HEATSTONE, 0))
	return have > 0 and (want <= 0 or have >= want)

## Whether there is anything to hand over. Asked before the verb so the game can
## say "there is nothing to put in" rather than doing nothing.
func has_fuel() -> bool:
	return int(stock.get(Defs.ITEM_HEATSTONE, 0)) > 0

## Cats without a thaw, for the debug unlocks and for tests that need a crew
## rather than a rescue. Everything the crates used to do through adopt_cats is
## this, minus the crates.
func grant_cats(count: int) -> int:
	if count <= 0:
		return 0
	var grades: Array[int] = []
	for _index in count:
		grades.append(Defs.RARITY_O)
	_spawn_cats(grades)
	cat_adopted.emit(cats.size())
	return count

## Puts new cats on the shelter doorstep, spread across it rather than stacked on
## one tile, the same way they come out in the morning. Three cats on the same
## pixel look like one cat, right up until they walk off in different directions.
##
## Successive cats, spread as far apart as a sequence can be spread. Derived from
## the crew size rather than stored in the save: cats are rebuilt in the order
## they were written, so the same cat gets the same number back.
func _next_phase() -> float:
	return fmod(float(cats.size()) * 0.61803398875, 1.0)

## Shared by the two ways a cat arrives -- crates and the slot machine -- because
## the second one can deliver ten at once, and ten cats on one pixel is not a
## reward, it is a rendering bug the player will report.
func _spawn_cats(grades: Array[int]) -> void:
	var doorstep: Vector2 = shelter_doorstep()
	for index in grades.size():
		var cat := Cat.new()
		cat.phase = _next_phase()
		cat.rarity = grades[index]
		cat.pos = _clear_spot(doorstep + Vector2((float(index) - float(grades.size() - 1) * 0.5)
			* Defs.CAT_LANE, 0.0))
		cats.append(cat)

## --- The slot machine ---------------------------------------------------------
## Split in two on purpose. The reels spin for three seconds, and the coins have
## to leave the purse at the moment the player presses the button rather than
## when the animation happens to end -- otherwise closing the window mid-spin, or
## a lag spike, is a free pull. So `begin_gacha` charges and `pull_gacha` decides;
## the orchestrator calls the second one when the reels stop.
func begin_gacha(count: int) -> bool:
	if count <= 0 or coins < count:
		return false
	coins -= count
	return true

## Rolls `count` grades, puts that many cats on the doorstep and returns what
## came out. Takes no payment: begin_gacha already did.
func pull_gacha(count: int) -> Array[int]:
	var grades: Array[int] = []
	for _index in maxi(count, 0):
		grades.append(Defs.roll_rarity(gacha_rng.randf() * 100.0))
	if grades.is_empty():
		return grades
	_spawn_cats(grades)
	cat_adopted.emit(cats.size())
	return grades

## Picking a cat up takes it off its machine; the machine stops immediately.
func pick_up_cat(cell: Vector2i) -> bool:
	if hands_full() or not can_lift(cell):
		return false
	var best: Cat = cat_on(cell)
	if best == null:
		return false
	if best.has_job() and machines.has(best.assigned):
		machines[best.assigned].operated = false
	best.assigned = Vector2i(9999, 9999)
	best.state = Defs.CAT_IDLE
	carried_cat = best
	return true

## Where a carried cat rides. Its real position is moved to just in front of the
## player rather than the renderer drawing it at an offset, so "being carried" is
## a fact about the world -- one place to read it from, and dropping the cat
## leaves it exactly where it looked like it was.
func carry_at(origin: Vector2, heading: Vector2) -> void:
	if carried_cat == null:
		return
	var direction: Vector2 = heading if not heading.is_zero_approx() else Vector2.DOWN
	carried_cat.pos = origin + direction.normalized() * Grid.px(Defs.CARRY_AHEAD)
	carried_cat.heading = direction

## Putting a cat down on a post -- a miner, or a bare seam -- assigns it there
## for good; it will return every morning, after every meal, and after every
## delivery.
func place_cat(cell: Vector2i) -> bool:
	if carried_cat == null:
		return false
	# Any cell of a post's footprint means that post: she is facing the machine,
	# not a particular one of its cells.
	cell = post_anchor(cell)
	if not _is_post(cell):
		return false
	for cat: Cat in cats:
		if cat != carried_cat and cat.assigned == cell:
			return false
	carried_cat.assigned = cell
	carried_cat.pos = post_stand(cell)
	carried_cat.state = Defs.CAT_WORKING
	carried_cat = null
	return true

## Dropping a cat anywhere else simply leaves it standing there.
func drop_cat(at: Vector2) -> bool:
	if carried_cat == null:
		return false
	carried_cat.pos = at
	carried_cat.state = Defs.CAT_IDLE
	carried_cat = null
	return true

func idle_miner_cells() -> Array[Vector2i]:
	var free: Array[Vector2i] = []
	for cell: Vector2i in machines:
		if not Defs.machine_mines(machines[cell].type):
			continue
		var taken := false
		for cat: Cat in cats:
			if cat.assigned == cell:
				taken = true
				break
		if not taken:
			free.append(cell)
	return free

## Each morning every cat walks back to the machine the player assigned it to.
## Cats without an assignment simply wait at the shelter to be carried somewhere:
## the game never picks a job for them.
func dispatch_cats() -> void:
	var doorstep: Vector2 = shelter_doorstep() - Vector2(0, Grid.px(0.15))
	var index := 0
	for cat: Cat in cats:
		if cat == carried_cat:
			continue
		# Everyone comes out of the shelter at first light, spread across the
		# doorstep rather than stacked on one tile.
		var lane: float = (float(index) - float(cats.size() - 1) * 0.5) * Defs.CAT_LANE
		cat.pos = _clear_spot(doorstep + Vector2(lane, 0.0))
		index += 1
		# `_is_post`, not "is there a machine there". A cat can be put down on
		# bare ore and will dig it by hand, which is the whole early game before
		# the first miner exists -- and this asked for a machine, so every one of
		# those cats lost its job overnight and stood at the door in the morning
		# waiting to be carried back to the seam it was already working.
		#
		# The predicate is the one `place_cat` and the walk use. Three places
		# deciding separately what counts as a job is how two of them come to
		# disagree.
		if cat.has_job() and _is_post(cat.assigned):
			cat.state = Defs.CAT_TO_MINER
			continue
		cat.assigned = Vector2i(9999, 9999)
		cat.state = Defs.CAT_IDLE

## The machine covering a cell, or null -- any cell of its footprint, not only
## the anchor it is stored under.
##
## Answered from `_occupancy`, which is derived from `machines` and rebuilt when
## the two disagree. Sim's own build and demolish keep it current; the checks
## here are for everything that writes `machines` directly (tests do, and the
## debug worlds), which would otherwise leave a footprint answering for a
## machine that is gone.
func machine_at(cell: Vector2i) -> Machine:
	if machines.size() != _occupied_count:
		_rebuild_occupancy()
	var anchor: Vector2i = _occupancy.get(cell, NONE)
	if anchor != NONE:
		var found: Machine = machines.get(anchor, null)
		if found != null and found.cell == anchor:
			return found
		_rebuild_occupancy()
		anchor = _occupancy.get(cell, NONE)
		return machines.get(anchor, null) if anchor != NONE else null
	return machines.get(cell, null)

## Every footprint cell -> the anchor of the machine on it.
var _occupancy: Dictionary[Vector2i, Vector2i] = {}
## How many machines `_occupancy` was built from. A different count is a
## machine added or removed behind Sim's back.
var _occupied_count: int = -1

func _rebuild_occupancy() -> void:
	_occupancy.clear()
	for anchor: Vector2i in machines:
		for cell: Vector2i in Grid.cells_in(machine_rect(machines[anchor])):
			_occupancy[cell] = anchor
	_occupied_count = machines.size()

## Puts a machine on the grid: into `machines` under its anchor, and every cell
## of its footprint into the occupancy map.
func add_machine(machine: Machine) -> void:
	if machines.size() != _occupied_count:
		_rebuild_occupancy()
	# A rig added without a target (built, loaded from a save written before
	# rigs carried one, migrated) takes the node it stands on.
	if Defs.machine_mines(machine.type) and machine.ore_node == NONE:
		machine.ore_node = ore_origin_at(machine.cell)
	machines[machine.cell] = machine
	for cell: Vector2i in Grid.cells_in(machine_rect(machine)):
		_occupancy[cell] = machine.cell
	_occupied_count = machines.size()
	_grid_dirty = true

## And takes one off, by any cell it covers. Returns what was removed.
func remove_machine(cell: Vector2i) -> Machine:
	var machine: Machine = machine_at(cell)
	if machine == null:
		return null
	machines.erase(machine.cell)
	for covered: Vector2i in Grid.cells_in(machine_rect(machine)):
		if _occupancy.get(covered, NONE) == machine.cell:
			_occupancy.erase(covered)
	_occupied_count = machines.size()
	_grid_dirty = true
	return machine

## The cells a standing machine covers.
func machine_rect(machine: Machine) -> Rect2i:
	return Defs.machine_footprint(machine.type, machine.cell, machine.dir)

## The middle of a machine's footprint, in world pixels -- where its picture is
## centred and where anything that happens to it is drawn.
func machine_centre(machine: Machine) -> Vector2:
	return Grid.rect_centre(machine_rect(machine))

## The middle of whatever machine covers this cell, or of the cell itself.
func machine_centre_at(cell: Vector2i) -> Vector2:
	var machine: Machine = machine_at(cell)
	return machine_centre(machine) if machine != null else Grid.centre(cell)

## Where a machine's output goes: the cell past its front edge, in line with its
## anchor. For a belt that is simply the next cell.
func output_cell(machine: Machine) -> Vector2i:
	return Grid.front_cell(machine_rect(machine), machine.dir, machine.cell)

# --- Buildings that are not machines -------------------------------------------
## The base is the core machine, and its footprint is the machine's. The hut and
## the food bin are placed by hand rather than built, so they are not machines --
## but they are buildings on the grid all the same, with footprints the same
## rules read.

func base_rect() -> Rect2i:
	return Defs.machine_footprint(Defs.M_CORE, core_cell)

## Whether a cell is part of the standing base.
func is_base(cell: Vector2i) -> bool:
	if not base_placed:
		return false
	var machine: Machine = machine_at(cell)
	return machine != null and machine.type == Defs.M_CORE

func shelter_rect() -> Rect2i:
	return Grid.footprint(shelter_cell, Defs.SHELTER_SIZE)

func in_shelter(cell: Vector2i) -> bool:
	return shelter_placed and shelter_rect().has_point(cell)

func food_rect() -> Rect2i:
	return Grid.footprint(food_cell, Defs.FOOD_BIN_SIZE)

func in_food_bin(cell: Vector2i) -> bool:
	return food_placed and food_rect().has_point(cell)

# --- Things a tile across -------------------------------------------------------
## Ice, wreckage, the case, the board and the village's pieces all stand on the
## snow a tile across -- the size a cell used to be -- so each covers
## `Defs.PROP_SIZE` cells and is stored under the top-left one. These answer "which
## one is on this cell" for any of the cells it covers.

func prop_rect(origin: Vector2i) -> Rect2i:
	return Rect2i(origin, Defs.PROP_SIZE)

func prop_centre(origin: Vector2i) -> Vector2:
	return Grid.rect_centre(prop_rect(origin))

## The origin of whatever in `props` covers `cell`, or NONE.
static func prop_key(props: Dictionary, cell: Vector2i) -> Vector2i:
	for dy in Defs.PROP_SIZE.y:
		for dx in Defs.PROP_SIZE.x:
			var origin: Vector2i = cell - Vector2i(dx, dy)
			if props.has(origin):
				return origin
	return NONE

func frozen_key(cell: Vector2i) -> Vector2i:
	return prop_key(frozen_cats, cell)

func debris_key(cell: Vector2i) -> Vector2i:
	return prop_key(debris, cell)

func village_key(cell: Vector2i) -> Vector2i:
	return prop_key(village, cell)

func is_kit(cell: Vector2i) -> bool:
	return kit_cell != NONE and prop_rect(kit_cell).has_point(cell)

func is_sign(cell: Vector2i) -> bool:
	return sign_cell != NONE and prop_rect(sign_cell).has_point(cell)

# --- Placement --------------------------------------------------------------------
## How far out anything may be built, in tiles from the fire. Past everything the
## world generates -- the last seams are at a hundred tiles and the scatter reaches
## a hundred and eight -- and well short of the hut's room, which is a place on the
## grid six hundred tiles north that must never be built into.
const WORLD_LIMIT := 200.0

func in_world(cell: Vector2i) -> bool:
	return tiles_from_core(cell) <= WORLD_LIMIT and not Defs.in_room(cell)

## Why one cell cannot take part of a building, or "". `node` is the ore node a
## mining post is being put on (NONE for anything else): its own cells are what
## the post is for, and any other node's are in the way.
func cell_problem(cell: Vector2i, node: Vector2i = NONE) -> String:
	if machine_at(cell) != null:
		return "이미 설비가 있습니다"
	var here: Vector2i = ore_origin_at(cell)
	if here != NONE and here != node:
		return "다른 광맥이 겹칩니다" if node != NONE else "광맥 위에는 설치할 수 없습니다"
	if not in_world(cell):
		return "여기에는 지을 수 없습니다"
	if is_structure(cell) or has_rock(cell):
		return "막혀 있습니다"
	return ""

## Every cell of a rectangle that cannot take a building, and why: cell -> reason.
##
## The whole footprint, never just the anchor: a building is every cell it
## covers, and the preview paints exactly these red. `node` is the ore node a
## mining post must cover, or NONE; `body` is where someone is standing.
func rect_problems(rect: Rect2i, node: Vector2i = NONE,
		body: Array[Vector2i] = []) -> Dictionary:
	var out: Dictionary = {}
	for cell: Vector2i in Grid.cells_in(rect):
		var why: String = cell_problem(cell, node)
		if why == "" and body.has(cell):
			why = "너무 가깝습니다"
		if why != "":
			out[cell] = why
	return out

## The same, for a machine of `type` with its anchor on `cell`.
##
## A mining post's anchor is the origin of the node it works, and its footprint
## has to take in the whole node -- never half of one, never straddling two.
## Anything else is refused at the anchor, in the words the player needs.
func footprint_problems(type: int, cell: Vector2i, dir: Vector2i = Vector2i.RIGHT,
		body: Array[Vector2i] = []) -> Dictionary:
	var rect: Rect2i = Defs.machine_footprint(type, cell, dir)
	if not Defs.machine_mines(type):
		return rect_problems(rect, NONE, body)
	var node: Vector2i = ore_origin_at(cell)
	var out: Dictionary = rect_problems(rect, node, body)
	if node != cell or not rect.encloses(ore_rect(node)):
		out[cell] = "광맥 위에만 설치할 수 있습니다"
	return out

## Which way a belt under this cell drags whatever is standing on it, in pixels
## per second. Zero everywhere else.
##
## Belts only. A splitter has a direction too, but its whole job is to send what
## lands on it one way and then the other, and a floor that shoves the player
## left, then right, then left is a floor they will walk around.
func belt_drift(cell: Vector2i) -> Vector2:
	var machine: Machine = machine_at(cell)
	if machine == null or machine.type != Defs.M_BELT:
		return Vector2.ZERO
	return Vector2(machine.dir) * Defs.belt_carry_speed()

## What a machine costs, as a material dictionary.
func cost_of(type: int) -> Dictionary:
	return Defs.MACHINE_COSTS[type]

## A machine is only offered once the player has held the resource that defines
## its line, so the hotbar teaches the tech tree by growing.
func is_unlocked(type: int) -> bool:
	return bool(unlocked.get(type, false))

## Called whenever a material reaches the player. Returns the machines this
## unlocked, so the caller can announce them.
func note_resource_seen(item_type: int) -> Array[int]:
	held_items[item_type] = true
	_check_unlocks()
	return take_unlocks()

## Whether every material this machine waits for has been held at least once.
##
## Asked of the run rather than of the item that just arrived. One material
## could be matched on arrival; two cannot, because the answer has to be the
## same whichever of them lands last.
func unlock_ready(type: int) -> bool:
	for entry in Defs.MACHINE_UNLOCK_ITEMS[type]:
		if entry is String:
			if String(entry) == Defs.UNLOCK_POWER and not power_ever:
				return false
		elif not held_items.has(int(entry)):
			return false
	return true

## Opens whatever is ready and queues it. A machine no material opens is skipped
## rather than treated as satisfied -- an empty list of conditions is trivially
## true, and the miner would open in the first frame.
func _check_unlocks() -> void:
	for type: int in Defs.BUILDABLE:
		if is_unlocked(type) or Defs.machine_previewed(type):
			continue
		if not unlock_ready(type):
			continue
		unlocked[type] = true
		pending_unlocks.append(type)

## Drains the queue for whoever announces it.
func take_unlocks() -> Array[int]:
	var opened: Array[int] = []
	opened.assign(pending_unlocks)
	pending_unlocks.clear()
	return opened

func can_afford(type: int) -> bool:
	for item_type: int in cost_of(type):
		if int(stock.get(item_type, 0)) < int(cost_of(type)[item_type]):
			return false
	return true

## Why a machine cannot go here, or "".
##
## Occupied first, then the questions about the player (is it unlocked, can it be
## paid for), then the ground under the whole footprint -- the order the reasons
## were always given in, so a refusal still names the first thing to fix.
func can_build(type: int, cell: Vector2i, dir: Vector2i = Vector2i.RIGHT,
		body: Array[Vector2i] = []) -> String:
	var rect: Rect2i = Defs.machine_footprint(type, cell, dir)
	for covered: Vector2i in Grid.cells_in(rect):
		if machine_at(covered) != null:
			return "이미 설비가 있습니다"
	if not is_unlocked(type):
		return "아직 해금되지 않았습니다"
	if not can_afford(type):
		var missing: String = _missing_label(type)
		return "%s%s 부족합니다" % [missing, Defs.subject(missing)]
	var problems: Dictionary = footprint_problems(type, cell, dir, body)
	if problems.has(cell):
		return String(problems[cell])
	for covered: Vector2i in Grid.cells_in(rect):
		if problems.has(covered):
			return String(problems[covered])
	return ""

func _missing_label(type: int) -> String:
	for item_type: int in cost_of(type):
		if int(stock.get(item_type, 0)) < int(cost_of(type)[item_type]):
			return String(Defs.ITEM_NAMES[item_type])
	return "자원"

func build(type: int, cell: Vector2i, dir: Vector2i, body: Array[Vector2i] = []) -> bool:
	var reason := can_build(type, cell, dir, body)
	if reason != "":
		build_rejected.emit(reason, cell)
		return false
	var machine := Machine.new()
	machine.type = type
	machine.cell = cell
	machine.dir = dir
	# What the last one was set to. A player who has just decided this base makes
	# wire did not decide it once, and a second machine that starts on plates
	# reads as a plate press with a menu bolted on.
	machine.recipe_key = String(last_recipe.get(type, ""))
	machine.flash = 0.45
	add_machine(machine)
	for item_type: int in cost_of(type):
		stock[item_type] = int(stock.get(item_type, 0)) - int(cost_of(type)[item_type])
	machine_built.emit(cell, type)
	return true

func demolish(cell: Vector2i) -> bool:
	var machine: Machine = machine_at(cell)
	if machine == null or machine.type == Defs.M_CORE:
		return false
	remove_machine(machine.cell)
	# Full refund. In a game with no combat and no fail state, the engine of the
	# fun is the freedom to tear it down and build it better -- and a 25% tax on
	# being wrong is exactly the thing that stops players experimenting.
	for item_type: int in cost_of(machine.type):
		stock[item_type] = int(stock.get(item_type, 0)) + int(cost_of(machine.type)[item_type])
	machine_removed.emit(machine.cell, machine.type)
	return true

func tick(delta: float) -> void:
	_tick_shown_radius(delta)
	_tick_cats(delta)
	_tick_thaw(delta)
	_tick_frozen_drift(delta)
	_recount_power()
	# Under-supplied power slows every drawing machine in proportion rather than
	# switching some off: a brown-out you can see is easier to diagnose than a
	# machine that silently stopped.
	var supply: float = 1.0 if power_draw <= 0.0 else clampf(power_capacity / power_draw, 0.0, 1.0)
	for cell: Vector2i in machines:
		var machine: Machine = machines[cell]
		machine.flash = maxf(0.0, machine.flash - delta)
		_advance_meter(machine, delta)
		var speed: float = 1.0 if is_warm(cell) else 0.45
		if Defs.machine_mines(machine.type):
			var rate: float = _operator_rate(cell, supply)
			speed *= rate
			# The drill spin and the progress ring both read `operated`, and a
			# machine running on the grid is just as much running.
			if rate > 0.0:
				machine.operated = true
		elif Defs.machine_uses_recipes(machine.type) and Defs.machine_power_draw(machine.type) > 0.0:
			# The same brown-out every other machine gets. No grid at all is a
			# stop rather than a slowdown, and nothing is lost either way: the
			# inputs stay in the buffer until a cycle actually finishes.
			speed *= supply if power_capacity > 0.0 else 0.0
		# Every rig, asked rather than listed -- a `match` arm per machine number
		# is what this registry replaced, and the second rig is the first chance
		# to put one back.
		if Defs.machine_mines(machine.type):
			_tick_miner(machine, delta * speed)
			continue
		match machine.type:
			Defs.M_BELT: _tick_belt(machine, delta * speed)
			Defs.M_GENERATOR: _tick_generator(machine, delta)
			Defs.M_SPLITTER: _tick_splitter(machine, delta * speed)
			_:
				# Everything the recipe system drives. There is no branch to add
				# here for a new production machine -- it finds its recipe and
				# runs the shared tick.
				tick_recipe(machine, recipe_of(machine), delta * speed)
	_refresh_radius()
	_tick_rate(delta)

## A slow average rather than an instant reading: material arrives in lumps and
## a number that jumps between 0 and 300 tells the player nothing.
func _tick_rate(delta: float) -> void:
	_rate_clock += delta
	if _rate_clock < 1.0:
		return
	_rate_history.append({"dt": _rate_clock, "items": _gain_accum.duplicate()})
	var span: float = 0.0
	for entry: Dictionary in _rate_history:
		span += float(entry["dt"])
	# Trimmed by time rather than by count, so this holds fifteen seconds however
	# long a frame took to arrive.
	while _rate_history.size() > 1 and span - float(_rate_history[0]["dt"]) >= RATE_WINDOW:
		span -= float(_rate_history[0]["dt"])
		_rate_history.remove_at(0)
	var item_sums: Dictionary[int, float] = {}
	for entry: Dictionary in _rate_history:
		var items: Dictionary = entry["items"]
		for item_type: int in items:
			item_sums[item_type] = float(item_sums.get(item_type, 0.0)) + float(items[item_type])
	# The average over the window is the smoothing. Running a lerp on top would
	# put the lag back without the honesty: this figure is exactly what arrived
	# in the last fifteen seconds, scaled to a minute.
	for item_type: int in Defs.COUNTED_ITEMS:
		gain_rate[item_type] = float(item_sums.get(item_type, 0.0)) * 60.0 / maxf(span, 0.001)
		_gain_accum[item_type] = 0.0
	_rate_clock = 0.0

## Every route by which a material reaches the base stock. Routed through one
## function so the income rate cannot miss one: cats delivering, belts feeding
## the core and the player walking over a dropped item are all production.
func _gain(item_type: int, amount: int) -> void:
	stock[item_type] = int(stock.get(item_type, 0)) + amount
	_gain_accum[item_type] = float(_gain_accum.get(item_type, 0.0)) + float(amount)
	# Everything ever gained, which is what "collected today" is measured
	# against. `stock` cannot answer that -- it goes down when she builds -- and a
	# day where she mined forty and spent forty is not a day where nothing
	# happened.
	collected[item_type] = int(collected.get(item_type, 0)) + amount
	# The one place everything gained flows through, which is why the unlock
	# question is asked here. It used to be asked at each pickup site against
	# whatever had just arrived, and a wreck giving up a core part went through
	# none of them: the condition became true with nobody there to notice.
	held_items[item_type] = true
	_check_unlocks()

# --- Throughput meter --------------------------------------------------------
## What a machine is *actually* moving, as opposed to what it could move.
##
## Design rates are already on screen, and on their own they mislead: a miner
## rated at 6/min reads as a working miner whether or not it has ever produced
## anything. The gap between the rated number and the measured one is the only
## thing that points at a bottleneck, so both are shown side by side.
##
## The window is real seconds, not simulation-adjusted ones. A machine crawling
## at half speed in the cold is producing genuinely fewer items per minute and
## the reading should say so.

## Rolls the sample buckets. Two of them: the older one keeps the reading alive
## while the newer one fills, so the number never drops to zero the instant a
## window boundary passes.
func _advance_meter(machine: Machine, delta: float) -> void:
	machine.meter_span += delta
	if machine.meter_span < Defs.METER_WINDOW:
		return
	machine.meter_in_old = machine.meter_in
	machine.meter_out_old = machine.meter_out
	machine.meter_span_old = machine.meter_span
	machine.meter_in = {}
	machine.meter_out = {}
	machine.meter_span = 0.0

func _note_in(machine: Machine, item_type: int) -> void:
	machine.meter_in[item_type] = int(machine.meter_in.get(item_type, 0)) + 1

func _note_out(machine: Machine, item_type: int) -> void:
	machine.meter_out[item_type] = int(machine.meter_out.get(item_type, 0)) + 1

## Items per minute across the sampled window. Returns 0 until there is enough of
## a window to divide by, because a rate computed over half a second is noise
## dressed up as a measurement.
func meter_rate(machine: Machine, item_type: int, outgoing: bool) -> float:
	var span: float = machine.meter_span + machine.meter_span_old
	if span < 2.0:
		return 0.0
	var recent: Dictionary = machine.meter_out if outgoing else machine.meter_in
	var older: Dictionary = machine.meter_out_old if outgoing else machine.meter_in_old
	var total: float = float(int(recent.get(item_type, 0)) + int(older.get(item_type, 0)))
	return total * 60.0 / span

## How long the reading covers, so the panel can say "still measuring" instead of
## presenting a one-second sample as if it were settled.
func meter_span(machine: Machine) -> float:
	return machine.meter_span + machine.meter_span_old

## The rated throughput, per item type. Separate from the measurement on purpose:
## this is what the machine promises, and it comes from the constants rather than
## from anything that happened.
func design_rates(machine: Machine) -> Dictionary:
	var into: Dictionary = {}
	var out: Dictionary = {}
	# Every rig, ahead of the match, because a `match` arm cannot ask a question
	# -- and listing machine numbers is how the second rig gets forgotten.
	if Defs.machine_mines(machine.type):
		var yielded: int = ore_item(machine.ore_node)
		if yielded >= 0:
			out[yielded] = Defs.per_minute(machine_period(machine))
		return {"in": into, "out": out}
	match machine.type:
		Defs.M_GENERATOR:
			into[Defs.GENERATOR_FUEL] = Defs.per_minute(Defs.GENERATOR_PERIOD)
		Defs.M_BELT:
			# A belt has no recipe, so its rated figure is its capacity: the most
			# it could carry if something fed it that fast.
			var cap: float = Defs.belt_speed(machine.tier) / Defs.BELT_GAP * 60.0
			into[-1] = cap
			out[-1] = cap
		Defs.M_SPLITTER:
			var split: float = Defs.per_minute(Defs.SPLITTER_PERIOD)
			into[-1] = split
			out[-1] = split
		_:
			# Rated straight off the recipe, so the readout over a new machine is
			# right the day it is added.
			var recipe: Dictionary = recipe_of(machine)
			if not recipe.is_empty():
				var each: float = Defs.per_minute(float(recipe["seconds"]))
				for port: Dictionary in recipe["inputs"]:
					into[int(port["item"])] = each * float(port["amount"])
				for port: Dictionary in recipe["outputs"]:
					out[int(port["item"])] = each * float(port["amount"])
	return {"in": into, "out": out}

## Every item type worth listing on one side of the panel: whatever the machine
## is rated for, plus anything it has actually handled. The second half matters
## because a mis-aimed belt feeds machines things they were never rated for, and
## a panel that hid those would hide the mistake.
func meter_items(machine: Machine, outgoing: bool) -> Array[int]:
	var seen: Array[int] = []
	var rated: Dictionary = design_rates(machine)[("out" if outgoing else "in")]
	for item_type: int in rated:
		if item_type >= 0 and not seen.has(item_type):
			seen.append(item_type)
	for source: Dictionary in [
		machine.meter_out if outgoing else machine.meter_in,
		machine.meter_out_old if outgoing else machine.meter_in_old,
	]:
		for item_type: int in source:
			if not seen.has(int(item_type)):
				seen.append(int(item_type))
	seen.sort()
	return seen

## One phrase for why the machine is not at its rated number. Ordered by what the
## player should fix first: no worker beats no input beats no room.
func meter_status(machine: Machine) -> String:
	if Defs.machine_mines(machine.type):
		if not machine.operated:
			return "일손 없음 · 고양이 또는 전력"
		if machine.stalled:
			return "출력 막힘"
		return "가동 중"
	match machine.type:
		Defs.M_GENERATOR:
			if int(machine.buffer.get(Defs.GENERATOR_FUEL, 0)) <= 0:
				return "연료 없음"
			return "가동 중 · 전력 %.1f" % Defs.GENERATOR_OUTPUT
		Defs.M_BELT, Defs.M_SPLITTER:
			if machine.stalled:
				return "가득 참 · 앞이 막힘"
			if machine.items.is_empty():
				return "비어 있음"
			return "운반 중"
		Defs.M_CORE:
			return "반입구"
		_:
			var recipe: Dictionary = recipe_of(machine)
			if recipe.is_empty():
				return ""
			if Defs.machine_power_draw(machine.type) > 0.0 and power_capacity <= 0.0:
				return "전력 없음"
			if not machine.outbox.is_empty():
				return "출력 막힘"
			if not recipe_inputs_ready(machine, recipe):
				return "재료 없음"
			return "가동 중"
	return ""

## What the machine is holding right now, as "구리 2 · 수정 1". A rate alone does
## not explain a machine that stopped a moment ago; its buffer does.
func meter_buffer(machine: Machine) -> String:
	var parts: Array[String] = []
	if machine.type == Defs.M_BELT or machine.type == Defs.M_SPLITTER:
		var capacity: int = Defs.belt_cell_capacity() if machine.type == Defs.M_BELT \
			else Defs.SPLITTER_CAPACITY
		return "적재 %d/%d" % [machine.items.size(), capacity]
	for item_type: int in machine.buffer:
		var held: int = int(machine.buffer[item_type])
		if held > 0:
			parts.append("%s %d" % [Defs.ITEM_SHORT[item_type], held])
	if parts.is_empty():
		return "보관 없음"
	return "보관 " + " · ".join(parts)

## Capacity is whatever the fed generators sustain; draw is what the powered
## machines ask for. Recomputed each tick so building or losing either is felt
## immediately.
## Two passes on purpose. Supply has to be known before demand is measured,
## because whether a miner is drawing at all depends on whether the grid exists
## -- and reading last frame's capacity to answer that gave a one-tick lag, the
## same bug that once made a freshly fuelled generator supply nothing.
func _recount_power() -> void:
	var capacity: float = 0.0
	for cell: Vector2i in machines:
		var machine: Machine = machines[cell]
		# Read the fuel, not a flag set later in the tick.
		if machine.type == Defs.M_GENERATOR and int(machine.buffer.get(Defs.GENERATOR_FUEL, 0)) > 0:
			capacity += Defs.GENERATOR_OUTPUT
	power_capacity = capacity
	# The first watt is an unlock condition ("power" token), asked here because
	# this is the one place that knows the grid exists. Latched: a generator
	# running dry later does not re-lock the belt.
	if capacity > 0.0 and not power_ever:
		power_ever = true
		_check_unlocks()

	var draw: float = 0.0
	for cell: Vector2i in machines:
		var machine: Machine = machines[cell]
		if Defs.machine_mines(machine.type) and miner_on_power(cell):
			draw += Defs.machine_power_draw(machine.type)
		elif Defs.machine_uses_recipes(machine.type):
			# Only while it has work. A machine standing empty and still pulling
			# on the grid slows every miner on it for no reason the player can
			# see, which is the shape of a number that moved with nothing on
			# screen to explain it.
			var recipe: Dictionary = recipe_of(machine)
			# Work means materials in *and* somewhere to put the result. A machine
			# holding output it cannot place does nothing at all -- `tick_recipe`
			# returns before the clock -- and one that kept drawing would slow
			# every miner on the grid for a stall the player cannot see from the
			# power number.
			if recipe.is_empty() or not machine.outbox.is_empty():
				continue
			if recipe_inputs_ready(machine, recipe):
				draw += Defs.machine_power_draw(machine.type)
	power_draw = draw

func cell_centre(cell: Vector2i) -> Vector2:
	return Grid.centre(cell)

## Where a cat stands to work this cell: its torso, CAT_FOOT_DROP above its feet.
##
## A cat's position is its torso and its feet are drawn ten pixels below that,
## so the point a cat is sent to is the work point lifted by that much. Used by
## both the walk and the drop, or a cat carried to a post would sit correctly and
## then shuffle ten pixels the first time it walked back from lunch.
func post_stand(cell: Vector2i) -> Vector2:
	return work_point(cell) - Vector2(0.0, Defs.CAT_FOOT_DROP)

## Where a working cat's feet stand: on the post (World Visual Pass 01).
##
## A mining post is its node's two by two now, and the cat works it standing on
## it -- at the rig's `work_anchor`, a point in the footprint written in its row
## of the machine table -- rather than from the cell behind a four by four. On a
## bare node the cat stands on the node and digs. Anything else is its own cell.
##
## The post is solid to everyone else: she cannot walk into it and no other cat
## crosses it. Its own cat reaches the spot because the route it asks for opens
## the one cell it is going to (`_route` opens start and goal), and nothing else.
func work_point(cell: Vector2i) -> Vector2:
	var machine: Machine = machine_at(cell)
	if machine != null and Defs.machine_mines(machine.type):
		return Grid.origin(machine_rect(machine).position) \
			+ Defs.machine_work_anchor(machine.type) * float(Grid.CELL)
	if has_ore(cell):
		return ore_centre(cell)
	return cell_centre(cell)

## The cell a cat works a post from: the one its feet are on.
func work_cell(cell: Vector2i) -> Vector2i:
	return cell_of(work_point(cell))

## The cell of a post's front edge its output leaves from, in line with its
## anchor: `output_cell` is the one past it. Named so the cat's spot and the
## post's doorway can be told apart -- a worker standing in its own doorway would
## be a post that stops itself (`test_output_anchor_is_separate_from_cat_work_anchor`).
func output_anchor(machine: Machine) -> Vector2i:
	return output_cell(machine) - machine.dir

## The free cell against a rectangle nearest to a point: where something that
## cannot enter a building stands to reach it. `avoid` are cells not to use --
## a post's output, which a cat standing on would be standing in the way of.
func approach_cell(rect: Rect2i, from: Vector2, avoid: Array[Vector2i] = []) -> Vector2i:
	var best: Vector2i = NONE
	var best_distance: float = 1e20
	for cell: Vector2i in Grid.edge_cells(rect):
		if avoid.has(cell) or blocks_player(cell):
			continue
		var distance: float = cell_centre(cell).distance_squared_to(from)
		if distance < best_distance:
			best_distance = distance
			best = cell
	if best == NONE:
		return Vector2i(rect.position.x, rect.end.y)
	return best

## Where a cat hands something in to the base: the nearest free cell against
## it. The base is eight cells across and solid; walking to its middle would be
## walking through it.
func base_door(from: Vector2) -> Vector2:
	return cell_centre(approach_cell(base_rect(), from))

## The hut's doorstep, in world pixels: half a tile below its bottom edge, under
## the middle of the building. Everything that comes out of the hut or goes into
## it -- the cats at night and in the morning, her after sleeping -- comes and
## goes here.
func shelter_doorstep() -> Vector2:
	var span: Rect2 = Grid.rect_px(shelter_rect())
	return Vector2(span.get_center().x, span.end.y + float(Grid.TILE) * 0.5)

## The middle of the hut, in world pixels.
func shelter_centre() -> Vector2:
	return Grid.rect_centre(shelter_rect())

## Where a cat stands to eat: the free cell against the bin nearest to it.
func food_door(from: Vector2) -> Vector2:
	return cell_centre(approach_cell(food_rect(), from))

## Work rate contributed by whichever cat is standing at this miner. Zero means
## nobody is home; a starving cat still works, at a third of the pace.
## How fast a miner runs. A cat at the machine is the early answer; once the grid
## can pay for it, the machine runs itself. Power never beats a fed cat -- it
## matches one -- so electrifying is about scale, not about replacing workers
## with something better.
func _operator_rate(cell: Vector2i, supply: float) -> float:
	var worker: Cat = worker_at(cell)
	if worker != null:
		# The grade multiplies the work, and hunger still cuts it. An O cat is
		# exactly 1.0, so this is the same number it always was for every cat the
		# game produced before the slot machine existed.
		var grade: float = Defs.RARITY_WORK_RATE[clampi(worker.rarity, 0, Defs.RARITY_WORK_RATE.size() - 1)]
		return grade if worker.hunger > 0.0 else grade * Defs.HUNGER_STARVED_RATE
	return supply if power_capacity > 0.0 else 0.0

## The cat actually standing at this machine, or null. Carried cats are excluded
## here rather than at each call site: a cat in the player's arms was still
## counted as working, so picking one up left its miner running on a worker who
## was several tiles away in mid-air.
func worker_at(cell: Vector2i) -> Cat:
	for cat: Cat in cats:
		if cat == carried_cat:
			continue
		if cat.assigned == cell and cat.state == Defs.CAT_WORKING:
			return cat
	return null

## True when this miner is running on the grid rather than on a worker, which is
## what the drill colour and the power ledger both need to know.
func miner_on_power(cell: Vector2i) -> bool:
	var machine: Machine = machines.get(cell, null)
	if machine == null or not Defs.machine_mines(machine.type):
		return false
	if power_capacity <= 0.0:
		return false
	return worker_at(cell) == null

## --- Hand mining ----------------------------------------------------------
## The player can work a seam themselves from the first minute. It is slow on
## purpose: it is the baseline every machine is measured against, and the reason
## the first miner feels like relief rather than a sidegrade. Returns the item
## produced this tick, or -1.
## Swinging at a cell. A seam yields its ore and stays; a boulder yields stone
## and is gone, which is the difference between a resource that renews and a
## thing you clear.
func hand_mine(cell: Vector2i, delta: float) -> int:
	var seam: bool = has_ore(cell)
	var rock: bool = not seam and has_rock(cell)
	if (not seam and not rock) or not can_touch(cell):
		hand_progress = 0.0
		hand_cell = Vector2i(9999, 9999)
		return -1
	# A node is one seam whichever of its four cells she is aimed at, so the
	# swing is kept against the node: stepping half a tile along it is not a
	# new swing, and the ring is drawn on the node rather than on a quarter of it.
	var target: Vector2i = ore_origin_at(cell) if seam else cell
	if target != hand_cell:
		hand_cell = target
		hand_progress = 0.0
	hand_progress += delta
	if hand_progress < hand_period(cell):
		return -1
	hand_progress = 0.0
	if rock:
		mined_rocks[Grid.tile_of(cell)] = true
		_grid_dirty = true
		return Defs.ITEM_STONE
	return ore_item(cell)

## How long one swing takes here. Boulders are slower than seams: a rock is a
## rock, and the gap is what makes walking to a seam worth the walk.
func hand_period(cell: Vector2i) -> float:
	return Defs.HAND_MINE_PERIOD if has_ore(cell) else Defs.ROCK_MINE_PERIOD

## 0..1 across the current swing, for the progress ring the player watches.
func can_hand_mine(cell: Vector2i) -> bool:
	# The prompt reads this, so a cell frozen out of reach must answer no --
	# otherwise the game offers 캐기 on a tile that refuses the key.
	if not can_touch(cell):
		return false
	# A block of ice standing on the seam outranks the seam. Z *pressed* already
	# picked the block up -- that branch sits above the swing -- but mining is a
	# key held down rather than pressed, and holding it started a swing before
	# the press was ever released. So a player who walked up to a cat frozen onto
	# a seam and held Z mined the ground out from under it.
	if frozen_key(cell) != NONE:
		return false
	return has_ore(cell) or has_rock(cell)

func hand_fraction() -> float:
	return clampf(hand_progress / hand_period(hand_cell), 0.0, 1.0)

func cancel_hand_mine() -> void:
	hand_progress = 0.0
	hand_cell = Vector2i(9999, 9999)

## Walking over a loose item pockets it straight into the base stock. Immediate,
## because bending down for something you are standing on should not need a
## second verb.
## A crystal picked up off the snow. Returns whether there was one -- the caller
## says so on screen, because this is the only way crystal enters the game and a
## silent pickup would leave the player wondering where it came from.
func collect_shard_at(cell: Vector2i) -> bool:
	if not can_touch(cell):
		return false
	if not shards.has(cell):
		return false
	shards.erase(cell)
	_gain(Defs.ITEM_CRYSTAL, 1)
	return true

## Walking over a pile takes the whole pile. Picking up one of a stack of nine
## and having to walk off and back on eight more times is not a mechanic.
##
## The count of what was taken is in `last_collected`, so the caller can say so.
var last_collected: int = 0
func collect_ground_at(cell: Vector2i) -> int:
	if not ground.has(cell) or not can_touch(cell):
		return -1
	var item_type: int = int(ground[cell])
	var count: int = ground_count(cell)
	ground.erase(cell)
	ground_stack.erase(cell)
	last_collected = count
	# Into the pack, not into the fire. An energy crystal picked up off the snow
	# used to add its heat on the spot and stay in the stores as well, so the
	# circle could grow from bending down.
	_gain(item_type, count)
	return item_type

## Everything on the belt she is standing on, straight into the pack.
##
## A belt runs under her feet and its cargo used to slide past untouched, which
## is the one place in this game where a thing she can see and reach cannot be
## taken. Returns what was taken, or -1.
func collect_belt_at(cell: Vector2i) -> int:
	var machine: Machine = machine_at(cell)
	if machine == null or machine.type != Defs.M_BELT or machine.items.is_empty():
		return -1
	if not can_touch(cell):
		return -1
	var item_type: int = int(machine.items[0]["type"])
	var count := 0
	# Only the ones of a kind, so a mixed belt does not turn into a single
	# picture of whatever happened to be at the front.
	var index := machine.items.size() - 1
	while index >= 0:
		if int(machine.items[index]["type"]) == item_type:
			machine.items.remove_at(index)
			count += 1
		index -= 1
	if count <= 0:
		return -1
	machine.stalled = false
	last_collected = count
	_gain(item_type, count)
	return item_type

## The nearest loose item, or a sentinel. Used by idle cats looking for work.
func nearest_ground(from: Vector2) -> Vector2i:
	var best := Vector2i(9999, 9999)
	var best_distance: float = 1e20
	for cell: Vector2i in ground:
		var distance: float = cell_centre(cell).distance_to(from)
		if distance < best_distance:
			best_distance = distance
			best = cell
	return best

func _tick_cats(delta: float) -> void:
	# Indoors there are no errands. The machines, the bowl and the shelter are
	# all six hundred cells away, and a cat that takes a job in here walks out of
	# the room and across the map to reach it -- which is what happened the first
	# time the room became a place. Awake and strolling, or asleep once she is,
	# and the wander is the same one they do outside.
	if indoors:
		for cat: Cat in cats:
			if cat == carried_cat:
				continue
			# Asleep on the floor, waking on its own second. She is up before them
			# -- the morning starts with her opening her eyes in a room full of
			# cats that have not.
			if cat.state == Defs.CAT_ASLEEP:
				if cat.waking <= 0.0:
					continue
				cat.waking = maxf(0.0, cat.waking - delta)
				if cat.waking <= 0.0:
					cat.state = Defs.CAT_IDLE
				continue
			# Still outside the door. It waits rather than standing on the mat,
			# and the pool does not draw it -- so what the player sees is one cat
			# after another arriving, which is what walking in single file looks
			# like from inside.
			if cat.entering > 0.0:
				cat.entering = maxf(0.0, cat.entering - delta)
				continue
			if cat.state != Defs.CAT_IDLE:
				cat.state = Defs.CAT_IDLE
				cat.path.clear()
			_cat_wander(cat, delta)
		return
	_assign_haulers()
	for cell: Vector2i in machines:
		if Defs.machine_mines(machines[cell].type):
			machines[cell].operated = false
	for cat: Cat in cats:
		# A cat in the player's arms is not a cat that is doing anything. Its
		# position belongs to carry_at, and letting a handler run alongside that
		# means the two write to it in the same frame: the sprite jumps between
		# the player's hands and wherever the cat was walking. It could also
		# change its own state in mid-air, and go on running a miner from up
		# there. Three of the nine handlers used to check this individually,
		# which is exactly how the other six came to be missing it.
		if cat == carried_cat:
			continue
		match cat.state:
			Defs.CAT_TO_MINER: _cat_walk_to_miner(cat, delta)
			Defs.CAT_WORKING: _cat_work(cat, delta)
			Defs.CAT_TO_FOOD: _cat_walk_to_food(cat, delta)
			Defs.CAT_EATING: _cat_eat(cat, delta)
			Defs.CAT_HAUL_TO_ITEM: _cat_fetch(cat, delta)
			Defs.CAT_HAUL_TO_BASE: _cat_deliver(cat, delta)
			Defs.CAT_IDLE: _cat_wander(cat, delta)
			Defs.CAT_TO_SHELTER: _cat_walk_home(cat, delta)
			Defs.CAT_ASLEEP: pass

## Walks a cat toward a point. Returns true once it is close enough to count as
## arrived -- which is not the same as being exactly on the spot. Snapping the
## last ten pixels onto the goal covered a fifth of a second of walking in a
## single frame, and the sprite and its shadow visibly jumped to get there.
## Stopping a few pixels short reads as a cat standing next to the bowl, which is
## what a cat would do anyway.
## A route from one point to another, as world points, ending on the goal itself.
##
## The goal is very often a structure -- a cat works standing on its miner, eats
## at the bin, sleeps in the hut, delivers onto the core -- so "cats cannot enter
## structures" would be a game where no cat can do anything. The rule is that a
## cat cannot walk *through* a structure it is not going to, which is the usual
## pathfinding one: the destination is passable for the trip that ends there.
##
## An empty route means walk straight. That happens when the goal is next door,
## and when there is no way round at all -- a cat sealed in by a factory built
## around it walks out through the wall rather than standing there forever, which
## is the lesser of the two wrongs.
func _route(from: Vector2, goal: Vector2) -> Array[Vector2]:
	var start: Vector2i = cell_of(from)
	var target: Vector2i = cell_of(goal)
	if start == target:
		return [goal] as Array[Vector2]
	_refresh_grid()
	if not _grid.is_in_boundsv(start) or not _grid.is_in_boundsv(target):
		return [goal] as Array[Vector2]
	# Both ends are opened for this query alone, then closed again.
	#
	# The destination, because a cat's errands are nearly all structures. And the
	# start, because it is one too: a worker leaves for the bowl from on top of
	# its own miner. Opening only the destination made A* refuse to plan from a
	# solid cell at all, which fell through to the straight line below -- so the
	# cats that most needed a route were exactly the ones that walked through the
	# machine next door.
	var opened: Array[Vector2i] = []
	for end: Vector2i in [start, target]:
		if _grid.is_point_solid(end):
			_grid.set_point_solid(end, false)
			opened.append(end)
	var cells: Array[Vector2i] = _grid.get_id_path(start, target)
	for end: Vector2i in opened:
		_grid.set_point_solid(end, true)
	if cells.size() <= 1:
		return [goal] as Array[Vector2]
	var route: Array[Vector2] = []
	# The first cell is the one the cat is standing in, and walking to its centre
	# first would drag the animal backwards before it set off.
	for index in range(1, cells.size() - 1):
		route.append(cell_centre(cells[index]))
	route.append(goal)
	return route

## Solid points, rebuilt when the world changes rather than every query. Only the
## blocked cells are touched: update() clears them all, and there are a handful of
## structures against ten thousand cells.
func _refresh_grid() -> void:
	if not _grid_dirty:
		return
	_grid_dirty = false
	# The grid follows wherever everyone is. Outside that is a square around the
	# fire; inside the hut it is the room, because a grid still centred on the
	# base leaves the room six hundred cells out of bounds -- and out of bounds
	# means no route, which means the straight line, which means cats walking
	# through the sofa. Same pathing, moved.
	if indoors:
		_grid.region = Defs.room_rect_cells(1)
	else:
		var reach: int = PATH_RADIUS * Grid.SCALE
		_grid.region = Rect2i(core_cell - Vector2i.ONE * reach,
			Vector2i.ONE * (reach * 2 + 1))
	_grid.cell_size = Vector2.ONE * float(Grid.CELL)
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.update()
	if indoors:
		# The furniture and the four walls, from the same table the drawing and
		# the collision read.
		for cell: Vector2i in Grid.cells_in(Defs.room_rect_cells(1)):
			if blocks_player(cell) and _grid.is_in_boundsv(cell):
				_grid.set_point_solid(cell, true)
		return
	# Every cell of every footprint, not the anchors: a base is eight cells across
	# and a cat that only knew about its anchor walked through the other sixty-three.
	for anchor: Vector2i in machines:
		var machine: Machine = machines[anchor]
		if machine.type in Defs.WALKABLE_MACHINES:
			continue
		for cell: Vector2i in Grid.cells_in(machine_rect(machine)):
			if _grid.is_in_boundsv(cell):
				_grid.set_point_solid(cell, true)
	# The two buildings, and the case. Ice and wreckage are deliberately not here
	# -- they stand out past the fire where a cat that could not path round one
	# would be a cat stuck behind it forever -- but the case is two cells from the
	# core, in the middle of everything, on the line every worker walks between
	# the eastern seams and the hut.
	var rects: Array[Rect2i] = [shelter_rect(), food_rect()]
	if kit_cell != NONE:
		rects.append(prop_rect(kit_cell))
	for rect: Rect2i in rects:
		for cell: Vector2i in Grid.cells_in(rect):
			if _grid.is_in_boundsv(cell):
				_grid.set_point_solid(cell, true)

## Which cell a point is in. One definition, because the player and the cats have
## to agree about what "this tile" means.
func cell_of(at: Vector2) -> Vector2i:
	return Grid.cell_at(at)

## The one place a walking cat is moved.
##
## Every handler goes through here -- to the machine, to the bowl, to the hut, to
## a dropped rock, to the core, and the stroll -- and that is the whole reason the
## rule holds at all. A check written into each handler is a check missing from
## one of them: this file has already had "do not simulate a carried cat" present
## in three of nine handlers and absent from six.
func _step_toward(cat: Cat, goal: Vector2, delta: float) -> bool:
	if not goal.is_equal_approx(cat.path_goal):
		cat.path_goal = goal
		cat.path = _route(cat.pos, goal)

	# One tick buys one step, however many corners the route turns inside it.
	# Spending a fresh step on each leg is what the first version did, and a cat
	# rounding three corners covered three steps in a frame -- which the walking
	# tests caught as exactly what it was, an animal moving faster than it can
	# walk.
	# Ambling, not commuting. A cat crossing the base to reach a machine has
	# somewhere to be; one killing time does not, and at the same speed the two
	# are indistinguishable.
	var pace: float = Defs.WANDER_SPEED if cat.state == Defs.CAT_IDLE else 1.0
	var budget: float = Defs.CAT_SPEED * pace * delta
	while budget > 0.0 and not cat.path.is_empty():
		var leg: Vector2 = cat.path[0]
		var to_leg: Vector2 = leg - cat.pos
		var distance: float = to_leg.length()
		if distance <= budget:
			cat.pos = leg
			budget -= distance
			cat.path.remove_at(0)
			if distance > 0.0:
				cat.heading = to_leg / distance
			continue
		cat.heading = to_leg / distance
		cat.pos += cat.heading * budget
		budget = 0.0
	# Arrived means standing on it, not near it. Reporting arrival from ten
	# pixels out left a cat working ten pixels off the middle of its own machine,
	# and then anything that put it where it belonged moved it those ten pixels
	# in one frame, which is a teleport.
	return cat.path.is_empty()

## Hands out the loose items: one cat per item, and the nearest free cat to each.
##
## This used to be a pull. Every idle cat asked for the item nearest to itself,
## which meant one rock on the floor sent the whole crew after it -- and the
## eight of them arrived together, seven found nothing, and went back. Deciding
## per item instead of per cat is what makes "the nearest one goes" expressible
## at all: a cat cannot know whether another cat is closer, and the sim can.
##
## Run once a tick over the whole crew rather than inside a cat's own handler,
## because that is the level the question lives at.
func _assign_haulers() -> void:
	if ground.is_empty() or cats.is_empty():
		return
	# Items already on their way to someone, and the cats with nothing on.
	var claimed: Dictionary[Vector2i, bool] = {}
	var free: Array[Cat] = []
	for cat: Cat in cats:
		if cat == carried_cat:
			continue
		if cat.state == Defs.CAT_HAUL_TO_ITEM:
			claimed[cat.haul_target] = true
		elif cat.state == Defs.CAT_IDLE and not cat.has_job():
			free.append(cat)
	for cell: Vector2i in ground:
		if free.is_empty():
			return
		if claimed.has(cell):
			continue
		var at: Vector2 = cell_centre(cell)
		var best: Cat = null
		var best_distance: float = 1e20
		for cat: Cat in free:
			var distance: float = cat.pos.distance_to(at)
			if distance < best_distance:
				best_distance = distance
				best = cat
		if best == null:
			return
		best.haul_target = cell
		best.state = Defs.CAT_HAUL_TO_ITEM
		best.path.clear()
		best.path_goal = Vector2(1e20, 1e20)
		best.wander_timer = 0.0
		free.erase(best)
		claimed[cell] = true

## Killing time. A pause, a stroll in some direction, another pause.
##
## Standing perfectly still reads as the game being paused rather than as an
## animal waiting, and eight cats standing perfectly still in a row reads as a
## bug. Both durations are drawn from a range: a fixed rhythm is its own kind of
## stillness, because four cats stepping on the same beat look like one
## animation played four times.
func _cat_wander(cat: Cat, delta: float) -> void:
	if cat == carried_cat:
		return
	# Mid-stroll: the same mover every other errand uses, so a loitering cat walks
	# round the hut instead of through it without anything here knowing that the
	# hut exists.
	if not cat.path.is_empty():
		if _step_toward(cat, cat.path_goal, delta):
			cat.wander_timer = wander_rng.randf_range(Defs.WANDER_PAUSE.x,
				Defs.WANDER_PAUSE.y)
		return
	cat.wander_timer -= delta
	if cat.wander_timer > 0.0:
		return
	var goal: Vector2 = _stroll_goal(cat)
	if goal.x > 1e19:
		cat.wander_timer = wander_rng.randf_range(Defs.WANDER_PAUSE.x, Defs.WANDER_PAUSE.y)
		return
	_step_toward(cat, goal, delta)

## Somewhere near, and somewhere it can stand.
##
## Tried a few times rather than solved: the base is mostly open, so a random
## nearby cell is almost always walkable, and giving up after a handful of tries
## is cheaper than being clever about the two frames a year where it is not.
func _stroll_goal(cat: Cat) -> Vector2:
	# Indoors the room is the leash. Same wander, same leash length, different
	# middle -- a cat strolling from a hut six hundred cells away would spend the
	# night walking north.
	var anchor: Vector2 = shelter_doorstep()
	if indoors:
		anchor = room_centre()
	var homeward: bool = cat.pos.distance_to(anchor) > Defs.WANDER_LEASH
	for attempt in 8:
		var heading: Vector2
		if homeward:
			# Roughly back, with enough scatter that the walk home does not look
			# like an order.
			heading = (anchor - cat.pos).normalized().rotated(
				wander_rng.randf_range(-0.7, 0.7))
		else:
			heading = Vector2.RIGHT.rotated(wander_rng.randf() * TAU)
		var reach: float = Grid.px(wander_rng.randf_range(1.0, 2.5))
		var candidate: Vector2 = cat.pos + heading * reach
		if not blocks_player(cell_of(candidate)):
			return candidate
	return Vector2(1e20, 1e20)

func _cat_fetch(cat: Cat, delta: float) -> void:
	if cat == carried_cat:
		return
	# The item may have been walked over by the player on the way.
	if not ground.has(cat.haul_target):
		cat.state = Defs.CAT_IDLE
		return
	if not _step_toward(cat, cell_centre(cat.haul_target), delta):
		return
	# One off the pile. A cat carries one thing.
	cat.carrying = int(ground[cat.haul_target])
	var left: int = ground_count(cat.haul_target) - 1
	if left > 0:
		ground_stack[cat.haul_target] = left
	else:
		ground.erase(cat.haul_target)
		ground_stack.erase(cat.haul_target)
	cat.state = Defs.CAT_HAUL_TO_BASE

func _cat_deliver(cat: Cat, delta: float) -> void:
	if cat == carried_cat:
		return
	# The side of the base it is coming from, chosen once per trip so the goal
	# does not slide under it as it walks.
	if cat.path_goal.x > 1e19 or not base_rect().grow(1).has_point(cell_of(cat.path_goal)):
		cat.path_goal = Vector2(1e20, 1e20)
	var door: Vector2 = cat.path_goal if cat.path_goal.x < 1e19 else base_door(cat.pos)
	if not _step_toward(cat, door, delta):
		return
	if cat.carrying >= 0:
		_deliver(cat.carrying, core_cell)
		cat.carrying = -1
	# Back to the seam it was put on, rather than standing at the core waiting to
	# be told again. A cat with a post keeps it: that is what putting it there
	# meant, and it is the difference between a worker and an errand.
	cat.state = Defs.CAT_TO_MINER if cat.has_job() and _is_post(cat.assigned) \
		else Defs.CAT_IDLE

# --- Going to bed ------------------------------------------------------------
## The workforce walks home rather than blinking out at the end of the day. It
## is also the moment the factory visibly stops: _tick_cats clears `operated` on
## every miner each frame, so a miner whose cat has left for the hut goes quiet
## on its own without anything having to switch it off.

## Calls everyone home. Whatever they were carrying comes with them -- dropping
## it on the way would lose the last minute of the day's haul for no reason the
## player could see.
func send_cats_home() -> void:
	carried_cat = null
	for cat: Cat in cats:
		cat.state = Defs.CAT_TO_SHELTER

## Night falling on a player who stays up. The crew stops work and walks home on
## its own -- the animals keep their own hours -- but nothing is yanked: a cat
## in her arms stays in her arms, and a machine on the grid keeps running,
## because electricity does not sleep. This is what makes powered automation
## the answer to the night rather than a nicer number.
func rest_cats() -> void:
	for cat: Cat in cats:
		if cat == carried_cat:
			continue
		if cat.state == Defs.CAT_TO_SHELTER or cat.state == Defs.CAT_ASLEEP:
			continue
		cat.state = Defs.CAT_TO_SHELTER

## And morning finding them where they slept: everyone walks back out to the
## post they had, from the hut, with their own legs.
func rouse_cats() -> void:
	for cat: Cat in cats:
		if cat.state != Defs.CAT_ASLEEP:
			continue
		cat.pos = shelter_doorstep() - Vector2(0.0, float(Grid.TILE) * 0.5 - 12.0)
		cat.state = Defs.CAT_TO_MINER if cat.has_job() else Defs.CAT_IDLE

## True once every cat has reached the hut.
func cats_all_home() -> bool:
	for cat: Cat in cats:
		if cat.state != Defs.CAT_ASLEEP:
			return false
	return true

## The end of the gathering phase, for the stragglers. A cat that cannot reach
## the hut -- boxed in by a factory built around it, or simply too far out -- must
## not be able to hold the night open, so the sequence closes the door on time
## and they are indoors regardless.
func force_cats_home() -> void:
	for cat: Cat in cats:
		if cat.state == Defs.CAT_ASLEEP:
			continue          # already in, and moving it would be a jump for nothing
		cat.pos = shelter_centre()
		cat.state = Defs.CAT_ASLEEP

## Morning. Everyone starts on the doorstep and walks back to the post they had,
## which is what makes the assignments the player made visible as a thing that
## survives the night.
func wake_cats(doorstep: Vector2) -> void:
	var count: int = maxi(cats.size(), 1)
	for index in cats.size():
		var cat: Cat = cats[index]
		# Fanned across the doorstep rather than stacked on one pixel, so a
		# workforce of six reads as six cats leaving a hut.
		var spread: float = (float(index) - float(count - 1) * 0.5) * Defs.CAT_LANE
		cat.pos = _clear_spot(doorstep + Vector2(spread, 0.0))
		# A beat on the doorstep before anyone wanders off. An animal that has
		# just come out of a hut stands and looks around; one that starts pacing
		# on the frame the door opens reads as a spawn rather than a waking.
		cat.path.clear()
		cat.path_goal = Vector2(1e20, 1e20)
		cat.wander_timer = wander_rng.randf_range(Defs.WANDER_PAUSE.x, Defs.WANDER_PAUSE.y)
		# Anything still in a cat's mouth at bedtime is handed in rather than
		# deleted. Silently losing the last minute of the day's haul is the kind
		# of thing a player notices only as a number that does not add up.
		if cat.carrying >= 0:
			_deliver(cat.carrying, core_cell)
			cat.carrying = -1
		cat.haul_target = Vector2i(9999, 9999)
		# Same predicate as the morning: a cat that carried a stone home from a
		# bare seam went back to standing around instead of back to the seam.
		if cat.has_job() and _is_post(cat.assigned):
			cat.state = Defs.CAT_TO_MINER
		else:
			cat.assigned = Vector2i(9999, 9999)
			cat.state = Defs.CAT_IDLE

func _cat_walk_home(cat: Cat, delta: float) -> void:
	if _step_toward(cat, shelter_doorstep(), delta):
		cat.state = Defs.CAT_ASLEEP

func _cat_walk_to_miner(cat: Cat, delta: float) -> void:
	if not cat.has_job() or not _is_post(cat.assigned):
		cat.state = Defs.CAT_IDLE
		return
	if _step_toward(cat, post_stand(cat.assigned), delta):
		cat.state = Defs.CAT_WORKING

## Whether the animal is holding the drill.
##
## The tool belongs to the machine, not to the cat: a cat at a miner is working
## the machine, and a cat at a bare seam is digging with its paws. Both are the
## same state and were drawn the same way, so a cat on open ore appeared to be
## running a drill that is not there -- and the difference between the two, the
## whole reason to build the machine, was invisible.
##
## Asked here rather than at the draw call, because the drawing side keeping its
## own list of when a cat is working is exactly how a handler gets missed.
func cat_has_tool(cat: Cat) -> bool:
	if cat == null or cat.state != Defs.CAT_WORKING:
		return false
	var machine: Machine = machines.get(cat.assigned, null)
	return machine != null and Defs.machine_mines(machine.type)

## A post is a miner, or a bare seam. Both are places a cat can be put down and
## will keep working; asked in one place so the three handlers that check it
## cannot come to disagree about what a job is.
func _is_post(cell: Vector2i) -> bool:
	var machine: Machine = machines.get(cell, null)
	if machine != null:
		return Defs.machine_mines(machine.type)
	# A bare node is a post by its origin, the way a machine is by its anchor.
	return ore_origin_at(cell) == cell and machine_at(cell) == null

## The post a cell belongs to: the anchor of the mining machine covering it, or
## the cell itself when it is a bare seam. NONE for anything else.
func post_anchor(cell: Vector2i) -> Vector2i:
	var machine: Machine = machine_at(cell)
	if machine != null:
		return machine.cell if Defs.machine_mines(machine.type) else NONE
	return ore_origin_at(cell)

func _cat_work(cat: Cat, delta: float) -> void:
	if not cat.has_job() or not _is_post(cat.assigned):
		cat.state = Defs.CAT_IDLE
		return
	cat.hunger = maxf(0.0, cat.hunger - Defs.HUNGER_PER_SECOND * delta)
	if machines.has(cat.assigned):
		machines[cat.assigned].operated = true
	else:
		# A bare seam. The cat digs it out itself and carries the stone home,
		# which is slower than a miner in two ways: the digging, and the walk.
		cat.dig += delta / Defs.CAT_DIG_PERIOD
		if cat.dig >= 1.0:
			cat.dig = 0.0
			cat.carrying = ore_item(cat.assigned)
			cat.state = Defs.CAT_HAUL_TO_BASE if cat.carrying >= 0 else Defs.CAT_IDLE
			return
	if cat.hunger <= 0.0 and food > 0 and food_placed:
		cat.state = Defs.CAT_TO_FOOD

func _cat_walk_to_food(cat: Cat, delta: float) -> void:
	if cat.path_goal.x > 1e19 or not food_rect().grow(1).has_point(cell_of(cat.path_goal)):
		cat.path_goal = Vector2(1e20, 1e20)
	var door: Vector2 = cat.path_goal if cat.path_goal.x < 1e19 else food_door(cat.pos)
	if _step_toward(cat, door, delta):
		cat.state = Defs.CAT_EATING
		cat.eat_timer = 0.0

## Eating is slow on purpose: one unit every five seconds, a third of a belly
## each. A hungry workforce is a real interruption, not a formality.
func _cat_eat(cat: Cat, delta: float) -> void:
	if food <= 0:
		cat.state = Defs.CAT_TO_MINER
		return
	cat.eat_timer += delta
	while cat.eat_timer >= Defs.FOOD_SECONDS_PER_UNIT and food > 0 and cat.hunger < 1.0:
		cat.eat_timer -= Defs.FOOD_SECONDS_PER_UNIT
		food -= 1
		cat.hunger = minf(1.0, cat.hunger + Defs.FOOD_HUNGER_PER_UNIT)
	if cat.hunger >= 1.0:
		cat.state = Defs.CAT_TO_MINER

## What the snow shows, as opposed to what the simulation answers. The rules --
## is_warm, can_touch, the cold -- read `warm_radius` and are right immediately;
## the picture eases toward it, so the base unfolding and every upgrade read as
## heat spreading rather than as a circle being swapped. Snapped on setup and on
## load: an old fire does not re-spread.
var shown_radius: float = 0.0

func _tick_shown_radius(delta: float) -> void:
	if is_equal_approx(shown_radius, warm_radius):
		return
	var gap: float = warm_radius - shown_radius
	var rate: float = maxf(3.0, absf(gap) * 1.6)
	shown_radius = move_toward(shown_radius, warm_radius, rate * delta)

func _refresh_radius() -> void:
	# No base, no fire, no circle -- only as much of the map as she can see from
	# where she is standing.
	var level: int = Defs.base_level(stones_in)
	var rose: bool = base_placed and level > base_level
	base_level = level
	warm_radius = Defs.warm_radius(stones_in) if base_placed else Defs.CRASH_SIGHT
	if not is_equal_approx(warm_radius, _cached_radius):
		_cached_radius = warm_radius
		warmth_changed.emit(warm_radius)
	if rose:
		base_upgraded.emit(base_level, warm_radius)

## One production step, shared by every machine the recipe system drives.
##
## This is the only tick a new production machine needs. Adding 제조기 is a row in
## `Defs.RECIPES` and its number in `Defs.RECIPE_MACHINES`; nothing in this file
## changes. That is the whole point of the piece of work this arrived in.
##
## The order is deliberate. Finished goods are handed on **first**, because a
## machine still holding output must not begin another cycle -- otherwise a
## mis-aimed belt turns the machine into a warehouse that grows without bound.
## Progress is kept rather than thrown away when the exit is blocked: the work
## was done, and losing it would punish the player for a belt they are about to
## fix.
func tick_recipe(machine: Machine, recipe: Dictionary, delta: float) -> void:
	if recipe.is_empty():
		return
	_drain_outbox(machine)
	if not machine.outbox.is_empty():
		machine.operated = false
		machine.stalled = true
		return
	if not recipe_inputs_ready(machine, recipe):
		machine.operated = false
		machine.stalled = false
		return
	# `operated` is what the drawing layer reads to decide between a progress arc
	# and an idle blink, so it has to mean "actually advancing". At zero power the
	# tick still runs with a delta of zero, and a machine that says it is working
	# while the grid is dead is the one state a player cannot diagnose.
	machine.operated = delta > 0.0
	machine.stalled = false
	machine.progress += delta
	if machine.progress < float(recipe["seconds"]):
		return
	machine.progress = 0.0
	# Consumed at the end rather than the start, which is what makes a blocked
	# machine hold its inputs instead of eating them into a cycle it cannot
	# finish.
	for port: Dictionary in recipe["inputs"]:
		var eaten: int = int(port["item"])
		var left: int = int(machine.buffer.get(eaten, 0)) - int(port["amount"])
		if left > 0:
			machine.buffer[eaten] = left
		else:
			machine.buffer.erase(eaten)
	for port: Dictionary in recipe["outputs"]:
		var made: int = int(port["item"])
		machine.outbox[made] = int(machine.outbox.get(made, 0)) + int(port["amount"])
		# The run has now had one, which is the question an unlock asks. Mining
		# is not the only way a material enters the world any more, and asking
		# only `_gain` would mean a factory that has been turning out 전동기 for a
		# minute still has nothing in the build list to spend them on -- the
		# player would have to walk two of them home to be told what they are for.
		held_items[made] = true
		recipe_produced.emit(machine.cell, made, int(port["amount"]))
	_check_unlocks()
	machine.flash = 0.5
	_drain_outbox(machine)
	machine.stalled = not machine.outbox.is_empty()

## Which recipe this machine is actually running.
##
## The key on the machine, or the type's starting recipe when it has none -- a
## machine built before the player chose anything, and every machine in a save
## written before machines could choose. A key that no longer names a recipe
## falls back the same way rather than leaving the machine inert.
func recipe_of(machine: Machine) -> Dictionary:
	if not machine.recipe_key.is_empty():
		var chosen: Dictionary = Defs.recipe_by_key(machine.recipe_key)
		if not chosen.is_empty() and int(chosen["machine"]) == machine.type:
			return chosen
	return Defs.recipe_for_machine(machine.type)

## Point a machine at a different recipe.
##
## Inputs are consumed at the *end* of a cycle, so there is never a half-eaten
## craft to refund -- resetting the clock loses nothing. What the buffer holds is
## a different question: iron sitting in a machine that now wants copper would be
## stranded there forever, since the input face only takes what the recipe asks
## for. So it is handed back out the front, through the same exit the output
## uses. Nothing is lost and nothing is made.
func set_recipe(machine: Machine, key: String) -> bool:
	var wanted: Dictionary = Defs.recipe_by_key(key)
	if wanted.is_empty() or int(wanted["machine"]) != machine.type:
		return false
	if machine.recipe_key == key:
		return false
	machine.recipe_key = key
	last_recipe[machine.type] = key
	machine.progress = 0.0
	machine.stalled = false
	machine.operated = false
	for item_id: int in machine.buffer.keys():
		var held: int = int(machine.buffer[item_id])
		if held > 0:
			machine.outbox[item_id] = int(machine.outbox.get(item_id, 0)) + held
	machine.buffer.clear()
	_drain_outbox(machine)
	return true

## Whether everything the recipe asks for is already inside the machine.
func recipe_inputs_ready(machine: Machine, recipe: Dictionary) -> bool:
	for port: Dictionary in recipe["inputs"]:
		if int(machine.buffer.get(int(port["item"]), 0)) < int(port["amount"]):
			return false
	return true

## Hands finished goods to whatever is in front, one at a time, and leaves what
## will not fit.
##
## Goes out through `_emit_from`, the same exit the miner uses -- a belt if one
## faces, the floor otherwise. A second set of output rules for recipe machines
## is a second set of rules to get wrong, and this repository has the receipts.
func _drain_outbox(machine: Machine) -> void:
	for item_id: int in machine.outbox.keys():
		while int(machine.outbox.get(item_id, 0)) > 0:
			if not _emit_from(machine, item_id):
				break
			machine.outbox[item_id] = int(machine.outbox[item_id]) - 1
		if int(machine.outbox.get(item_id, 0)) <= 0:
			machine.outbox.erase(item_id)

## Seconds per item for this rig on the seam under it. The seam decides which
## material and how pure it is; the rig decides the pace, and that split is the
## only thing Mk.2 changes.
func machine_period(machine: Machine) -> float:
	return seam_period(machine.ore_node) / Defs.machine_mine_rate(machine.type)

func _tick_miner(machine: Machine, delta: float) -> void:
	# A miner is inert without a cat standing at it. This is the whole point of
	# the worker system: heat buys the machine, cats buy the output.
	if not machine.operated:
		machine.stalled = false
		return
	# What the node it stands on yields -- asked of the node, never guessed. This
	# fell back to crystal (a retired item) when the anchor had no seam, which is
	# a machine inventing its own output; with no node under it, it produces
	# nothing and says so.
	var item_type: int = ore_item(machine.ore_node)
	if item_type < 0:
		machine.stalled = true
		return
	var period: float = machine_period(machine)
	machine.progress += delta
	if machine.progress < period:
		return
	if _emit_from(machine, item_type):
		machine.progress = 0.0
		machine.flash = 0.35
		machine.stalled = false
		machine_worked.emit(machine.cell, machine.type)
	else:
		# Hold the finished item instead of losing it when the output is blocked.
		machine.progress = period
		machine.stalled = true

## Copper is deliberately slower than crystal: it arrives later and is worth
## more per unit, so the same miner produces fewer of them.
func mine_period(item_type: int) -> float:
	match item_type:
		Defs.ITEM_COPPER: return Defs.COPPER_PERIOD
		Defs.ITEM_IRON: return Defs.IRON_PERIOD
	return Defs.MINER_PERIOD

## Node purity, keyed by distance from the core. Rich seams sit further out, so
## "walk further for a better node" becomes a real decision instead of every
## seam being interchangeable. Fixed at generation like everything else, so the
## map is the level design.
func purity_of(cell: Vector2i) -> int:
	var origin: Vector2i = ore_origin_at(cell)
	if origin == NONE:
		return Defs.PURITY_NORMAL
	return int(purity.get(origin, Defs.PURITY_NORMAL))

## Seconds per item at this seam, purity included.
func seam_period(cell: Vector2i) -> float:
	var base: float = mine_period(ore_type_at(cell))
	return base / Defs.PURITY_RATE[purity_of(cell)]

## Output goes onto a belt if one is facing, and onto the floor otherwise. The
## floor is not a failure state -- it is how the game works before belts exist,
## because cats pick up from there.
func _emit_from(machine: Machine, item_type: int) -> bool:
	var ahead: Vector2i = output_cell(machine)
	# The floor counts as output. It is where everything goes before belts exist,
	# and a meter that only counted belted items would read zero for a perfectly
	# productive early-game miner.
	if _push_into(ahead, item_type, machine.cell) or drop_item(ahead, item_type):
		_note_out(machine, item_type)
		return true
	return false

## Puts a loose item on the floor. One per cell keeps the world readable and
## stops a stalled miner from burying its own tile.
## A loose item on a tile, and how many of them are on it.
##
## A cell used to hold exactly one, which is fine for a miner dropping its output
## for a cat to fetch and wrong for the end of a belt: a line pouring onto bare
## ground filled one tile and then stalled forever. A belt that runs out of belt
## should pile its cargo up, not stop.
const GROUND_STACK_MAX := 24

func ground_count(cell: Vector2i) -> int:
	return int(ground_stack.get(cell, 1)) if ground.has(cell) else 0

func drop_item(cell: Vector2i, item_type: int) -> bool:
	if machine_at(cell) != null or has_ore(cell):
		return false
	# Not into a building either. The hut and the bin are not machines, and a
	# line that ran into the hut's wall used to pour its cargo onto the roof.
	if in_shelter(cell) or in_food_bin(cell):
		return false
	if ground.has(cell):
		# Same kind stacks; a different kind does not, because a tile showing one
		# picture cannot be holding two things.
		if int(ground[cell]) != item_type:
			return false
		var held: int = ground_count(cell)
		if held >= GROUND_STACK_MAX:
			return false
		ground_stack[cell] = held + 1
		return true
	ground[cell] = item_type
	ground_stack[cell] = 1
	return true

## `t` runs 0..1 across one belt cell. The belt is half a tile since Grid v2, so
## the cell speed and the spacing are the tile figures scaled to it -- items
## move and space out in the world exactly as they did.
func _tick_belt(machine: Machine, delta: float) -> void:
	var step: float = Defs.belt_cell_speed(machine.tier) * delta
	for index in range(machine.items.size()):
		var item: Dictionary = machine.items[index]
		var limit: float = 1.0
		if index > 0:
			limit = float(machine.items[index - 1]["t"]) - Defs.belt_gap_cells()
		item["t"] = minf(float(item["t"]) + step, limit)
		machine.items[index] = item
	if machine.items.is_empty():
		return
	var head: Dictionary = machine.items[0]
	if float(head["t"]) < 1.0:
		machine.stalled = false
		return
	var ahead: Vector2i = output_cell(machine)
	# Into whatever is in front, or -- if that is bare ground -- onto it. A line
	# that ends in the open used to stop dead at the last tile, so a belt built
	# before the thing it was going to feed was a belt that did nothing and gave
	# no sign why.
	if _push_into(ahead, int(head["type"]), machine.cell) \
			or drop_item(ahead, int(head["type"])):
		machine.items.remove_at(0)
		_note_out(machine, int(head["type"]))
		machine.stalled = false
	else:
		machine.stalled = machine.items.size() >= Defs.belt_cell_capacity()

## Upgrades a belt to the next grade, charging the difference. Grades are a
## convenience rather than a requirement -- grade 1 already outruns every miner
## in the game by a wide margin -- so this is an option the player can ignore.
## Returns the new tier, or -1.
func cycle_belt_tier(cell: Vector2i) -> int:
	var machine: Machine = machine_at(cell)
	if machine == null or machine.type != Defs.M_BELT:
		return -1
	var wanted: int = (machine.tier + 1) % Defs.BELT_TIERS.size()
	var have: int = int(stock.get(Defs.ITEM_COPPER, 0))
	var delta_cost: int = int(Defs.BELT_TIERS[wanted]["cost"]) - int(Defs.BELT_TIERS[machine.tier]["cost"])
	if delta_cost > 0 and have < delta_cost:
		return -1
	stock[Defs.ITEM_COPPER] = have - delta_cost
	machine.tier = wanted
	machine.flash = 0.4
	return wanted

## Round-robin across every neighbour that will actually accept the item, which
## is what lets a player write a ratio down and then build it. Blocked outputs
## are skipped rather than stalling the line, so one backed-up branch does not
## stop the others -- that behaviour is the whole reason a splitter is a tool
## and not just a fork in a pipe.
func _tick_splitter(machine: Machine, delta: float) -> void:
	if machine.items.is_empty():
		machine.stalled = false
		return
	machine.progress += delta
	if machine.progress < Defs.SPLITTER_PERIOD:
		return
	var item_type: int = int(machine.items[0]["type"])
	# A one-into-two splitter, not a four-way hub. Two outputs is the smallest
	# thing that can express a ratio, chains cleanly into 1:4 and 1:8, and stays
	# readable on a 32px tile -- a four-way version mostly produced lines the
	# player had not asked for.
	var sides: Array[Vector2i] = splitter_outputs(machine)
	for attempt in sides.size():
		var index: int = (machine.next_out + attempt) % sides.size()
		var target: Vector2i = machine.cell + sides[index]
		# Never push back where it came from, or two splitters face to face
		# would bounce one item between them forever.
		if target == machine.source:
			continue
		if _push_into(target, item_type, machine.cell) or drop_item(target, item_type):
			machine.items.remove_at(0)
			_note_out(machine, item_type)
			machine.next_out = (index + 1) % sides.size()
			machine.progress = 0.0
			machine.flash = 0.25
			machine.stalled = false
			return
	machine.progress = Defs.SPLITTER_PERIOD
	machine.stalled = true

## The two cells a splitter feeds: the pair perpendicular to the way it faces, so
## R turns the split axis and the input side stays behind it.
func splitter_outputs(machine: Machine) -> Array[Vector2i]:
	var dir: Vector2i = machine.dir
	var perp := Vector2i(-dir.y, dir.x)
	return [perp, -perp]

## A generator burns one heat stone every ten seconds. `operated` doubles as
## "currently supplying", which is what _recount_power reads.
##
## It burned crystal until 1.0.27, and crystal shards were the only place
## crystal came from; taking them out of the snow would have left this machine
## with nothing to eat. Heat stone is what the fire eats too, which is the
## point: power and warmth now bid for the same stone.
func _tick_generator(machine: Machine, delta: float) -> void:
	var fuel: int = int(machine.buffer.get(Defs.GENERATOR_FUEL, 0))
	if fuel <= 0:
		machine.operated = false
		machine.stalled = true
		machine.progress = 0.0
		return
	machine.stalled = false
	machine.operated = true
	machine.progress += delta
	if machine.progress < Defs.GENERATOR_PERIOD:
		return
	machine.buffer[Defs.GENERATOR_FUEL] = fuel - 1
	machine.progress = 0.0
	machine.flash = 0.5

## Returns true when the destination accepted the item. `from` is the cell the
## item is arriving from, which is what lets a machine refuse a face.
##
## Every accepted item is metered here rather than in each branch, so a machine
## added later cannot forget to count its own input. The core is the exception:
## cats hand it items without going through this path, so it counts in _deliver.
func _push_into(cell: Vector2i, item_type: int, from: Vector2i = Vector2i(9999, 9999)) -> bool:
	if not _accept_into(cell, item_type, from):
		return false
	var target: Machine = machine_at(cell)
	if target != null and target.type != Defs.M_CORE:
		_note_in(target, item_type)
	return true

func _accept_into(cell: Vector2i, item_type: int, from: Vector2i) -> bool:
	var target: Machine = machine_at(cell)
	if target == null:
		return false
	match target.type:
		Defs.M_CORE:
			_deliver(item_type, cell)
			return true
		Defs.M_BELT:
			if target.items.size() >= Defs.belt_cell_capacity():
				return false
			var tail_ok: bool = target.items.is_empty() \
				or float(target.items[-1]["t"]) > Defs.belt_gap_cells()
			if not tail_ok:
				return false
			target.items.append({"type": item_type, "t": 0.0})
			return true
		Defs.M_SPLITTER:
			if target.items.size() >= Defs.SPLITTER_CAPACITY:
				return false
			target.items.append({"type": item_type, "t": 0.0})
			target.source = from
			target.flash = 0.2
			return true
		Defs.M_GENERATOR:
			# Heat stone, and only from a face that is not the one it faces:
			# feeding the mouth a machine pours out of lets a line eat its own
			# product. The generator pours nothing, but the rule is cheaper to
			# keep than to remember the day it does.
			if item_type != Defs.GENERATOR_FUEL:
				return false
			var fuel: int = int(target.buffer.get(item_type, 0))
			if fuel >= 4:
				return false
			target.buffer[item_type] = fuel + 1
			target.flash = 0.25
			return true
		_:
			# Everything the recipe system drives takes what its recipe asks for
			# and nothing else. A machine that accepted anything would let one
			# mis-aimed belt fill it with a material it can never spend, and the
			# only way out of that is to tear the machine down.
			var recipe: Dictionary = recipe_of(target)
			if recipe.is_empty():
				return false
			var wanted := 0
			for port: Dictionary in recipe["inputs"]:
				if int(port["item"]) == item_type:
					wanted = int(port["amount"])
			if wanted <= 0:
				return false
			var held: int = int(target.buffer.get(item_type, 0))
			if held >= wanted * Defs.RECIPE_INPUT_CYCLES:
				return false
			target.buffer[item_type] = held + 1
			target.flash = 0.25
			return true
	return false

## Everything that reaches the core is banked as material. It is not burned.
##
## It used to be both: a heat stone a cat carried in was added to the stores and
## fed to the fire in the same call, so the same stone counted twice -- once on
## arrival and again when the player pressed Z at the core and the stores went
## into the flames. The visible half of that was worse than the arithmetic. The
## circle grew while the player was somewhere else, doing something else; the
## one thing the whole game is about happened as a background event with a
## number attached, and there was nothing to do about it or with it.
##
## So the core is a warehouse and the fire is fed by hand. Belts and cats save
## the walk to the seam, which is what they are for; walking to the fire and
## feeding it is the act the circle is the answer to.
## Whether a belt has ever put something into the fire.
##
## Latched, and saved: it is the moment the picture this game is about actually
## runs once, and a flag that reset on load would ask a player with a working
## factory to build their first line again.
var delivered_by_belt := false

func _deliver(item_type: int, cell: Vector2i) -> void:
	_gain(item_type, 1)
	delivered[item_type] = int(delivered.get(item_type, 0)) + 1
	# Where it came from. A belt feeding the core is the moment the whole design
	# runs by itself for the first time, and nothing else was in a position to
	# notice it happening.
	var feeder: Machine = machine_at(cell)
	if feeder != null and feeder.type == Defs.M_BELT:
		delivered_by_belt = true
	var core: Machine = machines.get(core_cell, null)
	if core != null:
		core.flash = 0.4
		_note_in(core, item_type)
	item_delivered.emit(item_type, cell)

func machine_count(type: int) -> int:
	var count := 0
	for cell: Vector2i in machines:
		if machines[cell].type == type:
			count += 1
	return count

func items_in_transit() -> int:
	var count := 0
	for cell: Vector2i in machines:
		count += machines[cell].items.size()
	return count
